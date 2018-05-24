// swift-tools-version:4.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GRDB",
    products: [
        .library(name: "GRDB", targets: ["GRDB"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/CSQLite.git", from: "0.2.0"),
    ],
    targets: [
        .target(name: "GRDB", path: "GRDB"),
        .testTarget(
            name: "GRDBTests",
            dependencies: ["GRDB"],
            path: "Tests",
            exclude: [
                "Carthage",
                "CocoaPods",
                "Crash",
                "GRDBCipher",
                "Performance",
                "SPM"
            ])
    ]
)
