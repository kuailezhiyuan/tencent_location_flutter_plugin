import { TencentLocationRequest, TencentLocationConstant } from '@tencentmap/location_sdk'

import { EnumCodec } from './EnumCodec'

/**
 * Flutter 侧 `TencentLocationRequest.toMap()` → 鸿蒙原生 [TencentLocationRequest]。
 *
 * 输入 map schema（P2 需要消费的字段）：
 * ```
 * {
 *   common: {
 *     intervalMs: number,               // 毫秒 → 秒（向上取整，>=1）
 *     coordinateType: 'wgs84' | 'gcj02',
 *     requestLevel: 'geo' | 'name' | 'adminArea' | 'poi',
 *     allowDirectionSensor: boolean,
 *   },
 *   harmony: {
 *     userActivityScenario?: string,
 *     powerConsumptionScenario?: string,
 *     locatingPriority: string,
 *     innerIntervalS: number,
 *     reverseGeocodeRequestIntervalS: number,
 *     firstLocationCachePolicyS: number,
 *     singleLocationTimeoutS: number,
 *   },
 *   // android / ios 段在鸿蒙端忽略
 * }
 * ```
 *
 * 备注：
 * - 鸿蒙 [TencentLocationRequest] 构造函数 private，只能用 `default()` + setter 链
 * - 鸿蒙 request **不携带 coordinateType**，坐标系需要在 manager 层单独 apply
 * - 通用 `intervalMs`（毫秒）与鸿蒙 `setInterval(秒)` 单位不同，需要换算
 */
export class RequestCodec {
  private constructor() {}

  /** 从 map 构造鸿蒙 request（不含坐标系 / 请求级别 —— 由 handler 自己 apply 到 manager）。 */
  static fromMap(map: ESObject): TencentLocationRequest {
    const request: TencentLocationRequest = TencentLocationRequest.default()

    const common: ESObject = RequestCodec.getAsMap(map, 'common')
    const harmony: ESObject = RequestCodec.getAsMap(map, 'harmony')

    // ---------- 通用 ----------
    if (common !== null) {
      const intervalMs = RequestCodec.asNumber(RequestCodec.get(common, 'intervalMs'))
      if (intervalMs !== null) {
        // 毫秒 → 秒，向上取整并保证下限 1s（鸿蒙 setInterval < 0 会被 clamp 到 1，
        // 我们再多兜一次防止 0/负值触发 setInterval(0) 的联动副作用）。
        const seconds = Math.max(1, Math.ceil(intervalMs / 1000))
        request.setInterval(seconds)
      }

      const allowDirectionSensor = RequestCodec.asBoolean(RequestCodec.get(common, 'allowDirectionSensor'))
      if (allowDirectionSensor !== null) {
        request.setEnableSensorForDirection(allowDirectionSensor)
      }

      const requestLevel = EnumCodec.requestLevelFromWire(
        RequestCodec.asString(RequestCodec.get(common, 'requestLevel'))
      )
      if (requestLevel !== null) {
        request.setRequestLevel(requestLevel)
      }
      // 坐标系不落到 request：鸿蒙 request 不接收 coordinateType，由 handler 直接
      // 从 map 里读出并 apply 到 native manager 实例。这里保留 map 值给 handler。
    }

    // ---------- 鸿蒙专属 ----------
    if (harmony !== null) {
      const priority = EnumCodec.locatingPriorityFromWire(
        RequestCodec.asString(RequestCodec.get(harmony, 'locatingPriority'))
      )
      if (priority !== null) {
        request.setLocatingPriority(priority)
      }

      // userActivityScenario 与 powerConsumptionScenario 互斥：
      // 先读 userActivityScenario，若无则读 powerConsumptionScenario。
      // 与鸿蒙 request 内部互斥 setter 语义保持一致。
      const userScenario = EnumCodec.userActivityScenarioFromWire(
        RequestCodec.asString(RequestCodec.get(harmony, 'userActivityScenario'))
      )
      if (userScenario !== null) {
        request.setUserActivityScenario(userScenario)
      } else {
        const powerScenario = EnumCodec.powerConsumptionScenarioFromWire(
          RequestCodec.asString(RequestCodec.get(harmony, 'powerConsumptionScenario'))
        )
        if (powerScenario !== null) {
          request.setPowerConsumptionScenario(powerScenario)
        }
      }

      const innerIntervalS = RequestCodec.asNumber(RequestCodec.get(harmony, 'innerIntervalS'))
      if (innerIntervalS !== null) {
        request.setInnerInterval(innerIntervalS)
      }

      const reverseIntervalS = RequestCodec.asNumber(RequestCodec.get(harmony, 'reverseGeocodeRequestIntervalS'))
      if (reverseIntervalS !== null) {
        request.setReverseGeocodeRequestInterval(reverseIntervalS)
      }

      const cachePolicyS = RequestCodec.asNumber(RequestCodec.get(harmony, 'firstLocationCachePolicyS'))
      if (cachePolicyS !== null) {
        request.setFirstLocationCachePolicy(cachePolicyS)
      }

      const singleTimeoutS = RequestCodec.asNumber(RequestCodec.get(harmony, 'singleLocationTimeoutS'))
      if (singleTimeoutS !== null) {
        request.setSingleLocationTimeout(singleTimeoutS)
      }
    }

    return request
  }

  /** 从 map.common.coordinateType 提取原生 CoordinateType，用于 handler 侧 apply。 */
  static coordinateTypeFromMap(map: ESObject): TencentLocationConstant.CoordinateType | null {
    const common: ESObject = RequestCodec.getAsMap(map, 'common')
    if (common === null) return null
    return EnumCodec.coordinateTypeFromWire(RequestCodec.asString(RequestCodec.get(common, 'coordinateType')))
  }

  /** 直接读 map.common.coordinateType 的 wire 字符串。 */
  static coordinateTypeWireFromMap(map: ESObject): string {
    const common: ESObject = RequestCodec.getAsMap(map, 'common')
    if (common === null) return 'gcj02'
    return RequestCodec.asString(RequestCodec.get(common, 'coordinateType')) ?? 'gcj02'
  }

  // ---------- helpers ----------

  /** 取子 map（接受 Map / HashMap / 普通对象）。找不到或非对象返回 null。 */
  private static getAsMap(container: ESObject, key: string): ESObject {
    const value: ESObject = RequestCodec.get(container, key)
    if (value === null || value === undefined) return null
    if (typeof value !== 'object') return null
    return value
  }

  /** 从 ESObject 里按键取值，找不到返回 null。 */
  private static get(container: ESObject, key: string): ESObject {
    if (container === null || container === undefined) return null
    if (container instanceof Map) {
      const value: ESObject = (container as Map<ESObject, ESObject>).get(key)
      return value === undefined ? null : value
    }
    try {
      const value: ESObject = (container as Record<string, ESObject>)[key]
      return value === undefined ? null : value
    } catch (_error) {
      return null
    }
  }

  private static asNumber(value: ESObject): number | null {
    if (typeof value === 'number' && Number.isFinite(value as number)) return value as number
    return null
  }

  private static asBoolean(value: ESObject): boolean | null {
    if (typeof value === 'boolean') return value as boolean
    return null
  }

  private static asString(value: ESObject): string | null {
    if (typeof value === 'string') return value as string
    return null
  }
}
