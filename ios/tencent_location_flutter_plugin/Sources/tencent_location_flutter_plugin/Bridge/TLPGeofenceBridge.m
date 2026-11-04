//
//  TLPGeofenceBridge.m
//  tencent_location_flutter_plugin
//

#import "TLPGeofenceBridge.h"

@implementation TencentLBSGeofenceManager (TLPSwiftBridge)

- (NSArray<TencentLBSGeofenceRegion *> *)tlp_geofenceRegionsContainingCoordinate:(CLLocationCoordinate2D)coordinate {
    return [self geofenceRegionsContainingCoordinate:coordinate];
}

@end
