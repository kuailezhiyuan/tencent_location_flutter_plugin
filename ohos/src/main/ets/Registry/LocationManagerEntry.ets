import HashMap from '@ohos.util.HashMap'
import {
  TencentLocation,
  TencentLocationConstant,
  TencentLocationError,
  TencentLocationManager,
  TencentLocationRequest,
} from '@tencentmap/location_sdk'
import { EnumCodec } from '../Codec/EnumCodec'
import { LocationCodec } from '../Codec/LocationCodec'
import { EventDispatcher } from '../Event/EventDispatcher'

/**
 * 每个 Flutter `TencentLocationManager` 实例对应一个 [LocationManagerEntry]，
 * 与 iOS 端 `LocationManagerEntry` 同构。
 *
 * 持有：
 * - `managerId`：Dart 侧生成的字符串 id，事件流按此 id 路由回订阅方
 * - `native`：鸿蒙原生 `TencentLocationManager`（每 Flutter manager 独立一份实例，
 *   由 [TencentLocationManager.createInstance] 创建）
 * - `dispatcher`：事件分发器；连续定位 / 状态 / 朝向回调直接经 dispatcher 走 EventChannel
 * - `continuousCoordinateWire`：本轮连续定位的坐标系 wireName，用于 encode 每帧 location payload
 *
 * 职责范围：
 * - 封装所有作用在原生 manager 上的连续 / 单次 / 状态 / 朝向 / 后台任务 API
 * - 连续定位、设备状态、朝向回调**在 entry 内部** encode 后经 dispatcher 分派
 * - 单次定位回调把 raw native 对象直接透传给调用方（handler 层处理 result 语义）
 *
 * Entry 本身对 handler 暴露的只有业务动词（`startContinuous / startSingle / dispose` 等），
 * handler 不再直接触碰 `native.xxx`。
 */
export class LocationManagerEntry {
  readonly managerId: string
  readonly native: TencentLocationManager
  private readonly dispatcher: EventDispatcher

  private continuous: boolean = false
  private statusReceiving: boolean = false
  private orientationReceiving: boolean = false

  /** 连续定位当前使用的坐标系 wireName，由每次 [startContinuous] 传入并覆盖。 */
  private continuousCoordinateWire: string = 'gcj02'

  constructor(managerId: string, native: TencentLocationManager, dispatcher: EventDispatcher) {
    this.managerId = managerId
    this.native = native
    this.dispatcher = dispatcher
  }

  // ---------- 状态查询 ----------

  isContinuous(): boolean {
    return this.continuous
  }

  isStatusReceiving(): boolean {
    return this.statusReceiving
  }

  isOrientationReceiving(): boolean {
    return this.orientationReceiving
  }

  // ---------- 连续定位 ----------

  /**
   * 启动连续定位。`coordinateTypeWire` 用于每帧回调时 encode payload；
   * 若 native 抛异常，异常向上冒泡，`continuous` 标记不会被置 true。
   */
  startContinuous(request: TencentLocationRequest, coordinateTypeWire: string): void {
    const managerId = this.managerId
    const dispatcher = this.dispatcher
    this.continuousCoordinateWire = coordinateTypeWire

    const onLocation = (location: TencentLocation): void => {
      const payload: ESObject = LocationCodec.toMap(location, this.continuousCoordinateWire)
      dispatcher.sendLocation('onLocationChanged', managerId, payload)
    }
    const onError = (error: TencentLocationError): void => {
      dispatcher.sendLocation(
        'onLocationError',
      managerId,
        LocationManagerEntry.encodeError(error)
      )
    }

    this.native.startContinuousLocation(request, onLocation, onError)
    this.continuous = true
  }

  /** 停止连续定位；`continuous == false` 时为 no-op。 */
  stopContinuous(): void {
    if (!this.continuous) return
    try {
      this.native.stopContinuousLocation()
    } catch (_error) {
      // 幂等：忽略重复停止
    }
    this.continuous = false
  }

  // ---------- 单次定位 ----------

