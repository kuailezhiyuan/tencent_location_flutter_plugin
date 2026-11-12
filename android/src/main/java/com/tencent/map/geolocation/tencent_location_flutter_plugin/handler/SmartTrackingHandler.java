package com.tencent.map.geolocation.tencent_location_flutter_plugin.handler;

import android.content.Context;
import android.util.Log;

import com.tencent.map.geolocation.tencent_location_flutter_plugin.smart.SmartTrackingService;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.smart.SmartTrackingStore;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.util.Errors;

import java.io.IOException;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Additive app-wide Smart API; ordinary per-manager APIs remain unchanged. */
public final class SmartTrackingHandler {
    private final Context context;
    private final LocationHandler locations;
    public SmartTrackingHandler(Context context, LocationHandler locations) {
        this.context = context;
        this.locations = locations;
    }

    public boolean handle(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "smart.start":
                    if (locations.hasActiveLocationRequests()) {
                        Errors.code(result, Errors.ALREADY_STARTED, "Stop ordinary location requests before starting the app-wide Smart session", null);
                        return true;
                    }
                    if (!(call.arguments instanceof Map)) throw new IllegalArgumentException("Smart start arguments must be a map");
                    @SuppressWarnings("unchecked") Map<String, Object> arguments = (Map<String, Object>) call.arguments;
                    SmartTrackingService.start(context, arguments, new SmartTrackingService.StartResult() {
                        @Override public void success(Map<String, Object> state) { result.success(state); }
                        @Override public void failure(String code, String message, Throwable error) {
                            result.error(code, message, error == null ? null : Log.getStackTraceString(error));
                        }
                    });
                    return true;
                case "smart.stop":
                    SmartTrackingService.stop(context);
                    result.success(SmartTrackingService.state(context));
                    return true;
                case "smart.getState":
                    result.success(SmartTrackingService.state(context));
                    return true;
                case "smart.getLog":
                    result.success(new SmartTrackingStore(context).getLog());
                    return true;
                case "smart.clearLog":
                    new SmartTrackingStore(context).clearLog();
                    result.success(null);
                    return true;
                default:
                    return false;
            }
        } catch (IllegalArgumentException error) {
            Errors.invalidArgument(result, error.getMessage() == null ? "Invalid Smart arguments" : error.getMessage());
        } catch (RuntimeException | IOException error) {
            Log.e("TencentSmart", "Handling " + call.method + " failed", error);
            Errors.native_(result, "Handling " + call.method + " failed", error);
        }
        return true;
    }
}
