## 0.2.2

### New

- **`onGeofenceCreated`**: district (administrative region) geofences are created asynchronously — the `addGeofence` future resolves when the fence is *submitted*, not when it actually takes effect. Subscribers now receive an event (with the original geofence id, and `userInfo` where the platform provides it) once the district geofence has actually been created. Circle / polygon geofences are added synchronously and never emit this event. Unsupported platforms subscribe but receive no events.

### Fix

- **Android**: geofence error events now carry `details.geofenceId` so callers can identify which fence failed (aligned with the iOS payload contract).
- **Android**: the district-fence async semantics are now documented honestly on `addGeofence` — a successful future means "submitted", not "active"; final results arrive via `onGeofenceCreated` (success) or `onError` (failure).
- **Docs**: `TencentGeofence` now documents that Android SDK treats a missing `expiration` as `duration=0` and immediately expires / removes the fence, which makes `getAllGeofences` return empty.

## 0.2.1

### Fix

- Re-include the `example/` app in the published package archive. It is required by the pub.dev scoring check ("Package has an example") and demonstrates the HarmonyOS integration; per-platform build artifacts and local signing material stay excluded via `.pubignore`.

## 0.2.0

### Platform support

- **HarmonyOS**: initial HarmonyOS implementation. Covers SDK bootstrap, continuous / single location, device status, device orientation, background location task, geofence, coordinate conversion. Backed by `@tencentmap/location_sdk` 1.2.0 (ohpm).
- **Android / iOS**: no behavior or API change relative to 0.1.0.

### HarmonyOS capability matrix

| Category | Supported | Not supported (throws `unsupportedOnThisPlatform`) |
| --- | --- | --- |
| SDK config | `setPrivacyPolicyAgreement`, `getPrivacyPolicyAgreement`, `init`, `getVersion`, `getBuildVersion`, `enableLogToFile`, `setExtraData` | `getOaid`, `setRtkLogEnabled`, `setSystemCacheEnabled`, `setUploadGpsForNaviEnabled`, `setLoadLibraryEnabled`, `requestIos*`, `getIosAccuracyAuthorization` |
| Location | `startContinuousLocation`, `stopContinuousLocation`, `startSingleLocation`, `getLastLocation`, `onLocationChanged`, `onLocationError` | `changeCallbackInterval` (stop+start to change the interval), `enableForeground`, `disableForeground` |
| Device status / orientation | `onStatusChanged`, `onOrientationChanged` (subscription-based, no explicit start/stop) | `dismissIosHeadingCalibrationDisplay` |
| Background location | `startBackgroundLocationTask`, `stopBackgroundLocationTask` (HarmonyOS-only) | Custom `wantAgentInfo` is not yet supported; passing a non-null value logs a warning and falls back to the SDK default WantAgent |
| Geofence | Circle geofence `addGeofence`, `removeGeofence`, `removeAllGeofences`, `getAllGeofences`, `onEvent`, `onError` | Polygon / district geofence, `isCoordinateInside`, `geofenceRegionsContainingCoordinate`, `startMonitoring`, `pauseMonitoring`, `resumeMonitoring`, `stopMonitoring`, `setIos*` |
| Utilities | `wgs84ToGcj02`, `distanceBetween` (Dart-only, cross-platform), `contains` (Dart-only, cross-platform) | `isSupportGps`, `isInRegion` |
| SDK log stream | `onSdkLogChanged` accepts subscribers but never emits (the HarmonyOS native SDK does not expose an internal log stream) | — |

### Compatibility

- The stock Flutter tool silently ignores `platforms.ohos` in `pubspec.yaml`; it neither errors nor affects Android / iOS builds. The HarmonyOS backend is only compiled by the HarmonyOS Flutter branch.
- Android / iOS Dart API and method-channel wire schema stay fully backward compatible with 0.1.0.

## 0.1.0

Initial public release.

### Platform support

- **Android**: supported.
- **iOS**: supported.
- **HarmonyOS**: planned, will ship in a later version together with the native implementation. Calling plugin methods on HarmonyOS in this release throws `MissingPluginException`.

> Comments in the public API that describe HarmonyOS behavior refer to the planned final semantics, not the current release.

### Features

- Global SDK config: privacy compliance, key initialization, version info, log switches.
- Continuous location: configurable coordinate system, callback interval, reverse geocoding, device status, device orientation.
- Single location: independent timeout that does not interact with the continuous location stream.
- Geofence: add / remove / query circle and polygon regions, entry / exit / dwell callbacks, monitoring pause / resume, and related iOS-specific tuning parameters.
- Utilities: coordinate conversion, distance between two points, point-in-region check.
- Multi-instance: multiple `TencentLocationManager` / `TencentGeofenceManager` instances can coexist inside a single app with isolated event streams.
