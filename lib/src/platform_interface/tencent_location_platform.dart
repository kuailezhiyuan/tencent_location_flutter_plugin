import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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
import 'tencent_location_method_channel.dart';

/// 腾讯定位 SDK Flutter 插件的 Platform Interface。
///
/// 平台实现通过继承本类并调用 [instance] setter 来注入。默认实现走
/// [TencentLocationMethodChannel]（Method / Event Channel）。
abstract class TencentLocationPlatform extends PlatformInterface {
  TencentLocationPlatform() : super(token: _token);

  static final Object _token = Object();

  static TencentLocationPlatform _instance = TencentLocationMethodChannel();

  /// 当前平台实现。
  static TencentLocationPlatform get instance => _instance;

  /// 设置平台实现。子类必须继承自 [TencentLocationPlatform]。
  static set instance(TencentLocationPlatform value) {
    PlatformInterface.verifyToken(value, _token);
    _instance = value;
  }

  // ==================== SDK 全局 ====================

  Future<void> setPrivacyPolicyAgreement(bool agreed);

  Future<bool> getPrivacyPolicyAgreement();

  Future<void> init({
    String? androidApiKey,
    String? iosApiKey,
    String? harmonyApiKey,
    String? deviceId,
    String? extraKey,
  });

  Future<String> getVersion();

  Future<String> getBuildVersion();

  Future<String> getOaid();

  Future<void> enableLogToFile(bool enabled);

  Future<void> setRtkLogEnabled(bool enabled);

  Future<void> setSystemCacheEnabled(bool enabled);

  Future<void> setExtraData(String key, String value);

  Future<void> setUploadGpsForNaviEnabled(bool enabled);

  Future<void> setLoadLibraryEnabled(bool enabled);

  // ---------- iOS 专属（其它端实现中抛 unsupportedOnThisPlatform） ----------

  Future<void> requestIosWhenInUseAuthorization();

  Future<void> requestIosAlwaysAuthorization();

  Future<String?> requestIosTemporaryFullAccuracy({required String purposeKey});

  Future<IosAccuracyAuthorization> getIosAccuracyAuthorization();

  /// SDK 内部运行日志（🅰️ 仅 Android 有）。
  Stream<TencentSdkLogEvent> get onSdkLogChanged;

  // ==================== Manager 生命周期 ====================

  /// 创建一个 manager；`managerId` 由 Dart 层生成。
  Future<void> createLocationManager(String managerId);

  Future<void> disposeLocationManager(String managerId);

  // ==================== 定位 ====================

  Future<void> startContinuousLocation(
      String managerId, TencentLocationRequest request);

  Future<void> stopContinuousLocation(String managerId);

  Future<TencentLocation> startSingleLocation(
      String managerId, TencentLocationRequest request);

  Future<TencentLocation?> getLastLocation(String managerId);

  Future<void> changeCallbackInterval(String managerId, Duration interval);

  Future<void> dismissIosHeadingCalibrationDisplay(String managerId);

  Future<void> enableForeground({
    required String managerId,
    required int notificationId,
    required String channelId,
    required String title,
    required String text,
    String? smallIconResourceName,
  });

  Future<void> disableForeground({
    required String managerId,
    bool removeNotification = true,
  });

  Future<void> startBackgroundLocationTask({
    required String managerId,
    Map<String, Object?>? wantAgentInfo,
  });

  Future<void> stopBackgroundLocationTask(String managerId);

  Future<void> setIosExtraData(String managerId, String key, String value);

  /// 单个 manager 的定位结果流。
  Stream<TencentLocation> onLocationChanged(String managerId);

  /// 单个 manager 的定位错误流。
  Stream<TencentLocationError> onLocationError(String managerId);

  /// 单个 manager 的设备状态流。
  Stream<TencentDeviceStatus> onStatusChanged(String managerId);

  /// 单个 manager 的朝向流。
  Stream<TencentDeviceOrientation> onOrientationChanged(String managerId);

  // ==================== 地理围栏 ====================

  Future<void> createGeofenceManager(String geofenceManagerId);

  Future<void> disposeGeofenceManager(String geofenceManagerId);

  Future<void> addGeofence(String geofenceManagerId, TencentGeofence fence);

  Future<void> removeGeofence(String geofenceManagerId, String id);

  Future<void> removeAllGeofences(String geofenceManagerId);

  Future<List<TencentGeofence>> getAllGeofences(String geofenceManagerId);

  Future<bool> isCoordinateInside(
    String geofenceManagerId,
    String id,
    TencentLocationCoordinate coordinate,
  );

  Future<List<TencentGeofence>> geofenceRegionsContainingCoordinate(
    String geofenceManagerId,
    TencentLocationCoordinate coordinate,
  );

  Future<void> startMonitoring(String geofenceManagerId);

  Future<void> stopMonitoring(String geofenceManagerId);

  Future<void> pauseMonitoring(String geofenceManagerId);

  Future<void> resumeMonitoring(String geofenceManagerId);

  Future<bool> isMonitoring(String geofenceManagerId);

  Future<void> setIosAllowsBackgroundLocationUpdates(
      String geofenceManagerId, bool enabled);

  Future<void> setIosAdaptiveDistanceFilterEnabled(
      String geofenceManagerId, bool enabled);

  Future<void> setIosDistanceFilter(
      String geofenceManagerId, double meters);

  Future<void> setIosDesiredAccuracy(
      String geofenceManagerId, IosDesiredAccuracy accuracy);

  Future<void> setIosDetectionInterval(
      String geofenceManagerId, Duration interval);

  Stream<TencentGeofenceEvent> onGeofenceEvent(String geofenceManagerId);

  Stream<TencentLocationError> onGeofenceError(String geofenceManagerId);

  Stream<TencentGeofenceCreatedEvent> onGeofenceCreated(
      String geofenceManagerId);

  // ==================== 工具（仅原生有的能力）====================

  Future<bool> utilsIsSupportGps();

  Future<bool> utilsIsInRegion({
    required double latitude,
    required double longitude,
  });

  Future<TencentLocationCoordinate> utilsWgs84ToGcj02(
      TencentLocationCoordinate coord);
}
