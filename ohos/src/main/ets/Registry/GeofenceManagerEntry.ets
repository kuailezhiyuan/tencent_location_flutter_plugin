import HashMap from '@ohos.util.HashMap'
import {
  TencentGeofence,
  TencentGeofenceRequest,
  TencentLocationConstant,
  TencentLocationManager,
} from '@tencentmap/location_sdk'
import { EnumCodec } from '../Codec/EnumCodec'
import { GeofenceCodec } from '../Codec/GeofenceCodec'
import { EventDispatcher } from '../Event/EventDispatcher'
import { Errors } from '../Util/Errors'

/**
 * 每个 Flutter `TencentGeofenceManager` 实例对应一个 [GeofenceManagerEntry]，
 * 与 iOS 端 `GeofenceManagerEntry` 同构。
 *
 * 持有：
 * - `geofenceManagerId`：Dart 侧字符串 id，围栏事件按此 id 路由
 * - `native`：鸿蒙原生 `TencentLocationManager`（围栏 API 挂在此类上）
 * - `dispatcher`：事件分发器；围栏事件 / 错误在 entry 内部 encode 后经 dispatcher 分派
 * - `dartIdToNative` / `nativeIdToDart`：Dart 字符串 id ↔ 鸿蒙原生 number id 双向映射
 * - `pendingFenceMetas`：以 Dart id 索引每个围栏在 add 时的元数据快照，用于 [getAllAsMaps]
 *   还原完整 map（鸿蒙原生只保存了 number id 数组，没有暴露 fence 详情 getter）
 *
 * Entry 对 handler 暴露业务动词（`addCircleGeofence / removeGeofence / removeAll / getAllAsMaps / dispose`），
 * handler 不再直接触碰 `native.addGeofence`。
 */
export class GeofenceManagerEntry {
  readonly geofenceManagerId: string
  readonly native: TencentLocationManager
  private readonly dispatcher: EventDispatcher

  private readonly dartIdToNative: Map<string, number> = new Map()
  private readonly nativeIdToDart: Map<number, string> = new Map()
  private readonly pendingFenceMetas: Map<string, GeofenceMeta> = new Map()

  constructor(
    geofenceManagerId: string,
    native: TencentLocationManager,
    dispatcher: EventDispatcher
  ) {
    this.geofenceManagerId = geofenceManagerId
    this.native = native
    this.dispatcher = dispatcher
  }

  // ---------- id / meta 映射查询 ----------

  nativeIdOf(dartId: string): number | null {
    const value = this.dartIdToNative.get(dartId)
    return value === undefined ? null : value
  }

  allDartIds(): Array<string> {
    return Array.from(this.dartIdToNative.keys())
  }

  // ---------- add ----------

  /**
   * 添加一个圆形围栏。事件回调（enter / exit / dwell）由 entry 内部构造并经
   * dispatcher 转发；成功时自动完成 dartId ↔ nativeId 双向绑定与 meta 缓存。
   *
   * @returns Promise，成功 resolve 无值；失败 reject 时携带原生 error 对象，
   * 由 handler 层通过 [GeofenceCodec.asNumberPublic] / [asStringPublic] 提取 code / message。
   */
  addCircleGeofence(
    fence: TencentGeofence,
    monitorEvents: Array<TencentLocationConstant.GeofenceEvent>,
    dartId: string,
    meta: GeofenceMeta
  ): Promise<void> {
    const geofenceManagerId = this.geofenceManagerId
    const dispatcher = this.dispatcher
    const entryRef: GeofenceManagerEntry = this

    const eventsCallback = (error: ESObject, event: ESObject): void => {
      if (error !== undefined && error !== null) {
        // 错误回调：转换为 onGeofenceError 事件
        const errCode: number | null = GeofenceCodec.asNumberPublic(GeofenceCodec.getPublic(error, 'code'))
        const errMsg: string | null = GeofenceCodec.asStringPublic(GeofenceCodec.getPublic(error, 'message'))
        const payload: HashMap<string, ESObject> = new HashMap<string, ESObject>()
        payload.set('code', errCode !== null ? EnumCodec.errorCodeToWire(errCode) : Errors.NATIVE_ERROR)
        payload.set('message', errMsg ?? 'geofence error')
        payload.set('nativeMessage', errMsg ?? null)
        payload.set('details', errCode !== null ? errCode : null)
        dispatcher.sendGeofence('onGeofenceError', geofenceManagerId, payload)
        return
      }
      if (event === undefined || event === null) return
      const nativeId: number | null = GeofenceCodec.asNumberPublic(GeofenceCodec.getPublic(event, 'id'))
      const evtValue: ESObject = GeofenceCodec.getPublic(event, 'event')
      if (nativeId === null || evtValue === null) return
      const evtEnum: TencentLocationConstant.GeofenceEvent =
        evtValue as TencentLocationConstant.GeofenceEvent
      const dartFenceId = entryRef.dartIdOfInternal(nativeId) ?? String(nativeId)
      const transitionWire = EnumCodec.geofenceEventToWire(evtEnum)
      const payload: HashMap<string, ESObject> = new HashMap<string, ESObject>()
      payload.set('geofenceId', dartFenceId)
      payload.set('transition', transitionWire)
      payload.set('location', null)
      payload.set('stayedDurationMs', null)
      payload.set('userInfo', null)
      dispatcher.sendGeofence('onGeofenceEvent', geofenceManagerId, payload)
    }

    const request = new TencentGeofenceRequest(fence, monitorEvents, eventsCallback)

    return this.native.addGeofence(request).then((nativeId: number) => {
      this.bindId(dartId, nativeId, meta)
    })
  }

