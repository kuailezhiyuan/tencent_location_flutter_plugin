import Flutter
import UIKit

/// 腾讯定位 SDK Flutter 插件 iOS 端入口。
public class TencentLocationFlutterPlugin: NSObject, FlutterPlugin {

    private let dispatcher: EventDispatcher
    private let sdkConfig = SdkConfig()
    private let locationRegistry = LocationManagerRegistry()
    private let geofenceRegistry = GeofenceManagerRegistry()
    private let sdkHandler: SdkHandler
    private let locationHandler: LocationHandler
    private let geofenceHandler: GeofenceHandler
    private let utilsHandler = UtilsHandler()

    init(messenger: FlutterBinaryMessenger) {
        self.dispatcher = EventDispatcher(messenger: messenger)
        self.sdkHandler = SdkHandler(config: sdkConfig)
        self.locationHandler = LocationHandler(
            registry: locationRegistry,
            dispatcher: dispatcher,
            config: sdkConfig)
        self.geofenceHandler = GeofenceHandler(
            registry: geofenceRegistry,
            dispatcher: dispatcher)
        super.init()

    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.tencent.map.geolocation.flutter/method",
            binaryMessenger: registrar.messenger())
        let instance = TencentLocationFlutterPlugin(messenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        if method.hasPrefix("sdk.") {
            if sdkHandler.handle(method, call, result) { return }
        } else if method.hasPrefix("manager.") || method.hasPrefix("location.") ||
                    method.hasPrefix("stream.") {
            if locationHandler.handle(method, call, result) { return }
        } else if method.hasPrefix("geofence.") {
            if geofenceHandler.handle(method, call, result) { return }
        } else if method.hasPrefix("utils.") {
            if utilsHandler.handle(method, call, result) { return }
        }
        result(FlutterMethodNotImplemented)
    }
}
