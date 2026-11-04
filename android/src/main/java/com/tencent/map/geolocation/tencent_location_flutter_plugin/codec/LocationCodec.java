package com.tencent.map.geolocation.tencent_location_flutter_plugin.codec;

import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.tencent.map.geolocation.TencentLocation;
import com.tencent.map.geolocation.TencentPoi;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 在 Flutter 侧的 Map 与原生 {@link TencentLocation} 之间转换。
 */
public final class LocationCodec {

    private LocationCodec() {}

    /**
     * Android provider 字符串 → Flutter 侧 LocationSource 的 wireName。
     */
    @NonNull
    public static String providerToWireName(@Nullable String provider) {
        if (provider == null) return "unknown";
        switch (provider) {
            case TencentLocation.GPS_PROVIDER:
                return "androidGps";
            case TencentLocation.NETWORK_PROVIDER:
                return "androidNetwork";
            case TencentLocation.CELL_PROVIDER:
                return "androidCell";
            case TencentLocation.WIFI_PROVIDER:
                return "androidWifi";
            case TencentLocation.CACHE_PROVIDER:
                return "androidCache";
            case TencentLocation.BEIDOU_PROVIDER:
                return "androidBeidou";
            case TencentLocation.RTK_PROVIDER:
                return "androidRtk";
            case TencentLocation.SINGLE_PROVIDER:
                return "androidSingle";
            case TencentLocation.COARSE_PROVIDER:
                return "androidCoarse";
            case TencentLocation.FUSED_PROVIDER:
                return "androidFused";
            case "fake":
            default:
                return "unknown";
        }
    }

    /** 把坐标系整数（{@code 1=GCJ02, 0=WGS84}）映射为 wireName。 */
    @NonNull
    public static String coordinateTypeToWireName(int coordinateType) {
        // TencentLocationManager.COORDINATE_TYPE_GCJ02 = 1, _WGS84 = 0
        return coordinateType == 0 ? "wgs84" : "gcj02";
    }

    @NonNull
    public static Map<String, Object> toMap(@NonNull TencentLocation loc) {
        Map<String, Object> map = new LinkedHashMap<>();

        // 核心经纬度
        map.put("latitude", loc.getLatitude());
        map.put("longitude", loc.getLongitude());
        map.put("altitude", loc.getAltitude());
        map.put("accuracy", (double) loc.getAccuracy());
        map.put("bearing", (double) loc.getBearing());
        map.put("speed", (double) loc.getSpeed());
        map.put("directionFromSensor", (double) loc.getDirection());
        map.put("time", loc.getTime());

        // 来源
        map.put("source", providerToWireName(loc.getProvider()));
        map.put("coordinateType", coordinateTypeToWireName(loc.getCoordinateType()));

        // 地址 —— 只有 requestLevel >= name 才有
        Map<String, Object> addr = buildAddress(loc);
        map.put("geoAddress", addr);

        // POI
        List<? extends TencentPoi> poiList = loc.getPoiList();
        if (poiList != null && !poiList.isEmpty()) {
            List<Map<String, Object>> encoded = new ArrayList<>(poiList.size());
            for (TencentPoi poi : poiList) {
                encoded.add(poiToMap(poi));
            }
            map.put("poiList", encoded);
        } else {
            map.put("poiList", Collections.emptyList());
        }

        // 室内
        map.put("indoorBuildingId", loc.getIndoorBuildingId());
        map.put("indoorBuildingFloor", loc.getIndoorBuildingFloor());

        // Android 专属
        map.put("elapsedRealtime", loc.getElapsedRealtime());
        map.put("gpsRssi", loc.getGPSRssi());

        // iOS / Harmony 专属字段：Android 端恒 null / 'none'
        map.put("verticalAccuracy", null);
        map.put("cacheSource", "none");

        // 扩展 bundle
        Bundle extra = loc.getExtra();
        if (extra != null && !extra.isEmpty()) {
            Map<String, Object> extras = new HashMap<>();
            for (String key : extra.keySet()) {
                Object v = extra.get(key);
                if (v instanceof CharSequence || v instanceof Number
                        || v instanceof Boolean || v == null) {
                    extras.put(key, v);
                } else {
                    extras.put(key, String.valueOf(v));
                }
            }
            map.put("extras", extras);
        } else {
            map.put("extras", Collections.emptyMap());
        }

        return map;
    }

    @NonNull
    private static Map<String, Object> buildAddress(@NonNull TencentLocation loc) {
        Map<String, Object> addr = new LinkedHashMap<>();
        addr.put("name", loc.getName());
        addr.put("address", loc.getAddress());
        addr.put("nation", loc.getNation());
        addr.put("nationCode", loc.getNationCode());
        addr.put("province", loc.getProvince());
        addr.put("city", loc.getCity());
        addr.put("district", loc.getDistrict());
        addr.put("town", loc.getTown());
        addr.put("village", loc.getVillage());
        addr.put("street", loc.getStreet());
        addr.put("streetNo", loc.getStreetNo());
        addr.put("cityCode", loc.getCityCode());
        addr.put("cityPhoneCode", loc.getCityPhoneCode());
        addr.put("areaStat", loc.getAreaStat());
        return addr;
    }

    @NonNull
    public static Map<String, Object> poiToMap(@NonNull TencentPoi poi) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("name", poi.getName());
        m.put("address", poi.getAddress());
        m.put("catalog", poi.getCatalog());
        m.put("distance", poi.getDistance());
        m.put("latitude", poi.getLatitude());
        m.put("longitude", poi.getLongitude());
        m.put("uid", poi.getUid());
        m.put("direction", poi.getDirection());
        return m;
    }
}
