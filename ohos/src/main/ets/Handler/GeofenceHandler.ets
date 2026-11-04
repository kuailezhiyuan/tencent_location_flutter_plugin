import { MethodCall, MethodResult } from '@ohos/flutter_ohos'
import {
  TencentGeofence,
  TencentLocationConstant,
  TencentLocationManager,
} from '@tencentmap/location_sdk'
import { Errors } from '../Util/Errors'
import { EnumCodec } from '../Codec/EnumCodec'
import { GeofenceCodec } from '../Codec/GeofenceCodec'
import { EventDispatcher } from '../Event/EventDispatcher'
import { GeofenceManagerEntry, GeofenceMeta } from '../Registry/GeofenceManagerEntry'
import { GeofenceManagerRegistry } from '../Registry/GeofenceManagerRegistry'

/**
 * 处理 `geofence.*` method。
 *
 * 与 Android / iOS 端同构，但鸿蒙**只支持圆形围栏**，polygon / district 会抛
 * `geofenceInvalidRegion`。
 *
 * ⚠️ 鸿蒙原生 `addGeofence` 返回**由系统分配的 number id**，Dart 层用字符串 id，
 * 双向映射由 [GeofenceManagerEntry] 维护。
 *
 * ⚠️ 鸿蒙原生**不支持**：
 * - `isCoordinateInside` / `regionsContainingCoordinate`（Dart 侧不做 haversine 兜底，
 *   见设计决策 #15）→ 抛 `unsupportedOnThisPlatform`
 * - iOS 独有的 `startMonitoring / pauseMonitoring / setIosXxx` → 抛不支持
 *
 * Handler 只做参数校验 + fence 反序列化 + 委托 entry；不直接触碰原生围栏 API。
 */
export class GeofenceHandler {
  private readonly dispatcher: EventDispatcher
  private readonly registry: GeofenceManagerRegistry

  constructor(dispatcher: EventDispatcher, registry: GeofenceManagerRegistry) {
    this.dispatcher = dispatcher
    this.registry = registry
  }

  handle(method: string, call: MethodCall, result: MethodResult): boolean {
    if (!method.startsWith('geofence.')) return false

    // 生命周期
    if (method === 'geofence.managerCreate') {
      const id = call.argument('geofenceManagerId') as string | null
      if (id === null) {
        Errors.invalidArgument(result, 'geofenceManagerId must be non-null')
        return true
      }
      if (this.registry.get(id) !== null) {
        result.success(null)
        return true
      }
      const native: TencentLocationManager | undefined = TencentLocationManager.createInstance()
      if (native === undefined) {
        Errors.code(
          result,
          Errors.PRIVACY_NOT_AGREED,
          'sdk.setPrivacyPolicyAgreement(true) must be called before creating a geofence manager',
          null
        )
        return true
      }
      const entry = new GeofenceManagerEntry(id, native, this.dispatcher)
      this.registry.put(id, entry)
      result.success(null)
      return true
    }
    if (method === 'geofence.managerDispose') {
      const id = call.argument('geofenceManagerId') as string | null
      if (id === null) {
        Errors.invalidArgument(result, 'geofenceManagerId must be non-null')
        return true
      }
      const entry = this.registry.remove(id)
      if (entry !== null) entry.dispose()
      result.success(null)
      return true
    }

    // 其他 geofence.* 需要 entry
    const geofenceManagerId = call.argument('geofenceManagerId') as string | null
    if (geofenceManagerId === null) {
      Errors.invalidArgument(result, 'geofenceManagerId must be non-null')
      return true
    }
    const entry = this.registry.get(geofenceManagerId)
    if (entry === null) {
      Errors.code(
        result,
        Errors.NATIVE_ERROR,
        `Geofence manager not found: ${geofenceManagerId}`,
        null
      )
      return true
    }

    switch (method) {
      case 'geofence.add':
        this.handleAdd(call, result, entry)
        return true
      case 'geofence.remove':
        this.handleRemove(call, result, entry)
        return true
      case 'geofence.removeAll':
        this.handleRemoveAll(result, entry)
        return true
      case 'geofence.getAll':
        result.success(entry.getAllAsMaps())
        return true

      case 'geofence.isCoordinateInside':
      case 'geofence.regionsContaining':
      case 'geofence.ios.startMonitoring':
      case 'geofence.ios.stopMonitoring':
      case 'geofence.ios.pauseMonitoring':
      case 'geofence.ios.resumeMonitoring':
      case 'geofence.ios.isMonitoring':
      case 'geofence.ios.setAllowsBackgroundLocationUpdates':
      case 'geofence.ios.setAdaptiveDistanceFilterEnabled':
      case 'geofence.ios.setDistanceFilter':
      case 'geofence.ios.setDesiredAccuracy':
      case 'geofence.ios.setDetectionInterval':
        Errors.unsupported(result, method)
        return true

      default:
        return false
    }
  }

  // ---------- 生命周期 ----------

  disposeAll(): void {
    for (const entry of this.registry.all()) {
      entry.dispose()
    }
    this.registry.clear()
  }

  // ---------- add ----------

