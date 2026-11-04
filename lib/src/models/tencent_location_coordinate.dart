/// 经纬度值对象，三端通用的基础类型。
///
/// **映射来源**：
/// - Android `TencentGeofence.FencePoint`（内部类）+ `distanceBetween` 等方法的入参
/// - iOS `CLLocationCoordinate2D`
/// - Harmony `TencentGeofence` 的 `latitude + longitude` 平铺字段
class TencentLocationCoordinate {
  /// 纬度，范围 `[-90, 90]`。
  final double latitude;

  /// 经度，范围 `[-180, 180]`。
  final double longitude;

  const TencentLocationCoordinate({
    required this.latitude,
    required this.longitude,
  });

  factory TencentLocationCoordinate.fromMap(Map map) {
    return TencentLocationCoordinate(
      latitude: ((map['latitude'] as num?) ?? 0).toDouble(),
      longitude: ((map['longitude'] as num?) ?? 0).toDouble(),
    );
  }

  Map<String, Object?> toMap() =>
      <String, Object?>{'latitude': latitude, 'longitude': longitude};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TencentLocationCoordinate &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'TencentLocationCoordinate($latitude, $longitude)';
}
