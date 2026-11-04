import 'dart:async';

import 'internal/manager_id_generator.dart';
import 'models/tencent_device_orientation.dart';
import 'models/tencent_device_status.dart';
import 'models/tencent_location.dart';
import 'models/tencent_location_error.dart';
import 'models/tencent_location_request.dart';
import 'platform_interface/tencent_location_platform.dart';

/// 腾讯定位管理器。
///
/// 支持在同一应用内创建多个实例，各实例独立维护自己的事件流（[onLocationChanged]
/// / [onLocationError] / [onStatusChanged] / [onOrientationChanged]）和启停状态
/// （[startContinuousLocation] / [stopContinuousLocation]、前台服务、后台任务等）。
///
/// **多实例语义边界**
///
/// 事件分发到哪个实例是隔离的：A 实例的订阅者只会收到 A 实例触发的回调，与同
/// 时存在的 B 实例互不干扰。但部分配置类参数在底层是应用范围共享的，多个实例
/// 同时使用时，**后调用的一方会覆盖先前的设置**，包括但不限于：
///
/// - [startContinuousLocation] 传入的 [TencentLocationRequest]（间隔、坐标系、
///   逆地址等所有字段）；
/// - [changeCallbackInterval]；
/// - [getLastLocation]（返回的是应用最近一次的定位结果，不区分由哪个实例产生）。
///
/// 因此**不建议**在同一应用内同时启动多个连续定位实例并期望它们各自使用不同的
/// [TencentLocationRequest]。多实例的典型用途是：把单次定位、连续定位、地理围栏
/// 这类语义不同的能力拆到不同管理器里，便于在业务侧分别控制生命周期。
class TencentLocationManager {
  final String _id;

  bool _disposed = false;

  /// 标记是否已调用过 [startContinuousLocation]，用于重复调用检查。
  bool _continuousStarted = false;

  /// 创建一个新的定位管理器。
  ///
  /// 调用前必须已完成 [TencentLocationSDK.setPrivacyPolicyAgreement] 与
  /// [TencentLocationSDK.init]，否则后续方法会抛出 [TencentLocationError]
  /// （错误码 `privacyNotAgreed` / `apiKeyInvalid`）。
  TencentLocationManager() : _id = ManagerIdGenerator.nextLocationManagerId() {
    _readyFuture = _platform.createLocationManager(_id);
  }

  TencentLocationPlatform get _platform => TencentLocationPlatform.instance;

  late final Future<void> _readyFuture;

  void _ensureAlive() {
    if (_disposed) {
      throw StateError('TencentLocationManager($_id) has been disposed.');
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
  /// 调用后该实例上的所有定位监听、事件订阅与前台 / 后台任务都会被清理；
  /// 之后再调用本实例的任何方法都会抛出 [StateError]。重复调用本方法是
  /// 安全的。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _platform.disposeLocationManager(_id);
    } catch (_) {
      // 幂等
    }
  }

  // ==================== 连续定位 ====================

  /// 开始连续定位。结果通过 [onLocationChanged] 获取。
  ///
  /// 重复调用会抛出 [TencentLocationError]（错误码 `alreadyStarted`）。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Parameters**:
  /// - [request]：连续定位请求参数。
  Future<void> startContinuousLocation(TencentLocationRequest request) =>
      _after(() async {
        if (_continuousStarted) {
          throw const TencentLocationError(
            code: TencentLocationErrorCode.alreadyStarted,
            message: 'startContinuousLocation already called on this manager.',
          );
        }
        await _platform.startContinuousLocation(_id, request);
        _continuousStarted = true;
      });

