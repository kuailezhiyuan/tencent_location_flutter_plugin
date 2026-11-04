package com.tencent.map.geolocation.tencent_location_flutter_plugin.handler;

import android.Manifest;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import com.tencent.map.geolocation.TencentLocation;
import com.tencent.map.geolocation.TencentLocationListener;
import com.tencent.map.geolocation.TencentLocationManager;
import com.tencent.map.geolocation.TencentLocationRequest;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.codec.LocationCodec;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.codec.RequestCodec;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.event.EventDispatcher;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.registry.LocationManagerEntry;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.registry.LocationManagerRegistry;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.util.Errors;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * 处理 {@code manager.*} / {@code location.*} / {@code stream.*} method。
 */
public class LocationHandler {

    // The SDK foreground service is process-wide. Method calls run on the main looper.
    private static final Set<LocationManagerEntry> FOREGROUND_OWNERS = new HashSet<>();

    private final Context appContext;
    private final EventDispatcher dispatcher;
    private final LocationManagerRegistry registry;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Set<SingleLocation> singleLocations = new HashSet<>();

    /** 用每个 managerId 启动定位时选择的 scene（null = 非场景化）。 */
    private final Map<String, Integer> sceneByManager = new HashMap<>();

    public LocationHandler(@NonNull Context appContext,
                           @NonNull EventDispatcher dispatcher,
                           @NonNull LocationManagerRegistry registry) {
        this.appContext = appContext;
        this.dispatcher = dispatcher;
        this.registry = registry;
    }

    public boolean handle(@NonNull MethodCall call, @NonNull Result result) {
        String method = call.method;

        // manager.*
        switch (method) {
            case "manager.create": {
                String managerId = call.argument("managerId");
                if (managerId == null) {
                    Errors.invalidArgument(result, "managerId must be non-null");
                    return true;
                }
                registry.getOrCreate(managerId,
                        id -> new LocationManagerEntry(id, dispatcher));
                result.success(null);
                return true;
            }
            case "manager.dispose": {
                String managerId = call.argument("managerId");
                if (managerId == null) {
                    Errors.invalidArgument(result, "managerId must be non-null");
                    return true;
                }
                disposeManager(managerId);
                result.success(null);
                return true;
            }
            default:
                // fall through
        }

        // 其他 location.* / stream.* 都需要 managerId。
        if (!method.startsWith("location.") && !method.startsWith("stream.")) return false;

        String managerId = call.argument("managerId");
        if (managerId == null) {
            Errors.invalidArgument(result, "managerId must be non-null");
            return true;
        }
        LocationManagerEntry entry = registry.get(managerId);
        if (entry == null) {
            Errors.code(result, Errors.NATIVE_ERROR,
                    "Location manager not found: " + managerId, null);
            return true;
        }

        switch (method) {
            case "stream.status.start":
                entry.setStatusForwardingEnabled(true);
                result.success(null);
                return true;
            case "stream.status.stop":
                entry.setStatusForwardingEnabled(false);
                result.success(null);
                return true;
            case "stream.orientation.start":
            case "stream.orientation.stop":
                // Android 原生 SDK 不提供设备朝向能力；保持订阅成功但静默。
                result.success(null);
                return true;

            case "location.startContinuous":
                handleStartContinuous(call, result, entry);
                return true;
            case "location.stopContinuous":
                handleStopContinuous(result, entry);
                return true;
            case "location.startSingle":
                handleStartSingle(call, result, entry);
                return true;

            case "location.getLastLocation":
                handleGetLastLocation(result, entry);
                return true;

            case "location.changeCallbackInterval": {
                Number intervalMs = call.argument("intervalMs");
                if (intervalMs == null) {
                    Errors.invalidArgument(result, "intervalMs required");
                    return true;
                }
                try {
                    TencentLocationManager.getInstance(appContext).changeCallbackInterval(intervalMs.longValue());
                    result.success(null);
                } catch (Exception t) {
                    Errors.native_(result, "changeCallbackInterval failed: " + t, t);
                }
                return true;
            }

            case "location.android.enableForeground":
                handleEnableForeground(call, result, entry);
                return true;
            case "location.android.disableForeground": {
                Boolean removeNotification = call.argument("removeNotification");
                try {
                    disableForeground(entry, removeNotification == null || removeNotification);
                    result.success(null);
                } catch (Exception t) {
                    Errors.native_(result, "disableForeground failed: " + t, t);
                }
                return true;
            }

            // iOS / Harmony 独有能力，Android 端一律抛不支持
            case "location.ios.dismissHeadingCalibrationDisplay":
            case "location.ios.setExtraData":
            case "location.harmony.startBackgroundTask":
            case "location.harmony.stopBackgroundTask":
                Errors.unsupported(result, method);
                return true;

            default:
                return false;
        }
    }

