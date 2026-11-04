package com.tencent.map.geolocation.tencent_location_flutter_plugin.codec;

import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.tencent.map.geolocation.TencentLocationRequest;

import java.util.Map;

/**
 * 在 Flutter 侧的 Map 与原生 {@link TencentLocationRequest} 之间转换。
 */
public final class RequestCodec {

    private RequestCodec() {}

    /**
     * 构造原生请求。
     *
     * @param map flutter 侧 {@code TencentLocationRequest.toMap()} 的结果
     * @return 用于传给 SDK 的请求对象
     */
    @NonNull
    public static TencentLocationRequest fromMap(@NonNull Map<?, ?> map) {
        Map<?, ?> common = asMap(map.get("common"));
        Map<?, ?> android = asMap(map.get("android"));

        TencentLocationRequest request = TencentLocationRequest.create();

        // ---------- common ----------
        Long intervalMs = asLong(get(common, "intervalMs"));
        if (intervalMs != null) request.setInterval(intervalMs);

        String requestLevel = asString(get(common, "requestLevel"));
        if (requestLevel != null) {
            request.setRequestLevel(levelFromWire(requestLevel));
        }

        Boolean allowDir = asBool(get(common, "allowDirectionSensor"));
        if (allowDir != null) request.setAllowDirection(allowDir);

        // ---------- android ----------
        String locMode = asString(get(android, "locMode"));
        if (locMode != null) request.setLocMode(locModeFromWire(locMode));

        String gnssSource = asString(get(android, "gnssSource"));
        if (gnssSource != null) request.setGnssSource(gnssSourceFromWire(gnssSource));

        Boolean allowGps = asBool(get(android, "allowGps"));
        if (allowGps != null) request.setAllowGPS(allowGps);

        Boolean allowBle = asBool(get(android, "allowBle"));
        if (allowBle != null) request.setAllowBLE(allowBle);

        Boolean allowCache = asBool(get(android, "allowCache"));
        if (allowCache != null) request.setAllowCache(allowCache);

        Boolean gpsFirst = asBool(get(android, "gpsFirst"));
        if (gpsFirst != null) request.setGpsFirst(gpsFirst);

        Long gpsFirstTimeoutMs = asLong(get(android, "gpsFirstTimeoutMs"));
        if (gpsFirstTimeoutMs != null) {
            request.setGpsFirstTimeOut(gpsFirstTimeoutMs.intValue());
        }

        Long firstLocTimeoutMs = asLong(get(android, "firstLocationTimeoutMs"));
        if (firstLocTimeoutMs != null) request.setLocFirstTimeOut(firstLocTimeoutMs);

        Boolean firstLocNeedAddr = asBool(get(android, "firstLocationNeedAddress"));
        if (firstLocNeedAddr != null) {
            request.setFirstLocationNeedAddress(firstLocNeedAddr);
        }

        Boolean indoorMode = asBool(get(android, "indoorMode"));
        if (indoorMode != null) request.setIndoorLocationMode(indoorMode);

        String qq = asString(get(android, "qq"));
        if (qq != null && !qq.isEmpty()) request.setQQ(qq);

        String smallAppKey = asString(get(android, "smallAppKey"));
        if (smallAppKey != null && !smallAppKey.isEmpty()) {
            request.setSmallAppKey(smallAppKey);
        }

        String phone = asString(get(android, "phoneNumber"));
        if (phone != null && !phone.isEmpty()) request.setPhoneNumber(phone);

        // extras 里透传 reGeoCodingKey
        String reGeo = asString(get(android, "reGeoCodingKey"));
        if (reGeo != null && !reGeo.isEmpty()) {
            Bundle extras = request.getExtras();
            // 原生 SDK 约定的 extras key 名固定为 "ReGeoCodingnKey"，
            // 拼写以原生 SDK 为准，请勿修改。
            extras.putString("ReGeoCodingnKey", reGeo);
        }

        return request;
    }

    /**
     * 读出 request 里是否要走 {@link com.tencent.map.geolocation.TencentLocationManager#requestLocationWithScene} 路径。
     *
     * @return 映射到原生 SCENE 整数；不走场景化时返回 {@code null}
     */
    @Nullable
    public static Integer sceneFromMap(@NonNull Map<?, ?> map) {
        Map<?, ?> android = asMap(map.get("android"));
        String scene = asString(get(android, "scene"));
        if (scene == null) return null;
        // SIGN_IN_SCENE=10, SPORT_SCENE=11, TRANSPORT_SCENE=12
        switch (scene) {
            case "signIn":
                return 10;
            case "sport":
                return 11;
            case "transport":
                return 12;
            default:
                return null;
        }
    }

    /** 从 request map 里读 coordinateType wireName（用于 start 之前 apply 到 Android 进程级）。 */
    @Nullable
    public static String coordinateTypeFromMap(@NonNull Map<?, ?> map) {
        Map<?, ?> common = asMap(map.get("common"));
        return asString(get(common, "coordinateType"));
    }

    // ==================== wire → native int ====================

    public static int levelFromWire(@NonNull String wire) {
        switch (wire) {
            case "geo":
                return TencentLocationRequest.REQUEST_LEVEL_GEO;
            case "name":
                return TencentLocationRequest.REQUEST_LEVEL_NAME;
            case "adminArea":
                return TencentLocationRequest.REQUEST_LEVEL_ADMIN_AREA;
            case "poi":
                return TencentLocationRequest.REQUEST_LEVEL_POI;
            default:
                return TencentLocationRequest.REQUEST_LEVEL_ADMIN_AREA;
        }
    }

    public static int locModeFromWire(@NonNull String wire) {
        switch (wire) {
            case "onlyNetwork":
                return TencentLocationRequest.ONLY_NETWORK_MODE;
            case "onlyGps":
                return TencentLocationRequest.ONLY_GPS_MODE;
            case "highAccuracy":
            default:
                return TencentLocationRequest.HIGH_ACCURACY_MODE;
        }
    }

    public static int gnssSourceFromWire(@NonNull String wire) {
        switch (wire) {
            case "beidouFirst":
                return TencentLocationRequest.GNSS_SOURCE_BEIDOU_FIRST;
            case "beidouOnly":
                return TencentLocationRequest.GNSS_SOURCE_BEIDOU_ONLY;
            case "rtkFirst":
                return TencentLocationRequest.GNSS_SOURCE_RTK_FIRST;
            case "gpsFirst":
            default:
                return TencentLocationRequest.GNSS_SOURCE_GPS_FIRST;
        }
    }

    public static int coordinateTypeFromWire(@Nullable String wire) {
        // TencentLocationManager.COORDINATE_TYPE_WGS84 = 0, _GCJ02 = 1
        return "wgs84".equals(wire) ? 0 : 1;
    }

    // ==================== helpers ====================

    @Nullable
    private static Map<?, ?> asMap(@Nullable Object v) {
        return v instanceof Map ? (Map<?, ?>) v : null;
    }

    @Nullable
    private static Object get(@Nullable Map<?, ?> map, @NonNull String key) {
        return map == null ? null : map.get(key);
    }

    @Nullable
    private static String asString(@Nullable Object v) {
        return v instanceof String ? (String) v : null;
    }

    @Nullable
    private static Long asLong(@Nullable Object v) {
        return v instanceof Number ? ((Number) v).longValue() : null;
    }

    @Nullable
    private static Boolean asBool(@Nullable Object v) {
        return v instanceof Boolean ? (Boolean) v : null;
    }
}
