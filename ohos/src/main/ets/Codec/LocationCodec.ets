import { TencentLocation, TencentGeoAddress, TencentPOI } from '@tencentmap/location_sdk'

import HashMap from '@ohos.util.HashMap'
import { EnumCodec } from './EnumCodec'

/**
 * 鸿蒙 [TencentLocation] → Flutter 侧 map schema。
 *
 * 目标 schema 由 Dart 侧 [TencentLocation.fromMap] 固化：
 * - 通用：`latitude / longitude / altitude / accuracy / bearing / speed /
 *         directionFromSensor / time / source / coordinateType /
 *         geoAddress / poiList / indoorBuildingId / indoorBuildingFloor / extras`
 * - Android 专属：`elapsedRealtime / gpsRssi`（鸿蒙侧恒 `null`）
 * - iOS 专属：`verticalAccuracy`（鸿蒙侧恒 `null`）
 * - Harmony 专属：`cacheSource`（`'none' | 'sdk' | 'system'`）
 *
 * ⚠️ 字段名对齐口径：鸿蒙原生用 `direction` / `timeStamp` / `additionsMap`，
 * Dart 侧统一为 `bearing` / `time` / `extras`，这里做名字翻译。
 *
 * ArkTS 严格模式禁止 untyped object literal，用 `HashMap` 作为 wire map。
 */
export class LocationCodec {
  private constructor() {}

  static toMap(location: TencentLocation, coordinateTypeWire: string): ESObject {
    const map: HashMap<string, ESObject> = new HashMap<string, ESObject>()

    map.set('latitude', LocationCodec.numberOrNull(location.latitude))
    map.set('longitude', LocationCodec.numberOrNull(location.longitude))
    map.set('altitude', LocationCodec.numberOrNull(location.altitude))
    map.set('accuracy', LocationCodec.numberOrNull(location.accuracy))
    map.set('bearing', LocationCodec.numberOrNull(location.direction))
    map.set('speed', LocationCodec.numberOrNull(location.speed))
    map.set('directionFromSensor', LocationCodec.numberOrNull(location.directionFromSensor))
    map.set('time', LocationCodec.numberOrNull(location.timeStamp))
    map.set('source', EnumCodec.locationSourceToWire(location.source))
    map.set('coordinateType', coordinateTypeWire)
    map.set('geoAddress', LocationCodec.buildGeoAddress(location.geoAddress))
    map.set('poiList', LocationCodec.buildPoiList(location.poiList))

    // 鸿蒙原生无室内建筑信息字段，返回 null 与 Dart 默认值兼容。
    map.set('indoorBuildingId', null)
    map.set('indoorBuildingFloor', null)

    // 其他平台专属字段
    map.set('elapsedRealtime', null)
    map.set('gpsRssi', null)
    map.set('verticalAccuracy', null)

    map.set('cacheSource', LocationCodec.readCacheSource(location))
    map.set('extras', LocationCodec.buildExtras(location))

    return map
  }

  private static buildGeoAddress(geo: TencentGeoAddress | undefined): ESObject {
    if (geo === undefined || geo === null) return null
    const map: HashMap<string, ESObject> = new HashMap<string, ESObject>()
    // Dart 侧 `nationCode / areaStat` Android 专属，鸿蒙原生无对应，恒 null。
    map.set('name', LocationCodec.stringOrNull(geo.name))
    map.set('address', LocationCodec.stringOrNull(geo.address))
    map.set('nation', LocationCodec.stringOrNull(geo.nation))
    map.set('nationCode', null)
    map.set('province', LocationCodec.stringOrNull(geo.province))
    map.set('city', LocationCodec.stringOrNull(geo.city))
    map.set('district', LocationCodec.stringOrNull(geo.district))
    map.set('town', LocationCodec.stringOrNull(geo.town))
    map.set('village', LocationCodec.stringOrNull(geo.village))
    map.set('street', LocationCodec.stringOrNull(geo.street))
    map.set('streetNo', LocationCodec.stringOrNull(geo.streetNo))
    map.set('cityCode', LocationCodec.stringOrNull(geo.cityCode))
    map.set('cityPhoneCode', LocationCodec.stringOrNull(geo.cityPhoneCode))
    map.set('areaStat', null)
    return map
  }

  private static buildPoiList(pois: Array<TencentPOI> | undefined): ESObject {
    const list: Array<ESObject> = []
    if (pois === undefined || pois === null) return list
    for (const poi of pois) {
      const map: HashMap<string, ESObject> = new HashMap<string, ESObject>()
      map.set('name', LocationCodec.stringOrNull(poi.name))
      map.set('address', LocationCodec.stringOrNull(poi.address))
      map.set('catalog', LocationCodec.stringOrNull(poi.catalog))
      map.set('distance', LocationCodec.numberOrNull(poi.distance))
      map.set('latitude', LocationCodec.numberOrNull(poi.latitude))
      map.set('longitude', LocationCodec.numberOrNull(poi.longitude))
      map.set('uid', LocationCodec.stringOrNull(poi.uid))
      // 鸿蒙 POI 未暴露 direction 字段，恒 null。
      map.set('direction', null)
      list.push(map)
    }
    return list
  }

  private static buildExtras(location: TencentLocation): ESObject {
    const extras: HashMap<string, ESObject> = new HashMap<string, ESObject>()
    const additionsMap = location.additionsMap
    if (additionsMap !== undefined && additionsMap !== null) {
      additionsMap.forEach((value: string, key: string) => {
        extras.set(key, value)
      })
    }
    if (location.additions !== undefined && location.additions !== null) {
      // 用一个稳定 key 承载数组，避免与 additionsMap 里的键冲突。
      extras.set('additions', location.additions.join(','))
    }
    if (location.additionSize !== undefined) {
      extras.set('additionSize', location.additionSize)
    }
    return extras
  }

  /**
   * 读取 cacheSource。getCacheSource 是接口上的方法，鸿蒙 1.0.8+ 保证存在；
   * 早期版本容错。ArkTS 不支持 `?.()` 链式可选调用，用 try-catch 兜底。
   */
  private static readCacheSource(location: TencentLocation): string {
    try {
      const rawCacheSource: string = location.getCacheSource()
      if (rawCacheSource === 'sdk' || rawCacheSource === 'system' || rawCacheSource === 'none') return rawCacheSource
      return 'none'
    } catch (_error) {
      return 'none'
    }
  }

  private static numberOrNull(value: number | undefined): ESObject {
    return value === undefined || value === null ? null : value
  }

  private static stringOrNull(value: string | undefined): ESObject {
    return value === undefined || value === null ? null : value
  }
}
