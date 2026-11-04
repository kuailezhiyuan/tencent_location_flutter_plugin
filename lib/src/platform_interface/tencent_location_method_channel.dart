import 'dart:async';

import 'package:flutter/services.dart';

import '../enums/ios_enums.dart';
import '../models/tencent_device_orientation.dart';
import '../models/tencent_device_status.dart';
import '../models/tencent_geofence.dart';
import '../models/tencent_geofence_event.dart';
import '../models/tencent_location.dart';
import '../models/tencent_location_coordinate.dart';
import '../models/tencent_location_error.dart';
import '../models/tencent_location_request.dart';
import '../models/tencent_sdk_log_event.dart';
import 'tencent_location_platform.dart';

typedef _NativeLifecycleCallback = Future<void> Function();

/// 以一个 manager 的业务订阅数驱动原生监听生命周期。
///
/// [EventChannel] 仍是全局共享的；本对象只负责某个 `managerId` 的某一类事件。
/// 首个订阅者触发 [onStart]，最后一个取消触发 [onStop]。异步启停按顺序串行，
/// 因此订阅后立即取消也会按 `start → stop` 正确收敛，不会遗留原生监听。
class _ManagedManagerEventStream<T> {
  _ManagedManagerEventStream({
    required Stream<T> source,
    required this.onStart,
    required this.onStop,
  }) : _source = source;

  final Stream<T> _source;
  final _NativeLifecycleCallback onStart;
  final _NativeLifecycleCallback onStop;

  StreamController<T>? _controller;
  StreamSubscription<T>? _sourceSubscription;
  Future<void> _transition = Future<void>.value();
  bool _wanted = false;
  bool _nativeActive = false;
  bool _disposeRequested = false;
  bool _closed = false;

  Stream<T> get stream {
    _controller ??= StreamController<T>.broadcast(
      onListen: _activate,
      onCancel: _deactivate,
    );
    return _controller!.stream;
  }

  void _activate() {
    if (_disposeRequested || _closed) return;
    _wanted = true;
    _sourceSubscription ??= _source.listen(
      _controller!.add,
      onError: _controller!.addError,
    );
    _scheduleTransition();
  }

  void _deactivate() {
    _wanted = false;
    final subscription = _sourceSubscription;
    _sourceSubscription = null;
    subscription?.cancel();
    _scheduleTransition();
  }

  void _scheduleTransition() {
    _transition = _transition.then((_) async {
      if (_wanted && !_nativeActive) {
        try {
          await onStart();
          _nativeActive = true;
        } catch (error, stackTrace) {
          if (!_disposeRequested && _wanted) {
            _controller?.addError(error, stackTrace);
          }
        }
        return;
      }
      if (!_wanted && _nativeActive) {
        try {
          await onStop();
          _nativeActive = false;
        } catch (error, stackTrace) {
          // 保留 active 状态：native stop 失败时不能假设底层监听已经释放。
          // 普通取消后的下次订阅不会重复 start；manager.dispose 会再尝试 stop，
          // 最终仍失败时向调用方报告，避免悄然泄漏原生监听。
          if (!_disposeRequested) {
            _controller?.addError(error, stackTrace);
          }
        }
      }
    });
  }

  Future<void> dispose() async {
    if (_closed) return;
    _disposeRequested = true;
    _wanted = false;
    final subscription = _sourceSubscription;
    _sourceSubscription = null;
    await subscription?.cancel();
    _scheduleTransition();
    await _transition;
    if (_nativeActive) {
      // 若普通取消阶段的 stop 失败，销毁时再尝试一次，随后交由
      // manager.dispose 执行原生兜底清理。
      _scheduleTransition();
      await _transition;
    }

    _closed = true;
    // 不等待 close 的 Future：暂停的业务订阅会阻塞 done 投递，不能因此阻塞
    // manager.dispose 与原生资源释放。
    _controller?.close();
  }
}

