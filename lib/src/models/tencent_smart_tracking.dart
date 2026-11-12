import 'tencent_location.dart';

/// 原生 Smart 动静检测参数。Dart 只传递参数，不运行判定或后台计时器。
///
/// 只有传感器与速度两路都判静时才进入静止档。移动和静止档的实际定位请求，
/// 由 `TencentLocationSDK.startSmartTracking` 的两个 request 分别提供。
class TencentSmartTrackingConfig {
  const TencentSmartTrackingConfig({
    this.stopTimeout = const Duration(minutes: 2),
    this.speedStationaryDelay = const Duration(seconds: 90),
    this.speedMovingThreshold = 5.0,
    this.speedWakeConfirmCount = 3,
    this.releaseWakelockWhenStationary = true,
    this.notificationTitle = 'Tracking active',
    this.notificationText = 'Recording your route in the background',
    this.notificationChannelName = 'Background tracking',
  });

  /// 传感器持续静止时间；到期仍需等待速度一路判静。
  final Duration stopTimeout;

  /// 速度持续处于低速区间后确认静止的时间。
  final Duration speedStationaryDelay;

  /// 静止状态下用于速度唤醒的门槛，单位 m/s。
  final double speedMovingThreshold;

  /// 连续达到速度唤醒门槛的定位点数。
  final int speedWakeConfirmCount;

  /// Android 静止时允许释放 CPU 锁；原生层还会检查硬件唤醒传感器。
  /// iOS 不使用 Android CPU 锁，此字段在 iOS 无作用。
  final bool releaseWakelockWhenStationary;

  final String notificationTitle;
  final String notificationText;
  final String notificationChannelName;

  /// 在发送给原生前校验参数。毫秒是通道传输单位。
  Map<String, Object?> toMap() {
    if (stopTimeout.isNegative || speedStationaryDelay.isNegative) {
      throw ArgumentError('Smart stationary delays must not be negative.');
    }
    if (!speedMovingThreshold.isFinite || speedMovingThreshold <= 0) {
      throw ArgumentError.value(speedMovingThreshold, 'speedMovingThreshold',
          'must be finite and > 0');
    }
    if (speedWakeConfirmCount < 1) {
      throw ArgumentError.value(
          speedWakeConfirmCount, 'speedWakeConfirmCount', 'must be >= 1');
    }
    if ([notificationTitle, notificationText, notificationChannelName]
        .any((value) => value.trim().isEmpty)) {
      throw ArgumentError(
          'Smart tracking notification wording must not be empty.');
    }
    return {
      'stopTimeoutMs': stopTimeout.inMilliseconds,
      'speedStationaryDelayMs': speedStationaryDelay.inMilliseconds,
      'speedMovingThreshold': speedMovingThreshold,
      'speedWakeConfirmCount': speedWakeConfirmCount,
      'releaseWakelockWhenStationary': releaseWakelockWhenStationary,
      'notificationTitle': notificationTitle,
      'notificationText': notificationText,
      'notificationChannelName': notificationChannelName,
    };
  }
}

/// 原生 app-wide Smart 会话的快照。重新打开页面后可读取正在运行的原生会话。
///
/// `wakeLockHeld` / `hasSignificantMotionSensor` 仅描述 Android 能力。
/// `lastLocation` 是最近一条结果，不是 Flutter 退出期间所有点的回放队列。
class TencentSmartTrackingState {
  const TencentSmartTrackingState({
    required this.enabled,
    required this.isMoving,
    required this.accelerometerMoving,
    required this.speedMoving,
    required this.speedState,
    required this.pace,
    required this.wakeLockHeld,
    required this.hasSignificantMotionSensor,
    required this.reason,
    required this.timestampMs,
    required this.locationCount,
    this.lastLocation,
    this.speedMps,
    this.speedSource = 'unknown',
  });

  final bool enabled;
  final bool isMoving;
  final bool accelerometerMoving;
  final bool speedMoving;

  /// `moving`、`slowing` 或 `stationary`。
  final String speedState;

  /// 当前已应用的请求：`high` 或 `low`。
  final String pace;
  final bool wakeLockHeld;
  final bool hasSignificantMotionSensor;
  final String reason;
  final int timestampMs;
  final int locationCount;
  final TencentLocation? lastLocation;
  final double? speedMps;

  /// `platform`、`position_delta` 或 `unknown`。
  final String speedSource;

  factory TencentSmartTrackingState.fromMap(Map map) {
    final location = map['lastLocation'];
    final speed = (map['speedMps'] as num?)?.toDouble();
    if (speed != null && (!speed.isFinite || speed < 0)) {
      throw const FormatException('Invalid Smart tracking speed.');
    }
    if (location != null && location is! Map) {
      throw const FormatException('Invalid Smart tracking lastLocation.');
    }
    return TencentSmartTrackingState(
      enabled: map['enabled'] as bool? ?? false,
      isMoving: map['isMoving'] as bool? ?? false,
      accelerometerMoving: map['accelerometerMoving'] as bool? ?? false,
      speedMoving: map['speedMoving'] as bool? ?? false,
      speedState: map['speedState'] as String? ?? 'stationary',
      pace: map['pace'] as String? ?? 'low',
      wakeLockHeld: map['wakeLockHeld'] as bool? ?? false,
      hasSignificantMotionSensor:
          map['hasSignificantMotionSensor'] as bool? ?? false,
      reason: map['reason'] as String? ?? 'snapshot',
      timestampMs: (map['timestampMs'] as num?)?.toInt() ?? 0,
      locationCount: (map['locationCount'] as num?)?.toInt() ?? 0,
      lastLocation: location is Map ? TencentLocation.fromMap(location) : null,
      speedMps: speed,
      speedSource: map['speedSource'] as String? ?? 'unknown',
    );
  }
}
