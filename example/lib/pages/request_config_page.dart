import 'package:flutter/material.dart';
import 'package:tencent_location_flutter_plugin/tencent_location_flutter_plugin.dart';

import '../state/request_holder.dart';
import '../widgets/labeled_control.dart';

/// 全屏弹出的 Request 配置页。
///
/// 4 个 Tab：通用 / 🅰️ Android / 🍏 iOS / 🔶 Harmony，对应 [TencentLocationRequest] 本体
/// 和三个平台扩展。修改直接作用于 [RequestHolder]，关闭页面即生效。
class RequestConfigPage extends StatefulWidget {
  final RequestHolder holder;

  const RequestConfigPage({super.key, required this.holder});

  @override
  State<RequestConfigPage> createState() => _RequestConfigPageState();
}

class _RequestConfigPageState extends State<RequestConfigPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request 配置'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '通用'),
            Tab(text: '🅰️ Android'),
            Tab(text: '🍏 iOS'),
            Tab(text: '🔶 Harmony'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重置为默认',
            onPressed: () {
              widget.holder.reset();
              setState(() {});
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.holder,
        builder: (_, __) => TabBarView(
          controller: _tabController,
          children: [
            _CommonTab(holder: widget.holder),
            _AndroidTab(holder: widget.holder),
            _IosTab(holder: widget.holder),
            _HarmonyTab(holder: widget.holder),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: const Text('完成'),
          ),
        ),
      ),
    );
  }
}

// ========== 通用 ==========

class _CommonTab extends StatelessWidget {
  final RequestHolder holder;
  const _CommonTab({required this.holder});

  @override
  Widget build(BuildContext context) {
    final r = holder.request;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
              title: '通用字段', subtitle: 'TencentLocationRequest'),
          LabeledControl(
            label: '回调间隔',
            description: '连续定位周期',
            child: _DurationField(
              valueMs: r.interval.inMilliseconds,
              onChanged: (ms) => holder.edit(
                  (r) => r.interval = Duration(milliseconds: ms ?? 5000)),
              unit: 'ms',
              step: 1000,
              min: 200,
            ),
          ),
          LabeledControl(
            label: '坐标系',
            child: _EnumDropdown<CoordinateType>(
              value: r.coordinateType,
              values: CoordinateType.values,
              label: (v) => v.wireName,
              onChanged: (v) => holder.edit((r) => r.coordinateType = v),
            ),
          ),
          LabeledControl(
            label: '返回等级',
            description: 'geo / adminArea / name / poi',
            child: _EnumDropdown<RequestLevel>(
              value: r.requestLevel,
              values: RequestLevel.values,
              label: (v) => v.wireName,
              onChanged: (v) => holder.edit((r) => r.requestLevel = v),
            ),
          ),
          _SwitchRow(
            label: '启用传感器方向',
            value: r.allowDirectionSensor,
            onChanged: (v) =>
                holder.edit((r) => r.allowDirectionSensor = v),
          ),
        ],
      ),
    );
  }
}

// ========== Android ==========

class _AndroidTab extends StatelessWidget {
  final RequestHolder holder;
  const _AndroidTab({required this.holder});

