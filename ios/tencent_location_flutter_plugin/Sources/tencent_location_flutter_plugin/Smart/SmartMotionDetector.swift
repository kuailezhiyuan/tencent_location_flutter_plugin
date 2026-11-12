// Adapted from Ikolvi/Tracelet 071cd0be (Apache-2.0):
// sdk/ios/Sources/TraceletSDK/motion/MotionDetector.swift.
// Modified: remove unrelated safety/classification outputs and Tracelet dependencies;
// use detector-owned motion state as in Tracelet's Android MotionDetector.
import CoreMotion
import Foundation

final class SmartMotionDetector {
    private lazy var activityManager = CMMotionActivityManager()
    private lazy var pedometer = CMPedometer()
    private let motionManager = CMMotionManager()
    private let queue = DispatchQueue(label: "com.tencent.location.smart.motion", qos: .utility)
    private let stopTimeout: TimeInterval
    private let log: (String) -> Void
    private var sampler: DispatchSourceTimer?
    private var dutyCycle: DispatchSourceTimer?
    private var stopTimer: DispatchWorkItem?
    private var running = false
    private var fullMode = false
    private var reportedMoving = true
    private var consecutiveStillSamples = 0
    private var consecutiveMotionSamples = 0
    var onMotionChange: ((Bool) -> Void)?

    init(stopTimeout: TimeInterval, log: @escaping (String) -> Void) {
        self.stopTimeout = stopTimeout
        self.log = log
    }

    func start() {
        guard !running else { return }
        running = true
        reportedMoving = true
        let hasUsage = (Bundle.main.object(forInfoDictionaryKey: "NSMotionUsageDescription") as? String)?.isEmpty == false
        fullMode = hasUsage && CMMotionActivityManager.isActivityAvailable()
            && CMMotionActivityManager.authorizationStatus() == .authorized
        if fullMode {
            activityManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let self = self, self.running, let activity = activity else { return }
                if activity.stationary { self.startStopCountdown() }
                else if activity.walking || activity.running || activity.cycling || activity.automotive {
                    self.handleMovingDetected()
                }
            }
            if CMPedometer.isStepCountingAvailable() {
                pedometer.startUpdates(from: Date()) { [weak self] data, error in
                    DispatchQueue.main.async {
                        guard let self = self, self.running else { return }
                        if let error = error {
                            self.log("Pedometer update failed: \(error); stack=\(Thread.callStackSymbols.joined(separator: " | "))")
                            return
                        }
                        if data != nil, !self.reportedMoving { self.handleMovingDetected() }
                    }
                }
            }
        } else {
            log("Motion activity unavailable or not authorized; using raw accelerometer detection")
        }
        startMovingSampler()
    }

    func refreshAuthorization() {
        guard running, fullMode, CMMotionActivityManager.authorizationStatus() != .authorized else { return }
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
        fullMode = false
        log("Motion activity authorization changed; falling back to raw accelerometer detection")
        if reportedMoving { startMovingSampler() } else { startDutyCycle() }
    }

    func stop() {
        running = false
        if fullMode {
            activityManager.stopActivityUpdates()
            pedometer.stopUpdates()
            fullMode = false
        }
        stopMovingSampler()
        stopDutyCycle()
        stopTimer?.cancel(); stopTimer = nil
        motionManager.stopAccelerometerUpdates()
        consecutiveStillSamples = 0
        consecutiveMotionSamples = 0
    }

    func onManualPaceChange(_ moving: Bool) {
        reportedMoving = moving
        if moving {
            stopTimer?.cancel(); stopTimer = nil
            consecutiveStillSamples = 0
            if running { startMovingSampler() }
        } else {
            stopMovingSampler()
            if fullMode { motionManager.stopAccelerometerUpdates() }
            else { startDutyCycle() }
        }
    }

    private func startMovingSampler() {
        guard running, motionManager.isAccelerometerAvailable else { return }
        stopDutyCycle()
        consecutiveStillSamples = 0
        consecutiveMotionSamples = 0
        motionManager.accelerometerUpdateInterval = 0.1
        if !motionManager.isAccelerometerActive { motionManager.startAccelerometerUpdates() }
        sampler?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in
            guard let self = self, let data = self.motionManager.accelerometerData else { return }
            let acceleration = data.acceleration
            DispatchQueue.main.async { [weak self] in self?.handleAcceleration(acceleration) }
        }
        timer.resume()
        sampler = timer
    }

    private func stopMovingSampler() { sampler?.cancel(); sampler = nil }
    private func stopDutyCycle() { dutyCycle?.cancel(); dutyCycle = nil }

    private func startDutyCycle() {
        guard running, !fullMode, motionManager.isAccelerometerAvailable else { return }
        stopMovingSampler()
        dutyCycle?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 10, repeating: 10)
        timer.setEventHandler { [weak self] in self?.runDutyBurst() }
        timer.resume()
        dutyCycle = timer
    }

    private func runDutyBurst() {
        guard running, !reportedMoving else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        if !motionManager.isAccelerometerActive { motionManager.startAccelerometerUpdates() }
        sampleBurst(until: ProcessInfo.processInfo.systemUptime + 1.5)
    }

    private func sampleBurst(until deadline: TimeInterval) {
        guard running, !reportedMoving, ProcessInfo.processInfo.systemUptime < deadline else {
            if !reportedMoving { motionManager.stopAccelerometerUpdates() }
            return
        }
        if let data = motionManager.accelerometerData { handleAcceleration(data.acceleration) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.sampleBurst(until: deadline)
        }
    }

    // Tracelet's exact iOS defaults: 0.15g stillness, 50 samples at10Hz,
    // 5 sustained motion samples to abort, and 0.35g stationary shake wake.
    func handleAcceleration(_ acceleration: CMAcceleration) {
        guard running else { return }
        let magnitude = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y
            + acceleration.z * acceleration.z) - 1
        if reportedMoving {
            if abs(magnitude) < 0.15 {
                consecutiveMotionSamples = 0
                consecutiveStillSamples += 1
                if consecutiveStillSamples == 50 { startStopCountdown() }
            } else if consecutiveStillSamples >= 50 {
                consecutiveMotionSamples += 1
                if consecutiveMotionSamples >= 5 {
                    consecutiveStillSamples = 0
                    consecutiveMotionSamples = 0
                    handleMovingDetected()
                }
            } else {
                consecutiveStillSamples = 0
            }
        } else if abs(magnitude) > 0.35 {
            stopDutyCycle()
            handleMovingDetected()
        }
    }

    private func handleMovingDetected() {
        stopTimer?.cancel(); stopTimer = nil
        if !reportedMoving { triggerMotionChange(true) }
        else if running { startMovingSampler() }
    }

    private func startStopCountdown() {
        guard running, reportedMoving, stopTimer == nil else { return }
        if stopTimeout <= 0 { triggerMotionChange(false); return }
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.running else { return }
            self.stopTimer = nil
            self.triggerMotionChange(false)
        }
        stopTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + stopTimeout, execute: item)
    }

    private func triggerMotionChange(_ moving: Bool) {
        guard running, reportedMoving != moving else { return }
        reportedMoving = moving
        onMotionChange?(moving)
        guard running else { return }
        if moving { startMovingSampler() }
        else {
            stopMovingSampler()
            if fullMode { motionManager.stopAccelerometerUpdates() }
            else { startDutyCycle() }
        }
    }
}
