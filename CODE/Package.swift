// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PennyAPI",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "PennyLambdaAddCoins", targets: ["PennyLambdaAddCoins"]),
        .executable(name: "PennyBOT", targets: ["PennyBOT"]),
        //.executable(name: "DBMigration", targets: ["DBMigration"]),
        .library(name: "PennyExtensions", targets: ["PennyExtensions"]),
        .library(name: "PennyRepositories", targets: ["PennyRepositories"]),
        .library(name: "PennyModels", targets: ["PennyModels"]),
        .library(name: "PennyServices", targets: ["PennyServices"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", revision: "98a23b64bb5feadf43eed2fc1edf08817d8449b4"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main"),
        .package(url: "https://github.com/soto-project/soto.git", from: "5.12.1"),
        .package(url: "https://github.com/mahdibm/DiscordBM.git", from: "1.0.0-beta.11"),
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
            ]),
//        .executableTarget(
//            name: "DBMigration",
//            dependencies: [
//                .product(name: "SotoDynamoDB", package: "soto"),
//                "PennyExtensions",
//                "PennyServices",
//                "PennyModels",
//            ],
//            resources: [
//                .copy("Data/accounts.txt"),
//                .copy("Data/coins.txt")
//            ]),
        .target(
            name: "PennyExtensions",
            dependencies: [
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "./Sources/PennySHARED/Extensions"),
        .target(
            name: "PennyModels",
            path: "./Sources/PennySHARED/Models"),
        .target(
            name: "PennyRepositories",
            dependencies: [
                .product(name: "SotoDynamoDB", package: "soto"),
                "PennyModels",
                "PennyExtensions"
            ],
            path: "./Sources/PennySHARED/Repositories"),
        .target(
            name: "PennyServices",
            dependencies: [
                "PennyRepositories",
                "PennyModels",
                .product(name: "SotoDynamoDB", package: "soto"),
            ],
            path: "./Sources/PennySHARED/Services"),
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
            ]),
    ]
)
