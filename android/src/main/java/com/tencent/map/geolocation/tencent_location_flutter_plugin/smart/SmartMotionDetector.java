package com.tencent.map.geolocation.tencent_location_flutter_plugin.smart;

import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.hardware.TriggerEvent;
import android.hardware.TriggerEventListener;
import android.os.Handler;

/**
 * Modified Java port of Tracelet 071cd0be motion/MotionDetector.kt (Apache-2.0),
 * accelerometer-only branch: gravity subtraction + vector stillness, 25 quiet samples,
 * five-sample motion abort, 3s/5s batching and one-shot significant-motion re-arming.
 * No Google Activity Recognition client or system location API is used.
 */
public final class SmartMotionDetector {
    public interface Listener {
        void onMotion(boolean moving, String reason);
        void onWakeAvailabilityChanged();
        void onDiagnostic(String message, Throwable error);
    }
    private static final double SHAKE_THRESHOLD = 2.5;
    private static final double STILL_THRESHOLD = 0.4;
    private static final int STILL_SAMPLE_COUNT = 25;
    private static final int MOTION_ABORT_COUNT = 5;
    private static final int SENSOR_BATCH_LATENCY_US = 3_000_000;
    private static final int STILLNESS_BATCH_LATENCY_US = 5_000_000;
    private final SensorManager sensors;
    private final Handler handler;
    private final long stopTimeoutMs;
    private final Listener listener;
    private boolean running;
    private boolean selfMoving = true;
    private SensorEventListener accelerometer;
    private TriggerEventListener significantMotion;
    private Runnable stopTimeout;
    private int stillSamples;
    private int motionSamples;

    public SmartMotionDetector(SensorManager sensors, Handler handler, long stopTimeoutMs, Listener listener) {
        this.sensors = sensors;
        this.handler = handler;
        this.stopTimeoutMs = stopTimeoutMs;
        this.listener = listener;
    }

    public void start(boolean moving) {
        running = true;
        setMoving(moving);
    }

    /** Tracelet onManualPaceChange reconfigures sensors even if the last answer agrees. */
    public void setMoving(boolean moving) {
        selfMoving = moving;
        cancelStopTimeout();
        stopAccelerometer();
        cancelSignificantMotion();
        stillSamples = motionSamples = 0;
        if (!running) return;
        startAccelerometer(moving);
        if (!moving) armSignificantMotion();
    }

    public void stop() {
        running = false;
        cancelStopTimeout();
        stopAccelerometer();
        cancelSignificantMotion();
    }

