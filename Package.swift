// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Penny",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.57.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.1.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.1"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2"),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/vapor/leaf-kit.git", from: "1.10.2"),
        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.7.0"),
        .package(url: "https://github.com/gwynne/swift-semver.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        .package(url: "https://github.com/DiscordBM/DiscordBM.git", branch: "main"),
        .package(url: "https://github.com/DiscordBM/DiscordLogger.git", from: "1.0.0-rc.2"),
        .package(url: "https://github.com/soto-project/soto.git", from: "7.3.0"),
        .package(url: "https://github.com/soto-project/soto-core.git", from: "7.3.0"),
        /// Not-released area:
        .package(url: "https://github.com/swiftlang/swift-evolution-metadata-extractor.git", from: "0.1.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.1"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "2.0.0-beta.3"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "1.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "Penny",
            dependencies: [
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "DiscordLogger", package: "DiscordLogger"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "EvolutionMetadataModel", package: "swift-evolution-metadata-extractor"),
                .target(name: "Rendering"),
                .target(name: "Shared"),
                .target(name: "Models"),
            ],
            swiftSettings: upcomingFeaturesSwiftSettings
        ),
        .lambdaTarget(
            name: "Users",
            additionalDependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .lambdaTarget(
            name: "Sponsors",
            additionalDependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .target(name: "Shared"),
            ]
        ),
        .lambdaTarget(
            name: "AutoPings",
            additionalDependencies: [
                .product(name: "SotoS3", package: "soto")
            ]
        ),
        .lambdaTarget(
            name: "Faqs",
            additionalDependencies: [
                .product(name: "SotoS3", package: "soto")
            ]
        ),
        .lambdaTarget(
            name: "AutoFaqs",
            additionalDependencies: [
                .product(name: "SotoS3", package: "soto")
            ]
        ),
        .lambdaTarget(
            name: "GHHooks",
            additionalDependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "SwiftSemver", package: "swift-semver"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "LeafKit", package: "leaf-kit"),
                .target(name: "GitHubAPI"),
                .target(name: "Rendering"),
                .target(name: "Shared"),
            ]
        ),
        .lambdaTarget(
            name: "GHOAuth",
            additionalDependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .target(name: "Shared"),
            ]
        ),
        .target(
            name: "LambdasShared",
            dependencies: [
                .product(name: "SotoSecretsManager", package: "soto"),
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .target(name: "Shared"),
            ],
            path: "./Lambdas/LambdasShared",
            swiftSettings: upcomingFeaturesSwiftSettings
        ),
        .target(
            name: "GitHubAPI",
            dependencies: [
                .product(
                    name: "OpenAPIAsyncHTTPClient",
                    package: "swift-openapi-async-http-client"
                ),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "./Lambdas/GitHubAPI",
            resources: [
                .copy("openapi-generator-config.yaml"),
                .copy("openapi.yaml"),
            ],
            swiftSettings: upcomingFeaturesSwiftSettings
        ),
        .target(
            name: "Models",
            dependencies: [
                .product(name: "DiscordModels", package: "DiscordBM")
            ],
            swiftSettings: upcomingFeaturesSwiftSettings
        ),
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .target(name: "Models"),
            ],
            swiftSettings: upcomingFeaturesSwiftSettings
        ),
        .target(
            name: "Rendering",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "LeafKit", package: "leaf-kit"),
                .target(name: "Shared"),
            ],
            swiftSettings: upcomingFeaturesSwiftSettings
        ),
        .testTarget(
            name: "PennyTests",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "LeafKit", package: "leaf-kit"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SwiftSemver", package: "swift-semver"),
                .product(name: "DiscordLogger", package: "DiscordLogger"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(
                    name: "EvolutionMetadataModel",
                    package: "swift-evolution-metadata-extractor"
                ),
                .target(name: "GitHubAPI"),
                .target(name: "LambdasShared"),
                .target(name: "Shared"),
                .target(name: "Rendering"),
                .target(name: "Models"),
                .target(name: "Penny"),
                .target(name: "GHHooksLambda"),
            ],
            swiftSettings: upcomingFeaturesSwiftSettings
        ),
    ]
)

/// Bug alert! Don't make this a constant, or it won't take effect!
/// https://github.com/apple/swift-package-manager/issues/6597
var upcomingFeaturesSwiftSettings: [SwiftSetting] {
    [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("FullTypedThrows"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InternalImportsByDefault"),
    ]
}

extension PackageDescription.Target {
    @MainActor
    static func lambdaTarget(
        name: String,
        additionalDependencies: [PackageDescription.Target.Dependency]
    ) -> PackageDescription.Target {
        .executableTarget(
            name: "\(name)Lambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "Logging", package: "swift-log"),
                .target(name: "LambdasShared"),
                .target(name: "Models"),
            ] + additionalDependencies,
            path: "./Lambdas/\(name)",
            swiftSettings: upcomingFeaturesSwiftSettings
        )
    }
}
