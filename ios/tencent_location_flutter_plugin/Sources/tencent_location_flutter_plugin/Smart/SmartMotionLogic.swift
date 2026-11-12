// Adapted from Ikolvi/Tracelet 071cd0be (Apache-2.0):
// sdk/rust-core/core/src/state/smart_motion_coordinator.rs and
// sdk/ios/Sources/TraceletSDK/motion/SpeedMotionManager.swift.
// Modified: remove Rust/Tracelet dependencies and use continuous High/Low actions.
import CoreFoundation
import Foundation

struct SmartTrackingConfiguration {
    let stopTimeout: TimeInterval
    let speedStationaryDelay: TimeInterval
    let speedMovingThreshold: Double
    let speedWakeConfirmCount: Int

    init(_ map: [String: Any]) throws {
        func number(_ key: String, _ fallback: Double, positive: Bool = false) throws -> Double {
            guard let value = map[key] else { return fallback }
            guard let n = value as? NSNumber,
                  CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite,
                  positive ? n.doubleValue > 0 : n.doubleValue >= 0 else {
                throw SmartConfigurationError.invalid(key)
            }
            return n.doubleValue
        }
        let stopMs = try number("stopTimeoutMs", 120_000)
        let speedMs = try number("speedStationaryDelayMs", 90_000)
        guard stopMs <= Double(Int32.max), speedMs <= Double(Int32.max) else {
            throw SmartConfigurationError.invalid("timeout milliseconds exceed Int32.max")
        }
        stopTimeout = stopMs / 1000
        speedStationaryDelay = speedMs / 1000
        speedMovingThreshold = try number("speedMovingThreshold", 5, positive: true)
        let count = try number("speedWakeConfirmCount", 3, positive: true)
        guard count.rounded(.towardZero) == count, count <= Double(Int32.max) else {
            throw SmartConfigurationError.invalid("speedWakeConfirmCount")
        }
        speedWakeConfirmCount = Int(count)
    }
}

// Validate the request fields Smart depends on; explicit Dart null uses the
// same defaults as RequestCodec (not an invalid supplied value).
func validateSmartLocationRequests(high: [String: Any?], low: [String: Any?]) throws {
    func nonNull(_ value: Any??) -> Any? {
        guard let value = value ?? nil, !(value is NSNull) else { return nil }
        return value
    }
    let highCommon = high["common"] as? [String: Any?] ?? [:]
    let lowCommon = low["common"] as? [String: Any?] ?? [:]
    guard (highCommon["coordinateType"] as? String ?? "gcj02") ==
            (lowCommon["coordinateType"] as? String ?? "gcj02") else {
        throw SmartConfigurationError.invalid("coordinateType must match in both requests")
    }
    var backgroundValues: [Bool] = []
    for request in [high, low] {
        let common = request["common"] as? [String: Any?] ?? [:]
        let ios = request["ios"] as? [String: Any?] ?? [:]
        if let value = nonNull(common["intervalMs"]) {
            guard let number = value as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite,
                  number.doubleValue > 0, number.doubleValue.rounded(.towardZero) == number.doubleValue,
                  number.doubleValue <= Double(Int32.max) else {
                throw SmartConfigurationError.invalid("intervalMs")
            }
        }
        if let value = nonNull(ios["distanceFilter"]) {
            guard let number = value as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite,
                  number.doubleValue <= 0 else {
                throw SmartConfigurationError.invalid("Smart continuous tracking requires distanceFilter <= 0")
            }
        }
        if let supplied = nonNull(ios["allowsBackgroundLocationUpdates"]) {
            guard let number = supplied as? NSNumber,
                  CFGetTypeID(number) == CFBooleanGetTypeID() else {
                throw SmartConfigurationError.invalid("allowsBackgroundLocationUpdates")
            }
        }
        backgroundValues.append(ios["allowsBackgroundLocationUpdates"] as? Bool ?? false)
    }
    guard backgroundValues[0] == backgroundValues[1] else {
        throw SmartConfigurationError.invalid("allowsBackgroundLocationUpdates must match in both requests")
    }
}


// Motion-only freshness/chronology gate from Tracelet's LocationEngine pace sink.
// Raw SDK points still reach callers; a cached/duplicate fix cannot become a
// velocity derivation anchor after its pace evidence has been declined.
func isUsableSmartMotionFix(timestamp: TimeInterval, previousTimestamp: TimeInterval?,
                            now: TimeInterval) -> Bool {
    let age = now - timestamp
    return timestamp.isFinite && timestamp > 0 && now.isFinite && age >= 0 && age <= 10
        && (previousTimestamp == nil || timestamp > previousTimestamp!)
}

enum SmartConfigurationError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let key): return "Invalid smart tracking configuration: \(key)" }
    }
}

