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
        SmartTrackingSession.shared.attach(dispatcher)

    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.tencent.map.geolocation.flutter/method",
            binaryMessenger: registrar.messenger())
        let instance = TencentLocationFlutterPlugin(messenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    private func handleSmart(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let session = SmartTrackingSession.shared
        do {
            switch call.method {
            case "smart.start":
                guard let arguments = call.arguments as? [String: Any] else {
                    Errors.invalidArg(result, "Smart tracking arguments are required"); return
                }
                try session.start(arguments: arguments, sdkConfig: sdkConfig,
                                  ordinaryContinuousActive: LocationManagerEntry.anyContinuousRunning)
                result(session.state().compactMapValues { $0 })
            case "smart.stop":
                session.stop(); result(session.state().compactMapValues { $0 })
            case "smart.getState": result(session.state().compactMapValues { $0 })
            case "smart.getLog": result(try session.getLog())
            case "smart.clearLog": try session.clearLog(); result(nil)
            default: result(FlutterMethodNotImplemented)
            }
        } catch let error as SmartStartError {
            NSLog("Smart tracking %@ failed: %@; stack=%@", call.method, error.localizedDescription, Thread.callStackSymbols.joined(separator: " | "))
            result(Errors.make(code: error.code, message: error.message))
        } catch {
            NSLog("Smart tracking %@ failed: %@; stack=%@", call.method, String(describing: error), Thread.callStackSymbols.joined(separator: " | "))
            result(Errors.make(code: error is SmartConfigurationError ? Errors.invalidArgument : Errors.nativeError,
                               message: error.localizedDescription))
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        if method.hasPrefix("smart.") {
            handleSmart(call, result: result)
            return
        }
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
