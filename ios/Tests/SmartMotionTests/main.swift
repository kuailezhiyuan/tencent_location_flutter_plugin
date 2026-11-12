// Run without Tencent credentials or simulator hardware:
// swiftc SmartMotionLogic.swift ios/Tests/SmartMotionTests/main.swift -o /tmp/tencent-smart-motion-tests
import Foundation

func configuration(_ overrides: [String: Any] = [:]) throws -> SmartTrackingConfiguration {
    try SmartTrackingConfiguration(overrides)
}

var checks = 0
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
    checks += 1
}

let coordinator = SmartMotionCoordinator()
check(coordinator.onAccelerometer(true) == .none, "initial moving must not duplicate a transition")
check(coordinator.onAccelerometer(false) == .none, "stationary accel must not override moving speed")
check(coordinator.onSpeed(false) == .low, "both stationary must lower accuracy")
check(coordinator.onSpeed(false) == .none, "duplicate input must not switch twice")
check(coordinator.onAccelerometer(true) == .high, "a walk must wake without the speed threshold")
check(coordinator.onAccelerometer(false) == .low, "speed remains stationary after the sensor settles")
check(coordinator.onSpeed(true) == .high, "speed-only movement must wake a smooth train")

for age: TimeInterval in [-1, 11] {
    let stale = SmartMotionCoordinator()
    _ = stale.onAccelerometer(true)
    check(stale.onSpeed(false, resolvedSpeed: 0, fixAge: age) == .none,
          "stale/future speed must not overrule the moving sensor")
    check(stale.accelerometerMoving, "invalid-age tremor override must retain acceleration input")
}
let unknown = SmartMotionCoordinator()
_ = unknown.onAccelerometer(true)
check(unknown.onSpeed(false, resolvedSpeed: nil, fixAge: 0) == .none, "unknown speed is not stationary")
let tremor = SmartMotionCoordinator()
_ = tremor.onAccelerometer(true)
check(tremor.onSpeed(false, resolvedSpeed: 0.1, fixAge: 1) == .low, "current near-zero speed overrides hand tremor")
let slowWalk = SmartMotionCoordinator()
_ = slowWalk.onAccelerometer(true)
check(slowWalk.onSpeed(false, resolvedSpeed: 0.5, fixAge: 1) == .none, "slow walking must trust the moving sensor")

check(isUsableSmartMotionFix(timestamp: 100, previousTimestamp: nil, now: 109), "a9-second-old firstfix can seed motion")
check(!isUsableSmartMotionFix(timestamp: 100, previousTimestamp: nil, now: 111), "stale firstfix cannot seed motion")
check(!isUsableSmartMotionFix(timestamp: 110, previousTimestamp: nil, now: 109), "future firstfix cannot seed motion")
check(!isUsableSmartMotionFix(timestamp: 100, previousTimestamp: 100, now: 100), "duplicate fix must not reset speedanchor")
check(!isUsableSmartMotionFix(timestamp: 99, previousTimestamp: 100, now: 100), "out-of-order fix must not replace speedanchor")
check(isUsableSmartMotionFix(timestamp: 101, previousTimestamp: 100, now: 101), "newcurrent fix advances speedanchor")
check(!isUsableSmartMotionFix(timestamp: .nan, previousTimestamp: nil, now: 101), "invalid timestamp rejected")

// Captured from jsonEncode(TencentLocationRequest.create().toMap()).
// JSON null crosses Flutter's codec as NSNull, including distanceFilter.
let defaultRequestJSON = #"{"common":{"intervalMs":5000,"coordinateType":"gcj02","requestLevel":"adminArea","allowDirectionSensor":false},"android":{"locMode":"highAccuracy","gnssSource":"gpsFirst","allowGps":true,"allowBle":true,"allowCache":false,"gpsFirst":false,"gpsFirstTimeoutMs":5000,"firstLocationTimeoutMs":15000,"firstLocationNeedAddress":false,"indoorMode":false,"scene":null,"smallAppKey":"","qq":"","phoneNumber":"","reGeoCodingKey":null},"ios":{"desiredAccuracy":"best","allowsBackgroundLocationUpdates":false,"distanceFilter":null,"pausesLocationUpdatesAutomatically":true,"activityType":"other","headingFilter":null,"headingOrientation":null,"poiUpdateIntervalS":10,"singleLocationTimeoutMs":10000},"harmony":{"userActivityScenario":null,"powerConsumptionScenario":"high","locatingPriority":"locatingSpeed","innerIntervalS":1,"reverseGeocodeRequestIntervalS":10,"firstLocationCachePolicyS":-1,"singleLocationTimeoutS":10}}"#
let defaultRequest = try JSONSerialization.jsonObject(with: Data(defaultRequestJSON.utf8)) as! [String: Any?]
try validateSmartLocationRequests(high: defaultRequest, low: defaultRequest)
check(true, "the default serialized Dart request must accept its optional null fields")
let nullRequest: [String: Any?] = ["common": ["intervalMs": NSNull(), "coordinateType": NSNull()],
                                 "ios": ["distanceFilter": NSNull(), "allowsBackgroundLocationUpdates": NSNull()]]
