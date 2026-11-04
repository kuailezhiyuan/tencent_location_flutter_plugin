import { MethodCall, MethodResult } from '@ohos/flutter_ohos'
import HashMap from '@ohos.util.HashMap'
import {
  TencentLocation,
  TencentLocationError,
  TencentLocationManager,
  TencentLocationRequest,
} from '@tencentmap/location_sdk'
import { Errors } from '../Util/Errors'
import { EnumCodec } from '../Codec/EnumCodec'
import { LocationCodec } from '../Codec/LocationCodec'
import { RequestCodec } from '../Codec/RequestCodec'
import { EventDispatcher } from '../Event/EventDispatcher'
import { LocationManagerEntry } from '../Registry/LocationManagerEntry'
import { LocationManagerRegistry } from '../Registry/LocationManagerRegistry'

/**
 * 处理 `manager.*` / `location.*` / `stream.*` method。
 *
 * 与 Android / iOS 端同构：
 *
 * - `manager.create` / `manager.dispose`：Entry 生命周期（Handler 负责 new entry + registry.put）
 * - `location.startContinuous` / `location.stopContinuous`：连续定位
 * - `location.startSingle` / `location.getLastLocation`：单次定位 / 上次位置
 * - `location.changeCallbackInterval`：鸿蒙原生不支持（需要 stop→start 重启）
 * - `location.android.*` / `location.ios.*`：不支持
 *
 * Handler 只做参数校验 + payload 编解码 + 委托 entry；不直接触碰原生 SDK。
 */
export class LocationHandler {
  private readonly dispatcher: EventDispatcher
  private readonly registry: LocationManagerRegistry

  constructor(dispatcher: EventDispatcher, registry: LocationManagerRegistry) {
    this.dispatcher = dispatcher
    this.registry = registry
  }

/** 返回 true 表示已处理。 */
  handle(method: string, call: MethodCall, result: MethodResult): boolean {
    // manager.*
    if (method === 'manager.create') {
      const managerId = call.argument('managerId') as string | null
      if (managerId === null) {
        Errors.invalidArgument(result, 'managerId must be non-null')
        return true
      }
      if (this.registry.get(managerId) !== null) {
        result.success(null)
        return true
      }
      const native: TencentLocationManager | undefined = TencentLocationManager.createInstance()
      if (native === undefined) {
        Errors.code(
          result,
          Errors.PRIVACY_NOT_AGREED,
          'sdk.setPrivacyPolicyAgreement(true) must be called before creating a manager',
          null
        )
        return true
      }
      const entry = new LocationManagerEntry(managerId, native, this.dispatcher)
      this.registry.put(managerId, entry)
      result.success(null)
      return true
    }

    if (method === 'manager.dispose') {
      const managerId = call.argument('managerId') as string | null
      if (managerId === null) {
        Errors.invalidArgument(result, 'managerId must be non-null')
        return true
      }
      const entry = this.registry.get(managerId)
      if (entry === null) {
        result.success(null)
        return true
      }
      try {
        entry.dispose()
      } catch (error) {
        // 释放失败时保留 registry entry，允许 Dart 层再次 manager.dispose 重试。
        Errors.native(result, `dispose manager failed: ${String(error)}`, error as Error)
        return true
      }
      this.registry.remove(managerId)
      result.success(null)
      return true
    }

    // 其他 location.* / stream.* 都需要 managerId + 已注册 entry
    if (!method.startsWith('location.') && !method.startsWith('stream.')) return false

    const managerId = call.argument('managerId') as string | null
    if (managerId === null) {
      Errors.invalidArgument(result, 'managerId must be non-null')
      return true
    }
    const entry = this.registry.get(managerId)
    if (entry === null) {
      Errors.code(
        result,
        Errors.NATIVE_ERROR,
        `Location manager not found: ${managerId}`,
        null
      )
      return true
    }

    switch (method) {
      case 'stream.status.start':
        this.handleStreamStatusStart(result, entry)
        return true
      case 'stream.status.stop':
        this.handleStreamStatusStop(result, entry)
        return true
      case 'stream.orientation.start':
        this.handleStreamOrientationStart(result, entry)
        return true
      case 'stream.orientation.stop':
        this.handleStreamOrientationStop(result, entry)
        return true

      case 'location.startContinuous':
        this.handleStartContinuous(call, result, entry)
      return true
      case 'location.stopContinuous':
        this.handleStopContinuous(result, entry)
        return true
      case 'location.startSingle':
        this.handleStartSingle(call, result, entry)
        return true
      case 'location.getLastLocation':
        this.handleGetLastLocation(result, entry)
        return true

      case 'location.harmony.startBackgroundTask':
        this.handleStartBackgroundTask(call, result, entry)
        return true
      case 'location.harmony.stopBackgroundTask':
        this.handleStopBackgroundTask(result, entry)
        return true

      // 鸿蒙原生不支持：需要 stop→改 request→start 才能改回调间隔
      case 'location.changeCallbackInterval':
      // Android / iOS 独有
      case 'location.android.enableForeground':
      case 'location.android.disableForeground':
      case 'location.ios.dismissHeadingCalibrationDisplay':
      case 'location.ios.setExtraData':
        Errors.unsupported(result, method)
        return true

      default:
        return false
    }
  }

