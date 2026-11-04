import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_location_flutter_plugin/tencent_location_flutter_plugin.dart';

import '../widgets/log_panel.dart';

/// 围栏 Tab：演示 `TencentGeofenceManager` 的三种围栏创建、事件订阅。
class GeofenceTab extends StatefulWidget {
  const GeofenceTab({super.key});

  @override
  State<GeofenceTab> createState() => _GeofenceTabState();
}

class _GeofenceTabState extends State<GeofenceTab>
    with AutomaticKeepAliveClientMixin {
  TencentGeofenceManager? _manager;
  StreamSubscription<TencentGeofenceEvent>? _evtSub;
  StreamSubscription<TencentLocationError>? _errSub;

  final List<String> _logs = [];
  final List<TencentGeofence> _fences = [];

  int _idSeed = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _evtSub?.cancel();
    _errSub?.cancel();
    _manager?.dispose();
    super.dispose();
  }

  void _log(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.insert(0, '$ts  $msg');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  TencentGeofenceManager _ensureManager() {
    if (_manager != null) return _manager!;
    final m = TencentGeofenceManager();
    _manager = m;
    _evtSub = m.onEvent.listen((e) {
      _log('🚨 ${e.geofenceId}: ${e.transition.wireName}'
          '${e.stayedDuration != null ? " stayed=${e.stayedDuration!.inSeconds}s" : ""}');
    });
    _errSub = m.onError.listen((err) {
      _log('❌ ${err.code.wireName}: ${err.message}');
    });
    _log('👤 geofence manager created: id=${m.id}');
    return m;
  }

  Future<void> _addCircle() async {
    final m = _ensureManager();
    final id = 'circle-${_idSeed++}';
    final fence = TencentGeofence.circle(
      id: id,
      center: const TencentLocationCoordinate(
          latitude: 22.540601, longitude: 113.934302),
      radius: 500,
      userInfo: const {'name': '腾讯大厦圆形围栏'},
    );
    try {
      await m.addGeofence(fence);
      setState(() => _fences.add(fence));
      _log('➕ addGeofence circle id=$id r=500m');
    } catch (e) {
      _log('addGeofence circle fail: $e');
    }
  }

  Future<void> _addPolygon() async {
    final m = _ensureManager();
    final id = 'polygon-${_idSeed++}';
    final fence = TencentGeofence.polygon(
      id: id,
      vertices: const [
        TencentLocationCoordinate(latitude: 22.5400, longitude: 113.9330),
        TencentLocationCoordinate(latitude: 22.5415, longitude: 113.9355),
        TencentLocationCoordinate(latitude: 22.5395, longitude: 113.9360),
      ],
      userInfo: const {'name': '三角形围栏'},
    );
    try {
      await m.addGeofence(fence);
      setState(() => _fences.add(fence));
      _log('➕ addGeofence polygon id=$id 顶点=3');
    } catch (e) {
      _log('addGeofence polygon fail: $e');
    }
  }

  Future<void> _addDistrict() async {
    final m = _ensureManager();
    final id = 'district-${_idSeed++}';
    final fence = TencentGeofence.district(
      id: id,
      keyword: '海淀区',
      userInfo: const {'name': '海淀区行政围栏'},
    );
    try {
      await m.addGeofence(fence);
      setState(() => _fences.add(fence));
      _log('➕ addGeofence district id=$id keyword=海淀区');
    } catch (e) {
      _log('addGeofence district fail: $e');
    }
  }

  Future<void> _remove(String id) async {
    try {
      await _manager?.removeGeofence(id);
      setState(() => _fences.removeWhere((f) => f.id == id));
      _log('➖ removeGeofence($id)');
    } catch (e) {
      _log('remove fail: $e');
    }
  }

  Future<void> _removeAll() async {
    try {
      await _manager?.removeAllGeofences();
      setState(_fences.clear);
      _log('🧹 removeAllGeofences');
    } catch (e) {
      _log('removeAll fail: $e');
    }
  }

  Future<void> _listValid() async {
    try {
      final list = await _manager?.getAllGeofences() ?? [];
      _log('ℹ️ getAllGeofences: ${list.length} 个');
      for (final f in list) {
        _log('   - ${f.id} (${f.type.wireName})');
      }
    } catch (e) {
      _log('list fail: $e');
    }
  }

  Future<void> _disposeManager() async {
    await _evtSub?.cancel();
    await _errSub?.cancel();
    await _manager?.dispose();
    if (!mounted) return;
    setState(() {
      _manager = null;
      _evtSub = null;
      _errSub = null;
      _fences.clear();
    });
    _log('🧹 geofence manager disposed');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.icon(
                onPressed: _addCircle,
                icon: const Icon(Icons.circle_outlined, size: 18),
                label: const Text('Circle'),
              ),
              FilledButton.icon(
                onPressed: _addPolygon,
                icon: const Icon(Icons.change_history, size: 18),
                label: const Text('Polygon'),
              ),
              FilledButton.icon(
                onPressed: _addDistrict,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('District'),
              ),
              OutlinedButton.icon(
                onPressed: _listValid,
                icon: const Icon(Icons.list_alt, size: 18),
                label: const Text('列表'),
              ),
              if (_fences.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _removeAll,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('全部移除'),
                ),
              if (_manager != null)
                OutlinedButton.icon(
                  onPressed: _disposeManager,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('dispose'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 3,
          child: _fences.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fence,
                            size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          '点上方按钮添加围栏\n'
                          '• Circle: 三端都支持\n'
                          '• Polygon: 🅰️🍏（Harmony 抛不支持）\n'
                          '• District: 🅰️🍏（Harmony 抛不支持）',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _fences.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = _fences[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(_iconForType(f.type)),
                      title: Text(f.id,
                          style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: Text(_fenceSummary(f)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _remove(f.id),
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: LogPanel(
            logs: _logs,
            onClear: () => setState(() => _logs.clear()),
          ),
        ),
      ],
    );
  }

  String _fenceSummary(TencentGeofence f) {
    final base = 'transitions=${f.monitorTransitions.map((t) => t.wireName).join(",")}';
    switch (f.type) {
      case GeofenceType.circle:
        return '$base  center=(${f.center?.latitude.toStringAsFixed(4)},'
            ' ${f.center?.longitude.toStringAsFixed(4)}) r=${f.radius}m';
      case GeofenceType.polygon:
        return '$base  顶点=${f.polygon?.length ?? 0}';
      case GeofenceType.district:
        return '$base  $_keyword${f.districtKeyword}';
    }
  }

  IconData _iconForType(GeofenceType type) {
    switch (type) {
      case GeofenceType.circle:
        return Icons.circle_outlined;
      case GeofenceType.polygon:
        return Icons.change_history;
      case GeofenceType.district:
        return Icons.map_outlined;
    }
  }

  static const _keyword = 'keyword=';
}
