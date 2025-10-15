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

let sqlcipherTraitTargetCondition: TargetDependencyCondition? = .when(platforms: darwinPlatforms, traits: ["SQLCipher"])

let sqlcipherTraitBuildSettingCondition: BuildSettingCondition? = .when(platforms: darwinPlatforms, traits: ["SQLCipher"])

var swiftSettings: [SwiftSetting] = [
    .define("SQLITE_ENABLE_FTS5"),
    // Until Xcode has proper support for package traits, we must enable
    // SQLITE_ENABLE_SNAPSHOT by default so that Xcode projects that build
    // a Darwin app can depend on GRDB and profit from WAL snapshots.
    // Package traits who want to disable snapshots must set SQLITE_DISABLE_SNAPSHOT.
    // TODO: when Xcode support traits, remove all mentions of SQLITE_DISABLE_SNAPSHOT and update as below:
    // .define("SQLITE_ENABLE_SNAPSHOT", .when(platforms: darwinPlatforms, traits: ["GRDBSQLite"])),
    .define("SQLITE_ENABLE_SNAPSHOT"),
    .define("SQLITE_HAS_CODEC", sqlcipherTraitBuildSettingCondition),
]

var cSettings: [CSetting] = [
    .define("SQLITE_HAS_CODEC", to: nil, sqlcipherTraitBuildSettingCondition)
]

var dependencies: [PackageDescription.Package.Dependency] = [
    .package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", exact: "4.11.0")
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
        "GRDBSQLite",
        .trait(name: "SQLCipher", description: "Enables SQLCipher encryption when a passphrase is supplied to Database"),
        .default(enabledTraits: ["GRDBSQLite"]),
    ],
    dependencies: dependencies,
    targets: [
        .systemLibrary(
            name: "GRDBSQLite",
            providers: [.apt(["libsqlite3-dev"])]),
        .target(
            name: "GRDBSQLCipher",
            dependencies: [.product(name: "SQLCipher", package: "SQLCipher.swift")]
        ),
        .target(
            name: "GRDB",
            dependencies: [
                .target(name: "GRDBSQLite", condition: .when(traits: ["GRDBSQLite"])),
                .product(name: "SQLCipher", package: "SQLCipher.swift", condition: sqlcipherTraitTargetCondition),
                .target(
                    name: "GRDBSQLCipher",
                    condition: sqlcipherTraitTargetCondition
                )
            ],
            path: "GRDB",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: cSettings,
            swiftSettings: swiftSettings
),
        .testTarget(
            name: "GRDBTests",
            dependencies: ["GRDB"],
            path: "Tests",
            exclude: [
                "CocoaPods",
                "Crash",
                "CustomSQLite",
                "GRDBManualInstall",
                "GRDBTests/getThreadsCount.c",
                "Info.plist",
                "Performance",
                "SPM",
                "Swift6Migration",
                "generatePerformanceReport.rb",
                "parsePerformanceTests.rb",
            ],
            resources: [
                .copy("GRDBTests/Betty.jpeg"),
                .copy("GRDBTests/InflectionsTests.json"),
                .copy("GRDBTests/Issue1383.sqlite"),
                .copy("CocoaPods/SQLCipher4/db.SQLCipher3")
            ],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                // Tests still use the Swift 5 language mode.
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
                .define(
                    "GRDBCIPHER_USE_ENCRYPTION",
                    sqlcipherTraitBuildSettingCondition
                )
            ]
)
    ],
    swiftLanguageModes: [.v6]
)
