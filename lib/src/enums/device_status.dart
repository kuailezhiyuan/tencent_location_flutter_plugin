/// 设备 / 开关状态值。
///
/// **映射来源**：
/// - Android `TencentLocationListener.STATUS_*`：0=DISABLED, 1=ENABLED,
///   2=DENIED, 3=GPS_AVAILABLE, 4=GPS_UNAVAILABLE, 5=LOCATION_SWITCH_OFF, -1=UNKNOWN
/// - Harmony `TencentLocationConstant.DeviceStatus`（NET_* / LOCATION_SWITCH_*）
/// - iOS：不支持。
enum DeviceStatus {
  /// 未知。对应 Android `-1`。
  unknown,

  /// 开启且可用（GPS 搜星成功 / 网络可用 / 定位总开关开启）。
  /// 对应 Android `STATUS_ENABLED(1)` 和 `STATUS_GPS_AVAILABLE(3)`。
  available,

  /// 开启但不可用（例如 GPS 开着但搜不到星）。
  /// 对应 Android `STATUS_GPS_UNAVAILABLE(4)`。
  enabledButUnavailable,

  /// 关闭。对应 Android `STATUS_DISABLED(0)` 和 `STATUS_LOCATION_SWITCH_OFF(5)`。
  disabled,

  /// 权限被拒。对应 Android `STATUS_DENIED(2)`。
  denied,
}

extension DeviceStatusCodec on DeviceStatus {
  String get wireName {
    switch (this) {
      case DeviceStatus.unknown:
        return 'unknown';
      case DeviceStatus.available:
        return 'available';
      case DeviceStatus.enabledButUnavailable:
        return 'enabledButUnavailable';
      case DeviceStatus.disabled:
        return 'disabled';
      case DeviceStatus.denied:
        return 'denied';
    }
  }

  static DeviceStatus fromWire(String? wire) {
    for (final value in DeviceStatus.values) {
      if (value.wireName == wire) return value;
    }
    return DeviceStatus.unknown;
  }
}

/// 设备 / 能力类型。
enum DeviceStatusKind {
  /// GPS 芯片 / 定位引擎。Android `"gps"`。
  gps,

  /// Wi-Fi 网络。Android `"wifi"` / Harmony `NET_AVAILABLE_WIFI`。
  wifi,

  /// 蜂窝 / 基站。Android `"cell"` 与 `"radio"` 合并 / Harmony `NET_AVAILABLE_CELLULAR`。
  cellular,

  /// VPN。Harmony `NET_AVAILABLE_VPN`。
  vpn,

  /// 定位总开关。Android `STATUS_LOCATION_SWITCH_OFF` / Harmony `LOCATION_SWITCH_*`。
  locationSwitch,
}

extension DeviceStatusKindCodec on DeviceStatusKind {
  String get wireName {
    switch (this) {
      case DeviceStatusKind.gps:
        return 'gps';
      case DeviceStatusKind.wifi:
        return 'wifi';
      case DeviceStatusKind.cellular:
        return 'cellular';
      case DeviceStatusKind.vpn:
        return 'vpn';
      case DeviceStatusKind.locationSwitch:
        return 'locationSwitch';
    }
  }

  static DeviceStatusKind? fromWire(String? wire) {
    for (final value in DeviceStatusKind.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}
