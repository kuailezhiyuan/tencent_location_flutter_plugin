package com.tencent.map.geolocation.tencent_location_flutter_plugin.smart;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.hardware.SensorManager;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import com.tencent.map.geolocation.TencentLocation;
import com.tencent.map.geolocation.TencentLocationManager;
import com.tencent.map.geolocation.TencentLocationManagerOptions;
import com.tencent.map.geolocation.TencentLocationUtils;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.codec.LocationCodec;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.codec.RequestCodec;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.event.EventDispatcher;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Tencent-only native foreground session. Motion/pacing/lock lifecycle adapted from
 * Tracelet 071cd0be service/LocationService.kt and location/LocationEngine.kt (Apache-2.0).
 * It never creates a FlutterEngine. START_STICKY restores consented SDK configuration,
 * the committed pace and both motion inputs in the new Android process.
 */
public class SmartTrackingService extends Service {
    private static final String TAG = "TencentSmart";
    private static final String ACTION_START = "com.tencent.map.geolocation.flutter.SMART_START";
    private static final int NOTIFICATION_ID = 7702;
    private static final String CHANNEL_ID = "tencent_native_smart";
    private static final long LOCK_TIMEOUT_MS = 600_000;
    private static SmartTrackingService active;
    private static EventDispatcher events;
    private static PendingStart pending;

    public interface StartResult {
        void success(Map<String, Object> state);
        void failure(String code, String message, Throwable error);
    }
    private static final class PendingStart {
        final StartResult callback;
        PendingStart(StartResult callback) { this.callback = callback; }
    }

    private final Handler handler = new Handler(Looper.getMainLooper());
    private SmartTrackingStore store;
    private SmartTrackingConfig config;
    private SmartMotionEngine engine;
    private SmartMotionDetector detector;
    private SmartTencentProvider provider;
    private Map<?, ?> movingRequest;
    private Map<?, ?> stationaryRequest;
    private PowerManager.WakeLock wakeLock;
    private Runnable renewal;
    private Runnable paceRetry;
    private boolean starting;
    private boolean stopping;
    private String reason = "idle";
    private long locationCount;
    private Map<String, Object> lastLocation;
    private TencentLocation previousFix;
    private Double speedMps;
    private String speedSource = "unknown";
    private final Map<String, Integer> statuses = new LinkedHashMap<>();

    public static void attach(EventDispatcher dispatcher) { events = dispatcher; }
    public static void detach(EventDispatcher dispatcher) { if (events == dispatcher) events = null; }
    public static boolean isEnabled(Context context) { return new SmartTrackingStore(context).enabled(); }

