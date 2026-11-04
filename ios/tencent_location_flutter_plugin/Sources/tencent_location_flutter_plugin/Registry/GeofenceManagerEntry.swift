import CoreLocation
import Flutter
import TencentLBS

/// 一个 Flutter 端 ``TencentGeofenceManager`` 实例在 iOS 端的落地。
///
/// 持有独立的 ``TencentLBSGeofenceManager`` 实例与 delegate 转发。
final class GeofenceManagerEntry: NSObject, TencentLBSGeofenceManagerDelegate {

    /// 行政区围栏待应用配置。
    ///
    /// 行政区围栏由 SDK 通过关键字异步创建，无法在创建前把
    /// ``activeAction`` / ``stayedDuration`` / ``userInfo`` 设到 region 上。
    /// 调用方先把这三个值缓存在这里，待 ``didCreateDistrictRegion`` 回调
    /// 拿到 region 后再统一应用；``identifier`` 用于创建完成事件透传。
    struct PendingDistrictConfig {
        let identifier: String
        let activeAction: TencentLBSGeofenceActiveAction
        let stayedDuration: TimeInterval?
        let userInfo: [String: Any]?
    }

    let managerId: String
    let geofenceManager: TencentLBSGeofenceManager
    private let dispatcher: EventDispatcher

    /// keyword → 待应用配置。一个 keyword 可能匹配到多个行政区
    /// （SDK 会为每个匹配项依次回调），因此成功回调里**不删除**对应项；
    /// 失败回调（region == nil）才把该 keyword 的 pending config 移除。
    private var pendingDistrictConfigs: [String: PendingDistrictConfig] = [:]

    init(managerId: String, dispatcher: EventDispatcher) {
        self.managerId = managerId
        self.geofenceManager = TencentLBSGeofenceManager()
        self.dispatcher = dispatcher
        super.init()
        self.geofenceManager.delegate = self
    }

    deinit {
        geofenceManager.delegate = nil
        geofenceManager.removeAllGeofences()
    }

    // MARK: - 行政区围栏 pending 配置维护

    /// 调用 ``addDistrictGeofence(withKeyword:identifier:)`` **之前**调用，
    /// 写入待应用配置；同 keyword 重复 add 会覆盖。
    func setPendingDistrictConfig(_ config: PendingDistrictConfig, forKeyword keyword: String) {
        pendingDistrictConfigs[keyword] = config
    }

    /// 清空所有 pending 配置（``removeAllGeofences`` / dispose 时调用）。
    func clearPendingDistrictConfigs() {
        pendingDistrictConfigs.removeAll()
    }

    // MARK: - TencentLBSGeofenceManagerDelegate

    func tencentLBSGeofenceManager(_ manager: TencentLBSGeofenceManager,
                                   didEnter region: TencentLBSGeofenceRegion) {
        sendEvent(transition: "enter", region: region, duration: nil)
    }

    func tencentLBSGeofenceManager(_ manager: TencentLBSGeofenceManager,
                                   didExitRegion region: TencentLBSGeofenceRegion) {
        sendEvent(transition: "exit", region: region, duration: nil)
    }

    func tencentLBSGeofenceManager(_ manager: TencentLBSGeofenceManager,
                                   didStayIn region: TencentLBSGeofenceRegion,
                                   forDuration duration: TimeInterval) {
        sendEvent(transition: "dwell", region: region, duration: duration)
    }

    func tencentLBSGeofenceManager(_ manager: TencentLBSGeofenceManager,
                                   didFailWithError error: Error,
                                   for region: TencentLBSGeofenceRegion?) {
        let nsError = error as NSError
        let code = mapGeofenceErrorCode(nsError.code)
        var payload: [String: Any?] = [
            "code": code,
            "message": nsError.localizedDescription,
            "nativeCode": nsError.code,
            "nativeMessage": nsError.localizedDescription,
        ]
        if let id = region?.identifier {
            payload["details"] = ["geofenceId": id]
        }
        dispatcher.sendGeofence(event: "onGeofenceError",
                                geofenceManagerId: managerId, payload: payload)
    }

    /// 行政区围栏异步创建完成回调。
    ///
    /// - 成功（region != nil）：把 pending config 中的 activeAction /
    ///   stayedDuration / userInfo 应用到 region 上。同一 keyword 可能匹配
    ///   多个行政区，SDK 会多次回调，因此**不在此处删除** pending config。
    /// - 失败（region == nil）：删除该 keyword 的 pending config，并把错误
    ///   通过 ``onGeofenceError`` 转发到 Flutter 侧。
    func tencentLBSGeofenceManager(_ manager: TencentLBSGeofenceManager,
                                   didCreateDistrictRegion region: TencentLBSGeofenceDistrictRegion?,
                                   forKeyword keyword: String,
                                   error: Error?) {
        if let region = region {
            if let config = pendingDistrictConfigs[keyword] {
                GeofenceCodec.applyCommonProperties(
                    region,
                    activeAction: config.activeAction,
                    stayed: config.stayedDuration,
                    userInfo: config.userInfo)
                // district 异步创建完成：透传 onGeofenceCreated。
                // 同一 keyword 可能匹配多个行政区，SDK 会多次回调，每次都是
                // 一个真实创建成功的事件，因此每个回调都发。
                let payload: [String: Any?] = [
                    "geofenceId": config.identifier,
                    "userInfo": config.userInfo,
                ]
                dispatcher.sendGeofence(event: "onGeofenceCreated",
                                        geofenceManagerId: managerId, payload: payload)
            }
            return
        }

        // 失败分支：清掉 pending、转发错误事件。
        pendingDistrictConfigs.removeValue(forKey: keyword)
        guard let error = error as NSError? else { return }
        let payload: [String: Any?] = [
            "code": mapGeofenceErrorCode(error.code),
            "message": error.localizedDescription,
            "nativeCode": error.code,
            "nativeMessage": error.localizedDescription,
            "details": ["districtKeyword": keyword],
        ]
        dispatcher.sendGeofence(event: "onGeofenceError",
                                geofenceManagerId: managerId, payload: payload)
    }

    // MARK: - helpers

    private func sendEvent(transition: String,
                           region: TencentLBSGeofenceRegion,
                           duration: TimeInterval?) {
        var payload: [String: Any?] = [
            "geofenceId": region.identifier,
            "transition": transition,
            "userInfo": region.userInfo as? [String: Any],
        ]
        if let duration = duration {
            payload["stayedDurationMs"] = Int(duration * 1000.0)
        }
        dispatcher.sendGeofence(event: "onGeofenceEvent",
                                geofenceManagerId: managerId, payload: payload)
    }

    /// 把 ``TencentLBSGeofenceError`` 映射成 Flutter 侧错误 wireName。
    private func mapGeofenceErrorCode(_ raw: Int) -> String {
        switch raw {
        case 1: // InvalidParameter
            return Errors.geofenceInvalidRegion
        case 2: // LocationNotAvailable
            return Errors.locationFailed
        case 3: // Denied
            return Errors.permissionDenied
        case 4: // Duplicate
            return Errors.geofenceDuplicateId
        case 5: // NetworkFailed
            return Errors.geofenceNetworkFailed
        case 6: // DistrictNotFound
            return Errors.geofenceDistrictNotFound
        case 7: // DistrictDataInvalid
            return Errors.geofenceInvalidRegion
        default:
            return Errors.nativeError
        }
    }
}
