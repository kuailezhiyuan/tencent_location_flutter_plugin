package com.tencent.map.geolocation.tencent_location_flutter_plugin.smart;

import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.hardware.TriggerEventListener;
import android.os.Handler;
import android.os.Looper;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;
import org.robolectric.shadows.ShadowSensor;
import java.lang.reflect.Constructor;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.robolectric.Shadows.shadowOf;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33, manifest = Config.NONE)
public class SmartMotionDetectorTest {
    SensorManager sensors;
    SmartMotionDetector detector;
    SensorEventListener sampleListener;
    TriggerEventListener trigger;
    boolean triggerAllowed;
    int availabilityChanges;
    List<Boolean> motions;

    @Before public void setUp() {
        sensors = mock(SensorManager.class);
        when(sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)).thenReturn(ShadowSensor.newInstance(Sensor.TYPE_ACCELEROMETER));
        when(sensors.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION)).thenReturn(ShadowSensor.newInstance(Sensor.TYPE_SIGNIFICANT_MOTION));
        when(sensors.registerListener(any(SensorEventListener.class), any(Sensor.class), anyInt(), anyInt(), any(Handler.class)))
                .thenAnswer(call -> { sampleListener = call.getArgument(0); return true; });
        when(sensors.requestTriggerSensor(any(TriggerEventListener.class), any(Sensor.class)))
                .thenAnswer(call -> { trigger = call.getArgument(0); return triggerAllowed; });
        triggerAllowed = true;
        motions = new ArrayList<>();
        detector = new SmartMotionDetector(sensors, new Handler(Looper.getMainLooper()), 1000, new SmartMotionDetector.Listener() {
            @Override public void onMotion(boolean moving, String reason) { motions.add(moving); }
            @Override public void onWakeAvailabilityChanged() { availabilityChanges++; }
            @Override public void onDiagnostic(String message, Throwable error) { }
        });
    }
    void sample(float x, float y, float z) throws Exception {
        Constructor<SensorEvent> c = SensorEvent.class.getDeclaredConstructor(int.class); c.setAccessible(true);
        SensorEvent event = c.newInstance(3); event.values[0]=x;event.values[1]=y;event.values[2]=z;
        sampleListener.onSensorChanged(event);
    }
    void quiet(int count) throws Exception { for (int i=0;i<count;i++) sample(0,0,9.81f); }
    void waitMs(long ms) { shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms)); }

    @Test public void twentyFiveQuietSamplesStartTheConfiguredStopTimeout() throws Exception {
        detector.start(true); quiet(24); waitMs(1000); assertTrue(motions.isEmpty());
        quiet(1); waitMs(999); assertTrue(motions.isEmpty()); waitMs(1);
        assertEquals(java.util.Collections.singletonList(false), motions);
        assertTrue(detector.isSignificantMotionArmed());
    }
    @Test public void rotationAtConstantMagnitudeDoesNotLookStill() throws Exception {
        detector.start(true);
        for(int i=0;i<50;i++) sample(i%2==0?9.81f:0,0,i%2==0?0:9.81f);
        waitMs(2000); assertTrue(motions.isEmpty());
    }
    @Test public void oneNoisySampleDoesNotAbortButFiveDo() throws Exception {
        detector.start(true); quiet(25); sample(0,0,12.5f); quiet(1); waitMs(1000);
        assertEquals(java.util.Collections.singletonList(false), motions);
        motions.clear(); detector.setMoving(true); quiet(25);
        for(int i=0;i<5;i++)sample(0,0,12.5f);
        waitMs(1000); assertTrue(motions.isEmpty());
    }
    @Test public void significantMotionIsOneShotAndRearmsAtNextStationaryPace() {
        detector.start(false); assertTrue(detector.isSignificantMotionArmed());
        trigger.onTrigger(null); assertFalse(detector.isSignificantMotionArmed());
        assertEquals(java.util.Collections.singletonList(true), motions);
        detector.setMoving(false); assertTrue(detector.isSignificantMotionArmed());
        assertTrue(availabilityChanges>=3);
    }
    @Test public void failedTriggerRegistrationNeverClaimsWakeCapability() {
        triggerAllowed=false; detector.start(false);
        assertTrue(detector.hasSignificantMotionSensor());
        assertFalse(detector.isSignificantMotionArmed());
    }
    @Test public void stoppedDetectorRejectsQueuedSensorAndTimerCallbacks() throws Exception {
        detector.start(true); quiet(25); detector.stop(); waitMs(1000);
        sample(0,0,20); assertTrue(motions.isEmpty());
    }
}
