import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  AbilityAware,
  AbilityPluginBinding,
} from '@ohos/flutter_ohos'
import { EventDispatcher } from './Event/EventDispatcher'
import { SdkConfig } from './Handler/SdkConfig'
import { SdkHandler } from './Handler/SdkHandler'
import { LocationHandler } from './Handler/LocationHandler'
import { GeofenceHandler } from './Handler/GeofenceHandler'
import { UtilsHandler } from './Handler/UtilsHandler'
import { LocationManagerRegistry } from './Registry/LocationManagerRegistry'
import { GeofenceManagerRegistry } from './Registry/GeofenceManagerRegistry'

/**
 * 腾讯定位 SDK Flutter 插件 HarmonyOS 端入口。
 *
 * 与 Android / iOS 端同构：
 *
 * - `sdk.*`      → [SdkHandler]
 * - `manager.*` / `location.*` / `stream.*` → [LocationHandler]
 * - `geofence.*` → [GeofenceHandler]
 * - `utils.*`    → [UtilsHandler]
 *
 * 事件通过 3 条 EventChannel（location / geofence / status）分派，全部按
 * `managerId` / `geofenceManagerId` 路由到 Dart 侧对应订阅者。
 *
 * 同时实现 [AbilityAware]：原生 `atManager.requestPermissionsFromUser` 只接受
 * `UIAbilityContext` / `UIExtensionContext`，而 `FlutterPluginBinding.getApplicationContext()`
 * 返回 `common.Context` 不被类型检查接受——通过 AbilityAware 拿到 `UIAbility`，
 * 取其 `.context` 才能正确请求定位授权。
 */
export default class TencentLocationFlutterPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private static readonly METHOD_CHANNEL_NAME: string =
    'com.tencent.map.geolocation.flutter/method'

  private methodChannel: MethodChannel | null = null
  private dispatcher: EventDispatcher | null = null

  private readonly sdkConfig: SdkConfig = new SdkConfig()
  private readonly locationRegistry: LocationManagerRegistry = new LocationManagerRegistry()
  private readonly geofenceRegistry: GeofenceManagerRegistry = new GeofenceManagerRegistry()

  private readonly sdkHandler: SdkHandler = new SdkHandler(this.sdkConfig)
  private readonly utilsHandler: UtilsHandler = new UtilsHandler()
  private locationHandler: LocationHandler | null = null
  private geofenceHandler: GeofenceHandler | null = null

  /** flutter_ohos 引擎通过此方法唯一识别插件实例，必须实现。 */
  getUniqueClassName(): string {
    return 'TencentLocationFlutterPlugin'
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.sdkConfig.context = binding.getApplicationContext()

    this.methodChannel = new MethodChannel(
      binding.getBinaryMessenger(),
      TencentLocationFlutterPlugin.METHOD_CHANNEL_NAME
    )
    this.methodChannel.setMethodCallHandler(this)

    this.dispatcher = new EventDispatcher(binding.getBinaryMessenger())
    this.locationHandler = new LocationHandler(this.dispatcher, this.locationRegistry)
    this.geofenceHandler = new GeofenceHandler(this.dispatcher, this.geofenceRegistry)

  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    if (this.methodChannel !== null) {
      this.methodChannel.setMethodCallHandler(null)
      this.methodChannel = null
    }
    if (this.locationHandler !== null) {
      this.locationHandler.disposeAll()
      this.locationHandler = null
    }
    if (this.geofenceHandler !== null) {
      this.geofenceHandler.disposeAll()
      this.geofenceHandler = null
    }
    if (this.dispatcher !== null) {
      this.dispatcher.dispose()
      this.dispatcher = null
    }
    this.sdkConfig.context = null
  }

  // ---------- AbilityAware ----------

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.sdkConfig.uiAbility = binding.getAbility()
  }

  onDetachedFromAbility(): void {
    this.sdkConfig.uiAbility = null
  }

  // ---------- method dispatch ----------

  onMethodCall(call: MethodCall, result: MethodResult): void {
    const method: string = call.method
    if (method.startsWith('sdk.')) {
      if (this.sdkHandler.handle(method, call, result)) return
    } else if (
      method.startsWith('manager.') ||
      method.startsWith('location.') ||
      method.startsWith('stream.')
    ) {
      const handler = this.locationHandler
      if (handler !== null && handler.handle(method, call, result)) return
    } else if (method.startsWith('geofence.')) {
      const handler = this.geofenceHandler
      if (handler !== null && handler.handle(method, call, result)) return
    } else if (method.startsWith('utils.')) {
      if (this.utilsHandler.handle(method, call, result)) return
    }
    result.notImplemented()
  }
}
