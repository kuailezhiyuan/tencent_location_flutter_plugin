import CoreLocation
import Flutter
import TencentLBS
#if SWIFT_PACKAGE
import TLPGeofenceBridge
#endif

/// 处理所有 ``geofence.*`` method。
final class GeofenceHandler {

    private let registry: GeofenceManagerRegistry
    private let dispatcher: EventDispatcher

    init(registry: GeofenceManagerRegistry, dispatcher: EventDispatcher) {
        self.registry = registry
        self.dispatcher = dispatcher
    }

    func handle(_ method: String, _ call: FlutterMethodCall,
                _ result: @escaping FlutterResult) -> Bool {
        switch method {
        // ---------- manager 生命周期 ----------
        case "geofence.managerCreate":
            guard let id = call.argString("geofenceManagerId") else {
                Errors.invalidArg(result, "geofenceManagerId required"); return true
            }
            if registry.get(id) != nil {
                result(nil); return true
            }
            let entry = GeofenceManagerEntry(managerId: id, dispatcher: dispatcher)
            registry.put(id, entry)
            result(nil)
            return true

        case "geofence.managerDispose":
            guard let id = call.argString("geofenceManagerId") else {
                Errors.invalidArg(result, "geofenceManagerId required"); return true
            }
            if let entry = registry.remove(id) {
                entry.geofenceManager.removeAllGeofences()
                entry.geofenceManager.stopMonitoring()
                entry.clearPendingDistrictConfigs()
            }
            result(nil)
            return true

        // ---------- 围栏管理 ----------
        case "geofence.add":
            guard let entry = lookup(call, result) else { return true }
            guard let fenceMap = (call.arguments as? [String: Any])?["geofence"]
                    as? [String: Any?] else {
                Errors.invalidArg(result, "geofence required"); return true
            }

            if let expirationMs = fenceMap["expirationMs"] as? Int, expirationMs >= 0 {
                NSLog("[TencentLocation] geofence.expiration is not supported on iOS"
                    + " (native CoreLocation has no expiration concept);"
                    + " value \(expirationMs)ms is ignored. The geofence stays valid"
                    + " until you remove it explicitly.")
            }
            applyCoordinateType(entry: entry, fenceMap: fenceMap)
            let typeWire = (fenceMap["type"] as? String) ?? "circle"
            if typeWire == "district" {
                guard let id = fenceMap["id"] as? String,
                      let keyword = fenceMap["districtKeyword"] as? String else {
                    Errors.invalidArg(result, "districtKeyword required"); return true
                }
                // 行政区围栏由 SDK 通过关键字异步创建，无法在创建前把 activeAction /
                // stayedDuration / userInfo 设到 region 上 —— 这些值要等
                // ``didCreateDistrictRegion`` 回调拿到 region 后才能应用。
                // 所以先把待应用配置缓存到 entry，再发起异步创建请求。
                let activeAction = EnumCodecs.activeActionFromTransitions(
                    (fenceMap["monitorTransitions"] as? [String]) ?? ["enter", "exit"])
                let stayedDuration = (fenceMap["dwellDurationMs"] as? Int)
                    .map { TimeInterval($0) / 1000.0 }
                let userInfo = fenceMap["userInfo"] as? [String: Any]
                entry.setPendingDistrictConfig(
                    GeofenceManagerEntry.PendingDistrictConfig(
                        identifier: id,
                        activeAction: activeAction,
                        stayedDuration: stayedDuration,
                        userInfo: userInfo),
                    forKeyword: keyword)
                entry.geofenceManager.addDistrictGeofence(
                    withKeyword: keyword, identifier: id)
                result(nil)
                return true
            }
            guard let region = GeofenceCodec.fromMap(fenceMap) else {
                Errors.invalidArg(result, "invalid geofence parameters"); return true
            }
            entry.geofenceManager.addGeofenceRegion(region)
            result(nil)
            return true

        case "geofence.remove":
            guard let entry = lookup(call, result),
                  let id = call.argString("id") else {
                Errors.invalidArg(result, "id required"); return true
            }
            entry.geofenceManager.removeGeofence(withIdentifier: id)
            result(nil)
            return true

        case "geofence.removeAll":
            guard let entry = lookup(call, result) else { return true }
            entry.geofenceManager.removeAllGeofences()
            entry.clearPendingDistrictConfigs()
            result(nil)
            return true

        case "geofence.getAll":
            guard let entry = lookup(call, result) else { return true }
            let coordinateType = entry.geofenceManager.coordinateType
            let regions = entry.geofenceManager.geofenceRegions.map {
                GeofenceCodec.toMap($0, coordinateType: coordinateType)
                    .compactMapValues { $0 }
            }
            result(regions)
            return true

        // ---------- 状态查询 ----------
        case "geofence.isCoordinateInside":
            guard let entry = lookup(call, result),
                  let identifier = call.argString("id"),
                  let coordinate = coordinate(from: call) else {
                Errors.invalidArg(result, "id/coordinate required"); return true
            }
            let inside = entry.geofenceManager.isCoordinate(
                coordinate, insideGeofenceWithIdentifier: identifier)
            result(inside)
            return true

        case "geofence.regionsContaining":
            guard let entry = lookup(call, result),
                  let coordinate = coordinate(from: call) else {
                Errors.invalidArg(result, "coordinate required"); return true
            }
            let coordinateType = entry.geofenceManager.coordinateType
            let rawRegions = TLPGeofenceRegionsContainingCoordinate(entry.geofenceManager, coordinate)
            let regions = rawRegions.map {
                GeofenceCodec.toMap($0, coordinateType: coordinateType)
                    .compactMapValues { $0 }
            }
            result(regions)
            return true

        // ---------- 监控生命周期 ----------
        case "geofence.ios.startMonitoring":
            guard let entry = lookup(call, result) else { return true }
            entry.geofenceManager.startMonitoring()
            result(nil)
            return true

        case "geofence.ios.stopMonitoring":
            guard let entry = lookup(call, result) else { return true }
            entry.geofenceManager.stopMonitoring()
            result(nil)
            return true

        case "geofence.ios.pauseMonitoring":
            guard let entry = lookup(call, result) else { return true }
            entry.geofenceManager.pauseMonitoring()
            result(nil)
            return true

        case "geofence.ios.resumeMonitoring":
            guard let entry = lookup(call, result) else { return true }
            entry.geofenceManager.resumeMonitoring()
            result(nil)
            return true

        case "geofence.ios.isMonitoring":
            guard let entry = lookup(call, result) else { return true }
            result(entry.geofenceManager.isMonitoring)
            return true

        // ---------- iOS 配置 ----------
        case "geofence.ios.setAllowsBackgroundLocationUpdates":
            guard let entry = lookup(call, result),
                  let enabled = call.argBool("enabled") else {
                Errors.invalidArg(result, "enabled required"); return true
            }
            entry.geofenceManager.allowsBackgroundLocationUpdates = enabled
            result(nil)
            return true

        case "geofence.ios.setAdaptiveDistanceFilterEnabled":
            guard let entry = lookup(call, result),
                  let enabled = call.argBool("enabled") else {
                Errors.invalidArg(result, "enabled required"); return true
            }
            entry.geofenceManager.isAdaptiveDistanceFilterEnabled = enabled
            result(nil)
            return true

        case "geofence.ios.setDistanceFilter":
            guard let entry = lookup(call, result),
                  let meters = call.argDouble("meters") else {
                Errors.invalidArg(result, "meters required"); return true
            }
            entry.geofenceManager.distanceFilter = meters
            result(nil)
            return true

        case "geofence.ios.setDesiredAccuracy":
            guard let entry = lookup(call, result),
                  let wire = call.argString("accuracy") else {
                Errors.invalidArg(result, "accuracy required"); return true
            }
            entry.geofenceManager.desiredAccuracy = EnumCodecs.desiredAccuracyFromWire(wire)
            result(nil)
            return true

        case "geofence.ios.setDetectionInterval":
            guard let entry = lookup(call, result),
                  let intervalMs = call.argInt("intervalMs") else {
                Errors.invalidArg(result, "intervalMs required"); return true
            }
            entry.geofenceManager.detectionInterval = TimeInterval(intervalMs) / 1000.0
            result(nil)
            return true

        default:
            return false
        }
    }

