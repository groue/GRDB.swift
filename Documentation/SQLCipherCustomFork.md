Custom SQLCipher Fork
=====================

The officially supported fork of GRDB w/SQLCipher is available here: `<url to official fork coming soon>`
This fork is maintained by GRDB in collaboration with the SQLCipher team and is the recommended fork to use to enable SQLCipher encryption for GRDB.

If you have requirements that the official fork doesn't support, you're can fork GRDB yourself and include a custom copy of SQLCipher. This guide provides instructions for what is minimally required to get up and running with your fork:

1. [Fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo) GRDB
2. Clone the repository on your machine

```sh
git clone <url to your fork>
```
3. Build the sqlite amalgamation w/SQLCipher (for example using the SQLCipher documentation for [Apple Source Integration](https://www.zetetic.net/sqlcipher/sqlcipher-apple-community/#source-integration)) to generate `sqlite3.c`/`sqlite3.h` files
4. Open the GRDB Package.swift project in Xcode. Create a new Directory named SQLCipher in the Sources directory and move the `sqlite3.c`/`sqlite3.h` files in the directory structure like so

```sh
SQLCipher
├── include
│   ├── module.modulemap
│   ├── SQLCipher
│   │   └── sqlite3.h
│   └── SQLCipher.h
└── sqlite3.c
```

Add a `module.modulemap` file in the `include` directory with these contents

```swift
module SQLCipher {
    umbrella header "SQLCipher.h"
    export *
}
```

Add a `SQLCipher.h` umbrella header file in the `include` directory with these contents

```objc
#ifndef SQLCipher_h
#define SQLCipher_h

#import <SQLCipher/sqlite3.h>
#endif /* SQLCipher_h */
```

6. Modify the `Package.swift` to include the new SQLCipher target and add it as a depdency for GRDB

```swift
        .target(
            name: "GRDB",
            dependencies: [
                // GRDB+SQLCipher: Uncomment the SQLCipher and GRDBSQLCipher dependencies
                .target(name: "SQLCipher"),
                .target(name: "GRDBSQLCipher"),
            ],
            path: "GRDB",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: cSettings,
            swiftSettings: swiftSettings),
        .target(
            name: "SQLCipher",
            publicHeadersPath: "include",
            cSettings: cSettings
        ),
```

7. Add these swiftSettings and cSettings to `Package.swift` (and whatever other flags desired)

```swift
swiftSettings.append(.define("SQLITE_HAS_CODEC"))
swiftSettings.append(.define("SQLCipher"))
```

```swift
cSettings.append(contentsOf: [
    .define("NDEBUG", to: nil),
    .define("SQLCIPHER_CRYPTO_CC", to: nil),
    .define("SQLITE_HAS_CODEC", to: nil),
    .define("SQLITE_TEMP_STORE", to: "2"),
    .define("SQLITE_THREADSAFE", to: "1"),
    .define("SQLITE_EXTRA_INIT", to: "sqlcipher_extra_init"),
    .define("SQLITE_EXTRA_SHUTDOWN", to: "sqlcipher_extra_shutdown"),
    .define("SQLITE_ENABLE_FTS5", to: nil),
    .define("SQLITE_ENABLE_SNAPSHOT", to: nil)
])
```