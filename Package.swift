// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GRDB",
    platforms: [
        .iOS("9.0"),
        .macOS("10.10"),
        .tvOS("9.0"),
        .watchOS("2.0"),
    ],
    products: [
        .library(name: "GRDB", targets: ["GRDB"]),
    ],
    dependencies: [
    ],
    targets: [
        .systemLibrary(
            name: "sqlite3",
            providers: [.apt(["libsqlite3-dev"])]),
        .target(
            name: "GRDB",
            dependencies: ["sqlite3"],
            path: "GRDB"),
        .testTarget(
            name: "GRDBTests",
            dependencies: ["GRDB"],
            path: "Tests",
            exclude: [
                "CocoaPods",
                "CustomSQLite",
                "Crash",
                "Performance",
                "SPM",
            ])
    ],
    swiftLanguageVersions: [.v5]
)
