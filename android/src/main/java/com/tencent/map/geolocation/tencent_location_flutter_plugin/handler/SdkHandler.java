package com.tencent.map.geolocation.tencent_location_flutter_plugin.handler;

import android.content.Context;

import androidx.annotation.NonNull;

import com.tencent.map.geolocation.TencentLocationLogListener;
import com.tencent.map.geolocation.TencentLocationManager;
import com.tencent.map.geolocation.TencentLocationManagerOptions;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.event.EventDispatcher;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.util.Errors;

import java.util.LinkedHashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * 处理所有 {@code sdk.*} method 调用。
 */
public class SdkHandler {

    private final Context appContext;
    private final EventDispatcher dispatcher;

    private TencentLocationLogListener logListener;
    /** 日志转发器是否已成功装载到 SDK。隐私未同意会装载失败，需要后续补装。 */
    private boolean logForwarderInstalled;

    public SdkHandler(@NonNull Context appContext,
                      @NonNull EventDispatcher dispatcher) {
        this.appContext = appContext;
        this.dispatcher = dispatcher;
        installSdkLogForwarder();
    }

    /** 返回 true 表示已处理，否则让主路由器 notImplemented。 */
    public boolean handle(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "sdk.setPrivacyPolicyAgreement": {
                Boolean agreed = call.argument("agreed");
                TencentLocationManager.setUserAgreePrivacy(Boolean.TRUE.equals(agreed));
                if (Boolean.TRUE.equals(agreed) && !logForwarderInstalled) {
                    // 首次同意隐私后补装日志转发器（attach 时若隐私未同意会装载失败）
                    installSdkLogForwarder();
                }
                result.success(null);
                return true;
            }
            case "sdk.getPrivacyPolicyAgreement":
                result.success(TencentLocationManager.getUserAgreePrivacy());
                return true;

            case "sdk.init":
                handleInit(call, result);
                return true;

            case "sdk.getVersion":
                result.success(safeVersion());
                return true;

            case "sdk.getBuildVersion":
                result.success(safeBuild());
                return true;

            case "sdk.getOaid":
                result.success(safeOaid());
                return true;

            case "sdk.enableLogToFile": {
                Boolean enabled = call.argument("enabled");
                TencentLocationManagerOptions.setDebuggable(Boolean.TRUE.equals(enabled));
                result.success(null);
                return true;
            }
            case "sdk.setRtkLogEnabled": {
                Boolean enabled = call.argument("enabled");
                TencentLocationManagerOptions.starRtkLog(Boolean.TRUE.equals(enabled));
                result.success(null);
                return true;
            }

            case "sdk.setSystemCacheEnabled": {
                Boolean enabled = call.argument("enabled");
                try {
                    TencentLocationManager.getInstance(appContext)
                            .setSystemCacheEnable(Boolean.TRUE.equals(enabled));
                    result.success(null);
                } catch (Exception t) {
                    Errors.native_(result, "setSystemCacheEnabled failed: " + t, t);
                }
                return true;
            }

            case "sdk.setExtraData": {
                String key = call.argument("key");
                String value = call.argument("value");
                if (key == null || value == null) {
                    Errors.invalidArgument(result, "key and value must be non-null");
                    return true;
                }
                try {
                    // Options 与 Manager 两侧的 setExtraData 各自维护独立存储、
                    // 生效时机不同，同一 key 通常只在一侧命中，另一侧静默忽略。
                    TencentLocationManagerOptions.setExtraData(key, value);
                    TencentLocationManager.getInstance(appContext).setExtraData(key, value);
                    result.success(null);
                } catch (Exception t) {
                    Errors.native_(result, "setExtraData failed: " + t, t);
                }
                return true;
            }

            case "sdk.setUploadGpsForNaviEnabled": {
                Boolean enabled = call.argument("enabled");
                TencentLocationManagerOptions.setUploadGpsForNavi(Boolean.TRUE.equals(enabled));
                result.success(null);
                return true;
            }
            case "sdk.setLoadLibraryEnabled": {
                Boolean enabled = call.argument("enabled");
                TencentLocationManagerOptions.setLoadLibraryEnabled(Boolean.TRUE.equals(enabled));
                result.success(null);
                return true;
            }

            // iOS 专属方法在 Android 上全部抛不支持
            case "sdk.ios.requestWhenInUseAuthorization":
            case "sdk.ios.requestAlwaysAuthorization":
            case "sdk.ios.requestTemporaryFullAccuracy":
            case "sdk.ios.getAccuracyAuthorization":
                Errors.unsupported(result, call.method);
                return true;

            default:
                return false;
        }
    }

    private void handleInit(@NonNull MethodCall call, @NonNull Result result) {
        String apiKey = call.argument("androidApiKey");
        String extraKey = call.argument("extraKey");
        String deviceId = call.argument("deviceId");

        try {
            if (apiKey != null && !apiKey.isEmpty()) {
                TencentLocationManagerOptions.setKey(apiKey);
            }
            if (extraKey != null && !extraKey.isEmpty()) {
                TencentLocationManagerOptions.setExtraKey(extraKey);
            }
            if (deviceId != null && !deviceId.isEmpty()) {
                TencentLocationManager.getInstance(appContext).setDeviceID(appContext, deviceId);
            }
            result.success(null);
        } catch (Exception t) {
            Errors.code(result, Errors.SDK_INIT_FAILED,
                    "sdk.init failed: " + t.getMessage(), t.toString());
        }
    }

    // ---------- helper ----------

    @NonNull
    private String safeVersion() {
        try {
            return TencentLocationManager.getInstance(appContext).getVersion();
        } catch (Exception t) {
            return "";
        }
    }

    @NonNull
    private String safeBuild() {
        try {
            return TencentLocationManager.getInstance(appContext).getBuild();
        } catch (Exception t) {
            return "";
        }
    }

    @NonNull
    private String safeOaid() {
        try {
            return TencentLocationManager.getInstance(appContext).getOaid();
        } catch (Exception t) {
            return "";
        }
    }

    /**
     * 安装 SDK 日志转发器。
     *
     * <p>插件 attach 时调用一次；若彼时隐私尚未同意，SDK 内部会抛异常导致装载失败，
     * 此处吞掉异常并保留 {@link #logForwarderInstalled} 为 {@code false}，
     * 等用户调用 {@code setPrivacyPolicyAgreement(true)} 后再补装一次（幂等）。
     */
    private void installSdkLogForwarder() {
        if (logListener == null) {
            logListener = (level, log) -> {
                Map<String, Object> payload = new LinkedHashMap<>();
                payload.put("level", level);
                payload.put("log", log == null ? "" : log);
                dispatcher.sendStatus("onSdkLog", null, payload);
            };
        }
        try {
            TencentLocationManager.getInstance(appContext).setSDKLogListener(logListener);
            logForwarderInstalled = true;
        } catch (Exception e) {
            logForwarderInstalled = false;
        
            android.util.Log.e("SdkHandler", "Exception ignored", e);
        }
    }

    public void dispose() {
        try {
            TencentLocationManager.getInstance(appContext).setSDKLogListener(null);
        } catch (Exception e) {
            android.util.Log.e("SdkHandler", "Exception ignored", e);
        }
        logForwarderInstalled = false;
    }
}
