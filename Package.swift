// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnapAPI",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
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
