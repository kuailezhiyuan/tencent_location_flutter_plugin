package com.tencent.map.geolocation.tencent_location_flutter_plugin.handler;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

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

    private boolean initialized;
    private boolean logForwarderInstalled;

    public SdkHandler(@NonNull Context appContext,
                      @NonNull EventDispatcher dispatcher) {
        this.appContext = appContext;
        this.dispatcher = dispatcher;
    }

    /** 返回 true 表示已处理，否则让主路由器 notImplemented。 */
    public boolean handle(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "sdk.setPrivacyPolicyAgreement": {
                boolean agreed = Boolean.TRUE.equals(call.argument("agreed"));
                if (!agreed) dispose();
                TencentLocationManager.setUserAgreePrivacy(agreed);
                if (agreed) installSdkLogForwarder();
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
            initialized = true;
            installSdkLogForwarder();
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
            Log.e("SdkHandler", "Failed to read Tencent SDK version", t);
            return "";
        }
    }

    @NonNull
    private String safeBuild() {
        try {
            return TencentLocationManager.getInstance(appContext).getBuild();
        } catch (Exception t) {
            Log.e("SdkHandler", "Failed to read Tencent SDK build number", t);
            return "";
        }
    }

    @NonNull
    private String safeOaid() {
        try {
            return TencentLocationManager.getInstance(appContext).getOaid();
        } catch (Exception t) {
            Log.e("SdkHandler", "Failed to read Tencent SDK OAID", t);
            return "";
        }
    }

    private void installSdkLogForwarder() {
        // 注册会创建 SDK 实例，需要先设置 Key 并取得隐私同意。
        if (!initialized || logForwarderInstalled || !TencentLocationManager.getUserAgreePrivacy()) return;
        try {
            TencentLocationManager.getInstance(appContext).setSDKLogListener((level, log) -> {
                Map<String, Object> payload = new LinkedHashMap<>();
                payload.put("level", level);
                payload.put("log", log == null ? "" : log);
                dispatcher.sendStatus("onSdkLog", null, payload);
            });
            logForwarderInstalled = true;
        } catch (Exception e) {
            Log.e("SdkHandler", "Failed to install Tencent SDK log listener", e);
        }
    }

    public void dispose() {
        if (!logForwarderInstalled) return;
        try {
            TencentLocationManager.getInstance(appContext).setSDKLogListener(null);
        } catch (Exception e) {
            Log.e("SdkHandler", "Failed to remove Tencent SDK log listener", e);
        }
        logForwarderInstalled = false;
    }
}
