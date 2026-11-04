import Flutter

/// 把原生事件分派到 Flutter 侧的 3 条 ``FlutterEventChannel``。
///
/// - 所有事件 payload 中带 `managerId` / `geofenceManagerId`，由 Dart 层做路由
/// - 每条 channel 共享同一个 ``StreamHandler``，订阅生命周期由 ``onListen`` /
///   ``onCancel`` 暴露给上层（用于按需开启 / 关闭原生订阅）
final class EventDispatcher {
    enum Channel {
        case location
        case geofence
        case status
    }

    private final class StreamHandler: NSObject, FlutterStreamHandler {
        var sink: FlutterEventSink?

        func onListen(withArguments arguments: Any?,
                      eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            sink = events
            return nil
        }

        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            sink = nil
            return nil
        }
    }

    private let locationChannel: FlutterEventChannel
    private let geofenceChannel: FlutterEventChannel
    private let statusChannel: FlutterEventChannel

    private let locationHandler = StreamHandler()
    private let geofenceHandler = StreamHandler()
    private let statusHandler = StreamHandler()

    init(messenger: FlutterBinaryMessenger) {
        locationChannel = FlutterEventChannel(
            name: "com.tencent.map.geolocation.flutter/event/location",
            binaryMessenger: messenger)
        geofenceChannel = FlutterEventChannel(
            name: "com.tencent.map.geolocation.flutter/event/geofence",
            binaryMessenger: messenger)
        statusChannel = FlutterEventChannel(
            name: "com.tencent.map.geolocation.flutter/event/status",
            binaryMessenger: messenger)

        locationChannel.setStreamHandler(locationHandler)
        geofenceChannel.setStreamHandler(geofenceHandler)
        statusChannel.setStreamHandler(statusHandler)
    }

    // MARK: - send

    func sendLocation(event: String, managerId: String, payload: [String: Any?]) {
        send(channel: .location, top: ["managerId": managerId], event: event, payload: payload)
    }

    func sendStatus(event: String, managerId: String, payload: [String: Any?]) {
        send(channel: .status, top: ["managerId": managerId], event: event, payload: payload)
    }

    func sendGeofence(event: String, geofenceManagerId: String, payload: [String: Any?]) {
        send(channel: .geofence, top: ["geofenceManagerId": geofenceManagerId],
             event: event, payload: payload)
    }

    private func send(channel: Channel, top: [String: Any], event: String,
                      payload: [String: Any?]) {
        let sink: FlutterEventSink?
        switch channel {
        case .location: sink = locationHandler.sink
        case .geofence: sink = geofenceHandler.sink
        case .status: sink = statusHandler.sink
        }
        guard let sink = sink else { return }
        var message: [String: Any] = top
        message["event"] = event
        message["payload"] = payload.compactMapValues { $0 }
        DispatchQueue.main.async {
            sink(message)
        }
    }
}
