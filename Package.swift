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
    // Not all Linux distributions have support for WAL snapshots.
    .define("SQLITE_DISABLE_SNAPSHOT", .when(platforms: [.linux])),
    .define("SQLITE_HAS_CODEC", .when(traits: ["SQLCipher"])),
    .define("SQLCipher", .when(traits: ["SQLCipher"])),
]
var cSettings: [CSetting] = [
    .define("SQLITE_HAS_CODEC", .when(traits: ["SQLCipher"])),
]
var dependencies: [PackageDescription.Package.Dependency] = [
    .package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", from: "4.11.0"),
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
        .library(name: "GRDBSQLite", targets: ["GRDBSQLite"]),
        .library(name: "GRDB", targets: ["GRDB"]),
        .library(name: "GRDB-dynamic", type: .dynamic, targets: ["GRDB"]),
    ],
    traits: [
        .default(enabledTraits: ["SQLite"]),
        .trait(
            name: "SQLite",
            description: "Use SQLite without SQLCipher.",
        ),
        .trait(
            name: "SQLCipher",
            description: "Enable SQLCipher.",
        ),
    ],
    dependencies: dependencies,
    targets: [
        .systemLibrary(
            name: "GRDBSQLite",
            providers: [.apt(["libsqlite3-dev"])]),
        .target(
            name: "GRDBSQLCipher",
            dependencies: [
                .product(name: "SQLCipher", package: "SQLCipher.swift", condition: .when(traits: ["SQLCipher"])),
            ]
        ),
        .target(
            name: "GRDB",
            dependencies: [
                .target(name: "GRDBSQLite", condition: .when(traits: ["SQLite"])),
                .product(name: "SQLCipher", package: "SQLCipher.swift", condition: .when(traits: ["SQLCipher"])),
                .target(name: "GRDBSQLCipher", condition: .when(traits: ["SQLCipher"])),
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
