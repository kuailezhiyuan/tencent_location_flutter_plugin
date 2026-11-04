import CoreLocation
import Flutter
import TencentLBS

/// 处理所有 ``utils.*`` method。
final class UtilsHandler {

    func handle(_ method: String, _ call: FlutterMethodCall,
                _ result: @escaping FlutterResult) -> Bool {
        switch method {
        case "utils.isInRegion":
            guard let arguments = call.arguments as? [String: Any],
                  let latitude = arguments["latitude"] as? Double,
                  let longitude = arguments["longitude"] as? Double else {
                Errors.invalidArg(result, "latitude/longitude required"); return true
            }
            result(TencentLBSLocationUtils.isInRegion(
                withLatitude: latitude, longitude: longitude))
            return true

        case "utils.wgs84ToGcj02":
            guard let arguments = call.arguments as? [String: Any],
                  let latitude = arguments["latitude"] as? Double,
                  let longitude = arguments["longitude"] as? Double else {
                Errors.invalidArg(result, "latitude/longitude required"); return true
            }
            let coordinate = CLLocationCoordinate2DMake(latitude, longitude)
            let gcj02 = TencentLBSLocationUtils.wgs84TOGCJ02(coordinate)
            result(["latitude": gcj02.latitude, "longitude": gcj02.longitude])
            return true

        case "utils.isSupportGps":
            // iOS SDK 没有提供 isSupportGps；按统一原则抛 unsupported。
            Errors.unsupported(result, method: method)
            return true

        default:
            return false
        }
    }
}
