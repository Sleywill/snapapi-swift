// swift-tools-version: 5.9
import PackageDescription

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
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "SnapAPITests",
            dependencies: ["SnapAPI"],
            path: "Tests/SnapAPITests"
        ),
    ]
)
