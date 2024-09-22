# Swift Concurrency

How to best integrate GRDB and Swift Concurrency 

## Overview

GRDB leverages the strengths of both SQLite and Swift 6 when it comes to concurrency.

For instance, when an application connects to the database using a ``DatabasePool``, it can read from the database and display values on the screen, even while a background task is writing the results of a network request to disk.

On the other hand, application previews and tests can connect to an in-memory ``DatabaseQueue``, which does not support concurrent access, but avoids writing to disk.

To choose the appropriate connection for different situations, applications can use the shared ``DatabaseWriter`` protocol, which ensures the concurrency guarantees described in <doc:Concurrency>. For examples of this integration, see the [demo apps].

Finally, GRDB connections support synchronous database access for applications that prefer not to display a loading screen before showing data on the screen.

Below, you can see the three main types of database access: reads and writes (synchronous or asynchronous), and database observation:

```swift
// Read (synchronous)
let player = try writer.read { db in
    try Player.find(db, id: 42)
}

// Write (asynchronous)
let newPlayerCount = try await writer.write { db in
    try Player(name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}

// Database observation
let observation = ValueObservation.tracking { db in
    try Player.fetchAll(db)
}
for try await players in observation.values(in: writer) {
    print("Fresh players", players)
}
```

Database accesses are handled through closures (as shown with the db argument above). GRDB schedules them optimally, in the best interest of the application.

Depending of the language mode and level of concurrency checkings used by your application (see [Migrating to Swift 6]), you may see warnings or errors. We will address them, and provide general advice below. 

### Usability of global-actor-isolated types

The database access closures can be written explicitly, or with the shorthand notation:

```swift
// Explicit closure
let count = try await writer.read { db in
    try Player.fetchCount(db)
}

// Shorthand notation
let count = try await writer.read(Player.fetchCount)
```

The shorthand notation can trigger a warning with the Swift 6 compiler:

> Compiler warning: Converting non-sendable function value to '@Sendable (Database) throws -> Int' may introduce data races.

You can remove this warning by enabling "Usability of global-actor-isolated types", described in [SE-0434], as below:

**Using Xcode**

Set `SWIFT_UPCOMING_FEATURE_INFER_SENDABLE_FROM_CAPTURES` to `YES` in the build settings of your target.

**In a SwiftPM package manifest**

Enable the "GlobalActorIsolatedTypesUsability" upcoming feature: 

```swift
.target(
    name: "MyTarget",
    swiftSettings: [
        .enableUpcomingFeature("GlobalActorIsolatedTypesUsability")
    ]
)
```


- Sendable record types and the Record class
- databaseSelection, databaseDecodingUserInfo, databaseEncodingUserInfo
- InferSendableFromCaptures
- GlobalActorIsolatedTypesUsability?
- Avoid sync db access methods in async contexts

[demo apps]: https://github.com/groue/GRDB.swift/tree/master/Documentation/DemoApps
[Migrating to Swift 6]: https://www.swift.org/migration/documentation/migrationguide/
[SE-0434]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0434-global-actor-isolated-types-usability.md
