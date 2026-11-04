/// 定位结果等级。
///
/// **映射来源**：三端同名，数值 0/1/3/4 一致。
/// - Android `TencentLocationRequest.REQUEST_LEVEL_GEO/NAME/ADMIN_AREA/POI`
/// - iOS `TencentLBSRequestLevelGeo/Name/AdminName/Poi`
/// - Harmony `RequestLevel.GEO/NAME/ADMIN_AREA/POI`
enum RequestLevel {
  /// 经纬度 + 海拔 + 精度。
  geo,

  /// + 名称 + 地址。
  name,

  /// + 行政区划。**默认值**。
  adminArea,

  /// + 周边 POI。
  poi,
}

extension RequestLevelCodec on RequestLevel {
  String get wireName {
    switch (this) {
      case RequestLevel.geo:
        return 'geo';
      case RequestLevel.name:
        return 'name';
      case RequestLevel.adminArea:
        return 'adminArea';
      case RequestLevel.poi:
        return 'poi';
    }
  }

  static RequestLevel? fromWire(String? wire) {
    for (final value in RequestLevel.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}
