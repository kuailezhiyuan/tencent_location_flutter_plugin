import { MethodCall, MethodResult } from '@ohos/flutter_ohos'
import { TencentLocationSDK } from '@tencentmap/location_sdk'
import { common, Permissions, abilityAccessCtrl } from '@kit.AbilityKit'
import type { PermissionRequestResult } from '@ohos.abilityAccessCtrl'
import { Errors } from '../Util/Errors'
import { SdkConfig } from './SdkConfig'

/**
 * 处理所有 `sdk.*` method 调用。
 *
 * 鸿蒙原生 `TencentLocationSDK` 提供 `setPrivacyPolicyAgreement / init /
 * enableLogToFile / version / buildVersion`，其余（getOaid / setRtkLogEnabled /
 * setSystemCacheEnabled / setUploadGpsForNaviEnabled / setLoadLibraryEnabled）
 * 与 iOS 权限相关 method 一律抛 `unsupportedOnThisPlatform`。
 */
export class SdkHandler {
  private readonly config: SdkConfig

  constructor(config: SdkConfig) {
    this.config = config
  }

  /** 返回 true 表示已处理，否则让主路由器 notImplemented。 */
  handle(method: string, call: MethodCall, result: MethodResult): boolean {
    switch (method) {
      case 'sdk.setPrivacyPolicyAgreement': {
        const agreed: boolean = (call.argument('agreed') as boolean) ?? false
        TencentLocationSDK.setPrivacyPolicyAgreement(agreed)
        result.success(null)
        return true
      }

      case 'sdk.getPrivacyPolicyAgreement': {
        result.success(TencentLocationSDK.isPrivacyPolicyAgreed)
        return true
      }

      case 'sdk.init': {
        this.handleInit(call, result)
        return true
      }

      case 'sdk.getVersion': {
        result.success(TencentLocationSDK.version())
        return true
      }

      case 'sdk.getBuildVersion': {
        result.success(TencentLocationSDK.buildVersion())
        return true
      }

      case 'sdk.enableLogToFile': {
        const enabled: boolean = (call.argument('enabled') as boolean) ?? false
        TencentLocationSDK.enableLogToFile(enabled)
        result.success(null)
        return true
      }

      case 'sdk.setExtraData': {
        const key: string | null = call.argument('key') as string | null
        const value: string | null = call.argument('value') as string | null
        if (key == null || value == null) {
          Errors.invalidArgument(result, 'key and value must be non-null')
          return true
        }
        this.config.extraData.set(key, value)
        // 鸿蒙 SDK 的 extraData 只在 init 时读取；这里先缓存，下次 init 一并生效。
        result.success(null)
        return true
      }

      // 鸿蒙独有：通过 atManager 弹窗请求定位授权。Dart 侧 demo 在 init 前调用。
      // 不进 Dart 公开 API（鸿蒙分支 Flutter 上 permission_handler 等社区插件未适配，
      // 由插件代调避免用户接入阻塞）。与 Android 端 "用户自己用 permission_handler
      // 弹窗" 不一致，是因为鸿蒙生态成熟度不同，参考 iOS 端插件代调
      // `requestIosWhenInUseAuthorization` 的先例。
      case 'sdk.harmony.requestLocationAuthorization': {
        this.handleRequestLocationAuthorization(result)
        return true
      }

      // Android / iOS 独有能力，鸿蒙一律抛不支持
      case 'sdk.getOaid':
      case 'sdk.setRtkLogEnabled':
      case 'sdk.setSystemCacheEnabled':
      case 'sdk.setUploadGpsForNaviEnabled':
      case 'sdk.setLoadLibraryEnabled':
      case 'sdk.ios.requestWhenInUseAuthorization':
      case 'sdk.ios.requestAlwaysAuthorization':
      case 'sdk.ios.requestTemporaryFullAccuracy':
      case 'sdk.ios.getAccuracyAuthorization':
        Errors.unsupported(result, method)
        return true

      default:
        return false
    }
  }

  private handleInit(call: MethodCall, result: MethodResult): void {
    const apiKey: string | null = call.argument('harmonyApiKey') as string | null
    const deviceId: string | null = call.argument('deviceId') as string | null

    // androidApiKey / iosApiKey / extraKey 在鸿蒙端无意义，忽略。
    if (apiKey != null && apiKey.length > 0) {
      this.config.harmonyApiKey = apiKey
    }
    if (deviceId != null && deviceId.length > 0) {
      this.config.deviceId = deviceId
    }

    const context = this.config.context
    if (context == null) {
      Errors.code(
        result,
        Errors.SDK_INIT_FAILED,
        'sdk.init failed: application context is not attached yet',
        null
      )
      return
    }

    try {
      TencentLocationSDK.init(
        context,
        this.config.harmonyApiKey,
        this.config.deviceId,
        this.config.extraData.size > 0 ? this.config.extraData : undefined
      )
      result.success(null)
    } catch (error) {
      const cause = error as Error
      Errors.code(
        result,
        Errors.SDK_INIT_FAILED,
        `sdk.init failed: ${cause.message ?? String(cause)}`,
        String(cause)
      )
    }
  }

  private handleRequestLocationAuthorization(result: MethodResult): void {
    const uiAbility = this.config.uiAbility
    if (uiAbility === null) {
      Errors.code(
        result,
        Errors.SDK_INIT_FAILED,
        'request authorization failed: UIAbility is not attached yet',
        null
      )
      return
    }

    try {
      // UIAbility.context 是 UIAbilityContext，atManager.requestPermissionsFromUser
      // 只接受 UIAbilityContext / UIExtensionContext。FlutterPluginBinding.getApplicationContext()
      // 返回的是 common.Context，类型不被接受——所以必须走 AbilityAware 拿到 UIAbility。
      const abilityContext: common.UIAbilityContext = uiAbility.context
      const permissions: Array<Permissions> = [
        'ohos.permission.APPROXIMATELY_LOCATION',
        'ohos.permission.LOCATION',
      ]
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
      atManager.requestPermissionsFromUser(abilityContext, permissions)
        .then((requestResult: PermissionRequestResult) => {
          // 用户点「拒绝」时 Promise 依然 resolve，必须检查 authResults：
          // 0 = 已授权，-1 = 未授权，2 = 请求无效。只要有一项不是 0 就视为未获得授权。
          result.success(SdkHandler.isLocationPermissionGranted(requestResult.authResults))
        })
        .catch((_error: Error) => {
          // 调用链本身失败（权限未在 module.json5 声明、context 失效等），按未授权处理。
          result.success(false)
        })
    } catch (error) {
      const cause = error as Error
      Errors.native(
        result,
        `requestLocationAuthorization failed: ${cause.message ?? String(cause)}`,
        cause
      )
    }
  }

  /**
   * 判断 atManager 返回的定位权限结果是否全部授权。
   *
   * HarmonyOS 中 `requestPermissionsFromUser` 即使用户拒绝也会 resolve；只有结果
   * 非空且每个授权码均为 0 才表示本次请求获得完整定位权限。
   */
  static isLocationPermissionGranted(authResults: Array<number> | undefined): boolean {
    return authResults !== undefined
      && authResults.length > 0
      && authResults.every((code: number) => code === 0)
  }
}
