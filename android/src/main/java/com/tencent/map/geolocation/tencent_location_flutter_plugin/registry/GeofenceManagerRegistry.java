package com.tencent.map.geolocation.tencent_location_flutter_plugin.registry;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Collection;
import java.util.concurrent.ConcurrentHashMap;

/** {@code geofenceManagerId → GeofenceManagerEntry} 注册表。线程安全。 */
public class GeofenceManagerRegistry {

    private final ConcurrentHashMap<String, GeofenceManagerEntry> entries =
            new ConcurrentHashMap<>();

    @NonNull
    public GeofenceManagerEntry getOrCreate(
            @NonNull String geofenceManagerId,
            @NonNull EntryFactory factory) {
        GeofenceManagerEntry existing = entries.get(geofenceManagerId);
        if (existing != null) return existing;
        GeofenceManagerEntry created = factory.create(geofenceManagerId);
        GeofenceManagerEntry previous = entries.putIfAbsent(geofenceManagerId, created);
        if (previous != null) {
            created.dispose();
            return previous;
        }
        return created;
    }

    @Nullable
    public GeofenceManagerEntry get(@NonNull String geofenceManagerId) {
        return entries.get(geofenceManagerId);
    }

    @Nullable
    public GeofenceManagerEntry remove(@NonNull String geofenceManagerId) {
        return entries.remove(geofenceManagerId);
    }

    @NonNull
    public Collection<GeofenceManagerEntry> all() {
        return entries.values();
    }

    public void clear() {
        entries.clear();
    }

    public interface EntryFactory {
        @NonNull
        GeofenceManagerEntry create(@NonNull String geofenceManagerId);
    }
}