  // ---------- 生命周期 ----------

  disposeAll(): void {
    for (const entry of this.registry.all()) {
      try {
        entry.dispose()
      } catch (_error) {
        // 引擎卸载时尽力释放每个 entry；单个 native stop 失败不应阻断其他 entry。
      }
    }
    this.registry.clear()
  }

  // ---------- 私有 stream 生命周期 ----------

  private handleStreamStatusStart(result: MethodResult, entry: LocationManagerEntry): void {
    try {
      entry.startStatusReceiving()
      result.success(null)
    } catch (error) {
      Errors.native(result, `start status stream failed: ${String(error)}`, error as Error)
    }
  }

  private handleStreamStatusStop(result: MethodResult, entry: LocationManagerEntry): void {
    try {
      entry.stopStatusReceiving()
      result.success(null)
    } catch (error) {
      Errors.native(result, `stop status stream failed: ${String(error)}`, error as Error)
    }
  }

  private handleStreamOrientationStart(result: MethodResult, entry: LocationManagerEntry): void {
    try {
      entry.startOrientationReceiving()
      result.success(null)
    } catch (error) {
      Errors.native(result, `start orientation stream failed: ${String(error)}`, error as Error)
    }
  }

  private handleStreamOrientationStop(result: MethodResult, entry: LocationManagerEntry): void {
    try {
      entry.stopOrientationReceiving()
      result.success(null)
    } catch (error) {
      Errors.native(result, `stop orientation stream failed: ${String(error)}`, error as Error)
    }
  }

  // ---------- 连续定位 ----------

  private handleStartContinuous(
    call: MethodCall,
    result: MethodResult,
    entry: LocationManagerEntry
  ): void {
    const requestMap: ESObject = call.argument('request')
    if (requestMap === null || requestMap === undefined) {
      Errors.invalidArgument(result, 'request must be non-null')
      return
    }

    let request: TencentLocationRequest
    let coordinateTypeWire: string
    try {
      request = RequestCodec.fromMap(requestMap)
      const coordinateType = RequestCodec.coordinateTypeFromMap(requestMap)
      if (coordinateType !== null) {
        request.setCoordinateType(coordinateType)
      }
      coordinateTypeWire = RequestCodec.coordinateTypeWireFromMap(requestMap)
    } catch (parseError) {
      Errors.invalidArgument(result, `invalid request: ${String(parseError)}`)
      return
    }

    try {
      entry.startContinuous(request, coordinateTypeWire)
      result.success(null)
    } catch (error) {
      Errors.native(result, `startContinuous failed: ${String(error)}`, error as Error)
    }
  }

  private handleStopContinuous(
    result: MethodResult,
    entry: LocationManagerEntry
  ): void {
    try {
      entry.stopContinuous()
      result.success(null)
    } catch (error) {
      Errors.native(result, `stopContinuous failed: ${String(error)}`, error as Error)
    }
  }

  // ---------- 单次定位 ----------

