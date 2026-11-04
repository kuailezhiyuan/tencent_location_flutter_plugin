import { LocationManagerEntry } from './LocationManagerEntry'

/**
 * `managerId → LocationManagerEntry` 映射，dumb map。与 iOS 端同构。
 *
 * ArkTS 是单线程 event loop，所有 method call 与 native 回调都在主线程串行执行，
 * 因此 Map 不需要锁保护。原生 manager 实例创建（`TencentLocationManager.createInstance`）
 * 与 entry 构造由 handler 完成后再 [put] 进本 registry。
 */
export class LocationManagerRegistry {
  private readonly entries: Map<string, LocationManagerEntry> = new Map()

  /** 获取已注册 entry，未注册返回 null。 */
  get(managerId: string): LocationManagerEntry | null {
    const entry = this.entries.get(managerId)
    return entry === undefined ? null : entry
  }

  /** 注册 entry；同 id 会被覆盖。 */
  put(managerId: string, entry: LocationManagerEntry): void {
    this.entries.set(managerId, entry)
  }

  /** 移除并返回 entry；由调用方负责调用 [LocationManagerEntry.dispose]。 */
  remove(managerId: string): LocationManagerEntry | null {
    const entry = this.entries.get(managerId)
    if (entry === undefined) return null
    this.entries.delete(managerId)
    return entry
  }

  /** 快照（不引用内部 map）。 */
  all(): Array<LocationManagerEntry> {
    return Array.from(this.entries.values())
  }

  /** 清空 registry；调用方负责在此之前 dispose 每一个 entry。 */
  clear(): void {
    this.entries.clear()
  }
}
