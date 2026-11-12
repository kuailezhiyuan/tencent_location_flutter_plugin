import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_location_flutter_plugin/src/platform_interface/tencent_location_method_channel.dart';
import 'package:tencent_location_flutter_plugin/src/platform_interface/tencent_location_platform.dart';
import 'package:tencent_location_flutter_plugin_example/pages/smart_tracking_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'reopening test page discovers native session without starting one',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const method = MethodChannel('com.tencent.map.geolocation.flutter/method');
    const status =
        MethodChannel('com.tencent.map.geolocation.flutter/event/status');
    final calls = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    TencentLocationPlatform.instance = TencentLocationMethodChannel();
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call.method);
      if (call.method == 'smart.getState') {
        return {
          'enabled': true,
          'isMoving': false,
          'pace': 'low',
          'reason': 'sticky_restart',
          'locationCount': 42
        };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(status, (_) async => null);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SmartTrackingTab(initialized: false)),
    ));
    await tester.pumpAndSettle();
    expect(calls, ['smart.getState']);
    expect(find.textContaining('原生快照点数：42'), findsOneWidget);
    expect(find.textContaining('sticky_restart'), findsWidgets);
    expect(calls, ['smart.getState']);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(calls, ['smart.getState'],
        reason: 'Leaving the page must not stop native recording');
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockMethodCallHandler(status, null);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
