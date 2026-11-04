/// iOS 期望精度。
///
/// **映射来源**：iOS `kCLLocationAccuracyBest / BestForNavigation / NearestTenMeters /
/// HundredMeters / Kilometer / ThreeKilometers`。
enum IosDesiredAccuracy {
  /// 最佳精度。**默认值**。
  best,

  /// 导航用最佳精度。
  bestForNavigation,

  /// 10 米级。
  nearestTenMeters,

  /// 100 米级。
  hundredMeters,

  /// 千米级。
  kilometer,

  /// 3 千米级。
  threeKilometers,
}

extension IosDesiredAccuracyCodec on IosDesiredAccuracy {
  String get wireName {
    switch (this) {
      case IosDesiredAccuracy.best:
        return 'best';
      case IosDesiredAccuracy.bestForNavigation:
        return 'bestForNavigation';
      case IosDesiredAccuracy.nearestTenMeters:
        return 'nearestTenMeters';
      case IosDesiredAccuracy.hundredMeters:
        return 'hundredMeters';
      case IosDesiredAccuracy.kilometer:
        return 'kilometer';
      case IosDesiredAccuracy.threeKilometers:
        return 'threeKilometers';
    }
  }

  static IosDesiredAccuracy? fromWire(String? wire) {
    for (final value in IosDesiredAccuracy.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

/// iOS 活动类型。
///
/// **映射来源**：iOS `CLActivityType.Other / AutomotiveNavigation / Fitness /
/// OtherNavigation / Airborne`。
enum IosActivityType {
  /// 其它。**默认值**。
  other,

  /// 车载导航。
  automotiveNavigation,

  /// 健身。
  fitness,

  /// 其它导航。
  otherNavigation,

  /// 航空。
  airborne,
}

extension IosActivityTypeCodec on IosActivityType {
  String get wireName {
    switch (this) {
      case IosActivityType.other:
        return 'other';
      case IosActivityType.automotiveNavigation:
        return 'automotiveNavigation';
      case IosActivityType.fitness:
        return 'fitness';
      case IosActivityType.otherNavigation:
        return 'otherNavigation';
      case IosActivityType.airborne:
        return 'airborne';
    }
  }

  static IosActivityType? fromWire(String? wire) {
    for (final value in IosActivityType.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

/// 系统当前实际的精度权限状态。
///
/// **映射来源**：iOS `TencentLBSAccuracyAuthorization`：`FullAccuracy / ReducedAccuracy`。
///
/// 仅 iOS 14+ 可用；其它平台调用 `getIosAccuracyAuthorization()` 恒返回 [fullAccuracy]。
enum IosAccuracyAuthorization {
  /// 精确定位。
  fullAccuracy,

  /// 模糊定位（位置精度约 5km，更新频率降低）。
  reducedAccuracy,
}

extension IosAccuracyAuthorizationCodec on IosAccuracyAuthorization {
  String get wireName {
    switch (this) {
      case IosAccuracyAuthorization.fullAccuracy:
        return 'fullAccuracy';
      case IosAccuracyAuthorization.reducedAccuracy:
        return 'reducedAccuracy';
    }
  }

  static IosAccuracyAuthorization fromWire(String? wire) {
    for (final value in IosAccuracyAuthorization.values) {
      if (value.wireName == wire) return value;
    }
    return IosAccuracyAuthorization.fullAccuracy;
  }
}
