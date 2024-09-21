// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPM",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7),
    ],
    dependencies: [
        .package(name: "GRDB", path: "../../.."),
    ],
    targets: [
        .executableTarget(name: "SPM", dependencies: ["GRDB"]),
    ]
)