    // MARK: - helpers

    private func lookup(_ call: FlutterMethodCall,
                        _ result: @escaping FlutterResult) -> GeofenceManagerEntry? {
        guard let id = call.argString("geofenceManagerId") else {
            Errors.invalidArg(result, "geofenceManagerId required"); return nil
        }
        guard let entry = registry.get(id) else {
            result(Errors.make(code: Errors.nativeError,
                               message: "geofence manager not found: \(id)"))
            return nil
        }
        return entry
    }

    private func coordinate(from call: FlutterMethodCall) -> CLLocationCoordinate2D? {
        guard let arguments = call.arguments as? [String: Any],
              let coordinateMap = arguments["coordinate"] as? [String: Any],
              let latitude = coordinateMap["latitude"] as? Double,
              let longitude = coordinateMap["longitude"] as? Double else {
            return nil
        }
        return CLLocationCoordinate2DMake(latitude, longitude)
    }

    private func applyCoordinateType(entry: GeofenceManagerEntry,
                                     fenceMap: [String: Any?]) {
        let wire = fenceMap["coordinateType"] as? String ?? "gcj02"
        entry.geofenceManager.coordinateType =
            EnumCodecs.coordinateTypeFromWire(wire)
    }
}

private extension FlutterMethodCall {
    func argString(_ name: String) -> String? {
        return (arguments as? [String: Any])?[name] as? String
    }
    func argBool(_ name: String) -> Bool? {
        return (arguments as? [String: Any])?[name] as? Bool
    }
    func argDouble(_ name: String) -> Double? {
        guard let rawValue = (arguments as? [String: Any])?[name] else { return nil }
        if let doubleValue = rawValue as? Double { return doubleValue }
        if let number = rawValue as? NSNumber { return number.doubleValue }
        return nil
    }
    func argInt(_ name: String) -> Int? {
        guard let rawValue = (arguments as? [String: Any])?[name] else { return nil }
        if let intValue = rawValue as? Int { return intValue }
        if let number = rawValue as? NSNumber { return number.intValue }
        return nil
    }
}
