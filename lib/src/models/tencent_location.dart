import '../enums/coordinate_type.dart';
import '../enums/location_source.dart';
import 'tencent_geo_address.dart';
import 'tencent_poi.dart';

/// 一次定位的结果。
///
/// **映射来源**：
/// - Android `TencentLocation`
/// - iOS `TencentLBSLocation`
/// - Harmony `TencentLocation`
///
/// 字段顺序按 common → Android / iOS / Harmony 专属分组。
class TencentLocation {
  // ---------- 核心经纬度（通用）----------

  /// 纬度。
  final double? latitude;

  /// 经度。
  final double? longitude;

  /// 海拔，单位米。仅 GNSS 有效。
  final double? altitude;

  /// 水平精度，单位米。
  final double? accuracy;

  /// 方向角（course），单位度。仅 GNSS 有效。
  final double? bearing;

  /// 速度，单位 m/s。仅 GNSS 有效。
  final double? speed;

  /// 传感器方向。仅在 request 的 `allowDirectionSensor=true` 时有值。
  final double? directionFromSensor;

  // ---------- 时间（通用）----------

  /// Unix 时间戳（毫秒）。
  final int? time;

  // ---------- 来源 / 坐标系（通用）----------

  /// 三端分组枚举。用扩展方法 `.isGnss` / `.isNetwork` / `.isCached` 做跨端归类。
  final LocationSource source;

  /// 坐标系。
  final CoordinateType coordinateType;

  // ---------- 地址 / POI（通用）----------

  /// 逆地理信息。`request.requestLevel` 达到 `name` 及以上时有值。
  final TencentGeoAddress? geoAddress;

  /// 周边 POI 列表。`request.requestLevel == poi` 才有。
  final List<TencentPoi> poiList;

  // ---------- 室内（通用）----------

  /// 室内建筑 ID。
  final String? indoorBuildingId;

  /// 室内楼层。
  final String? indoorBuildingFloor;

  // ---------- 🅰️ Android 专属 ----------

  /// 设备启动后毫秒数。仅 Android 有。
  final int? elapsedRealtime;

  /// GPS 信号强度：`0`(无) / `1`(弱) / `2`(中) / `3`(强)。仅 Android 有。
  final int? gpsRssi;

  // ---------- 🍏 iOS 专属 ----------

  /// 垂直精度，单位米。仅 iOS 有。
  final double? verticalAccuracy;

  // ---------- 🔶 Harmony 专属 ----------

  /// 缓存来源：`'none'` / `'sdk'` / `'system'`。
  ///
  /// 对应 Harmony `TencentLocation.getCacheSource()`。Android / iOS 端恒为 `'none'`
  /// （Android 的缓存信息通过 `source == LocationSource.androidCache` 表达）。
  final String cacheSource;

  // ---------- 扩展（通用）----------

  /// 原生附加键值对。
  final Map<String, Object?> extras;

  const TencentLocation({
    this.latitude,
    this.longitude,
    this.altitude,
    this.accuracy,
    this.bearing,
    this.speed,
    this.directionFromSensor,
    this.time,
    this.source = LocationSource.unknown,
    this.coordinateType = CoordinateType.gcj02,
    this.geoAddress,
    this.poiList = const [],
    this.indoorBuildingId,
    this.indoorBuildingFloor,
    this.elapsedRealtime,
    this.gpsRssi,
    this.verticalAccuracy,
    this.cacheSource = 'none',
    this.extras = const {},
  });

  factory TencentLocation.fromMap(Map map) {
    final rawPois = map['poiList'];
    final poiList = <TencentPoi>[];
    if (rawPois is List) {
      for (final p in rawPois) {
        if (p is Map) poiList.add(TencentPoi.fromMap(p));
      }
    }

    TencentGeoAddress? geoAddress;
    final rawGeo = map['geoAddress'];
    if (rawGeo is Map) geoAddress = TencentGeoAddress.fromMap(rawGeo);

    final rawExtras = map['extras'];
    final extras = <String, Object?>{};
    if (rawExtras is Map) {
      rawExtras.forEach((key, value) {
        if (key is String) extras[key] = value;
      });
    }

    return TencentLocation(
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      bearing: (map['bearing'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      directionFromSensor: (map['directionFromSensor'] as num?)?.toDouble(),
      time: map['time'] as int?,
      source: LocationSourceX.fromWire(map['source'] as String?),
      coordinateType:
          CoordinateTypeCodec.fromWire(map['coordinateType'] as String?) ??
              CoordinateType.gcj02,
      geoAddress: geoAddress,
      poiList: poiList,
      indoorBuildingId: map['indoorBuildingId'] as String?,
      indoorBuildingFloor: map['indoorBuildingFloor'] as String?,
      elapsedRealtime: map['elapsedRealtime'] as int?,
      gpsRssi: map['gpsRssi'] as int?,
      verticalAccuracy: (map['verticalAccuracy'] as num?)?.toDouble(),
      cacheSource: (map['cacheSource'] as String?) ?? 'none',
      extras: extras,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'accuracy': accuracy,
        'bearing': bearing,
        'speed': speed,
        'directionFromSensor': directionFromSensor,
        'time': time,
        'source': source.wireName,
        'coordinateType': coordinateType.wireName,
        'geoAddress': geoAddress?.toMap(),
        'poiList': poiList.map((p) => p.toMap()).toList(),
        'indoorBuildingId': indoorBuildingId,
        'indoorBuildingFloor': indoorBuildingFloor,
        'elapsedRealtime': elapsedRealtime,
        'gpsRssi': gpsRssi,
        'verticalAccuracy': verticalAccuracy,
        'cacheSource': cacheSource,
        'extras': extras,
      };

  @override
  String toString() =>
      'TencentLocation(lat=$latitude, lng=$longitude, accuracy=$accuracy, '
      'source=${source.wireName}, coordinateType=${coordinateType.wireName})';
}
