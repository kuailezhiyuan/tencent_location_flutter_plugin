import '../enums/android_enums.dart';
import '../enums/coordinate_type.dart';
import '../enums/harmony_enums.dart';
import '../enums/ios_enums.dart';
import '../enums/request_level.dart';

/// Android 专属请求字段。
class TencentLocationRequestAndroidExtension {
  /// 定位模式。对应 `TencentLocationRequest.setLocMode(int)`。
  AndroidLocationMode locMode = AndroidLocationMode.highAccuracy;

  /// GNSS 来源。对应 `setGnssSource(int)`。
  AndroidGnssSource gnssSource = AndroidGnssSource.gpsFirst;

  /// 允许 GPS。对应 `setAllowGPS(bool)`。
  bool allowGps = true;

  /// 允许 BLE。对应 `setAllowBLE(bool)`。
  bool allowBle = true;

  /// 允许缓存定位。对应 `setAllowCache(bool)`。
  bool allowCache = false;

  /// GPS 优先。对应 `setGpsFirst(bool)`。
  bool gpsFirst = false;

  /// GPS 优先超时。对应 `setGpsFirstTimeOut(int)`。
  Duration gpsFirstTimeout = const Duration(seconds: 5);

  /// 首次定位回调的兜底超时时间，默认 15s。对应 `setLocFirstTimeOut(long)`。
  ///
  /// 作用于连续定位启动、或单次定位，若在该时间内仍未产生符合
  /// 条件的回调，会触发一次兜底回调，返回当前最优定位点；若全程无任何点，则回调
  /// `ERROR_FIRST_TIMEOUT`（错误码 6）。
  ///
  /// 当 [firstLocationNeedAddress] 为 true 时，该值还会同时作为「等待地址信息」的最长
  /// 等待窗口：窗口内出现的无地址点会被暂时忽略；窗口到期仍未拿到地址，则回调当前最优
  /// 定位点（可能不带地址）。
  ///
  /// 不影响单次定位缓存命中时的快速返回路径。
  ///
  /// Android 端**单次定位的整体超时**也由本字段控制。iOS / Harmony 的单次定位超时分别在
  /// `iosExtension.singleLocationTimeout` / `harmonyExtension.singleLocationTimeout`
  /// 上配置。
  Duration firstLocationTimeout = const Duration(seconds: 15);

  /// 首次定位是否需要地址。对应 `setFirstLocationNeedAddress(bool)`。
  bool firstLocationNeedAddress = false;

  /// 室内定位模式。对应 `setIndoorLocationMode(bool)`。
  bool indoorMode = false;

  /// 场景化定位。
  ///
  /// 设置后 Native 走 `TencentLocationManager.requestLocationWithScene(scene, listener)` 路径，
  /// 覆盖其它参数。
  AndroidLocationScene? scene;

  /// 小程序 AppKey。对应 `setSmallAppKey(String)`。
  String smallAppKey = '';

  /// QQ 号。对应 `setQQ(String)`。
  String qq = '';

  /// 手机号。对应 `setPhoneNumber(String)`（内部 `extras["phoneNumber"]`）。
  String phoneNumber = '';

  /// ReGeoCoding Key，拿 [TencentGeoAddress.nationCode] 必需。
  String? reGeoCodingKey;

  Map<String, Object?> toMap() => <String, Object?>{
        'locMode': locMode.wireName,
        'gnssSource': gnssSource.wireName,
        'allowGps': allowGps,
        'allowBle': allowBle,
        'allowCache': allowCache,
        'gpsFirst': gpsFirst,
        'gpsFirstTimeoutMs': gpsFirstTimeout.inMilliseconds,
        'firstLocationTimeoutMs': firstLocationTimeout.inMilliseconds,
        'firstLocationNeedAddress': firstLocationNeedAddress,
        'indoorMode': indoorMode,
        'scene': scene?.wireName,
        'smallAppKey': smallAppKey,
        'qq': qq,
        'phoneNumber': phoneNumber,
        'reGeoCodingKey': reGeoCodingKey,
      };
}

/// iOS 专属请求字段。
class TencentLocationRequestIosExtension {
  /// 期望精度。对应 `desiredAccuracy`。
  IosDesiredAccuracy desiredAccuracy = IosDesiredAccuracy.best;

  /// 是否允许后台定位。默认 `false`。对应 `allowsBackgroundLocationUpdates`。
  ///
  /// 设为 `true` 时需要在 `Info.plist` 的 `UIBackgroundModes` 中勾选 `location`，
  /// 否则 iOS 系统会抛出异常。
  bool allowsBackgroundLocationUpdates = false;

  /// 距离过滤器（米）。`null` = `kCLDistanceFilterNone`。对应 `distanceFilter`。
  double? distanceFilter;

  /// 自动暂停定位。对应 `pausesLocationUpdatesAutomatically`。
  ///
  /// 默认 `true`，与苹果原生 `CLLocationManager` 默认值对齐。
  bool pausesLocationUpdatesAutomatically = true;

