package com.tencent.map.geolocation.tencent_location_flutter_plugin.smart;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.hardware.TriggerEventListener;
import android.os.Handler;
import android.os.Looper;
import com.tencent.map.geolocation.TencentLocation;
import com.tencent.map.geolocation.TencentLocationManager;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.android.controller.ServiceController;
import org.robolectric.annotation.Config;
import org.robolectric.shadows.ShadowSensor;
import java.lang.reflect.Constructor;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.robolectric.Shadows.shadowOf;

/** Actual Service, timers, SensorManager listeners and wakelock policy; only Tencent acquisition is fake. */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33, manifest = Config.NONE)
public class SmartTrackingServiceTest {
    static SensorManager sensors;
    static SensorEventListener sample;
    static TriggerEventListener trigger;
    static boolean triggerAllowed;
    static boolean failApply;
    static FakeProvider currentProvider;
    static int providerCount;
    Context context;
    SmartTrackingStore store;
    ServiceController<TestService> controller;

    public static class TestService extends SmartTrackingService {
        @Override protected void restoreSdk() { /* SDK initialization is replaced at the provider boundary. */ }
        @Override protected SmartTencentProvider createProvider(SmartTencentProvider.Callback callback) {
            providerCount++; currentProvider = new FakeProvider(callback); return currentProvider;
        }
        @Override public Object getSystemService(String name) {
            return Context.SENSOR_SERVICE.equals(name) && sensors != null ? sensors : super.getSystemService(name);
        }
    }
    static class FakeProvider extends SmartTencentProvider {
        boolean running;
        Map<?,?> request;
        Callback callback;
        FakeProvider(Callback callback) { super((TencentLocationManager)null, callback); this.callback=callback; }
        @Override public void apply(Map<?,?> request) { if(failApply)throw new IllegalStateException("Tencent rejected request"); this.request=request; running=true; }
        @Override public boolean isRunning() { return running; }
        @Override public void stop() { running=false; }
        void fix(TencentLocation fix) { callback.onLocation(fix, TencentLocation.ERROR_OK,"OK"); }
    }
    @Before public void setUp() {
        context=RuntimeEnvironment.getApplication();
        context.getSharedPreferences("tencent_native_smart",0).edit().clear().commit();
        store=new SmartTrackingStore(context);
        store.savePrivacy(true); store.saveSession(arguments());
        sensors=mock(SensorManager.class);
        when(sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)).thenReturn(ShadowSensor.newInstance(Sensor.TYPE_ACCELEROMETER));
        when(sensors.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION)).thenReturn(ShadowSensor.newInstance(Sensor.TYPE_SIGNIFICANT_MOTION));
        when(sensors.registerListener(any(SensorEventListener.class),any(Sensor.class),anyInt(),anyInt(),any(Handler.class)))
                .thenAnswer(call->{ sample=call.getArgument(0);return true; });
        when(sensors.requestTriggerSensor(any(TriggerEventListener.class),any(Sensor.class)))
                .thenAnswer(call->{trigger=call.getArgument(0);return triggerAllowed;});
        triggerAllowed=true; failApply=false; providerCount=0;
        SmartTrackingService.attach(null);
    }
    @After public void tearDown() {
        if(controller!=null)controller.destroy();
        sensors=null;
    }
    static Map<String,Object> arguments() {
        Map<String,Object> args=new HashMap<>();
        args.put("movingRequest",SmartTencentProviderTest.request(1000));
        args.put("stationaryRequest",SmartTencentProviderTest.request(60000));
        Map<String,Object> config=new HashMap<>();config.put("stopTimeoutMs",1000);config.put("speedStationaryDelayMs",1000);
        args.put("config",config);return args;
    }
    TestService start(boolean sticky) {
        controller=Robolectric.buildService(TestService.class).create();
        TestService service=controller.get();
        int result=service.onStartCommand(sticky?null:new Intent().setAction("com.tencent.map.geolocation.flutter.SMART_START"),0,1);
        assertEquals(Service.START_STICKY,result); return service;
    }
    Map<String,Object> state() { return SmartTrackingService.state(context); }
    void waitMs(long time) { shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(time)); }
    void zeroFix() { currentProvider.fix(fix(0,System.currentTimeMillis())); }
    static TencentLocation fix(float speed,long time) {
        TencentLocation fix=mock(TencentLocation.class);
        when(fix.getLatitude()).thenReturn(30.0);when(fix.getLongitude()).thenReturn(120.0);
        when(fix.getTime()).thenReturn(time);when(fix.getSpeed()).thenReturn(speed);return fix;
    }
    void quietSamples() throws Exception {
        Constructor<SensorEvent> c=SensorEvent.class.getDeclaredConstructor(int.class);c.setAccessible(true);
        for(int i=0;i<25;i++){SensorEvent event=c.newInstance(3);event.values[2]=9.81f;sample.onSensorChanged(event);}
    }
    @Test public void stickyLowRestoresNativeSubscriptionAndReleasesCpuOnlyAfterWakeSensorArms() {
        Map<String,Object> motion=new HashMap<>();motion.put("accelerometerMoving",false);motion.put("speedState","stationary");motion.put("isMoving",false);
        store.saveMotion(motion);start(true);
        assertEquals("low",state().get("pace"));assertEquals(false,state().get("wakeLockHeld"));
        assertTrue(currentProvider.running);assertEquals(60000,((Number)((Map<?,?>)currentProvider.request.get("common")).get("intervalMs")).intValue());
        assertNotNull(shadowOf(controller.get()).getLastForegroundNotification());
        trigger.onTrigger(null);
        assertEquals("high",state().get("pace"));assertEquals(true,state().get("wakeLockHeld"));
    }
    @Test public void failedWakeRegistrationKeepsCpuEvenWithSensorPresent() {
        triggerAllowed=false;
        Map<String,Object> motion=new HashMap<>();motion.put("accelerometerMoving",false);motion.put("speedState","stationary");motion.put("isMoving",false);
        store.saveMotion(motion);start(true);
        assertEquals("low",state().get("pace"));assertEquals(true,state().get("hasSignificantMotionSensor"));
        assertEquals(true,state().get("wakeLockHeld"));
    }
    @Test public void singleZeroSpeedStartupAnchorCanParkAndCancelLockRenewal() {
        start(false);zeroFix();waitMs(1000);
        assertEquals("low",state().get("pace"));assertEquals("stationary",state().get("speedState"));
        assertEquals(false,state().get("wakeLockHeld"));
        waitMs(600_001);assertEquals(false,state().get("wakeLockHeld"));
    }
    @Test public void highStateUpdatesCannotPostponeCpuLockRenewalBeyondExpiry() {
        start(false);waitMs(120_000);
        currentProvider.fix(fix(20,System.currentTimeMillis()));
        assertEquals(true,state().get("wakeLockHeld"));
        waitMs(480_001);
        assertEquals("high",state().get("pace"));assertEquals(true,state().get("wakeLockHeld"));
    }
    @Test public void accelStationaryCannotReleaseWhileVehicleSpeedStillMoving() throws Exception {
        start(false);currentProvider.fix(fix(20,System.currentTimeMillis()));quietSamples();waitMs(1000);
        assertEquals(false,state().get("accelerometerMoving"));assertEquals("moving",state().get("speedState"));
        assertEquals("high",state().get("pace"));assertEquals(true,state().get("wakeLockHeld"));
    }
    @Test public void staleLocationStillDispatchesButCannotAnchorMotion() {
        start(false);currentProvider.fix(fix(0,System.currentTimeMillis()-10_001));waitMs(2000);
        assertEquals(1L,state().get("locationCount"));assertNotNull(state().get("lastLocation"));
        assertEquals("moving",state().get("speedState"));assertNull(state().get("speedMps"));
        zeroFix();waitMs(1000);assertEquals("low",state().get("pace"));
    }
    @Test public void duplicateAndOutOfOrderLocationsDoNotCountTowardSpeedWake() {
        start(false);zeroFix();waitMs(1000);assertEquals("low",state().get("pace"));
        long now=System.currentTimeMillis();currentProvider.fix(fix(6,now));
        currentProvider.fix(fix(6,now));currentProvider.fix(fix(6,now-1));
        assertEquals("low",state().get("pace"));assertEquals(1,state().get("speedWakeCount"));
        waitMs(1);currentProvider.fix(fix(6,System.currentTimeMillis()));assertEquals("low",state().get("pace"));
        waitMs(1);currentProvider.fix(fix(6,System.currentTimeMillis()));assertEquals("high",state().get("pace"));
    }
    @Test public void explicitStopCannotBeResurrectedByStickyNullIntentOrQueuedTimers() {
        start(false);zeroFix();SmartTrackingService.stop(context);waitMs(600_001);
        assertFalse(store.enabled());assertFalse(currentProvider.running);assertEquals(false,state().get("wakeLockHeld"));
        controller.destroy();controller=Robolectric.buildService(TestService.class).create();
        assertEquals(Service.START_NOT_STICKY,controller.get().onStartCommand(null,0,2));
        assertEquals(1,providerCount);
    }
    @Test public void revokedPrivacyDeclinesColdNativeRestore() {
        store.savePrivacy(false);controller=Robolectric.buildService(TestService.class).create();
        assertEquals(Service.START_NOT_STICKY,controller.get().onStartCommand(null,0,1));assertEquals(0,providerCount);
    }
    @Test public void failedStartupDoesNotLeaveEnabledSessionOrHeldCpu() {
        failApply=true;controller=Robolectric.buildService(TestService.class).create();
        assertEquals(Service.START_NOT_STICKY,controller.get().onStartCommand(null,0,1));
        assertFalse(store.enabled());assertEquals(false,state().get("wakeLockHeld"));assertFalse(currentProvider.running);
    }
    @Test public void requestValidationRejectsCoordinateMismatchAndAndroidScenes() {
        Map<String,Object> args=arguments();
        ((Map<String,Object>)((Map<String,Object>)args.get("stationaryRequest")).get("common")).put("coordinateType","wgs84");
        assertThrows(IllegalArgumentException.class,()->SmartTrackingService.validateArguments(args));
        args.clear();args.putAll(arguments());Map<String,Object> platform=new HashMap<>();platform.put("scene","sport");
        ((Map<String,Object>)args.get("movingRequest")).put("android",platform);
        assertThrows(IllegalArgumentException.class,()->SmartTrackingService.validateArguments(args));
    }
}
