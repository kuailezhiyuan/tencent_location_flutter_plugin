//
//  TLPGeofenceBridge.h
//  tencent_location_flutter_plugin
//
//  Swift bridge: ObjC method `geofenceRegionsContainingCoordinate:` 与
//  property `geofenceRegions` 同前缀，Swift 桥接会隐藏方法本身，
//  这里通过 category 用新名字暴露。
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <TencentLBS/TencentLBSGeofenceManager.h>

NS_ASSUME_NONNULL_BEGIN

@interface TencentLBSGeofenceManager (TLPSwiftBridge)

/// 与原生 `geofenceRegionsContainingCoordinate:` 等价，仅改名以避免 Swift 桥接冲突。tlp：Tencent Location Plugin。
- (NSArray<TencentLBSGeofenceRegion *> *)tlp_geofenceRegionsContainingCoordinate:(CLLocationCoordinate2D)coordinate;

@end

NS_ASSUME_NONNULL_END