    // ---------- 生命周期 ----------

    public void disposeAll() {
        for (LocationManagerEntry entry : registry.all()) {
            disposeManagerInternal(entry);
        }
        registry.clear();
        sceneByManager.clear();
    }

    private void disposeManager(@NonNull String managerId) {
        LocationManagerEntry entry = registry.remove(managerId);
        if (entry == null) return;
        disposeManagerInternal(entry);
    }

    private void disposeManagerInternal(@NonNull LocationManagerEntry entry) {
        for (SingleLocation pending : new ArrayList<>(singleLocations)) {
            if (pending.entry == entry) {
                pending.cancel(Errors.LOCATION_FAILED, "Location manager was disposed");
            }
        }
        try {
            disableForeground(entry, true);
        } catch (Exception e) {
            Log.e("LocationHandler", "Failed to disable foreground location for " + entry.getManagerId(), e);
            FOREGROUND_OWNERS.remove(entry);
        }
        Integer scene = sceneByManager.remove(entry.getManagerId());
        try {
            if (scene != null) {
                TencentLocationManager.getInstance(appContext).stopLocationWithScene(scene, entry.getListener());
            } else {
                TencentLocationManager.getInstance(appContext).removeUpdates(entry.getListener());
            }
        } catch (Exception e) {
            Log.e("LocationHandler", "Failed to stop continuous location for " + entry.getManagerId(), e);
        }
        try {
            TencentLocationManager.getInstance(appContext).removeLocationListener(entry.getListener());
        } catch (Exception e) {
            Log.e("LocationHandler", "Failed to remove location listener for " + entry.getManagerId(), e);
        }
        // 显式重置内部连续定位标志，让 entry 在被回收前状态干净；
        // 万一 entry 被外部引用 / 单测复用时不会读到陈旧的 true。
        entry.markContinuous(false);
    }

    // ---------- 连续定位 ----------

    private void handleStartContinuous(@NonNull MethodCall call,
                                       @NonNull Result result,
                                       @NonNull LocationManagerEntry entry) {
        Map<?, ?> requestMap = call.argument("request");
        if (requestMap == null) {
            Errors.invalidArgument(result, "request must be non-null");
            return;
        }
        try {
            applyGlobalCoordinateType(requestMap);
            TencentLocationRequest request = RequestCodec.fromMap(requestMap);
            Integer scene = RequestCodec.sceneFromMap(requestMap);

            int ret;
            if (scene != null) {
                ret = TencentLocationManager.getInstance(appContext).requestLocationWithScene(scene, entry.getListener());
                sceneByManager.put(entry.getManagerId(), scene);
            } else {
                ret = TencentLocationManager.getInstance(appContext).requestLocationUpdates(
                        request, entry.getListener(), Looper.getMainLooper());
                sceneByManager.remove(entry.getManagerId());
            }

            if (ret != 0) {
                Errors.code(result, mapRetToErrorCode(ret),
                        "requestLocationUpdates returned " + ret, ret);
                return;
            }
            entry.markContinuous(true);
            result.success(null);
        } catch (Exception t) {
            Errors.native_(result, "startContinuous failed: " + t, t);
        }
    }

    private void handleStopContinuous(@NonNull Result result,
                                      @NonNull LocationManagerEntry entry) {
        try {
            Integer scene = sceneByManager.remove(entry.getManagerId());
            if (scene != null) {
                TencentLocationManager.getInstance(appContext).stopLocationWithScene(scene, entry.getListener());
            } else {
                TencentLocationManager.getInstance(appContext).removeUpdates(entry.getListener());
            }
            entry.markContinuous(false);
            result.success(null);
        } catch (Exception t) {
            Errors.native_(result, "stopContinuous failed: " + t, t);
        }
    }

    // ---------- 单次定位 ----------

