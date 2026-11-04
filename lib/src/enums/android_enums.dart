/// Android 定位模式。
///
/// **映射来源**：Android `TencentLocationRequest`：
/// - `HIGH_ACCURACY_MODE`=10
/// - `ONLY_NETWORK`=11
/// - `ONLY_GPS`=12
enum AndroidLocationMode {
  /// 高精度。**默认值**。
  highAccuracy,

  /// 仅网络。
  onlyNetwork,

  /// 仅 GPS。
  onlyGps,
}

extension AndroidLocationModeCodec on AndroidLocationMode {
  String get wireName {
    switch (this) {
      case AndroidLocationMode.highAccuracy:
        return 'highAccuracy';
      case AndroidLocationMode.onlyNetwork:
        return 'onlyNetwork';
      case AndroidLocationMode.onlyGps:
        return 'onlyGps';
    }
  }

  static AndroidLocationMode? fromWire(String? wire) {
    for (final value in AndroidLocationMode.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

/// Android GNSS 来源。
///
/// **映射来源**：Android `TencentLocationRequest`：
/// - `GNSS_SOURCE_GPS_FIRST`=20
/// - `GNSS_SOURCE_BEIDOU_FIRST`=21
/// - `GNSS_SOURCE_BEIDOU_ONLY`=22
/// - `GNSS_SOURCE_RTK_FIRST`=31
enum AndroidGnssSource {
  /// GPS 优先。**默认值**。
  gpsFirst,

  /// 北斗优先。
  beidouFirst,

  /// 仅北斗。
  beidouOnly,

  /// RTK 优先。
  rtkFirst,
}

extension AndroidGnssSourceCodec on AndroidGnssSource {
  String get wireName {
    switch (this) {
      case AndroidGnssSource.gpsFirst:
        return 'gpsFirst';
      case AndroidGnssSource.beidouFirst:
        return 'beidouFirst';
      case AndroidGnssSource.beidouOnly:
        return 'beidouOnly';
      case AndroidGnssSource.rtkFirst:
        return 'rtkFirst';
    }
  }

  static AndroidGnssSource? fromWire(String? wire) {
    for (final value in AndroidGnssSource.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

/// Android 场景化定位。
///
/// **映射来源**：Android `TencentLocationManager`：
/// - `SIGN_IN_SCENE`=10（签到）
/// - `SPORT_SCENE`=11（运动）
/// - `TRANSPORT_SCENE`=12（出行）
///
/// 设置此字段后 Native 端走 `requestLocationWithScene(scene, listener)` 路径，
/// 一次性配好该场景的最佳参数（会覆盖 request 中大部分其他字段）。
///
/// ⚠️ 与 Harmony 的 `UserActivityScenario` **不是同一概念**（鸿蒙那个是功耗+精度策略，
/// 不是业务场景）。
enum AndroidLocationScene {
  /// 签到：单次定位，首次优先高精度。
  signIn,

  /// 运动：高精度连续定位，内部启动 DR。
  sport,

  /// 出行：高精度连续定位，卫星优先。
  transport,
}

extension AndroidLocationSceneCodec on AndroidLocationScene {
  String get wireName {
    switch (this) {
      case AndroidLocationScene.signIn:
        return 'signIn';
      case AndroidLocationScene.sport:
        return 'sport';
      case AndroidLocationScene.transport:
        return 'transport';
    }
  }

  static AndroidLocationScene? fromWire(String? wire) {
    for (final value in AndroidLocationScene.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}