/// 基于 MethodChannel / EventChannel 的默认实现。
///
/// 通过 [MethodChannel] 收发命令、通过 3 条 [EventChannel]（`event/location`、
/// `event/geofence`、`event/status`）接收原生回调事件。
class TencentLocationMethodChannel extends TencentLocationPlatform {
  /// 主 method channel。
  static const MethodChannel _method =
      MethodChannel('com.tencent.map.geolocation.flutter/method');

  /// 定位事件通道（按 managerId 分发）。
  static const EventChannel _locationEvent =
      EventChannel('com.tencent.map.geolocation.flutter/event/location');

  /// 围栏事件通道（按 geofenceManagerId 分发）。
  static const EventChannel _geofenceEvent =
      EventChannel('com.tencent.map.geolocation.flutter/event/geofence');

  /// 状态 / 朝向 / SDK 日志通道（按 managerId 分发）。
  static const EventChannel _statusEvent =
      EventChannel('com.tencent.map.geolocation.flutter/event/status');

  // ---------- 延迟创建的共享 broadcast stream ----------
  //
  // 三条 EventChannel 在 Dart 侧按 managerId / geofenceManagerId 过滤路由。
  // location、geofence 保持常驻底层订阅；status 使用 EventChannel 原生 broadcast
  // 语义，以便所有按 manager 管理的 status / orientation 流停止时释放 sink。

  Stream<Map>? _locationBroadcast;
  Stream<Map>? _geofenceBroadcast;
  Stream<Map>? _statusBroadcast;

  final Map<String, _ManagedManagerEventStream<TencentDeviceStatus>>
      _statusStreams =
      <String, _ManagedManagerEventStream<TencentDeviceStatus>>{};
  final Map<String, _ManagedManagerEventStream<TencentDeviceOrientation>>
      _orientationStreams =
      <String, _ManagedManagerEventStream<TencentDeviceOrientation>>{};

  /// 定位事件的共享 broadcast 流。
  ///
  /// 多个 [TencentLocationManager] 共用同一条底层 [EventChannel]，按
  /// `managerId` 过滤分发。
  Stream<Map> _locationStream() => _locationBroadcast ??= _locationEvent
      .receiveBroadcastStream()
      .where((e) => e is Map)
      .cast<Map>()
      .asBroadcastStream();

  /// 围栏事件的共享 broadcast 流。
  ///
  /// 多个 [TencentGeofenceManager] 共用同一条底层 [EventChannel]，按
  /// `geofenceManagerId` 过滤分发。
  Stream<Map> _geofenceStream() => _geofenceBroadcast ??= _geofenceEvent
      .receiveBroadcastStream()
      .where((e) => e is Map)
      .cast<Map>()
      .asBroadcastStream();

  /// 状态 / 朝向 / SDK 日志事件的共享 broadcast 流。
  ///
  /// 三类事件复用一条 channel：状态 / 朝向按 `managerId` 过滤；SDK 日志为进程级
  /// 事件，不带 `managerId`。不额外包裹 `asBroadcastStream`，因此最后一个业务
  /// 订阅者离开时，EventChannel 可以正常取消原生 sink。
  Stream<Map> _statusStream() => _statusBroadcast ??=
      _statusEvent.receiveBroadcastStream().where((e) => e is Map).cast<Map>();

  // ==================== 异常转换 ====================

  /// 把 PlatformException 统一转成 TencentLocationError。
  Never _throwFromPlatform(PlatformException e) {
    final code = TencentLocationErrorCodeCodec.fromWire(e.code);
    throw TencentLocationError(
      code: code,
      message: e.message ?? e.code,
      nativeMessage: e.message,
      details: e.details,
    );
  }

