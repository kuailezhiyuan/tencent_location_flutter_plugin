package com.tencent.map.geolocation.tencent_location_flutter_plugin.smart;

import android.os.Handler;
import android.os.SystemClock;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Modified Java port of Tracelet 071cd0be (Apache-2.0): motion/SpeedMotionManager.kt,
 * motion/SmartMotionCoordinator.kt and rust-core/core/src/state/smart_motion_coordinator.rs.
 * The speed hysteresis, three-fix slowing abort, stale-speed and tremor rules are retained.
 * Only continuous High/Low pacing is exposed; provider application belongs to the service.
 */
public final class SmartMotionEngine {
    public enum SpeedState { MOVING, SLOWING, STATIONARY }
    public interface Listener {
        void onStateChanged(String reason);
        void onPaceRequested(boolean moving, String reason);
    }

    private static final int SPEED_ABORT_FIX_COUNT = 3;
    private static final double STATIONARY_THRESHOLD_RATIO = 0.65;
    private static final double TREMOR_SPEED_THRESHOLD = 0.15;
    private static final long MAX_PACE_FIX_AGE_MS = 10_000;
    private final SmartTrackingConfig config;
    private final Handler handler;
    private final Listener listener;
    private boolean running;
    private boolean accelMoving = true;
    private SpeedState speedState = SpeedState.MOVING;
    private boolean committedMoving = true;
    private int lowCount;
    private int wakeCount;
    private int highCount;
    private long slowingStarted;
    private Runnable slowingTimer;
    private Double lastSpeed;
    private long lastSpeedAt;

    public SmartMotionEngine(SmartTrackingConfig config, Handler handler, Listener listener) {
        this.config = config;
        this.handler = handler;
        this.listener = listener;
    }

    public void start(Map<?, ?> restored, boolean resume) {
        running = true;
        if (resume) {
            accelMoving = bool(restored, "accelerometerMoving", true);
            committedMoving = bool(restored, "isMoving", true);
            Object speed = restored.get("speedState");
            try {
                speedState = speed instanceof String ? SpeedState.valueOf(((String) speed).toUpperCase(java.util.Locale.ROOT)) : SpeedState.MOVING;
            } catch (IllegalArgumentException error) {
                throw new IllegalArgumentException("Invalid persisted Smart speedState", error);
            }
            wakeCount = count(restored.get("speedWakeCount"));
            lowCount = count(restored.get("speedLowCount"));
            // Tracelet restarts a SLOWING countdown in the new monotonic process epoch.
            if (speedState == SpeedState.SLOWING) beginSlowingTimer();
        } else {
            accelMoving = true;
            speedState = SpeedState.MOVING;
            committedMoving = true;
            lowCount = wakeCount = highCount = 0;
        }
        listener.onStateChanged(resume ? "motion_restored" : "motion_started");
        reconcile("startup_reconcile");
    }

    public void stop() {
        running = false;
        stopSlowingTimer();
    }

    public void onAccelerometer(boolean moving) {
        if (!running || accelMoving == moving) return;
        boolean wasMoving = wantsMoving();
        accelMoving = moving;
        // Tracelet reasserts MOVING in the speed peer only for an actual wake.
        if (moving && !wasMoving) {
            stopSlowingTimer();
            lowCount = wakeCount = highCount = 0;
            speedState = SpeedState.MOVING;
        }
        listener.onStateChanged(moving ? "accelerometer_moving" : "accelerometer_stationary");
        reconcile("accelerometer");
    }

    public void onSpeed(double speed, long fixAgeMs) {
        if (!running || (Double.isNaN(speed) || Double.isInfinite(speed)) || speed < 0 || fixAgeMs < 0 || fixAgeMs > MAX_PACE_FIX_AGE_MS) return;
        lastSpeed = speed;
        lastSpeedAt = SystemClock.elapsedRealtime() - fixAgeMs;
        switch (speedState) {
            case MOVING:
                if (speed < config.speedMovingThreshold * STATIONARY_THRESHOLD_RATIO) {
                    lowCount = 1;
                    highCount = 0;
                    transition(SpeedState.SLOWING, "speed_slowing");
                    beginSlowingTimer();
                }
                break;
            case SLOWING:
                if (speed >= config.speedMovingThreshold) {
                    highCount++;
                    if (highCount < SPEED_ABORT_FIX_COUNT) return;
                    lowCount = highCount = 0;
                    stopSlowingTimer();
                    transition(SpeedState.MOVING, "speed_slowing_aborted");
                } else {
                    highCount = 0;
                    lowCount++;
                    if (SystemClock.elapsedRealtime() - slowingStarted >= config.speedStationaryDelayMs) {
                        enterStationary();
                    }
                }
                break;
            case STATIONARY:
                if (speed >= config.speedMovingThreshold) {
                    wakeCount++;
                    if (wakeCount >= config.speedWakeConfirmCount) {
                        wakeCount = 0;
                        transition(SpeedState.MOVING, "speed_wake_confirmed");
                    }
                } else {
                    wakeCount = 0;
                }
                break;
        }
        listener.onStateChanged("speed_sample");
    }

    private void beginSlowingTimer() {
        stopSlowingTimer();
        slowingStarted = SystemClock.elapsedRealtime();
        slowingTimer = () -> {
            if (running && speedState == SpeedState.SLOWING) enterStationary();
        };
        handler.postDelayed(slowingTimer, config.speedStationaryDelayMs);
    }

    private void stopSlowingTimer() {
        if (slowingTimer != null) handler.removeCallbacks(slowingTimer);
        slowingTimer = null;
    }

    private void enterStationary() {
        lowCount = wakeCount = 0;
        stopSlowingTimer();
        transition(SpeedState.STATIONARY, "speed_stationary");
    }

    private void transition(SpeedState next, String reason) {
        if (speedState == next) return;
        speedState = next;
        if (next == SpeedState.STATIONARY && accelMoving && resolvedSpeed() != null
                && resolvedSpeed() <= TREMOR_SPEED_THRESHOLD) {
            accelMoving = false;
        }
        listener.onStateChanged(reason);
        reconcile(reason);
    }

    private Double resolvedSpeed() {
        return lastSpeed != null && SystemClock.elapsedRealtime() - lastSpeedAt <= MAX_PACE_FIX_AGE_MS ? lastSpeed : null;
    }

    public void reconcile(String reason) {
        if (running && wantsMoving() != committedMoving) listener.onPaceRequested(wantsMoving(), reason);
    }

    public void commitPace(boolean moving) {
        committedMoving = moving;
    }

    public boolean wantsMoving() { return accelMoving || speedState != SpeedState.STATIONARY; }
    public boolean isMoving() { return committedMoving; }
    public boolean isAccelMoving() { return accelMoving; }
    public boolean isSpeedMoving() { return speedState != SpeedState.STATIONARY; }
    public String speedState() { return speedState.name().toLowerCase(java.util.Locale.ROOT); }

    public Map<String, Object> snapshot() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("isMoving", committedMoving);
        map.put("accelerometerMoving", accelMoving);
        map.put("speedMoving", isSpeedMoving());
        map.put("speedState", speedState());
        map.put("speedWakeCount", wakeCount);
        map.put("speedLowCount", lowCount);
        return map;
    }

    private static boolean bool(Map<?, ?> map, String key, boolean fallback) {
        Object value = map.get(key);
        return value instanceof Boolean ? (Boolean) value : fallback;
    }

    private static int count(Object value) {
        return value instanceof Number ? Math.max(0, ((Number) value).intValue()) : 0;
    }
}
