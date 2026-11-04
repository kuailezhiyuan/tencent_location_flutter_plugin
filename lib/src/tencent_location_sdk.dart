import 'enums/ios_enums.dart';
import 'models/tencent_sdk_log_event.dart';
import 'platform_interface/tencent_location_platform.dart';

/// 腾讯定位 SDK 的全局入口。所有全局设置都在此类。
///
/// 使用顺序：
/// 1. [setPrivacyPolicyAgreement(true)] — 同意隐私政策
/// 2. [init(...)] — 设置 API Key（也可在 manifest/plist 中配置）
/// 3. 创建 [TencentLocationManager] / [TencentGeofenceManager] 实例使用
abstract class TencentLocationSDK {
  TencentLocationSDK._();

  static TencentLocationPlatform get _platform =>
      TencentLocationPlatform.instance;

  // ==================== 隐私合规（必先调用）====================

  /// 设置用户是否同意隐私政策。**必须在调用任何其他 API 前调用**。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Parameters**:
  /// - [agreed]：是否同意隐私政策。
  static Future<void> setPrivacyPolicyAgreement(bool agreed) =>
      _platform.setPrivacyPolicyAgreement(agreed);

  /// 获取当前隐私政策同意状态。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Returns**:
  /// - `true` 表示已同意，`false` 表示未同意。
  static Future<bool> getPrivacyPolicyAgreement() =>
      _platform.getPrivacyPolicyAgreement();

  // ==================== 初始化 ====================

  /// 初始化 SDK。调用前必须已同意隐私政策。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Parameters**:
  /// - [androidApiKey] / [iosApiKey] / [harmonyApiKey]：三端的 ApiKey。
  /// - [deviceId]：用于问题排查的设备唯一标识；长度 1–63，仅字母 / 数字 / 下划线。
  /// - [extraKey]：高级功能用的额外 Key（Android `setExtraKey`）。
  static Future<void> init({
    String? androidApiKey,
    String? iosApiKey,
    String? harmonyApiKey,
    String? deviceId,
    String? extraKey,
  }) =>
      _platform.init(
        androidApiKey: androidApiKey,
        iosApiKey: iosApiKey,
        harmonyApiKey: harmonyApiKey,
        deviceId: deviceId,
        extraKey: extraKey,
      );

  // ==================== 版本信息 ====================

  /// 获取 SDK 版本号。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Returns**:
  /// - 形如 `7.6.1.8` 的版本号字符串。
  static Future<String> getVersion() => _platform.getVersion();

  /// 获取 SDK 构建版本号。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Returns**:
  /// - 形如 `YYMMDD` / `YYYYMMDD` 的构建日期字符串。
  static Future<String> getBuildVersion() => _platform.getBuildVersion();

  /// 获取设备 OAID（Android 设备唯一标识）。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Returns**:
  /// - 设备的 OAID 字符串。
  static Future<String> getOaid() => _platform.getOaid();

  // ==================== 日志与调试 ====================

  /// 是否把 SDK 日志写入本地文件。建议开发调试时打开，生产环境关闭。
  ///
  /// **必须在创建 [TencentLocationManager] 实例之前调用**，否则不生效。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持，写入 `/sdcard/Android/data/<应用包名>/files/t_log/` 目录
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：支持，写入 `data/app/el2/100/base/<应用包名>/haps/entry/files/TencentLocation/t_log/` 目录
  ///
  /// **Parameters**:
  /// - [enabled]：`true` 开启日志文件写入，`false` 关闭。
  static Future<void> enableLogToFile(bool enabled) => _platform.enableLogToFile(enabled);

  /// RTK 日志开关。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [enabled]：`true` 开启 RTK 日志，`false` 关闭。
  static Future<void> setRtkLogEnabled(bool enabled) =>
      _platform.setRtkLogEnabled(enabled);

  /// 订阅 SDK 运行日志。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，订阅成功但不会收到事件
  /// - 🔶 Harmony：不支持，订阅成功但不会收到事件
  ///
  /// **Returns**:
  /// - SDK 内部运行日志的事件流，用于排查问题。
  static Stream<TencentSdkLogEvent> get onSdkLogChanged => _platform.onSdkLogChanged;

  // ==================== 其它全局配置 ====================

  /// 是否允许定位失败时返回系统缓存位置。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [enabled]：`true` 允许返回系统缓存位置，`false` 禁止。
  static Future<void> setSystemCacheEnabled(bool enabled) =>
      _platform.setSystemCacheEnabled(enabled);

  /// 设置 SDK 附加数据。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，请用 [TencentLocationManager.setIosExtraData]
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [key]：附加数据的键。
  /// - [value]：附加数据的值。
  static Future<void> setExtraData(String key, String value) =>
      _platform.setExtraData(key, value);

  /// 是否上传 GPS 点用于导航增强。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [enabled]：`true` 允许上传，`false` 禁止。
  static Future<void> setUploadGpsForNaviEnabled(bool enabled) =>
      _platform.setUploadGpsForNaviEnabled(enabled);

  /// 是否由 SDK 自动加载 `libtencentloc.so`。**必须在 [init] 之前调用**。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [enabled]：`true` 由 SDK 自动加载，`false` 由调用方自行加载。
  static Future<void> setLoadLibraryEnabled(bool enabled) =>
      _platform.setLoadLibraryEnabled(enabled);

  // ==================== iOS 权限 ====================

  /// 请求使用期间定位权限。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  static Future<void> requestIosWhenInUseAuthorization() =>
      _platform.requestIosWhenInUseAuthorization();

  /// 请求始终允许定位权限。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  static Future<void> requestIosAlwaysAuthorization() =>
      _platform.requestIosAlwaysAuthorization();

  /// 请求临时的完全精度权限（iOS 14+）。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [purposeKey]：对应 Info.plist 中 `NSLocationTemporaryUsageDescriptionDictionary` 的 key。
  ///
  /// **Returns**:
  /// - `null` 表示授权成功；否则返回系统错误描述字符串。
  static Future<String?> requestIosTemporaryFullAccuracy({
    required String purposeKey,
  }) =>
      _platform.requestIosTemporaryFullAccuracy(purposeKey: purposeKey);

  /// 获取当前系统精度权限状态（iOS 14+）。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Returns**:
  /// - 当前系统授予的精度等级（完全精度 / 模糊精度）。
  static Future<IosAccuracyAuthorization> getIosAccuracyAuthorization() =>
      _platform.getIosAccuracyAuthorization();
}
