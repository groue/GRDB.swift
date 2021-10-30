:twisted_rightwards_arrows: Concurrency
=======================================

**This guide describes how GRDB helps your app deal with database concurrency.**

Concurrency is hard, and better avoided when you can. But sometimes your application will need it.

Some apps do not want slow database accesses to stall the user interface. Database concurrency makes it possible to move those slow database jobs off the main thread.

Concurrent database accesses also happen when a database file is shared between several processes. Maybe you develop an iOS app that communicates with an extension through a shared database? This, honestly, is the most difficult setup, and there exists a dedicated [Sharing a Database] guide about it.

**In all cases, and first and foremost, follow the [Concurrency Rules] right from the start.**

- [Concurrency Rules]
- [Synchronous and Asynchronous Database Accesses]
- [Safe and Unsafe Database Accesses]
- [Differences between Database Queues and Pools]
- [Advanced DatabasePool]
- [Database Snapshots]
- [Sharing a Database]


## Concurrency Rules

**The two concurrency rules are all about SQLite.** This chapter of the GRDB documentation is just a reminder of the fundamental behaviors of this robust database.

<a id="rule-1"></a>:point_up: **[Rule 1](#rule-1): Connect to any database file only once**

Open one single [DatabaseQueue] or [DatabasePool] per database file, for the whole duration of your use of the database. Not for the duration of _each_ database access, but really for the duration of _all_ database accesses to this file.

> *Why does this rule exist?* - Since SQLite does not support parallel writes, each [DatabaseQueue] and [DatabasePool] makes sure application threads perform writes one by one, without overlap.
> 
> *Practical advice* - An app that uses a single database will connect only once. A document-based app will connect each time a document is opened, and disconnect when the document is closed. See the [demo apps] in order to see how to setup a UIKit or SwiftUI application for a single database.
> 
> *What if you do not follow this rule?*
> 
> - You will not be able to use the [Database Observation] features.
> - You will see SQLite errors with code 5 ([SQLITE_BUSY]).

<a id="rule-2"></a>:point_up: **[Rule 2](#rule-2): Mind your transactions**

Database operations that are grouped in an SQLite transaction are guaranteed to be either fully saved on disk, or not at all. Read-only transactions have an interesting property as well: they guarantee a stable and immutable view of the database[^1], and do not see changes performed by eventual concurrent writes. In other words, transactions are the one and single tool that helps you enforce and rely on the important invariants of your database (such as "all credits have a matching debit", or "all books have an author").

**You are responsible**, in your Swift code, for delimiting transactions. You do so by grouping database accesses inside a pair of `{ db in ... }` brackets:

```swift
try dbQueue.write { db in /* Inside a transaction */ }
try dbQueue.read { db in /* Inside a transaction */ }
let observation = ValueObservation.tracking { db in /* Inside a transaction */ }`
```

> *Why does this rule exist?* - Because GRDB and SQLite can not guess where to insert the transaction boundaries that protect the invariants of your database. This is your task.
> 
> *Practical advice* - See below a correct example, as well as frequent mistakes you should avoid:
> 
> <details><summary>Sample code</summary>
>
> In order to insert a money transfer in the database, in a way that enforces the "all credits have a matching debit" invariant, you can write:
>
> ```swift
> // CORRECT: the "all credits have a matching debit" invariant is preserved.
> do {
>     try dbQueue.write { db in
>         try credit.insert(db)
>         try debit.insert(db)
>     }
> } catch {
>     print("An error occurred: \(error)")
> }
> ```
> 
> A frequent mistake is to forget about grouping inside a pair of `{ db in ... }` brackets:
> 
> ```swift
> // INCORRECT. Related database operations are not grouped inside
> // one transaction. The invariant is not enforced.
> do {
>     try dbQueue.write { db in try credit.insert(db) }
>     try dbQueue.write { db in try debit.insert(db) }
> } catch {
>     print("An error occurred: \(error)")
> }
> ```
> 
> Another frequent mistake is to catch database errors at the wrong place:
> 
> ```swift
> // INCORRECT. Related database operations are not grouped inside
> // one transaction, and a failed operation does not prevent
> // subsequent operations from being performed. The invariant is
> // not enforced.
> do {
>     try dbQueue.write { db in try credit.insert(db) }
> } catch {
>     print("An error occurred: \(error)")
> }
>
> do {
>     try dbQueue.write { db in try debit.insert(db) }
> } catch {
>     print("An error occurred: \(error)")
> }
> ```
> 
> </details>
> 
> *What if you do not follow this rule?* - You will see broken database invariants, at runtime, and when your apps wakes up after a crash. You may have a hard time fixing this mess.


## Synchronous and Asynchronous Database Accesses

**You can access the database from any thread, in a synchronous or asynchronous way.**

:arrow_right: **A sync access blocks the current thread** until the database operations are completed:

```swift
let playerCount = try dbQueue.read { db in
    try Player.fetchCount(db)
}

let newPlayerCount = try dbQueue.write { db -> Int in
    try Player(id: 12, name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}
```

> :point_up: **Note**: It is a programmer error to perform a sync access from any other database access (this restriction can be lifted: see [Safe and Unsafe Database Accesses]):
> 
> ```swift
> try dbQueue.write { db in
>     // Fatal Error: Database methods are not reentrant.
>     try dbQueue.write { db in ... }
> }
> ```

:twisted_rightwards_arrows: **An async access does not block the current thread.** Instead, it notifies you when the database operations are completed. There are four ways to access the database asynchronously:

<details open>
    <summary><b>Swift concurrency</b> (async/await)</summary>

```swift
let playerCount = try await dbQueue.read { db in
    try Player.fetchCount(db)
}

let newPlayerCount = try await dbQueue.write { db -> Int in
    try Player(id: 12, name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}
```

Note the identical method names: `read`, `write`. The async version is only available in async Swift functions.

</details>

<details>
    <summary><b>Combine publishers</b></summary>

```swift
let playerCountPublisher = dbQueue.readPublisher { db in
    try Player.fetchCount(db)
}

let newPlayerCountPublisher = dbQueue.writePublisher { db -> Int in
    try Player(id: 12, name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}
```

Those publishers do not access the database until they are subscribed. They complete on the main dispatch queue by default. See [GRDB ❤️ Combine].

</details>

<details>
    <summary><b>RxSwift observables</b></summary>

```swift
let playerCountObservable = dbQueue.rx.read { db in
    try Player.fetchCount(db)
}

let newPlayerCountObservable = dbQueue.rx.write { db -> Int in
    try Player(id: 12, name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}
```

Those observables do not access the database until they are subscribed. They complete on the main dispatch queue by default. See the companion library [RxGRDB].

</details>

<details>
    <summary><b>Completion blocks</b></summary>

```swift
dbQueue.asyncRead { (dbResult: Result<Database, Error>) in
    do {
        let db = try dbResult.get()
        let playerCount = try Player.fetchCount(db)
        ... // Handle playerCount
    } catch {
        ... // Handle error
    }
}

dbQueue.asyncWrite({ (db: Database) -> Int in
    try Player(id: 12, name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}, completion: { (db: Database, result: Result<Int, Error>) in
    switch result {
    case let .success(newPlayerCount):
        ... // Handle newPlayerCount
    case let .failure(error):
        ... // Handle error
    }
})
```

</details>

> :point_up: **Note**: During one async access, all individual database operations (fetch, insert, etc.) remain synchronous:
>
> ```swift
> // When you perform ONE async access...
> try await dbQueue.write { db in
>     // ALL database operations are performed synchronously:
>     try Player(...).insert(db)
>     try Player(...).insert(db)
>     let players = try Player.fetchAll(db)
> }
> ```
>
> This is true for all async techniques (Swift concurrency, Combine, etc.)
>
> This prevents the database operations from various concurrent accesses from being interleaved, with disastrous consequences. For example, one access must not be able to issue a `COMMIT` statement in the middle of an unfinished concurrent write!


## Safe and Unsafe Database Accesses

**You will generally use safe database access methods such as `read` and `write`.** In this context, "safe" means that a database access is concurrency-friendly, because it provides the following guarantees:

- <a id="guarantee-serialized-writes"></a>**[Serialized Writes]** - All writes performed by one [DatabaseQueue] or [DatabasePool] instance are serialized. *Why is it important?* - this guarantee prevents [SQLITE_BUSY] errors during concurrent writes.
- <a id="guarantee-write-transactions"></a>**[Write Transactions]** - All writes are wrapped in a transaction. *Why is it important?* - concurrent reads can not see partial database updates (even reads performed by other processes).
- <a id="guarantee-isolated-reads"></a>**[Isolated Reads]** - All reads are wrapped in a transaction. *Why is it important?* - an isolated read sees a stable and immutable state of the database[^1], and does not see changes performed by eventual concurrent writes (even writes performed by other processes).
- <a id="guarantee-forbidden-writes"></a>**[Forbidden Writes]** - Inside a read database access, all attempts to write raise an error. *Why is it important?* - this enforces the immutability of the database during a read.
- <a id="guarantee-non-reentrancy"></a>**[Non-Reentrancy]** - Database accesses are not reentrant. *Why is it important?* - this reduces the opportunities for deadlocks, and fosters the clear transaction boundaries of the [second concurrency rule](#rule-2).

Some applications need to lift this safety net in order to achieve some SQLite operations. In this case, you will replace `read` and `write` with one of the methods below:

- **Write outside of any transaction**  
  (Lifted guarantee: [Write Transactions])
    
    ```swift
    try dbQueue.writeWithoutTransaction { db in ... }
    ```
    
    `writeWithoutTransaction` is also available as an `async` function. You can also use `asyncWriteWithoutTransaction`.

- **Write outside of any transaction, and prevents concurrent reads**  
  (Lifted guarantee: [Write Transactions])
    
    ```swift
    try dbQueue.barrierWriteWithoutTransaction { db in ... }
    ```
    
    The barrier write guarantees an exclusive access to the database: the method blocks until all concurrent database accesses are completed, reads and writes, and postpones all other accesses until it completes.

    There is a known limitation: database accesses performed by other processes, and reads performed by [DatabaseSnapshot] are out of scope of this barrier, and can run concurrently with the barrier.
    
    You will use this method, for example, when you [change the password](../README.md#changing-the-passphrase-of-an-encrypted-database) of an encrypted database.
    
    `barrierWriteWithoutTransaction` is also available as an `async` function.

- **Reentrant write outside of any transaction**  
  (Lifted guarantees: [Write Transactions], [Non-Reentrancy])
    
    ```swift
    try dbQueue.unsafeReentrantWrite { db in ... }
    ```
    
    Reentrant writes can be performed from any other database access:
    
    ```swift
    try dbQueue.write { db in
        // No fatal error
        try dbQueue.unsafeReentrantWrite { db in ... }
    }
    ```
    
    `unsafeReentrantWrite` has no async version.
    
- **Read outside of any transaction**  
  (Lifted guarantees: [Isolated Reads], [Forbidden Writes])
    
    ```swift
    try dbQueue.unsafeRead { db in ... }
    ```
    
    `unsafeRead` is also available as an `async` function.

- **Reentrant read, outside of any transaction**  
  (Lifted guarantees: [Isolated Reads], [Forbidden Writes], [Non-Reentrancy])

    ```swift
    try dbQueue.unsafeReentrantRead { db in ... }
    ```
    
    Reentrant reads can be performed from any other database access:
    
    ```swift
    try dbQueue.write { db in
        // No fatal error
        try dbQueue.unsafeReentrantRead { db in ... }
    }
    ```
    
    `unsafeReentrantRead` has no async version.

:warning: By using one of the methods above, you become responsible of the thread-safety of your application. Please understand the consequences of lifting each concurrency guarantee. Some guarantees can also be restored at your convenience:

- The [Write Transactions] and [Isolated Reads] guarantees can be restored at any point, by opening an [explicit transaction](../README.md#transactions-and-savepoints). For example:
    
    ```swift
    try dbQueue.writeWithoutTransaction { db in
        try db.inTransaction {
            ...
            return .commit
        }
    }
    ```
    
- The [Forbidden Writes] guarantee can only be lifted with [DatabaseQueue]. It can be restored with [`PRAGMA query_only`](https://www.sqlite.org/pragma.html#pragma_query_only).


## Differences between Database Queues and Pools

Despite the common [guarantees](#safe-and-unsafe-database-accesses) and [rules](#concurrency-rules) shared by database queues and pools, those two database accessors don't have the same behavior.

[DatabaseQueue] opens a single database connection, and serializes all database accesses, reads, and writes. There is never more than one thread that uses the database. In the image below, we see how three threads can see the database as time passes:

![DatabaseQueueScheduling](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/DatabaseQueueScheduling.svg)

[DatabasePool] manages a pool of several database connections, and allows concurrent reads and writes. It serializes all writes. Reads are isolated so that they don't see changes performed by other threads. This gives a very different picture:

![DatabasePoolScheduling](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/DatabasePoolScheduling.svg)

See how, with database pools, two reads can see different database states at the same time. This may look scary, but there is a simple way to think about it. After all, most applications are generally interested in the latest state of the database:

- You are sure, when you perform a write access, that you deal with the latest database state. This is because SQLite does not support parallel writes, even from other processes.

- When your application wants to synchronize the information displayed on screen with the database, use [ValueObservation].

For more information about database pools, grab information about SQLite [WAL mode](https://www.sqlite.org/wal.html) and [snapshot isolation](https://sqlite.org/isolation.html).


## Advanced DatabasePool

[DatabasePool] is very concurrent, since all reads can run in parallel, and can even run during write operations. But writes are still serialized: at any given point in time, there is no more than a single thread that is writing into the database.

When your application modifies the database, and then reads some value that depends on those modifications, you may want to avoid blocking concurrent writes longer than necessary:

```swift
try dbPool.write { db in
    // Increment the number of players
    try Player(...).insert(db)
    try Player(...).insert(db)
    
    // Read the number of players. Concurrent writes are blocked :-(
    let newPlayerCount = try Player.fetchCount(db)
}
```

:arrow_right: The solution is the `concurrentRead` method. It must be called from within a write access, outside of any transaction. It returns a *future value* which you consume any time later, with the `wait()` method.

```swift
let future: DatabaseFuture<Int> = try dbPool.writeWithoutTransaction { db in
    // Increment the number of players
    try db.inTransaction {
        try Player(...).insert(db)
        try Player(...).insert(db)
        return .commit
    }
    
    // <- Not in a transaction here
    let future = dbPool.concurrentRead { db
        try Player.fetchCount(db)
    }
    return future
}
// <- Concurrent writes can be performed :-)

// Wait and handle newPlayerCount
let newPlayerCount = try future.wait()
```

:twisted_rightwards_arrows: The async version of `concurrentRead` is `asyncConcurrentRead`:

```swift
try dbPool.writeWithoutTransaction { db in
    // Increment the number of players
    try db.inTransaction {
        try Player(...).insert(db)
        try Player(...).insert(db)
        return .commit
    }
    
    // <- Not in a transaction here
    dbPool.asyncConcurrentRead { dbResult in
        do {
            let db = try dbResult.get()
            let newPlayerCount = try Player.fetchCount(db)
            // Handle newPlayerCount
        } catch {
            // Handle error
        }
    }
}
```

`concurrentRead` and `asyncConcurrentRead` block until they can guarantee their closure argument an isolated access to the database, in the exact state left by the last transaction. It then asynchronously executes this closure.

[Transaction Observers](../README.md#transactionobserver-protocol) can also use those methods in their `databaseDidCommit` method, in order to process database changes without blocking other threads that want to write into the database.


## Database Snapshots

**[DatabasePool] can take snapshots.** A database snapshot sees an unchanging database content, as it existed at the moment it was created.

"Unchanging" means that a snapshot never sees any database modifications during all its lifetime. And yet it doesn't prevent database updates. This "magic" is made possible by SQLite's WAL mode (see [Isolation In SQLite](https://sqlite.org/isolation.html)).

```swift
let snapshot = try dbPool.makeSnapshot()
```

You can create as many snapshots as you need, regardless of the [maximum number of readers](../README.md#databasepool-configuration) in the pool. A snapshot database connection is closed when the snapshot is deinitialized.

**A snapshot can be used from any thread.** It has the same [synchronous and asynchronous reading methods](#synchronous-and-asynchronous-database-accesses) as database queues and pools:

```swift
let playerCount = try snapshot.read { db in
    try Player.fetchCount(db)
}
```

When you want to control the latest committed changes seen by a snapshot, create the snapshot from within a write, outside of any transaction:

```swift
let snapshot1 = try dbPool.writeWithoutTransaction { db -> DatabaseSnapshot in
    try db.inTransaction {
        // delete all players
        try Player.deleteAll()
        return .commit
    }
    
    // <- not in a transaction here
    return dbPool.makeSnapshot()
}
// <- Other threads may modify the database here
let snapshot2 = try dbPool.makeSnapshot()

try snapshot1.read { db in
    // Guaranteed to be zero
    try Player.fetchCount(db)
}

try snapshot2.read { db in
    // Could be anything
    try Player.fetchCount(db)
}
```

> :point_up: **Note**: snapshots currently serialize all database accesses. In the future, snapshots may allow concurrent reads.

[^1]: This immutable view of the database is called [snapshot isolation](https://www.sqlite.org/isolation.html).

[Concurrency Rules]: #concurrency-rules
[Synchronous and Asynchronous Database Accesses]: #synchronous-and-asynchronous-database-accesses
[Safe and Unsafe Database Accesses]: #safe-and-unsafe-database-accesses
[Differences between Database Queues and Pools]: #differences-between-database-queues-and-pools
[Advanced DatabasePool]: #advanced-databasepool
[Database Snapshots]: #database-snapshots
[DatabaseQueue]: ../README.md#database-queues
[DatabasePool]: ../README.md#database-pools
[DatabaseSnapshot]: #database-snapshots
[demo apps]: DemoApps
[Database Observation]: ../README.md#database-changes-observation
[SQLITE_BUSY]: https://www.sqlite.org/rescode.html#busy
[Sharing a Database]: SharingADatabase.md
[ValueObservation]: ../README.md#valueobservation
[GRDB ❤️ Combine]: Combine.md
[RxGRDB]: https://github.com/RxSwiftCommunity/RxGRDB
[Serialized Writes]: #guarantee-serialized-writes
[Write Transactions]: #guarantee-write-transactions
[Isolated Reads]: #guarantee-isolated-reads
[Forbidden Writes]: #guarantee-forbidden-writes
[Non-Reentrancy]: #guarantee-non-reentrancy
