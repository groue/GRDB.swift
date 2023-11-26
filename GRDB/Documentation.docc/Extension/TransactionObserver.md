# ``GRDB/TransactionObserver``

A type that tracks database changes and transactions performed in a database.

## Overview

`TransactionObserver` is the low-level protocol that supports all <doc:DatabaseObservation> features.

A transaction observer is notified of individual changes (inserts, updates and deletes), before they are committed to disk, as well as transaction commits and rollbacks.

## Activate a Transaction Observer

An observer starts receiving change notifications after it has been added to a database connection with the ``DatabaseWriter/add(transactionObserver:extent:)`` `DatabaseWriter` method, or the ``Database/add(transactionObserver:extent:)`` `Database` method:

```swift
let observer = MyObserver()
dbQueue.add(transactionObserver: observer)
```

By default, database holds weak references to its transaction observers: they are not retained, and stop getting notifications after they are deallocated. See <doc:TransactionObserver#Observation-Extent> for more options.

## Database Changes And Transactions

Database changes are notified to the ``databaseDidChange(with:)`` callback. This includes indirect changes triggered by `ON DELETE` and `ON UPDATE` actions associated to [foreign keys](https://www.sqlite.org/foreignkeys.html#fk_actions), and [SQL triggers](https://www.sqlite.org/lang_createtrigger.html).

Transaction completions are notified to the ``databaseWillCommit()-7mksu``, ``databaseDidCommit(_:)`` and ``databaseDidRollback(_:)`` callbacks.

> Important: Some changes and transactions are not automatically notified. See <doc:GRDB/TransactionObserver#Dealing-with-Undetected-Changes> below.

Notified changes are not actually written to disk until the transaction commits, and the `databaseDidCommit` callback is called. On the other side, `databaseDidRollback` confirms their invalidation:

```swift
try dbQueue.write { db in
    try db.execute(sql: "INSERT ...") // 1. didChange
    try db.execute(sql: "UPDATE ...") // 2. didChange
}                                     // 3. willCommit, 4. didCommit

try dbQueue.inTransaction { db in
    try db.execute(sql: "INSERT ...") // 1. didChange
    try db.execute(sql: "UPDATE ...") // 2. didChange
    return .rollback                  // 3. didRollback
}

try dbQueue.write { db in
    try db.execute(sql: "INSERT ...") // 1. didChange
    throw SomeError()
}                                     // 2. didRollback
```

Database statements that are executed outside of any explicit transaction do not drop off the radar:

```swift
try dbQueue.writeWithoutTransaction { db in
    try db.execute(sql: "INSERT ...") // 1. didChange, 2. willCommit, 3. didCommit
    try db.execute(sql: "UPDATE ...") // 4. didChange, 5. willCommit, 6. didCommit
}
```

Changes that are on hold because of a [savepoint](https://www.sqlite.org/lang_savepoint.html) are only notified after the savepoint has been released. This makes sure that notified events are only those that have an opportunity to be committed:

```swift
try dbQueue.inTransaction { db in
    try db.execute(sql: "INSERT ...")            // 1. didChange

    try db.execute(sql: "SAVEPOINT foo")
    try db.execute(sql: "UPDATE ...")            // delayed
    try db.execute(sql: "UPDATE ...")            // delayed
    try db.execute(sql: "RELEASE SAVEPOINT foo") // 2. didChange, 3. didChange

    try db.execute(sql: "SAVEPOINT bar")
    try db.execute(sql: "UPDATE ...")            // not notified
    try db.execute(sql: "ROLLBACK TO SAVEPOINT bar")
    try db.execute(sql: "RELEASE SAVEPOINT bar")

    return .commit                               // 4. willCommit, 5. didCommit
}
```

Eventual errors thrown from `databaseWillCommit` are exposed to the application code:

```swift
do {
    try dbQueue.inTransaction { db in
        ...
        return .commit // 1. willCommit (throws), 2. didRollback
    }
} catch {
    // 3. The error thrown by the transaction observer.
}
```

- Note: All callbacks are called in the writer dispatch queue, and serialized with all database updates.

- Note: The `databaseDidChange` and `databaseWillCommit` callbacks must not access the observed writer database connection in any way. This limitation does not apply to `databaseDidCommit` and `databaseDidRollback` which can use their database argument.

## Filtering Database Events

**Transaction observers can choose the database changes they are interested in.**

The ``observes(eventsOfKind:)`` method filters events that are notified to ``databaseDidChange(with:)``. It is the most efficient and recommended change filtering technique, because it is only called once before a database query is executed, and can completely disable change tracking:

```swift
// Calls `observes(eventsOfKind:)` once.
// Calls `databaseDidChange(with:)` for every updated row, or not at all.
try db.execute(sql: "UPDATE player SET score = score + 1")
```

The ``DatabaseEventKind`` argument of `observes(eventsOfKind:)` can distinguish insertions from deletions and updates, and is also able to tell the columns that are about to be changed.

For example, an observer can focus on the changes that happen on the "player" database table only:

```swift
class PlayerObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        // Only observe changes to the "player" table.
        eventKind.tableName == "player"
    }

    func databaseDidChange(with event: DatabaseEvent) {
        // This method is only called for changes that happen to
        // the "player" table.
    }
}
```

When the `observes(eventsOfKind:)` method returns false for all event kinds, the observer is still notified of transactions.

## Observation Extent

**You can specify how long an observer is notified of database changes and transactions.**

The `remove(transactionObserver:)` method explicitly stops notifications, at any time:

```swift
// From a database queue or pool:
dbQueue.remove(transactionObserver: observer)

// From a database connection:
dbQueue.inDatabase { db in
    db.remove(transactionObserver: observer)
}
```

Alternatively, use the `extent` parameter of the `add(transactionObserver:extent:)` method:

```swift
let observer = MyObserver()

// On a database queue or pool:
dbQueue.add(transactionObserver: observer) // default extent
dbQueue.add(transactionObserver: observer, extent: .observerLifetime)
dbQueue.add(transactionObserver: observer, extent: .nextTransaction)
dbQueue.add(transactionObserver: observer, extent: .databaseLifetime)

// On a database connection:
dbQueue.inDatabase { db in
    db.add(transactionObserver: ...)
}
```

- The default extent is `.observerLifetime`: the database holds a weak reference to the observer, and the observation automatically ends when the observer is deallocated. Meanwhile, the observer is notified of all changes and transactions.

- `.nextTransaction` activates the observer until the current or next transaction completes. The database keeps a strong reference to the observer until its `databaseDidCommit` or `databaseDidRollback` callback is called. Hereafter the observer won't get any further notification.

- `.databaseLifetime` has the database retain and notify the observer until the database connection is closed.

Finally, an observer can avoid processing database changes until the end of the current transaction. After ``stopObservingDatabaseChangesUntilNextTransaction()``, the `databaseDidChange` callback will not be called until the current transaction completes:

```swift
class PlayerObserver: TransactionObserver {
    var playerTableWasModified = false

    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        eventKind.tableName == "player"
    }

    func databaseDidChange(with event: DatabaseEvent) {
        playerTableWasModified = true

        // It is pointless to keep on tracking further changes:
        stopObservingDatabaseChangesUntilNextTransaction()
    }
}
```

## Support for SQLite Pre-Update Hooks

When SQLite is built with the `SQLITE_ENABLE_PREUPDATE_HOOK` option, `TransactionObserver` gets an extra callback which lets you observe individual column values in the rows modified by a transaction:

```swift
protocol TransactionObserver: AnyObject {
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    /// Notifies before a database change (insert, update, or delete)
    /// with change information (initial / final values for the row's
    /// columns).
    ///
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy: event.copy().
    func databaseWillChange(with event: DatabasePreUpdateEvent)
    #endif
}
```

This extra API can be activated in two ways:

1. Use the GRDB.swift CocoaPod with a custom compilation option, as below.

    It uses the system SQLite, which is compiled with `SQLITE_ENABLE_PREUPDATE_HOOK` support, but only on iOS 11.0+ (we don't know the minimum version of macOS, tvOS, watchOS):

    ```ruby
    pod 'GRDB.swift'
    platform :ios, '11.0' # or above

    post_install do |installer|
      installer.pods_project.targets.select { |target| target.name == "GRDB.swift" }.each do |target|
        target.build_configurations.each do |config|
          # Enable extra GRDB APIs
          config.build_settings['OTHER_SWIFT_FLAGS'] = "$(inherited) -D SQLITE_ENABLE_PREUPDATE_HOOK"
          # Enable extra SQLite APIs
          config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = "$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1"
        end
      end
    end
    ```

    **Warning**: make sure you use the right platform version! You will get runtime errors on devices with a lower version.

    **Note**: the `GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1` option in `GCC_PREPROCESSOR_DEFINITIONS` defines some C function prototypes that are lacking from the system `<sqlite3.h>` header. When Xcode eventually ships with an SDK that includes a complete header, you may get a compiler error about duplicate function definitions. When this happens, just remove this `GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1` option.

2. Use a [custom SQLite build](http://github.com/groue/GRDB.swift/blob/master/Documentation/CustomSQLiteBuilds.md) and activate the `SQLITE_ENABLE_PREUPDATE_HOOK` compilation option.

## Dealing with Undetected Changes

The changes and transactions that are not automatically notified to transaction observers are:

- Read-only transactions.
- Changes and transactions performed by external database connections.
- Changes performed by SQLite statements that are not both compiled and executed through GRDB APIs.
- Changes to the database schema, changes to internal system tables such as `sqlite_master`.
- Changes to [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) tables.
- The deletion of duplicate rows triggered by [`ON CONFLICT REPLACE`](https://www.sqlite.org/lang_conflict.html) clauses (this last exception might change in a future release of SQLite).

To notify undetected changes to transaction observers, perform an explicit call to the ``Database/notifyChanges(in:)`` `Database` method. The ``databaseDidChange()-7olv7`` callback will be called accordingly. For example:

```swift
try dbQueue.write { db in
    // Notify observers that some changes were performed in the database
    try db.notifyChanges(in: .fullDatabase)

    // Notify observers that some changes were performed in the player table
    try db.notifyChanges(in: Player.all())

    // Equivalent alternative
    try db.notifyChanges(in: Table("player"))
}
```

To notify a change in the database schema, notify a change to the `sqlite_master` table:

```swift
try dbQueue.write { db in
    // Notify all observers of the sqlite_master table
    try db.notifyChanges(in: Table("sqlite_master"))
}
```

## Topics

### Filtering Database Changes

- ``observes(eventsOfKind:)``
- ``DatabaseEventKind``

### Handling Database Changes

- ``databaseDidChange()-7olv7``
- ``databaseDidChange(with:)``
- ``stopObservingDatabaseChangesUntilNextTransaction()``
- ``DatabaseEvent``

### Handling Transactions

- ``databaseWillCommit()-7mksu``
- ``databaseDidCommit(_:)``
- ``databaseDidRollback(_:)``
