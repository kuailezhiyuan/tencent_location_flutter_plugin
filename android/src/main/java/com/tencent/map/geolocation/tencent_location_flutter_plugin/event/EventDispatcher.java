package com.tencent.map.geolocation.tencent_location_flutter_plugin.event;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;

/**
 * 统一管理 3 条 EventChannel：
 *
 * <ul>
 *   <li>{@link #LOCATION_CHANNEL_NAME}：定位结果 / 定位错误，按 {@code managerId} 路由</li>
 *   <li>{@link #GEOFENCE_CHANNEL_NAME}：围栏事件 / 围栏错误，按 {@code geofenceManagerId} 路由</li>
 *   <li>{@link #STATUS_CHANNEL_NAME}：SDK 日志 / 设备状态 / 朝向，按 {@code managerId} 路由（SDK 日志不带）</li>
 * </ul>
 *
 * <p><b>事件缓冲</b>：Dart 未订阅期间产生的事件直接丢弃；订阅后才转发。与
 * Flutter {@code StreamController.broadcast()} 语义一致。</p>
 */
public class EventDispatcher {

    public static final String LOCATION_CHANNEL_NAME =
            "com.tencent.map.geolocation.flutter/event/location";
    public static final String GEOFENCE_CHANNEL_NAME =
            "com.tencent.map.geolocation.flutter/event/geofence";
    public static final String STATUS_CHANNEL_NAME =
            "com.tencent.map.geolocation.flutter/event/status";

    private final EventChannel locationChannel;
    private final EventChannel geofenceChannel;
    private final EventChannel statusChannel;

    private final Sink locationSink = new Sink();
    private final Sink geofenceSink = new Sink();
    private final Sink statusSink = new Sink();

    /** 主线程 handler，EventSink 必须在主线程回调。 */
    private final Handler uiHandler = new Handler(Looper.getMainLooper());

    public EventDispatcher(@NonNull BinaryMessenger messenger) {
        locationChannel = new EventChannel(messenger, LOCATION_CHANNEL_NAME);
        geofenceChannel = new EventChannel(messenger, GEOFENCE_CHANNEL_NAME);
        statusChannel = new EventChannel(messenger, STATUS_CHANNEL_NAME);

        locationChannel.setStreamHandler(locationSink);
        geofenceChannel.setStreamHandler(geofenceSink);
        statusChannel.setStreamHandler(statusSink);
    }

    /** detach 时调用，清理 handler。 */
    public void dispose() {
        locationChannel.setStreamHandler(null);
        geofenceChannel.setStreamHandler(null);
        statusChannel.setStreamHandler(null);
        locationSink.clear();
        geofenceSink.clear();
        statusSink.clear();
    }

    // ---------- 发送 ----------

    /** 发送到 location channel，带 managerId 路由。 */
    public void sendLocation(@NonNull String event,
                             @Nullable String managerId,
                             @Nullable Object payload) {
        locationSink.send(buildEvent(event, managerId, null, payload));
    }

    /** 发送到 geofence channel，带 geofenceManagerId 路由。 */
    public void sendGeofence(@NonNull String event,
                             @Nullable String geofenceManagerId,
                             @Nullable Object payload) {
        geofenceSink.send(buildEvent(event, null, geofenceManagerId, payload));
    }

    /** 发送到 status channel，带 managerId 路由。 */
    public void sendStatus(@NonNull String event,
                           @Nullable String managerId,
                           @Nullable Object payload) {
        statusSink.send(buildEvent(event, managerId, null, payload));
    }

    @NonNull
    private Map<String, Object> buildEvent(@NonNull String event,
                                           @Nullable String managerId,
                                           @Nullable String geofenceManagerId,
                                           @Nullable Object payload) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("event", event);
        if (managerId != null) map.put("managerId", managerId);
        if (geofenceManagerId != null) map.put("geofenceManagerId", geofenceManagerId);
        if (payload != null) map.put("payload", payload);
        return map;
    }

    // ---------- 内部 sink ----------

    private class Sink implements EventChannel.StreamHandler {
        private final CopyOnWriteArrayList<EventChannel.EventSink> sinks =
                new CopyOnWriteArrayList<>();

        @Override
        public void onListen(Object arguments, EventChannel.EventSink events) {
            sinks.add(events);
        }

        @Override
        public void onCancel(Object arguments) {
            // Flutter 侧的 broadcast stream 一般全程只取消一次。
            // 这里直接清空所有 sink（没法区分是哪一个 sink）。
            sinks.clear();
        }

        void send(@NonNull Object data) {
            if (sinks.isEmpty()) return;
            uiHandler.post(() -> {
                for (EventChannel.EventSink sink : sinks) {
                    try {
                        sink.success(data);
                    } catch (Exception e) {
                        // 防御：若 sink 已 close 就忽略
                    
            android.util.Log.e("EventDispatcher", "Exception ignored", e);
        }
                }
            });
        }

        void clear() {
            sinks.clear();
        }
    }
}
