// Smart coordination adapted from Ikolvi/Tracelet 071cd0be (Apache-2.0),
// sdk/ios/Sources/TraceletSDK/SmartMotionCoordinator.swift and location/LocationEngine.swift.
// Modified: TencentLBS is the only location provider; no Rust or Flutter engine is used.
import CoreLocation
import Flutter
import Foundation
import TencentLBS
import UIKit

final class SmartTrackingSession: NSObject, TencentLBSLocationManagerDelegate {
    static let shared = SmartTrackingSession()
    private(set) var enabled = false
    private var moving = true
    private var coordinator = SmartMotionCoordinator()
    private var speed: SmartSpeedMotionManager?
    private var motion: SmartMotionDetector?
    private var manager: TencentLBSLocationManager?
    private var movingRequest: [String: Any?] = [:]
    private var stationaryRequest: [String: Any?] = [:]
    private var requestSnapshot: RequestCodec.CommonConfig?
    private var motionLocation: CLLocation?
    private var lastLocation: [String: Any?]?
    private var effectiveSpeed: Double?
    private var speedSource = "unknown"
    private var locationCount = 0
    private var reason = "stopped"
    private weak var dispatcher: EventDispatcher?
    private let diagnostics = SmartTrackingLog()
    private var activationObserver: NSObjectProtocol?

