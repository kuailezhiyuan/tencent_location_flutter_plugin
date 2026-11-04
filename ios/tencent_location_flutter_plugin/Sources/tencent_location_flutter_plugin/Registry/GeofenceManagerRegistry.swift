import Foundation

/// `geofenceManagerId → GeofenceManagerEntry` 的线程安全映射。
final class GeofenceManagerRegistry {
    private let lock = NSRecursiveLock()
    private var entries: [String: GeofenceManagerEntry] = [:]

    func get(_ id: String) -> GeofenceManagerEntry? {
        lock.lock(); defer { lock.unlock() }
        return entries[id]
    }

    func put(_ id: String, _ entry: GeofenceManagerEntry) {
        lock.lock(); defer { lock.unlock() }
        entries[id] = entry
    }

    func remove(_ id: String) -> GeofenceManagerEntry? {
        lock.lock(); defer { lock.unlock() }
        return entries.removeValue(forKey: id)
    }

    func all() -> [GeofenceManagerEntry] {
        lock.lock(); defer { lock.unlock() }
        return Array(entries.values)
    }
}
