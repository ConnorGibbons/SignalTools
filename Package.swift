// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SignalTools",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "SignalTools",
            targets: ["SignalTools"]),
    ],
    targets: [
        .target(
            name: "SignalTools"),
        .testTarget(
            name: "SignalToolsTests",
            dependencies: ["SignalTools"]
        ),
    ]
)
