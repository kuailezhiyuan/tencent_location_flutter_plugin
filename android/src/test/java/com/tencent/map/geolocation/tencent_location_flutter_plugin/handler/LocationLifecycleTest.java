package com.tencent.map.geolocation.tencent_location_flutter_plugin.handler;

import android.app.Notification;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Looper;

import androidx.core.app.NotificationCompat;

import com.tencent.map.geolocation.TencentLocation;
import com.tencent.map.geolocation.TencentLocationListener;
import com.tencent.map.geolocation.TencentLocationManager;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.event.EventDispatcher;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.registry.LocationManagerRegistry;
import com.tencent.map.geolocation.tencent_location_flutter_plugin.util.Errors;

import org.junit.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.MockedConstruction;
import org.mockito.MockedStatic;

import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel.Result;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.nullable;
import static org.mockito.Mockito.RETURNS_SELF;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockConstruction;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.withSettings;

public class LocationLifecycleTest {
    private final Context context = mock(Context.class);
    private final EventDispatcher dispatcher = mock(EventDispatcher.class);
    private final TencentLocationManager manager = mock(TencentLocationManager.class);

    @Test
    public void disposeCancelsOnlyItsOwnSingleRequest() {
        try (MockedStatic<TencentLocationManager> sdk = mockStatic(TencentLocationManager.class)) {
            sdk.when(() -> TencentLocationManager.getInstance(context)).thenReturn(manager);
            LocationHandler handler = new LocationHandler(context, dispatcher, new LocationManagerRegistry());
            Map<String, Object> first = Map.of("managerId", "first", "request", Map.of());
            Map<String, Object> second = Map.of("managerId", "second", "request", Map.of());
            Result firstResult = mock(Result.class);
            Result secondResult = mock(Result.class);

            handler.handle(new MethodCall("manager.create", first), mock(Result.class));
            handler.handle(new MethodCall("manager.create", second), mock(Result.class));
            handler.handle(new MethodCall("location.startSingle", first), firstResult);
            handler.handle(new MethodCall("location.startSingle", second), secondResult);

            ArgumentCaptor<TencentLocationListener> listeners = ArgumentCaptor.forClass(TencentLocationListener.class);
            verify(manager, times(2)).requestSingleFreshLocation(any(), listeners.capture(), nullable(Looper.class));
            TencentLocationListener firstListener = listeners.getAllValues().get(0);
            TencentLocationListener secondListener = listeners.getAllValues().get(1);

            handler.handle(new MethodCall("manager.dispose", first), mock(Result.class));
            verify(manager).removeUpdates(firstListener);
            verify(manager, never()).removeUpdates(secondListener);
            verify(firstResult).error(Errors.LOCATION_FAILED, "Location manager was disposed", null);
            verifyNoInteractions(secondResult);

            firstListener.onLocationChanged(null, TencentLocation.ERROR_FIRST_TIMEOUT, "late callback");
            verifyNoMoreInteractions(firstResult);
            secondListener.onLocationChanged(null, TencentLocation.ERROR_FIRST_TIMEOUT, "timeout");
            verify(secondResult).error(Errors.LOCATION_FAILED, "Single location failed: timeout",
                    TencentLocation.ERROR_FIRST_TIMEOUT);
        }
    }

    @Test
    public void registersSdkLogsAfterConsentAndInitialization() {
        AtomicBoolean consent = new AtomicBoolean();
        try (MockedStatic<TencentLocationManager> sdk = mockStatic(TencentLocationManager.class)) {
            sdk.when(TencentLocationManager::getUserAgreePrivacy).thenAnswer(call -> consent.get());
            sdk.when(() -> TencentLocationManager.getInstance(context)).thenReturn(manager);
            sdk.when(() -> TencentLocationManager.setUserAgreePrivacy(true)).thenAnswer(call -> {
                consent.set(true);
                return null;
            });

            SdkHandler handler = new SdkHandler(context, dispatcher);
            MethodCall agree = new MethodCall("sdk.setPrivacyPolicyAgreement", Map.of("agreed", true));
            handler.handle(agree, mock(Result.class));
            verifyNoInteractions(manager);

            handler.handle(new MethodCall("sdk.init", Map.of()), mock(Result.class));
            handler.handle(agree, mock(Result.class));
            verify(manager).setSDKLogListener(any());

            handler.dispose();
            verify(manager).setSDKLogListener(null);
        }
    }

    @Test
    public void foregroundUsesTheAppIconAndStopsAfterTheLastOwner() {
        ApplicationInfo appInfo = new ApplicationInfo();
        appInfo.icon = android.R.drawable.ic_menu_compass;
        when(context.getApplicationInfo()).thenReturn(appInfo);
        Notification notification = mock(Notification.class);
        try (MockedStatic<TencentLocationManager> sdk = mockStatic(TencentLocationManager.class);
             MockedConstruction<NotificationCompat.Builder> builders = mockConstruction(
                     NotificationCompat.Builder.class, withSettings().defaultAnswer(RETURNS_SELF),
                     (builder, context) -> when(builder.build()).thenReturn(notification))) {
            sdk.when(TencentLocationManager::getUserAgreePrivacy).thenReturn(true);
            sdk.when(() -> TencentLocationManager.getInstance(context)).thenReturn(manager);
            LocationHandler handler = new LocationHandler(context, dispatcher, new LocationManagerRegistry());
            Result enableResult = mock(Result.class);
            for (String id : new String[]{"first", "second"}) {
                handler.handle(new MethodCall("manager.create", Map.of("managerId", id)), mock(Result.class));
                handler.handle(new MethodCall("location.android.enableForeground", Map.of(
                        "managerId", id, "notificationId", 1, "channelId", "location",
                        "title", "Recording", "text", "Recording location")), enableResult);
            }

            verify(enableResult, times(2)).success(null);
            verify(builders.constructed().get(0)).setSmallIcon(appInfo.icon);
            verify(manager).enableForegroundLocation(1, notification);
            handler.handle(new MethodCall("manager.dispose", Map.of("managerId", "first")), mock(Result.class));
            verify(manager, never()).disableForegroundLocation(anyBoolean());
            handler.handle(new MethodCall("manager.dispose", Map.of("managerId", "second")), mock(Result.class));
            verify(manager).disableForegroundLocation(true);
        }
    }
}
