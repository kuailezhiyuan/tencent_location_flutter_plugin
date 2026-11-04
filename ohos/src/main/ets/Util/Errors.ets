import { MethodResult } from '@ohos/flutter_ohos'

/**
 * 错误码常量与 [MethodResult.error] 上报工具。
 *
 * 各常量字符串必须与 Flutter 侧 `TencentLocationErrorCode.wireName`、
 * Android 侧 `Errors.java`、iOS 侧 `Errors.swift` 完全一致（大小写敏感），
 * 否则 `fromWire` 会静默 fallback 到 default，把异常吞掉。
 */
export class Errors {
  // 通用
  static readonly UNSUPPORTED_ON_PLATFORM: string = 'unsupportedOnThisPlatform'
  static readonly INVALID_ARGUMENT: string = 'invalidArgument'
  static readonly TIMEOUT: string = 'timeout'
  static readonly NATIVE_ERROR: string = 'nativeError'

  // 初始化 / 权限
  static readonly PRIVACY_NOT_AGREED: string = 'privacyNotAgreed'
  static readonly API_KEY_INVALID: string = 'apiKeyInvalid'
  static readonly SDK_INIT_FAILED: string = 'sdkInitFailed'
  static readonly PERMISSION_DENIED: string = 'permissionDenied'
  static readonly LOCATION_SWITCH_OFF: string = 'locationSwitchOff'

  // 运行时
  static readonly ALREADY_STARTED: string = 'alreadyStarted'
  static readonly LOCATION_FAILED: string = 'locationFailed'

  // 围栏
  static readonly GEOFENCE_INVALID_REGION: string = 'geofenceInvalidRegion'
  static readonly GEOFENCE_DISTRICT_NOT_FOUND: string = 'geofenceDistrictNotFound'
  static readonly GEOFENCE_DUPLICATE_ID: string = 'geofenceDuplicateId'
  static readonly GEOFENCE_NETWORK_FAILED: string = 'geofenceNetworkFailed'
  static readonly GEOFENCE_LIMIT_EXCEEDED: string = 'geofenceLimitExceeded'
  static readonly GEOFENCE_ID_NOT_FOUND: string = 'geofenceIdNotFound'

  /** 当前平台不支持该方法。 */
  static unsupported(result: MethodResult, method: string): void {
    result.error(
      Errors.UNSUPPORTED_ON_PLATFORM,
      `Method '${method}' is not supported on HarmonyOS.`,
      null
    )
  }

  /** 参数非法。 */
  static invalidArgument(result: MethodResult, message: string): void {
    result.error(Errors.INVALID_ARGUMENT, message, null)
  }

  /** 通用兜底错误。 */
  static native(result: MethodResult, message: string, cause?: Error | null): void {
    result.error(
      Errors.NATIVE_ERROR,
      message,
      cause == null ? null : String(cause)
    )
  }

  /** 根据指定 code 构造错误。 */
  static code(
    result: MethodResult,
    code: string,
    message: string,
    details: ESObject
  ): void {
    result.error(code, message, details)
  }
}
