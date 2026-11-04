import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_location_flutter_plugin/tencent_location_flutter_plugin.dart';

import '../state/request_holder.dart';
import 'geofence_tab.dart';
import 'location_tab.dart';
import 'utils_tab.dart';

/// Demo 主页：顶部 AppBar 放 SDK 版本 / init 按钮；下方 3 个 Tab。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _holder = RequestHolder();

  String _sdkVersion = '…';
  bool _initDone = false;
  bool _privacyAgreed = false;

  @override
  void initState() {
    super.initState();
    _fetchVersion();
  }

  @override
  void dispose() {
    _holder.dispose();
    super.dispose();
  }

  Future<void> _fetchVersion() async {
    try {
      final v = await TencentLocationSDK.getVersion();
      final b = await TencentLocationSDK.getBuildVersion();
      if (!mounted) return;
      setState(() => _sdkVersion = '$v ($b)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sdkVersion = 'N/A');
    }
  }

  Future<void> _initSdk() async {
    final msg = ScaffoldMessenger.of(context);
    try {
      // Android / iOS：先用 permission_handler 申请系统定位权限，否则 SDK 启动后会一直拿不到点。
      // HarmonyOS：permission_handler 等社区插件尚未适配，由插件侧 atManager 弹窗授权。
      //
      // 这里用枚举名字符串比较而不是 `TargetPlatform.ohos`：后者只存在于 HarmonyOS
      // 分支的 Flutter，官方 Flutter 上会编译不过。字符串比较让同一份 demo 代码
      // 在两种 Flutter 上都能通过静态分析。
      final isHarmony = !kIsWeb && defaultTargetPlatform.name == 'ohos';
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          msg.showSnackBar(SnackBar(
              content: Text('⚠️ 未授权定位权限 (status=$status)，请到系统设置开启')));
          return;
        }
      } else if (isHarmony) {
        const channel = MethodChannel('com.tencent.map.geolocation.flutter/method');
        final granted = await channel
            .invokeMethod<bool>('sdk.harmony.requestLocationAuthorization');
        if (granted != true) {
          msg.showSnackBar(const SnackBar(
              content: Text('⚠️ 未授权定位权限，请到系统设置开启')));
          return;
        }
      }

      await TencentLocationSDK.setPrivacyPolicyAgreement(true);
      setState(() => _privacyAgreed = true);

      // 开 SDK 本地日志：必须在 init 之前调用。
      // Android 日志路径：/sdcard/Android/data/<包名>/files/t_log/
      // iOS 原生 SDK 未提供此能力，跳过。
      if (!kIsWeb && Platform.isAndroid) {
        await TencentLocationSDK.enableLogToFile(true);
      }

      // ⚠️ 真机运行前请在下面填写你自己的 ApiKey。
      await TencentLocationSDK.init(
        androidApiKey: _kAndroidApiKey.isEmpty ? null : _kAndroidApiKey,
        iosApiKey: _kIosApiKey.isEmpty ? null : _kIosApiKey,
        harmonyApiKey: _kHarmonyApiKey.isEmpty ? null : _kHarmonyApiKey,
        deviceId: 'flutter_demo',
      );

      // iOS 还要申请系统权限
      if (!kIsWeb && Platform.isIOS) {
        await TencentLocationSDK.requestIosWhenInUseAuthorization();
      }

      setState(() => _initDone = true);
      msg.showSnackBar(const SnackBar(content: Text('✅ init 成功')));
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('init 失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tencent Location Demo'),
              Text(
                'SDK $_sdkVersion',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: _initDone
                    ? const Chip(
                        avatar: Icon(Icons.check, size: 16),
                        label: Text('Init Done',
                            style: TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      )
                    : FilledButton.icon(
                        onPressed: _initSdk,
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Init'),
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
              ),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.my_location), text: '定位'),
            Tab(icon: Icon(Icons.calculate_outlined), text: '工具'),
            Tab(icon: Icon(Icons.fence), text: '围栏'),
          ]),
        ),
        body: Column(
          children: [
            if (!_privacyAgreed)
              Container(
                color: Colors.amber.shade100,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '未初始化。任何定位调用都会抛 privacyNotAgreed / apiKeyInvalid。请点右上角 Init。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  LocationTab(holder: _holder),
                  const UtilsTab(),
                  const GeofenceTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 真机运行时请替换为你自己的 ApiKey。
const String _kAndroidApiKey = 'EXLBZ-B7TH5-CTZIK-QNQFR-76OGO-GNFCS';
const String _kIosApiKey = '7WZBZ-KRGHK-3WGJP-ATMLL-UO7C6-T6BEW';
const String _kHarmonyApiKey = 'YOUR_HARMONY_API_KEY';
