/// 定位结果的来源。
///
/// **设计原则**：**诚实分组 + 扩展方法**。枚举值按平台
/// 前缀分组，同时提供跨端归类的扩展方法 —— 用户想精确控制用枚举值，
/// 想通用判断用 [LocationSourceX]。
///
/// **映射来源**：
/// - Android：`TencentLocation` 的 `*_PROVIDER` 字符串常量（GPS/NETWORK/CELL/WIFI/
///   CACHE/BEIDOU/RTK/SINGLE/COARSE/FUSED）；其他映射为 [unknown]
/// - iOS：`TencentLBSLocationProvider { GPS=0, NetWork=1, Simulated=2, AccessoryGPS=3,
///   AccessoryNetwork=4 }`
/// - Harmony：`TencentLocationConstant.LocationSource { GNSS=1, NETWORK=2, INDOOR=3, RTK=4 }`
enum LocationSource {
  /// 未知 / 未提供。所有平台通用。
  unknown,

  // ---------- 🅰️ Android ----------
  /// Android `GPS_PROVIDER`（`"gps"`）。
  androidGps,

  /// Android `NETWORK_PROVIDER`（`"network"`）。
  androidNetwork,

  /// Android `CELL_PROVIDER`（`"cell"`）。
  androidCell,

  /// Android `WIFI_PROVIDER`（`"wifi"`）。
  androidWifi,

  /// Android `CACHE_PROVIDER`（`"cache"`）。
  androidCache,

  /// Android `BEIDOU_PROVIDER`（`"beidou"`）。
  androidBeidou,

  /// Android `RTK_PROVIDER`（`"rtk"`）。
  androidRtk,

  /// Android `SINGLE_PROVIDER`（`"single"`）。
  androidSingle,

  /// Android `COARSE_PROVIDER`（`"coarse"`）。
  androidCoarse,

  /// Android `FUSED_PROVIDER`（`"fused"`）。
  androidFused,

  // ---------- 🍏 iOS ----------
  /// iOS `TencentLBSLocationProviderGPS`。
  iosGps,

  /// iOS `TencentLBSLocationProviderNetWork`。
  iosNetwork,

  /// iOS `TencentLBSLocationProviderSimulated`。
  iosSimulated,

  /// iOS `TencentLBSLocationProviderAccessoryGPS`（外设 GPS）。
  iosAccessoryGps,

  /// iOS `TencentLBSLocationProviderAccessoryNetwork`（外设网络）。
  iosAccessoryNetwork,

  // ---------- 🔶 Harmony ----------
  /// Harmony `LocationSource.GNSS`。
  harmonyGnss,

  /// Harmony `LocationSource.NETWORK`。
  harmonyNetwork,

  /// Harmony `LocationSource.INDOOR`。
  harmonyIndoor,

  /// Harmony `LocationSource.RTK`。
  harmonyRtk,
}

/// 跨平台归类扩展（按语义分组，不是平台分组）。
///
/// 用户不需要关心平台，直接用 `.isGnss` / `.isNetwork` / `.isCached` 等即可。
extension LocationSourceX on LocationSource {
  /// 是否为任一端的卫星定位来源（GPS / 北斗 / RTK / GNSS）。
  bool get isGnss {
    switch (this) {
      case LocationSource.androidGps:
      case LocationSource.androidBeidou:
      case LocationSource.androidRtk:
      case LocationSource.androidSingle:
      case LocationSource.iosGps:
      case LocationSource.iosAccessoryGps:
      case LocationSource.harmonyGnss:
      case LocationSource.harmonyRtk:
        return true;
      default:
        return false;
    }
  }

  /// 是否为任一端的网络定位来源（Wi-Fi / 基站 / Network）。
  bool get isNetwork {
    switch (this) {
      case LocationSource.androidNetwork:
      case LocationSource.androidCell:
      case LocationSource.androidWifi:
      case LocationSource.androidCoarse:
      case LocationSource.iosNetwork:
      case LocationSource.iosAccessoryNetwork:
      case LocationSource.harmonyNetwork:
        return true;
      default:
        return false;
    }
  }

  /// 是否为缓存定位来源。
  ///
  /// Android 通过枚举 [LocationSource.androidCache] 表达；iOS 无缓存机制；
  /// Harmony 的缓存信息在 `TencentLocation.cacheSource` 字段（因为鸿蒙原生
  /// [LocationSource] 没有缓存值，缓存是独立维度），本扩展在 Harmony 上
  /// 恒返回 `false`；Harmony 判缓存请直接读 `TencentLocation.cacheSource`。
  bool get isCached => this == LocationSource.androidCache;

  /// 是否为室内高精度定位（仅 Harmony 原生有此枚举值）。
  bool get isIndoor => this == LocationSource.harmonyIndoor;

  /// 是否为融合定位（仅 Android 原生有此枚举值）。
  bool get isFused => this == LocationSource.androidFused;

  /// 给 channel 的字符串名。
  String get wireName {
    switch (this) {
      case LocationSource.unknown:
        return 'unknown';
      case LocationSource.androidGps:
        return 'androidGps';
      case LocationSource.androidNetwork:
        return 'androidNetwork';
      case LocationSource.androidCell:
        return 'androidCell';
      case LocationSource.androidWifi:
        return 'androidWifi';
      case LocationSource.androidCache:
        return 'androidCache';
      case LocationSource.androidBeidou:
        return 'androidBeidou';
      case LocationSource.androidRtk:
        return 'androidRtk';
      case LocationSource.androidSingle:
        return 'androidSingle';
      case LocationSource.androidCoarse:
        return 'androidCoarse';
      case LocationSource.androidFused:
        return 'androidFused';
      case LocationSource.iosGps:
        return 'iosGps';
      case LocationSource.iosNetwork:
        return 'iosNetwork';
      case LocationSource.iosSimulated:
        return 'iosSimulated';
      case LocationSource.iosAccessoryGps:
        return 'iosAccessoryGps';
      case LocationSource.iosAccessoryNetwork:
        return 'iosAccessoryNetwork';
      case LocationSource.harmonyGnss:
        return 'harmonyGnss';
      case LocationSource.harmonyNetwork:
        return 'harmonyNetwork';
      case LocationSource.harmonyIndoor:
        return 'harmonyIndoor';
      case LocationSource.harmonyRtk:
        return 'harmonyRtk';
    }
  }

  /// 从 channel 字符串名解析。无法解析时返回 [LocationSource.unknown]。
  static LocationSource fromWire(String? wire) {
    if (wire == null) return LocationSource.unknown;
    for (final value in LocationSource.values) {
      if (value.wireName == wire) return value;
    }
    return LocationSource.unknown;
  }
}
