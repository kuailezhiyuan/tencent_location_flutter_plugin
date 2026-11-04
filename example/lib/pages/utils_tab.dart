import 'package:flutter/material.dart';
import 'package:tencent_location_flutter_plugin/tencent_location_flutter_plugin.dart';

import '../widgets/labeled_control.dart';
import '../widgets/log_panel.dart';

/// 工具 Tab：演示 `TencentLocationUtils` 所有方法 + `LocationSource` 扩展。
class UtilsTab extends StatefulWidget {
  const UtilsTab({super.key});

  @override
  State<UtilsTab> createState() => _UtilsTabState();
}

class _UtilsTabState extends State<UtilsTab>
    with AutomaticKeepAliveClientMixin {
  final List<String> _logs = [];

  // 固定两个参考点：腾讯大厦 & 天安门
  static const _tencent = TencentLocationCoordinate(
      latitude: 22.540601, longitude: 113.934302);
  static const _tiananmen =
      TencentLocationCoordinate(latitude: 39.908722, longitude: 116.397499);

  @override
  bool get wantKeepAlive => true;

  void _log(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.insert(0, '$ts  $msg');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  Future<void> _distance() async {
    try {
      final d = TencentLocationUtils.distanceBetween(_tencent, _tiananmen);
      _log('distanceBetween(腾讯大厦, 天安门) = ${d.toStringAsFixed(2)} m'
          '  (${(d / 1000).toStringAsFixed(2)} km)');
    } catch (e) {
      _log('distanceBetween fail: $e');
    }
  }

  Future<void> _contains() async {
    try {
      final inside = TencentLocationUtils.contains(
        center: _tencent,
        radius: 500,
        point: const TencentLocationCoordinate(
            latitude: 22.541, longitude: 113.935),
      );
      _log('contains(center=腾讯大厦, r=500m, pt=+100m偏移) = $inside');
    } catch (e) {
      _log('contains fail: $e');
    }
  }

  Future<void> _isSupportGps() async {
    try {
      final ok = await TencentLocationUtils.isSupportGps();
      _log('isSupportGps() = $ok');
    } catch (e) {
      _log('isSupportGps fail: $e');
    }
  }

  Future<void> _wgs84ToGcj02() async {
    try {
      final gcj = await TencentLocationUtils.wgs84ToGcj02(_tiananmen);
      _log('wgs84ToGcj02(天安门) = '
          '(${gcj.latitude.toStringAsFixed(6)}, '
          '${gcj.longitude.toStringAsFixed(6)})');
    } catch (e) {
      _log('wgs84ToGcj02 fail: $e');
    }
  }

  Future<void> _isInRegion() async {
    try {
      final ok = await TencentLocationUtils.isInRegion(
          latitude: _tiananmen.latitude, longitude: _tiananmen.longitude);
      _log('isInRegion(天安门) = $ok');
    } catch (e) {
      _log('isInRegion fail: $e');
    }
  }

  void _demoSourceExtensions() {
    final samples = <LocationSource>[
      LocationSource.androidGps,
      LocationSource.androidWifi,
      LocationSource.androidCache,
      LocationSource.iosGps,
      LocationSource.iosNetwork,
      LocationSource.harmonyGnss,
      LocationSource.harmonyIndoor,
      LocationSource.unknown,
    ];
    _log('── LocationSource 扩展方法 ──');
    for (final s in samples) {
      _log('${s.wireName.padRight(16)}'
          ' isGnss=${s.isGnss ? 'Y' : '.'}'
          ' isNetwork=${s.isNetwork ? 'Y' : '.'}'
          ' isCached=${s.isCached ? 'Y' : '.'}'
          ' isIndoor=${s.isIndoor ? 'Y' : '.'}'
          ' isFused=${s.isFused ? 'Y' : '.'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'TencentLocationUtils',
                  icon: Icons.calculate_outlined,
                ),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '参考点',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        const Text('A: 腾讯大厦 (22.5406, 113.9343)',
                            style: TextStyle(fontFamily: 'monospace')),
                        const Text('B: 天安门  (39.9087, 116.3975)',
                            style: TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: _distance,
                      child: const Text('distanceBetween(A,B)  🅰️🍏🔶'),
                    ),
                    FilledButton.tonal(
                      onPressed: _contains,
                      child: const Text('contains  🅰️🍏🔶'),
                    ),
                    FilledButton.tonal(
                      onPressed: _isSupportGps,
                      child: const Text('isSupportGps  🅰️'),
                    ),
                    FilledButton.tonal(
                      onPressed: _wgs84ToGcj02,
                      child: const Text('wgs84ToGcj02  🍏🔶'),
                    ),
                    FilledButton.tonal(
                      onPressed: _isInRegion,
                      child: const Text('isInRegion  🍏'),
                    ),
                  ],
                ),
                const SectionTitle(
                  title: 'LocationSource 扩展',
                  icon: Icons.link,
                ),
                OutlinedButton.icon(
                  onPressed: _demoSourceExtensions,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('打印 .isGnss / .isNetwork / .isCached …'),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        SizedBox(height: 240, child: LogPanel(
          logs: _logs,
          onClear: () => setState(() => _logs.clear()),
        )),
      ],
    );
  }
}
