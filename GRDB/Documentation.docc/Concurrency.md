# Concurrency

GRDB helps your app deal with Swift and SQLite concurrency.

## Overview

If your app moves slow database jobs off the main thread, so that the user interface remains responsive, then this guide is for you. In the case of apps that share a database with other processes, such as an iOS app and its extensions, don't miss the dedicated <doc:DatabaseSharing> guide after this one.

**In all cases, and first and foremost, follow the <doc:Concurrency#Concurrency-Rules> right from the start.**

The other chapters cover, with more details, the fundamentals of SQLite concurrency, and how GRDB makes it manageable from your Swift code.

## Concurrency Rules

**The two concurrency rules are strongly recommended practices.** They are all about SQLite, a robust and reliable database that takes great care of your data: don't miss an opportunity to put it on your side!

#### Rule 1: Connect to any database file only once

Open one single ``DatabaseQueue`` or ``DatabasePool`` per database file, for the whole duration of your use of the database. Not for the duration of _each_ database access, but really for the duration of _all_ database accesses to this file.

- *Why does this rule exist?* - Since SQLite does not support parallel writes, each `DatabaseQueue` and `DatabasePool` makes sure application threads perform writes one by one, without overlap.

- *Practical advice* - An app that uses a single database will connect only once. A document-based app will connect each time a document is opened, and disconnect when the document is closed. See the [demo apps] in order to see how to setup a UIKit or SwiftUI application for a single database.

- *What if you do not follow this rule?*
    
    - You will not be able to use the <doc:DatabaseObservation> features.
    - You will see SQLite errors ([`SQLITE_BUSY`]).

#### Rule 2: Mind your transactions

Database operations that are grouped in a transaction are guaranteed to be either fully saved on disk, or not at all. Read-only transactions guarantee a stable and immutable view of the database, and do not see changes performed by eventual concurrent writes.

In other words, transactions are the one and single tool that helps you enforce and rely on the invariants of your database (such as "all authors must have at least one book").

**You are responsible**, in your Swift code, for delimiting transactions. You do so by grouping database accesses inside a pair of `{ db in ... }` brackets:

```swift
try dbQueue.write { db in
    // Inside a transaction
}

try dbQueue.read { db
    // Inside a transaction
}
```

Alternatively, you can open an explicit transaction or savepoint: see <doc:Transactions>.

- *Why does this rule exist?* - Because GRDB and SQLite can not guess where to insert the transaction boundaries that protect the invariants of your database. This is your task. Transactions also avoid concurrency problems, as described in the <doc:Concurrency#Safe-and-Unsafe-Database-Accesses> section below. 

- *Practical advice* - Take the time to identify the invariants of your database. Some of them can be enforced in the database schema itself, such as "all books must have a non-empty title", or "all books must have an author" (see <doc:DatabaseSchema>). Some invariants can only be enforced by transactions, such as "all account credits must have a matching debit", or "all authors must have at least one book".

- *What if you do not follow this rule?* - You will see broken database invariants, at runtime, or when your apps wakes up after a crash. These bugs corrupt user data, and are very difficult to fix.


## Synchronous and Asynchronous Database Accesses

**You can access the database from any thread, in a synchronous or asynchronous way.**

➡️ **A sync access blocks the current thread** until the database operations are completed:

```swift
let playerCount = try dbQueue.read { db in
    try Player.fetchCount(db)
}

let newPlayerCount = try dbQueue.write { db -> Int in
    try Player(name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}
```

See ``DatabaseReader/read(_:)-3806d`` and ``DatabaseWriter/write(_:)-76inz``.

