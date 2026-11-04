import CoreLocation
import TencentLBS

/// 在 Flutter 侧的 Map 与原生 ``TencentLBSLocation`` 之间转换。
enum LocationCodec {

    /// 把 ``TencentLBSLocation`` 编码为 Flutter 侧能消费的 Map。
    ///
    /// - Parameter coordinateType: 当前 manager 的坐标系（用于回传给 Dart 层）。
    static func toMap(_ location: TencentLBSLocation,
                      coordinateType: TencentLBSLocationCoordinateType) -> [String: Any?] {
        let coreLocation: CLLocation = location.location

        // 仅写入 iOS 端能提供的字段；其它平台专属字段（elapsedRealtime / gpsRssi /
        // cacheSource / extras 等）省略，由 Dart 侧 `TencentLocation.fromMap` 兜底
        // 为 null / 默认值，避免无效占位增大 payload。
        let map: [String: Any?] = [
            "latitude": coreLocation.coordinate.latitude,
            "longitude": coreLocation.coordinate.longitude,
            "altitude": coreLocation.altitude,
            "accuracy": coreLocation.horizontalAccuracy,
            "bearing": coreLocation.course,
            "speed": coreLocation.speed,
            "time": Int(coreLocation.timestamp.timeIntervalSince1970 * 1000.0),
            "source": EnumCodecs.locationProviderToWire(location.locationProvider),
            "coordinateType": EnumCodecs.coordinateTypeToWire(coordinateType),
            "geoAddress": geoAddressMap(location),
            "poiList": (location.poiList ?? []).map(poiToMap),
            "indoorBuildingId": location.buildingId,
            "indoorBuildingFloor": location.buildingFloor,
            // iOS 专属
            "verticalAccuracy": coreLocation.verticalAccuracy,
        ]
        return map
    }

    private static func geoAddressMap(_ location: TencentLBSLocation) -> [String: Any?]? {
        let hasAny: Bool = {
            if location.name?.isEmpty == false { return true }
            if location.address?.isEmpty == false { return true }
            if location.nation?.isEmpty == false { return true }
            if location.province?.isEmpty == false { return true }
            if location.city?.isEmpty == false { return true }
            if location.district?.isEmpty == false { return true }
            if location.town?.isEmpty == false { return true }
            if location.village?.isEmpty == false { return true }
            if location.street?.isEmpty == false { return true }
            if location.street_no?.isEmpty == false { return true }
            if location.code?.isEmpty == false { return true }
            if location.cityPhoneCode?.isEmpty == false { return true }
            if location.nationCode != 0 { return true }
            return false
        }()
        guard hasAny else { return nil }
        return [
            "name": location.name,
            "address": location.address,
            "nation": location.nation,
            "nationCode": location.nationCode == 0 ? nil : Int(location.nationCode),
            "province": location.province,
            "city": location.city,
            "district": location.district,
            "town": location.town,
            "village": location.village,
            "street": location.street,
            "streetNo": location.street_no,
            "cityCode": location.code,
            "cityPhoneCode": location.cityPhoneCode,
            "areaStat": Int(location.areaStat),
        ]
    }

    private static func poiToMap(_ poi: TencentLBSPoi) -> [String: Any?] {
        return [
            "name": poi.name,
            "address": poi.address,
            "catalog": poi.catalog,
            "distance": poi.distance,
            "latitude": poi.latitude,
            "longitude": poi.longitude,
            "uid": poi.uid,
            "direction": nil,
        ]
    }
}