  /// 停止连续定位。重复调用是安全的。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  Future<void> stopContinuousLocation() => _after(() async {
        if (!_continuousStarted) return;
        await _platform.stopContinuousLocation(_id);
        _continuousStarted = false;
      });

  /// 动态修改连续定位的回调频率。用于修改 Android 系统定位回调频率，可以降低系统定位次数的统计，
  /// 同时会修改 [onLocationChanged] 的回调频率，二者保持一致。
  ///
  /// 需要在 [startContinuousLocation] 之后调用才有意义；未启动连续定位时
  /// 调用此方法不会报错但也不会生效。
  ///
  /// 注意：本设置在应用内是共享的，调用本方法会影响当前所有正在运行的连续
  /// 定位实例的回调频率。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [interval]：新的回调间隔，建议不小于 1 秒。
  Future<void> changeCallbackInterval(Duration interval) =>
      _after(() => _platform.changeCallbackInterval(_id, interval));

  // ==================== 单次定位 ====================

  /// 请求单次定位。结果直接由返回的 [Future] 发出，不经过 [onLocationChanged]。
  ///
  /// 超时会抛出 [TencentLocationError]（错误码 `timeout`）；失败抛出
  /// `locationFailed`。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Parameters**:
  /// - [request]：单次定位请求参数。超时时长由各平台扩展字段控制：
  ///   Android 走 `androidExtension.firstLocationTimeout`（默认 15s），
  ///   iOS 走 `iosExtension.singleLocationTimeout`（默认 10s），
  ///   Harmony 走 `harmonyExtension.singleLocationTimeout`（默认 10s）。
  ///
  /// **Returns**:
  /// - 单次定位的结果。
  Future<TencentLocation> startSingleLocation(TencentLocationRequest request) =>
      _after(() => _platform.startSingleLocation(_id, request));

  // ==================== 最近位置 ====================

  /// 获取最近一次的定位结果。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：支持
  ///
  /// **Returns**:
  /// - 最近一次的定位结果；尚未产生定位结果时返回 `null`。
  Future<TencentLocation?> getLastLocation() =>
      _after(() => _platform.getLastLocation(_id));

  // ==================== 结果流 ====================

  /// 连续定位结果流。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Returns**:
  /// - 连续定位结果的广播 [Stream]，可订阅多次。
  Stream<TencentLocation> get onLocationChanged =>
      _platform.onLocationChanged(_id);

  /// 定位错误流。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Returns**:
  /// - 定位过程中产生的错误的广播 [Stream]，可订阅多次。
  Stream<TencentLocationError> get onLocationError =>
      _platform.onLocationError(_id);

  // ==================== 设备状态 ====================

  /// 设备状态事件流。订阅即开启监听，取消订阅即停止。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持（事件随连续定位回调一并产生）
  /// - 🍏 iOS：不支持，订阅成功但不会收到事件
  /// - 🔶 Harmony：支持
  ///
  /// **Returns**:
  /// - 设备状态变化的广播 [Stream]，可订阅多次；首次订阅时自动激活原生
  ///   监听，最后一个订阅者取消时自动停止。
  Stream<TencentDeviceStatus> get onStatusChanged =>
      _platform.onStatusChanged(_id);

  // ==================== 设备朝向 ====================

  /// 设备朝向事件流。订阅即开启监听，取消订阅即停止。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，订阅成功但不会收到事件
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Returns**:
  /// - 设备朝向变化的广播 [Stream]，可订阅多次；首次订阅时自动激活原生
  ///   监听，最后一个订阅者取消时自动停止。
  Stream<TencentDeviceOrientation> get onOrientationChanged =>
      _platform.onOrientationChanged(_id);

  /// 关闭系统弹出的朝向校准提示面板。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  Future<void> dismissIosHeadingCalibrationDisplay() =>
      _after(() => _platform.dismissIosHeadingCalibrationDisplay(_id));

  // ==================== 前台服务 / 后台任务 ====================

  /// 启用前台定位服务，让定位在应用进入后台时也能继续运行。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [notificationId]：前台通知的唯一 ID，必须大于 0。
  /// - [channelId]：Android O（API 26）及以上版本必填的
  ///   `NotificationChannel` ID。
  /// - [title]：通知栏展示的标题文案。
  /// - [text]：通知栏展示的正文文案。
  /// - [smallIconResourceName]：通知小图标的资源名（位于 `mipmap` /
  ///   `drawable` 下，不含扩展名）；为空时使用应用默认图标。
  Future<void> enableForeground({
    required int notificationId,
    required String channelId,
    required String title,
    required String text,
    String? smallIconResourceName,
  }) =>
      _after(() => _platform.enableForeground(
            managerId: _id,
            notificationId: notificationId,
            channelId: channelId,
            title: title,
            text: text,
            smallIconResourceName: smallIconResourceName,
          ));

  /// 关闭前台定位服务。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [removeNotification]：关闭服务时是否一并移除通知栏的通知。
  Future<void> disableForeground({bool removeNotification = true}) =>
      _after(() => _platform.disableForeground(
          managerId: _id, removeNotification: removeNotification));

  /// 开始后台定位任务。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：支持
  ///
  /// **Parameters**:
  /// - [wantAgentInfo]：鸿蒙后台任务所需的 `wantAgent.WantAgentInfo`，
  ///   原样透传给底层。
  Future<void> startBackgroundLocationTask(
          {Map<String, Object?>? wantAgentInfo}) =>
      _after(() => _platform.startBackgroundLocationTask(
            managerId: _id,
            wantAgentInfo: wantAgentInfo,
          ));

  /// 停止后台定位任务。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：支持
  Future<void> stopBackgroundLocationTask() =>
      _after(() => _platform.stopBackgroundLocationTask(_id));

  // ==================== iOS 实例附加数据 ====================

  /// 在本实例上设置 iOS 专属的附加数据。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [key]：附加数据的键。
  /// - [value]：附加数据的值。
  Future<void> setIosExtraData(String key, String value) =>
      _after(() => _platform.setIosExtraData(_id, key, value));
}