It is a programmer error to perform a sync access from any other database access (this restriction can be lifted: see <doc:Concurrency#Safe-and-Unsafe-Database-Accesses>):

```swift
try dbQueue.write { db in
    // Fatal Error: Database methods are not reentrant.
    try dbQueue.write { db in ... }
}
```

🔀 **An async access does not block the current thread.** Instead, it notifies you when the database operations are completed. There are four ways to access the database asynchronously:

- **Swift concurrency** (async/await)
    
    ```swift
    let playerCount = try await dbQueue.read { db in
        try Player.fetchCount(db)
    }
    
    let newPlayerCount = try await dbQueue.write { db -> Int in
        try Player(name: "Arthur").insert(db)
        return try Player.fetchCount(db)
    }
    ```

    See ``DatabaseReader/read(_:)-4d1da`` and ``DatabaseWriter/write(_:)-3db50``.
    
    Note the identical method names: `read`, `write`. The async version is only available in async Swift functions.
    
    The async database access methods honor task cancellation. Once an async Task is cancelled, reads and writes throw `CancellationError`, and any transaction is rollbacked.
    
    See <doc:SwiftConcurrency> for more information about GRDB and Swift 6.

- **Combine publishers**
    
    For example:
    
    ```swift
    let playerCountPublisher = dbQueue.readPublisher { db in
        try Player.fetchCount(db)
    }
    
    let newPlayerCountPublisher = dbQueue.writePublisher { db -> Int in
        try Player(name: "Arthur").insert(db)
        return try Player.fetchCount(db)
    }
    ```
    
    See ``DatabaseReader/readPublisher(receiveOn:value:)``, and ``DatabaseWriter/writePublisher(receiveOn:updates:)``.
    
    Those publishers do not access the database until they are subscribed. They complete on the main dispatch queue by default.

- **RxSwift observables**
    
    See the companion library [RxGRDB].

- **Completion blocks**

    See ``DatabaseReader/asyncRead(_:)`` and ``DatabaseWriter/asyncWrite(_:completion:)``.

During one async access, all individual database operations grouped inside (fetch, insert, etc.) are synchronous:

```swift
// One asynchronous access...
try await dbQueue.write { db in
    // ... always performs synchronous database operations:
    try Player(...).insert(db)
    try Player(...).insert(db)
    let players = try Player.fetchAll(db)
}
```

This is true for all async techniques.

This prevents the database operations from various concurrent accesses from being interleaved. For example, one access must not be able to issue a `COMMIT` statement in the middle of an unfinished concurrent write!

## Safe and Unsafe Database Accesses

**You will generally use the safe database access methods `read` and `write`.** In this context, "safe" means that a database access is concurrency-friendly, because GRDB provides the following guarantees:

#### Serialized Writes

**All writes performed by one ``DatabaseQueue`` or ``DatabasePool`` instance are serialized.**

This guarantee prevents [`SQLITE_BUSY`] errors during concurrent writes.

#### Write Transactions

**All writes are wrapped in a transaction.**

Concurrent reads can not see partial database updates (even reads performed by other processes).

#### Isolated Reads

**All reads are wrapped in a transaction.**

An isolated read sees a stable and immutable state of the database, and does not see changes performed by eventual concurrent writes (even writes performed by other processes). See [Isolation In SQLite](https://www.sqlite.org/isolation.html) for more information.

#### Forbidden Writes

**Inside a read access, all attempts to write raise an error.**

This enforces the immutability of the database during a read.

#### Non-Reentrancy

**Database accesses methods are not reentrant.**

This reduces the opportunities for deadlocks, and fosters the clear transaction boundaries of <doc:Concurrency#Rule-2:-Mind-your-transactions>.

### Unsafe Database Accesses

Some applications need to relax this safety net, in order to achieve specific SQLite operations. In this case, replace `read` and `write` with one of the methods below:

- **Write outside of any transaction** (Lifted guarantee: <doc:Concurrency#Write-Transactions>)
    
    See all ``DatabaseWriter`` methods with `WithoutTransaction` in their names.
    
- **Reentrant write, outside of any transaction** (Lifted guarantees: <doc:Concurrency#Write-Transactions>, <doc:Concurrency#Non-Reentrancy>)
    
    See ``DatabaseWriter/unsafeReentrantWrite(_:)``.
    
- **Read outside of any transaction** (Lifted guarantees: <doc:Concurrency#Isolated-Reads>, <doc:Concurrency#Forbidden-Writes>)
    
    See all ``DatabaseReader`` methods with `unsafe` in their names.

- **Reentrant read, outside of any transaction** (Lifted guarantees: <doc:Concurrency#Isolated-Reads>, <doc:Concurrency#Forbidden-Writes>, <doc:Concurrency#Non-Reentrancy>)
    
    See ``DatabaseReader/unsafeReentrantRead(_:)``.

> Important: By using one of the methods above, you become responsible of the thread-safety of your application. Please understand the consequences of lifting each concurrency guarantee.

Some concurrency guarantees can be restored at your convenience:

- The <doc:Concurrency#Write-Transactions> and <doc:Concurrency#Isolated-Reads> guarantees can be restored at any point, with an explicit transaction or savepoint. For example:
    
    ```swift
    try dbQueue.writeWithoutTransaction { db in
        try db.inTransaction { ... }
    }
    ```
    
- The <doc:Concurrency#Forbidden-Writes> guarantee can only be lifted with ``DatabaseQueue``. It can be restored with [`PRAGMA query_only`](https://www.sqlite.org/pragma.html#pragma_query_only).

## Differences between Database Queues and Pools

Despite the common guarantees and rules shared by database queues and pools, those two database accessors don't have the same behavior.

``DatabaseQueue`` opens a single database connection, and serializes all database accesses, reads, and writes. There is never more than one thread that uses the database. In the image below, we see how three threads can see the database as time passes:

![DatabaseQueue Scheduling](DatabaseQueueScheduling.png)

``DatabasePool`` manages a pool of several database connections, and allows concurrent reads and writes thanks to the [WAL mode](https://www.sqlite.org/wal.html). A database pool serializes all writes (the <doc:Concurrency#Serialized-Writes> guarantee). Reads are isolated so that they don't see changes performed by other threads (the <doc:Concurrency#Isolated-Reads> guarantee). This gives a very different picture:

![DatabasePool Scheduling](DatabasePoolScheduling.png)

See how, with database pools, two reads can see different database states at the same time. This may look scary! Please see the next chapter below for a relief.

## Concurrent Thinking

Despite the <doc:Concurrency#Differences-between-Database-Queues-and-Pools>, you can write robust code that works equally well with both `DatabaseQueue` and `DatabasePool`.

This allows your app to switch between queues and pools, at your convenience:

- The [demo applications] share the same database code for the on-disk pool that feeds the app, and the in-memory queue that feeds tests and SwiftUI previews. This makes sure tests and previews run fast, without any temporary file, with the same behavior as the app.

- Applications that perform slow write transactions (when saving a lot of data from a remote server, for example) may want to replace their queue with a pool so that the reads that feed their user interface can run in parallel.

All you need is a little "concurrent thinking", based on those two basic facts:

- You are sure, when you perform a write access, that you deal with the latest database state on disk. This is enforced by SQLite, which simply can't perform parallel writes, and by the <doc:Concurrency#Serialized-Writes> guarantee. Writes performed by other processes can trigger an [`SQLITE_BUSY`] ``DatabaseError`` that you can handle.

- Whenever you extract some data from a database access, immediately consider it as _stale_. It is stale, whether you use a `DatabaseQueue` or `DatabasePool`. It is stale because nothing prevents other application threads or processes from overwriting the value you have just fetched:
    
    ```swift
    // or dbQueue.write, for that matter
    let cookieCount = dbPool.read { db in
        try Cookie.fetchCount(db)
    }
    
    // At this point, the number of cookies on disk
    // may have already changed.
    print("We have \(cookieCount) cookies left")
    ```
    
    Does this mean you can't rely on anything? Of course not:
    
    - If you intend to display some database value on screen, use ``ValueObservation``: it always eventually notifies the latest state of the database. Your application won't display stale values for a long time: after the database has been changed on disk, the fresh value if fetched, and soon notified on the main thread where the screen can be updated.
    
    - As said above, the moment of truth is the next write access!

## Advanced DatabasePool

``DatabasePool`` is very concurrent, since all reads can run in parallel, and can even run during write operations. But writes are still serialized: at any given point in time, there is no more than a single thread that is writing into the database.

When your application modifies the database, and then reads some value that depends on those modifications, you may want to avoid blocking concurrent writes longer than necessary - especially when the read is slow:

```swift
let newPlayerCount = try dbPool.write { db in
    // Increment the number of players
    try Player(...).insert(db)
    
    // Read the number of players. Concurrent writes are blocked :-(
    return try Player.fetchCount(db)
}
```

🔀 The solution is ``DatabasePool/asyncConcurrentRead(_:)``. It must be called from within a write access, outside of any transaction:

```swift
try dbPool.writeWithoutTransaction { db in
    // Increment the number of players
    try db.inTransaction {
        try Player(...).insert(db)
        return .commit
    }
    
    // <- Not in a transaction here
    dbPool.asyncConcurrentRead { dbResult in
        do {
            // Handle the new player count - guaranteed greater than zero
            let db = try dbResult.get()
            let newPlayerCount = try Player.fetchCount(db)
        } catch {
            // Handle error
        }
    }
}
```

The ``DatabasePool/asyncConcurrentRead(_:)`` method blocks until it can guarantee its closure argument an isolated access to the database, in the exact state left by the last transaction. It then asynchronously executes the closure.

In the illustration below, the striped band shows the delay needed for the reading thread to acquire isolation. Until then, no other thread can write:

![DatabasePool Concurrent Read](DatabasePoolConcurrentRead.png)

Types that conform to ``TransactionObserver`` can also use those methods in their ``TransactionObserver/databaseDidCommit(_:)`` method, in order to process database changes without blocking other threads that want to write into the database.

## Topics

### Database Connections with Concurrency Guarantees

- ``DatabaseWriter``
- ``DatabaseReader``
- ``DatabaseSnapshotReader``

### Going Further

- <doc:SwiftConcurrency>
- <doc:DatabaseSharing>


[demo apps]: https://github.com/groue/GRDB.swift/tree/master/Documentation/DemoApps
[`SQLITE_BUSY`]: https://www.sqlite.org/rescode.html#busy
[RxGRDB]: https://github.com/RxSwiftCommunity/RxGRDB
[demo applications]: https://github.com/groue/GRDB.swift/tree/master/Documentation/DemoApps
