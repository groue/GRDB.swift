// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// Don't rely on those environment variables. They are ONLY testing conveniences:
// $ SQLITE_ENABLE_FTS5=1 SQLITE_ENABLE_PREUPDATE_HOOK=1 make test_SPM
var swiftSettings: [SwiftSetting] = []
var cSettings: [CSetting] = []
if ProcessInfo.processInfo.environment["SQLITE_ENABLE_FTS5"] == "1" {
    swiftSettings.append(.define("SQLITE_ENABLE_FTS5"))
}
if ProcessInfo.processInfo.environment["SQLITE_ENABLE_PREUPDATE_HOOK"] == "1" {
    swiftSettings.append(.define("SQLITE_ENABLE_PREUPDATE_HOOK"))
    cSettings.append(.define("GRDB_SQLITE_ENABLE_PREUPDATE_HOOK"))
}

let package = Package(
    name: "GRDB",
    defaultLocalization: "en", // for tests
    platforms: [
        .iOS(.v11),
        .macOS(.v10_13),
        .tvOS(.v11),
        .watchOS(.v4),
    ],
    products: [
        .library(name: "GRDB", targets: ["GRDB"]),
        .library(name: "GRDB-dynamic", type: .dynamic, targets: ["GRDB"]),
    ],
    dependencies: [
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            providers: [.apt(["libsqlite3-dev"])]),
        .target(
            name: "GRDB",
            dependencies: ["CSQLite"],
            path: "GRDB",
            cSettings: cSettings,
            swiftSettings: swiftSettings),
        .testTarget(
            name: "GRDBTests",
            dependencies: ["GRDB"],
            path: "Tests",
            exclude: [
                "CocoaPods",
                "Crash",
                "CustomSQLite",
                "GRDBTests/getThreadsCount.c",
                "Info.plist",
                "Performance",
                "SPM",
                "generatePerformanceReport.rb",
                "parsePerformanceTests.rb",
            ],
            resources: [
                .copy("GRDBTests/Betty.jpeg"),
                .copy("GRDBTests/InflectionsTests.json"),
            ],
            cSettings: cSettings,
            swiftSettings: swiftSettings)
    ],
    swiftLanguageVersions: [.v5]
)
