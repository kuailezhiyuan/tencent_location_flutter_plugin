package com.tencent.map.geolocation.tencent_location_flutter_plugin.registry;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.location.LocationManager;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.tencent.map.geolocation.TencentGeofence;
import com.tencent.map.geolocation.TencentGeofenceManager;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.event.EventDispatcher;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * 一个 Flutter 端 {@code TencentGeofenceManager} 实例在 Android 端的落地。
 *
 * <p>每个 entry 持有：</p>
 * <ul>
 *   <li>一个独立的 {@link TencentGeofenceManager}</li>
 *   <li>一个动态注册的 {@link BroadcastReceiver}（action = 本 entry 的 UUID）</li>
 *   <li>每个 fence 对应一个独立 {@link PendingIntent}，并在 base Intent 的
 *       {@code KEY_GEOFENCE_ID} extra 中携带 fence 标识，用于在回调里识别围栏</li>
 * </ul>
 */
public class GeofenceManagerEntry {

    /** 回调 Intent 的 extra key：fence 标识。 */
    public static final String KEY_GEOFENCE_ID = "KEY_GEOFENCE_ID";

    private final String geofenceManagerId;
    private final Context appContext;
    private final EventDispatcher dispatcher;
    private final String action;
    private final BroadcastReceiver receiver;
    private final TencentGeofenceManager manager;

    /** fence tag → 对应的 PendingIntent。用于 dispose 时统一 cancel。 */
    private final Map<String, PendingIntent> pendingIntents = new HashMap<>();

    /** 已提交的 district 围栏 tag。district 为异步创建，成功广播到达时据此透传事件。 */
    private final Set<String> districtTags = new HashSet<>();

