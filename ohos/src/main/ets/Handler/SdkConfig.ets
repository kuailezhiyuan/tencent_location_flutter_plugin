import { common } from '@kit.AbilityKit'
import UIAbility from '@ohos.app.ability.UIAbility'

/**
 * 进程级共享的 SDK 配置。
 *
 * 鸿蒙原生 `TencentLocationSDK.init` 与 `TencentLocationManager.createInstance`
 * 分离：init 缓存 apiKey / deviceID / extraData 到全局静态字段，manager 实例
 * 创建时不再重新读取参数。本 [SdkConfig] 只在 Flutter 侧再缓存一份，方便：
 *
 * - `sdk.init` 与 `sdk.setExtraData` 之间的顺序无关（先设后 init 也能生效）
 * - 用户在 [Ability] 初始化前先调 `sdk.setPrivacyPolicyAgreement` 时兜底
 */
export class SdkConfig {
  /** 由 [TencentLocationFlutterPlugin.onAttachedToEngine] 注入，之后可直接读取。 */
  context: common.Context | null = null

  /**
   * 由 [TencentLocationFlutterPlugin.onAttachedToAbility] 注入。
   *
   * 仅在请求需要 UIAbilityContext 的系统能力（如 atManager.requestPermissionsFromUser）
   * 时使用，避免 FlutterPluginBinding.getApplicationContext() 返回的通用 Context
   * 不被 SDK 类型检查接受。
   */
  uiAbility: UIAbility | null = null

  /** 用户通过 `sdk.init` 传入的鸿蒙 apiKey。 */
  harmonyApiKey: string | undefined = undefined

  /** 用户通过 `sdk.init` 传入的设备 id。 */
  deviceId: string | undefined = undefined

  /** 通过 `sdk.setExtraData` / `sdk.init` 累积的附加数据。 */
  readonly extraData: Map<string, string> = new Map<string, string>()
}