    public static void start(Context context, Map<String, Object> arguments, StartResult result) {
        if (pending != null || (active != null && active.provider != null && active.provider.isRunning())) {
            result.failure("alreadyStarted", "A native Smart session is already running", null);
            return;
        }
        validateArguments(arguments);
        if (!TencentLocationManager.getUserAgreePrivacy()) {
            result.failure("privacyNotAgreed", "Agree to the Tencent privacy policy before Smart tracking", null);
            return;
        }
        SmartTrackingStore store = new SmartTrackingStore(context);
        if (!store.privacyAgreed()) {
            result.failure("privacyNotAgreed", "Call setPrivacyPolicyAgreement(true) before Smart tracking", null);
            return;
        }
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED
                || (Build.VERSION.SDK_INT >= 29 && ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED)) {
            result.failure("permissionDenied", "Smart background tracking requires precise and Always location permission", null);
            return;
        }
        store.saveSession(arguments);
        PendingStart request = new PendingStart(result);
        pending = request;
        try {
            Intent intent = new Intent(context, SmartTrackingService.class).setAction(ACTION_START);
            ContextCompat.startForegroundService(context, intent);
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                if (pending != request) return;
                pending = null;
                stop(context);
                request.callback.failure("timeout", "Starting the native Smart service timed out", null);
            }, 15_000);
        } catch (RuntimeException error) {
            pending = null;
            try { store.disable(); }
            catch (RuntimeException persistenceError) { error.addSuppressed(persistenceError); }
            Log.e(TAG, "Starting the native Smart foreground service failed", error);
            result.failure("nativeError", "Starting native Smart service failed", error);
        }
    }

    public static void stop(Context context) {
        RuntimeException failure = null;
        try { new SmartTrackingStore(context).disable(); }
        catch (RuntimeException error) {
            Log.e(TAG, "Persisting explicit Smart stop failed", error);
            failure = error;
        }
        PendingStart old = pending;
        pending = null;
        if (old != null) old.callback.failure("nativeError", "Smart start was cancelled by stop", null);
        if (active != null) {
            active.shutdown("stopped");
            active.stopSelf();
        }
        context.stopService(new Intent(context, SmartTrackingService.class));
        if (failure != null) throw failure;
    }

    public static Map<String, Object> state(Context context) {
        if (active != null) return active.snapshot();
        Map<String, Object> result = new LinkedHashMap<>();
        Map<String, Object> saved = new SmartTrackingStore(context).motion();
        result.putAll(saved);
        result.put("enabled", false);
        result.put("isMoving", false);
        result.put("accelerometerMoving", false);
        result.put("speedMoving", false);
        result.put("speedState", "stationary");
        result.put("pace", "low");
        result.put("wakeLockHeld", false);
        result.put("hasSignificantMotionSensor", false);
        result.put("reason", "idle");
        result.put("timestampMs", System.currentTimeMillis());
        result.put("locationCount", 0L);
        result.put("lastLocation", null);
        result.put("speedMps", null);
        result.put("speedSource", "unknown");
        return result;
    }

    public static void validateArguments(Map<?, ?> arguments) {
        Map<?, ?> moving = requiredMap(arguments, "movingRequest");
        Map<?, ?> stationary = requiredMap(arguments, "stationaryRequest");
        new SmartTrackingConfig(requiredMap(arguments, "config"));
        if (RequestCodec.sceneFromMap(moving) != null || RequestCodec.sceneFromMap(stationary) != null) {
            throw new IllegalArgumentException("Smart requests cannot use Android scenes, which override the pace request");
        }
        if (RequestCodec.coordinateTypeFromWire(RequestCodec.coordinateTypeFromMap(moving))
                != RequestCodec.coordinateTypeFromWire(RequestCodec.coordinateTypeFromMap(stationary))) {
            throw new IllegalArgumentException("Smart moving and stationary requests must use the same coordinate type");
        }
        RequestCodec.fromMap(moving);
        RequestCodec.fromMap(stationary);
    }

    private static Map<?, ?> requiredMap(Map<?, ?> arguments, String key) {
        Object value = arguments.get(key);
        if (!(value instanceof Map)) throw new IllegalArgumentException(key + " must be a map");
        return (Map<?, ?>) value;
    }

    @Override public void onCreate() {
        super.onCreate();
        store = new SmartTrackingStore(this);
        active = this;
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (!store.enabled() || !store.privacyAgreed()) {
            shutdown("restart_declined");
            stopSelf();
            return START_NOT_STICKY;
        }
        if (provider != null && provider.isRunning()) return START_STICKY;
        starting = true;
        stopping = false;
        try {
            Map<String, Object> arguments = store.session();
            validateArguments(arguments);
            config = new SmartTrackingConfig(requiredMap(arguments, "config"));
            movingRequest = requiredMap(arguments, "movingRequest");
            stationaryRequest = requiredMap(arguments, "stationaryRequest");
            // Android's foreground-service deadline is satisfied before SDK initialization.
            startForeground(NOTIFICATION_ID, notification());
            acquireLock();
            restoreSdk();
            provider = createProvider(new SmartTencentProvider.Callback() {
                @Override public void onLocation(TencentLocation fix, int error, String message) {
                    if (error != TencentLocation.ERROR_OK || fix == null) {
                        diagnostic("Tencent location error " + error + ": " + message, null);
                    } else {
                        handleLocation(fix);
                    }
                }
                @Override public void onStatus(String name, int status, String description) {
                    Integer previous = statuses.put(name, status);
                    if (previous == null || previous != status) diagnostic("Tencent status " + name + "=" + status + ": " + description, null);
                }
            });
            engine = new SmartMotionEngine(config, handler, new SmartMotionEngine.Listener() {
                @Override public void onStateChanged(String why) {
                    store.saveMotion(engine.snapshot());
                    updateWakelock();
                    if (!"speed_sample".equals(why)) publish(why, null);
                }
                @Override public void onPaceRequested(boolean moving, String why) {
                    if (!starting && !stopping) applyPace(moving, why);
                }
            });
            boolean restore = intent == null || !ACTION_START.equals(intent.getAction());
            engine.start(restore ? store.motion() : Collections.emptyMap(), restore);
            detector = createDetector();
            provider.apply(engine.wantsMoving() ? movingRequest : stationaryRequest);
            engine.commitPace(engine.wantsMoving());
            detector.start(engine.isMoving());
            starting = false;
            updateWakelock();
            store.saveMotion(engine.snapshot());
            publish(restore ? "sticky_restart" : "started", null);
            PendingStart request = pending;
            pending = null;
            if (request != null) request.callback.success(snapshot());
            return START_STICKY;
        } catch (RuntimeException error) {
            Log.e(TAG, "Initializing native Smart tracking failed", error);
            try { store.disable(); }
            catch (RuntimeException persistenceError) { error.addSuppressed(persistenceError); }
            diagnostic("Initializing native Smart tracking failed", error);
            shutdown("startup_failed");
            PendingStart request = pending;
            pending = null;
            if (request != null) request.callback.failure("nativeError", "Initializing native Smart tracking failed", error);
            stopSelf();
            return START_NOT_STICKY;
        }
    }

    protected void restoreSdk() {
        // Agreement is restored only from the user's explicit sdk.setPrivacyPolicyAgreement call.
        TencentLocationManager.setUserAgreePrivacy(store.privacyAgreed());
        String key = store.sdkValue("apiKey");
        if (!key.isEmpty()) TencentLocationManagerOptions.setKey(key);
        String extra = store.sdkValue("extraKey");
        if (!extra.isEmpty()) TencentLocationManagerOptions.setExtraKey(extra);
        String device = store.sdkValue("deviceId");
        if (!device.isEmpty()) TencentLocationManager.getInstance(this).setDeviceID(this, device);
    }

    protected SmartTencentProvider createProvider(SmartTencentProvider.Callback callback) {
        return new SmartTencentProvider(this, callback);
    }

    protected SmartMotionDetector createDetector() {
        return new SmartMotionDetector((SensorManager) getSystemService(SENSOR_SERVICE), handler, config.stopTimeoutMs,
                new SmartMotionDetector.Listener() {
                    @Override public void onMotion(boolean moving, String why) {
                        if (engine == null || stopping) return;
                        reason = why;
                        engine.onAccelerometer(moving);
                        publish(why, null);
                        updateWakelock();
                    }
                    @Override public void onWakeAvailabilityChanged() { updateWakelock(); }
                    @Override public void onDiagnostic(String message, Throwable error) { diagnostic(message, error); }
                });
    }

    private void applyPace(boolean moving, String why) {
        if (stopping || provider == null || engine == null) return;
        if (paceRetry != null) handler.removeCallbacks(paceRetry);
        paceRetry = null;
        if (moving) acquireLock();
        try {
            provider.apply(moving ? movingRequest : stationaryRequest);
            engine.commitPace(moving);
            detector.setMoving(moving);
            store.saveMotion(engine.snapshot());
            updateWakelock();
            publish("pace_" + (moving ? "high" : "low") + ":" + why, null);
        } catch (RuntimeException error) {
            diagnostic("Applying Tencent " + (moving ? "High" : "Low") + " pace failed; retrying", error);
            // Preserve the committed pace and keep the CPU available for the retry.
            acquireLock();
            paceRetry = () -> { paceRetry = null; if (!stopping && store.enabled()) engine.reconcile("pace_retry"); };
            handler.postDelayed(paceRetry, 5_000);
        }
    }

    private void handleLocation(TencentLocation fix) {
        if (stopping || engine == null) return;
        if ((Double.isNaN(fix.getLatitude()) || Double.isInfinite(fix.getLatitude())) || Math.abs(fix.getLatitude()) > 90
                || (Double.isNaN(fix.getLongitude()) || Double.isInfinite(fix.getLongitude())) || Math.abs(fix.getLongitude()) > 180 || fix.getTime() <= 0) {
            diagnostic("Tencent delivered an invalid location", null);
            return;
        }
        long age = System.currentTimeMillis() - fix.getTime();
        // Every Tencent fix is forwarded. The freshness guard belongs to motion evidence only.
        if (age >= 0 && age <= 10_000 && (previousFix == null || fix.getTime() > previousFix.getTime())) {
            double raw = fix.getSpeed();
            Double effective = 0.0;
            String source = "unknown";
            if (!Double.isNaN(raw) && !Double.isInfinite(raw) && raw > 0) {
                effective = raw;
                source = "platform";
            } else if (previousFix != null && fix.getTime() > previousFix.getTime()) {
                double seconds = (fix.getTime() - previousFix.getTime()) / 1000.0;
                effective = TencentLocationUtils.distanceBetween(previousFix, fix) / seconds;
                source = "position_delta";
            }
            // First session fix anchors derivation; stale/out-of-order fixes cannot replace it.
            if (previousFix == null || fix.getTime() > previousFix.getTime()) previousFix = fix;
            speedMps = effective;
            speedSource = source;
            if (effective != null) engine.onSpeed(effective, age);
        }
        locationCount++;
        lastLocation = LocationCodec.toMap(fix);
        if (events != null) events.sendSmartLocation(lastLocation);
    }

    private void updateWakelock() {
        if (stopping || config == null || engine == null) return;
        boolean release = !starting && provider != null && provider.isRunning()
                && !engine.isMoving() && !engine.wantsMoving()
                && config.releaseWakelockWhenStationary && detector != null && detector.isSignificantMotionArmed();
        boolean held = wakeLock != null && wakeLock.isHeld();
        if (release) releaseLock(); else acquireLock();
        if (held != (wakeLock != null && wakeLock.isHeld())) publish(release ? "wakelock_released" : "wakelock_acquired", null);
    }

    private void acquireLock() {
        if (stopping) return;
        if (wakeLock == null || !wakeLock.isHeld()) {
            PowerManager power = (PowerManager) getSystemService(POWER_SERVICE);
            if (power == null) throw new IllegalStateException("PowerManager unavailable");
            String maker = Build.MANUFACTURER.toLowerCase(Locale.ROOT);
            String tag = maker.contains("huawei") || maker.contains("honor") ? "LocationManagerService" : "tencent.smart:location";
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, tag);
            wakeLock.setReferenceCounted(false);
            wakeLock.acquire(LOCK_TIMEOUT_MS);
        }
        // Motion/status updates must not postpone renewal past the existing lock expiry.
        if (renewal != null) return;
        renewal = () -> {
            renewal = null;
            if (!stopping && store.enabled()) {
                // Renew only a lock that policy still wants, never resurrect a stationary lock.
                if (wakeLock != null && wakeLock.isHeld()) wakeLock.acquire(LOCK_TIMEOUT_MS);
                updateWakelock();
            }
        };
        handler.postDelayed(renewal, LOCK_TIMEOUT_MS - 60_000);
    }

    private void releaseLock() {
        if (renewal != null) handler.removeCallbacks(renewal);
        renewal = null;
        PowerManager.WakeLock old = wakeLock;
        wakeLock = null;
        if (old != null && old.isHeld()) old.release();
    }

    private Map<String, Object> snapshot() {
        Map<String, Object> map = engine == null ? new LinkedHashMap<>() : engine.snapshot();
        if (engine == null) {
            map.put("isMoving", false);
            map.put("accelerometerMoving", false);
            map.put("speedMoving", false);
            map.put("speedState", "stationary");
        }
        map.put("enabled", !stopping && !starting && provider != null && provider.isRunning());
        map.put("pace", engine != null && engine.isMoving() ? "high" : "low");
        map.put("wakeLockHeld", wakeLock != null && wakeLock.isHeld());
        map.put("hasSignificantMotionSensor", detector != null && detector.hasSignificantMotionSensor());
        map.put("reason", reason);
        map.put("timestampMs", System.currentTimeMillis());
        map.put("locationCount", locationCount);
        map.put("lastLocation", lastLocation);
        map.put("lastFixAtMs", lastLocation == null ? null : lastLocation.get("time"));
        map.put("speedMps", speedMps);
        map.put("speedSource", speedSource);
        return map;
    }

    private void publish(String why, Throwable error) {
        reason = why;
        Map<String, Object> state = snapshot();
        store.append("state", state, error);
        if (events != null) events.sendSmartState(state);
    }

    private void diagnostic(String message, Throwable error) {
        if (store != null) publish(message, error);
        else Log.e(TAG, message, error);
    }

    private Notification notification() {
        NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26 && manager != null) {
            manager.createNotificationChannel(new NotificationChannel(CHANNEL_ID, config.notificationChannelName, NotificationManager.IMPORTANCE_LOW));
        }
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentTitle(config.notificationTitle).setContentText(config.notificationText)
                .setOngoing(true).setOnlyAlertOnce(true).setCategory(NotificationCompat.CATEGORY_SERVICE);
        Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launch != null) builder.setContentIntent(PendingIntent.getActivity(this, 0, launch, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT));
        return builder.build();
    }

    private void shutdown(String why) {
        if (stopping) return;
        stopping = true;
        starting = false;
        if (paceRetry != null) handler.removeCallbacks(paceRetry);
        paceRetry = null;
        if (engine != null) engine.stop();
        if (detector != null) {
            try { detector.stop(); }
            catch (RuntimeException error) { diagnostic("Stopping Smart motion sensors failed", error); }
        }
        if (provider != null) {
            try { provider.stop(); }
            catch (RuntimeException error) { diagnostic("Stopping Tencent Smart location updates failed", error); }
        }
        releaseLock();
        stopForeground(true);
        publish(why, null);
    }

    @Override public void onDestroy() {
        shutdown("service_destroyed");
        if (active == this) active = null;
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent) { return null; }
}
