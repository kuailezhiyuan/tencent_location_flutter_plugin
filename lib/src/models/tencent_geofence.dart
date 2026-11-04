import '../enums/coordinate_type.dart';
import '../enums/geofence_enums.dart';
import 'tencent_location_coordinate.dart';

/// 地理围栏。
///
/// **映射来源**：
/// - Android `TencentGeofence.Builder`（三形态：circle / polygon / district）
/// - iOS `TencentLBSGeofenceCircleRegion` / `PolygonRegion` / `DistrictRegion`
/// - Harmony `TencentGeofence`（仅圆形支持）
///
/// 当某字段或事件在当前平台原生不支持时，`addGeofence` **不会抛异常**，
/// 而是忽略该字段并在控制台输出 warning（前缀 `[TencentLocation]`）。
/// 各字段的具体平台支持差异见对应字段注释。
///
/// **注意**：[expiration]（有效期）在 Android 端应显式设置。SDK 对未设置
/// 有效期的围栏按 `duration=0` 处理，会立即判定为过期并清理，导致
/// `getAllGeofences` 查不到刚添加的围栏。
class TencentGeofence {
  /// 围栏唯一标识。
  final String id;

  /// 围栏形态。
  final GeofenceType type;

  /// 坐标系。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：原生 SDK 单例的**进程级**全局属性，与连续/单次定位共用同一个值；
  ///   同一进程里多个 `TencentGeofenceManager` / `TencentLocationManager` 实例互相覆盖
  ///   （后写入生效），不存在 per-instance 隔离。请保持各 fence / request 的坐标系一致。
  /// - 🍏 iOS：每个原生 manager 实例独立保存，per-instance 隔离。
  /// - 🔶 Harmony：每个原生 manager 实例独立保存，per-instance 隔离。
  final CoordinateType coordinateType;

  /// 有效期。
  /// - 🅰️ Android：对应 `Builder.setExpirationDuration(ms)`
  /// - 🍏 iOS：原生**不支持**，传入非 null 时该字段被忽略，控制台输出 warning；
  ///   围栏将一直有效直到显式 `removeGeofence`
  /// - 🔶 Harmony：对应 `TencentGeofence.expiration(s)`
  final Duration? expiration;

  /// 监听事件集合（enter / exit / dwell 任意组合）。
  /// - 🅰️ Android：原生固定 enter + exit；包含 `dwell` 时该事件被忽略，
  ///   控制台输出 warning（原生 dwell 固定 10 分钟不可配置）
  /// - 🍏 iOS：映射 `TencentLBSGeofenceActiveAction` 位掩码
  /// - 🔶 Harmony：映射 `monitorEvents` 数组（仅支持圆形）
  final Set<GeofenceTransition> monitorTransitions;

  /// 停留事件的触发阈值。仅当 [monitorTransitions] 含 [GeofenceTransition.dwell] 时有效。
  /// - 🍏 iOS：`stayedDuration`，默认 600s，最小 60s
  /// - 🔶 Harmony：由系统决定
  final Duration? dwellDuration;

  /// 自定义附加信息（随事件回调带回）。
  final Map<String, Object?>? userInfo;

  // ---------- circle ----------

  /// 圆心。仅 [type] 为 [GeofenceType.circle] 时使用。
  final TencentLocationCoordinate? center;

  /// 半径，单位米。仅 [type] 为 [GeofenceType.circle] 时使用。
  final double? radius;

  // ---------- polygon ----------

  /// 多边形顶点（≥3 且不重复）。仅 [type] 为 [GeofenceType.polygon] 时使用。
  final List<TencentLocationCoordinate>? polygon;

  // ---------- district ----------

  /// 行政区划关键字：adcode（如 `"110108"`）或中文名称（如 `"海淀区"`）。
  /// 仅 [type] 为 [GeofenceType.district] 时使用。
  final String? districtKeyword;

  const TencentGeofence._({
    required this.id,
    required this.type,
    required this.coordinateType,
    required this.monitorTransitions,
    this.expiration,
    this.dwellDuration,
    this.userInfo,
    this.center,
    this.radius,
    this.polygon,
    this.districtKeyword,
  });

  /// 圆形围栏。
  factory TencentGeofence.circle({
    required String id,
    required TencentLocationCoordinate center,
    required double radius,
    CoordinateType coordinateType = CoordinateType.gcj02,
    Duration? expiration,
    Set<GeofenceTransition> monitorTransitions = const {
      GeofenceTransition.enter,
      GeofenceTransition.exit,
    },
    Duration? dwellDuration,
    Map<String, Object?>? userInfo,
  }) {
    return TencentGeofence._(
      id: id,
      type: GeofenceType.circle,
      coordinateType: coordinateType,
      monitorTransitions: monitorTransitions,
      expiration: expiration,
      dwellDuration: dwellDuration,
      userInfo: userInfo,
      center: center,
      radius: radius,
    );
  }

