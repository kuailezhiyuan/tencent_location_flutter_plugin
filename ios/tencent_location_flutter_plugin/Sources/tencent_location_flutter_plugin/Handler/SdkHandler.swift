import CoreLocation
import Flutter
import TencentLBS

/// 处理所有 ``sdk.*`` method 调用。
///
/// iOS 上 apiKey / extraData 是 ``TencentLBSLocationManager`` 实例属性而非全局
/// 单例。本 handler 把它们缓存到 ``SdkConfig`` 中，由 ``LocationManagerRegistry``
/// 在创建 entry 时再应用。
final class SdkHandler {

    private let config: SdkConfig

    init(config: SdkConfig) {
        self.config = config
    }

    func handle(_ method: String, _ call: FlutterMethodCall,
                _ result: @escaping FlutterResult) -> Bool {
        switch method {
        case "sdk.setPrivacyPolicyAgreement":
            let agreed = (call.arguments as? [String: Any])?["agreed"] as? Bool ?? false
            TencentLBSLocationManager.setUserAgreePrivacy(agreed)
            result(nil)
            return true

        case "sdk.getPrivacyPolicyAgreement":
            result(TencentLBSLocationManager.getUserAgreePrivacy())
            return true

        case "sdk.init":
            guard let arguments = call.arguments as? [String: Any] else {
                Errors.invalidArg(result, "init: arguments required")
                return true
            }
            config.iosApiKey = arguments["iosApiKey"] as? String
            config.deviceId = arguments["deviceId"] as? String
            // androidApiKey / harmonyApiKey / extraKey 在 iOS 端无意义，忽略。
            result(nil)
            return true

        case "sdk.getVersion":
            result(TencentLBSLocationManager.getLBSSDKVersion())
            return true

        case "sdk.getBuildVersion":
            result(TencentLBSLocationManager.getLBSSDKbuild())
            return true

        // ---------- iOS 权限 ----------

        case "sdk.ios.requestWhenInUseAuthorization":
            anyManager().requestWhenInUseAuthorization()
            result(nil)
            return true

        case "sdk.ios.requestAlwaysAuthorization":
            anyManager().requestAlwaysAuthorization()
            result(nil)
            return true

        case "sdk.ios.requestTemporaryFullAccuracy":
            guard let arguments = call.arguments as? [String: Any],
                  let purposeKey = arguments["purposeKey"] as? String else {
                Errors.invalidArg(result, "purposeKey required")
                return true
            }
            anyManager().requestTemporaryFullAccuracyAuthorization(
                withPurposeKey: purposeKey) { error in
                // ObjC 接口 completion 的 error 在用户授予权限时为 nil；
                // 由于 SDK 未标 nullable，Swift 桥接成 non-optional，需要再做一次
                // optional 转换。
                let optionalError: NSError? = error as NSError?
                if let optionalError = optionalError {
                    result(optionalError.localizedDescription)
                } else {
                    result(nil)
                }
            }
            return true

        case "sdk.ios.getAccuracyAuthorization":
            let value = TencentLBSLocationManager.accuracyAuthorization()
            result(EnumCodecs.accuracyAuthorizationToWire(value))
            return true

        // ---------- Android / Harmony 独有 ----------

        case "sdk.getOaid",
             "sdk.enableLogToFile",
             "sdk.setRtkLogEnabled",
             "sdk.setSystemCacheEnabled",
             "sdk.setUploadGpsForNaviEnabled",
             "sdk.setLoadLibraryEnabled":
            Errors.unsupported(result, method: method)
            return true

        case "sdk.setExtraData":
            // iOS 没有"全局 setExtraData"概念，需要 manager 实例。
            // 这里把它缓存到 config，每次创建 entry 时应用。
            guard let arguments = call.arguments as? [String: Any],
                  let key = arguments["key"] as? String,
                  let value = arguments["value"] as? String else {
                Errors.invalidArg(result, "key/value required")
                return true
            }
            config.extraData[key] = value
            result(nil)
            return true

        default:
            return false
        }
    }

    /// 仅用于不属于任何 manager 的全局调用（权限申请等）。
    private func anyManager() -> TencentLBSLocationManager {
        if let existing = config.scratchManager {
            return existing
        }
        let manager = TencentLBSLocationManager()
        config.scratchManager = manager
        return manager
    }
}

/// 进程级共享的 SDK 配置（iOS 端每个 manager 都要 apply 一遍 apiKey 等）。
final class SdkConfig {
    var iosApiKey: String?
    var deviceId: String?
    var extraData: [String: String] = [:]
    /// 用于全局权限申请等不绑定具体 manager 的调用。
    var scratchManager: TencentLBSLocationManager?

    /// 把缓存配置应用到一个新的 manager 上。
    func apply(to manager: TencentLBSLocationManager) {
        if let key = iosApiKey, !key.isEmpty {
            manager.apiKey = key
        }
        if let id = deviceId, !id.isEmpty {
            manager.setDeviceId(id)
        }
        for (k, v) in extraData {
            manager.setDataWithValue(v, forKey: k)
        }
    }
}
