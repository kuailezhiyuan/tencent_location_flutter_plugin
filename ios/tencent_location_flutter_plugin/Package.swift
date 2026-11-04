// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "tencent_location_flutter_plugin",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "tencent-location-flutter-plugin", targets: ["tencent_location_flutter_plugin"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .binaryTarget(
            name: "TencentLBS",
            url: "https://mapapi.qq.com/sdk/locationSDK/iOS/TencentLBS_4.3.1.zip",
            checksum: "a0eb5b51778175ff1749c009a3dd5d99730ac4a700941132246857f9176863e9"
        ),
        .target(name: "TLPGeofenceBridge", dependencies: ["TencentLBS"]),
        .target(
            name: "tencent_location_flutter_plugin",
            dependencies: [
                "TencentLBS",
                "TLPGeofenceBridge",
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [.process("PrivacyInfo.xcprivacy")],
            linkerSettings: [.linkedLibrary("c++")]
        )
    ]
)
