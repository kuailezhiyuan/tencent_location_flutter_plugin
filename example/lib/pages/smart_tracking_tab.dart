import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_location_flutter_plugin/tencent_location_flutter_plugin.dart';

import '../widgets/location_card.dart';
import '../widgets/log_panel.dart';

/// 原生 Smart 验证页。所有动静判定、计时、切档和服务恢复都在原生端。
class SmartTrackingTab extends StatefulWidget {
  const SmartTrackingTab({super.key, required this.initialized});

  final bool initialized;

  @override
  State<SmartTrackingTab> createState() => _SmartTrackingTabState();
}

class _SmartTrackingTabState extends State<SmartTrackingTab>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  StreamSubscription<TencentSmartTrackingState>? _stateSubscription;
  StreamSubscription<TencentLocation>? _locationSubscription;
  TencentSmartTrackingState? _state;
  TencentLocation? _location;
  final List<String> _logs = [];
  bool _busy = false;
  bool _shortTest = false;
  bool _releaseLock = true;
  DateTime? _lastCallback;
  int? _callbackIntervalMs;
  int _visibleLocationCount = 0;

  bool get _android => defaultTargetPlatform == TargetPlatform.android;
  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  bool get _supported => !kIsWeb && (_android || _ios);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_supported) return;
    _stateSubscription = TencentLocationSDK.onSmartTrackingChanged.listen(
      (state) {
        if (!mounted) return;
        setState(() => _state = state);
        _log('状态: ${state.enabled ? state.pace : 'stopped'} / '
            'accel=${state.accelerometerMoving} / '
            'speed=${state.speedState} / ${state.reason}');
      },
      onError: (Object error, StackTrace stack) =>
          _reportError('receive Smart state', error, stack),
    );
    _locationSubscription = TencentLocationSDK.onSmartLocationChanged.listen(
      (location) {
        if (!mounted) return;
        final now = DateTime.now();
        setState(() {
          _callbackIntervalMs = _lastCallback == null
              ? null
              : now.difference(_lastCallback!).inMilliseconds;
          _lastCallback = now;
          _location = location;
          _visibleLocationCount++;
        });
        _log('定位: ${location.source.wireName} '
            'acc=${location.accuracy?.toStringAsFixed(1)}m '
            'speed=${location.speed?.toStringAsFixed(2)}m/s '
            'fix=${location.time} interval=$_callbackIntervalMs ms');
      },
      onError: (Object error, StackTrace stack) =>
          _reportError('receive Smart location', error, stack),
    );
    unawaited(_run('read restored native state', _refresh));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_supported && state == AppLifecycleState.resumed) {
      unawaited(_run('refresh resumed native state', _refresh));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cancelSubscriptions());
    // The app-wide native session is stopped only by the explicit Stop button.
    super.dispose();
  }

  Future<void> _cancelSubscriptions() async {
    for (final subscription in [_stateSubscription, _locationSubscription]) {
      try {
        await subscription?.cancel();
      } catch (error, stack) {
        debugPrint('Smart demo: cancelling event subscription failed: $error');
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  void _log(String message) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, '${DateTime.now().toIso8601String()} $message');
      if (_logs.length > 200) _logs.removeRange(200, _logs.length);
    });
  }

  void _reportError(String operation, Object error, StackTrace stack) {
    debugPrint('Smart demo: $operation failed: $error');
    debugPrintStack(stackTrace: stack);
    _log('$operation failed: $error\n$stack');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$operation: $error')));
    }
  }

  Future<void> _run(String operation, Future<void> Function() action) async {
    if (_busy) return;
    if (mounted) setState(() => _busy = true);
    try {
      await action();
    } catch (error, stack) {
      _reportError(operation, error, stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final state = await TencentLocationSDK.getSmartTrackingState();
    if (!mounted) return;
    setState(() {
      _state = state;
      if (state.lastLocation != null) _location = state.lastLocation;
    });
    _log('原生快照: ${state.enabled ? state.pace : 'stopped'} / '
        'count=${state.locationCount} / ${state.reason}');
  }

  Future<bool> _permissions() async {
    if (!(await Permission.locationWhenInUse.request()).isGranted) {
      throw StateError('请先授予使用期间定位权限，并选择精确位置。');
    }
    if (!(await Permission.locationAlways.status).isGranted) {
      if (_ios && (await Permission.locationAlways.request()).isGranted) {
        _log('已取得始终定位权限');
      } else {
        if (!mounted) return false;
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('后台测试需要始终允许定位'),
            content: const Text('请在系统设置中开启“始终允许”及精确定位。'
                '返回后再次点“开始 Smart”。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('打开设置'),
              ),
            ],
          ),
        );
        if (openSettings == true && !await openAppSettings()) {
          throw StateError('系统应用设置无法打开。');
        }
        return false;
      }
    }
    if (_android && !(await Permission.notification.request()).isGranted) {
      throw StateError('请开启通知权限，以便验证常驻录制通知。');
    }
    if (_ios && !(await Permission.sensors.request()).isGranted) {
      _log('运动与健身未授权，原生层将使用可用的传感器降级路径。');
    }
    return true;
  }

  Future<void> _start() async {
    if (!widget.initialized) throw StateError('请先点右上角 Init 初始化腾讯 SDK。');
    if (!await _permissions()) return;
    final moving = TencentLocationRequest.create()
      ..setCoordinateType(CoordinateType.wgs84)
      ..setRequestLevel(RequestLevel.geo)
      ..setInterval(const Duration(seconds: 1))
      ..android((request) {
        request.locMode = AndroidLocationMode.highAccuracy;
        request.allowGps = true;
      })
      ..ios((request) {
        request.desiredAccuracy = IosDesiredAccuracy.best;
        request.distanceFilter = 0;
        request.allowsBackgroundLocationUpdates = true;
        request.pausesLocationUpdatesAutomatically = false;
      });
    final stationary = moving.copy()
      ..android((request) {
        request.locMode = AndroidLocationMode.onlyNetwork;
        request.allowGps = false;
      })
      ..ios((request) {
        request.desiredAccuracy = IosDesiredAccuracy.hundredMeters;
      });
    await TencentLocationSDK.startSmartTracking(
      movingRequest: moving,
      stationaryRequest: stationary,
      config: TencentSmartTrackingConfig(
        stopTimeout: _shortTest
            ? const Duration(seconds: 15)
            : const Duration(minutes: 2),
        speedStationaryDelay: _shortTest
            ? const Duration(seconds: 15)
            : const Duration(seconds: 90),
        releaseWakelockWhenStationary: _releaseLock,
        notificationTitle: 'Smart 轨迹测试',
        notificationText: '腾讯定位正在后台录制',
        notificationChannelName: 'Smart 后台定位测试',
      ),
    );
    _lastCallback = null;
    _visibleLocationCount = 0;
    _log('开始 Smart；移动和静止请求均由腾讯 SDK 执行。');
    await _refresh();
  }

  Future<void> _stop() async {
    await TencentLocationSDK.stopSmartTracking();
    await _refresh();
  }

  Future<void> _copyNativeLog() async {
    final log = await TencentLocationSDK.getSmartTrackingLog();
    await Clipboard.setData(ClipboardData(text: log));
    _log('已复制原生诊断 JSONL（${log.length} 字符）。');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_supported) {
      return const Center(child: Text('Smart 测试仅支持 Android / iOS。'));
    }
    final state = _state;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('先停止“定位”页的普通连续定位，再开始 Smart。'
              '锁屏平放等待 Low，随后走动验证 High。'
              '重开 App 后点刷新查看原生会话；关闭页面不会停止。'),
        ),
        SwitchListTile(
          title: const Text('短测参数：两路判静均为 15 秒'),
          subtitle: const Text('关闭时：传感器 2 分钟、速度 90 秒；速度唤醒 5 m/s 连续 3 点。'),
          value: _shortTest,
          onChanged: _busy || state?.enabled == true
              ? null
              : (value) => setState(() => _shortTest = value),
        ),
        if (_android)
          SwitchListTile(
            title: const Text('静止时释放 CPU 锁'),
            subtitle: const Text('原生层仅在硬件运动唤醒可用时释放。'),
            value: _releaseLock,
            onChanged: _busy || state?.enabled == true
                ? null
                : (value) => setState(() => _releaseLock = value),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton(
                onPressed: _busy || state?.enabled == true
                    ? null
                    : () => _run('start Smart', _start),
                child: const Text('开始 Smart'),
              ),
              OutlinedButton(
                onPressed: _busy || state?.enabled != true
                    ? null
                    : () => _run('stop Smart', _stop),
                child: const Text('停止 Smart'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _run('refresh Smart', _refresh),
                child: const Text('刷新原生状态'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run('copy native log', _copyNativeLog),
                child: const Text('复制原生 JSONL'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            '会话：${state == null ? '读取中' : state.enabled ? '运行' : '停止'} '
            '档位：${state?.pace ?? '-'}\n'
            '移动：${state?.isMoving}  传感器：${state?.accelerometerMoving} '
            '速度：${state?.speedMoving} (${state?.speedState ?? '-'})\n'
            '快照判定速度：${state?.speedMps?.toStringAsFixed(2) ?? '-'} m/s '
            '来源：${state?.speedSource ?? '-'}\n'
            '${_android ? 'CPU 锁：${state?.wakeLockHeld} '
                '硬件唤醒：${state?.hasSignificantMotionSensor}\n' : ''}'
            '原生快照点数：${state?.locationCount ?? 0} '
            '本页面收到：$_visibleLocationCount\n'
            '最近回调间隔：${_callbackIntervalMs ?? '-'} ms\n'
            '原因：${state?.reason ?? '-'}',
          ),
        ),
        if (_location != null)
          LocationCard(location: _location!, title: '最近腾讯定位结果'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('原生日志用于诊断状态和服务恢复；实时事件没有完整定位回放队列。'
              'START_STICKY 仍受系统策略约束，iOS 用户强退后不保证继续定位。'),
        ),
        SizedBox(
          height: 300,
          child: LogPanel(
            logs: _logs,
            onClear: () => setState(_logs.clear),
          ),
        ),
      ],
    );
  }
}
