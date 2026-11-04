import { TencentLocationConstant } from '@tencentmap/location_sdk'
import { TencentLocationErrorCode } from '@tencentmap/location_sdk'
import { Errors } from '../Util/Errors'

/**
 * Dart wire name（字符串）与鸿蒙原生枚举（number）之间的双向映射。
 *
 * 每个 codec 只做映射，不带兜底策略：调用方拿到 null 时自行决定使用默认值还是
 * 报错，避免把"未知 wire 值"静默吞成 default。
 */
export class EnumCodec {
  // ---------- CoordinateType ----------

  static coordinateTypeFromWire(
    wire: string | null | undefined
  ): TencentLocationConstant.CoordinateType | null {
    switch (wire) {
      case 'wgs84':
        return TencentLocationConstant.CoordinateType.WGS84
      case 'gcj02':
        return TencentLocationConstant.CoordinateType.GCJ02
      default:
        return null
    }
  }

  static coordinateTypeToWire(
    value: TencentLocationConstant.CoordinateType
  ): string {
    switch (value) {
      case TencentLocationConstant.CoordinateType.WGS84:
        return 'wgs84'
      case TencentLocationConstant.CoordinateType.GCJ02:
      default:
        return 'gcj02'
    }
  }

  // ---------- RequestLevel ----------

  static requestLevelFromWire(
    wire: string | null | undefined
  ): TencentLocationConstant.RequestLevel | null {
    switch (wire) {
      case 'geo':
        return TencentLocationConstant.RequestLevel.GEO
      case 'name':
        return TencentLocationConstant.RequestLevel.NAME
      case 'adminArea':
        return TencentLocationConstant.RequestLevel.ADMIN_AREA
      case 'poi':
        return TencentLocationConstant.RequestLevel.POI
      default:
        return null
    }
  }

  // ---------- HarmonyUserActivityScenario ----------

  static userActivityScenarioFromWire(
    wire: string | null | undefined
  ): TencentLocationConstant.UserActivityScenario | null {
    switch (wire) {
      case 'navigation':
        return TencentLocationConstant.UserActivityScenario.NAVIGATION
      case 'sport':
        return TencentLocationConstant.UserActivityScenario.SPORT
      case 'transport':
        return TencentLocationConstant.UserActivityScenario.TRANSPORT
      case 'dailyLifeService':
        return TencentLocationConstant.UserActivityScenario.DAILY_LIFE_SERVICE
      default:
        return null
    }
  }

  // ---------- HarmonyPowerConsumptionScenario ----------

  static powerConsumptionScenarioFromWire(
    wire: string | null | undefined
  ): TencentLocationConstant.PowerConsumptionScenario | null {
    switch (wire) {
      case 'high':
        return TencentLocationConstant.PowerConsumptionScenario.HIGH_POWER_CONSUMPTION
      case 'low':
        return TencentLocationConstant.PowerConsumptionScenario.LOW_POWER_CONSUMPTION
      case 'no':
        return TencentLocationConstant.PowerConsumptionScenario.NO_POWER_CONSUMPTION
      default:
        return null
    }
  }

  // ---------- HarmonyLocatingPriority ----------

  static locatingPriorityFromWire(
    wire: string | null | undefined
  ): TencentLocationConstant.LocatingPriority | null {
    switch (wire) {
      case 'accuracy':
        return TencentLocationConstant.LocatingPriority.PRIORITY_ACCURACY
      case 'locatingSpeed':
        return TencentLocationConstant.LocatingPriority.PRIORITY_LOCATING_SPEED
      default:
        return null
    }
  }

  // ---------- LocationSource（native → wire）----------
  //
  // 鸿蒙 LocationSource 数值 → Dart LocationSource wire name。
  // Dart 侧按平台前缀分组（harmonyGnss / harmonyNetwork / harmonyIndoor /
  // harmonyRtk），未知值 fallback 到 `unknown`。

  static locationSourceToWire(
    value: TencentLocationConstant.LocationSource | undefined
  ): string {
    if (value === undefined) return 'unknown'
    switch (value) {
      case TencentLocationConstant.LocationSource.GNSS:
        return 'harmonyGnss'
      case TencentLocationConstant.LocationSource.NETWORK:
        return 'harmonyNetwork'
      case TencentLocationConstant.LocationSource.INDOOR:
        return 'harmonyIndoor'
      case TencentLocationConstant.LocationSource.RTK:
        return 'harmonyRtk'
      default:
        return 'unknown'
    }
  }

  // ---------- DeviceStatus（native → wire） ----------
  //
  // 鸿蒙原生 DeviceStatus 是单一枚举（7 值），Dart 侧拆成 `(kind, status)`
  // 两个字段，需要一次性映射。以下返回 `[kindWire, statusWire, description]`
  // 三元组，供 handler 直接构造事件 payload。

