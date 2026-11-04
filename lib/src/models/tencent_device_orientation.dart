/// 设备朝向事件。
///
/// 🍏 iOS / 🔶 Harmony 支持；🅰️ Android 不支持（订阅
/// [TencentLocationManager.onOrientationChanged] 时会抛
/// `unsupportedOnThisPlatform`）。
class TencentDeviceOrientation {
  /// 真北方向，范围 [0, 360)。iOS / Harmony 都有。
  final double trueHeading;

  /// 磁北方向。**仅 iOS**。
  final double? magneticHeading;

  /// 精度（偏差最大度数，负数表示无效）。**仅 iOS**。
  final double? accuracy;

  /// 地磁三轴原始值。**仅 iOS**。
  final double? x;
  final double? y;
  final double? z;

  /// Unix 毫秒时间戳。
  final int? timestamp;

  const TencentDeviceOrientation({
    required this.trueHeading,
    this.magneticHeading,
    this.accuracy,
    this.x,
    this.y,
    this.z,
    this.timestamp,
  });

  factory TencentDeviceOrientation.fromMap(Map map) {
    return TencentDeviceOrientation(
      trueHeading: ((map['trueHeading'] as num?) ?? 0).toDouble(),
      magneticHeading: (map['magneticHeading'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      x: (map['x'] as num?)?.toDouble(),
      y: (map['y'] as num?)?.toDouble(),
      z: (map['z'] as num?)?.toDouble(),
      timestamp: map['timestamp'] as int?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'trueHeading': trueHeading,
        'magneticHeading': magneticHeading,
        'accuracy': accuracy,
        'x': x,
        'y': y,
        'z': z,
        'timestamp': timestamp,
      };

  @override
  String toString() =>
      'TencentDeviceOrientation(trueHeading=$trueHeading, magnetic=$magneticHeading, accuracy=$accuracy)';
}