    /**
     * 单次定位使用<b>独立的一次性 listener</b>，与 entry 持有的连续 listener 完全隔离。
     *
     * <p>原生 SDK 内部维护两份独立的 listener 列表（连续 / 单次），并通过
     * {@code msg_id} 区分回调路径；但 {@link TencentLocationListener#onLocationChanged}
     * 接口未暴露 msg_id，复用同一个 listener 时无法判定本次回调属于哪条流。
     * 此外原生 SDK 单次回调后会调用 {@code removeUpdates(listener)}，会同时把
     * listener 从连续列表里摘掉。两点叠加意味着复用 listener 在 entry 既订阅了
     * 连续定位、又触发单次定位时，会出现"连续帧错填进 single waiter"以及
     * "连续定位被静默停止"的问题，因此采用独立 listener 处理单次定位。</p>
     */
    private void handleStartSingle(@NonNull MethodCall call,
                                   @NonNull Result result,
                                   @NonNull LocationManagerEntry entry) {
        Map<?, ?> requestMap = call.argument("request");
        if (requestMap == null) {
            Errors.invalidArgument(result, "request must be non-null");
            return;
        }
        TencentLocationRequest request;
        long timeoutMs;
        try {
            applyGlobalCoordinateType(requestMap);
            request = RequestCodec.fromMap(requestMap);
            // Android 原生 SDK 的单次定位超时由 setLocFirstTimeOut(long) 兜底，
            // 这里读取 android.firstLocationTimeoutMs 作为 latch 的等待上限，
            // 与 RequestCodec 中应用到原生 request 的字段一致。
            Map<?, ?> android = (Map<?, ?>) requestMap.get("android");
            timeoutMs = android != null && android.get("firstLocationTimeoutMs") instanceof Number
                    ? ((Number) android.get("firstLocationTimeoutMs")).longValue()
                    : 15_000L;
        } catch (Exception t) {
            Errors.invalidArgument(result, "invalid request: " + t);
            return;
        }

        SingleLocation pending = new SingleLocation(entry, result);
        singleLocations.add(pending);
        mainHandler.postDelayed(pending.timeout, timeoutMs);
        try {
            int ret = TencentLocationManager.getInstance(appContext).requestSingleFreshLocation(
                    request, pending.listener, Looper.getMainLooper());
            if (ret != 0 && pending.finish()) {
                Errors.code(result, mapRetToErrorCode(ret),
                        "requestSingleFreshLocation returned " + ret, ret);
            }
        } catch (Exception e) {
            if (pending.finish()) {
                pending.removeListener();
                Errors.native_(result, "Failed to request single location", e);
            } else {
                Log.e("LocationHandler", "Single location request failed after completion", e);
            }
        }
    }

    private final class SingleLocation {
        final LocationManagerEntry entry;
        final Result result;
        final TencentLocationListener listener = LocationManagerEntry.createSingleListener(this::onLocation);
        final Runnable timeout = () -> cancel(Errors.TIMEOUT, "Single location timed out");

        SingleLocation(LocationManagerEntry entry, Result result) {
            this.entry = entry;
            this.result = result;
        }

        private boolean finish() {
            if (!singleLocations.remove(this)) return false;
            mainHandler.removeCallbacks(timeout);
            return true;
        }

        private void onLocation(TencentLocation location, int error, String reason) {
            if (!finish()) return;
            if (error != TencentLocation.ERROR_OK || location == null) {
                Errors.code(result, Errors.LOCATION_FAILED,
                        "Single location failed: " + (reason == null ? "" : reason), error);
                return;
            }
            Map<String, Object> data;
            try {
                data = LocationCodec.toMap(location);
            } catch (Exception e) {
                Errors.native_(result, "Failed to encode single location", e);
                return;
            }
            result.success(data);
        }

        private void cancel(String code, String message) {
            if (!finish()) return;
            removeListener();
            Errors.code(result, code, message, null);
        }

        private void removeListener() {
            try {
                TencentLocationManager.getInstance(appContext).removeUpdates(listener);
            } catch (Exception e) {
                Log.e("LocationHandler", "Failed to remove single location listener for " + entry.getManagerId(), e);
            }
        }
    }

    // ---------- 最近位置 ----------

    private void handleGetLastLocation(@NonNull Result result,
                                       @NonNull LocationManagerEntry entry) {
        try {
            TencentLocation last = TencentLocationManager.getInstance(appContext).getLastKnownLocation();
            if (last == null) {
                result.success(null);
            } else {
                result.success(LocationCodec.toMap(last));
            }
        } catch (Exception t) {
            Errors.native_(result, "getLastLocation failed: " + t, t);
        }
    }

    // ---------- 前台服务 ----------

