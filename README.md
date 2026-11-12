# tencent_location_flutter_plugin

本仓库基于 [腾讯位置服务发布的 Flutter 插件 0.2.2](https://pub.dev/packages/tencent_location_flutter_plugin/versions/0.2.2) 独立维护，对原生 SDK 的连续定位、单次定位、地理围栏与常用坐标 / 距离工具做了统一封装。

## 平台支持

| 平台 | 状态 | 底层 SDK |
| --- | --- | --- |
| 🅰️ Android | 已实装 | `TencentLocationSdk-openplatform`（Maven Central） |
| 🍏 iOS | 已实装 | `TencentLBS.xcframework` 4.3.1（SwiftPM 或 CocoaPods） |
| 🔶 HarmonyOS | 已实装 | `@tencentmap/location_sdk`（ohpm） |

各公开 API 在文档注释中都以 🅰️ / 🍏 / 🔶 三行明确列出各平台的支持情况与差异；调用平台不支持的接口会抛出 `TencentLocationError`，错误码为 `unsupportedOnThisPlatform`。

## 安装

在你的 `pubspec.yaml` 中引用本仓库的分支：

```yaml
dependencies:
  tencent_location_flutter_plugin:
    git:
      url: https://github.com/kuailezhiyuan/tencent_location_flutter_plugin.git
      ref: codex/native-smart-tracking
```

然后执行：

```sh
flutter pub get
```

### Android 配置

1. 在 [腾讯位置服务开放平台](https://lbs.qq.com/) 申请 Android 平台的 ApiKey。
2. 在 `android/app/src/main/AndroidManifest.xml` 的 `<application>` 节点中声明 ApiKey，或在运行时通过 [`TencentLocationSDK.init`](#快速开始) 传入。
3. 申请定位所需权限（`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` 等），并按 Android 运行时权限规则向用户请求。

### iOS 配置

1. 在 [腾讯位置服务开放平台](https://lbs.qq.com/) 申请 iOS 平台的 ApiKey。
2. 在 `ios/Runner/Info.plist` 中声明定位用途字符串（`NSLocationWhenInUseUsageDescription` 等）。
3. ApiKey 可通过 `Info.plist` 配置或运行时通过 [`TencentLocationSDK.init`](#快速开始) 传入。

使用本仓库的插件时，启用了 SwiftPM 的 Flutter 项目会从腾讯下载并校验 `TencentLBS.xcframework`，支持 `arm64` 真机和 `arm64` / `x86_64` 模拟器构建。

通过 CocoaPods 接入时，在宿主 `ios/Podfile` 的 Runner target 中，紧接在 `flutter_install_all_ios_pods` 之后添加以下依赖，让 CocoaPods 使用同一份 XCFramework：

```ruby
pod 'TencentLocationSDK', :podspec => '.symlinks/plugins/tencent_location_flutter_plugin/ios/TencentLocationSDK.podspec'
```

宿主通过 `use_frameworks!` 集成 CocoaPods 时，使用 `use_frameworks! :linkage => :static`。启用 SwiftPM 后应移除上述 CocoaPods 覆盖，避免重复链接 SDK。

### HarmonyOS 配置

HarmonyOS 端集成需要使用 OpenHarmony 社区维护的鸿蒙分支 Flutter（不是官方 Flutter）。同一份插件仓库可同时被官方 Flutter（用于 Android / iOS 编译）与鸿蒙分支 Flutter（用于 HarmonyOS 编译）识别，Dart 代码完全共用。

1. 克隆鸿蒙分支 Flutter，并切到稳定 tag `3.22.0-ohos`：

    ```sh
    git clone https://gitcode.com/openharmony-tpc/flutter_flutter.git flutter_ohos
    cd flutter_ohos
    git checkout 3.22.0-ohos
    ```

    建议给它单独取一个命令别名（例如 `fohos`）与官方 Flutter 并存，编 HarmonyOS 时用 `fohos`，编 Android / iOS 时仍用官方 `flutter`。

2. 安装 DevEco Studio 5.0.3.900+ 与 HarmonyOS SDK 5.0.0(12)，并确保 `ohpm` 已就绪。

3. 在 [腾讯位置服务开放平台](https://lbs.qq.com/) 申请 HarmonyOS 平台的 ApiKey，运行时通过 [`TencentLocationSDK.init`](#快速开始) 的 `harmonyApiKey` 传入。

4. 在 `example/ohos/entry/src/main/module.json5`（或你的宿主工程对应位置）中声明定位权限：

    ```json5
    "requestPermissions": [
      { "name": "ohos.permission.LOCATION" },
      { "name": "ohos.permission.APPROXIMATELY_LOCATION" },
      { "name": "ohos.permission.INTERNET" }
    ]
    ```

    需要后台定位时额外申请 `ohos.permission.LOCATION_IN_BACKGROUND`。

5. 通过鸿蒙分支 Flutter 运行 example：

    ```sh
    cd example
    fohos pub get
    fohos run -d <鸿蒙设备 id>
    ```

    鸿蒙分支 Flutter tool 会自动准备 `flutter.har` 引擎产物，触发 `ohpm install` 拉取 `@tencentmap/location_sdk` 与 `@ohos/flutter_ohos`，然后走 hvigor 打包成 hap 并部署到设备。

如需在自己的 Flutter 工程中新增 `ohos/` 目录，可在装有鸿蒙 Flutter 的机器上执行：

```sh
fohos create --platforms=ohos .
```

## 快速开始

### 1. 同意隐私政策并初始化 SDK

调用任何其他 API 前，**必须**先同意隐私政策并完成 SDK 初始化。

```dart
import 'package:tencent_location_flutter_plugin/tencent_location_flutter_plugin.dart';

Future<void> setupSdk() async {
  await TencentLocationSDK.setPrivacyPolicyAgreement(true);
  await TencentLocationSDK.init(
    androidApiKey: 'YOUR_ANDROID_API_KEY',
    iosApiKey: 'YOUR_IOS_API_KEY',
    harmonyApiKey: 'YOUR_HARMONY_API_KEY',
  );
}
```

### 2. 单次定位

```dart
Future<void> requestSingleLocation() async {
  final manager = TencentLocationManager();
  try {
    final request = TencentLocationRequest.create()
      ..setRequestLevel(RequestLevel.geo)
      ..setCoordinateType(CoordinateType.gcj02);
    final location = await manager.startSingleLocation(request);
    print('单次定位：${location.latitude}, ${location.longitude}');
  } on TencentLocationError catch (error) {
    print('定位失败：${error.code} ${error.message}');
  } finally {
    await manager.dispose();
  }
}
```

### 3. 连续定位

```dart
Future<void> startContinuousLocation() async {
  final manager = TencentLocationManager();

  manager.onLocationChanged.listen((location) {
    print('位置更新：${location.latitude}, ${location.longitude}');
  });
  manager.onLocationError.listen((error) {
    print('定位错误：${error.code} ${error.message}');
  });

  final request = TencentLocationRequest.create()
    ..setRequestLevel(RequestLevel.geo)
    ..setCoordinateType(CoordinateType.gcj02)
    ..setInterval(const Duration(seconds: 3));
  await manager.startContinuousLocation(request);

  // 不再需要时停止并释放：
  // await manager.stopContinuousLocation();
  // await manager.dispose();
}
```

### 4. 地理围栏

```dart
Future<void> watchGeofence() async {
  final manager = TencentGeofenceManager();

  manager.onEvent.listen((event) {
    print('围栏事件：${event.transition} -> ${event.geofenceId}');
  });

  await manager.addGeofence(
    TencentGeofence.circle(
      id: 'office',
      center: const TencentLocationCoordinate(
        latitude: 39.984120,
        longitude: 116.307484,
      ),
      radius: 200,
    ),
  );
  await manager.startMonitoring();

  // 不再需要时清理：
  // await manager.stopMonitoring();
  // await manager.dispose();
}
```

## 功能概览

- **全局配置**（[`TencentLocationSDK`](https://pub.dev/documentation/tencent_location_flutter_plugin/latest/tencent_location_flutter_plugin/TencentLocationSDK-class.html)）：隐私合规、ApiKey 初始化、版本信息、日志开关、iOS 权限申请等。
- **连续 / 单次定位**（[`TencentLocationManager`](https://pub.dev/documentation/tencent_location_flutter_plugin/latest/tencent_location_flutter_plugin/TencentLocationManager-class.html)）：可配置坐标系、回调间隔、逆地址、设备状态、设备朝向；支持前台服务与后台任务。
- **地理围栏**（[`TencentGeofenceManager`](https://pub.dev/documentation/tencent_location_flutter_plugin/latest/tencent_location_flutter_plugin/TencentGeofenceManager-class.html)）：圆形 / 多边形围栏的增删改查、进出停留事件回调、监听暂停 / 恢复。
- **工具方法**（[`TencentLocationUtils`](https://pub.dev/documentation/tencent_location_flutter_plugin/latest/tencent_location_flutter_plugin/TencentLocationUtils-class.html)）：坐标系互转、两点间距离计算、判断点是否在围栏内等。
- **多实例**：同一应用内可创建多个管理器实例，事件流互相隔离。

完整 API 文档见 pub.dev 的 [API reference](https://pub.dev/documentation/tencent_location_flutter_plugin/latest/)。

## 许可

[BSD 3-Clause License](LICENSE)。本分支移植的 Tracelet 代码遵循 [Apache-2.0](third_party/tracelet/LICENSE)，来源及修改说明见下文。

## 原生 Smart 高低档跟踪（Android / iOS）

`TencentLocationSDK.startSmartTracking` 启动一个应用级的 Smart 会话。运动检测、速度状态机、计时和档位切换都在 Java / Swift 中执行，Dart 负责配置与观察状态。所有定位请求通过腾讯 SDK 发起；插件不另开系统定位请求，不依赖 Rust 或后台 Flutter 引擎。

```dart
final moving = TencentLocationRequest.create()
  ..interval = const Duration(seconds: 1);
moving.android((a) {
  a.locMode = AndroidLocationMode.highAccuracy;
  a.allowGps = true;
});
moving.ios((i) {
  i.desiredAccuracy = IosDesiredAccuracy.best;
  i.allowsBackgroundLocationUpdates = true;
  i.pausesLocationUpdatesAutomatically = false;
});

final stationary = TencentLocationRequest.create()
  ..interval = const Duration(seconds: 1);
stationary.android((a) {
  a.locMode = AndroidLocationMode.onlyNetwork;
  a.allowGps = false;
});
stationary.ios((i) {
  i.desiredAccuracy = IosDesiredAccuracy.hundredMeters;
  i.allowsBackgroundLocationUpdates = true;
  i.pausesLocationUpdatesAutomatically = false;
});

// 先完成隐私同意、腾讯 SDK 初始化和所需的系统权限授权。
await TencentLocationSDK.startSmartTracking(
  movingRequest: moving,
  stationaryRequest: stationary,
  config: const TencentSmartTrackingConfig(
    stopTimeout: Duration(minutes: 2),
    speedStationaryDelay: Duration(seconds: 90),
    speedMovingThreshold: 5,
    speedWakeConfirmCount: 3,
    releaseWakelockWhenStationary: true,
    notificationTitle: '后台记录中',
    notificationText: '正在后台持续记录旅途',
  ),
);

final state = await TencentLocationSDK.getSmartTrackingState();
print('${state.pace}: accel=${state.accelerometerMoving}, '
    'speed=${state.speedState}, lock=${state.wakeLockHeld}');

// 原生会话不随 Dart 事件订阅取消而停止。结束时显式调用：
await TencentLocationSDK.stopSmartTracking();
```

### 判定与平台边界

- Smart 同时运行传感器与速度两路判定。任一路认为在移动时保持 High，两路均静止时进入连续 Low；同时保留 Tracelet 的新鲜近零速度校正、速度滞回、连续点确认及启动锚点保护。
- 默认传感器判静计时为 2 分钟，速度判静为 90 秒。速度开始减速的门槛为移动门槛的 `0.65` 倍；静止后的速度唤醒要求连续 3 点达到 `5 m/s`。传感器唤醒独立于速度门槛。
- Low 保留腾讯连续定位。Android 示例使用仅网络定位；iOS 使用百米精度、无距离过滤和后台定位。请求间隔是 SDK 请求值，不能保证系统按该频率交付新位置。
- iOS 两档的后台开关必须一致，`distanceFilter` 仅接受空值或不大于 0。后台模式会关闭自动暂停，并按 Tracelet 的挂起保护将千米等更粗的精度限制为百米。两档请求间隔相同时直接调整腾讯 manager 属性；间隔不同时，腾讯 SDK 需要停止并重新启动订阅才能应用新间隔，日志会记录 `request_restart`。
- 高低档应使用相同坐标系。Android 场景化定位会覆盖请求参数，不能用于这组显式高低档请求。腾讯 Android SDK 的全局配置有共享边界，因此 Smart 与普通连续定位互斥。
- Android 使用前台位置服务并返回 `START_STICKY`。进程被回收后，服务恢复已保存的请求、已同意的 SDK 配置与运动状态，重新创建腾讯定位订阅及传感器，不启动 Flutter 引擎。不会自动在设备重启后开启录制。
- Android 在已确认静止、允许释放且硬件 significant-motion 监听注册成功时释放 CPU 锁，运动后重新获取；缺少传感器或注册失败时保留锁。使用硬件加速度计和 `TYPE_SIGNIFICANT_MOTION`，无需 GMS 活动识别。
- iOS 使用 CoreMotion 及腾讯的后台连续定位。Android 的 CPU 锁与 `START_STICKY` 不适用于 iOS，用户强制退出 App 后不保证继续运行。
- 新接口在 HarmonyOS 不受支持；原有定位接口保持原有行为。

### 为什么不把运动检测迁到 Dart

纯状态转换可以用 Dart 表达，但当前目标需要在 Android Flutter 引擎退出后继续运行、由服务恢复，并使用系统唤醒传感器和 CPU 锁。将计时与判定放到 Dart 会重新依赖 Flutter 引擎生命周期，也增加后台引擎的内存开销。当前实现将配置、界面与日志展示留在 Dart，平台调度及算法保留在原生端。

### 演示程序与验证

演示程序新增 Smart 测试页，可启动 / 停止原生会话，查看高低档、两路运动状态、速度状态、Android 锁与传感器能力、最近位置及计数，并复制原生 JSONL 日志。重新打开页面会读取原生会话快照，不会自动启动新会话。

```sh
cd example
flutter run --dart-define=TENCENT_ANDROID_API_KEY=<your-android-key>
# iOS 使用 TENCENT_IOS_API_KEY；ApiKey 需与实际包名、签名或 Bundle ID 匹配。
```

测试前授予定位权限。Android 后台恢复需要后台定位、通知及前台位置服务权限；传感器方案不需要 `ACTIVITY_RECOGNITION`。iOS 后台测试需「始终」定位、`UIBackgroundModes=location`，使用 CoreMotion 活动识别时需运动权限。示例已配置用途说明与演示用后台模式，拒绝运动权限时走原始加速度计降级。

建议在真机上分别验证：

1. 默认参数下平放并锁屏，确认两路判静后进入 Low，Android 日志记录 CPU 锁释放。
2. 保持锁屏走动，确认传感器唤醒后恢复 High；单个漂移速度尖峰不能跳过连续点确认。
3. Android 在 Low 档杀掉普通进程后，确认原生服务恢复、请求保持 Low，再走动验证 High。`am force-stop`、系统设置中的「强行停止」和用户主动停止前台服务不属于 `START_STICKY` 的恢复保证。
4. 显式停止后再回收进程，确认不会恢复旧录制；撤回隐私同意时也应停止。
5. 分别运行普通定位与 Smart，确认冲突请求会报告错误，不会偷偷覆盖另一条连续定位。

本次只移植 Smart 连续高低档、Android 唤醒 / CPU 锁管理和服务恢复。原生诊断日志是有界日志，`lastLocation` 是最新位置快照；没有移植 SQLite 定位点队列，因此不会回放 Flutter 不在运行期间的所有定位点。

### 移植来源

算法以 [Tracelet `071cd0be`](https://github.com/kuailezhiyuan/Tracelet/tree/071cd0bebe9937816470e306c583651bf64d20a2) 为基准，保留判定阈值、计数、时序和状态协调语义。为适配本插件，Android 实现从 Kotlin 转为 Java，小型 Rust OR 协调器逐项翻译为 Java / Swift，定位调用改接腾讯 SDK，删除未移植功能的依赖。来源文件、Apache-2.0 许可和原始 NOTICE 保存在 [`third_party/tracelet`](third_party/tracelet/PROVENANCE)。