    public boolean hasSignificantMotionSensor() {
        return sensors != null && sensors.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION) != null;
    }

    /** A present sensor is insufficient: failed registration must retain the CPU lock. */
    public boolean isSignificantMotionArmed() { return significantMotion != null; }

    private void startAccelerometer(boolean stillness) {
        if (accelerometer != null) return;
        if (sensors == null) {
            listener.onDiagnostic("SensorManager unavailable; retaining the CPU lock", null);
            return;
        }
        Sensor sensor = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        if (sensor == null) {
            listener.onDiagnostic("Accelerometer unavailable", null);
            return;
        }
        SensorEventListener next = new SensorEventListener() {
            private int sampleCount;
            private float lastX, lastY, lastZ;
            @Override public void onSensorChanged(SensorEvent event) {
                if (!running || accelerometer != this) return;
                float x = event.values[0], y = event.values[1], z = event.values[2];
                double magnitude = Math.sqrt(x * x + y * y + z * z) - 9.81;
                sampleCount++;
                if (!stillness) {
                    if (Math.abs(magnitude) > SHAKE_THRESHOLD) declareMoving("accelerometer_shake");
                    return;
                }
                boolean first = sampleCount == 1;
                float dx = x - lastX, dy = y - lastY, dz = z - lastZ;
                double vectorDelta = Math.sqrt(dx * dx + dy * dy + dz * dz);
                lastX = x; lastY = y; lastZ = z;
                if (Math.abs(magnitude) < STILL_THRESHOLD && (first || vectorDelta < STILL_THRESHOLD)) {
                    motionSamples = 0;
                    stillSamples++;
                    if (stillSamples >= STILL_SAMPLE_COUNT && stopTimeout == null) startStopTimeout();
                } else if (stillSamples >= STILL_SAMPLE_COUNT) {
                    motionSamples++;
                    if (motionSamples >= MOTION_ABORT_COUNT) {
                        cancelStopTimeout();
                        stillSamples = motionSamples = 0;
                    }
                } else {
                    stillSamples = 0;
                }
            }
            @Override public void onAccuracyChanged(Sensor sensor, int accuracy) { }
        };
        accelerometer = next;
        try {
            if (!sensors.registerListener(next, sensor, SensorManager.SENSOR_DELAY_NORMAL,
                    stillness ? STILLNESS_BATCH_LATENCY_US : SENSOR_BATCH_LATENCY_US, handler)) {
                accelerometer = null;
                listener.onDiagnostic("Accelerometer listener registration failed", null);
            }
        } catch (RuntimeException error) {
            accelerometer = null;
            listener.onDiagnostic("Registering accelerometer failed", error);
        }
    }

    private void startStopTimeout() {
        cancelStopTimeout();
        stopTimeout = () -> {
            stopTimeout = null;
            if (!running || !selfMoving) return;
            selfMoving = false;
            stopAccelerometer();
            listener.onMotion(false, "accelerometer_stationary");
            if (!running) return;
            startAccelerometer(false);
            armSignificantMotion();
        };
        handler.postDelayed(stopTimeout, stopTimeoutMs);
    }

    private void declareMoving(String reason) {
        if (!running) return;
        selfMoving = true;
        cancelStopTimeout();
        stopAccelerometer();
        cancelSignificantMotion();
        stillSamples = motionSamples = 0;
        listener.onMotion(true, reason);
        if (running && accelerometer == null) startAccelerometer(true);
    }

    private void cancelStopTimeout() {
        if (stopTimeout != null) handler.removeCallbacks(stopTimeout);
        stopTimeout = null;
    }

    private void stopAccelerometer() {
        SensorEventListener old = accelerometer;
        accelerometer = null;
        if (sensors != null && old != null) {
            try { sensors.unregisterListener(old); }
            catch (RuntimeException error) { listener.onDiagnostic("Unregistering Smart accelerometer failed", error); }
        }
    }

    private void armSignificantMotion() {
        if (!running || significantMotion != null || sensors == null) return;
        Sensor sensor = sensors.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION);
        if (sensor == null) {
            listener.onDiagnostic("Significant-motion wake sensor unavailable; retaining the CPU lock", null);
            listener.onWakeAvailabilityChanged();
            return;
        }
        TriggerEventListener next = new TriggerEventListener() {
            @Override public void onTrigger(TriggerEvent event) {
                if (!running || significantMotion != this) return;
                significantMotion = null;
                // Keep the CPU awake before returning the one-shot sensor delivery.
                listener.onWakeAvailabilityChanged();
                declareMoving("significant_motion_wake");
            }
        };
        significantMotion = next;
        try {
            if (!sensors.requestTriggerSensor(next, sensor)) {
                significantMotion = null;
                listener.onDiagnostic("Significant-motion registration failed; retaining the CPU lock", null);
            }
        } catch (RuntimeException error) {
            significantMotion = null;
            listener.onDiagnostic("Registering significant-motion wake sensor failed", error);
        }
        listener.onWakeAvailabilityChanged();
    }

    private void cancelSignificantMotion() {
        TriggerEventListener old = significantMotion;
        significantMotion = null;
        if (old != null && sensors != null) {
            Sensor sensor = sensors.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION);
            if (sensor != null) {
                try { sensors.cancelTriggerSensor(old, sensor); }
                catch (RuntimeException error) { listener.onDiagnostic("Cancelling significant-motion wake sensor failed", error); }
            }
        }
        listener.onWakeAvailabilityChanged();
    }
}
