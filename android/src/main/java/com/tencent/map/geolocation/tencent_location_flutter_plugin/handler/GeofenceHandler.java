package com.tencent.map.geolocation.tencent_location_flutter_plugin.handler;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.tencent.map.geolocation.TencentGeofence;
import com.tencent.map.geolocation.TencentLocationManager;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.codec.GeofenceCodec;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.codec.RequestCodec;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.event.EventDispatcher;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.registry.GeofenceManagerEntry;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.registry.GeofenceManagerRegistry;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.util.Errors;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel.Result;

/** 处理 {@code geofence.*} method。 */
public class GeofenceHandler {

    private static final String TAG = "TencentLocation";

    private final Context appContext;
    private final EventDispatcher dispatcher;
    private final GeofenceManagerRegistry registry;

    public GeofenceHandler(@NonNull Context appContext,
                           @NonNull EventDispatcher dispatcher,
                           @NonNull GeofenceManagerRegistry registry) {
        this.appContext = appContext;
        this.dispatcher = dispatcher;
        this.registry = registry;
    }

    public boolean handle(@NonNull MethodCall call, @NonNull Result result) {
        String method = call.method;
        if (!method.startsWith("geofence.")) return false;

        if ("geofence.managerCreate".equals(method)) {
            String id = call.argument("geofenceManagerId");
            if (id == null) {
                Errors.invalidArgument(result, "geofenceManagerId must be non-null");
                return true;
            }
            registry.getOrCreate(id,
                    gid -> new GeofenceManagerEntry(gid, appContext, dispatcher));
            result.success(null);
            return true;
        }

        if ("geofence.managerDispose".equals(method)) {
            String id = call.argument("geofenceManagerId");
            if (id == null) {
                Errors.invalidArgument(result, "geofenceManagerId must be non-null");
                return true;
            }
            GeofenceManagerEntry entry = registry.remove(id);
            if (entry != null) entry.dispose();
            result.success(null);
            return true;
        }

        // 其余方法都需要 geofenceManagerId
        String geofenceManagerId = call.argument("geofenceManagerId");
        if (geofenceManagerId == null) {
            Errors.invalidArgument(result, "geofenceManagerId must be non-null");
            return true;
        }
        GeofenceManagerEntry entry = registry.get(geofenceManagerId);
        if (entry == null) {
            Errors.code(result, Errors.NATIVE_ERROR,
                    "Geofence manager not found: " + geofenceManagerId, null);
            return true;
        }

        switch (method) {
            case "geofence.add":
                handleAdd(call, result, entry);
                return true;
            case "geofence.remove": {
                String id = call.argument("id");
                if (id == null) {
                    Errors.invalidArgument(result, "id must be non-null");
                    return true;
                }
                try {
                    entry.removeFenceByTag(id);
                    result.success(null);
                } catch (Exception t) {
                    Errors.native_(result, "removeGeofence failed: " + t, t);
                }
                return true;
            }
            case "geofence.removeAll":
                try {
                    entry.removeAllFences();
                    result.success(null);
                } catch (Exception t) {
                    Errors.native_(result, "removeAllGeofences failed: " + t, t);
                }
                return true;

            case "geofence.getAll":
                try {
                    List<TencentGeofence> fences = entry.getManager().getValidFences();
                    List<Map<String, Object>> encoded = new ArrayList<>();
                    if (fences != null) {
                        for (TencentGeofence f : fences) encoded.add(GeofenceCodec.toMap(f));
                    }
                    result.success(encoded);
                } catch (Exception t) {
                    Errors.native_(result, "getAllGeofences failed: " + t, t);
                }
                return true;

            // iOS 独有能力，Android 端一律抛不支持
            case "geofence.isCoordinateInside":
            case "geofence.regionsContaining":
            case "geofence.ios.startMonitoring":
            case "geofence.ios.stopMonitoring":
            case "geofence.ios.pauseMonitoring":
            case "geofence.ios.resumeMonitoring":
            case "geofence.ios.isMonitoring":
            case "geofence.ios.setAllowsBackgroundLocationUpdates":
            case "geofence.ios.setAdaptiveDistanceFilterEnabled":
            case "geofence.ios.setDistanceFilter":
            case "geofence.ios.setDesiredAccuracy":
            case "geofence.ios.setDetectionInterval":
                Errors.unsupported(result, method);
                return true;

            default:
                return false;
        }
    }

    private void handleAdd(@NonNull MethodCall call,
                           @NonNull Result result,
                           @NonNull GeofenceManagerEntry entry) {
        Map<?, ?> fenceMap = call.argument("geofence");
        if (fenceMap == null) {
            Errors.invalidArgument(result, "geofence must be non-null");
            return;
        }

        // Android 原生固定每 10 分钟回调一次 dwell 事件且不可配置，与跨端
        // 抽象的 dwell（可指定阈值）语义不完全一致。这里仅打印 warning，
        // 不阻止 add：原生 enter / exit 事件依旧正常上报。
        Set<String> transitions =
                GeofenceCodec.parseMonitorTransitions(fenceMap.get("monitorTransitions"));
        if (transitions.contains("dwell")) {
            Log.w(TAG, "geofence.monitorTransitions contains 'dwell',"
                    + " which is not configurable on Android"
                    + " (native dwell fires every 10 minutes by default);"
                    + " falling back to enter + exit only.");
        }

        try {
            applyGlobalCoordinateType(fenceMap);
            TencentGeofence fence = GeofenceCodec.fromMap(fenceMap);
            entry.addFence(fence);
            result.success(null);
        } catch (IllegalArgumentException iae) {
            Errors.code(result, Errors.GEOFENCE_INVALID_REGION,
                    "addGeofence invalid region: " + iae.getMessage(), null);
        } catch (Exception t) {
            Errors.native_(result, "addGeofence failed: " + t, t);
        }
    }

    /**
     * 把围栏自带的坐标系 apply 到 Android 进程级。
     *
     * <p><b>注意：进程级共享，最后一次写入生效。</b>
     * Android 7.6.1.8 SDK 的 {@code TencentGeofence.Builder} 没有
     * {@code setCoordinateType}；围栏坐标系受
     * {@link TencentLocationManager#setCoordinateType(int)} <b>进程级</b>控制，
     * 与定位 ({@link com.tencent.map.geolocation.tencent_location_flutter_plugin.handler.LocationHandler})
     * 共用同一个全局坐标系；同一进程里多个 manager / 围栏实例互相覆盖，
     * <b>不存在 per-instance 隔离</b>。多实例混用场景下，调用方应保持各 fence / request 的
     * {@code coordinateType} 一致，避免跨实例相互影响。</p>
     */
    private void applyGlobalCoordinateType(@NonNull Map<?, ?> fenceMap) {
        String wire = GeofenceCodec.coordinateTypeFromMap(fenceMap);
        if (wire == null) return;
        int coord = RequestCodec.coordinateTypeFromWire(wire);
        try {
            TencentLocationManager mgr = TencentLocationManager.getInstance(appContext);
            if (mgr.getCoordinateType() != coord) {
                mgr.setCoordinateType(coord);
            }
        } catch (Exception e) {
            android.util.Log.e("GeofenceHandler", "Exception ignored", e);
        }
    }

    public void disposeAll() {
        for (GeofenceManagerEntry e : registry.all()) e.dispose();
        registry.clear();
    }
}
