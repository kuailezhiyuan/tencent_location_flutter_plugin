//
//  TLPGeofenceBridge.m
//  tencent_location_flutter_plugin
//

#import "TLPGeofenceBridge.h"

NSArray<TencentLBSGeofenceRegion *> *TLPGeofenceRegionsContainingCoordinate(
    TencentLBSGeofenceManager *manager, CLLocationCoordinate2D coordinate) {
    return [manager geofenceRegionsContainingCoordinate:coordinate];
}
