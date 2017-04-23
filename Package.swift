import PackageDescription

let package = Package(
    name: "GRDB",
    dependencies: [
        .Package(url: "https://github.com/groue/CSQLite.git", majorVersion: 0, minor: 2)
    ],
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
