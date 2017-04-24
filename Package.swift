import PackageDescription
import Foundation

let env = ProcessInfo.processInfo.environment

var dependencies: [Package.Dependency] = [
        .Package(url: "https://github.com/groue/CSQLite.git", majorVersion: 0, minor: 2)
]

if env["SOURCERY"] != nil {
    dependencies.append(.Package(url: "https://github.com/krzysztofzablocki/Sourcery.git", majorVersion: 0, minor: 6))
}

let package = Package(
    name: "GRDB",
    dependencies: dependencies,
    exclude: [
        "DemoApps",
        "Documentation",
        "GRDB.xcworkspace",
        "Playgrounds",
        "SQLCipher",
        "SQLiteCustom",
        "Support",
        "Tests/Carthage",
        "Tests/CocoaPods",
        "Tests/Crash",
        "Tests/GRDBCipher",
        "Tests/Performance",
        "Tests/SPM"
    ]
)
