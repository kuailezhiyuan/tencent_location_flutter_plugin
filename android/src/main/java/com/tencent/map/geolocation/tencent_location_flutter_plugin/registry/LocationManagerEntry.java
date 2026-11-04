package com.tencent.map.geolocation.tencent_location_flutter_plugin.registry;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.tencent.map.geolocation.TencentLocation;
import com.tencent.map.geolocation.TencentLocationListener;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.codec.LocationCodec;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.event.EventDispatcher;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 一个 Flutter 端 {@code TencentLocationManager} 实例在 Android 端的落地。
 *
 * <p>持有独立的 <b>连续定位 listener</b>，所有连续定位回调通过 {@link EventDispatcher}
 * 以 {@code managerId} 路由回 Flutter。Android 原生 SDK 的
 * {@code TencentLocationManager.getInstance} 在进程内是单例，但 listener
 * 粒度完全独立，多个 entry 互不干扰。</p>
 *
 * <p><b>单次定位</b>不复用本 entry 的连续 listener，而是由 handler 在调用时
 * 构造一次性 listener（见 {@link #createSingleListener(SingleResultSink)}）。
 * 这样可以规避原生 SDK 的两个底层风险：</p>
 * <ul>
 *   <li>原生 SDK 内部以"连续 listener 列表"和"单次 listener 列表"两份独立列表分发回调，
 *   只通过 listener 接口无法区分本次回调属于哪条流，复用同一个 listener
 *   会导致单次等待期间到达的连续帧被错误地填进 single waiter；</li>
 *   <li>单次定位完成后原生 SDK 会调用 {@code removeUpdates(listener)}，
 *   该方法会同时把 listener 从连续列表里摘掉，副作用会让连续定位被静默停止。</li>
 * </ul>
 */
public class LocationManagerEntry {

    private final String managerId;
    private final EventDispatcher dispatcher;

    /** 是否正在进行连续定位（用于 start/stop 幂等）。 */
    private boolean continuousRunning = false;

    /** 是否向 Dart 转发当前 manager 的设备状态回调。 */
    private volatile boolean statusForwardingEnabled = false;

    private final TencentLocationListener listener = new TencentLocationListener() {
        @Override
        public void onLocationChanged(TencentLocation location, int error, String reason) {
            // 该 listener 仅承担连续定位回调；单次定位走独立的一次性 listener。
            if (error == TencentLocation.ERROR_OK && location != null) {
                dispatcher.sendLocation("onLocationChanged", managerId,
                        LocationCodec.toMap(location));
            } else {
                Map<String, Object> errMap = new LinkedHashMap<>();
                errMap.put("code", "locationFailed");
                errMap.put("message", reason == null ? "" : reason);
                errMap.put("nativeCode", error);
                errMap.put("nativeMessage", reason);
                dispatcher.sendLocation("onLocationError", managerId, errMap);
            }
        }

        @Override
        public void onStatusUpdate(String name, int status, String desc) {
            if (!statusForwardingEnabled) return;
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("kind", kindToWire(name, status));
            payload.put("status", statusToWire(status));
            payload.put("description", desc);
            dispatcher.sendStatus("onStatusChanged", managerId, payload);
        }
    };

    public LocationManagerEntry(@NonNull String managerId,
                                @NonNull EventDispatcher dispatcher) {
        this.managerId = managerId;
        this.dispatcher = dispatcher;
    }

    @NonNull
    public String getManagerId() {
        return managerId;
    }

    /** 连续定位的 listener；不要用于单次定位。 */
    @NonNull
    public TencentLocationListener getListener() {
        return listener;
    }

    public boolean isContinuousRunning() {
        return continuousRunning;
    }

    public void markContinuous(boolean running) {
        continuousRunning = running;
    }

    /**
     * 设置当前 manager 是否需要向 Dart 转发设备状态。
     *
     * Android SDK 的状态回调是连续定位 listener 的附属事件，不额外启动原生能力；
     * 这里仅按业务 stream 订阅状态过滤转发。
     */
    public void setStatusForwardingEnabled(boolean enabled) {
        statusForwardingEnabled = enabled;
    }

    // ---------- 单次定位：一次性 listener ----------

    /**
     * 构造一个仅用于单次定位的一次性 {@link TencentLocationListener}。
     *
     * <p>该 listener 与 entry 的连续 listener 完全独立，原生 SDK 在单次回调后
     * 会自行 {@code removeUpdates}，不会影响连续 listener。</p>
     */
    @NonNull
    public static TencentLocationListener createSingleListener(@NonNull SingleResultSink sink) {
        return new TencentLocationListener() {
            @Override
            public void onLocationChanged(TencentLocation location, int error, String reason) {
                sink.onResult(location, error, reason);
            }

            @Override
            public void onStatusUpdate(String name, int status, String desc) {
                // 单次定位过程中的 status 不需要透传给 Flutter（连续 listener 已承担）
            }
        };
    }

    /** 单次定位结果回调（一次性）。 */
    public interface SingleResultSink {
        void onResult(@Nullable TencentLocation location, int error, @Nullable String reason);
    }

    // ---------- 工具 ----------

    @NonNull
    private static String kindToWire(@Nullable String name, int status) {
        if (TencentLocationListener.GPS.equals(name)) return "gps";
        if (TencentLocationListener.WIFI.equals(name)) return "wifi";
        if (TencentLocationListener.CELL.equals(name)) return "cellular";
        if (TencentLocationListener.RADIO.equals(name)) return "cellular";
        if (status == TencentLocationListener.STATUS_LOCATION_SWITCH_OFF) {
            return "locationSwitch";
        }
        return "gps";
    }

    @NonNull
    private static String statusToWire(int status) {
        switch (status) {
            case TencentLocationListener.STATUS_ENABLED:
            case TencentLocationListener.STATUS_GPS_AVAILABLE:
                return "available";
            case TencentLocationListener.STATUS_GPS_UNAVAILABLE:
                return "enabledButUnavailable";
            case TencentLocationListener.STATUS_DISABLED:
            case TencentLocationListener.STATUS_LOCATION_SWITCH_OFF:
                return "disabled";
            case TencentLocationListener.STATUS_DENIED:
                return "denied";
            case TencentLocationListener.STATUS_UNKNOWN:
            default:
                return "unknown";
        }
    }
}
