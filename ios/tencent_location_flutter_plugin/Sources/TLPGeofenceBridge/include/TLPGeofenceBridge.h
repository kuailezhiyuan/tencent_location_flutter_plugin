//
//  TLPGeofenceBridge.h
//  tencent_location_flutter_plugin
//
//  Swift bridge: ObjC method `geofenceRegionsContainingCoordinate:` 与
//  property `geofenceRegions` 同前缀，Swift 桥接会隐藏方法本身，
//  通过 C 函数暴露该方法，使静态链接器保留桥接实现。
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <TencentLBS/TencentLBSGeofenceManager.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSArray<TencentLBSGeofenceRegion *> *TLPGeofenceRegionsContainingCoordinate(
    TencentLBSGeofenceManager *manager, CLLocationCoordinate2D coordinate);

NS_ASSUME_NONNULL_END
