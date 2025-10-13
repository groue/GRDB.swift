// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppDependencies",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v7),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "AppDependencies",
            targets: ["AppDependencies"]),
    ],
    dependencies: [
        .package(
            path: "../../../..",
            traits: ["SQLCipher"])
    ],
    targets: [
        .target(
            name: "AppDependencies",
            dependencies: [
                .product(
                    name: "GRDB",
                    package: "GRDB.swift")
            ]
        )
    ]
)
