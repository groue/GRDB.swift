# Swift Concurrency

How to best integrate GRDB and Swift Concurrency 

## Overview

GRDB leverages the strengths of both SQLite and Swift 6 when it comes to concurrency.

For instance, when an application connects to the database using a ``DatabasePool``, it can read from the database and display values on the screen, even while a background task is writing the results of a network request to disk. This is possible because SQLite supports [Write-Ahead Logging].

On the other hand, application previews and tests may prefer to connect to an in-memory ``DatabaseQueue``, which does not support concurrent access, but avoids writing to disk.

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

The Swift 6 compiler ensures that no data races occur during these database accesses.

### Section header


[Write-Ahead Logging]: https://www.sqlite.org/draft/wal.html
[demo apps]: https://github.com/groue/GRDB.swift/tree/master/Documentation/DemoApps
