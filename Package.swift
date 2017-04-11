import PackageDescription

let package = Package(
    name: "GRDB",
    dependencies: [
        .Package(url: "https://github.com/groue/CSQLite.git", majorVersion: 0)
    ],
    exclude: ["GRDB.xcworkspace", "Playgrounds", "SQLCipher", "SQLiteCustom", "Support", "DemoApps", "Tests", "Documentation"]
)
