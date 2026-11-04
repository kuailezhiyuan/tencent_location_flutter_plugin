import 'dart:math' as math;

import 'models/tencent_location_coordinate.dart';
import 'platform_interface/tencent_location_platform.dart';

/// 定位相关工具方法。
///
/// 原生不支持的平台会抛出 `TencentLocationError`（错误码
/// `unsupportedOnThisPlatform`）。各方法的平台支持情况详见方法注释。
abstract class TencentLocationUtils {
  TencentLocationUtils._();

  static TencentLocationPlatform get _platform =>
      TencentLocationPlatform.instance;

  /// 计算两个坐标点之间的距离，单位：米。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Parameters**:
  /// - [a]：第一个坐标点。
  /// - [b]：第二个坐标点。
  ///
  /// 两个坐标必须在同一坐标系下（均为 GCJ-02 或均为 WGS-84），否则结果无意义。
  ///
  /// **Returns**:
  /// - 球面距离，单位：米。
  static double distanceBetween(
    TencentLocationCoordinate a,
    TencentLocationCoordinate b,
  ) =>
      _haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude);

  /// 判断指定坐标点是否落在以 [center] 为圆心、半径为 [radius] 米的圆形区域内。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Parameters**:
  /// - [center]：圆形区域的中心坐标。
  /// - [radius]：圆形区域的半径，单位：米。
  /// - [point]：待判断的坐标点。
  ///
  /// **Returns**:
  /// - `true` 当且仅当 [point] 与 [center] 之间的球面距离 ≤ [radius]。
  ///   边界点（距离 == 半径）视为包含在圆内。
  static bool contains({
    required TencentLocationCoordinate center,
    required double radius,
    required TencentLocationCoordinate point,
  }) {
    final distance = _haversineMeters(
      center.latitude,
      center.longitude,
      point.latitude,
      point.longitude,
    );
    return distance <= radius;
  }

  /// 当前设备是否支持 GPS。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：支持
  /// - 🍏 iOS：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Returns**:
  /// - `true` 表示当前设备支持 GPS 模块，否则返回 `false`。
  static Future<bool> isSupportGps() => _platform.utilsIsSupportGps();

  /// 坐标是否在国内。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  ///
  /// **Parameters**:
  /// - [latitude]：纬度。
  /// - [longitude]：经度。
  ///
  /// **Returns**:
  /// - `true` 表示坐标位于中国境内，否则返回 `false`。
  static Future<bool> isInRegion({
    required double latitude,
    required double longitude,
  }) =>
      _platform.utilsIsInRegion(
        latitude: latitude,
        longitude: longitude,
      );

  /// WGS-84 坐标转 GCJ-02 坐标。
  ///
  /// **Platforms**:
  /// - 🅰️ Android：不支持，抛出 `TencentLocationError`（错误码 `unsupportedOnThisPlatform`）
  /// - 🍏 iOS：支持
  /// - 🔶 Harmony：支持
  ///
  /// **Parameters**:
  /// - [coord]：待转换的 WGS-84 坐标。
  ///
  /// **Returns**:
  /// - 转换后的 GCJ-02 坐标。
  static Future<TencentLocationCoordinate> wgs84ToGcj02(
    TencentLocationCoordinate coord,
  ) =>
      _platform.utilsWgs84ToGcj02(coord);

  // ==================== 内部计算 ====================

  /// 球面 haversine 距离，单位：米。
  static double _haversineMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final radStartLat = _toRadians(startLatitude);
    final radEndLat = _toRadians(endLatitude);
    final deltaLat = radStartLat - radEndLat;
    final deltaLng = _toRadians(startLongitude) - _toRadians(endLongitude);

    final sinHalfLat = math.sin(deltaLat / 2);
    final sinHalfLng = math.sin(deltaLng / 2);
    final h = sinHalfLat * sinHalfLat +
        math.cos(radStartLat) * math.cos(radEndLat) * sinHalfLng * sinHalfLng;
    var kilometers = 2 * math.asin(math.sqrt(h)) * _earthRadiusKilometers;
    kilometers = (kilometers * 10000).round() / 10000.0;
    return kilometers * 1000;
  }

  static double _toRadians(double degrees) => math.pi * degrees / 180.0;

  /// WGS-84 赤道半径，单位：千米。
  static const double _earthRadiusKilometers = 6378.137;
}
