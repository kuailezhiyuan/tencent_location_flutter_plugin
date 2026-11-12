package com.tencent.map.geolocation.tencent_location_flutter_plugin.smart;

import android.content.Context;
import android.os.Looper;

import com.tencent.map.geolocation.TencentLocation;
import com.tencent.map.geolocation.TencentLocationListener;
import com.tencent.map.geolocation.TencentLocationManager;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.codec.RequestCodec;

import java.util.Map;
import java.util.ArrayList;
import java.util.List;

/** Tencent-only location acquisition. Each request replacement gets a generation-bound listener. */
public class SmartTencentProvider {
    public interface Callback {
        void onLocation(TencentLocation location, int error, String reason);
        void onStatus(String name, int status, String description);
    }
    private final TencentLocationManager manager;
    private final Callback callback;
    private TencentLocationListener listener;
    private Map<?, ?> request;
    private boolean running;
    private final List<TencentLocationListener> pendingRemoval = new ArrayList<>();

    public SmartTencentProvider(Context context, Callback callback) {
        this(TencentLocationManager.getInstance(context), callback);
    }

    SmartTencentProvider(TencentLocationManager manager, Callback callback) {
        this.manager = manager;
        this.callback = callback;
    }

    /** Applies the acquisition request, restoring the old stream if Tencent rejects replacement. */
    public void apply(Map<?, ?> nextRequest) {
        TencentLocationListener previous = listener;
        Map<?, ?> previousRequest = request;
        TencentLocationListener next = new TencentLocationListener() {
            @Override public void onLocationChanged(TencentLocation location, int error, String reason) {
                if (listener == this && running) callback.onLocation(location, error, reason);
            }
            @Override public void onStatusUpdate(String name, int status, String description) {
                if (listener == this && running) callback.onStatus(name, status, description);
            }
        };
        try {
            manager.setCoordinateType(RequestCodec.coordinateTypeFromWire(RequestCodec.coordinateTypeFromMap(nextRequest)));
            int result = manager.requestLocationUpdates(RequestCodec.fromMap(nextRequest), next, Looper.getMainLooper());
            if (result != 0) throw new IllegalStateException("Tencent requestLocationUpdates rejected Smart pace: " + result);
            // Candidate-first replacement mirrors Tracelet d66d7646: do not stop the old
            // acquisition until Tencent accepted the new request. Late old callbacks fail identity.
            listener = next;
            request = nextRequest;
            running = true;
        } catch (RuntimeException failure) {
            try { manager.removeUpdates(next); }
            catch (RuntimeException cleanupError) { pendingRemoval.add(next); failure.addSuppressed(cleanupError); }
            if (previous != null && previousRequest != null) {
                try {
                    manager.setCoordinateType(RequestCodec.coordinateTypeFromWire(RequestCodec.coordinateTypeFromMap(previousRequest)));
                    int restored = manager.requestLocationUpdates(RequestCodec.fromMap(previousRequest), previous, Looper.getMainLooper());
                    if (restored != 0) throw new IllegalStateException("Tencent rollback request rejected: " + restored);
                    listener = previous;
                    request = previousRequest;
                    running = true;
                } catch (RuntimeException restoreError) {
                    running = false;
                    failure.addSuppressed(restoreError);
                }
            }
            throw failure;
        }
        if (previous != null) {
            try { manager.removeUpdates(previous); }
            catch (RuntimeException cleanupError) {
                // The new request is already active; retain the successful acquisition.
                android.util.Log.e("TencentSmart", "Retiring the previous Tencent listener failed", cleanupError);
                pendingRemoval.add(previous);
            }
        }
    }

    public boolean isRunning() { return running; }

    public void stop() {
        TencentLocationListener old = listener;
        listener = null;
        running = false;
        request = null;
        if (old != null) pendingRemoval.add(old);
        RuntimeException failure = null;
        for (TencentLocationListener retired : new ArrayList<>(pendingRemoval)) {
            try { manager.removeUpdates(retired); pendingRemoval.remove(retired); }
            catch (RuntimeException error) {
                if (failure == null) failure = error; else failure.addSuppressed(error);
            }
        }
        if (failure != null) throw failure;
    }
}