try validateSmartLocationRequests(high: nullRequest, low: nullRequest)
check(true, "optional null interval/background fields must use RequestCodec defaults")
for invalidRequest: [String: Any?] in [
    ["common": ["intervalMs": 0]], ["common": ["intervalMs": true]],
    ["ios": ["distanceFilter": 10]], ["ios": ["distanceFilter": true]],
    ["ios": ["allowsBackgroundLocationUpdates": 1]]
] {
    do {
        try validateSmartLocationRequests(high: invalidRequest, low: invalidRequest)
        preconditionFailure("invalid native request accepted: \(invalidRequest)")
    } catch {
        check(error is SmartConfigurationError, "invalid request must produce a useful error")
    }
}

var now: TimeInterval = 0
let config = try configuration()
let manager = SmartSpeedMotionManager(config: config, clock: { now })
var changes: [Bool] = []
manager.onMotionChange = { moving, _ in changes.append(moving) }
manager.start()
manager.onLocation(speed: 3.4)
check(manager.state == .moving, "hysteresis: 3.4 must remain moving for a5m/s wake threshold")
manager.onLocation(speed: 3.2)
check(manager.state == .slowing, "5 *0.65 is the lowering threshold")
manager.onLocation(speed: 6); manager.onLocation(speed: 6)
check(manager.state == .slowing, "two drift spikes must not abort the countdown")
manager.onLocation(speed: 0)
manager.onLocation(speed: 6); manager.onLocation(speed: 6)
check(manager.state == .slowing, "a low-speed fix must reset a partial high-speed streak")
manager.onLocation(speed: 6)
check(manager.state == .moving, "three sustained high-speed fixes must abort slowing")
manager.onLocation(speed: 0)
now = 89
manager.onLocation(speed: 0)
check(manager.state == .slowing, "must wait the configured delay")
now = 90
manager.onLocation(speed: 0)
check(manager.state == .stationary && changes == [false], "90 seconds of low speed must declare stationary once")
manager.onLocation(speed: 6); manager.onLocation(speed: 6)
check(manager.state == .stationary, "two above-threshold fixes must not wake")
manager.onLocation(speed: 0)
manager.onLocation(speed: 6); manager.onLocation(speed: 6)
check(manager.state == .stationary, "a low fix must reset wake confirmation")
manager.onLocation(speed: 6)
check(manager.state == .moving && changes == [false, true], "three confirming fixes must wake exactly once")
manager.stop()

let quick = try configuration(["speedStationaryDelayMs": 10])
let stopped = SmartSpeedMotionManager(config: quick)
var stoppedCallbacks = 0
stopped.onMotionChange = { _, _ in stoppedCallbacks += 1 }
stopped.start(); stopped.onLocation(speed: 0); stopped.stop()
RunLoop.main.run(until: Date().addingTimeInterval(0.03))
check(stoppedCallbacks == 0, "a stopped countdown must not resurrect a session")

let timer = SmartSpeedMotionManager(config: quick)
var timerCallbacks: [Bool] = []
timer.onMotionChange = { moving, _ in timerCallbacks.append(moving) }
timer.start(); timer.onLocation(speed: 0)
RunLoop.main.run(until: Date().addingTimeInterval(0.03))
check(timer.state == .stationary && timerCallbacks == [false], "countdown must settle without a new position fix")
timer.stop()

for invalid: [String: Any] in [["speedWakeConfirmCount": 0], ["speedWakeConfirmCount": 1.5],
                              ["speedMovingThreshold": Double.nan], ["stopTimeoutMs": -1],
                              ["speedStationaryDelayMs": true], ["stopTimeoutMs": 1e100]] {
    do {
        _ = try configuration(invalid)
        preconditionFailure("invalid native input accepted: \(invalid)")
    } catch {
        check(error is SmartConfigurationError, "invalid config must produce a useful error")
    }
}
print("Smart motion tests passed: \(checks) assertions")
