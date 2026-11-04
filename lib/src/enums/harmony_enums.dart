/// Harmony 用户活动场景。
///
/// **映射来源**：Harmony `UserActivityScenario`：
/// - `NAVIGATION`=0x401
/// - `SPORT`=0x402
/// - `TRANSPORT`=0x403
/// - `DAILY_LIFE_SERVICE`=0x404
///
/// ⚠️ 与 Android 的 `AndroidLocationScene` **不是同一概念**（Android 那个是业务场景：
/// 签到/运动/出行；鸿蒙这个是**功耗 + 精度策略**）。
enum HarmonyUserActivityScenario {
  /// 导航场景。
  navigation,

  /// 运动场景。
  sport,

  /// 出行场景。
  transport,

  /// 日常生活服务。
  dailyLifeService,
}

extension HarmonyUserActivityScenarioCodec on HarmonyUserActivityScenario {
  String get wireName {
    switch (this) {
      case HarmonyUserActivityScenario.navigation:
        return 'navigation';
      case HarmonyUserActivityScenario.sport:
        return 'sport';
      case HarmonyUserActivityScenario.transport:
        return 'transport';
      case HarmonyUserActivityScenario.dailyLifeService:
        return 'dailyLifeService';
    }
  }

  static HarmonyUserActivityScenario? fromWire(String? wire) {
    for (final value in HarmonyUserActivityScenario.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

/// Harmony 功耗场景。
///
/// **映射来源**：Harmony `PowerConsumptionScenario`：
/// - `HIGH`=0x601
/// - `LOW`=0x602
/// - `NO`=0x603
enum HarmonyPowerConsumptionScenario {
  /// 高功耗。**默认值**。
  high,

  /// 低功耗。
  low,

  /// 无功耗限制。
  no,
}

extension HarmonyPowerConsumptionScenarioCodec
    on HarmonyPowerConsumptionScenario {
  String get wireName {
    switch (this) {
      case HarmonyPowerConsumptionScenario.high:
        return 'high';
      case HarmonyPowerConsumptionScenario.low:
        return 'low';
      case HarmonyPowerConsumptionScenario.no:
        return 'no';
    }
  }

  static HarmonyPowerConsumptionScenario? fromWire(String? wire) {
    for (final value in HarmonyPowerConsumptionScenario.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

/// Harmony 定位优先级。
///
/// **映射来源**：Harmony `LocatingPriority`：
/// - `PRIORITY_ACCURACY`=0x501
/// - `PRIORITY_LOCATING_SPEED`=0x502
enum HarmonyLocatingPriority {
  /// 精度优先。
  accuracy,

  /// 定位速度优先。**默认值**。
  locatingSpeed,
}

extension HarmonyLocatingPriorityCodec on HarmonyLocatingPriority {
  String get wireName {
    switch (this) {
      case HarmonyLocatingPriority.accuracy:
        return 'accuracy';
      case HarmonyLocatingPriority.locatingSpeed:
        return 'locatingSpeed';
    }
  }

  static HarmonyLocatingPriority? fromWire(String? wire) {
    for (final value in HarmonyLocatingPriority.values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}
