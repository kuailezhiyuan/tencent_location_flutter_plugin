import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_location_flutter_plugin/tencent_location_flutter_plugin.dart';
import 'package:tencent_location_flutter_plugin/src/platform_interface/tencent_location_method_channel.dart';
import 'package:tencent_location_flutter_plugin/src/platform_interface/tencent_location_platform.dart';

const method = MethodChannel('com.tencent.map.geolocation.flutter/method');
const status =
    MethodChannel('com.tencent.map.geolocation.flutter/event/status');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final eventCalls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TencentLocationPlatform.instance = TencentLocationMethodChannel();
    calls.clear();
    eventCalls.clear();
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      if (call.method == 'smart.getState') {
        return {
          'enabled': true,
          'isMoving': false,
          'accelerometerMoving': false,
          'speedMoving': false,
          'speedState': 'stationary',
          'pace': 'low',
          'wakeLockHeld': false,
          'hasSignificantMotionSensor': true,
          'reason': 'sticky_restart',
          'timestampMs': 1234,
          'locationCount': 9,
          'lastLocation': {'latitude': 30.0, 'longitude': 120.0, 'time': 1234},
          'speedMps': 0.0,
          'speedSource': 'platform',
        };
      }
      if (call.method == 'smart.getLog') return '{"event":"sticky_restart"}\n';
      return null;
    });
    messenger.setMockMethodCallHandler(status, (call) async {
      eventCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockMethodCallHandler(status, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('config keeps native timing and validates before sending', () async {
    const defaults = TencentSmartTrackingConfig();
    expect(defaults.toMap(), {
      'stopTimeoutMs': 120000,
      'speedStationaryDelayMs': 90000,
      'speedMovingThreshold': 5.0,
      'speedWakeConfirmCount': 3,
      'releaseWakelockWhenStationary': true,
      'notificationTitle': 'Tracking active',
      'notificationText': 'Recording your route in the background',
      'notificationChannelName': 'Background tracking',
    });
    for (final bad in [
      const TencentSmartTrackingConfig(stopTimeout: Duration(seconds: -1)),
      const TencentSmartTrackingConfig(
          speedStationaryDelay: Duration(seconds: -1)),
      const TencentSmartTrackingConfig(speedMovingThreshold: double.nan),
      const TencentSmartTrackingConfig(speedMovingThreshold: double.infinity),
      const TencentSmartTrackingConfig(speedMovingThreshold: 0),
      const TencentSmartTrackingConfig(speedWakeConfirmCount: 0),
      const TencentSmartTrackingConfig(notificationTitle: ' '),
    ]) {
      await expectLater(
        TencentLocationSDK.startSmartTracking(
          movingRequest: TencentLocationRequest.create(),
          stationaryRequest: TencentLocationRequest.create(),
          config: bad,
        ),
        throwsArgumentError,
      );
    }
    expect(calls, isEmpty);
  });

  test('start sends two complete Tencent requests without manager ownership',
      () async {
    final moving = TencentLocationRequest.create()
      ..setInterval(const Duration(seconds: 1))
      ..android(
          (request) => request.locMode = AndroidLocationMode.highAccuracy);
    final stationary = moving.copy()
      ..android((request) {
        request.locMode = AndroidLocationMode.onlyNetwork;
        request.allowGps = false;
      });
    await TencentLocationSDK.startSmartTracking(
      movingRequest: moving,
      stationaryRequest: stationary,
      config:
          const TencentSmartTrackingConfig(stopTimeout: Duration(seconds: 15)),
    );
    expect(calls, hasLength(1));
    expect(calls.single.method, 'smart.start');
    final arguments = calls.single.arguments as Map;
    expect(arguments.keys,
        unorderedEquals(['movingRequest', 'stationaryRequest', 'config']));
    expect(arguments['movingRequest'], moving.toMap());
    expect(arguments['stationaryRequest'], stationary.toMap());
    expect((arguments['config'] as Map)['stopTimeoutMs'], 15000);
  });

  test('reads restored native state and calls explicit stop/log methods',
      () async {
    final state = await TencentLocationSDK.getSmartTrackingState();
    expect(state.enabled, isTrue);
    expect(state.isMoving, isFalse);
    expect(state.pace, 'low');
    expect(state.hasSignificantMotionSensor, isTrue);
    expect(state.wakeLockHeld, isFalse);
    expect(state.reason, 'sticky_restart');
    expect(state.locationCount, 9);
    expect(state.lastLocation?.time, 1234);
    expect(state.speedMps, 0.0);
    expect(await TencentLocationSDK.getSmartTrackingLog(),
        contains('sticky_restart'));
    await TencentLocationSDK.clearSmartTrackingLog();
    await TencentLocationSDK.stopSmartTracking();
    expect(calls.map((c) => c.method), [
      'smart.getState',
      'smart.getLog',
      'smart.clearLog',
      'smart.stop',
    ]);
  });

  test('invalid native speed is reported rather than used for display', () {
    expect(
      () => TencentSmartTrackingState.fromMap({'speedMps': double.nan}),
      throwsFormatException,
    );
    expect(
      () => TencentSmartTrackingState.fromMap({'lastLocation': 'bad'}),
      throwsFormatException,
    );
  });

  test('state and location share status channel without driving tracking',
      () async {
    final states = <TencentSmartTrackingState>[];
    final locations = <TencentLocation>[];
    final errors = <Object>[];
    final stateSubscription = TencentLocationSDK.onSmartTrackingChanged
        .listen(states.add, onError: errors.add);
    final locationSubscription = TencentLocationSDK.onSmartLocationChanged
        .listen(locations.add, onError: errors.add);
    await Future<void>.delayed(Duration.zero);
    void send(Map<String, Object?> event) {
      ServicesBinding.instance.channelBuffers.push(
        status.name,
        const StandardMethodCodec().encodeSuccessEnvelope(event),
        (_) {},
      );
    }

    send({
      'event': 'onSdkLog',
      'payload': {'message': 'other event'}
    });
    send({
      'type': 'smartState',
      'data': {'enabled': true, 'pace': 'low', 'reason': 'sensor_stationary'}
    });
    send({
      'type': 'smartLocation',
      'data': {'latitude': 30.0, 'longitude': 120.0, 'time': 1234}
    });
    await Future<void>.delayed(Duration.zero);
    expect(states.single.reason, 'sensor_stationary');
    expect(locations.single.time, 1234);
    expect(errors, isEmpty);
    expect(eventCalls.map((c) => c.method), ['listen']);
    await stateSubscription.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(eventCalls.map((c) => c.method), ['listen']);
    await locationSubscription.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(eventCalls.map((c) => c.method), ['listen', 'cancel']);
    expect(calls, isEmpty,
        reason: 'No implicit start, stop or subscription lifecycle command');
  });

  test('unsupported platforms fail before invoking native methods', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await expectLater(
      TencentLocationSDK.getSmartTrackingState(),
      throwsA(isA<TencentLocationError>().having(
        (error) => error.code,
        'code',
        TencentLocationErrorCode.unsupportedOnThisPlatform,
      )),
    );
    expect(calls, isEmpty);
  });
}
