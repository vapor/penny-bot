// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "0.1.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.2.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "3.0.0"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.3.1"),
        /// Pinning these to the latest release/commit since they're not released.
        /// You can pin them to the newest version if you're not afraid of fixing breaking changes.
        .package(
            url: "https://github.com/mahdibm/DiscordBM.git",
            revision: "2ef02ece1ec1c4cf792d60de23a9dca72902130a"
        ),
        .package(
            url: "https://github.com/swift-server/swift-aws-lambda-runtime.git",
            exact: "1.0.0-alpha.1"
        ),
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
                .product(name: "Backtrace", package: "swift-backtrace"),
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                "PennyModels",
                "PennyRepositories",
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

let swiftSettings: [SwiftSetting] = [
    /// `minimal` / `targeted` / `complete`
    /// The only things incompatible with `complete` in Penny are the globally-modifiable vars.
    .unsafeFlags(["-Xfrontend", "-strict-concurrency=targeted"]),

    /// `-enable-upcoming-feature` flags will get removed in the future
    /// and we'll need to remove them from here too.

    /// https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
    /// Require `any` for existential types.
        .unsafeFlags(["-enable-upcoming-feature", "ExistentialAny"]),

    /// https://github.com/apple/swift-evolution/blob/main/proposals/0274-magic-file.md
    /// Nicer `#file`.
        .unsafeFlags(["-enable-upcoming-feature", "ConciseMagicFile"]),

    /// https://github.com/apple/swift-evolution/blob/main/proposals/0286-forward-scan-trailing-closures.md
    /// This one shouldn't do much to be honest, but shouldn't hurt as well.
        .unsafeFlags(["-enable-upcoming-feature", "ForwardTrailingClosures"]),

    /// https://github.com/apple/swift-evolution/blob/main/proposals/0354-regex-literals.md
    /// `BareSlashRegexLiterals` not enabled since we don't use regex anywhere.

    /// https://github.com/apple/swift-evolution/blob/main/proposals/0384-importing-forward-declared-objc-interfaces-and-protocols.md
    /// `ImportObjcForwardDeclarations` not enabled because it's objc-related.
]