    public GeofenceManagerEntry(@NonNull String geofenceManagerId,
                                @NonNull Context appContext,
                                @NonNull EventDispatcher dispatcher) {
        this.geofenceManagerId = geofenceManagerId;
        this.appContext = appContext;
        this.dispatcher = dispatcher;
        this.action =
                "com.tencent.map.geolocation.flutter.GEOFENCE." + UUID.randomUUID();

        this.manager = new TencentGeofenceManager(appContext);

        this.receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                handleReceive(intent);
            }
        };

        IntentFilter filter = new IntentFilter(action);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            appContext.registerReceiver(receiver, filter);
        }
    }

    @NonNull
    public String getGeofenceManagerId() {
        return geofenceManagerId;
    }

    @NonNull
    public TencentGeofenceManager getManager() {
        return manager;
    }

    /**
     * 添加围栏并为其分配独立 PendingIntent，PendingIntent 的 base Intent 里
     * 以 {@link #KEY_GEOFENCE_ID} 携带 fence tag，后续回调据此识别。
     *
     * <p><b>district（行政区）围栏是异步提交的</b>：SDK 对行政区围栏先发起
     * 网络请求，成功回调后才真正加入围栏列表；失败时只通过 PendingIntent
     * 广播错误。因此本方法返回不代表围栏已生效——调用方应通过
     * {@code onGeofenceError} 事件流感知异步失败（circle / polygon 为同步
     * 提交，不受此影响）。</p>
     */
    public void addFence(@NonNull TencentGeofence fence) {
        String tag = fence.getTag();
        PendingIntent pi = buildPendingIntent(tag);
        synchronized (pendingIntents) {
            PendingIntent old = pendingIntents.put(tag, pi);
            if (old != null) old.cancel();
        }
        if (fence.getType() == TencentGeofence.GEOFENCE_TYPE_DISTRICT) {
            synchronized (districtTags) {
                districtTags.add(tag);
            }
        }
        manager.addFence(fence, pi);
    }

    /** 按 tag 移除围栏并释放对应 PendingIntent。 */
    public void removeFenceByTag(@NonNull String tag) {
        manager.removeFence(tag);
        synchronized (pendingIntents) {
            PendingIntent pi = pendingIntents.remove(tag);
            if (pi != null) pi.cancel();
        }
    }

    /** 移除本 entry 上的所有围栏并释放全部 PendingIntent。 */
    public void removeAllFences() {
        manager.removeAllFences();
        cancelAllPendingIntents();
    }

    public void dispose() {
        try {
            manager.removeAllFences();
        } catch (Exception e) {
            android.util.Log.e("GeofenceManagerEntry", "Exception ignored", e);
        }
        try {
            manager.destroy();
        } catch (Exception e) {
            android.util.Log.e("GeofenceManagerEntry", "Exception ignored", e);
        }
        try {
            appContext.unregisterReceiver(receiver);
        } catch (Exception e) {
            android.util.Log.e("GeofenceManagerEntry", "Exception ignored", e);
        }
        cancelAllPendingIntents();
    }

    @NonNull
    private PendingIntent buildPendingIntent(@NonNull String tag) {
        Intent intent = new Intent(action)
                .setPackage(appContext.getPackageName())
                .putExtra(KEY_GEOFENCE_ID, tag);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_MUTABLE;
        }
        // requestCode 用 tag 的 hashCode，避免不同 fence 拿到同一个 PendingIntent
        return PendingIntent.getBroadcast(appContext, tag.hashCode(), intent, flags);
    }

    private void cancelAllPendingIntents() {
        List<PendingIntent> copy;
        synchronized (pendingIntents) {
            copy = new ArrayList<>(pendingIntents.values());
            pendingIntents.clear();
        }
        for (PendingIntent pi : copy) {
            try {
                pi.cancel();
            } catch (Exception e) {
            android.util.Log.e("GeofenceManagerEntry", "Exception ignored", e);
        }
        }
    }

    // ---------- Intent 解析 ----------

    private void handleReceive(@Nullable Intent intent) {
        if (intent == null) return;
        int errorCode = intent.getIntExtra(TencentGeofence.ERROR_CODE, TencentGeofence.ERROR_OK);
        if (errorCode != TencentGeofence.ERROR_OK) {
            String fenceTag = intent.getStringExtra(KEY_GEOFENCE_ID);
            if (fenceTag != null) {
                synchronized (districtTags) {
                    districtTags.remove(fenceTag);
                }
            }
            dispatcher.sendGeofence("onGeofenceError",
                    geofenceManagerId, buildErrorPayload(intent, errorCode));
            return;
        }

        // 成功路径 —— KEY_PROXIMITY_ENTERING 决定 enter / exit
        if (!intent.hasExtra(LocationManager.KEY_PROXIMITY_ENTERING)) {
            // "fence add success" 广播（SDK 对每种围栏添加成功都会广播）：
            // - circle / polygon 为同步添加，addGeofence 的 Future 已代表生效，忽略；
            // - district 异步创建完成才广播此通知，透传为 onGeofenceCreated。
            Map<String, Object> created = buildCreatedPayload(intent, districtTags);
            if (created != null) {
                dispatcher.sendGeofence("onGeofenceCreated", geofenceManagerId, created);
            }
            return;
        }
        boolean entering = intent.getBooleanExtra(LocationManager.KEY_PROXIMITY_ENTERING, false);
        String fenceTag = intent.getStringExtra(KEY_GEOFENCE_ID);

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("geofenceId", fenceTag == null ? "" : fenceTag);
        payload.put("transition", entering ? "enter" : "exit");
        payload.put("location", null);
        payload.put("stayedDurationMs", null);
        payload.put("userInfo", null);
        dispatcher.sendGeofence("onGeofenceEvent", geofenceManagerId, payload);
    }

    /**
     * 组装 district 围栏异步创建完成事件 payload。
     *
     * <p>仅当该 tag 是已提交的 district 围栏时才返回 payload（并移除 pending
     * 标记）；circle / polygon 或未知 tag 返回 {@code null}。SDK 广播 add-success
     * 时通过 fillIn 语义保留 base Intent 的 {@link #KEY_GEOFENCE_ID}，因此这里
     * 拿到的 tag 与 addGeofence 传入的一致。</p>
     */
    @Nullable
    static Map<String, Object> buildCreatedPayload(@NonNull Intent intent,
                                                    @NonNull Set<String> districtTags) {
        String fenceTag = intent.getStringExtra(KEY_GEOFENCE_ID);
        if (fenceTag == null || fenceTag.isEmpty()) return null;
        synchronized (districtTags) {
            if (!districtTags.remove(fenceTag)) return null;
        }
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("geofenceId", fenceTag);
        payload.put("userInfo", null);
        return payload;
    }

    /**
     * 组装围栏错误事件 payload，与 iOS / Dart 侧的 {@code onGeofenceError}
     * 字段契约对齐。
     *
     * <p>district（行政区）围栏为异步提交，失败时 SDK 通过 PendingIntent
     * 广播错误（fillIn 语义保留 base Intent 的 {@link #KEY_GEOFENCE_ID}），
     * 因此这里能拿到失败的 fence 标识并放进 {@code details.geofenceId}，
     * 供调用方定位到具体围栏。</p>
     */
    @NonNull
    static Map<String, Object> buildErrorPayload(@NonNull Intent intent, int errorCode) {
        String message = intent.getStringExtra(TencentGeofence.ERROR_MESSAGE);
        String fenceTag = intent.getStringExtra(KEY_GEOFENCE_ID);
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("code", mapGeofenceErrorCode(errorCode));
        payload.put("message", message == null ? "" : message);
        payload.put("nativeCode", errorCode);
        payload.put("nativeMessage", message);
        if (fenceTag != null && !fenceTag.isEmpty()) {
            Map<String, Object> details = new LinkedHashMap<>();
            details.put("geofenceId", fenceTag);
            payload.put("details", details);
        }
        return payload;
    }

    @NonNull
    private static String mapGeofenceErrorCode(int code) {
        // 见 TencentGeofence.ERROR_*
        switch (code) {
            case TencentGeofence.ERROR_KEYWORD_EMPTY:
            case TencentGeofence.ERROR_POLYGON_INSUFFICIENT:
            case TencentGeofence.ERROR_POLYGON_INVALID:
            case TencentGeofence.ERROR_KEYWORD_INVALID:
                return "geofenceInvalidRegion";
            case TencentGeofence.ERROR_REQUEST_FAILED:
                return "geofenceDistrictNotFound";
            case TencentGeofence.ERROR_OK:
            default:
                return "nativeError";
        }
    }
}
