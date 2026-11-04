import { EventChannel, StreamHandler, EventSink, BinaryMessenger } from '@ohos/flutter_ohos'

/**
 * 事件 envelope。三端 wire 一致：
 *
 * - location channel：`{event, managerId, payload}`
 * - geofence channel：`{event, geofenceManagerId, payload}`
 * - status channel：`{event, managerId, payload}`
 *
 * ArkTS 严格模式禁止 untyped object literal，必须显式声明 interface 才能构造。
 */
export interface EventEnvelope {
  event: string
  managerId: string
  geofenceManagerId: string
  payload: ESObject
}

/**
 * 内部 StreamHandler：仅缓存当前 sink，上层通过 [EventDispatcher.sendXxx] 分派事件。
 */
class DispatchStreamHandler implements StreamHandler {
  sink: EventSink | null = null

  onListen(_args: ESObject, events: EventSink): void {
    this.sink = events
  }

  onCancel(_args: ESObject): void {
    this.sink = null
  }
}

/**
 * 统一管理 3 条 EventChannel，与 Android / iOS 侧同构：
 *
 * - `com.tencent.map.geolocation.flutter/event/location`  → 定位事件流
 * - `com.tencent.map.geolocation.flutter/event/geofence`  → 围栏事件流
 * - `com.tencent.map.geolocation.flutter/event/status`    → 状态 / 朝向 / SDK 日志
 *
 * 事件 payload 中带 `managerId` / `geofenceManagerId`，Dart 侧按 id 过滤路由。
 * Dart 未订阅期间产生的事件直接丢弃（与 broadcast stream 语义一致）。
 */
export class EventDispatcher {
  static readonly LOCATION_CHANNEL_NAME: string =
    'com.tencent.map.geolocation.flutter/event/location'
  static readonly GEOFENCE_CHANNEL_NAME: string =
    'com.tencent.map.geolocation.flutter/event/geofence'
  static readonly STATUS_CHANNEL_NAME: string =
    'com.tencent.map.geolocation.flutter/event/status'

  private readonly locationChannel: EventChannel
  private readonly geofenceChannel: EventChannel
  private readonly statusChannel: EventChannel

  private readonly locationHandler: DispatchStreamHandler = new DispatchStreamHandler()
  private readonly geofenceHandler: DispatchStreamHandler = new DispatchStreamHandler()
  private readonly statusHandler: DispatchStreamHandler = new DispatchStreamHandler()

  constructor(messenger: BinaryMessenger) {
    this.locationChannel = new EventChannel(
      messenger,
      EventDispatcher.LOCATION_CHANNEL_NAME
    )
    this.geofenceChannel = new EventChannel(
      messenger,
      EventDispatcher.GEOFENCE_CHANNEL_NAME
    )
    this.statusChannel = new EventChannel(
      messenger,
      EventDispatcher.STATUS_CHANNEL_NAME
    )

    this.locationChannel.setStreamHandler(this.locationHandler)
    this.geofenceChannel.setStreamHandler(this.geofenceHandler)
    this.statusChannel.setStreamHandler(this.statusHandler)
  }

  /** onDetachedFromEngine 时调用，清理 handler。 */
  dispose(): void {
    // flutter_ohos 的 EventChannel.setStreamHandler 类型签名不允许传 null，
    // 但 onDetachedFromEngine 时 plugin 即将销毁，channel 引用也会随之失效，
    // 这里只清空本地 sink 引用避免 leak 即可。
    this.locationHandler.sink = null
    this.geofenceHandler.sink = null
    this.statusHandler.sink = null
  }

  // ---------- send ----------

  sendLocation(event: string, managerId: string, payload: ESObject): void {
    const sink = this.locationHandler.sink
    if (sink === null) return
    const envelope: EventEnvelope = {
      event: event,
      managerId: managerId,
      geofenceManagerId: '',
      payload: payload,
    }
    sink.success(envelope)
  }

  sendGeofence(event: string, geofenceManagerId: string, payload: ESObject): void {
    const sink = this.geofenceHandler.sink
    if (sink === null) return
    const envelope: EventEnvelope = {
      event: event,
      managerId: '',
      geofenceManagerId: geofenceManagerId,
      payload: payload,
    }
    sink.success(envelope)
  }

  sendStatus(event: string, managerId: string, payload: ESObject): void {
    const sink = this.statusHandler.sink
    if (sink === null) return
    const envelope: EventEnvelope = {
      event: event,
      managerId: managerId,
      geofenceManagerId: '',
      payload: payload,
    }
    sink.success(envelope)
  }
}
