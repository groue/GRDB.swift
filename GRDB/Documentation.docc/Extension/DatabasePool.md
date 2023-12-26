# ``GRDB/DatabasePool``

A database connection that allows concurrent accesses to an SQLite database.

## Usage

Open a `DatabasePool` with the path to a database file:

```swift
import GRDB

let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
```

SQLite creates the database file if it does not already exist. The connection is closed when the database queue gets deallocated.

**A `DatabasePool` can be used from any thread.** The ``DatabaseWriter/write(_:)-76inz`` and ``DatabaseReader/read(_:)-3806d`` methods are synchronous, and block the current thread until your database statements are executed in a protected dispatch queue:

```swift
// Modify the database:
try dbPool.write { db in
    try Player(name: "Arthur").insert(db)
}

// Read values:
try dbPool.read { db in
    let players = try Player.fetchAll(db)
    let playerCount = try Player.fetchCount(db)
}
```

Database access methods can return values:

```swift
let playerCount = try dbPool.read { db in
    try Place.fetchCount(db)
}

let newPlayerCount = try dbPool.write { db -> Int in
    try Player(name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}
```

The ``DatabaseWriter/write(_:)-76inz`` method wraps your database statements in a transaction that commits if and only if no error occurs. On the first unhandled error, all changes are reverted, the whole transaction is rollbacked, and the error is rethrown.

When you don't need to modify the database, prefer the ``DatabaseReader/read(_:)-3806d`` method, because several threads can perform reads in parallel.

When precise transaction handling is required, see <doc:Transactions>.

Asynchronous database accesses are described in <doc:Concurrency>.

`DatabasePool` can take snapshots of the database: see ``DatabaseSnapshot`` and ``DatabaseSnapshotPool``.

`DatabasePool` can be configured with ``Configuration``.

## Concurrency

A `DatabasePool` creates one writer SQLite connection, and a pool of read-only SQLite connections.

Unless ``Configuration/readonly``, the database is set to the [WAL mode](https://sqlite.org/wal.html). The WAL mode makes it possible for reads and writes to proceed concurrently.

All write accesses are executed in a serial **writer dispatch queue**, which means that there is never more than one thread that writes in the database.

All read accesses are executed in **reader dispatch queues** (one per read-only SQLite connection). Reads are generally non-blocking, unless the maximum number of concurrent reads has been reached. In this case, a read has to wait for another read to complete. That maximum number can be configured with ``Configuration/maximumReaderCount``.

SQLite connections are closed when the `DatabasePool` is deallocated.

`DatabasePool` inherits most of its database access methods from the ``DatabaseReader`` and ``DatabaseWriter`` protocols. It defines a few specific database access methods as well, listed below.

A `DatabasePool` needs your application to follow rules in order to deliver its safety guarantees. See <doc:Concurrency> for more information.

## Topics

### Creating a DatabasePool

- ``init(path:configuration:)``

### Accessing the Database

See ``DatabaseReader`` and ``DatabaseWriter`` for more database access methods.

- ``asyncConcurrentRead(_:)``
- ``writeInTransaction(_:_:)``

### Creating Database Snapshots

- ``makeSnapshot()``
- ``makeSnapshotPool()``

### Managing SQLite Connections

- ``invalidateReadOnlyConnections()``
- ``releaseMemory()``
- ``releaseMemoryEventually()``
