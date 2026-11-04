import CoreLocation
import TencentLBS

/// 在 Flutter 侧 `wireName` 字符串与原生 SDK 枚举值之间转换。
enum EnumCodecs {

    // MARK: CoordinateType

    static func coordinateTypeFromWire(_ wire: String?) -> TencentLBSLocationCoordinateType {
        switch wire {
        case "wgs84": return .WGS84
        case "gcj02": return .GCJ02
        default: return .GCJ02
        }
    }

    static func coordinateTypeToWire(_ type: TencentLBSLocationCoordinateType) -> String {
        switch type {
        case .WGS84: return "wgs84"
        case .GCJ02: return "gcj02"
        @unknown default: return "gcj02"
        }
    }

    // MARK: RequestLevel

    static func requestLevelFromWire(_ wire: String?) -> TencentLBSRequestLevel {
        switch wire {
        case "geo": return .geo
        case "name": return .name
        case "adminArea": return .adminName
        case "poi": return .poi
        default: return .adminName
        }
    }

    // MARK: IosDesiredAccuracy

    static func desiredAccuracyFromWire(_ wire: String?) -> CLLocationAccuracy {
        switch wire {
        case "best": return kCLLocationAccuracyBest
        case "bestForNavigation": return kCLLocationAccuracyBestForNavigation
        case "nearestTenMeters": return kCLLocationAccuracyNearestTenMeters
        case "hundredMeters": return kCLLocationAccuracyHundredMeters
        case "kilometer": return kCLLocationAccuracyKilometer
        case "threeKilometers": return kCLLocationAccuracyThreeKilometers
        default: return kCLLocationAccuracyBest
        }
    }

    // MARK: IosActivityType

    static func activityTypeFromWire(_ wire: String?) -> CLActivityType {
        switch wire {
        case "automotiveNavigation": return .automotiveNavigation
        case "fitness": return .fitness
        case "otherNavigation": return .otherNavigation
        case "airborne":
            if #available(iOS 12.0, *) { return .airborne }
            return .other
        case "other": return .other
        default: return .other
        }
    }

    // MARK: IosAccuracyAuthorization

    static func accuracyAuthorizationToWire(_ value: TencentLBSAccuracyAuthorization) -> String {
        switch value {
        case .fullAccuracy: return "fullAccuracy"
        case .reducedAccuracy: return "reducedAccuracy"
        @unknown default: return "fullAccuracy"
        }
    }

    // MARK: LocationSource

    /// 把 `TencentLBSLocationProvider` 映射为 Flutter 侧的 `LocationSource.wireName`。
    static func locationProviderToWire(_ provider: TencentLBSLocationProvider) -> String {
        switch provider {
        case .GPS: return "iosGps"
        case .netWork: return "iosNetwork"
        case .simulated: return "iosSimulated"
        case .accessoryGPS: return "iosAccessoryGps"
        case .accessoryNetwork: return "iosAccessoryNetwork"
        case .unkown: return "unknown"
        @unknown default:
            // 原生 SDK 新增了未识别的枚举值，提示插件层需要补映射。
            // 仅在 SDK 升级且引入新值时触发，频率自然收敛。
            NSLog("[TencentLocation] locationProviderToWire received unknown"
                + " TencentLBSLocationProvider raw value \(provider.rawValue);"
                + " falling back to \"unknown\". Plugin needs to add mapping.")
            return "unknown"
        }
    }

    // MARK: GeofenceTransition

    /// Flutter wireName 集合 → iOS 位掩码。
    ///
    /// 空集合时回退为 `enter + exit`，与 Android 端 `GeofenceCodec.parseMonitorTransitions`
    /// 行为对齐，避免同样的入参在两端表现不一致。
    static func activeActionFromTransitions(_ transitions: [String]) -> TencentLBSGeofenceActiveAction {
        var mask: TencentLBSGeofenceActiveAction = []
        for t in transitions {
            switch t {
            case "enter": mask.insert(.enter)
            case "exit": mask.insert(.exit)
            case "dwell": mask.insert(.stayed)
            default: break
            }
        }
        return mask.isEmpty ? [.enter, .exit] : mask
    }
}
