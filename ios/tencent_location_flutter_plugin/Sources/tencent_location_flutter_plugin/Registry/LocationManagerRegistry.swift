import Foundation

/// `managerId → LocationManagerEntry` 的线程安全映射。
final class LocationManagerRegistry {
    private let lock = NSRecursiveLock()
    private var entries: [String: LocationManagerEntry] = [:]

    func get(_ id: String) -> LocationManagerEntry? {
        lock.lock(); defer { lock.unlock() }
        return entries[id]
    }

    func put(_ id: String, _ entry: LocationManagerEntry) {
        lock.lock(); defer { lock.unlock() }
        entries[id] = entry
    }

    func remove(_ id: String) -> LocationManagerEntry? {
        lock.lock(); defer { lock.unlock() }
        return entries.removeValue(forKey: id)
    }

    /// 当前所有 entry 的快照。
    func all() -> [LocationManagerEntry] {
        lock.lock(); defer { lock.unlock() }
        return Array(entries.values)
    }
}
