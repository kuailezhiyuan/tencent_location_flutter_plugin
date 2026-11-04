/// 周边兴趣点（POI）。
///
/// **映射来源**：
/// - Android `TencentPoi` 接口
/// - iOS `TencentLBSPoi`
/// - Harmony `TencentPOI`
class TencentPoi {
  /// POI 名称。
  final String? name;

  /// POI 地址。
  final String? address;

  /// POI 类别（如"餐饮"、"公司"）。
  final String? catalog;

  /// 与定位中心的距离，单位米。
  final double? distance;

  /// POI 纬度。
  final double? latitude;

  /// POI 经度。
  final double? longitude;

  /// POI 唯一 ID。
  final String? uid;

  /// 方向（东/南/西/北/东南/西南/东北/西北/"内"/""）。
  ///
  /// **仅 Android 原生有此字段**，iOS / Harmony 为 `null`。
  final String? direction;

  const TencentPoi({
    this.name,
    this.address,
    this.catalog,
    this.distance,
    this.latitude,
    this.longitude,
    this.uid,
    this.direction,
  });

  factory TencentPoi.fromMap(Map map) {
    return TencentPoi(
      name: map['name'] as String?,
      address: map['address'] as String?,
      catalog: map['catalog'] as String?,
      distance: (map['distance'] as num?)?.toDouble(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      uid: map['uid'] as String?,
      direction: map['direction'] as String?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'name': name,
        'address': address,
        'catalog': catalog,
        'distance': distance,
        'latitude': latitude,
        'longitude': longitude,
        'uid': uid,
        'direction': direction,
      };

  @override
  String toString() =>
      'TencentPoi(name=$name, address=$address, catalog=$catalog, '
      'distance=$distance, lat=$latitude, lng=$longitude)';
}
