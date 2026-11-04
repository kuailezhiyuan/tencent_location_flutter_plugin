import { MethodCall, MethodResult } from '@ohos/flutter_ohos'
import HashMap from '@ohos.util.HashMap'
import { TencentLocationUtil } from '@tencentmap/location_sdk'
import { Errors } from '../Util/Errors'

/**
 * 处理 `utils.*` method。
 *
 * - `utils.wgs84ToGcj02` → 鸿蒙原生 `TencentLocationUtil.wgs84ToGcj02`
 * - `utils.isSupportGps` / `utils.isInRegion` → 鸿蒙原生无对应能力，抛不支持
 */
export class UtilsHandler {
  handle(method: string, call: MethodCall, result: MethodResult): boolean {
    if (!method.startsWith('utils.')) return false

    switch (method) {
      case 'utils.wgs84ToGcj02':
        this.handleWgs84ToGcj02(call, result)
        return true

      case 'utils.isSupportGps':
      case 'utils.isInRegion':
        Errors.unsupported(result, method)
        return true

      default:
        return false
    }
  }

  private handleWgs84ToGcj02(call: MethodCall, result: MethodResult): void {
    // 输入 map 直接就是 TencentLocationCoordinate.toMap() 的结果：
    //   `{ latitude: number, longitude: number }`
    // 参数以 top-level map 传入，无外层 wrapper。
    const args: ESObject = call.args
    if (args === null || args === undefined) {
      Errors.invalidArgument(result, 'latitude / longitude required')
      return
    }
    const latitude: ESObject = UtilsHandler.get(args, 'latitude')
    const longitude: ESObject = UtilsHandler.get(args, 'longitude')
    if (typeof latitude !== 'number' || typeof longitude !== 'number') {
      Errors.invalidArgument(result, 'latitude / longitude must be numbers')
      return
    }

    const wgs84Coordinate: Array<number> = [latitude as number, longitude as number]
    const gcj02Coordinate: Array<number> = [0, 0]
    try {
      const converted: boolean = TencentLocationUtil.wgs84ToGcj02(wgs84Coordinate, gcj02Coordinate)
      if (!converted) {
        Errors.native(result, 'wgs84ToGcj02 failed', null)
        return
      }
      const map: HashMap<string, ESObject> = new HashMap<string, ESObject>()
      map.set('latitude', gcj02Coordinate[0])
      map.set('longitude', gcj02Coordinate[1])
      result.success(map)
    } catch (error) {
      Errors.native(
        result,
        `wgs84ToGcj02 failed: ${String(error)}`,
        error as Error
      )
    }
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
}