  /**
   * 启动单次定位。`onSuccess / onFailure` 收到的是原生 raw 对象；handler 层
   * 自己 encode + `result.success/failure`。原因：单次定位的坐标系是一次性的、
   * 不能覆盖连续定位的 `continuousCoordinateWire`。
   */
  startSingle(
    request: TencentLocationRequest,
    onSuccess: (location: TencentLocation) => void,
    onFailure: (error: TencentLocationError) => void
  ): void {
    this.native.startSingleLocation(request, onSuccess, onFailure)
  }

  // ---------- 最近位置 ----------

  /** 直接返回原生 SDK 的最近一次缓存位置；handler 层负责 encode。 */
  getLastLocation(): TencentLocation | undefined {
    return this.native.getLastLocation()
  }

  // ---------- 设备状态 ----------

  /** 开启设备状态订阅（幂等）。原生调用失败时异常向 handler 传播。 */
  startStatusReceiving(): void {
    if (this.statusReceiving) return
    const managerId = this.managerId
    const dispatcher = this.dispatcher
    this.native.startReceivingDeviceStatus((status: TencentLocationConstant.DeviceStatus) => {
      const parts = EnumCodec.deviceStatusToPayload(status)
      const payload: HashMap<string, ESObject> = new HashMap<string, ESObject>()
      payload.set('kind', parts[0])
      payload.set('status', parts[1])
      payload.set('description', parts[2])
      dispatcher.sendStatus('onStatusChanged', managerId, payload)
    })
    this.statusReceiving = true
  }

  stopStatusReceiving(): void {
    if (!this.statusReceiving) return
    this.native.stopReceivingDeviceStatus()
    this.statusReceiving = false
  }

  // ---------- 设备朝向 ----------

  /** 开启朝向订阅（幂等）。回调 payload 中 iOS 专属字段恒 null。 */
  startOrientationReceiving(): void {
    if (this.orientationReceiving) return
    const managerId = this.managerId
    const dispatcher = this.dispatcher
    this.native.startReceivingDeviceOrientation((heading: number) => {
      const payload: HashMap<string, ESObject> = new HashMap<string, ESObject>()
      payload.set('trueHeading', heading)
      // magneticHeading / accuracy / x / y / z 是 iOS 专属，鸿蒙侧恒 null。
      payload.set('magneticHeading', null)
      payload.set('accuracy', null)
      payload.set('x', null)
      payload.set('y', null)
      payload.set('z', null)
      payload.set('timestamp', Date.now())
      dispatcher.sendStatus('onOrientationChanged', managerId, payload)
    })
    this.orientationReceiving = true
  }

  stopOrientationReceiving(): void {
    if (!this.orientationReceiving) return
    this.native.stopReceivingDeviceOrientation()
    this.orientationReceiving = false
  }

  // ---------- 后台定位（鸿蒙独有） ----------

  /**
   * 启动后台定位任务（走 SDK 默认 WantAgent，点通知回自己 ability）。
   * 若 native 抛异常，异常向上冒泡，由 handler 层转成 method result。
   */
  startBackgroundTask(): void {
    this.native.startBackgroundLocationTask()
  }

  stopBackgroundTask(): void {
    this.native.stopBackgroundLocationTask()
  }

  // ---------- dispose ----------

  /**
   * 释放本 entry 关联的所有原生订阅：状态 / 朝向 / 连续定位。
   * 幂等：内部逐项判断 `xxxReceiving / continuous` 标记后调用对应 stop。
   */
  dispose(): void {
    let firstCleanupError: Error | null = null
    try {
      this.stopStatusReceiving()
    } catch (error) {
      firstCleanupError = error as Error
    }
    try {
      this.stopOrientationReceiving()
    } catch (error) {
      if (firstCleanupError === null) firstCleanupError = error as Error
    }
    this.stopContinuous()
    if (firstCleanupError !== null) throw firstCleanupError
  }

  // ---------- helper ----------

  private static encodeError(error: TencentLocationError): ESObject {
    const map: HashMap<string, ESObject> = new HashMap<string, ESObject>()
    map.set('code', EnumCodec.errorCodeToWire(error.code))
    map.set('message', error.message ?? '')
    map.set('nativeMessage', error.message ?? null)
map.set('details', error.code)
    return map
  }
}
