import 'package:flutter/material.dart';
import 'package:tencent_location_flutter_plugin/tencent_location_flutter_plugin.dart';

/// 展示一次定位结果的卡片。字段按 common → Android / iOS / Harmony 分组。
class LocationCard extends StatelessWidget {
  final TencentLocation location;
  final String? title;

  const LocationCard({super.key, required this.location, this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  title!,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Row(
              children: [
                Icon(Icons.location_on, color: cs.primary, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '(${location.latitude?.toStringAsFixed(6) ?? '-'}, '
                    '${location.longitude?.toStringAsFixed(6) ?? '-'})',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Chip(
                  label: Text(location.source.wireName,
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _kv('精度', '${location.accuracy?.toStringAsFixed(1) ?? '-'} m'),
                _kv('海拔', '${location.altitude?.toStringAsFixed(1) ?? '-'} m'),
                _kv('速度',
                    '${location.speed?.toStringAsFixed(2) ?? '-'} m/s'),
                _kv('方向', '${location.bearing?.toStringAsFixed(1) ?? '-'}°'),
                if (location.directionFromSensor != null)
                  _kv('传感器方向',
                      '${location.directionFromSensor!.toStringAsFixed(1)}°'),
                _kv('坐标系', location.coordinateType.wireName),
              ],
            ),
            if (location.geoAddress != null) ...[
              const Divider(height: 16),
              Text(
                location.geoAddress!.address ?? '',
                style: const TextStyle(fontSize: 12),
              ),
              if ((location.geoAddress!.name ?? '').isNotEmpty)
                Text(
                  '📍 ${location.geoAddress!.name}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
            ],
            if (location.poiList.isNotEmpty) ...[
              const Divider(height: 16),
              Text(
                '附近 POI (${location.poiList.length})',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              ...location.poiList.take(3).map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '• ${p.name} '
                        '(${p.distance?.toStringAsFixed(1) ?? '-'}m)',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
            ],
            // 平台专属 —— 只有非空才展示
            if (location.elapsedRealtime != null ||
                location.gpsRssi != null ||
                location.verticalAccuracy != null ||
                location.cacheSource != 'none') ...[
              const Divider(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (location.elapsedRealtime != null)
                    _kv('🅰️ elapsedRealtime',
                        '${location.elapsedRealtime}'),
                  if (location.gpsRssi != null)
                    _kv('🅰️ gpsRssi', '${location.gpsRssi}'),
                  if (location.verticalAccuracy != null)
                    _kv('🍏 verticalAccuracy',
                        '${location.verticalAccuracy!.toStringAsFixed(1)}m'),
                  if (location.cacheSource != 'none')
                    _kv('🔶 cacheSource', location.cacheSource),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$k: ',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          Text(
            v,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}
