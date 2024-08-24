// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPM",
    dependencies: [
        .package(name: "GRDB", path: "../../.."),
    ],
    targets: [
        .executableTarget(name: "SPM", dependencies: ["GRDB"]),
    ]
)
