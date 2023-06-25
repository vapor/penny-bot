// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Bug alert! Don't move this constant to the end of the file, or it won't take effect!
/// https://github.com/apple/swift-package-manager/issues/6597
let swiftSettings: [SwiftSetting] = [
    /// `minimal` / `targeted` / `complete`
    /// The only things incompatible with `complete` in Penny are the globally-modifiable vars.
        .unsafeFlags(["-strict-concurrency=targeted"]),

    /// `-enable-upcoming-feature` flags will get removed in the future
    /// and we'll need to remove them from here too.

    /// https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
    /// Require `any` for existential types.
        .enableUpcomingFeature("ExistentialAny"),

    /// https://github.com/apple/swift-evolution/blob/main/proposals/0274-magic-file.md
    /// Nicer `#file`.
        .enableUpcomingFeature("ConciseMagicFile"),

    /// https://github.com/apple/swift-evolution/blob/main/proposals/0286-forward-scan-trailing-closures.md
    /// This one shouldn't do much to be honest, but shouldn't hurt as well.
        .enableUpcomingFeature("ForwardTrailingClosures"),

    /// https://github.com/apple/swift-evolution/blob/main/proposals/0354-regex-literals.md
    /// `BareSlashRegexLiterals` not enabled since we don't use regex anywhere.

    /// https://github.com/apple/swift-evolution/blob/main/proposals/0384-importing-forward-declared-objc-interfaces-and-protocols.md
    /// `ImportObjcForwardDeclarations` not enabled because it's objc-related.
]

let package = Package(
    name: "Lambdas",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Penny", targets: ["Penny"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "0.1.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.2.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.3.1"),
        .package(url: "https://github.com/DiscordBM/DiscordBM.git", branch: "main"),
        .package(url: "https://github.com/DiscordBM/DiscordLogger.git", from: "1.0.0-rc.1"),
        /// Pinning this to the latest release/commit since they're not released.
        .package(
            url: "https://github.com/swift-server/swift-aws-lambda-runtime.git",
            exact: "1.0.0-alpha.1"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "CoinsLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "SotoDynamoDB", package: "soto"),
                .target(name: "Extensions"),
                .target(name: "SharedServices"),
                .target(name: "Models"),
            ],
            path: "./Lambdas/AddCoin",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "Penny",
            dependencies: [
                .product(name: "Backtrace", package: "swift-backtrace"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "DiscordLogger", package: "DiscordLogger"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .target(name: "Models"),
                .target(name: "Repositories"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "SponsorsLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "SotoSecretsManager", package: "soto"),
                .target(name: "Extensions"),
                .target(name: "SharedServices"),
            ],
            path: "./Lambdas/Sponsors",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "AutoPingsLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .target(name: "Extensions"),
                .target(name: "SharedServices"),
                .target(name: "Models"),
            ],
            path: "./Lambdas/AutoPings",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "FaqsLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .target(name: "Extensions"),
                .target(name: "SharedServices"),
                .target(name: "Models"),
            ],
            path: "./Lambdas/Faqs",
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
                .target(name: "Models"),
                .target(name: "Extensions"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SharedServices",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .target(name: "Repositories"),
                .target(name: "Models"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Fake",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .target(name: "Penny"),
                .target(name: "Repositories"),
            ],
            path: "./Tests/Fake",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "PennyTests",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .target(name: "Penny"),
                .target(name: "Repositories"),
                .target(name: "Fake"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
