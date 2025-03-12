// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "StandaloneTests",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "StandaloneTests",
            targets: ["VisualTests"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VisualTests",
            dependencies: [],
            path: "VisualTests"),
        .testTarget(
            name: "VisualTestsTests",
            dependencies: ["VisualTests"],
            path: "VisualTestsTests"),
    ]
)
