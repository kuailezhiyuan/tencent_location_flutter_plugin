/// 围栏类型。
///
/// **映射来源**：
/// - Android `TencentGeofence.GEOFENCE_TYPE_CIRCLE/POLYGON/DISTRICT` = 0/1/2
/// - iOS `TencentLBSGeofenceRegionType { Circle=0, Polygon=1, District=2 }`
/// - Harmony 仅支持圆形
enum GeofenceType {
  /// 圆形围栏。三端都支持。
  circle,

  /// 多边形围栏。Android + iOS 支持；Harmony **不支持**。
  polygon,

  /// 行政区划围栏。Android + iOS 支持；Harmony **不支持**。
  district,
}

extension GeofenceTypeCodec on GeofenceType {
  String get wireName {
    switch (this) {
      case GeofenceType.circle:
        return 'circle';
      case GeofenceType.polygon:
        return 'polygon';
      case GeofenceType.district:
        return 'district';
    }
  }

  static GeofenceType? fromWire(String? wire) {
    for (final value in GeofenceType.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

/// 围栏事件类型。
///
/// **映射来源**：
/// - Android：系统 `LocationManager.addProximityAlert` + Intent extra
///   `KEY_PROXIMITY_ENTERING`（true=enter / false=exit），**不支持 dwell**
/// - iOS `TencentLBSGeofenceActiveAction` 位掩码：`None=0, Enter=1, Exit=2, Stayed=4`
/// - Harmony `GeofenceEvent.ENTER=1 / EXIT=2 / DWELL=4`（仅圆形支持）
enum GeofenceTransition {
  /// 进入围栏。
  enter,

  /// 离开围栏。
  exit,

  /// 在围栏内停留一段时间。
  ///
  /// - iOS：由 `TencentGeofence.dwellDuration` 决定（默认 600s，最小 60s）
  /// - Android：**不支持**（原生 dwell 固定 10 分钟且不可配置）。
  ///   传入 `dwell` 时该事件被忽略，控制台输出 warning，
  ///   `addGeofence` 仍然成功并按 enter + exit 监听
  /// - Harmony：由系统决定
  dwell,
}

extension GeofenceTransitionCodec on GeofenceTransition {
  String get wireName {
    switch (this) {
      case GeofenceTransition.enter:
        return 'enter';
      case GeofenceTransition.exit:
        return 'exit';
      case GeofenceTransition.dwell:
        return 'dwell';
    }
  }

  static GeofenceTransition? fromWire(String? wire) {
    for (final value in GeofenceTransition.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}