  /// 活动类型。对应 `activityType`。
  IosActivityType activityType = IosActivityType.other;

  /// Heading 过滤器。对应 `headingFilter`。
  double? headingFilter;

  /// Heading 参考方向（`CLDeviceOrientation` 对应的 int）。对应 `headingOrientation`。
  int? headingOrientation;

  /// POI 更新间隔。对应 `poiUpdateInterval`（秒）。
  Duration poiUpdateInterval = const Duration(seconds: 10);

  /// 单次定位超时，默认 10s。对应原生
  /// `[manager requestLocationWithRequestLevel:locationTimeout:completionBlock:]`
  /// 的 `locationTimeout` 入参。
  ///
  /// 仅对单次定位生效，不影响连续定位。
  Duration singleLocationTimeout = const Duration(seconds: 10);

  Map<String, Object?> toMap() => <String, Object?>{
        'desiredAccuracy': desiredAccuracy.wireName,
        'allowsBackgroundLocationUpdates': allowsBackgroundLocationUpdates,
        'distanceFilter': distanceFilter,
        'pausesLocationUpdatesAutomatically':
            pausesLocationUpdatesAutomatically,
        'activityType': activityType.wireName,
        'headingFilter': headingFilter,
        'headingOrientation': headingOrientation,
        'poiUpdateIntervalS': poiUpdateInterval.inSeconds,
        'singleLocationTimeoutMs': singleLocationTimeout.inMilliseconds,
      };
}

/// Harmony 专属请求字段。
class TencentLocationRequestHarmonyExtension {
  /// 用户活动场景。与 [powerConsumptionScenario] 互斥。
  ///
  /// ⚠️ 与 Android 的 `AndroidLocationScene` **不是同一概念**：Android scene 是
  /// 业务场景（签到 / 运动 / 出行），而 Harmony 这里是功耗 + 精度策略。
  HarmonyUserActivityScenario? userActivityScenario;

  /// 功耗场景。
  HarmonyPowerConsumptionScenario? powerConsumptionScenario =
      HarmonyPowerConsumptionScenario.high;

  /// 定位优先级。
  HarmonyLocatingPriority locatingPriority =
      HarmonyLocatingPriority.locatingSpeed;

  /// SDK 内部定位间隔。对应 `setInnerInterval(s)`。
  Duration innerInterval = const Duration(seconds: 1);

  /// 逆地理请求间隔。对应 `setReverseGeocodeRequestInterval(s)`。
  Duration reverseGeocodeRequestInterval = const Duration(seconds: 10);

  /// 首次定位缓存策略（秒）。对应 `setFirstLocationCachePolicy(s)`：
  /// - `-1`：不用缓存
  /// - `0`：全部使用缓存
  /// - `>0`：仅使用该时间内的缓存
  Duration firstLocationCachePolicy = const Duration(seconds: -1);

  /// 单次定位超时，默认 10s。对应 `setSingleLocationTimeout(s)`。
  ///
  /// 仅对单次定位生效，不影响连续定位。
  Duration singleLocationTimeout = const Duration(seconds: 10);

  Map<String, Object?> toMap() => <String, Object?>{
        'userActivityScenario': userActivityScenario?.wireName,
        'powerConsumptionScenario': powerConsumptionScenario?.wireName,
        'locatingPriority': locatingPriority.wireName,
        'innerIntervalS': innerInterval.inSeconds,
        'reverseGeocodeRequestIntervalS':
            reverseGeocodeRequestInterval.inSeconds,
        'firstLocationCachePolicyS': firstLocationCachePolicy.inSeconds,
        'singleLocationTimeoutS': singleLocationTimeout.inSeconds,
      };
}

/// 定位请求。
///
/// 使用 `TencentLocationRequest.create()` 创建默认请求，然后链式设置通用字段，
/// 通过 `.android((a) => ...)` / `.ios((i) => ...)` / `.harmony((h) => ...)` 配置平台专属字段。
class TencentLocationRequest {
  // ---------- 通用字段 ----------

  /// 连续定位回调间隔。默认 5 秒。
  Duration interval = const Duration(seconds: 5);

  /// 坐标系。默认 [CoordinateType.gcj02]。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：原生 SDK 单例的**进程级**全局属性，所有 `TencentLocationManager` /
  ///   `TencentGeofenceManager` 实例共享同一个值；同一进程里多个实例使用不同坐标系会相互覆盖
  ///   （后写入生效），不存在 per-instance 隔离。请保持各 request / fence 的坐标系一致。
  /// - 🍏 iOS：每个原生 manager 实例独立保存，per-instance 隔离。
  /// - 🔶 Harmony：每个原生 manager 实例独立保存，per-instance 隔离。
  CoordinateType coordinateType = CoordinateType.gcj02;

