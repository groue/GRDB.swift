# ``GRDB/DatabaseRegionObservation``

`DatabaseRegionObservation` tracks changes in a database region, and notifies impactful transactions.

## Overview

`DatabaseRegionObservation` tracks insertions, updates, and deletions that impact the tracked region, whether performed with raw SQL, or <doc:QueryInterface>. This includes indirect changes triggered by [foreign keys actions](https://www.sqlite.org/foreignkeys.html#fk_actions) or [SQL triggers](https://www.sqlite.org/lang_createtrigger.html).

See <doc:GRDB/DatabaseRegionObservation#Dealing-with-Undetected-Changes> below for the list of exceptions.

`DatabaseRegionObservation` calls your application right after changes have been committed in the database, and before any other thread had any opportunity to perform further changes. *This is a pretty strong guarantee, that most applications do not really need.* Instead, most applications prefer to be notified with fresh values: make sure you check ``ValueObservation`` before using `DatabaseRegionObservation`.

## DatabaseRegionObservation Usage

Create a `DatabaseRegionObservation` with one or several requests to track:

```swift
// Tracks the full player table
let observation = DatabaseRegionObservation(tracking: Player.all())
```

Then start the observation from a ``DatabaseQueue`` or ``DatabasePool``:

```swift
let cancellable = try observation.start(in: dbQueue) { error in
    // Handle error
} onChange: { (db: Database) in
    print("Players were changed")
}
```

Enjoy the changes notifications:

```swift
try dbQueue.write { db in
    try Player(name: "Arthur").insert(db)
}
// Prints "Players were changed"
```

You stop the observation by calling the ``DatabaseCancellable/cancel()`` method on the object returned by the `start` method. Cancellation is automatic when the cancellable is deallocated:

```swift
cancellable.cancel()
```

`DatabaseRegionObservation` can also be turned into a Combine publisher, or an RxSwift observable (see the companion library [RxGRDB](https://github.com/RxSwiftCommunity/RxGRDB)):

```swift
let cancellable = observation.publisher(in: dbQueue).sink { completion in
    // Handle completion
} receiveValue: { (db: Database) in
    print("Players were changed")
}
```

You can feed `DatabaseRegionObservation` with any type that conforms to the ``DatabaseRegionConvertible`` protocol: ``FetchRequest``, ``DatabaseRegion``, ``Table``, etc. For example:

```swift
// Observe the score column of the 'player' table
let observation = DatabaseRegionObservation(
    tracking: Player.select(Column("score")))

// Observe the 'score' column of the 'player' table
let observation = DatabaseRegionObservation(
    tracking: SQLRequest("SELECT score FROM player"))

// Observe both the 'player' and 'team' tables
let observation = DatabaseRegionObservation(
    tracking: Table("player"), Table("team"))

// Observe the full database
let observation = DatabaseRegionObservation(
    tracking: .fullDatabase)
```

## Dealing with Undetected Changes

`DatabaseRegionObservation` will not notify impactful transactions whenever the database is modified in an undetectable way:

- Changes performed by external database connections.
- Changes performed by SQLite statements that are not compiled and executed by GRDB.
- Changes to the database schema, changes to internal system tables such as `sqlite_master`.
- Changes to [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) tables.

To have observations notify such undetected changes, applications can take explicit action: call the ``Database/notifyChanges(in:)`` `Database` method from a write transaction:
    
```swift
try dbQueue.write { db in
    // Notify observations that some changes were performed in the database
    try db.notifyChanges(in: .fullDatabase)

    // Notify observations that some changes were performed in the player table
    try db.notifyChanges(in: Player.all())

    // Equivalent alternative
    try db.notifyChanges(in: Table("player"))
}
```

## Topics

### Creating DatabaseRegionObservation

- ``init(tracking:)-5ldbe``
- ``init(tracking:)-2nqjd``

### Observing Database Transactions

- ``publisher(in:)``
- ``start(in:onError:onChange:)``