  /// 多边形围栏。
  factory TencentGeofence.polygon({
    required String id,
    required List<TencentLocationCoordinate> vertices,
    CoordinateType coordinateType = CoordinateType.gcj02,
    Duration? expiration,
    Set<GeofenceTransition> monitorTransitions = const {
      GeofenceTransition.enter,
      GeofenceTransition.exit,
    },
    Duration? dwellDuration,
    Map<String, Object?>? userInfo,
  }) {
    return TencentGeofence._(
      id: id,
      type: GeofenceType.polygon,
      coordinateType: coordinateType,
      monitorTransitions: monitorTransitions,
      expiration: expiration,
      dwellDuration: dwellDuration,
      userInfo: userInfo,
      polygon: List<TencentLocationCoordinate>.unmodifiable(vertices),
    );
  }

  /// 行政区划围栏。
  factory TencentGeofence.district({
    required String id,
    required String keyword,
    CoordinateType coordinateType = CoordinateType.gcj02,
    Duration? expiration,
    Set<GeofenceTransition> monitorTransitions = const {
      GeofenceTransition.enter,
      GeofenceTransition.exit,
    },
    Duration? dwellDuration,
    Map<String, Object?>? userInfo,
  }) {
    return TencentGeofence._(
      id: id,
      type: GeofenceType.district,
      coordinateType: coordinateType,
      monitorTransitions: monitorTransitions,
      expiration: expiration,
      dwellDuration: dwellDuration,
      userInfo: userInfo,
      districtKeyword: keyword,
    );
  }

  factory TencentGeofence.fromMap(Map map) {
    final type = GeofenceTypeCodec.fromWire(map['type'] as String?) ??
        GeofenceType.circle;

    final coord =
        CoordinateTypeCodec.fromWire(map['coordinateType'] as String?) ??
            CoordinateType.gcj02;

    final transitions = <GeofenceTransition>{};
    final rawTrans = map['monitorTransitions'];
    if (rawTrans is List) {
      for (final t in rawTrans) {
        final parsed = GeofenceTransitionCodec.fromWire(t as String?);
        if (parsed != null) transitions.add(parsed);
      }
    }

    Duration? durationFromMs(Object? raw) {
      if (raw is int) return Duration(milliseconds: raw);
      if (raw is num) return Duration(milliseconds: raw.toInt());
      return null;
    }

    Map<String, Object?>? userInfo;
    final rawInfo = map['userInfo'];
    if (rawInfo is Map) {
      userInfo = <String, Object?>{};
      rawInfo.forEach((k, v) {
        if (k is String) userInfo![k] = v;
      });
    }

    TencentLocationCoordinate? center;
    final rawCenter = map['center'];
    if (rawCenter is Map) center = TencentLocationCoordinate.fromMap(rawCenter);

    List<TencentLocationCoordinate>? polygon;
    final rawPoly = map['polygon'];
    if (rawPoly is List) {
      polygon = <TencentLocationCoordinate>[
        for (final v in rawPoly)
          if (v is Map) TencentLocationCoordinate.fromMap(v),
      ];
    }

    return TencentGeofence._(
      id: (map['id'] as String?) ?? '',
      type: type,
      coordinateType: coord,
      monitorTransitions: transitions.isEmpty
          ? const {GeofenceTransition.enter, GeofenceTransition.exit}
          : transitions,
      expiration: durationFromMs(map['expirationMs']),
      dwellDuration: durationFromMs(map['dwellDurationMs']),
      userInfo: userInfo,
      center: center,
      radius: (map['radius'] as num?)?.toDouble(),
      polygon: polygon,
      districtKeyword: map['districtKeyword'] as String?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'type': type.wireName,
        'coordinateType': coordinateType.wireName,
        'expirationMs': expiration?.inMilliseconds,
        'monitorTransitions':
            monitorTransitions.map((t) => t.wireName).toList(),
        'dwellDurationMs': dwellDuration?.inMilliseconds,
        'userInfo': userInfo,
        'center': center?.toMap(),
        'radius': radius,
        'polygon': polygon?.map((c) => c.toMap()).toList(),
        'districtKeyword': districtKeyword,
      };
}
