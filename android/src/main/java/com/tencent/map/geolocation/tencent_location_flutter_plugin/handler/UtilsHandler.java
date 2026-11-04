package com.tencent.map.geolocation.tencent_location_flutter_plugin.handler;

import android.content.Context;

import androidx.annotation.NonNull;

import com.tencent.map.geolocation.TencentLocationUtils;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.util.Errors;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * 处理 {@code utils.*} method。
 *
 * <ul>
 *   <li>{@code isSupportGps} → {@link TencentLocationUtils#isSupportGps(Context)}</li>
 *   <li>{@code isInRegion} / {@code wgs84ToGcj02} → Android 原生未提供，返回 unsupported</li>
 * </ul>
 */
public class UtilsHandler {

    private final Context appContext;

    public UtilsHandler(@NonNull Context appContext) {
        this.appContext = appContext;
    }

    public boolean handle(@NonNull MethodCall call, @NonNull Result result) {
        String method = call.method;
        if (!method.startsWith("utils.")) return false;

        switch (method) {
            case "utils.isSupportGps":
                try {
                    result.success(TencentLocationUtils.isSupportGps(appContext));
                } catch (Exception t) {
                    Errors.native_(result, "isSupportGps failed: " + t, t);
                }
                return true;

            case "utils.isInRegion":
            case "utils.wgs84ToGcj02":
                Errors.unsupported(result, method);
                return true;

            default:
                return false;
        }
    }
}
