package com.tencent.map.geolocation.tencent_location_flutter_plugin;

import android.content.Context;

import androidx.annotation.NonNull;

import com.tencent.map.geolocation.tencent_location_flutter_plugin.event.EventDispatcher;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.handler.GeofenceHandler;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.handler.LocationHandler;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.handler.SdkHandler;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.handler.UtilsHandler;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.registry.GeofenceManagerRegistry;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.registry.LocationManagerRegistry;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * 腾讯定位 SDK Flutter 插件 Android 端入口。
 */
public class TencentLocationFlutterPlugin implements FlutterPlugin, MethodCallHandler {

    /** 主 MethodChannel 名称。 */
    private static final String METHOD_CHANNEL_NAME =
            "com.tencent.map.geolocation.flutter/method";

    private MethodChannel methodChannel;
    private EventDispatcher eventDispatcher;

    private SdkHandler sdkHandler;
    private LocationHandler locationHandler;
    private GeofenceHandler geofenceHandler;
    private UtilsHandler utilsHandler;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        Context appContext = binding.getApplicationContext();

        methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL_NAME);
        methodChannel.setMethodCallHandler(this);

        eventDispatcher = new EventDispatcher(binding.getBinaryMessenger());

        LocationManagerRegistry locRegistry = new LocationManagerRegistry();
        GeofenceManagerRegistry geoRegistry = new GeofenceManagerRegistry();

        sdkHandler = new SdkHandler(appContext, eventDispatcher);
        locationHandler = new LocationHandler(appContext, eventDispatcher, locRegistry);
        geofenceHandler = new GeofenceHandler(appContext, eventDispatcher, geoRegistry);
        utilsHandler = new UtilsHandler(appContext);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        String method = call.method == null ? "" : call.method;
        if (method.startsWith("sdk.")) {
            if (!sdkHandler.handle(call, result)) result.notImplemented();
            return;
        }
        if (method.startsWith("manager.") || method.startsWith("location.")
                || method.startsWith("stream.")) {
            if (!locationHandler.handle(call, result)) result.notImplemented();
            return;
        }
        if (method.startsWith("geofence.")) {
            if (!geofenceHandler.handle(call, result)) result.notImplemented();
            return;
        }
        if (method.startsWith("utils.")) {
            if (!utilsHandler.handle(call, result)) result.notImplemented();
            return;
        }
        result.notImplemented();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (methodChannel != null) {
            methodChannel.setMethodCallHandler(null);
            methodChannel = null;
        }
        if (locationHandler != null) {
            locationHandler.disposeAll();
            locationHandler = null;
        }
        if (geofenceHandler != null) {
            geofenceHandler.disposeAll();
            geofenceHandler = null;
        }
        if (sdkHandler != null) {
            sdkHandler.dispose();
            sdkHandler = null;
        }
        if (eventDispatcher != null) {
            eventDispatcher.dispose();
            eventDispatcher = null;
        }
        utilsHandler = null;
    }
}
