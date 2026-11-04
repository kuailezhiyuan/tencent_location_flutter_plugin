/// 坐标系类型。
///
/// **映射来源**：
/// - Android `TencentLocationManager.COORDINATE_TYPE_GCJ02`=1 / `WGS84`=0
/// - iOS `TencentLBSLocationCoordinateTypeGCJ02`=0 / `Wgs84`=1
/// - Harmony `CoordinateType.WGS84`=1 / `GCJ02`=2
///
/// 三端整数值不一致，插件内部用字符串 `"gcj02"` / `"wgs84"` 传递，
/// 由各端原生层再映射到本地枚举值。
enum CoordinateType {
  /// GCJ-02 火星坐标系，**默认值**。
  gcj02,

  /// WGS-84 地球坐标系（GPS 原始）。
  wgs84,
}

/// 字符串 codec，用于 channel 传输。
extension CoordinateTypeCodec on CoordinateType {
  String get wireName {
    switch (this) {
      case CoordinateType.gcj02:
        return 'gcj02';
      case CoordinateType.wgs84:
        return 'wgs84';
    }
  }

  static CoordinateType? fromWire(String? wire) {
    for (final value in CoordinateType.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}
