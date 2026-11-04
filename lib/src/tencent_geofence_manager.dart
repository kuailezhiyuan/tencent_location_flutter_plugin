import 'dart:async';

import 'enums/ios_enums.dart';
import 'internal/manager_id_generator.dart';
import 'models/tencent_geofence.dart';
import 'models/tencent_geofence_event.dart';
import 'models/tencent_location_coordinate.dart';
import 'models/tencent_location_error.dart';
import 'platform_interface/tencent_location_platform.dart';

/// 腾讯地理围栏管理器。
///
/// 支持创建多个实例，各实例的围栏与监听互相独立。
class TencentGeofenceManager {
  final String _id;
  bool _disposed = false;

  TencentGeofenceManager()
      : _id = ManagerIdGenerator.nextGeofenceManagerId() {
    _readyFuture = _platform.createGeofenceManager(_id);
  }

  TencentLocationPlatform get _platform => TencentLocationPlatform.instance;

  late final Future<void> _readyFuture;

  void _ensureAlive() {
    if (_disposed) {
      throw StateError('TencentGeofenceManager($_id) has been disposed.');
    }
  }

  Future<T> _after<T>(Future<T> Function() fn) async {
    _ensureAlive();
    await _readyFuture;
    _ensureAlive();
    return fn();
  }

  /// 本实例的唯一 ID。
  ///
  /// **Returns**:
  /// - 由插件分配的实例标识符，可用于日志排查。
  String get id => _id;

