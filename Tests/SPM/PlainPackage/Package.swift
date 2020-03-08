// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPM",
    dependencies: [
        .package(name: "GRDB", path: "../../.."),
    ],
    targets: [
        .target(name: "SPM", dependencies: ["GRDB"]),
    ]
)
