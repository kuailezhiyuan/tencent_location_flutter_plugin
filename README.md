# tencent_location_flutter_plugin

腾讯定位服务（[腾讯位置服务开放平台](https://lbs.qq.com/)）的官方 Flutter 插件，对原生 SDK 的连续定位、单次定位、地理围栏与常用坐标 / 距离工具做了统一封装。

## 平台支持

| 平台 | 状态 | 底层 SDK |
| --- | --- | --- |
| 🅰️ Android | 已实装 | `TencentLocationSdk-openplatform`（Maven Central） |
| 🍏 iOS | 已实装 | `TencentLocationSDK`（CocoaPods） |
| 🔶 HarmonyOS | 已实装 | `@tencentmap/location_sdk`（ohpm） |

各公开 API 在文档注释中都以 🅰️ / 🍏 / 🔶 三行明确列出各平台的支持情况与差异；调用平台不支持的接口会抛出 `TencentLocationError`，错误码为 `unsupportedOnThisPlatform`。

## 安装

在你的 `pubspec.yaml` 中加入依赖：

```yaml
dependencies:
  tencent_location_flutter_plugin: ^0.2.0
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

[BSD 3-Clause License](LICENSE)。