// Literal translation of the Rust coordinator's two inputs, transition deduplication
// and OR decision. The only stationary strategy exposed here is continuous Low.
final class SmartMotionCoordinator {
    enum Action { case none, high, low }
    private(set) var accelerometerMoving = false
    private(set) var speedMoving = true
    private(set) var currentMoving = true

    func onAccelerometer(_ moving: Bool) -> Action {
        guard accelerometerMoving != moving else { return .none }
        accelerometerMoving = moving
        return evaluate()
    }

    func onSpeed(_ moving: Bool, resolvedSpeed: Double? = nil, fixAge: TimeInterval? = nil) -> Action {
        // Tracelet's Swift wrapper #333/#404/#409: only a current, resolved
        // near-zero speed can override hand tremor; unknown/stale is not zero.
        var override: Action = .none
        if !moving, accelerometerMoving, let value = resolvedSpeed,
           value.isFinite, value >= 0, value <= 0.15,
           let age = fixAge, age.isFinite, age >= 0, age <= 10 {
            override = onAccelerometer(false)
        }
        guard speedMoving != moving else { return override }
        speedMoving = moving
        let action = evaluate()
        return action == .none ? override : action
    }

    private func evaluate() -> Action {
        let moving = accelerometerMoving || speedMoving
        guard moving != currentMoving else { return .none }
        currentMoving = moving
        return moving ? .high : .low
    }
}

// The thresholds, hysteresis, countdown, 3-fix SLOWING abort and confirmed wake
// below follow Tracelet's Swift SpeedMotionManager; timing uses system uptime.
final class SmartSpeedMotionManager {
    enum State: String { case moving, slowing, stationary }
    private(set) var state: State = .moving
    private(set) var lowSpeedCount = 0
    private(set) var wakeCount = 0
    private var highSpeedCount = 0
    private var slowingStart: TimeInterval = 0
    private var timer: DispatchWorkItem?
    private var running = false
    private let config: SmartTrackingConfiguration
    private let clock: () -> TimeInterval
    var onMotionChange: ((Bool, String) -> Void)?
    var onStateChange: ((State, State, String) -> Void)?

    init(config: SmartTrackingConfiguration,
         clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.config = config
        self.clock = clock
    }

    func start() {
        guard !running else { return }
        running = true
        state = .moving
        lowSpeedCount = 0; wakeCount = 0; highSpeedCount = 0
    }

    func stop() {
        running = false
        stopTimer()
    }

    func forceMoving() {
        guard running else { return }
        let previous = state
        state = .moving
        lowSpeedCount = 0; wakeCount = 0; highSpeedCount = 0
        stopTimer()
        commit(previous, "sensor wake")
        onMotionChange?(true, "sensor_wake")
    }

    func onLocation(speed: Double) {
        guard running, speed.isFinite else { return }
        let speed = max(0, speed)
        let now = clock()
        switch state {
        case .moving:
            if speed < config.speedMovingThreshold * 0.65 {
                let previous = state
                state = .slowing
                lowSpeedCount = 1; wakeCount = 0; highSpeedCount = 0
                slowingStart = now
                startTimer()
                commit(previous, "speed below stationary threshold")
            }
        case .slowing:
            if speed >= config.speedMovingThreshold {
                highSpeedCount += 1
                guard highSpeedCount >= 3 else { return }
                let previous = state
                state = .moving
                lowSpeedCount = 0; highSpeedCount = 0
                stopTimer()
                commit(previous, "three sustained high-speed fixes")
                return
            }
            highSpeedCount = 0
            lowSpeedCount += 1
            if now - slowingStart >= config.speedStationaryDelay {
                let previous = state
                state = .stationary
                wakeCount = 0
                stopTimer()
                onMotionChange?(false, "speed_stationary")
                commit(previous, "low-speed delay elapsed")
            }
        case .stationary:
            if speed >= config.speedMovingThreshold {
                wakeCount += 1
                if wakeCount >= config.speedWakeConfirmCount {
                    let previous = state
                    state = .moving
                    lowSpeedCount = 0; wakeCount = 0
                    onMotionChange?(true, "speed_wake")
                    commit(previous, "confirming high-speed fixes")
                }
            } else {
                wakeCount = 0
            }
        }
    }

    private func startTimer() {
        stopTimer()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.running, self.state == .slowing else { return }
            let previous = self.state
            self.state = .stationary
            self.wakeCount = 0; self.lowSpeedCount = 0
            self.onMotionChange?(false, "speed_stationary")
            self.commit(previous, "slowing countdown expired")
        }
        timer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + config.speedStationaryDelay, execute: item)
    }

    private func stopTimer() { timer?.cancel(); timer = nil }
    private func commit(_ previous: State, _ reason: String) {
        guard previous != state else { return }
        onStateChange?(previous, state, reason)
    }
}
