package com.tencent.map.geolocation.tencent_location_flutter_plugin.smart;

import android.os.Handler;
import android.os.Looper;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;
import java.time.Duration;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import static org.junit.Assert.*;
import static org.robolectric.Shadows.shadowOf;

/** Behavior cases adapted from Tracelet speed-motion and Smart posture regressions. */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33, manifest = Config.NONE)
public class SmartMotionEngineTest {
    SmartMotionEngine engine;
    int changes;
    @Before public void setUp() {
        engine = new SmartMotionEngine(config(1000), new Handler(Looper.getMainLooper()), new SmartMotionEngine.Listener() {
            @Override public void onStateChanged(String reason) { }
            @Override public void onPaceRequested(boolean moving, String reason) { changes++; engine.commitPace(moving); }
        });
        engine.start(Collections.emptyMap(), false);
    }
    static SmartTrackingConfig config(long delay) {
        Map<String, Object> config = new HashMap<>();
        config.put("stopTimeoutMs", 1000L);
        config.put("speedStationaryDelayMs", delay);
        config.put("speedMovingThreshold", 5.0);
        config.put("speedWakeConfirmCount", 3);
        return new SmartTrackingConfig(config);
    }
    private void waitMs(long ms) { shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms)); }

    @Test public void accelStillCannotDropHighWhileVehicleSpeedMoves() {
        engine.onSpeed(20, 0);
        engine.onAccelerometer(false);
        assertTrue(engine.isMoving());
        assertEquals(0, changes);
    }
    @Test public void hysteresisKeepsMovingUntilBelowSixtyFivePercent() {
        engine.onSpeed(4, 0);
        assertEquals("moving", engine.speedState());
        engine.onSpeed(3.2, 0);
        assertEquals("slowing", engine.speedState());
    }
    @Test public void isolatedSpeedNoiseDoesNotResetSlowingCountdown() {
        engine.onAccelerometer(false);
        engine.onSpeed(1, 0);
        engine.onSpeed(8, 0); engine.onSpeed(9, 0);
        waitMs(1000);
        assertEquals("stationary", engine.speedState());
        assertFalse(engine.isMoving());
    }
    @Test public void thirdHighFixAbortsSlowing() {
        engine.onAccelerometer(false);
        engine.onSpeed(1, 0);
        engine.onSpeed(8, 0); engine.onSpeed(9, 0); engine.onSpeed(10, 0);
        waitMs(1000);
        assertEquals("moving", engine.speedState());
        assertTrue(engine.isMoving());
    }
    @Test public void stationarySpeedWakeRequiresConsecutiveFixes() {
        engine.onAccelerometer(false); engine.onSpeed(1, 0); waitMs(1000);
        engine.onSpeed(5, 0); engine.onSpeed(5, 0); engine.onSpeed(0, 0);
        assertFalse(engine.isMoving());
        engine.onSpeed(5, 0); engine.onSpeed(5, 0);
        assertFalse(engine.isMoving());
        engine.onSpeed(5, 0);
        assertTrue(engine.isMoving());
    }
    @Test public void accelerometerWakeDoesNotNeedVehicleSpeed() {
        engine.onAccelerometer(false); engine.onSpeed(1, 0); waitMs(1000);
        engine.onAccelerometer(true);
        assertTrue(engine.isMoving());
        assertEquals("moving", engine.speedState());
    }
    @Test public void freshNearZeroSpeedOverridesTremor() {
        engine.onSpeed(0, 0); waitMs(1000);
        assertFalse(engine.isAccelMoving());
        assertFalse(engine.isMoving());
    }
    @Test public void realFixAgeDoesNotExtendTremorFreshness() {
        engine.onSpeed(0, 9500);
        waitMs(1000);
        assertTrue(engine.isAccelMoving());
        assertTrue(engine.isMoving());
        engine.onAccelerometer(false);
        assertFalse(engine.isMoving());
    }
    @Test public void staleSpeedCannotDriveTheSpeedMachine() {
        engine.onSpeed(0, 10001);
        waitMs(2000);
        assertEquals("moving", engine.speedState());
    }
    @Test public void stopCancelsPostedStationaryTransition() {
        engine.onSpeed(0, 0); engine.stop(); waitMs(2000);
        assertEquals("slowing", engine.speedState());
        assertEquals(0, changes);
    }
    @Test public void restoredContradictoryPostureIsReconciled() {
        engine.stop();
        Map<String, Object> saved = new HashMap<>();
        saved.put("isMoving", true); saved.put("accelerometerMoving", false); saved.put("speedState", "stationary");
        engine.start(saved, true);
        assertFalse(engine.isMoving());
    }
}