  private handleAdd(
    call: MethodCall,
    result: MethodResult,
    entry: GeofenceManagerEntry
  ): void {
    const fenceMap: ESObject = call.argument('geofence')
    if (fenceMap === null || fenceMap === undefined) {
      Errors.invalidArgument(result, 'geofence must be non-null')
      return
    }

    // 只支持 circle：其他类型直接返回 wire 错误
    const typeError = GeofenceCodec.validateCircleOrError(fenceMap)
    if (typeError !== null) {
      Errors.code(
        result,
        typeError,
        'HarmonyOS geofence only supports circle regions',
        null
      )
      return
    }

    const dartId: string = (GeofenceCodec.asStringPublic(GeofenceCodec.getPublic(fenceMap, 'id'))) ?? ''
    if (dartId.length === 0) {
      Errors.invalidArgument(result, 'geofence.id must be non-empty')
      return
    }

    // Dart 侧允许重复 id 时抛错，与 Android/iOS 对齐
    if (entry.isRegistered(dartId)) {
      Errors.code(
        result,
        Errors.GEOFENCE_DUPLICATE_ID,
        `geofence id already exists: ${dartId}`,
        null
      )
      return
    }

    let fence: TencentGeofence | null
    try {
      fence = GeofenceCodec.fenceFromMap(fenceMap)
    } catch (parseError) {
      Errors.invalidArgument(result, `invalid geofence: ${String(parseError)}`)
      return
    }
    if (fence === null) {
      Errors.code(
        result,
        Errors.GEOFENCE_INVALID_REGION,
        'invalid circle geofence',
        null
      )
      return
    }

    const monitorEvents: Array<TencentLocationConstant.GeofenceEvent> =
      GeofenceCodec.monitorEventsFromMap(fenceMap)
    const monitorWires: Array<string> = monitorEvents.map((event) =>
      EnumCodec.geofenceEventToWire(event)
    )
    const coordinateWire: string = EnumCodec.coordinateTypeToWire(fence.coordinateType)

    const meta: GeofenceMeta = {
      latitude: fence.latitude,
      longitude: fence.longitude,
      radius: fence.radius,
      // native 将 null / 0 / 负值统一解释为永不过期；缓存同一语义，
      // 避免 getAll 返回与原生实际生效状态不一致的零或负 Duration。
      expirationMs: GeofenceHandler.normalizeExpirationMs(fenceMap),
      coordinateTypeWire: coordinateWire,
      monitorTransitionWires: monitorWires,
    }

    entry.addCircleGeofence(fence, monitorEvents, dartId, meta)
      .then(() => {
        result.success(null)
      })
      .catch((error: ESObject) => {
        GeofenceHandler.rejectWithNativeError(result, 'addGeofence', error)
      })
  }

  // ---------- remove ----------

  private handleRemove(
    call: MethodCall,
    result: MethodResult,
    entry: GeofenceManagerEntry
  ): void {
    const id = call.argument('id') as string | null
    if (id === null) {
      Errors.invalidArgument(result, 'id must be non-null')
      return
    }
    if (!entry.isRegistered(id)) {
      Errors.code(
        result,
        Errors.GEOFENCE_ID_NOT_FOUND,
        `geofence id not found: ${id}`,
        null
      )
      return
    }
    entry.removeByDartId(id)
      .then(() => {
        result.success(null)
      })
      .catch((error: ESObject) => {
        GeofenceHandler.rejectWithNativeError(result, 'removeGeofence', error)
      })
  }

  // ---------- removeAll ----------

  private handleRemoveAll(
    result: MethodResult,
    entry: GeofenceManagerEntry
  ): void {
    entry.removeAll()
      .then(() => {
        result.success(null)
      })
      .catch((error: ESObject) => {
        GeofenceHandler.rejectWithNativeError(result, 'removeAllGeofences', error)
      })
  }

  // ---------- helper ----------

  /**
   * 将 Dart 围栏有效期归一化为原生实际语义。
   *
   * 鸿蒙 `TencentGeofence` 对 `null / 0 / 负值` 都按永不过期处理，
   * 所以只缓存正毫秒值；其他值一律以 null 回传给 Dart。
   */
  static normalizeExpirationMs(fenceMap: ESObject): number | null {
    const expirationMs = GeofenceCodec.asNumberPublic(
      GeofenceCodec.getPublic(fenceMap, 'expirationMs')
    )
    return expirationMs !== null && expirationMs > 0 ? expirationMs : null
  }

  private static rejectWithNativeError(
    result: MethodResult,
    scope: string,
    error: ESObject
  ): void {
    const errCode: number | null = GeofenceCodec.asNumberPublic(GeofenceCodec.getPublic(error, 'code'))
    const errMsg: string | null = GeofenceCodec.asStringPublic(GeofenceCodec.getPublic(error, 'message'))
    if (errCode !== null) {
      Errors.code(
        result,
        EnumCodec.errorCodeToWire(errCode),
        errMsg ?? `${scope} failed`,
        errCode
      )
      return
    }
    Errors.native(result, `${scope} failed: ${String(error)}`, error as Error)
  }
}