  // ---------- remove ----------

  /**
   * 移除指定 Dart id 对应的围栏。若 id 未绑定，`nativeIdOf` 返回 null，
   * 调用方应在此之前自行报 `geofenceIdNotFound`。
   */
  removeByDartId(dartId: string): Promise<void> {
    const nativeId = this.dartIdToNative.get(dartId)
    if (nativeId === undefined) {
      return Promise.reject(new Error(`geofence id not found: ${dartId}`))
    }
    return this.native.removeGeofence(nativeId).then(() => {
      this.unbindByDartId(dartId)
    })
  }

  /**
   * 清空所有围栏。即使 native reject，本地映射也会被清空，避免脏数据；
   * 但 Promise 仍会以 native 错误 reject 出去。
   */
  removeAll(): Promise<void> {
    return this.native.removeGeofence().then(() => {
      this.clearMappings()
    }).catch((error: ESObject) => {
      // 即使 native 报错，本地映射也清空避免脏数据
      this.clearMappings()
      throw error as Error
    })
  }

  // ---------- getAll（本地反查） ----------

  /**
   * 反查当前所有已注册围栏的完整 Dart wire map。数据来源是 [pendingFenceMetas]，
   * 鸿蒙原生未暴露 fence 列表 getter，无法从 native 拿完整对象。
   */
  getAllAsMaps(): Array<ESObject> {
    const list: Array<ESObject> = []
    for (const dartId of Array.from(this.dartIdToNative.keys())) {
      const meta = this.pendingFenceMetas.get(dartId)
      if (meta === undefined) continue
      const center: HashMap<string, ESObject> = new HashMap<string, ESObject>()
      center.set('latitude', meta.latitude)
      center.set('longitude', meta.longitude)

      const map: HashMap<string, ESObject> = new HashMap<string, ESObject>()
      map.set('id', dartId)
      map.set('type', 'circle')
      map.set('coordinateType', meta.coordinateTypeWire)
      // 直接回传 Dart 侧传入的原始毫秒值（null 表示永不过期），避免经由
      // native 的秒级 expiration 反算导致语义漂移（null → 巨大数值）与精度损失。
      map.set('expirationMs', meta.expirationMs)
      map.set('monitorTransitions', meta.monitorTransitionWires)
      map.set('dwellDurationMs', null)
      map.set('userInfo', null)
      map.set('center', center)
      map.set('radius', meta.radius)
      map.set('polygon', null)
      map.set('districtKeyword', null)
      list.push(map)
    }
    return list
  }

  // ---------- 已注册 Dart id 存在性检查（handler 侧防重复用） ----------

  isRegistered(dartId: string): boolean {
    return this.dartIdToNative.has(dartId)
  }

  // ---------- dispose ----------

  /**
   * 释放本 entry：尝试清理原生所有围栏（catch 静默，避免影响其他 entry），
   * 并清空本地 dartId ↔ nativeId 映射与 meta 缓存。
   */
  dispose(): void {
    try {
      this.native.removeGeofence().catch((_error: Error) => {
        // 忽略：可能围栏已被系统清理
      })
    } catch (_error) {
      // 幂等：忽略
    }
    this.clearMappings()
  }

  // ---------- internal ----------

  private bindId(dartId: string, nativeId: number, meta: GeofenceMeta): void {
    this.dartIdToNative.set(dartId, nativeId)
    this.nativeIdToDart.set(nativeId, dartId)
    this.pendingFenceMetas.set(dartId, meta)
  }

  private unbindByDartId(dartId: string): void {
    const nativeId = this.dartIdToNative.get(dartId)
    this.dartIdToNative.delete(dartId)
    this.pendingFenceMetas.delete(dartId)
    if (nativeId !== undefined) this.nativeIdToDart.delete(nativeId)
  }

  private dartIdOfInternal(nativeId: number): string | null {
    const value = this.nativeIdToDart.get(nativeId)
    return value === undefined ? null : value
  }

  private clearMappings(): void {
    this.dartIdToNative.clear()
    this.nativeIdToDart.clear()
    this.pendingFenceMetas.clear()
  }
}

/**
 * 围栏的元数据缓存。[GeofenceManagerEntry.getAllAsMaps] 时用这个还原出 Dart 侧 map schema。
 *
 * `expirationMs` 保存 Dart 请求的归一化有效期（`null` = 永不过期），而不是从
 * native 秒级值反算。正毫秒值按请求回显，native 实际执行时可能按秒向上取整。
 */
export interface GeofenceMeta {
  latitude: number
  longitude: number
  radius: number
  expirationMs: number | null
  coordinateTypeWire: string
  monitorTransitionWires: Array<string>
}