  @override
  Widget build(BuildContext context) {
    final a = holder.request.androidExtension;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Android 扩展',
            subtitle: '仅 Android 生效',
            icon: Icons.android,
          ),
          LabeledControl(
            label: 'locMode',
            description: '定位模式',
            child: _EnumDropdown<AndroidLocationMode>(
              value: a.locMode,
              values: AndroidLocationMode.values,
              label: (v) => v.wireName,
              onChanged: (v) => holder.edit((_) => a.locMode = v),
            ),
          ),
          LabeledControl(
            label: 'gnssSource',
            child: _EnumDropdown<AndroidGnssSource>(
              value: a.gnssSource,
              values: AndroidGnssSource.values,
              label: (v) => v.wireName,
              onChanged: (v) => holder.edit((_) => a.gnssSource = v),
            ),
          ),
          _SwitchRow(
            label: 'allowGps',
            value: a.allowGps,
            onChanged: (v) => holder.edit((_) => a.allowGps = v),
          ),
          _SwitchRow(
            label: 'allowBle',
            value: a.allowBle,
            onChanged: (v) => holder.edit((_) => a.allowBle = v),
          ),
          _SwitchRow(
            label: 'allowCache',
            value: a.allowCache,
            onChanged: (v) => holder.edit((_) => a.allowCache = v),
          ),
          _SwitchRow(
            label: 'gpsFirst',
            value: a.gpsFirst,
            onChanged: (v) => holder.edit((_) => a.gpsFirst = v),
          ),
          LabeledControl(
            label: 'gpsFirstTimeout',
            child: _DurationField(
              valueMs: a.gpsFirstTimeout.inMilliseconds,
              onChanged: (ms) => holder.edit((_) =>
                  a.gpsFirstTimeout = Duration(milliseconds: ms ?? 5000)),
              unit: 'ms',
              step: 500,
            ),
          ),
          LabeledControl(
            label: 'firstLocationTimeout',
            child: _DurationField(
              valueMs: a.firstLocationTimeout.inMilliseconds,
              onChanged: (ms) => holder.edit((_) => a.firstLocationTimeout =
                  Duration(milliseconds: ms ?? 15000)),
              unit: 'ms',
              step: 1000,
            ),
          ),
          _SwitchRow(
            label: 'firstLocationNeedAddress',
            value: a.firstLocationNeedAddress,
            onChanged: (v) =>
                holder.edit((_) => a.firstLocationNeedAddress = v),
          ),
          _SwitchRow(
            label: 'indoorMode',
            description: '室内定位',
            value: a.indoorMode,
            onChanged: (v) => holder.edit((_) => a.indoorMode = v),
          ),
          LabeledControl(
            label: 'scene',
            description: '场景化定位（signIn/sport/transport）',
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<AndroidLocationScene?>(
                    value: a.scene,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<AndroidLocationScene?>(
                        value: null,
                        child: Text('（不设置）'),
                      ),
                      ...AndroidLocationScene.values.map(
                        (v) => DropdownMenuItem<AndroidLocationScene?>(
                          value: v,
                          child: Text(v.wireName),
                        ),
                      ),
                    ],
                    onChanged: (v) => holder.edit((_) => a.scene = v),
                  ),
                ),
              ],
            ),
          ),
          LabeledControl(
            label: 'reGeoCodingKey',
            description: '拿 nationCode 必需',
            child: _TextField(
              value: a.reGeoCodingKey,
              hint: '可选',
              onChanged: (v) =>
                  holder.edit((_) => a.reGeoCodingKey = v.isEmpty ? null : v),
            ),
          ),
          LabeledControl(
            label: 'smallAppKey',
            child: _TextField(
              value: a.smallAppKey,
              hint: '可选',
              onChanged: (v) => holder.edit((_) => a.smallAppKey = v),
            ),
          ),
          LabeledControl(
            label: 'qq',
            child: _TextField(
              value: a.qq,
              hint: '可选',
              onChanged: (v) => holder.edit((_) => a.qq = v),
            ),
          ),
          LabeledControl(
            label: 'phoneNumber',
            child: _TextField(
              value: a.phoneNumber,
              hint: '可选',
              onChanged: (v) => holder.edit((_) => a.phoneNumber = v),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== iOS ==========

class _IosTab extends StatelessWidget {
  final RequestHolder holder;
  const _IosTab({required this.holder});

  @override
  Widget build(BuildContext context) {
    final i = holder.request.iosExtension;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'iOS 扩展',
            subtitle: '仅 iOS 生效',
            icon: Icons.apple,
          ),
          LabeledControl(
            label: 'desiredAccuracy',
            child: _EnumDropdown<IosDesiredAccuracy>(
              value: i.desiredAccuracy,
              values: IosDesiredAccuracy.values,
              label: (v) => v.wireName,
              onChanged: (v) => holder.edit((_) => i.desiredAccuracy = v),
            ),
          ),
          _SwitchRow(
            label: 'allowsBackgroundLocationUpdates',
            value: i.allowsBackgroundLocationUpdates,
            onChanged: (v) =>
                holder.edit((_) => i.allowsBackgroundLocationUpdates = v),
          ),
          LabeledControl(
            label: 'distanceFilter',
            description: 'null = None',
            child: _DoubleField(
              value: i.distanceFilter,
              onChanged: (v) => holder.edit((_) => i.distanceFilter = v),
              unit: 'm',
              allowNull: true,
            ),
          ),
          _SwitchRow(
            label: 'pausesLocationUpdatesAutomatically',
            value: i.pausesLocationUpdatesAutomatically,
            onChanged: (v) =>
                holder.edit((_) => i.pausesLocationUpdatesAutomatically = v),
          ),
          LabeledControl(
            label: 'activityType',
            child: _EnumDropdown<IosActivityType>(
              value: i.activityType,
              values: IosActivityType.values,
              label: (v) => v.wireName,
              onChanged: (v) => holder.edit((_) => i.activityType = v),
            ),
          ),
          LabeledControl(
            label: 'headingFilter',
            description: 'null = 不过滤',
            child: _DoubleField(
              value: i.headingFilter,
              onChanged: (v) => holder.edit((_) => i.headingFilter = v),
              unit: '°',
              allowNull: true,
            ),
          ),
          LabeledControl(
            label: 'poiUpdateInterval',
            child: _DurationField(
              valueMs: i.poiUpdateInterval.inMilliseconds,
              onChanged: (ms) => holder.edit((_) =>
                  i.poiUpdateInterval = Duration(milliseconds: ms ?? 10000)),
              unit: 'ms',
              step: 1000,
            ),
          ),
          LabeledControl(
            label: 'singleLocationTimeout',
            description: '仅单次定位生效',
            child: _DurationField(
              valueMs: i.singleLocationTimeout.inMilliseconds,
              onChanged: (ms) => holder.edit((_) => i.singleLocationTimeout =
                  Duration(milliseconds: ms ?? 10000)),
              unit: 'ms',
              step: 1000,
            ),
          ),
        ],
      ),
    );
  }
}

