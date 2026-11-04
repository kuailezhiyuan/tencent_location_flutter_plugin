import CoreLocation
import MapKit
import TencentLBS

/// 在 Flutter 侧的 Map 与原生 ``TencentLBSGeofenceRegion`` 之间转换。
enum GeofenceCodec {

    /// Flutter Map → 原生围栏对象（仅 circle / polygon；district 由 manager 异步创建）。
    ///
    /// - Returns: 构造成功返回 region；参数非法或类型不支持返回 nil。
    static func fromMap(_ map: [String: Any?]) -> TencentLBSGeofenceRegion? {
        guard let id = map["id"] as? String, !id.isEmpty else { return nil }
        let typeWire = (map["type"] as? String) ?? "circle"
        let activeAction = EnumCodecs.activeActionFromTransitions(
            (map["monitorTransitions"] as? [String]) ?? ["enter", "exit"])
        let stayed = (map["dwellDurationMs"] as? Int).map { TimeInterval($0) / 1000.0 }

        switch typeWire {
        case "circle":
            guard let center = map["center"] as? [String: Any?],
                  let latitude = center["latitude"] as? Double,
                  let longitude = center["longitude"] as? Double,
                  let radius = (map["radius"] as? Double), radius > 0 else {
                return nil
            }
            let coordinate = CLLocationCoordinate2DMake(latitude, longitude)
            guard let region = TencentLBSGeofenceCircleRegion(
                center: coordinate, radius: radius, identifier: id) else {
                return nil
            }
            applyCommonProperties(region, activeAction: activeAction,
                                  stayed: stayed, userInfo: map["userInfo"])
            return region

        case "polygon":
            guard let rawVertices = map["polygon"] as? [Any], rawVertices.count >= 3 else {
                return nil
            }
            var values: [NSValue] = []
            for vertex in rawVertices {
                if let vertexMap = vertex as? [String: Any?],
                   let latitude = vertexMap["latitude"] as? Double,
                   let longitude = vertexMap["longitude"] as? Double {
                    let coordinate = CLLocationCoordinate2DMake(latitude, longitude)
                    values.append(NSValue(mkCoordinate: coordinate))
                }
            }
            guard values.count >= 3 else { return nil }
            guard let region = TencentLBSGeofencePolygonRegion(
                coordinates: values, identifier: id) else {
                return nil
            }
            applyCommonProperties(region, activeAction: activeAction,
                                  stayed: stayed, userInfo: map["userInfo"])
            return region

        default:
            // district 由 manager 通过关键字异步创建，不在此处处理。
            return nil
        }
    }

    /// 把围栏序列化回 Flutter Map（用于 `getAllGeofences` / 事件回调）。
    static func toMap(_ region: TencentLBSGeofenceRegion,
                      coordinateType: TencentLBSLocationCoordinateType) -> [String: Any?] {
        var map: [String: Any?] = [
            "id": region.identifier,
            "type": typeToWire(region.regionType),
            "coordinateType": EnumCodecs.coordinateTypeToWire(coordinateType),
            "expirationMs": nil,
            "monitorTransitions": activeActionToTransitions(region.activeAction),
            "dwellDurationMs": Int(region.stayedDuration * 1000.0),
            "userInfo": region.userInfo as? [String: Any],
            "center": coordToMap(region.center),
            "radius": nil,
            "polygon": nil,
            "districtKeyword": nil,
        ]

        if let circle = region as? TencentLBSGeofenceCircleRegion {
            map["radius"] = circle.radius
        }

        if let polygon = region as? TencentLBSGeofencePolygonRegion {
            // 取第一个 polygon（多 polygon 仅 district 才有飞地，先平铺第一段）。
            if let first = polygon.polygons.first {
                map["polygon"] = first.compactMap(nsValueToCoordMap)
            }
        }

        if let district = region as? TencentLBSGeofenceDistrictRegion {
            map["districtKeyword"] = district.keyword
        }

        return map
    }

    // MARK: - helpers

    /// 把 ``activeAction`` / ``stayedDuration`` / ``userInfo`` 三个共用属性
    /// 应用到 region 上。circle / polygon 在构造时同步调用；district 由
    /// ``GeofenceManagerEntry`` 在 ``didCreateDistrictRegion`` delegate 回调里
    /// 异步调用（SDK 仅在回调里才暴露 region 引用）。
    static func applyCommonProperties(_ region: TencentLBSGeofenceRegion,
                                      activeAction: TencentLBSGeofenceActiveAction,
                                      stayed: TimeInterval?,
                                      userInfo: Any?) {
        region.activeAction = activeAction
        if let stayed = stayed { region.stayedDuration = stayed }
        if let raw = userInfo as? [String: Any] {
            // 仅保留可被 NSSecureCoding 接受的简单类型。
            var safe: [String: any NSSecureCoding] = [:]
            for (k, v) in raw {
                if let coding = v as? any NSSecureCoding {
                    safe[k] = coding
                }
            }
            region.userInfo = safe
        }
    }

    private static func typeToWire(_ t: TencentLBSGeofenceRegionType) -> String {
        switch t {
        case .circle: return "circle"
        case .polygon: return "polygon"
        case .district: return "district"
        @unknown default: return "circle"
        }
    }

    /// iOS 位掩码 → Flutter wireName 数组。
    static func activeActionToTransitions(_ mask: TencentLBSGeofenceActiveAction) -> [String] {
        var transitions: [String] = []
        if mask.contains(.enter) { transitions.append("enter") }
        if mask.contains(.exit) { transitions.append("exit") }
        if mask.contains(.stayed) { transitions.append("dwell") }
        return transitions
    }

    private static func coordToMap(_ coordinate: CLLocationCoordinate2D) -> [String: Any?] {
        return ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
    }

    private static func nsValueToCoordMap(_ value: NSValue) -> [String: Any?]? {
        let coordinate = value.mkCoordinateValue
        return coordToMap(coordinate)
    }
}
