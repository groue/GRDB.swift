// swift-tools-version:6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let darwinPlatforms: [Platform] = [
    .iOS,
    .macOS,
    .macCatalyst,
    .tvOS,
    .visionOS,
    .watchOS,
]
var swiftSettings: [SwiftSetting] = [
    .define("SQLITE_ENABLE_FTS5"),
    .define("SQLITE_ENABLE_SNAPSHOT"),
    // The amalgamation supplied by swiftlang/swift-toolchain-sqlite is
    // built without SQLITE_ENABLE_SNAPSHOT (its library target declares
    // no cSettings, and SwiftPM does not let us inject them into a binary
    // dependency). The Swift call sites that reference sqlite3_snapshot_*
    // are gated by `#if SQLITE_ENABLE_SNAPSHOT && !SQLITE_DISABLE_SNAPSHOT`,
    // so applying SQLITE_DISABLE_SNAPSHOT unconditionally here keeps GRDB
    // linking on every platform. Trade-off: snapshot-based ValueObservation
    // optimisations are not available — the cost of switching to the
    // swift-toolchain-sqlite route.
    .define("SQLITE_DISABLE_SNAPSHOT"),
]
var cSettings: [CSetting] = [
    // Without SQLITE_CORE, sqlite3ext.h (exposed alongside sqlite3.h by
    // SwiftToolchainCSQLite's modulemap) redefines sqlite3_db_config(...)
    // and sqlite3_config(...) as macros that go through sqlite3_api->...,
    // which is only valid in loadable-extension contexts. shim.c calls
    // those functions directly, so without SQLITE_CORE the macro expansion
    // breaks shim.c's compile. SQLITE_CORE skips that macro block (see
    // sqlite3ext.h: `#if !defined(SQLITE_CORE) && ...`).
    .define("SQLITE_CORE"),
]
var dependencies: [PackageDescription.Package.Dependency] = [
    // Vendors the SQLite amalgamation as a regular SwiftPM target so that
    // GRDB compiles on platforms without a system libsqlite3 — notably
    // Swift's Static Linux SDK (musl-static), where the sysroot ships no
    // sqlite3 and `.systemLibrary` would fail at `#include <sqlite3.h>`.
    .package(url: "https://github.com/swiftlang/swift-toolchain-sqlite", from: "1.0.10"),
]

// Don't rely on those environment variables. They are ONLY testing conveniences:
// $ SQLITE_ENABLE_PREUPDATE_HOOK=1 make test_SPM
if ProcessInfo.processInfo.environment["SQLITE_ENABLE_PREUPDATE_HOOK"] == "1" {
    swiftSettings.append(.define("SQLITE_ENABLE_PREUPDATE_HOOK"))
    cSettings.append(.define("GRDB_SQLITE_ENABLE_PREUPDATE_HOOK"))
}

// The SPI_BUILDER environment variable enables documentation building
// on <https://swiftpackageindex.com/groue/GRDB.swift>. See
// <https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2122>
// for more information.
//
// SPI_BUILDER also enables the `make docs-localhost` command.
if ProcessInfo.processInfo.environment["SPI_BUILDER"] == "1" {
    dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"))
}

// GRDB+SQLCipher: Uncomment those lines
//dependencies.append(.package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", from: "4.11.0"))
//cSettings.append(.define("SQLITE_HAS_CODEC"))
//swiftSettings.append(.define("SQLITE_HAS_CODEC"))
//swiftSettings.append(.define("SQLCipher"))

let package = Package(
    name: "GRDB",
    defaultLocalization: "en", // for tests
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7),
    ],
    products: [
        // GRDB+SQLCipher: Delete the GRDBSQLite library
        .library(name: "GRDBSQLite", targets: ["GRDBSQLite"]),
        .library(name: "GRDB", targets: ["GRDB"]),
        .library(name: "GRDB-dynamic", type: .dynamic, targets: ["GRDB"]),
    ],
    dependencies: dependencies,
    targets: [
        // GRDB+SQLCipher: Delete the GRDBSQLite target
        //
        // Thin shim over swiftlang/swift-toolchain-sqlite. shim.h declares
        // wrappers around variadic sqlite3 calls that Swift can't import;
        // shim.c provides the bodies (compiled with this target's cSettings).
        // The SQLite amalgamation itself comes from the dependency.
        .target(
            name: "GRDBSQLite",
            dependencies: [
                .product(name: "SwiftToolchainCSQLite", package: "swift-toolchain-sqlite"),
            ],
            // shim.h and module.modulemap live at the target root, not in
            // an `include/` subdirectory (SwiftPM's default).
            publicHeadersPath: ".",
            cSettings: cSettings),
        // GRDB+SQLCipher: Uncomment the GRDBSQLCipher target
        //.target(
        //    name: "GRDBSQLCipher",
        //    dependencies: [.product(name: "SQLCipher", package: "SQLCipher.swift")]
        //),
        .target(
            name: "GRDB",
            dependencies: [
                // GRDB+SQLCipher: Delete the GRDBSQLite dependency
                .target(name: "GRDBSQLite"),
                // GRDB+SQLCipher: Uncomment the SQLCipher and GRDBSQLCipher dependencies
                //.product(name: "SQLCipher", package: "SQLCipher.swift"),
                //.target(name: "GRDBSQLCipher"),
            ],
            path: "GRDB",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                .enableUpcomingFeature("MemberImportVisibility"),
            ]),
        .testTarget(
            name: "GRDBTests",
            dependencies: ["GRDB"],
            path: "Tests",
            exclude: [
                "CocoaPods",
                "Crash",
                "CustomSQLite",
                "GRDBManualInstall",
                "GRDBTests/Core/DatabasePool/getThreadsCount.c",
                "Info.plist",
                "Performance",
                "SPM",
                "Swift6Migration",
                "generatePerformanceReport.rb",
                "parsePerformanceTests.rb",
            ],
            resources: [
                .copy("GRDBTests/Betty.jpeg"),
                .copy("GRDBTests/Private/InflectionsTests.json"),
                .copy("GRDBTests/ValueObservation/Issue1383.sqlite"),
                .copy("GRDBTests/GRDBCipher/db.SQLCipher3"),
            ],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                // Tests still use the Swift 5 language mode.
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
            ])
    ],
    swiftLanguageModes: [.v6]
)
