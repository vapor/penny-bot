// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    /// `minimal` / `targeted` / `complete`
    .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
]

let package = Package(
    name: "PennyAPI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PennyLambdaAddCoins", targets: ["PennyLambdaAddCoins"]),
        .executable(name: "PennyBOT", targets: ["PennyBOT"]),
        .library(name: "PennyExtensions", targets: ["PennyExtensions"]),
        .library(name: "PennyRepositories", targets: ["PennyRepositories"]),
        .library(name: "PennyModels", targets: ["PennyModels"]),
        .library(name: "PennyServices", targets: ["PennyServices"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha.1"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "0.1.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.2.0"),
        /// Pinning DiscordBM to the latest release/commit since it's in beta.
        /// You can pin it to the newest version if you want.
        .package(
            url: "https://github.com/mahdibm/DiscordBM.git",
            revision: "ceac35a09360c8af2714d8a5c8baa3958e946157"
        ),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "3.0.0"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.3.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "PennyLambdaAddCoins",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "SotoDynamoDB", package: "soto"),
                "PennyExtensions",
                "PennyServices",
                "PennyModels",
            ],
            path: "./Sources/PennyAPI/AddCoin",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "PennyBOT",
            dependencies: [
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "Backtrace", package: "swift-backtrace"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                "PennyModels",
                "PennyRepositories"
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "SponsorLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "SotoSecretsManager", package: "soto"),
                "PennyExtensions",
                "PennyServices",
            ],
            path: "./Sources/PennyAPI/Sponsors",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "AutoPingsLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                "PennyExtensions",
                "PennyServices",
                "PennyModels",
            ],
            path: "./Sources/PennyAPI/AutoPings",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "PennyExtensions",
            dependencies: [
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "./Sources/PennySHARED/Extensions",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "PennyModels",
            path: "./Sources/PennySHARED/Models",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "PennyRepositories",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "SotoS3", package: "soto"),
                "PennyModels",
                "PennyExtensions"
            ],
            path: "./Sources/PennySHARED/Repositories",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "PennyServices",
            dependencies: [
                "PennyRepositories",
                "PennyModels",
                .product(name: "SotoDynamoDB", package: "soto"),
            ],
            path: "./Sources/PennySHARED/Services",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Fake",
            dependencies: [
                "PennyBOT",
                "PennyRepositories",
                "PennyLambdaAddCoins",
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "DiscordBM", package: "DiscordBM"),
            ],
            path: "./Tests/Fake",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "PennyBOTTests",
            dependencies: [
                "PennyBOT",
                "PennyRepositories",
                "PennyLambdaAddCoins",
                "Fake",
                .product(name: "SotoDynamoDB", package: "soto"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
