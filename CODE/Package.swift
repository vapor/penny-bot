// swift-tools-version:5.5
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
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main"),
        .package(url: "https://github.com/soto-project/soto.git", from: "5.12.1"),
        .package(url: "https://github.com/BennyDeBock/Swiftcord", .branch("master")),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "3.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0")
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
                "Swiftcord",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                "PennyModels",
                .product(name: "Vapor", package: "vapor")
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
            dependencies: [
                "Swiftcord"
            ],
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
        /*.testTarget(
            name: "HelloWorldTests",
            dependencies: ["PennyLambdaAddCoins"]),*/
    ]
)
