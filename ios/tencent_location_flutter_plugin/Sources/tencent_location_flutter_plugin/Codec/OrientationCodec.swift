import CoreLocation

/// 把 ``CLHeading`` 编码为 Flutter 侧的 device orientation Map。
enum OrientationCodec {
    static func toMap(_ heading: CLHeading) -> [String: Any?] {
        return [
            "trueHeading": heading.trueHeading,
            "magneticHeading": heading.magneticHeading,
            "accuracy": heading.headingAccuracy,
            "x": heading.x,
            "y": heading.y,
            "z": heading.z,
            "timestamp": Int(heading.timestamp.timeIntervalSince1970 * 1000.0),
        ]
    }
}
