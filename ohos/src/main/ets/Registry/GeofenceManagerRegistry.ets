import { GeofenceManagerEntry } from './GeofenceManagerEntry'

/**
 * `geofenceManagerId → GeofenceManagerEntry` 映射，dumb map。与 iOS 端同构。
 *
 * ArkTS 单线程 event loop，无需锁。原生 manager 实例创建与 entry 构造由 handler 完成后再 [put] 进本 registry。
 */
export class GeofenceManagerRegistry {
  private readonly entries: Map<string, GeofenceManagerEntry> = new Map()

  get(geofenceManagerId: string): GeofenceManagerEntry | null {
    const entry = this.entries.get(geofenceManagerId)
    return entry === undefined ? null : entry
  }

  put(geofenceManagerId: string, entry: GeofenceManagerEntry): void {
    this.entries.set(geofenceManagerId, entry)
  }

  remove(geofenceManagerId: string): GeofenceManagerEntry | null {
    const entry = this.entries.get(geofenceManagerId)
    if (entry === undefined) return null
    this.entries.delete(geofenceManagerId)
    return entry
  }

  all(): Array<GeofenceManagerEntry> {
    return Array.from(this.entries.values())
  }

  clear(): void {
    this.entries.clear()
  }
}
