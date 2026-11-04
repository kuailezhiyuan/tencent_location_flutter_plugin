/// 腾讯定位 SDK Flutter 插件的错误码。
///
/// **注意**：枚举值按"分组分段 + 段内 Android / iOS / Harmony 顺序"排列。
enum TencentLocationErrorCode {
  // ---------- 通用 ----------
  /// 当前平台不支持该 API 或参数组合。
  unsupportedOnThisPlatform,

  /// 参数非法。对应 Harmony `401`。
  invalidArgument,

  /// 超时。
  timeout,

  /// 兜底错误（未分类）。
  nativeError,

  // ---------- 初始化 / 权限 ----------
  /// 未同意隐私政策。对应 Android ret=4 / iOS init 返回 nil / Harmony 990100。
  privacyNotAgreed,

  /// API Key 无效。对应 Android ret=2。
  apiKeyInvalid,

  /// SDK 初始化失败（so 加载失败等）。对应 Android ret=3。
  sdkInitFailed,

  /// 权限被拒。对应 Android ret=1 / Harmony 201。
  permissionDenied,

  /// 定位总开关已关闭。对应 Android `STATUS_LOCATION_SWITCH_OFF(5)` / Harmony 3301100。
  locationSwitchOff,

  // ---------- 运行时 ----------
  /// 重复启动同一种定位。对应 Harmony 990200。
  alreadyStarted,

  /// 定位失败。对应 Android `ERROR_*` / iOS `TencentLBSLocationError*` /
  /// Harmony 3301200 / 3301300。
  locationFailed,

  // ---------- 围栏 ----------
  /// 围栏区域非法（多边形点数不足、经纬度超范围等）。对应 Android `ERROR_POLYGON_*` /
  /// iOS `InvalidParameter` / Harmony 880100。
  geofenceInvalidRegion,

  /// 行政区划未找到。对应 Android `ERROR_REQUEST_FAILED` / iOS `DistrictNotFound(6)`。
  geofenceDistrictNotFound,

  /// 围栏 ID 重复。对应 iOS `TencentLBSGeofenceErrorDuplicate(4)`。
  geofenceDuplicateId,

  /// 围栏网络请求失败。对应 iOS `NetworkFailed(5)`。
  geofenceNetworkFailed,

  /// 围栏数量超限。对应 Harmony 3301601。
  geofenceLimitExceeded,

  /// 围栏 ID 未找到。对应 Harmony 3301602。
  geofenceIdNotFound,
}

/// 字符串 codec。
extension TencentLocationErrorCodeCodec on TencentLocationErrorCode {
  String get wireName {
    switch (this) {
      case TencentLocationErrorCode.unsupportedOnThisPlatform:
        return 'unsupportedOnThisPlatform';
      case TencentLocationErrorCode.invalidArgument:
        return 'invalidArgument';
      case TencentLocationErrorCode.timeout:
        return 'timeout';
      case TencentLocationErrorCode.nativeError:
        return 'nativeError';
      case TencentLocationErrorCode.privacyNotAgreed:
        return 'privacyNotAgreed';
      case TencentLocationErrorCode.apiKeyInvalid:
        return 'apiKeyInvalid';
      case TencentLocationErrorCode.sdkInitFailed:
        return 'sdkInitFailed';
      case TencentLocationErrorCode.permissionDenied:
        return 'permissionDenied';
      case TencentLocationErrorCode.locationSwitchOff:
        return 'locationSwitchOff';
      case TencentLocationErrorCode.alreadyStarted:
        return 'alreadyStarted';
      case TencentLocationErrorCode.locationFailed:
        return 'locationFailed';
      case TencentLocationErrorCode.geofenceInvalidRegion:
        return 'geofenceInvalidRegion';
      case TencentLocationErrorCode.geofenceDistrictNotFound:
        return 'geofenceDistrictNotFound';
      case TencentLocationErrorCode.geofenceDuplicateId:
        return 'geofenceDuplicateId';
      case TencentLocationErrorCode.geofenceNetworkFailed:
        return 'geofenceNetworkFailed';
      case TencentLocationErrorCode.geofenceLimitExceeded:
        return 'geofenceLimitExceeded';
      case TencentLocationErrorCode.geofenceIdNotFound:
        return 'geofenceIdNotFound';
    }
  }

  static TencentLocationErrorCode fromWire(String? wire) {
    for (final value in TencentLocationErrorCode.values) {
      if (value.wireName == wire) return value;
    }
    return TencentLocationErrorCode.nativeError;
  }
}

/// 腾讯定位 SDK Flutter 插件所有异步错误的统一封装。
class TencentLocationError implements Exception {
  /// 插件层错误码。
  final TencentLocationErrorCode code;

  /// 错误消息（可读）。
  final String message;

  /// 原生 SDK 回传的原始错误码，可为空。
  final int? nativeCode;

  /// 原生 SDK 回传的原始错误消息，可为空。
  final String? nativeMessage;

  /// 附加数据（例如围栏 ID、失败的 `managerId` 等）。
  final Object? details;

  const TencentLocationError({
    required this.code,
    required this.message,
    this.nativeCode,
    this.nativeMessage,
    this.details,
  });

  factory TencentLocationError.fromMap(Map map) {
    return TencentLocationError(
      code: TencentLocationErrorCodeCodec.fromWire(map['code'] as String?),
      message: (map['message'] as String?) ?? '',
      nativeCode: map['nativeCode'] as int?,
      nativeMessage: map['nativeMessage'] as String?,
      details: map['details'],
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'code': code.wireName,
      'message': message,
      'nativeCode': nativeCode,
      'nativeMessage': nativeMessage,
      if (details != null) 'details': details,
    };
  }

  @override
  String toString() {
    final buf = StringBuffer('TencentLocationError(${code.wireName}: $message');
    if (nativeCode != null) buf.write(', nativeCode=$nativeCode');
    if (nativeMessage != null) buf.write(', nativeMessage=$nativeMessage');
    if (details != null) buf.write(', details=$details');
    buf.write(')');
    return buf.toString();
  }
}
