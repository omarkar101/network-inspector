// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkInspectorKit",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "NetworkInspectorKit",
            targets: ["NetworkInspectorKit"]
        )
    ],
    targets: [
        .target(
            name: "NetworkInspectorKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "NetworkInspectorKitTests",
            dependencies: ["NetworkInspectorKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
