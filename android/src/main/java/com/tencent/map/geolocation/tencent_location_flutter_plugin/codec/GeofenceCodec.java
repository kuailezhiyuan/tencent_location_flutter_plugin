package com.tencent.map.geolocation.tencent_location_flutter_plugin.codec;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.tencent.map.geolocation.TencentGeofence;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 在 Flutter 侧的 Map 与原生 {@link TencentGeofence} 之间转换。
 */
public final class GeofenceCodec {

    private GeofenceCodec() {}

    /** Flutter 侧 GeofenceType wireName → 原生 GEOFENCE_TYPE_* 常量。 */
    public static int typeFromWire(@NonNull String wire) {
        switch (wire) {
            case "circle":
                return TencentGeofence.GEOFENCE_TYPE_CIRCLE;
            case "polygon":
                return TencentGeofence.GEOFENCE_TYPE_POLYGON;
            case "district":
                return TencentGeofence.GEOFENCE_TYPE_DISTRICT;
            default:
                return TencentGeofence.GEOFENCE_TYPE_CIRCLE;
        }
    }

    @NonNull
    public static String typeToWire(int type) {
        if (type == TencentGeofence.GEOFENCE_TYPE_POLYGON) return "polygon";
        if (type == TencentGeofence.GEOFENCE_TYPE_DISTRICT) return "district";
        return "circle";
    }

    /** 把 Flutter 传来的 map 构造成原生 {@link TencentGeofence}。
     *
     * <p>注：当前 Android 原生 SDK 的 {@code TencentGeofence.Builder} 没有
     * {@code setCoordinateType(int)}，围栏的坐标系由
     * {@link com.tencent.map.geolocation.TencentLocationManager#setCoordinateType(int)}
     * 进程级控制。调用方应在 add 之前根据 fence 的 coordinateType 调用
     * {@link #coordinateTypeFromMap(Map)} 并 apply 到全局，再把 fence 传进来。</p>
     */
    @NonNull
    public static TencentGeofence fromMap(@NonNull Map<?, ?> map) {
        String type = asString(map.get("type"), "circle");
        Long expirationMs = asLong(map.get("expirationMs"));
        String id = asString(map.get("id"), "");

        TencentGeofence.Builder builder = new TencentGeofence.Builder()
                .setTag(id);
        if (expirationMs != null) {
            builder.setExpirationDuration(expirationMs);
        }

        switch (type) {
            case "circle": {
                Map<?, ?> center = asMap(map.get("center"));
                double lat = asDouble(center == null ? null : center.get("latitude"), 0);
                double lng = asDouble(center == null ? null : center.get("longitude"), 0);
                double radius = asDouble(map.get("radius"), 0);
                builder.setCircularRegion(lat, lng, (float) radius);
                break;
            }
            case "polygon": {
                Object rawPolygon = map.get("polygon");
                List<TencentGeofence.FencePoint> points = new ArrayList<>();
                if (rawPolygon instanceof Iterable) {
                    for (Object pt : (Iterable<?>) rawPolygon) {
                        if (pt instanceof Map) {
                            Map<?, ?> p = (Map<?, ?>) pt;
                            double lat = asDouble(p.get("latitude"), 0);
                            double lng = asDouble(p.get("longitude"), 0);
                            points.add(new TencentGeofence.FencePoint(lat, lng));
                        }
                    }
                }
                builder.setPolygonRegion(points);
                break;
            }
            case "district": {
                String keyword = asString(map.get("districtKeyword"), "");
                builder.setDistrictRegion(keyword);
                break;
            }
            default:
                builder.setCircularRegion(0, 0, 0);
        }

        return builder.build();
    }

    /** 原生 {@link TencentGeofence} 反序列化回 Map。 */
    @NonNull
    public static Map<String, Object> toMap(@NonNull TencentGeofence fence) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", fence.getTag());
        map.put("type", typeToWire(fence.getType()));
        map.put("coordinateType", "gcj02");
        long duration = fence.getDuration();
        map.put("expirationMs", duration > 0 ? duration : null);
        map.put("monitorTransitions",
                new ArrayList<>(Arrays.asList("enter", "exit")));
        map.put("dwellDurationMs", null);
        map.put("userInfo", null);

        switch (fence.getType()) {
            case TencentGeofence.GEOFENCE_TYPE_CIRCLE: {
                Map<String, Object> center = new LinkedHashMap<>();
                center.put("latitude", fence.getLatitude());
                center.put("longitude", fence.getLongitude());
                map.put("center", center);
                map.put("radius", (double) fence.getRadius());
                map.put("polygon", null);
                map.put("districtKeyword", null);
                break;
            }
            case TencentGeofence.GEOFENCE_TYPE_POLYGON: {
                map.put("center", null);
                List<Map<String, Object>> polygon = new ArrayList<>();
                TencentGeofence.PolygonFence poly = fence.getPolygonFence();
                if (poly != null && poly.getPointList() != null) {
                    for (TencentGeofence.FencePoint p : poly.getPointList()) {
                        Map<String, Object> pm = new LinkedHashMap<>();
                        pm.put("latitude", p.getLatitude());
                        pm.put("longitude", p.getLongitude());
                        polygon.add(pm);
                    }
                }
                map.put("polygon", polygon);
                map.put("radius", null);
                map.put("districtKeyword", null);
                break;
            }
            case TencentGeofence.GEOFENCE_TYPE_DISTRICT: {
                map.put("center", null);
                map.put("radius", null);
                map.put("polygon", null);
                TencentGeofence.DistrictFence district = fence.getDistrictFence();
                map.put("districtKeyword",
                        district == null ? "" : district.getKeyword());
                break;
            }
            default:
                map.put("center", null);
                map.put("radius", null);
                map.put("polygon", null);
                map.put("districtKeyword", null);
        }
        return map;
    }

    /** 从 fence map 里读 coordinateType wireName（用于 add 之前 apply 到 Android 进程级）。 */
    @Nullable
    public static String coordinateTypeFromMap(@NonNull Map<?, ?> map) {
        Object v = map.get("coordinateType");
        return v instanceof String ? (String) v : null;
    }

    /** 解析 monitorTransitions 列表，返回小写 wireName 集合。 */
    @NonNull
    public static Set<String> parseMonitorTransitions(@Nullable Object raw) {
        Set<String> set = new HashSet<>();
        if (raw instanceof Iterable) {
            for (Object e : (Iterable<?>) raw) {
                if (e instanceof String) set.add((String) e);
            }
        }
        if (set.isEmpty()) {
            set.addAll(Arrays.asList("enter", "exit"));
        }
        return Collections.unmodifiableSet(set);
    }

    // ---------- primitive helpers ----------

    @Nullable
    private static Map<?, ?> asMap(@Nullable Object v) {
        return v instanceof Map ? (Map<?, ?>) v : null;
    }

    @NonNull
    private static String asString(@Nullable Object v, @NonNull String fallback) {
        return v instanceof String ? (String) v : fallback;
    }

    @Nullable
    private static Long asLong(@Nullable Object v) {
        if (v instanceof Number) return ((Number) v).longValue();
        return null;
    }

    private static double asDouble(@Nullable Object v, double fallback) {
        return v instanceof Number ? ((Number) v).doubleValue() : fallback;
    }
}