  private handleStartSingle(
    call: MethodCall,
    result: MethodResult,
    entry: LocationManagerEntry
  ): void {
    const requestMap: ESObject = call.argument('request')
    if (requestMap === null || requestMap === undefined) {
      Errors.invalidArgument(result, 'request must be non-null')
      return
    }

    let request: TencentLocationRequest
    let coordinateTypeWire: string
    try {
      request = RequestCodec.fromMap(requestMap)
      const coordinateType = RequestCodec.coordinateTypeFromMap(requestMap)
      if (coordinateType !== null) {
        request.setCoordinateType(coordinateType)
      }
      coordinateTypeWire = RequestCodec.coordinateTypeWireFromMap(requestMap)
    } catch (parseError) {
      Errors.invalidArgument(result, `invalid request: ${String(parseError)}`)
      return
    }

    // success / failure 只回调一次；用 `settled` 兜底防御性去重
    // （鸿蒙原生实现是 Promise-like 回调，理论上不会重入，防御性保守）。
    let settled: boolean = false

    const onSuccess = (location: TencentLocation): void => {
      if (settled) return
      settled = true
      try {
        const map: ESObject = LocationCodec.toMap(location, coordinateTypeWire)
        result.success(map)
      } catch (encodeError) {
        Errors.native(
          result,
          `startSingle succeed but encode failed: ${String(encodeError)}`,
          encodeError as Error
        )
      }
    }

    const onFailure = (error: TencentLocationError): void => {
      if (settled) return
      settled = true
      Errors.code(
        result,
        EnumCodec.errorCodeToWire(error.code),
        error.message ?? 'startSingle failed',
        error.code
      )
    }

    try {
      entry.startSingle(request, onSuccess, onFailure)
    } catch (throwError) {
      if (settled) return
      settled = true
      Errors.native(
        result,
        `startSingle failed: ${String(throwError)}`,
        throwError as Error
      )
    }
  }

  // ---------- 最近位置 ----------

  private handleGetLastLocation(
    result: MethodResult,
    entry: LocationManagerEntry
  ): void {
    try {
      const location = entry.getLastLocation()
      if (location === undefined) {
        result.success(null)
        return
      }
      // 上次位置的坐标系无法通过 API 反查，与 iOS 端一致 fallback 到 gcj02
      // （SDK 内部 lastGivenOutTencentLocation 已经过坐标系转换）。
      const map: ESObject = LocationCodec.toMap(location, 'gcj02')
      result.success(map)
    } catch (error) {
      Errors.native(
        result,
        `getLastLocation failed: ${String(error)}`,
        error as Error
      )
    }
  }

  // ---------- 后台定位（鸿蒙独有） ----------

  private handleStartBackgroundTask(
    call: MethodCall,
    result: MethodResult,
    entry: LocationManagerEntry
  ): void {
    // Dart 侧 `wantAgentInfo` 是 Map<String, Object?>?。当前实现直接把它透传给
    // 原生 `startBackgroundLocationTask(wantAgentInfo?: wantAgent.WantAgentInfo)`。
    //
    // ⚠️ 精细定制（自定义 wants / actionType / wantAgentFlags）需要把 map 里的
    // int 反序列化成鸿蒙 `wantAgent.OperationType` / `WantAgentFlags` 枚举，成本
    // 高且极易出错。P5 阶段只放行 `null / undefined`（走 SDK 默认 wantAgent，
    // 点击通知回自己 ability）；非 null 时同样按 undefined 处理并留 warning。
    const wantAgentInfo: ESObject = call.argument('wantAgentInfo')
    if (wantAgentInfo !== null && wantAgentInfo !== undefined) {
      // TODO: 后续版本按需支持 wantAgentInfo 深层反序列化；目前忽略但不抛错。
      console.warn(
        '[TencentLocationFlutterPlugin] custom wantAgentInfo is not yet supported on HarmonyOS; '
          + 'falling back to SDK default WantAgentInfo.'
      )
    }
    try {
      entry.startBackgroundTask()
      result.success(null)
    } catch (error) {
      Errors.native(
        result,
        `startBackgroundTask failed: ${String(error)}`,
        error as Error
      )
    }
  }

  private handleStopBackgroundTask(
    result: MethodResult,
    entry: LocationManagerEntry
  ): void {
    try {
      entry.stopBackgroundTask()
      result.success(null)
    } catch (error) {
      Errors.native(
        result,
        `stopBackgroundTask failed: ${String(error)}`,
        error as Error
      )
    }
  }
}
