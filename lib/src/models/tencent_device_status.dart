import '../enums/device_status.dart';

/// 设备 / 开关状态变化事件。
///
/// 🅰️ Android / 🔶 Harmony 支持；🍏 iOS 不支持（订阅
/// [TencentLocationManager.onStatusChanged] 时会抛
/// `unsupportedOnThisPlatform`）。
class TencentDeviceStatus {
  /// 事件对应的设备 / 能力类型。
  final DeviceStatusKind kind;

  /// 当前状态。
  final DeviceStatus status;

  /// 状态描述文案。
  final String? description;

  const TencentDeviceStatus({
    required this.kind,
    required this.status,
    this.description,
  });

  factory TencentDeviceStatus.fromMap(Map map) {
    return TencentDeviceStatus(
      kind: DeviceStatusKindCodec.fromWire(map['kind'] as String?) ??
          DeviceStatusKind.gps,
      status: DeviceStatusCodec.fromWire(map['status'] as String?),
      description: map['description'] as String?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'kind': kind.wireName,
        'status': status.wireName,
        'description': description,
      };

  @override
  String toString() =>
      'TencentDeviceStatus(${kind.wireName}: ${status.wireName}'
      '${description != null ? ', "$description"' : ''})';
}
