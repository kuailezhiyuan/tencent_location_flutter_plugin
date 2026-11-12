package com.tencent.map.geolocation.tencent_location_flutter_plugin.smart;

import java.util.Map;

/** Wire configuration for the native-only Smart session. Durations are milliseconds. */
public final class SmartTrackingConfig {
    public final long stopTimeoutMs;
    public final long speedStationaryDelayMs;
    public final double speedMovingThreshold;
    public final int speedWakeConfirmCount;
    public final boolean releaseWakelockWhenStationary;
    public final String notificationTitle;
    public final String notificationText;
    public final String notificationChannelName;

    public SmartTrackingConfig(Map<?, ?> map) {
        stopTimeoutMs = duration(map, "stopTimeoutMs", 120_000);
        speedStationaryDelayMs = duration(map, "speedStationaryDelayMs", 90_000);
        speedMovingThreshold = number(map, "speedMovingThreshold", 5.0);
        if ((Double.isNaN(speedMovingThreshold) || Double.isInfinite(speedMovingThreshold)) || speedMovingThreshold <= 0) {
            throw new IllegalArgumentException("speedMovingThreshold must be finite and positive");
        }
        long count = duration(map, "speedWakeConfirmCount", 3);
        if (count < 1 || count > Integer.MAX_VALUE) {
            throw new IllegalArgumentException("speedWakeConfirmCount must be a positive integer");
        }
        speedWakeConfirmCount = (int) count;
        Object release = map.get("releaseWakelockWhenStationary");
        if (release != null && !(release instanceof Boolean)) {
            throw new IllegalArgumentException("releaseWakelockWhenStationary must be boolean");
        }
        releaseWakelockWhenStationary = release == null || (Boolean) release;
        notificationTitle = text(map, "notificationTitle", "Tracking active");
        notificationText = text(map, "notificationText", "Recording your route in the background");
        notificationChannelName = text(map, "notificationChannelName", "Background tracking");
    }

    private static double number(Map<?, ?> map, String key, double fallback) {
        Object value = map.get(key);
        if (value == null) return fallback;
        if (!(value instanceof Number)) throw new IllegalArgumentException(key + " must be numeric");
        return ((Number) value).doubleValue();
    }

    private static long duration(Map<?, ?> map, String key, long fallback) {
        double value = number(map, key, fallback);
        if ((Double.isNaN(value) || Double.isInfinite(value)) || value < 0 || value > Long.MAX_VALUE || value != Math.rint(value)) {
            throw new IllegalArgumentException(key + " must be a non-negative integer");
        }
        return (long) value;
    }

    private static String text(Map<?, ?> map, String key, String fallback) {
        Object value = map.get(key);
        if (value == null) return fallback;
        if (!(value instanceof String) || ((String) value).trim().isEmpty()) {
            throw new IllegalArgumentException(key + " must be a non-empty string");
        }
        return (String) value;
    }
}