// ========== Harmony ==========

class _HarmonyTab extends StatelessWidget {
  final RequestHolder holder;
  const _HarmonyTab({required this.holder});

  @override
  Widget build(BuildContext context) {
    final h = holder.request.harmonyExtension;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Harmony 扩展',
            subtitle: '仅 HarmonyOS 生效',
            icon: Icons.star_outline,
          ),
          LabeledControl(
            label: 'userActivityScenario',
            description: '与 powerConsumptionScenario 互斥',
            child: DropdownButton<HarmonyUserActivityScenario?>(
              value: h.userActivityScenario,
              isExpanded: true,
              items: [
                const DropdownMenuItem<HarmonyUserActivityScenario?>(
                  value: null,
                  child: Text('（不设置）'),
                ),
                ...HarmonyUserActivityScenario.values.map(
                  (v) => DropdownMenuItem<HarmonyUserActivityScenario?>(
                    value: v,
                    child: Text(v.wireName),
                  ),
                ),
              ],
              onChanged: (v) =>
                  holder.edit((_) => h.userActivityScenario = v),
            ),
          ),
          LabeledControl(
            label: 'powerConsumptionScenario',
            child: DropdownButton<HarmonyPowerConsumptionScenario?>(
              value: h.powerConsumptionScenario,
              isExpanded: true,
              items: [
                const DropdownMenuItem<HarmonyPowerConsumptionScenario?>(
                  value: null,
                  child: Text('（不设置）'),
                ),
                ...HarmonyPowerConsumptionScenario.values.map(
                  (v) => DropdownMenuItem<HarmonyPowerConsumptionScenario?>(
                    value: v,
                    child: Text(v.wireName),
                  ),
                ),
              ],
              onChanged: (v) =>
                  holder.edit((_) => h.powerConsumptionScenario = v),
            ),
          ),
          LabeledControl(
            label: 'locatingPriority',
            child: _EnumDropdown<HarmonyLocatingPriority>(
              value: h.locatingPriority,
              values: HarmonyLocatingPriority.values,
              label: (v) => v.wireName,
              onChanged: (v) => holder.edit((_) => h.locatingPriority = v),
            ),
          ),
          LabeledControl(
            label: 'innerInterval',
            child: _DurationField(
              valueMs: h.innerInterval.inMilliseconds,
              onChanged: (ms) => holder.edit(
                  (_) => h.innerInterval = Duration(milliseconds: ms ?? 1000)),
              unit: 'ms',
              step: 1000,
            ),
          ),
          LabeledControl(
            label: 'reverseGeocodeRequestInterval',
            child: _DurationField(
              valueMs: h.reverseGeocodeRequestInterval.inMilliseconds,
              onChanged: (ms) => holder.edit((_) => h
                  .reverseGeocodeRequestInterval =
                  Duration(milliseconds: ms ?? 10000)),
              unit: 'ms',
              step: 1000,
            ),
          ),
          LabeledControl(
            label: 'firstLocationCachePolicy',
            description: '-1=不缓存, 0=全用, >0=时间内缓存',
            child: _IntField(
              value: h.firstLocationCachePolicy.inSeconds,
              onChanged: (s) => holder.edit((_) =>
                  h.firstLocationCachePolicy = Duration(seconds: s ?? -1)),
              unit: 's',
            ),
          ),
          LabeledControl(
            label: 'singleLocationTimeout',
            description: '仅单次定位生效，最小 1 秒',
            child: _IntField(
              value: h.singleLocationTimeout.inSeconds,
              onChanged: (s) => holder.edit((_) =>
                  h.singleLocationTimeout = Duration(seconds: s ?? 10)),
              unit: 's',
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 通用表单控件 ==========

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  @override
  Widget build(BuildContext context) => LabeledControl(
        label: label,
        description: description,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Switch(value: value, onChanged: onChanged),
        ),
      );
}

class _EnumDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _EnumDropdown({
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButton<T>(
        value: value,
        isExpanded: true,
        items: values
            .map((v) => DropdownMenuItem<T>(value: v, child: Text(label(v))))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
}

class _TextField extends StatefulWidget {
  final String? value;
  final String? hint;
  final ValueChanged<String> onChanged;

  const _TextField({this.value, this.hint, required this.onChanged});

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: widget.onChanged,
      );
}

class _IntField extends StatefulWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final String? unit;
  const _IntField({this.value, required this.onChanged, this.unit});

  @override
  State<_IntField> createState() => _IntFieldState();
}

class _IntFieldState extends State<_IntField> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                widget.onChanged(parsed);
              },
            ),
          ),
          if (widget.unit != null) ...[
            const SizedBox(width: 4),
            Text(widget.unit!, style: const TextStyle(fontSize: 12)),
          ],
        ],
      );
}

