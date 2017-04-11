// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "SPM",
    dependencies: [
        .Package(url: "https://github.com/groue/GRDB.swift.git", majorVersion: 0)
    ]
)
