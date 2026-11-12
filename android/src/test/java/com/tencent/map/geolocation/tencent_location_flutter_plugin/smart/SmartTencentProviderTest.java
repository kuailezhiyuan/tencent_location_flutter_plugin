package com.tencent.map.geolocation.tencent_location_flutter_plugin.smart;

import android.os.Looper;
import com.tencent.map.geolocation.TencentLocation;
import com.tencent.map.geolocation.TencentLocationListener;
import com.tencent.map.geolocation.TencentLocationManager;
import com.tencent.map.geolocation.TencentLocationRequest;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InOrder;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33, manifest = Config.NONE)
public class SmartTencentProviderTest {
    TencentLocationManager sdk;
    SmartTencentProvider provider;
    List<TencentLocationListener> listeners;
    int delivered;
    @Before public void setUp() {
        sdk = mock(TencentLocationManager.class);
        listeners = new ArrayList<>();
        when(sdk.requestLocationUpdates(any(TencentLocationRequest.class), any(TencentLocationListener.class), any(Looper.class)))
                .thenAnswer(call -> { listeners.add(call.getArgument(1)); return 0; });
        provider = new SmartTencentProvider(sdk, new SmartTencentProvider.Callback() {
            @Override public void onLocation(TencentLocation location, int error, String reason) { delivered++; }
            @Override public void onStatus(String name, int status, String description) { }
        });
    }
    static Map<String,Object> request(long interval) {
        Map<String,Object> request = new HashMap<>();
        Map<String,Object> common = new HashMap<>(); common.put("intervalMs", interval); common.put("coordinateType", "gcj02");
        request.put("common", common); return request;
    }
    @Test public void replacementSubscribesBeforeRetiringOldAndRejectsLateCallbacks() {
        provider.apply(request(1000));
        TencentLocationListener old = listeners.get(0);
        provider.apply(request(60000));
        TencentLocationListener next = listeners.get(1);
        InOrder order = inOrder(sdk);
        order.verify(sdk).setCoordinateType(1);
        order.verify(sdk).requestLocationUpdates(any(TencentLocationRequest.class), eq(old), any(Looper.class));
        order.verify(sdk).setCoordinateType(1);
        order.verify(sdk).requestLocationUpdates(any(TencentLocationRequest.class), eq(next), any(Looper.class));
        order.verify(sdk).removeUpdates(old);
        old.onLocationChanged(null, 0, "late");
        next.onLocationChanged(null, 0, "current");
        assertEquals(1, delivered);
        assertTrue(provider.isRunning());
    }
    @Test public void rejectedReplacementRestoresOldSubscription() {
        provider.apply(request(1000));
        TencentLocationListener old = listeners.get(0);
        when(sdk.requestLocationUpdates(any(TencentLocationRequest.class), any(TencentLocationListener.class), any(Looper.class)))
                .thenAnswer(call -> { TencentLocationListener listener=call.getArgument(1); listeners.add(listener); return listener == old ? 0 : 2; });
        assertThrows(IllegalStateException.class, () -> provider.apply(request(60000)));
        TencentLocationListener rejected = listeners.get(1);
        verify(sdk).removeUpdates(rejected);
        old.onLocationChanged(null,0,"retained"); rejected.onLocationChanged(null,0,"rejected");
        assertEquals(1, delivered); assertTrue(provider.isRunning());
    }
    @Test public void stopInvalidatesCallbacksEvenIfSdkRemovalFailsAndRetriesCleanup() {
        provider.apply(request(1000)); TencentLocationListener old=listeners.get(0);
        doThrow(new IllegalStateException("remove failed")).doNothing().when(sdk).removeUpdates(old);
        assertThrows(IllegalStateException.class, provider::stop);
        old.onLocationChanged(null,0,"late"); assertEquals(0,delivered); assertFalse(provider.isRunning());
        provider.stop(); verify(sdk,times(2)).removeUpdates(old);
    }
}
