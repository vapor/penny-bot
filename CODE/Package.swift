// swift-tools-version:5.7
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
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", revision: "c915322ecad44006790c72646380a897d3199342"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.2.0"),
        .package(url: "https://github.com/mahdibm/DiscordBM.git", branch: "connection-tests"),
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
            path: "./Sources/PennyAPI/AddCoin"
        ),
        .executableTarget(
            name: "PennyBOT",
            dependencies: [
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "Backtrace", package: "swift-backtrace"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                "PennyModels",
                "PennyRepositories"
            ]
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
            path: "./Sources/PennyAPI/Sponsors"
        ),
        .executableTarget(
            name: "AutoPingLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                "PennyExtensions",
                "PennyServices",
                "PennyModels",
            ],
            path: "./Sources/PennyAPI/AutoPing"
        ),
        .target(
            name: "PennyExtensions",
            dependencies: [
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "./Sources/PennySHARED/Extensions"
        ),
        .target(
            name: "PennyModels",
            path: "./Sources/PennySHARED/Models"
        ),
        .target(
            name: "PennyRepositories",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                .product(name: "SotoS3", package: "soto"),
                "PennyModels",
                "PennyExtensions"
            ],
            path: "./Sources/PennySHARED/Repositories"
        ),
        .target(
            name: "PennyServices",
            dependencies: [
                "PennyRepositories",
                "PennyModels",
                .product(name: "SotoDynamoDB", package: "soto"),
            ],
            path: "./Sources/PennySHARED/Services"
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
            path: "./Tests/Fake"
        ),
        .testTarget(
            name: "PennyBOTTests",
            dependencies: [
                "PennyBOT",
                "PennyRepositories",
                "PennyLambdaAddCoins",
                "Fake",
                .product(name: "SotoDynamoDB", package: "soto"),
            ]
        ),
    ]
)
