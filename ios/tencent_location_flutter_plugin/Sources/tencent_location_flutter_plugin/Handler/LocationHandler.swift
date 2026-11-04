import Flutter
import TencentLBS

/// 处理 ``manager.*`` / ``location.*`` / ``stream.*`` method。
final class LocationHandler {

    private let registry: LocationManagerRegistry
    private let dispatcher: EventDispatcher
    private let config: SdkConfig

    init(registry: LocationManagerRegistry,
         dispatcher: EventDispatcher,
         config: SdkConfig) {
        self.registry = registry
        self.dispatcher = dispatcher
        self.config = config
    }

    func handle(_ method: String, _ call: FlutterMethodCall,
                _ result: @escaping FlutterResult) -> Bool {

        switch method {
        // ---------- manager 生命周期 ----------
        case "manager.create":
            guard let id = call.argString("managerId") else {
                Errors.invalidArg(result, "managerId required"); return true
            }
            if registry.get(id) != nil {
                result(nil); return true
            }
            guard let entry = LocationManagerEntry(managerId: id, dispatcher: dispatcher) else {
                result(Errors.make(code: Errors.privacyNotAgreed,
                                   message: "TencentLBSLocationManager init returned nil; ensure setPrivacyPolicyAgreement(true) was called first"))
                return true
            }
            config.apply(to: entry.locationManager)
            registry.put(id, entry)
            result(nil)
            return true

        case "manager.dispose":
            guard let id = call.argString("managerId") else {
                Errors.invalidArg(result, "managerId required"); return true
            }
            if let entry = registry.remove(id) {
                entry.stopContinuous()
                entry.stopHeading()
            }
            result(nil)
            return true

        // ---------- stream 生命周期 ----------
        case "stream.status.start", "stream.status.stop":
            // iOS SDK 没有设备状态回调；订阅成功但静默。
            guard lookup(call, result) != nil else { return true }
            result(nil)
            return true

        case "stream.orientation.start":
            guard let entry = lookup(call, result) else { return true }
            entry.startHeading()
            result(nil)
            return true

        case "stream.orientation.stop":
            guard let entry = lookup(call, result) else { return true }
            entry.stopHeading()
            result(nil)
            return true

        // ---------- 定位 ----------
        case "location.startContinuous":
            guard let entry = lookup(call, result) else { return true }
            // 配置已通过 apply 直接落到 manager 属性上，无需缓存 snapshot —— 见
            // applyRequestIfPresent 的文档注释。
            applyRequestIfPresent(call, entry: entry)
            entry.startContinuous()
            result(nil)
            return true

        case "location.stopContinuous":
            guard let entry = lookup(call, result) else { return true }
            entry.stopContinuous()
            result(nil)
            return true

        case "location.startSingle":
            guard let entry = lookup(call, result) else { return true }
            let snapshot = applyRequestIfPresent(call, entry: entry)
            let timeoutMs = snapshot?.singleLocationTimeoutMs ?? 10_000
            let level = snapshot?.requestLevel ?? .adminName
            let coordinateType = snapshot?.coordinateType ?? .GCJ02
            let started = entry.startSingle(timeoutMs: timeoutMs, level: level) { location, error in
                if let error = error as NSError? {
                    result(Errors.make(code: Errors.locationFailed,
                                       message: error.localizedDescription,
                                       nativeCode: error.code))
                    return
                }
                guard let location = location else {
                    result(Errors.make(code: Errors.locationFailed,
                                       message: "single location returned nil"))
                    return
                }
                result(LocationCodec.toMap(location, coordinateType: coordinateType)
                    .compactMapValues { $0 })
            }
            if !started {
                result(Errors.make(code: Errors.alreadyStarted,
                                   message: "another single location is in progress"))
            }
            return true

        case "location.ios.dismissHeadingCalibrationDisplay":
            guard let entry = lookup(call, result) else { return true }
            entry.dismissHeadingCalibrationDisplay()
            result(nil)
            return true

        case "location.ios.setExtraData":
            guard let entry = lookup(call, result),
                  let key = call.argString("key"),
                  let value = call.argString("value") else {
                Errors.invalidArg(result, "managerId/key/value required"); return true
            }
            entry.locationManager.setDataWithValue(value, forKey: key)
            result(nil)
            return true

        // ---------- iOS 不支持的能力 ----------
        // - getLastLocation：iOS SDK 没有"获取最近一次定位结果"的能力。
        // - changeCallbackInterval：iOS 上 locationCallbackInterval 仅在启动前
        //   生效，运行时改不重建定时器。
        // - android.* / harmony.*：平台独有能力，iOS 一律抛不支持。
        case "location.getLastLocation",
             "location.changeCallbackInterval",
             "location.android.enableForeground",
             "location.android.disableForeground",
             "location.harmony.startBackgroundTask",
             "location.harmony.stopBackgroundTask":
            Errors.unsupported(result, method: method)
            return true

        default:
            return false
        }
    }

    // MARK: - helpers

    private func lookup(_ call: FlutterMethodCall,
                        _ result: @escaping FlutterResult) -> LocationManagerEntry? {
        guard let id = call.argString("managerId") else {
            Errors.invalidArg(result, "managerId required"); return nil
        }
        guard let entry = registry.get(id) else {
            result(Errors.make(code: Errors.nativeError,
                               message: "manager not found: \(id)"))
            return nil
        }
        return entry
    }

    /// 把当前 method call 中的 `request` 段（若存在）应用到 entry 持有的原生 manager 上。
    ///
    /// 返回的 ``RequestCodec/CommonConfig`` 仅供调用方在**当前调用栈内**消费（典型场景是
    /// `location.startSingle` 拿 `requestLevel` / `singleLocationTimeoutMs` / `coordinateType`
    /// 用作请求参数）。`location.startContinuous` 路径不消费返回值是有意为之：
    /// `TencentLBSLocationManager` 的所有配置项都是属性式直写，apply 时已经全部落到 manager 上，
    /// `startUpdatingLocation` 后不需要再二次回放，也没有 ``Android`` 那种 `changeXxx` 运行时改
    /// 配的入口（iOS 的 `location.changeCallbackInterval` 直接抛
    /// ``Errors/unsupportedOnThisPlatform``）。因此不在 entry 上缓存 snapshot，避免后续维护者
    /// 误以为某些路径会自动 re-apply。
    @discardableResult
    private func applyRequestIfPresent(_ call: FlutterMethodCall,
                                       entry: LocationManagerEntry) -> RequestCodec.CommonConfig? {
        guard let arguments = call.arguments as? [String: Any?],
              let requestMap = arguments["request"] as? [String: Any?] else {
            return nil
        }
        let snapshot = RequestCodec.apply(requestMap, to: entry.locationManager)
        // coordinateType 需要跨方法保留，因为 didUpdate location 回调里要用它来选择
        // 输出的坐标系（GCJ02 / WGS84），manager 自身不暴露查询接口。
        entry.updateCoordinateType(snapshot.coordinateType)
        return snapshot
    }
}

private extension FlutterMethodCall {
    func argString(_ name: String) -> String? {
        return (arguments as? [String: Any])?[name] as? String
    }
}