    private void handleEnableForeground(@NonNull MethodCall call,
                                        @NonNull Result result,
                                        @NonNull LocationManagerEntry entry) {
        Integer notificationId = call.argument("notificationId");
        String channelId = call.argument("channelId");
        String title = call.argument("title");
        String text = call.argument("text");
        String smallIconResourceName = call.argument("smallIconResourceName");

        if (notificationId == null || notificationId <= 0 || channelId == null || channelId.isEmpty()
                || title == null || text == null) {
            Errors.invalidArgument(result,
                    "notificationId(>0), channelId, title, text are required");
            return;
        }
        if (!TencentLocationManager.getUserAgreePrivacy()) {
            Errors.code(result, Errors.PRIVACY_NOT_AGREED, "Location privacy policy has not been accepted", null);
            return;
        }
        if (ContextCompat.checkSelfPermission(appContext, Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED
                && ContextCompat.checkSelfPermission(appContext, Manifest.permission.ACCESS_COARSE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            Errors.code(result, Errors.PERMISSION_DENIED, "Foreground location requires location permission", null);
            return;
        }
        try {
            if (FOREGROUND_OWNERS.isEmpty()) {
                ensureNotificationChannel(channelId);
                int icon = resolveDrawable(smallIconResourceName);
                if (icon == 0) icon = appContext.getApplicationInfo().icon;
                TencentLocationManager.getInstance(appContext).enableForegroundLocation(notificationId,
                        new NotificationCompat.Builder(appContext, channelId)
                                .setContentTitle(title)
                                .setContentText(text)
                                .setOngoing(true)
                                .setPriority(NotificationCompat.PRIORITY_LOW)
                                .setSmallIcon(icon != 0 ? icon : android.R.drawable.ic_menu_mylocation)
                                .build());
            }
            FOREGROUND_OWNERS.add(entry);
            result.success(null);
        } catch (Exception t) {
            Errors.native_(result, "enableForeground failed: " + t, t);
        }
    }

    private void disableForeground(LocationManagerEntry entry, boolean removeNotification) {
        if (!FOREGROUND_OWNERS.contains(entry)) return;
        if (FOREGROUND_OWNERS.size() == 1) {
            TencentLocationManager.getInstance(appContext).disableForegroundLocation(removeNotification);
        }
        FOREGROUND_OWNERS.remove(entry);
    }

    private void ensureNotificationChannel(@NonNull String channelId) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager nm =
                (NotificationManager) appContext.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;
        if (nm.getNotificationChannel(channelId) != null) return;
        NotificationChannel channel = new NotificationChannel(
                channelId, "Tencent Location Service", NotificationManager.IMPORTANCE_LOW);
        channel.setDescription("Tencent Location Flutter plugin foreground service");
        nm.createNotificationChannel(channel);
    }

    private int resolveDrawable(@Nullable String name) {
        if (name == null || name.isEmpty()) return 0;
        int id = appContext.getResources()
                .getIdentifier(name, "mipmap", appContext.getPackageName());
        if (id != 0) return id;
        return appContext.getResources()
                .getIdentifier(name, "drawable", appContext.getPackageName());
    }

    // ---------- helpers ----------

    /**
     * 把 request 自带的坐标系 apply 到 Android 进程级。
     *
     * <p><b>注意：进程级共享，最后一次写入生效。</b>
     * Android 原生 SDK 的 {@link TencentLocationManager#setCoordinateType(int)} 是<b>进程级</b>
     * 设置（SDK 单例的全局属性），所有 manager 实例共享同一个值；同一进程里如果有多个 Flutter
     * {@code TencentLocationManager} / {@code TencentGeofenceManager} 实例使用不同的坐标系，
     * 后启动 / 后变更的那个会覆盖前一个，<b>不存在 per-instance 隔离</b>。
     *
     * <p>{@link com.tencent.map.geolocation.tencent_location_flutter_plugin.handler.GeofenceHandler}
     * 中也有同名 helper，行为完全一致；定位与围栏共用同一全局坐标系。多 manager 混用场景下，
     * 调用方应保持各 request / fence 的 {@code coordinateType} 一致，避免跨实例相互影响。
     */
    private void applyGlobalCoordinateType(@NonNull Map<?, ?> requestMap) {
        String wire = RequestCodec.coordinateTypeFromMap(requestMap);
        if (wire == null) return;
        int coord = RequestCodec.coordinateTypeFromWire(wire);
        try {
            if (TencentLocationManager.getInstance(appContext).getCoordinateType() != coord) {
                TencentLocationManager.getInstance(appContext).setCoordinateType(coord);
            }
        } catch (Exception e) {
            Log.e("LocationHandler", "Failed to set Tencent location coordinate type to " + wire, e);
        }
    }

    @NonNull
    private String mapRetToErrorCode(int ret) {
        // 详见 TencentLocationManager 的 requestLocationUpdates 返回值（参考 SDK 文档）
        // 1=permission, 2=apiKey invalid, 3=so load failed, 4=privacy not agreed
        switch (ret) {
            case 1:
                return Errors.PERMISSION_DENIED;
            case 2:
                return Errors.API_KEY_INVALID;
            case 3:
                return Errors.SDK_INIT_FAILED;
            case 4:
                return Errors.PRIVACY_NOT_AGREED;
            case 5:
                return Errors.LOCATION_SWITCH_OFF;
            default:
                return Errors.LOCATION_FAILED;
        }
    }

}
