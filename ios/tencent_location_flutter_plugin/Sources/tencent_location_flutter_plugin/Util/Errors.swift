import Flutter

/// 错误码常量与 ``FlutterResult`` 上报工具。
///
/// 各常量的字符串值与 Flutter 侧 `TencentLocationErrorCode` 枚举的
/// `wireName` 一一对应；message 字段会作为 `TencentLocationError.message`
/// 透传给上层。
enum Errors {
    // 通用
    static let unsupportedOnPlatform = "unsupportedOnThisPlatform"
    static let invalidArgument = "invalidArgument"
    static let timeout = "timeout"
    static let nativeError = "nativeError"

    // 初始化 / 权限
    static let privacyNotAgreed = "privacyNotAgreed"
    static let apiKeyInvalid = "apiKeyInvalid"
    static let sdkInitFailed = "sdkInitFailed"
    static let permissionDenied = "permissionDenied"
    static let locationSwitchOff = "locationSwitchOff"

    // 运行时
    static let alreadyStarted = "alreadyStarted"
    static let locationFailed = "locationFailed"

    // 围栏
    static let geofenceInvalidRegion = "geofenceInvalidRegion"
    static let geofenceDistrictNotFound = "geofenceDistrictNotFound"
    static let geofenceDuplicateId = "geofenceDuplicateId"
    static let geofenceNetworkFailed = "geofenceNetworkFailed"
    static let geofenceLimitExceeded = "geofenceLimitExceeded"
    static let geofenceIdNotFound = "geofenceIdNotFound"

    static func unsupported(_ result: @escaping FlutterResult, method: String) {
        result(FlutterError(code: unsupportedOnPlatform,
                            message: "Method '\(method)' is not supported on iOS.",
                            details: nil))
    }

    static func invalidArg(_ result: @escaping FlutterResult, _ message: String) {
        result(FlutterError(code: invalidArgument, message: message, details: nil))
    }

    static func native(_ result: @escaping FlutterResult, _ message: String,
                       nativeCode: Int? = nil) {
        var details: [String: Any]? = nil
        if let nativeCode = nativeCode {
            details = ["nativeCode": nativeCode]
        }
        result(FlutterError(code: nativeError, message: message, details: details))
    }

    static func make(code: String, message: String,
                     nativeCode: Int? = nil) -> FlutterError {
        var details: [String: Any]? = nil
        if let nativeCode = nativeCode {
            details = ["nativeCode": nativeCode]
        }
        return FlutterError(code: code, message: message, details: details)
    }
}
