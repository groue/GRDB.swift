// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPM",
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "2.0.1"),
    ],
    targets: [
        .target(name: "SPM", dependencies: ["GRDB"]),
    ]
)
