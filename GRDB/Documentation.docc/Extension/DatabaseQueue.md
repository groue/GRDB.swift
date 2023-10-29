# ``GRDB/DatabaseQueue``

A database connection that serializes accesses to an SQLite database.

## Usage

Open a `DatabaseQueue` with the path to a database file:

```swift
import GRDB

let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
```

SQLite creates the database file if it does not already exist. The connection is closed when the database queue gets deallocated.

**A `DatabaseQueue` can be used from any thread.** The ``DatabaseWriter/write(_:)-76inz`` and ``DatabaseReader/read(_:)-3806d`` methods are synchronous, and block the current thread until your database statements are executed in a protected dispatch queue:

```swift
// Modify the database:
try dbQueue.write { db in
    try Player(name: "Arthur").insert(db)
}

// Read values:
try dbQueue.read { db in
    let players = try Player.fetchAll(db)
    let playerCount = try Player.fetchCount(db)
}
```

Database access methods can return values:

```swift
let playerCount = try dbQueue.read { db in
    try Place.fetchCount(db)
}

let newPlayerCount = try dbQueue.write { db -> Int in
    try Player(name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}
```

The ``DatabaseWriter/write(_:)-76inz`` method wraps your database statements in a transaction that commits if and only if no error occurs. On the first unhandled error, all changes are reverted, the whole transaction is rollbacked, and the error is rethrown.

When you don't need to modify the database, prefer the ``DatabaseReader/read(_:)-3806d`` method: it prevents any modification to the database.

When precise transaction handling is required, see <doc:Transactions>.

Asynchronous database accesses are described in <doc:Concurrency>.

`DatabaseQueue` can be configured with ``Configuration``.

## In-Memory Databases

`DatabaseQueue` can open a connection to an [in-memory SQLite database](https://www.sqlite.org/inmemorydb.html).

Such connections are quite handy for tests and SwiftUI previews, since you do not have to perform any cleanup of the file system.

```swift
let dbQueue = try DatabaseQueue()
```

In order to create several connections to the same in-memory database, give this database a name:

```swift
// A shared in-memory database
let dbQueue1 = try DatabaseQueue(named: "myDatabase")

// Another connection to the same database
let dbQueue2 = try DatabaseQueue(named: "myDatabase")
```

See ``init(named:configuration:)``.

## Concurrency

A `DatabaseQueue` creates one single SQLite connection. All database accesses are executed in a serial **writer dispatch queue**, which means that there is never more than one thread that uses the database. The SQLite connection is closed when the `DatabaseQueue` is deallocated.

`DatabaseQueue` inherits most of its database access methods from the ``DatabaseReader`` and ``DatabaseWriter`` protocols. It defines a few specific database access methods as well, listed below.

A `DatabaseQueue` needs your application to follow rules in order to deliver its safety guarantees. See <doc:Concurrency> for more information.

## Topics

### Creating a DatabaseQueue

- ``init(named:configuration:)``
- ``init(path:configuration:)``
- ``inMemoryCopy(fromPath:configuration:)``
- ``temporaryCopy(fromPath:configuration:)``

### Accessing the Database

See ``DatabaseReader`` and ``DatabaseWriter`` for more database access methods.

- ``inDatabase(_:)``
- ``inTransaction(_:_:)``

### Managing the SQLite Connection

- ``releaseMemory()``