  Future<T> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      final result = await _method.invokeMethod<T>(method, args);
      return result as T;
    } on PlatformException catch (e) {
      _throwFromPlatform(e);
    }
  }

  Future<T?> _invokeNullable<T>(String method,
      [Map<String, Object?>? args]) async {
    try {
      return await _method.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      _throwFromPlatform(e);
    }
  }

  // ==================== SDK 全局 ====================

  @override
  Future<void> setPrivacyPolicyAgreement(bool agreed) =>
      _invoke<void>('sdk.setPrivacyPolicyAgreement', {'agreed': agreed});

  @override
  Future<bool> getPrivacyPolicyAgreement() =>
      _invoke<bool>('sdk.getPrivacyPolicyAgreement');

  @override
  Future<void> init({
    String? androidApiKey,
    String? iosApiKey,
    String? harmonyApiKey,
    String? deviceId,
    String? extraKey,
  }) =>
      _invoke<void>('sdk.init', {
        'androidApiKey': androidApiKey,
        'iosApiKey': iosApiKey,
        'harmonyApiKey': harmonyApiKey,
        'deviceId': deviceId,
        'extraKey': extraKey,
      });

  @override
  Future<String> getVersion() => _invoke<String>('sdk.getVersion');

  @override
  Future<String> getBuildVersion() => _invoke<String>('sdk.getBuildVersion');

  @override
  Future<String> getOaid() => _invoke<String>('sdk.getOaid');

  @override
  Future<void> enableLogToFile(bool enabled) =>
      _invoke<void>('sdk.enableLogToFile', {'enabled': enabled});

  @override
  Future<void> setRtkLogEnabled(bool enabled) =>
      _invoke<void>('sdk.setRtkLogEnabled', {'enabled': enabled});

  @override
  Future<void> setSystemCacheEnabled(bool enabled) =>
      _invoke<void>('sdk.setSystemCacheEnabled', {'enabled': enabled});

  @override
  Future<void> setExtraData(String key, String value) =>
      _invoke<void>('sdk.setExtraData', {'key': key, 'value': value});

  @override
  Future<void> setUploadGpsForNaviEnabled(bool enabled) =>
      _invoke<void>('sdk.setUploadGpsForNaviEnabled', {'enabled': enabled});

  @override
  Future<void> setLoadLibraryEnabled(bool enabled) =>
      _invoke<void>('sdk.setLoadLibraryEnabled', {'enabled': enabled});

  // ---------- iOS 权限 ----------

  @override
  Future<void> requestIosWhenInUseAuthorization() =>
      _invoke<void>('sdk.ios.requestWhenInUseAuthorization');

  @override
  Future<void> requestIosAlwaysAuthorization() =>
      _invoke<void>('sdk.ios.requestAlwaysAuthorization');

  @override
  Future<String?> requestIosTemporaryFullAccuracy(
          {required String purposeKey}) =>
      _invokeNullable<String>(
          'sdk.ios.requestTemporaryFullAccuracy', {'purposeKey': purposeKey});

  @override
  Future<IosAccuracyAuthorization> getIosAccuracyAuthorization() async {
    final raw =
        await _invokeNullable<String>('sdk.ios.getAccuracyAuthorization');
    return IosAccuracyAuthorizationCodec.fromWire(raw);
  }

  // ---------- SDK 日志 ----------

  @override
  Stream<TencentSdkLogEvent> get onSdkLogChanged => _statusStream()
      .where((m) => m['event'] == 'onSdkLog')
      .map((m) => TencentSdkLogEvent.fromMap(_payloadOf(m)));

  // ==================== Manager ====================

  @override
  Future<void> createLocationManager(String managerId) =>
      _invoke<void>('manager.create', {'managerId': managerId});

  @override
  Future<void> disposeLocationManager(String managerId) async {
    final statusStream = _statusStreams[managerId];
    await statusStream?.dispose();
    _statusStreams.remove(managerId);

    final orientationStream = _orientationStreams[managerId];
    await orientationStream?.dispose();
    _orientationStreams.remove(managerId);

    await _invoke<void>('manager.dispose', {'managerId': managerId});
  }

  // ==================== 定位 ====================

  @override
  Future<void> startContinuousLocation(
          String managerId, TencentLocationRequest request) =>
      _invoke<void>('location.startContinuous',
          {'managerId': managerId, 'request': request.toMap()});

  @override
  Future<void> stopContinuousLocation(String managerId) =>
      _invoke<void>('location.stopContinuous', {'managerId': managerId});

  @override
  Future<TencentLocation> startSingleLocation(
      String managerId, TencentLocationRequest request) async {
    final map = await _invokeNullable<Map>('location.startSingle',
        {'managerId': managerId, 'request': request.toMap()});
    if (map == null) {
      throw const TencentLocationError(
        code: TencentLocationErrorCode.locationFailed,
        message: 'startSingleLocation returned null',
      );
    }
    return TencentLocation.fromMap(map);
  }

  @override
  Future<TencentLocation?> getLastLocation(String managerId) async {
    final map = await _invokeNullable<Map>(
        'location.getLastLocation', {'managerId': managerId});
    return map == null ? null : TencentLocation.fromMap(map);
  }

  @override
  Future<void> changeCallbackInterval(String managerId, Duration interval) =>
      _invoke<void>('location.changeCallbackInterval',
          {'managerId': managerId, 'intervalMs': interval.inMilliseconds});

  @override
  Future<void> dismissIosHeadingCalibrationDisplay(String managerId) =>
      _invoke<void>('location.ios.dismissHeadingCalibrationDisplay',
          {'managerId': managerId});

  @override
  Future<void> enableForeground({
    required String managerId,
    required int notificationId,
    required String channelId,
    required String title,
    required String text,
    String? smallIconResourceName,
  }) =>
      _invoke<void>('location.android.enableForeground', {
        'managerId': managerId,
        'notificationId': notificationId,
        'channelId': channelId,
        'title': title,
        'text': text,
        'smallIconResourceName': smallIconResourceName,
      });

  @override
  Future<void> disableForeground({
    required String managerId,
    bool removeNotification = true,
  }) =>
      _invoke<void>('location.android.disableForeground', {
        'managerId': managerId,
        'removeNotification': removeNotification,
      });

  @override
  Future<void> startBackgroundLocationTask({
    required String managerId,
    Map<String, Object?>? wantAgentInfo,
  }) =>
      _invoke<void>('location.harmony.startBackgroundTask', {
        'managerId': managerId,
        'wantAgentInfo': wantAgentInfo,
      });

  @override
  Future<void> stopBackgroundLocationTask(String managerId) => _invoke<void>(
      'location.harmony.stopBackgroundTask', {'managerId': managerId});

  @override
  Future<void> setIosExtraData(String managerId, String key, String value) =>
      _invoke<void>('location.ios.setExtraData',
          {'managerId': managerId, 'key': key, 'value': value});

  // ---------- manager 事件流 ----------

  @override
  Stream<TencentLocation> onLocationChanged(String managerId) =>
      _locationStream()
          .where((m) =>
              m['event'] == 'onLocationChanged' && m['managerId'] == managerId)
          .map((m) => TencentLocation.fromMap(_payloadOf(m)));

  @override
  Stream<TencentLocationError> onLocationError(String managerId) =>
      _locationStream()
          .where((m) =>
              m['event'] == 'onLocationError' && m['managerId'] == managerId)
          .map((m) => TencentLocationError.fromMap(_payloadOf(m)));

  @override
  Stream<TencentDeviceStatus> onStatusChanged(String managerId) {
    final managed = _statusStreams.putIfAbsent(
      managerId,
      () => _ManagedManagerEventStream<TencentDeviceStatus>(
        source: _statusStream()
            .where((m) =>
                m['event'] == 'onStatusChanged' && m['managerId'] == managerId)
            .map((m) => TencentDeviceStatus.fromMap(_payloadOf(m))),
        onStart: () => _invoke<void>(
          'stream.status.start',
          <String, Object?>{'managerId': managerId},
        ),
        onStop: () => _invoke<void>(
          'stream.status.stop',
          <String, Object?>{'managerId': managerId},
        ),
      ),
    );
    return managed.stream;
  }

  @override
  Stream<TencentDeviceOrientation> onOrientationChanged(String managerId) {
    final managed = _orientationStreams.putIfAbsent(
      managerId,
      () => _ManagedManagerEventStream<TencentDeviceOrientation>(
        source: _statusStream()
            .where((m) =>
                m['event'] == 'onOrientationChanged' &&
                m['managerId'] == managerId)
            .map((m) => TencentDeviceOrientation.fromMap(_payloadOf(m))),
        onStart: () => _invoke<void>(
          'stream.orientation.start',
          <String, Object?>{'managerId': managerId},
        ),
        onStop: () => _invoke<void>(
          'stream.orientation.stop',
          <String, Object?>{'managerId': managerId},
        ),
      ),
    );
    return managed.stream;
  }

  // ==================== 围栏 ====================

  @override
  Future<void> createGeofenceManager(String geofenceManagerId) => _invoke<void>(
      'geofence.managerCreate', {'geofenceManagerId': geofenceManagerId});

  @override
  Future<void> disposeGeofenceManager(String geofenceManagerId) =>
      _invoke<void>(
          'geofence.managerDispose', {'geofenceManagerId': geofenceManagerId});

  @override
  Future<void> addGeofence(String geofenceManagerId, TencentGeofence fence) =>
      _invoke<void>('geofence.add', {
        'geofenceManagerId': geofenceManagerId,
        'geofence': fence.toMap(),
      });

  @override
  Future<void> removeGeofence(String geofenceManagerId, String id) =>
      _invoke<void>('geofence.remove',
          {'geofenceManagerId': geofenceManagerId, 'id': id});

  @override
  Future<void> removeAllGeofences(String geofenceManagerId) => _invoke<void>(
      'geofence.removeAll', {'geofenceManagerId': geofenceManagerId});

  @override
  Future<List<TencentGeofence>> getAllGeofences(
      String geofenceManagerId) async {
    final raw = await _invokeNullable<List<Object?>>(
        'geofence.getAll', {'geofenceManagerId': geofenceManagerId});
    return (raw ?? <Object?>[])
        .whereType<Map>()
        .map((m) => TencentGeofence.fromMap(m))
        .toList();
  }

  @override
  Future<bool> isCoordinateInside(String geofenceManagerId, String id,
          TencentLocationCoordinate coordinate) =>
      _invoke<bool>('geofence.isCoordinateInside', {
        'geofenceManagerId': geofenceManagerId,
        'id': id,
        'coordinate': coordinate.toMap(),
      });

  @override
  Future<List<TencentGeofence>> geofenceRegionsContainingCoordinate(
      String geofenceManagerId, TencentLocationCoordinate coordinate) async {
    final raw =
        await _invokeNullable<List<Object?>>('geofence.regionsContaining', {
      'geofenceManagerId': geofenceManagerId,
      'coordinate': coordinate.toMap(),
    });
    return (raw ?? <Object?>[])
        .whereType<Map>()
        .map((m) => TencentGeofence.fromMap(m))
        .toList();
  }

  @override
  Future<void> startMonitoring(String geofenceManagerId) => _invoke<void>(
      'geofence.ios.startMonitoring', {'geofenceManagerId': geofenceManagerId});

  @override
  Future<void> stopMonitoring(String geofenceManagerId) => _invoke<void>(
      'geofence.ios.stopMonitoring', {'geofenceManagerId': geofenceManagerId});

  @override
  Future<void> pauseMonitoring(String geofenceManagerId) => _invoke<void>(
      'geofence.ios.pauseMonitoring', {'geofenceManagerId': geofenceManagerId});

  @override
  Future<void> resumeMonitoring(String geofenceManagerId) => _invoke<void>(
      'geofence.ios.resumeMonitoring',
      {'geofenceManagerId': geofenceManagerId});

  @override
  Future<bool> isMonitoring(String geofenceManagerId) => _invoke<bool>(
      'geofence.ios.isMonitoring', {'geofenceManagerId': geofenceManagerId});

  @override
  Future<void> setIosAllowsBackgroundLocationUpdates(
          String geofenceManagerId, bool enabled) =>
      _invoke<void>('geofence.ios.setAllowsBackgroundLocationUpdates', {
        'geofenceManagerId': geofenceManagerId,
        'enabled': enabled,
      });

  @override
  Future<void> setIosAdaptiveDistanceFilterEnabled(
          String geofenceManagerId, bool enabled) =>
      _invoke<void>('geofence.ios.setAdaptiveDistanceFilterEnabled', {
        'geofenceManagerId': geofenceManagerId,
        'enabled': enabled,
      });

  @override
  Future<void> setIosDistanceFilter(String geofenceManagerId, double meters) =>
      _invoke<void>('geofence.ios.setDistanceFilter',
          {'geofenceManagerId': geofenceManagerId, 'meters': meters});

  @override
  Future<void> setIosDesiredAccuracy(
          String geofenceManagerId, IosDesiredAccuracy accuracy) =>
      _invoke<void>('geofence.ios.setDesiredAccuracy', {
        'geofenceManagerId': geofenceManagerId,
        'accuracy': accuracy.wireName,
      });

  @override
  Future<void> setIosDetectionInterval(
          String geofenceManagerId, Duration interval) =>
      _invoke<void>('geofence.ios.setDetectionInterval', {
        'geofenceManagerId': geofenceManagerId,
        'intervalMs': interval.inMilliseconds,
      });

  @override
  Stream<TencentGeofenceEvent> onGeofenceEvent(String geofenceManagerId) =>
      _geofenceStream()
          .where((m) =>
              m['event'] == 'onGeofenceEvent' &&
              m['geofenceManagerId'] == geofenceManagerId)
          .map((m) => TencentGeofenceEvent.fromMap(_payloadOf(m)));

  @override
  Stream<TencentLocationError> onGeofenceError(String geofenceManagerId) =>
      _geofenceStream()
          .where((m) =>
              m['event'] == 'onGeofenceError' &&
              m['geofenceManagerId'] == geofenceManagerId)
          .map((m) => TencentLocationError.fromMap(_payloadOf(m)));

  @override
  Stream<TencentGeofenceCreatedEvent> onGeofenceCreated(
          String geofenceManagerId) =>
      _geofenceStream()
          .where((m) =>
              m['event'] == 'onGeofenceCreated' &&
              m['geofenceManagerId'] == geofenceManagerId)
          .map((m) => TencentGeofenceCreatedEvent.fromMap(_payloadOf(m)));

  // ==================== 工具 ====================

  @override
  Future<bool> utilsIsSupportGps() => _invoke<bool>('utils.isSupportGps');

  @override
  Future<bool> utilsIsInRegion({
    required double latitude,
    required double longitude,
  }) =>
      _invoke<bool>('utils.isInRegion', {
        'latitude': latitude,
        'longitude': longitude,
      });

  @override
  Future<TencentLocationCoordinate> utilsWgs84ToGcj02(
      TencentLocationCoordinate coord) async {
    final raw = await _invokeNullable<Map>('utils.wgs84ToGcj02', coord.toMap());
    if (raw == null) {
      throw const TencentLocationError(
        code: TencentLocationErrorCode.nativeError,
        message: 'utils.wgs84ToGcj02 returned null',
      );
    }
    return TencentLocationCoordinate.fromMap(raw);
  }

  // ==================== helper ====================

  Map _payloadOf(Map event) {
    final payload = event['payload'];
    return payload is Map ? payload : const {};
  }
}
