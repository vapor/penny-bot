// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PennyShared",
    products: [
        .library(name: "Shared", targets: ["PennyShared"])
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "PennyShared",
            dependencies: []),
        .testTarget(
            name: "SHAREDTests",
            dependencies: ["PennyShared"]),
    ]
)