    private override init() {
        super.init()
        activationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self, self.enabled else { return }
            self.motion?.refreshAuthorization()
        }
    }

    func attach(_ dispatcher: EventDispatcher) { self.dispatcher = dispatcher }

    func state() -> [String: Any?] {
        ["enabled": enabled, "isMoving": moving,
         "accelerometerMoving": coordinator.accelerometerMoving,
         "speedMoving": coordinator.speedMoving,
         "speedState": speed?.state.rawValue ?? "moving", "pace": moving ? "high" : "low",
         "wakeLockHeld": false, "hasSignificantMotionSensor": false,
         "reason": reason, "timestampMs": Int(Date().timeIntervalSince1970 * 1000),
         "locationCount": locationCount, "lastLocation": lastLocation?.compactMapValues { $0 },
         "lastFixAtMs": lastLocation?["time"] ?? nil,
         "motionFixAtMs": motionLocation.map { Int($0.timestamp.timeIntervalSince1970 * 1000) },
         "rawSpeedMps": motionLocation.map { $0.speed },
         "nativeDesiredAccuracy": manager.map { $0.desiredAccuracy },
         "speedMps": effectiveSpeed, "speedSource": speedSource]
    }

    func start(arguments: [String: Any], sdkConfig: SdkConfig,
               ordinaryContinuousActive: Bool) throws {
        guard !enabled, !ordinaryContinuousActive else {
            throw SmartStartError(code: Errors.alreadyStarted, message: "A continuous location session is already active")
        }
        guard TencentLBSLocationManager.getUserAgreePrivacy() else {
            throw SmartStartError(code: Errors.privacyNotAgreed, message: "Tencent location privacy consent is required")
        }
        guard let key = sdkConfig.iosApiKey, !key.isEmpty else {
            throw SmartStartError(code: Errors.apiKeyInvalid, message: "Initialize the Tencent iOS API key first")
        }
        guard let high = arguments["movingRequest"] as? [String: Any?],
              let low = arguments["stationaryRequest"] as? [String: Any?] else {
            throw SmartConfigurationError.invalid("movingRequest/stationaryRequest")
        }
        if let supplied = arguments["config"], !(supplied is [String: Any]) {
            throw SmartConfigurationError.invalid("config")
        }
        let config = try SmartTrackingConfiguration(arguments["config"] as? [String: Any] ?? [:])
        try validateSmartLocationRequests(high: high, low: low)
        let optional: TencentLBSLocationManager? = TencentLBSLocationManager()
        guard let manager = optional else {
            throw SmartStartError(code: Errors.sdkInitFailed, message: "Tencent location manager initialization failed")
        }
        let background = ((high["ios"] as? [String: Any?])?["allowsBackgroundLocationUpdates"] as? Bool) ?? false
        let authorization = manager.authorizationStatus
        guard authorization == .authorizedAlways || (!background && authorization == .authorizedWhenInUse) else {
            throw SmartStartError(code: Errors.permissionDenied,
                                  message: background ? "Always location permission is required for background Smart tracking" : "Location permission is required")
        }
        if background {
            let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
            guard modes.contains("location") else { throw SmartConfigurationError.invalid("UIBackgroundModes.location") }
        }
        sdkConfig.apply(to: manager)
        movingRequest = high; stationaryRequest = low
        self.manager = manager
        manager.delegate = self
        coordinator = SmartMotionCoordinator()
        moving = true; locationCount = 0; motionLocation = nil; lastLocation = nil
        effectiveSpeed = nil; speedSource = "unknown"
        let speedManager = SmartSpeedMotionManager(config: config)
        speed = speedManager
        let detector = SmartMotionDetector(stopTimeout: config.stopTimeout) { [weak self] message in
            self?.record("sensor", message: message)
        }
        motion = detector
        detector.onMotionChange = { [weak self] moving in
            guard let self = self, self.enabled else { return }
            // Mirrors TraceletSdk's sensor wake: only a genuine coordinator wake
            // forces the speed machine, so a slow walk need not clear 5m/s.
            let action = self.coordinator.onAccelerometer(moving)
            self.apply(action, reason: moving ? "sensor_wake" : "sensor_stationary")
            if action == .high { self.speed?.forceMoving() }
            self.emitState(reason: moving ? "sensor_wake" : "sensor_stationary")
        }
        speedManager.onMotionChange = { [weak self] moving, reason in
            guard let self = self, self.enabled else { return }
            let age = self.motionLocation.map { -$0.timestamp.timeIntervalSinceNow }
            self.apply(self.coordinator.onSpeed(moving, resolvedSpeed: self.effectiveSpeed, fixAge: age), reason: reason)
            self.emitState(reason: reason)
        }
        speedManager.onStateChange = { [weak self] previous, current, reason in
            guard let self = self, self.enabled else { return }
            self.record("speed_state", message: "\(previous.rawValue) -> \(current.rawValue): \(reason)")
            self.emitState(reason: "speed_\(current.rawValue)")
        }
        requestSnapshot = RequestCodec.apply(high, to: manager)
        applySuspensionGuard(to: manager)
        enabled = true
        speedManager.start()
        // Initial acceleration ownership is moving, matching Tracelet start().
        _ = coordinator.onAccelerometer(true)
        detector.start()
        manager.startUpdatingLocation()
        emitState(reason: "start")
    }

    func stop(reason: String = "stop") {
        enabled = false
        speed?.stop(); motion?.stop()
        manager?.stopUpdatingLocation()
        manager?.delegate = nil
        manager = nil; motion = nil
        motionLocation = nil
        emitState(reason: reason)
    }

    func getLog() throws -> String {
        var snapshot = state()
        snapshot.removeValue(forKey: "lastLocation")
        diagnostics.append(type: "snapshot", values: snapshot)
        return try diagnostics.read()
    }
    func clearLog() throws { try diagnostics.clear() }

    private func apply(_ action: SmartMotionCoordinator.Action, reason: String) {
        guard enabled, action != .none, let manager = manager else { return }
        let nextMoving = action == .high
        let request = nextMoving ? movingRequest : stationaryRequest
        let common = request["common"] as? [String: Any?] ?? [:]
        let nextInterval = (common["intervalMs"] as? Int) ?? 5000
        let restartForInterval = requestSnapshot?.intervalMs != nextInterval
        if restartForInterval {
            record("request_restart", message: "Tencent callback interval changed; restarting Tencent continuous updates")
            manager.stopUpdatingLocation()
        }
        requestSnapshot = RequestCodec.apply(request, to: manager, applyCoordinateType: false)
        applySuspensionGuard(to: manager)
        if restartForInterval { manager.startUpdatingLocation() }
        moving = nextMoving
        motion?.onManualPaceChange(nextMoving)
        emitState(reason: reason)
    }

    private func applySuspensionGuard(to manager: TencentLBSLocationManager) {
        manager.pausesLocationUpdatesAutomatically = false
        // Tracelet LocationEngine #435: Always/no-indicator background tracking
        // keeps native accuracy at least100m and removes the OS distance gate.
        if manager.authorizationStatus == .authorizedAlways {
            if manager.desiredAccuracy > kCLLocationAccuracyHundredMeters {
                manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            }
            manager.distanceFilter = kCLDistanceFilterNone
        }
    }

    func tencentLBSLocationManager(_ manager: TencentLBSLocationManager,
                                 didUpdate location: TencentLBSLocation) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.tencentLBSLocationManager(manager, didUpdate: location) }
            return
        }
        guard enabled, manager === self.manager else { return }
        motion?.refreshAuthorization()
        let fix = location.location
        let timestamp = fix.timestamp.timeIntervalSince1970
        guard CLLocationCoordinate2DIsValid(fix.coordinate), fix.horizontalAccuracy.isFinite,
              fix.horizontalAccuracy >= 0, timestamp.isFinite, timestamp > 0,
              timestamp < TimeInterval(Int64.max) / 1000 else {
            record("invalid_location", message: "Tencent returned invalid coordinates, timestamp or accuracy")
            return
        }
        let coordinate = requestSnapshot?.coordinateType ?? .GCJ02
        lastLocation = LocationCodec.toMap(location, coordinateType: coordinate)
        locationCount += 1
        if isUsableSmartMotionFix(timestamp: timestamp,
                                  previousTimestamp: motionLocation?.timestamp.timeIntervalSince1970,
                                  now: Date().timeIntervalSince1970) {
            if fix.speed.isFinite, fix.speed > 0 {
                effectiveSpeed = fix.speed; speedSource = "platform"
            } else if let previous = motionLocation {
                effectiveSpeed = fix.distance(from: previous) / fix.timestamp.timeIntervalSince(previous.timestamp)
                speedSource = "position_delta"
            } else {
                // Tracelet startup anchor #385 never derives against a prior session.
                effectiveSpeed = 0; speedSource = "unknown"
            }
            motionLocation = fix
            if let speed = effectiveSpeed { self.speed?.onLocation(speed: speed) }
        }
        dispatcher?.sendSmart(type: "smartLocation", data: lastLocation ?? [:])
    }

    func tencentLBSLocationManager(_ manager: TencentLBSLocationManager, didFailWithError error: Error) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.tencentLBSLocationManager(manager, didFailWithError: error) }
            return
        }
        guard enabled, manager === self.manager else { return }
        record("location_error", message: "Tencent location failed: \(error); stack=\(Thread.callStackSymbols.joined(separator: " | "))")
        emitState(reason: "location_error")
    }

    func tencentLBSLocationManager(_ manager: TencentLBSLocationManager,
                                 didChangeAuthorization status: CLAuthorizationStatus) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.tencentLBSLocationManager(manager, didChangeAuthorization: status) }
            return
        }
        guard enabled, manager === self.manager else { return }
        if status == .denied || status == .restricted ||
            (requestSnapshot?.allowsBackgroundLocationUpdates == true && status != .authorizedAlways) {
            stop(reason: "location_permission_revoked")
        }
    }

    func tencentLBSDidChangeAuthorization(_ manager: TencentLBSLocationManager) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.tencentLBSDidChangeAuthorization(manager) }
            return
        }
        guard manager === self.manager else { return }
        tencentLBSLocationManager(manager, didChangeAuthorization: manager.authorizationStatus)
    }

    private func emitState(reason: String) {
        self.reason = reason
        let value = state()
        var diagnostic = value
        diagnostic.removeValue(forKey: "lastLocation")
        diagnostics.append(type: "state", values: diagnostic)
        dispatcher?.sendSmart(type: "smartState", data: value)
    }

    private func record(_ type: String, message: String) {
        diagnostics.append(type: type, values: ["message": message])
    }
}

struct SmartStartError: LocalizedError {
    let code: String
    let message: String
    var errorDescription: String? { message }
}

final class SmartTrackingLog {
    private let url = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Application Support/tencent-smart/diagnostics.jsonl")
    private let limit = 1_048_576

    func append(type: String, values: [String: Any?]) {
        do {
            var row = values.compactMapValues { $0 }
            row["type"] = type
            row["timestampMs"] = Int(Date().timeIntervalSince1970 * 1000)
            let line = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) + Data([10])
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            var existing = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : Data()
            if existing.count + line.count > limit {
                existing = Data(existing.suffix(limit / 2))
                if let newline = existing.firstIndex(of: 10) { existing.removeSubrange(...newline) }
            }
            existing.append(line)
            try existing.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            NSLog("Smart tracking diagnostic append failed: %@; stack=%@", String(describing: error), Thread.callStackSymbols.joined(separator: " | "))
        }
    }

    func read() throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
