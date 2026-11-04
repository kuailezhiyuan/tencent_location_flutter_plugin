import {
  TencentGeofence,
  TencentLocationConstant,
} from '@tencentmap/location_sdk'

import { Errors } from '../Util/Errors'
import { EnumCodec } from './EnumCodec'

/**
 * 地理围栏 Map ↔ 鸿蒙原生对象。
 *
 * ⚠️ 鸿蒙原生**只支持圆形围栏**（`TencentGeofence` 只有 lat/lng/radius/expiration 字段），
 * `polygon` / `district` 类型在 handler 侧应直接抛 `unsupportedOnThisPlatform`。
 * 这里只处理 circle 类型。
 *
 * ⚠️ 鸿蒙 fence 的 id 由系统在 `addGeofence` 返回的 Promise 中给出（数值），Dart 侧
 * 用字符串 id，双向映射由 GeofenceManagerEntry 维护，不在 codec 层处理。
 *
 * 输入端（Dart 侧传入的 fence map）在 ArkTS 侧只能用 `ESObject`（`ESObject`）承接，
 * 运行时再用辅助方法做类型断言。
 */
export class GeofenceCodec {
  private constructor() {}

  /**
   * 从 Dart 侧 fence map 构造鸿蒙 [TencentGeofence]。
   * 若 map 描述的不是 circle 类型，返回 null。
   */
  static fenceFromMap(map: ESObject): TencentGeofence | null {
    const type: string = GeofenceCodec.asString(GeofenceCodec.get(map, 'type')) ?? 'circle'
    if (type !== 'circle') return null

    const center: ESObject = GeofenceCodec.get(map, 'center')
    if (center === null || center === undefined) return null

    const latitude: number = GeofenceCodec.asNumber(GeofenceCodec.get(center, 'latitude')) ?? 0
    const longitude: number = GeofenceCodec.asNumber(GeofenceCodec.get(center, 'longitude')) ?? 0
    const radius: number = GeofenceCodec.asNumber(GeofenceCodec.get(map, 'radius')) ?? 0

    // Dart 侧 expiration 用毫秒；鸿蒙 native 构造函数要秒。null / <=0 用较大兜底值
    // （鸿蒙 SDK 内部将 expiration_s * 1000 传给系统，负值会被拒绝）。
    const expirationMs: number | null = GeofenceCodec.asNumber(GeofenceCodec.get(map, 'expirationMs'))
    const expirationS: number = expirationMs !== null && expirationMs > 0
      ? Math.ceil(expirationMs / 1000)
      : 0x7fffffff  // 永不过期兜底（约 68 年）

    const coordType: TencentLocationConstant.CoordinateType =
      EnumCodec.coordinateTypeFromWire(GeofenceCodec.asString(GeofenceCodec.get(map, 'coordinateType')))
        ?? TencentLocationConstant.CoordinateType.GCJ02

    return new TencentGeofence(latitude, longitude, radius, expirationS, coordType)
  }

  /** 从 map 里读监听事件集合，转成鸿蒙原生数组。 */
  static monitorEventsFromMap(map: ESObject): Array<TencentLocationConstant.GeofenceEvent> {
    const rawTransitions: ESObject = GeofenceCodec.get(map, 'monitorTransitions')
    const events: Array<TencentLocationConstant.GeofenceEvent> = []
    if (Array.isArray(rawTransitions)) {
      const transitionList: Array<ESObject> = rawTransitions as Array<ESObject>
      transitionList.forEach((item: ESObject) => {
        const wire: string | null = GeofenceCodec.asString(item)
        const parsed = EnumCodec.geofenceEventFromWire(wire)
        if (parsed !== null) events.push(parsed)
      })
    }
    if (events.length === 0) {
      // 与 Dart 默认值对齐：{enter, exit}
      events.push(TencentLocationConstant.GeofenceEvent.ENTER)
      events.push(TencentLocationConstant.GeofenceEvent.EXIT)
    }
    return events
  }

  /** 若 map 描述的不是 circle 类型，返回 Dart wire 错误码；否则返回 null。 */
  static validateCircleOrError(map: ESObject): string | null {
    const type: string = GeofenceCodec.asString(GeofenceCodec.get(map, 'type')) ?? 'circle'
    if (type !== 'circle') return Errors.GEOFENCE_INVALID_REGION
    return null
  }

  // ---------- helpers ----------

  /**
   * 从 ESObject（多半是 HashMap 或 object）里按键取值，找不到返回 null。
   * 对外公开，handler 也需要用同样的逻辑解 `event / err` payload。
   */
  static getPublic(container: ESObject, key: string): ESObject {
    return GeofenceCodec.get(container, key)
  }

  /** 对外公开的 asNumber，handler 解 native 回调用。 */
  static asNumberPublic(value: ESObject): number | null {
    return GeofenceCodec.asNumber(value)
  }

  /** 对外公开的 asString，handler 解 native 回调用。 */
  static asStringPublic(value: ESObject): string | null {
    return GeofenceCodec.asString(value)
  }

  /** 从 ESObject（多半是 HashMap 或 object）里按键取值，找不到返回 null。 */
  private static get(container: ESObject, key: string): ESObject {
    if (container === null || container === undefined) return null
    // StandardMessageCodec 解码出的 map 在 flutter_ohos 内部通常是 Map 实例
    if (container instanceof Map) {
      const value: ESObject = (container as Map<ESObject, ESObject>).get(key)
      return value === undefined ? null : value
    }
    try {
      // 兜底：当成普通 JS 对象访问
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

  private static asString(value: ESObject): string | null {
    if (typeof value === 'string') return value as string
    return null
  }
}
