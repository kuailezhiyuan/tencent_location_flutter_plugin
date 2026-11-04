import CoreLocation
import TencentLBS

/// 在 Flutter 侧的 Map 与原生 ``TencentLBSLocationManager`` 配置项之间转换。
///
/// 仅读 `common` + `ios` 两段；调用方需要把 Map 应用到一个具体的 manager 上。
enum RequestCodec {

    struct CommonConfig {
        let coordinateType: TencentLBSLocationCoordinateType
        let requestLevel: TencentLBSRequestLevel
        let allowsBackgroundLocationUpdates: Bool
        let intervalMs: Int
        let singleLocationTimeoutMs: Int
    }

    /// 把 Flutter 下发的 request map 应用到 manager 上，并返回 common 段的快照。
    @discardableResult
    static func apply(_ map: [String: Any?],
                      to manager: TencentLBSLocationManager) -> CommonConfig {
        let common = (map["common"] as? [String: Any?]) ?? [:]
        let ios = (map["ios"] as? [String: Any?]) ?? [:]

        // ---------- common ----------
        let coordinateType = EnumCodecs.coordinateTypeFromWire(
            common["coordinateType"] as? String)
        let requestLevel = EnumCodecs.requestLevelFromWire(
            common["requestLevel"] as? String)
        manager.coordinateType = coordinateType
        manager.requestLevel = requestLevel
        let intervalMs = (common["intervalMs"] as? Int) ?? 5000

        // ---------- ios ----------
        manager.desiredAccuracy = EnumCodecs.desiredAccuracyFromWire(
            ios["desiredAccuracy"] as? String)
        let allowsBackgroundLocationUpdates =
            (ios["allowsBackgroundLocationUpdates"] as? Bool) ?? false
        manager.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates
        if let distanceFilter = ios["distanceFilter"] as? Double {
            manager.distanceFilter = distanceFilter
        } else {
            manager.distanceFilter = kCLDistanceFilterNone
        }
        if let pause = ios["pausesLocationUpdatesAutomatically"] as? Bool {
            manager.pausesLocationUpdatesAutomatically = pause
        }
        manager.activityType = EnumCodecs.activityTypeFromWire(
            ios["activityType"] as? String)
        if let headingFilter = ios["headingFilter"] as? Double {
            manager.headingFilter = headingFilter
        }
        if let headingOrientation = ios["headingOrientation"] as? Int,
           let orientation = CLDeviceOrientation(rawValue: Int32(headingOrientation)) {
            manager.headingOrientation = orientation
        }
        // 连续定位回调间隔（来自通用段 `intervalMs`）。
        if intervalMs > 0 {
            manager.locationCallbackInterval = UInt64(intervalMs)
        }
        if let poiInterval = ios["poiUpdateIntervalS"] as? Int {
            manager.poiUpdateInterval = poiInterval
        }
        let singleTimeoutMs = (ios["singleLocationTimeoutMs"] as? Int) ?? 10_000

        return CommonConfig(
            coordinateType: coordinateType,
            requestLevel: requestLevel,
            allowsBackgroundLocationUpdates: allowsBackgroundLocationUpdates,
            intervalMs: intervalMs,
            singleLocationTimeoutMs: singleTimeoutMs)
    }
}
