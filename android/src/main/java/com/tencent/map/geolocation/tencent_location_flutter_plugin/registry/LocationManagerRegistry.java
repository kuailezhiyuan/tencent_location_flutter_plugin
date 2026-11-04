package com.tencent.map.geolocation.tencent_location_flutter_plugin.registry;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Collection;
import java.util.concurrent.ConcurrentHashMap;

/**
 * {@code managerId → LocationManagerEntry} 注册表。
 *
 * <p>所有 Flutter 端 {@code TencentLocationManager} 实例的 Listener 都在这里。
 * 线程安全。</p>
 */
public class LocationManagerRegistry {

    private final ConcurrentHashMap<String, LocationManagerEntry> entries =
            new ConcurrentHashMap<>();

    @NonNull
    public LocationManagerEntry getOrCreate(
            @NonNull String managerId,
            @NonNull EntryFactory factory) {
        LocationManagerEntry existing = entries.get(managerId);
        if (existing != null) return existing;
        LocationManagerEntry created = factory.create(managerId);
        LocationManagerEntry previous = entries.putIfAbsent(managerId, created);
        return previous != null ? previous : created;
    }

    @Nullable
    public LocationManagerEntry get(@NonNull String managerId) {
        return entries.get(managerId);
    }

    @Nullable
    public LocationManagerEntry remove(@NonNull String managerId) {
        return entries.remove(managerId);
    }

    @NonNull
    public Collection<LocationManagerEntry> all() {
        return entries.values();
    }

    public void clear() {
        entries.clear();
    }

    public interface EntryFactory {
        @NonNull
        LocationManagerEntry create(@NonNull String managerId);
    }
}
