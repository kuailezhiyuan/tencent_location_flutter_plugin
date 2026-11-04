/// 腾讯定位 SDK Flutter 插件。
///
/// 入口：[TencentLocationSDK]（全局 SDK 配置）、[TencentLocationManager]（连续 / 单次定位）、
/// [TencentGeofenceManager]（地理围栏）、[TencentLocationUtils]（坐标 / 距离工具）。
///
/// ## 平台支持矩阵（v0.1.0）
///
/// | 平台 | 状态 |
/// | --- | --- |
/// | 🅰️ Android | 已实装 |
/// | 🍏 iOS | 已实装 |
/// | 🔶 HarmonyOS | 规划中，将在后续版本随原生实装一并发布 |
///
/// 当前版本在 HarmonyOS 平台调用插件方法将抛出 `MissingPluginException`；
/// 各公开 API 注释中 `🔶 Harmony` 行描述的是规划中的目标行为，不代表当前版本
/// 已实装。详见 `CHANGELOG.md`。
library tencent_location_flutter_plugin;

// ---------- 枚举 ----------
export 'src/enums/android_enums.dart';
export 'src/enums/coordinate_type.dart';
export 'src/enums/device_status.dart';
export 'src/enums/geofence_enums.dart';
export 'src/enums/harmony_enums.dart';
export 'src/enums/ios_enums.dart';
export 'src/enums/location_source.dart';
export 'src/enums/request_level.dart';

// ---------- Model ----------
export 'src/models/tencent_device_orientation.dart';
export 'src/models/tencent_device_status.dart';
export 'src/models/tencent_geo_address.dart';
export 'src/models/tencent_geofence.dart';
export 'src/models/tencent_geofence_event.dart';
export 'src/models/tencent_location.dart';
export 'src/models/tencent_location_coordinate.dart';
export 'src/models/tencent_location_error.dart';
export 'src/models/tencent_location_request.dart';
export 'src/models/tencent_poi.dart';
export 'src/models/tencent_sdk_log_event.dart';

// ---------- 公开类 ----------
export 'src/tencent_geofence_manager.dart';
export 'src/tencent_location_manager.dart';
export 'src/tencent_location_sdk.dart';
export 'src/tencent_location_utils.dart';
