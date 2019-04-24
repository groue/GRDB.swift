Migrating From GRDB 3 to GRDB 4
===============================

GRDB 4 comes with new features, but also a few breaking changes. This guide aims at helping you upgrading your applications.


### New requirements

GRDB now requires Swift 4.2+ and Xcode 10+. Swift 4.0 and 4.1 are no longer supported. Xcode 9 is no longer supported.

iOS 8 is no longer supported. The minimum iOS target is now iOS 9.


### Raw SQL

Whenever your application uses raw SQL queries or snippets, you will now always have to use the `sql` argument label:

```swift
// GRDB 3
try db.execute("INSERT INTO player (name) VALUES (?)", arguments: ["Arthur"])
let playerCount = try Int.fetchOne(db, "SELECT COUNT(*) FROM player")

// GRDB 4
try db.execute(sql: "INSERT INTO player (name) VALUES (?)", arguments: ["Arthur"])
let playerCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player")
```

This change was made necessary by the introduction of [SQL Interpolation].


### ValueObservation

[ValueObservation] had a lifting in GRDB 4.

To guarantee asynchronous notifications, and never ever block your main thread, use the `.async(onQueue:startImmediately:)` scheduling:

```swift
// On main queue
var observation = ValueObservation.trackingAll(Player.all())
observation.scheduling = .async(onQueue: .main, startImmediately: true)
let observer = try observation.start(in: dbQueue) { (players: [Player]) in
    // On main queue
    print("fresh players: \(players)")s
}
// <- here "fresh players" is not printed yet.
```

In GRDB 3, this scheduling used to be named `.queue(_: startImmediately:)`.

The second breaking change is `ValueObservation.extent`, which was removed in GRDB 4. Now all observations last until the observer returned by the `start` method is deallocated.


### SQLCipher

The integration of GRDB with SQLCipher has changed.

With GRDB 3, it was possible to perform a manual installation, or to use CocoaPods and the GRDBCipher pod.

With GRDB 4, CocoaPods is the only supported installation method. And the GRDBCipher pod is discontinued, replaced with GRDB.swift/SQLCipher:

```diff
-pod 'GRDBCipher'
+pod 'GRDB.swift/SQLCipher'
```

In your Swift code, you no longer import the GRDBCipher module, but GRDB:

```diff
-import GRDBCipher
+import GRDB
```

- #497 replaced with #508


### PersistenceError.recordNotFound

PersistenceError.recordNotFound is thrown whenever a record update method does not find any database row to update. It was refactored in GRDB 4:

```swift
public enum PersistenceError: Error {
    case recordNotFound(databaseTableName: String, key: [String: DatabaseValue])
}

do {
    try player.updateChanges { 
        $0.score += 1000
    }
} catch let error as PersistenceError.recordNotFound {
    // Update failed because player does not exist in the database
    print(error)
    // prints "Key not found in table player: [id:42]"
}
```


[SQL Interpolation]: SQLInterpolation.md
[ValueObservation]: ../README.md#valueobservation
