/// SDK 内部运行日志事件。
///
/// **映射来源**：Android `TencentLocationLogListener.onSDKRunningLogChanged(int logLevel, String log)`。
///
/// 仅 Android 原生会产出此事件，其它平台不发出。
class TencentSdkLogEvent {
  /// 日志级别（Android `android.util.Log` 的常量）：
  /// `2=VERBOSE, 3=DEBUG, 4=INFO, 5=WARN, 6=ERROR`。
  final int level;

  /// 日志正文。
  final String log;

  const TencentSdkLogEvent({required this.level, required this.log});

  factory TencentSdkLogEvent.fromMap(Map map) {
    return TencentSdkLogEvent(
      level: (map['level'] as int?) ?? 4,
      log: (map['log'] as String?) ?? '',
    );
  }

  @override
  String toString() => '[$level] $log';
}
