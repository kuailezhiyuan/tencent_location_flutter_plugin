/// manager id 生成器（insert-only int 计数，配合前缀）。
class ManagerIdGenerator {
  ManagerIdGenerator._();

  static int _locSeq = 0;
  static int _geoSeq = 0;

  /// 生成定位 manager 的 ID，形如 `loc-1`, `loc-2`, ...
  static String nextLocationManagerId() => 'loc-${++_locSeq}';

  /// 生成围栏 manager 的 ID，形如 `geo-1`, `geo-2`, ...
  static String nextGeofenceManagerId() => 'geo-${++_geoSeq}';
}
