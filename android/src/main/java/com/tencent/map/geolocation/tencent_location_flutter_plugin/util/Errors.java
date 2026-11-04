package com.tencent.map.geolocation.tencent_location_flutter_plugin.util;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.plugin.common.MethodChannel;

/**
 * 错误码常量与 {@link MethodChannel.Result#error(String, String, Object)} 上报工具。
 *
 * <p>各常量的字符串值与 Flutter 侧 {@code TencentLocationErrorCode} 枚举的
 * {@code wireName} 一一对应；message 字段会作为 {@code TencentLocationError.message}
 * 透传给上层。</p>
 */
public final class Errors {

    // Flutter 侧 TencentLocationErrorCode.wireName 保持一致
    public static final String UNSUPPORTED_ON_PLATFORM = "unsupportedOnThisPlatform";
    public static final String INVALID_ARGUMENT = "invalidArgument";
    public static final String TIMEOUT = "timeout";
    public static final String NATIVE_ERROR = "nativeError";
    public static final String PRIVACY_NOT_AGREED = "privacyNotAgreed";
    public static final String API_KEY_INVALID = "apiKeyInvalid";
    public static final String SDK_INIT_FAILED = "sdkInitFailed";
    public static final String PERMISSION_DENIED = "permissionDenied";
    public static final String LOCATION_SWITCH_OFF = "locationSwitchOff";
    public static final String ALREADY_STARTED = "alreadyStarted";
    public static final String LOCATION_FAILED = "locationFailed";
    public static final String GEOFENCE_INVALID_REGION = "geofenceInvalidRegion";
    public static final String GEOFENCE_DISTRICT_NOT_FOUND = "geofenceDistrictNotFound";
    public static final String GEOFENCE_DUPLICATE_ID = "geofenceDuplicateId";
    public static final String GEOFENCE_NETWORK_FAILED = "geofenceNetworkFailed";
    public static final String GEOFENCE_LIMIT_EXCEEDED = "geofenceLimitExceeded";
    public static final String GEOFENCE_ID_NOT_FOUND = "geofenceIdNotFound";

    private Errors() {}

    /** 当前平台不支持该方法。 */
    public static void unsupported(@NonNull MethodChannel.Result result, @NonNull String method) {
        result.error(UNSUPPORTED_ON_PLATFORM,
                "Method '" + method + "' is not supported on Android.", null);
    }

    /** 参数非法。 */
    public static void invalidArgument(
            @NonNull MethodChannel.Result result, @NonNull String message) {
        result.error(INVALID_ARGUMENT, message, null);
    }

    /** 通用兜底错误。 */
    public static void native_(@NonNull MethodChannel.Result result,
                               @NonNull String message,
                               @Nullable Throwable cause) {
        result.error(NATIVE_ERROR, message,
                cause == null ? null : cause.toString());
    }

    /** 根据指定 code 构造错误。 */
    public static void code(@NonNull MethodChannel.Result result,
                            @NonNull String code,
                            @NonNull String message,
                            @Nullable Object details) {
        result.error(code, message, details);
    }
}
