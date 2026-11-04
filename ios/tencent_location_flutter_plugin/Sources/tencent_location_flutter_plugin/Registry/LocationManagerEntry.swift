import CoreLocation
import Flutter
import TencentLBS

/// 一个 Flutter 端 ``TencentLocationManager`` 实例在 iOS 端的落地。
///
/// 持有独立的原生 ``TencentLBSLocationManager`` 实例与 delegate 转发；
/// 定位 / 朝向回调通过 ``EventDispatcher`` 以 ``managerId`` 路由回 Flutter。
final class LocationManagerEntry: NSObject, TencentLBSLocationManagerDelegate {

    let managerId: String
    let locationManager: TencentLBSLocationManager
    private let dispatcher: EventDispatcher

    private var coordinateType: TencentLBSLocationCoordinateType = .GCJ02
    private var continuousRunning = false

    /// 单次定位的 completion；若同一 manager 已有等待中的单次定位则后续会被拒绝。
    private var singleCompletion: ((TencentLBSLocation?, Error?) -> Void)?

    /// 当前 manager 的朝向原生监听是否已启动。
    private var headingActive = false

    init?(managerId: String, dispatcher: EventDispatcher) {
        // 原生 manager init 在未同意隐私协议时返回 nil，
        // Swift 看 ObjC 非空标注，这里通过 Optional 强转处理。
        let optional: TencentLBSLocationManager? = TencentLBSLocationManager()
        guard let manager = optional else { return nil }
        self.managerId = managerId
        self.locationManager = manager
        self.dispatcher = dispatcher
        super.init()
        self.locationManager.delegate = self
    }

    deinit {
        stopContinuous()
        stopHeading()
        locationManager.delegate = nil
    }

    // MARK: - 连续定位

    func startContinuous() {
        if continuousRunning { return }
        continuousRunning = true
        locationManager.startUpdatingLocation()
    }

    func stopContinuous() {
        if !continuousRunning { return }
        continuousRunning = false
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 单次定位

    func startSingle(timeoutMs: Int,
                     level: TencentLBSRequestLevel,
                     completion: @escaping (TencentLBSLocation?, Error?) -> Void) -> Bool {
        if singleCompletion != nil {
            return false
        }
        singleCompletion = completion
        let timeout = TimeInterval(timeoutMs) / 1000.0
        let started = locationManager.requestLocation(
            with: level, locationTimeout: timeout) { [weak self] location, error in
            guard let self = self else { return }
            let completion = self.singleCompletion
            self.singleCompletion = nil
            completion?(location, error)
        }
        if !started {
            singleCompletion = nil
        }
        return started
    }

    // MARK: - 朝向

    func startHeading() {
        if headingActive { return }
        headingActive = true
        locationManager.startUpdatingHeading()
    }

    func stopHeading() {
        if !headingActive { return }
        headingActive = false
        locationManager.stopUpdatingHeading()
    }

    func dismissHeadingCalibrationDisplay() {
        locationManager.dismissHeadingCalibrationDisplay()
    }

    // MARK: - 配置

    func updateCoordinateType(_ type: TencentLBSLocationCoordinateType) {
        coordinateType = type
    }

    // MARK: - TencentLBSLocationManagerDelegate

    func tencentLBSLocationManager(_ manager: TencentLBSLocationManager,
                                   didUpdate location: TencentLBSLocation) {
        // 单次定位的回调由 requestLocation: completion 处理；这里只处理连续定位。
        if !continuousRunning { return }
        let payload = LocationCodec.toMap(location, coordinateType: coordinateType)
        dispatcher.sendLocation(event: "onLocationChanged",
                                managerId: managerId, payload: payload)
    }

    func tencentLBSLocationManager(_ manager: TencentLBSLocationManager,
                                   didUpdate newHeading: CLHeading) {
        guard headingActive else { return }
        let payload = OrientationCodec.toMap(newHeading)
        dispatcher.sendStatus(event: "onOrientationChanged",
                              managerId: managerId, payload: payload)
    }

    func tencentLBSLocationManager(_ manager: TencentLBSLocationManager,
                                   didFailWithError error: Error) {
        let nsError = error as NSError
        let payload: [String: Any?] = [
            "code": Errors.locationFailed,
            "message": nsError.localizedDescription,
            "nativeCode": nsError.code,
            "nativeMessage": nsError.localizedDescription,
        ]
        dispatcher.sendLocation(event: "onLocationError",
                                managerId: managerId, payload: payload)
    }
}
