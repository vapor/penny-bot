// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    /// `minimal` / `targeted` / `complete`
    .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
]

let package = Package(
    name: "Penny",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Penny", targets: ["Penny"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-server/swift-aws-lambda-runtime.git",
            from: "1.0.0-alpha.1"
        ),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "0.1.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.2.0"),
        .package(url: "https://github.com/mahdibm/DiscordBM.git", exact: "1.0.0-beta.41"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "3.0.0"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.3.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "Penny",
            dependencies: [
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "Backtrace", package: "swift-backtrace"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                "Models",
                "Repositories"
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "AddCoinsLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "SotoDynamoDB", package: "soto"),
                "Extensions",
                "SharedServices",
                "Models",
            ],
            path: "./Lambdas/AddCoin",
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
                "Extensions",
                "SharedServices",
            ],
            path: "./Lambdas/Sponsors",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "AutoPingsLambda",
            dependencies: [
                .product(name: "SotoS3", package: "soto"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                "Extensions",
                "Models",
                "Repositories"
            ],
            path: "./Lambdas/AutoPings",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Extensions",
            dependencies: [
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Models",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Repositories",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "SotoS3", package: "soto"),
                "Models",
                "Extensions"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SharedServices",
            dependencies: [
                "Repositories",
                "Models",
                .product(name: "SotoDynamoDB", package: "soto"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Fake",
            dependencies: [
                "Penny",
                "Repositories",
                "AddCoinsLambda",
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "DiscordBM", package: "DiscordBM"),
            ],
            path: "./Tests/Fake",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "BotTests",
            dependencies: [
                "Penny",
                "Repositories",
                "AddCoinsLambda",
                "Fake",
                .product(name: "SotoDynamoDB", package: "soto"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