  /**
   * 把鸿蒙 DeviceStatus 单值枚举拆成 Dart 侧的 `(kind, status, description)` 三元组。
   *
   * Dart 侧 `TencentDeviceStatus` 拆成：
   * - `kind`：设备 / 能力类型（gps / wifi / cellular / vpn / locationSwitch）
   * - `status`：当前状态（available / disabled / denied / ...）
   * - `description`：文案描述
   */
  static deviceStatusToPayload(
    value: TencentLocationConstant.DeviceStatus
  ): [string, string, string] {
    switch (value) {
      case TencentLocationConstant.DeviceStatus.NET_AVAILABLE_CELLULAR:
        return ['cellular', 'available', 'Cellular network available']
      case TencentLocationConstant.DeviceStatus.NET_AVAILABLE_WIFI:
        return ['wifi', 'available', 'Wi-Fi network available']
      case TencentLocationConstant.DeviceStatus.NET_AVAILABLE_VPN:
        return ['vpn', 'available', 'VPN network available']
      case TencentLocationConstant.DeviceStatus.NET_UNAVAILABLE_NEED_AUTHORIZATION:
        // "网络不可用，需要登录认证" → 权限 / 授权被拒
        return ['cellular', 'denied', 'Network unavailable: authentication required']
      case TencentLocationConstant.DeviceStatus.NET_UNAVAILABLE_OTHER:
        // "网络不可用，其他原因" → 归入 disabled
        return ['cellular', 'disabled', 'Network unavailable: other reason']
      case TencentLocationConstant.DeviceStatus.LOCATION_SWITCH_ON:
        return ['locationSwitch', 'available', 'Location switch on']
      case TencentLocationConstant.DeviceStatus.LOCATION_SWITCH_OFF:
        return ['locationSwitch', 'disabled', 'Location switch off']
      default:
        return ['gps', 'unknown', `unknown status: ${value}`]
    }
  }

  // ---------- GeofenceEvent（native → wire） ----------

  static geofenceEventToWire(value: TencentLocationConstant.GeofenceEvent): string {
    switch (value) {
      case TencentLocationConstant.GeofenceEvent.ENTER:
        return 'enter'
      case TencentLocationConstant.GeofenceEvent.EXIT:
        return 'exit'
      case TencentLocationConstant.GeofenceEvent.DWELL:
        return 'dwell'
      default:
        return 'unknown'
    }
  }

  static geofenceEventFromWire(
    wire: string | null | undefined
  ): TencentLocationConstant.GeofenceEvent | null {
    switch (wire) {
      case 'enter':
        return TencentLocationConstant.GeofenceEvent.ENTER
      case 'exit':
        return TencentLocationConstant.GeofenceEvent.EXIT
      case 'dwell':
        return TencentLocationConstant.GeofenceEvent.DWELL
      default:
        return null
    }
  }

  // ---------- TencentLocationErrorCode（native number → wire name） ----------
  //
  // 鸿蒙原生错误码是数值（201 / 3301100 / 990100 等）。这里映射到 [Errors] 里
  // 定义的 wire name 常量（单一真相源，避免与 Dart / Java / Swift 三端漂移），
  // 未知值 fallback 到 `nativeError`（与 Dart TencentLocationErrorCodeCodec 一致）。

  static errorCodeToWire(code: number): string {
    switch (code) {
      case TencentLocationErrorCode.PermissionDenied:
        return Errors.PERMISSION_DENIED
      case TencentLocationErrorCode.ParameterError:
        return Errors.INVALID_ARGUMENT
      case TencentLocationErrorCode.CapabilityNotSupported:
        return Errors.UNSUPPORTED_ON_PLATFORM
      case TencentLocationErrorCode.LocationServiceUnavailable:
        return Errors.SDK_INIT_FAILED
      case TencentLocationErrorCode.LocationSwitchOff:
        return Errors.LOCATION_SWITCH_OFF
      case TencentLocationErrorCode.ObtainGeographicalLocationFailed:
        return Errors.LOCATION_FAILED
      case TencentLocationErrorCode.ReverseGeocodingQueryFailed:
      case TencentLocationErrorCode.GeocodingQueryFailed:
      case TencentLocationErrorCode.QueryAreaInfoFailed:
        return Errors.NATIVE_ERROR
      case TencentLocationErrorCode.GeofenceOperationFailed:
        return Errors.NATIVE_ERROR
      case TencentLocationErrorCode.GeofenceCountExceedsLimit:
        return Errors.GEOFENCE_LIMIT_EXCEEDED
      case TencentLocationErrorCode.GeofenceIncorrectId:
        return Errors.GEOFENCE_ID_NOT_FOUND
      case TencentLocationErrorCode.NoResponseToRequest:
        return Errors.TIMEOUT
      case TencentLocationErrorCode.WifiBluetoothScanFailed:
        return Errors.NATIVE_ERROR
      case TencentLocationErrorCode.GeofenceCoordinateTypeNotSupported:
        return Errors.GEOFENCE_INVALID_REGION
      case TencentLocationErrorCode.PrivacyPolicyNotAgreed:
        return Errors.PRIVACY_NOT_AGREED
      case TencentLocationErrorCode.ContinuousLocationAlreadyStarted:
        return Errors.ALREADY_STARTED
      default:
        return Errors.NATIVE_ERROR
    }
  }
}