class _DoubleField extends StatefulWidget {
  final double? value;
  final ValueChanged<double?> onChanged;
  final String? unit;
  final bool allowNull;
  const _DoubleField({
    this.value,
    required this.onChanged,
    this.unit,
    this.allowNull = false,
  });

  @override
  State<_DoubleField> createState() => _DoubleFieldState();
}

class _DoubleFieldState extends State<_DoubleField> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                border: const OutlineInputBorder(),
                hintText: widget.allowNull ? 'null' : null,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) {
                if (v.isEmpty && widget.allowNull) {
                  widget.onChanged(null);
                  return;
                }
                final parsed = double.tryParse(v);
                widget.onChanged(parsed);
              },
            ),
          ),
          if (widget.unit != null) ...[
            const SizedBox(width: 4),
            Text(widget.unit!, style: const TextStyle(fontSize: 12)),
          ],
        ],
      );
}

class _DurationField extends StatefulWidget {
  final int? valueMs;
  final ValueChanged<int?> onChanged;
  final String unit;
  final int step;
  final int min;

  const _DurationField({
    required this.valueMs,
    required this.onChanged,
    this.unit = 'ms',
    this.step = 1000,
    this.min = 0,
  });

  @override
  State<_DurationField> createState() => _DurationFieldState();
}

class _DurationFieldState extends State<_DurationField> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.valueMs?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.remove, size: 14),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () {
              final cur = int.tryParse(_ctrl.text) ?? 0;
              final next = (cur - widget.step).clamp(widget.min, 1 << 30);
              _ctrl.text = next.toString();
              widget.onChanged(next);
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) {
                if (v.isEmpty) {
                  widget.onChanged(null);
                  return;
                }
                final parsed = int.tryParse(v);
                widget.onChanged(parsed);
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            icon: const Icon(Icons.add, size: 14),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () {
              final cur = int.tryParse(_ctrl.text) ?? 0;
              final next = cur + widget.step;
              _ctrl.text = next.toString();
              widget.onChanged(next);
            },
          ),
          const SizedBox(width: 4),
          Text(widget.unit, style: const TextStyle(fontSize: 12)),
        ],
      );
}