  /// 释放本实例资源。
  ///
  /// 调用后该实例上的所有围栏与事件订阅都会被清理；之后再调用本实例的任何
  /// 方法都会抛出 [StateError]。重复调用本方法是安全的。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _platform.disposeGeofenceManager(_id);
    } catch (_) {
      // 幂等
    }
  }

  // ==================== 围栏管理 ====================

  /// 添加围栏。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：仅支持圆形围栏（[TencentGeofence] 为 polygon / district 时
  ///   抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`））
  ///
  /// **Parameters**:
  /// - [fence]：围栏定义，包含唯一 ID、类型、坐标、半径、监听事件等参数。
  ///
  /// **Returns**:
  /// - 返回仅表示围栏已提交给 SDK。district（行政区）围栏为异步创建：提交后
  ///   SDK 需要网络请求行政区边界，创建完成后通过 [onGeofenceCreated] 通知，
  ///   失败时通过 [onError] 通知（错误码 `geofenceDistrictNotFound` /
  ///   `geofenceInvalidRegion`，可用 [TencentLocationError.details] 的
  ///   `geofenceId` 定位对应围栏）。circle / polygon 为同步添加，不受此影响。
  ///
  /// **Throws**:
  /// 失败时抛出 [TencentLocationError]，可能的错误码：
  /// `geofenceDuplicateId` / `geofenceInvalidRegion` / `geofenceLimitExceeded` /
  /// `geofenceNetworkFailed` / `geofenceDistrictNotFound` /
  /// `unsupportedOnThisPlatform`。
  Future<void> addGeofence(TencentGeofence fence) =>
      _after(() => _platform.addGeofence(_id, fence));

  /// 按 ID 移除单个围栏。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Parameters**:
  /// - [id]：围栏的唯一标识符（即 [TencentGeofence.id]）。
  ///
  /// **Throws**:
  /// 当 ID 不存在时抛出 [TencentLocationError]（错误码 `geofenceIdNotFound`）。
  Future<void> removeGeofence(String id) =>
      _after(() => _platform.removeGeofence(_id, id));

  /// 移除本实例上的所有围栏。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  Future<void> removeAllGeofences() =>
      _after(() => _platform.removeAllGeofences(_id));

  /// 获取本实例上所有有效围栏。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Returns**:
  /// - 当前实例下所有处于有效状态的围栏列表，顺序与添加顺序无关。
  Future<List<TencentGeofence>> getAllGeofences() =>
      _after(() => _platform.getAllGeofences(_id));

  // ==================== 事件流 ====================

  /// 围栏触发事件流（进入 / 离开 / 停留 / 状态变化等）。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Returns**:
  /// - 围栏事件的广播 [Stream]，可订阅多次。
  Stream<TencentGeofenceEvent> get onEvent => _platform.onGeofenceEvent(_id);

  /// 围栏操作错误流。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Returns**:
  /// - 围栏操作过程中产生的错误的广播 [Stream]，可订阅多次。
  Stream<TencentLocationError> get onError => _platform.onGeofenceError(_id);

  /// 行政区围栏异步创建完成事件流。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：订阅成功但不会收到事件（不支持行政区围栏）
  ///
  /// **Returns**:
  /// - [GeofenceType.district] 围栏异步创建完成（已加入围栏列表）时发出
  ///   [TencentGeofenceCreatedEvent]；circle / polygon 为同步添加，不触发。
  /// - 事件中的 [TencentGeofenceCreatedEvent.geofenceId] 与 `addGeofence` 传入
  ///   的原始 id 一致（详见该字段注释）。
  Stream<TencentGeofenceCreatedEvent> get onGeofenceCreated =>
      _platform.onGeofenceCreated(_id);

  // ==================== 状态查询 ====================

  /// 判断指定坐标是否位于指定围栏内。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [id]：围栏的唯一标识符。
  /// - [coordinate]：待检测的坐标，坐标系需与围栏自身的坐标系一致。
  ///
  /// **Returns**:
  /// - `true` 表示坐标位于围栏内，否则返回 `false`。
  Future<bool> isCoordinateInside(
          String id, TencentLocationCoordinate coordinate) =>
      _after(() => _platform.isCoordinateInside(_id, id, coordinate));

  /// 获取包含指定坐标的所有围栏。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [coordinate]：待检测的坐标，坐标系需与围栏自身的坐标系一致。
  ///
  /// **Returns**:
  /// - 所有包含该坐标的围栏列表；若没有围栏命中则返回空列表。
  Future<List<TencentGeofence>> geofenceRegionsContainingCoordinate(
          TencentLocationCoordinate coordinate) =>
      _after(() =>
          _platform.geofenceRegionsContainingCoordinate(_id, coordinate));

  // ==================== 监控生命周期 ====================

  /// 开始监控本实例上已添加的所有围栏。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  Future<void> startMonitoring() =>
      _after(() => _platform.startMonitoring(_id));

  /// 停止监控所有围栏。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  Future<void> stopMonitoring() =>
      _after(() => _platform.stopMonitoring(_id));

  /// 暂停围栏监控（保留围栏数据，仅暂停位置检测）。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  Future<void> pauseMonitoring() =>
      _after(() => _platform.pauseMonitoring(_id));

  /// 恢复已暂停的围栏监控。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  Future<void> resumeMonitoring() =>
      _after(() => _platform.resumeMonitoring(_id));

  /// 查询围栏监控当前是否正在运行。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Returns**:
  /// - `true` 表示监控正在进行中，`false` 表示已停止或暂停。
  Future<bool> isMonitoring() => _after(() => _platform.isMonitoring(_id));

  // ==================== iOS 专属属性 ====================

  /// 是否允许后台围栏位置更新。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`)
  ///
  /// **Parameters**:
  /// - [enabled]：是否允许后台位置更新。`true` 允许，`false` 禁止。
  Future<void> setIosAllowsBackgroundLocationUpdates(bool enabled) => _after(
      () => _platform.setIosAllowsBackgroundLocationUpdates(_id, enabled));

  /// 是否启用自适应距离过滤器（智能频率控制）。
  ///
  /// 启用后 SDK 会根据当前位置到最近围栏边界的距离动态调整定位频率，距离越
  /// 近频率越高、距离越远频率越低，以平衡检测精度与功耗。启用期间手动设置
  /// 的距离过滤值不会生效。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [enabled]：是否启用自适应距离过滤器。
  Future<void> setIosAdaptiveDistanceFilterEnabled(bool enabled) => _after(
      () => _platform.setIosAdaptiveDistanceFilterEnabled(_id, enabled));

  /// 设置围栏检测使用的最小更新距离（米）。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [meters]：触发位置更新所需的最小水平移动距离，单位米。
  Future<void> setIosDistanceFilter(double meters) =>
      _after(() => _platform.setIosDistanceFilter(_id, meters));

  /// 设置围栏检测使用的期望定位精度。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [accuracy]：期望的定位精度等级。
  Future<void> setIosDesiredAccuracy(IosDesiredAccuracy accuracy) =>
      _after(() => _platform.setIosDesiredAccuracy(_id, accuracy));

  /// 设置围栏检测频率间隔。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [interval]：相邻两次围栏检测的最小时间间隔；传 [Duration.zero] 表示
  ///   每次位置更新都检测。
  Future<void> setIosDetectionInterval(Duration interval) =>
      _after(() => _platform.setIosDetectionInterval(_id, interval));
}
