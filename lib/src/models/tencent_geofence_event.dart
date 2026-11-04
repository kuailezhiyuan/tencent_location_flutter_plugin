import '../enums/geofence_enums.dart';
import 'tencent_location.dart';

/// 围栏触发事件。
///
/// **映射来源**：
/// - Android：`PendingIntent` extras 中的 `fence_tag` + `transition`
/// - iOS delegate：`didEnterRegion` / `didExitRegion` / `didStayInRegion:forDuration:`
/// - Harmony：`TencentGeofenceEvent { id, event }`
class TencentGeofenceEvent {
  /// 对应的围栏 ID。
  final String geofenceId;

  /// 事件类型。
  final GeofenceTransition transition;

  /// 触发时位置（部分平台可能为 `null`）。
  final TencentLocation? location;

  /// [GeofenceTransition.dwell] 事件的已停留时长；其他事件为 `null`。
  final Duration? stayedDuration;

  /// 创建围栏时附带的 `userInfo`（iOS / Dart 层透传）。
  final Map<String, Object?>? userInfo;

  const TencentGeofenceEvent({
    required this.geofenceId,
    required this.transition,
    this.location,
    this.stayedDuration,
    this.userInfo,
  });

  factory TencentGeofenceEvent.fromMap(Map map) {
    TencentLocation? loc;
    final rawLoc = map['location'];
    if (rawLoc is Map) loc = TencentLocation.fromMap(rawLoc);

    Duration? stayed;
    final rawStayed = map['stayedDurationMs'];
    if (rawStayed is num) stayed = Duration(milliseconds: rawStayed.toInt());

    Map<String, Object?>? userInfo;
    final rawInfo = map['userInfo'];
    if (rawInfo is Map) {
      userInfo = <String, Object?>{};
      rawInfo.forEach((k, v) {
        if (k is String) userInfo![k] = v;
      });
    }

    return TencentGeofenceEvent(
      geofenceId: (map['geofenceId'] as String?) ?? '',
      transition:
          GeofenceTransitionCodec.fromWire(map['transition'] as String?) ??
              GeofenceTransition.enter,
      location: loc,
      stayedDuration: stayed,
      userInfo: userInfo,
    );
  }

  @override
  String toString() =>
      'TencentGeofenceEvent($geofenceId: ${transition.wireName}'
      '${stayedDuration != null ? ', stayed=${stayedDuration!.inSeconds}s' : ''})';
}

/// 行政区围栏异步创建完成事件。
///
/// **触发场景**：district（行政区）围栏是异步创建的，`addGeofence` 的 Future
/// 成功仅表示"已提交"；本事件在该围栏真正创建完成（已加入围栏列表）时发出。
/// 创建失败走 [TencentLocationError] 事件流（`geofenceDistrictNotFound` /
/// `geofenceInvalidRegion` 等），不触发本事件。circle / polygon 为同步添加，
/// 不触发本事件。
class TencentGeofenceCreatedEvent {
  /// 已创建围栏的 id，与 [TencentGeofenceManager.addGeofence] 传入的
  /// [TencentGeofence.id] 一致（即开发者写入的原始 tag）。
  ///
  /// **注意**：Android 上 [TencentGeofenceManager.getAllGeofences] 在某些
  /// 情况下可能返回带行政区 adcode 后缀的 id（如 `district-1_110108`），
  /// 这是 SDK 内部 `mFences` 存储的 tag，与本事件的 id 表达不同——本事件
  /// 始终是 `addGeofence` 传入的原始 id。如需对齐两端，应以本事件为基准。
  final String geofenceId;

  /// 添加围栏时传入的 `userInfo`；平台拿不到时为 `null`。
  final Map<String, Object?>? userInfo;

  const TencentGeofenceCreatedEvent({
    required this.geofenceId,
    this.userInfo,
  });

  factory TencentGeofenceCreatedEvent.fromMap(Map map) {
    Map<String, Object?>? userInfo;
    final rawInfo = map['userInfo'];
    if (rawInfo is Map) {
      userInfo = <String, Object?>{};
      rawInfo.forEach((k, v) {
        if (k is String) userInfo![k] = v;
      });
    }

    return TencentGeofenceCreatedEvent(
      geofenceId: (map['geofenceId'] as String?) ?? '',
      userInfo: userInfo,
    );
  }

  @override
  String toString() => 'TencentGeofenceCreatedEvent($geofenceId)';
}
