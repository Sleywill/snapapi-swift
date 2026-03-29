// swift-tools-version: 5.9
import PackageDescription

// On Swift 5.9/5.10 we opt-in to strict concurrency checking explicitly.
// Swift 6 enforces it by default, so no extra setting is needed there.
#if swift(>=6.0)
let swiftSettings: [SwiftSetting] = []
#else
let swiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]
#endif

let package = Package(
    name: "SnapAPI",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "SnapAPI",
            targets: ["SnapAPI"]
        ),
    ],
    targets: [
        .target(
            name: "SnapAPI",
            dependencies: [],
            path: "Sources/SnapAPI",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SnapAPITests",
            dependencies: ["SnapAPI"],
            path: "Tests/SnapAPITests",
            swiftSettings: swiftSettings
        ),
    ]
)
