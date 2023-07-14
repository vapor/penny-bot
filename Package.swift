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
    name: "Penny",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Penny", targets: ["Penny"])
    ],
    dependencies: [
        .package(url: "https://github.com/soto-project/soto.git", from: "6.2.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.3.1"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/DiscordBM/DiscordBM.git", branch: "main"),
        .package(url: "https://github.com/DiscordBM/DiscordLogger.git", from: "1.0.0-rc.1"),
        /// Not-released area:
        .package(url: "https://github.com/apple/swift-markdown.git", .branch("main")),
        .package(
            url: "https://github.com/gwynne/swift-semver",
            from: "0.1.0-alpha.3"
        ),
        .package(
            url: "https://github.com/swift-server/swift-aws-lambda-runtime.git",
            exact: "1.0.0-alpha.1"
        ),
        .package(
            url: "https://github.com/swift-server/swift-aws-lambda-events.git",
            // Use 'from: "0.1.0"' when there is tag higher than "0.1.0"
            revision: "3ac078f4d8fe6d9ae8dd05b680a284a423e1578d"
        ),
        .package(
            url: "https://github.com/mahdibm/swift-openapi-generator",
            // Use the apple repo when command plugin is merged
            branch: "generator-command-plugin"
        ),
        .package(
            url: "https://github.com/swift-server/swift-openapi-async-http-client",
            .upToNextMinor(from: "0.1.0")
        ),
        .package(
            url: "https://github.com/apple/swift-openapi-runtime",
            .upToNextMinor(from: "0.1.0")
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "Penny",
            dependencies: [
                .product(name: "Backtrace", package: "swift-backtrace"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "DiscordLogger", package: "DiscordLogger"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SotoS3", package: "soto"),
                .target(name: "Models")
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "CoinsLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "Collections", package: "swift-collections"),
                .target(name: "Extensions"),
                .target(name: "SharedServices"),
                .target(name: "Models"),
            ],
            path: "./Lambdas/Coins",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "SponsorsLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "SotoSecretsManager", package: "soto"),
                .product(name: "DiscordBM", package: "DiscordBM"),
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
                .product(name: "SotoS3", package: "soto"),
                .target(name: "Extensions"),
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
                .product(name: "SotoS3", package: "soto"),
                .target(name: "Extensions"),
                .target(name: "Models"),
            ],
            path: "./Lambdas/Faqs",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "GHHooksLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "SotoSecretsManager", package: "soto"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "SwiftSemver", package: "swift-semver"),
                .product(name: "Markdown", package: "swift-markdown"),
                .target(name: "GithubAPI"),
                .target(name: "Extensions")
            ],
            path: "./Lambdas/GHHooks",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "GithubAPI",
            dependencies: [
                .product(
                    name: "OpenAPIAsyncHTTPClient",
                    package: "swift-openapi-async-http-client"
                ),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            resources: [
                .copy("openapi-generator-config.yml"),
                .copy("openapi.yaml"),
            ],
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
            name: "SharedServices",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .target(name: "Models"),
                .target(name: "Extensions"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Fake",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .target(name: "Penny"),
            ],
            path: "./Tests/Fake",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "PennyTests",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .target(name: "Penny"),
                .target(name: "GHHooksLambda"),
                .target(name: "Fake"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
