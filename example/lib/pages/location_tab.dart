import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_location_flutter_plugin/tencent_location_flutter_plugin.dart';

import '../state/request_holder.dart';
import '../widgets/location_card.dart';
import '../widgets/log_panel.dart';
import 'request_config_page.dart';

/// 定位 Tab：核心流程演示。
///
/// 按钮顺序与实际调用顺序一致：
/// 1. 配置 Request（弹出页）
/// 2. Start 连续定位 / Single 单次定位
/// 3. Get Last 拉最近一次缓存
/// 4. Stop / Dispose
class LocationTab extends StatefulWidget {
  final RequestHolder holder;
  const LocationTab({super.key, required this.holder});

  @override
  State<LocationTab> createState() => _LocationTabState();
}

class _LocationTabState extends State<LocationTab>
    with AutomaticKeepAliveClientMixin {
  TencentLocationManager? _manager;
  StreamSubscription<TencentLocation>? _locSub;
  StreamSubscription<TencentLocationError>? _errSub;
  StreamSubscription<TencentDeviceStatus>? _statusSub;
  StreamSubscription<TencentDeviceOrientation>? _orientationSub;

  /// 最近一次连续定位结果（给上方卡片展示）。
  TencentLocation? _lastLocation;

  /// 单次/最近位置的结果（另一个卡片）。
  TencentLocation? _oneshot;
  String? _oneshotTitle;

  final List<String> _logs = [];

  bool _continuousRunning = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _locSub?.cancel();
    _errSub?.cancel();
    _statusSub?.cancel();
    _orientationSub?.cancel();
    _manager?.dispose();
    super.dispose();
  }

  TencentLocationManager _ensureManager() {
    if (_manager != null) return _manager!;
    final m = TencentLocationManager();
    _manager = m;
    _locSub = m.onLocationChanged.listen((loc) {
      if (!mounted) return;
      setState(() => _lastLocation = loc);
      _log('📍 loc: ${loc.source.wireName} '
          'acc=${loc.accuracy?.toStringAsFixed(1)}m '
          'spd=${loc.speed?.toStringAsFixed(2) ?? '-'}m/s');
    });
    _errSub = m.onLocationError.listen((err) {
      _log('❌ ${err.code.wireName}: ${err.message}');
    });
    _log('👤 manager created: id=${m.id}');
    return m;
  }

  void _log(String msg) {
    if (!mounted) return;
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    setState(() {
      _logs.insert(0, '$ts  $msg');
      if (_logs.length > 200) _logs.removeRange(200, _logs.length);
    });
  }

  Future<void> _openConfig() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RequestConfigPage(holder: widget.holder),
    ));
    setState(() {});
  }

  Future<void> _start() async {
    try {
      final m = _ensureManager();
      await m.startContinuousLocation(widget.holder.request);
      setState(() => _continuousRunning = true);
      _log('▶️ startContinuousLocation');
    } catch (e) {
      _log('start fail: $e');
    }
  }

  Future<void> _stop() async {
    try {
      await _manager?.stopContinuousLocation();
      setState(() => _continuousRunning = false);
      _log('⏹️ stopContinuousLocation');
    } catch (e) {
      _log('stop fail: $e');
    }
  }

  Future<void> _single() async {
    try {
      final m = _ensureManager();
      _log('🎯 startSingleLocation ...');
      final loc = await m.startSingleLocation(widget.holder.request);
      if (!mounted) return;
      setState(() {
        _oneshot = loc;
        _oneshotTitle = '单次定位';
      });
      _log('✔️ single ok: poi=${loc.poiList.length}');
    } catch (e) {
      _log('single fail: $e');
    }
  }

  Future<void> _getLast() async {
    try {
      final m = _ensureManager();
      final loc = await m.getLastLocation();
      if (!mounted) return;
      if (loc == null) {
        _log('ℹ️ last: null (尚无定位结果)');
      } else {
        setState(() {
          _oneshot = loc;
          _oneshotTitle = '最近位置（getLastLocation）';
        });
        _log('ℹ️ last loaded');
      }
    } catch (e) {
      _log('getLast fail: $e');
    }
  }

  Future<void> _changeInterval() async {
    final current = widget.holder.request.interval;
    try {
      await _manager?.changeCallbackInterval(current);
      _log('🔁 changeCallbackInterval(${current.inMilliseconds}ms)');
    } catch (e) {
      _log('changeInterval fail: $e');
    }
  }

  Future<void> _toggleStatus() async {
    if (_statusSub != null) {
      await _statusSub!.cancel();
      if (!mounted) return;
      setState(() => _statusSub = null);
      _log('🛰️ 已取消设备状态订阅');
      return;
    }
    try {
      final m = _ensureManager();
      final sub = m.onStatusChanged.listen(
        (event) => _log('🛰️ status: ${event.kind.wireName} → '
            '${event.status.wireName}'
            '${event.description != null ? ' (${event.description})' : ''}'),
        onError: (Object err) => _log('🛰️ status error: $err'),
      );
      if (!mounted) return;
      setState(() => _statusSub = sub);
      _log('🛰️ 已订阅设备状态（iOS 不发事件）');
    } catch (e) {
      _log('subscribe status fail: $e');
    }
  }

  Future<void> _toggleOrientation() async {
    if (_orientationSub != null) {
      await _orientationSub!.cancel();
      if (!mounted) return;
      setState(() => _orientationSub = null);
      _log('🧭 已取消设备朝向订阅');
      return;
    }
    try {
      final m = _ensureManager();
      final sub = m.onOrientationChanged.listen(
        (event) => _log('🧭 heading: '
            '${event.trueHeading.toStringAsFixed(1)}°'),
        onError: (Object err) => _log('🧭 orientation error: $err'),
      );
      if (!mounted) return;
      setState(() => _orientationSub = sub);
      _log('🧭 已订阅设备朝向（Android 不发事件）');
    } catch (e) {
      _log('subscribe orientation fail: $e');
    }
  }

  Future<void> _disposeManager() async {
    await _locSub?.cancel();
    await _errSub?.cancel();
    await _statusSub?.cancel();
    await _orientationSub?.cancel();
    await _manager?.dispose();
    if (!mounted) return;
    setState(() {
      _manager = null;
      _locSub = null;
      _errSub = null;
      _statusSub = null;
      _orientationSub = null;
      _continuousRunning = false;
      _lastLocation = null;
    });
    _log('🧹 manager disposed');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildToolbar(),
        const Divider(height: 1),
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (_lastLocation != null)
                SliverToBoxAdapter(
                  child: LocationCard(
                    location: _lastLocation!,
                    title: '最新实时定位（连续）',
                  ),
                ),
              if (_oneshot != null)
                SliverToBoxAdapter(
                  child: LocationCard(
                    location: _oneshot!,
                    title: _oneshotTitle,
                  ),
                ),
              if (_lastLocation == null && _oneshot == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            '点击 "开始定位" 启动连续定位\n或 "单次" 获取一次位置',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(height: 180, child: LogPanel(
          logs: _logs,
          onClear: () => setState(() => _logs.clear()),
        )),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openConfig,
                  icon: const Icon(Icons.tune),
                  label: Text(
                    '配置 Request（间隔 '
                    '${widget.holder.request.interval.inSeconds}s, '
                    '${widget.holder.request.requestLevel.wireName}）',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (!_continuousRunning)
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('开始定位'),
                )
              else
                FilledButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('停止'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _single,
                icon: const Icon(Icons.gps_fixed, size: 18),
                label: const Text('单次'),
              ),
              OutlinedButton.icon(
                onPressed: _getLast,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('最近位置'),
              ),
              if (_continuousRunning)
                OutlinedButton.icon(
                  onPressed: _changeInterval,
                  icon: const Icon(Icons.speed, size: 18),
                  label: const Text('应用间隔'),
                ),
              if (_manager != null)
                OutlinedButton.icon(
                  onPressed: _toggleStatus,
                  icon: Icon(
                    _statusSub == null
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 18,
                  ),
                  label: Text(_statusSub == null ? '订阅状态' : '取消状态'),
                ),
              if (_manager != null)
                OutlinedButton.icon(
                  onPressed: _toggleOrientation,
                  icon: Icon(
                    _orientationSub == null
                        ? Icons.explore_outlined
                        : Icons.explore_off_outlined,
                    size: 18,
                  ),
                  label: Text(_orientationSub == null ? '订阅朝向' : '取消朝向'),
                ),
              if (_manager != null)
                OutlinedButton.icon(
                  onPressed: _disposeManager,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('dispose'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
