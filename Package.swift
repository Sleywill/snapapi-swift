// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnapAPI",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
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
            path: "Sources/SnapAPI"
        ),
        .testTarget(
            name: "SnapAPITests",
            dependencies: ["SnapAPI"],
            path: "Tests/SnapAPITests"
        ),
    ]
)