  /// 返回等级。默认 [RequestLevel.adminArea]。
  ///
  /// 不需要地址信息时设为 [RequestLevel.geo] 即可（仅返回经纬度，不带 name / address）。
  RequestLevel requestLevel = RequestLevel.adminArea;

  /// 是否启用传感器方向。默认 `false`。
  bool allowDirectionSensor = false;

  // ---------- 平台扩展 ----------

  final TencentLocationRequestAndroidExtension _android =
      TencentLocationRequestAndroidExtension();
  final TencentLocationRequestIosExtension _ios =
      TencentLocationRequestIosExtension();
  final TencentLocationRequestHarmonyExtension _harmony =
      TencentLocationRequestHarmonyExtension();

  TencentLocationRequest._();

  /// 创建默认请求。
  factory TencentLocationRequest.create() => TencentLocationRequest._();

  // ---------- 通用 setter（链式）----------

  TencentLocationRequest setInterval(Duration value) {
    interval = value;
    return this;
  }

  TencentLocationRequest setCoordinateType(CoordinateType value) {
    coordinateType = value;
    return this;
  }

  TencentLocationRequest setRequestLevel(RequestLevel value) {
    requestLevel = value;
    return this;
  }

  TencentLocationRequest setAllowDirectionSensor(bool value) {
    allowDirectionSensor = value;
    return this;
  }

  // ---------- 平台扩展配置 ----------

  TencentLocationRequest android(
      void Function(TencentLocationRequestAndroidExtension ext) configure) {
    configure(_android);
    return this;
  }

  TencentLocationRequest ios(
      void Function(TencentLocationRequestIosExtension ext) configure) {
    configure(_ios);
    return this;
  }

  TencentLocationRequest harmony(
      void Function(TencentLocationRequestHarmonyExtension ext) configure) {
    configure(_harmony);
    return this;
  }

  /// 只读访问（给 Utils / 测试 / 序列化用）。
  TencentLocationRequestAndroidExtension get androidExtension => _android;
  TencentLocationRequestIosExtension get iosExtension => _ios;
  TencentLocationRequestHarmonyExtension get harmonyExtension => _harmony;

  /// 深拷贝（对应 Android `TencentLocationRequest.copy(to, from)`）。
  TencentLocationRequest copy() {
    final dst = TencentLocationRequest._();
    dst
      ..interval = interval
      ..coordinateType = coordinateType
      ..requestLevel = requestLevel
      ..allowDirectionSensor = allowDirectionSensor;

    // Android
    final a = dst._android;
    a
      ..locMode = _android.locMode
      ..gnssSource = _android.gnssSource
      ..allowGps = _android.allowGps
      ..allowBle = _android.allowBle
      ..allowCache = _android.allowCache
      ..gpsFirst = _android.gpsFirst
      ..gpsFirstTimeout = _android.gpsFirstTimeout
      ..firstLocationTimeout = _android.firstLocationTimeout
      ..firstLocationNeedAddress = _android.firstLocationNeedAddress
      ..indoorMode = _android.indoorMode
      ..scene = _android.scene
      ..smallAppKey = _android.smallAppKey
      ..qq = _android.qq
      ..phoneNumber = _android.phoneNumber
      ..reGeoCodingKey = _android.reGeoCodingKey;

    // iOS
    final i = dst._ios;
    i
      ..desiredAccuracy = _ios.desiredAccuracy
      ..allowsBackgroundLocationUpdates = _ios.allowsBackgroundLocationUpdates
      ..distanceFilter = _ios.distanceFilter
      ..pausesLocationUpdatesAutomatically =
          _ios.pausesLocationUpdatesAutomatically
      ..activityType = _ios.activityType
      ..headingFilter = _ios.headingFilter
      ..headingOrientation = _ios.headingOrientation
      ..poiUpdateInterval = _ios.poiUpdateInterval
      ..singleLocationTimeout = _ios.singleLocationTimeout;

    // Harmony
    final h = dst._harmony;
    h
      ..userActivityScenario = _harmony.userActivityScenario
      ..powerConsumptionScenario = _harmony.powerConsumptionScenario
      ..locatingPriority = _harmony.locatingPriority
      ..innerInterval = _harmony.innerInterval
      ..reverseGeocodeRequestInterval = _harmony.reverseGeocodeRequestInterval
      ..firstLocationCachePolicy = _harmony.firstLocationCachePolicy
      ..singleLocationTimeout = _harmony.singleLocationTimeout;

    return dst;
  }

  /// 序列化（形如 `{common:{}, android:{}, ios:{}, harmony:{}}`）。
  Map<String, Object?> toMap() => <String, Object?>{
        'common': <String, Object?>{
          'intervalMs': interval.inMilliseconds,
          'coordinateType': coordinateType.wireName,
          'requestLevel': requestLevel.wireName,
          'allowDirectionSensor': allowDirectionSensor,
        },
        'android': _android.toMap(),
        'ios': _ios.toMap(),
        'harmony': _harmony.toMap(),
      };
}
