// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Bug alert! Don't move this constant to the end of the file, or it won't take effect!
/// https://github.com/apple/swift-package-manager/issues/6597
let upcomingFeaturesSwiftSettings: [SwiftSetting] = [
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

let swiftSettings: [SwiftSetting] = upcomingFeaturesSwiftSettings + [
    /// https://github.com/apple/swift/issues/67214
    .unsafeFlags(["-Xllvm", "-vectorize-slp=false"], .when(platforms: [.linux], configuration: .release)),

    /// `minimal` / `targeted` / `complete`
    /// The only things incompatible with `complete` in Penny are the globally-modifiable vars.
    .unsafeFlags(["-strict-concurrency=complete"]),
]

let testsSwiftSettings: [SwiftSetting] = upcomingFeaturesSwiftSettings + [
    /// `minimal` / `targeted` / `complete`
    /// The only things incompatible with `complete` in Penny are the globally-modifiable vars.
    .unsafeFlags(["-strict-concurrency=targeted"]),
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
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.57.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.2.0"),
        .package(url: "https://github.com/soto-project/soto-core.git", branch: "main"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.3.1"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2"),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/vapor/leaf-kit.git", from: "1.10.2"),
        .package(url: "https://github.com/DiscordBM/DiscordBM.git", branch: "main"),
        .package(url: "https://github.com/DiscordBM/DiscordLogger.git", from: "1.0.0-rc.1"),
        /// Not-released area:
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
        .package(
            url: "https://github.com/gwynne/swift-semver",
            from: "0.2.0-alpha.1"
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
            // Use the apple repo when command plugin is merged and tagged
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
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .target(name: "Models"),
                .target(name: "SharedServices"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "UsersLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "Collections", package: "swift-collections"),
                .target(name: "Extensions"),
                .target(name: "SharedServices"),
                .target(name: "Models"),
            ],
            path: "./Lambdas/Users",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "SponsorsLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .target(name: "Extensions"),
                .target(name: "SharedServices"),
                .target(name: "LambdasShared"),
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
                .product(name: "SotoCore", package: "soto-core"),
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
                .product(name: "SotoCore", package: "soto-core"),
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
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "SotoCore", package: "soto-core"),
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
                .target(name: "Extensions"),
                .target(name: "LambdasShared"),
            ],
            path: "./Lambdas/GHHooks",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "GHOAuthLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .target(name: "Extensions"),
                .target(name: "SharedServices"),
                .target(name: "LambdasShared"),
            ],
            path: "./Lambdas/GHOAuth",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "LambdasShared",
            dependencies: [
                .product(name: "SotoSecretsManager", package: "soto"),
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "./Lambdas/LambdasShared",
            swiftSettings: swiftSettings
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
            dependencies: [
                .product(name: "DiscordModels", package: "DiscordBM")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SharedServices",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "SotoCore", package: "soto-core"),
                .target(name: "Models"),
                .target(name: "Extensions"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Rendering",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "LeafKit", package: "leaf-kit"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Fake",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .target(name: "GHHooksLambda"),
                .target(name: "Penny"),
            ],
            path: "./Tests/Fake",
            swiftSettings: testsSwiftSettings
        ),
        .testTarget(
            name: "PennyTests",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "SotoCore", package: "soto-core"),
                .target(name: "Penny"),
                .target(name: "GHHooksLambda"),
                .target(name: "Fake"),
            ],
            swiftSettings: testsSwiftSettings
        ),
    ]
)
