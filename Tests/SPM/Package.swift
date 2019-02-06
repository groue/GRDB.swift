// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPM",
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "3.0.0"),
    ],
    targets: [
        .target(name: "SPM", dependencies: ["GRDB"]),
    ]
)
