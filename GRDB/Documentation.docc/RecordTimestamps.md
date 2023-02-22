# Record Timestamps and Transaction Date

Learn how applications can save creation and modification dates of records.

## Overview

Some applications want to record creation and modification dates of database records. This article provides some advice and sample code that you can adapt for your specific needs.

> Note: Creation and modification dates can be automatically handled by [SQLite triggers](https://www.sqlite.org/lang_createtrigger.html). We'll explore a different technique, though.
>
> This is not an advice against triggers, and you won't feel hindered in any way if you prefer to use triggers. Still, consider:
>
> - A trigger does not suffer any exception, when some applications eventually want to fine-tune timestamps, or to perform migrations without touching timestamps.
> - The current time, according to SQLite, is not guaranteed to be constant in a given transaction. This may create undesired timestamp variations. We'll see below how GRDB provides a date that is constant at any point during a transaction.
> - The current time, according to SQLite, can't be controlled in tests and previews.

We'll start from this table and record type:

```swift
try db.create(table: "player") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("creationDate", .datetime).notNull()
    t.column("modificationDate", .datetime).notNull()
    t.column("name", .text).notNull()
    t.column("score", .integer).notNull()
}

struct Player: Identifiable {
    var id: Int64?
    var creationDate: Date?
    var modificationDate: Date?
    var name: String
    var score: Int
}
```

Note that the table has non-null dates, while the record has optional dates.

This is because we intend, in this article, to timestamp actual database operations. The `creationDate` property is the date of database insertion, and `modificationDate` is the date of last modification in the database. A new `Player` instance has no meaningful timestamp until it is saved, and this absence of information is represented with `nil`:

```swift
// A new player has no timestamps.
var player = Player(id: nil, name: "Arthur", score: 1000)
player.id               // nil, because never saved
player.creationDate     // nil, because never saved
player.modificationDate // nil, because never saved

// After insertion, the player has timestamps.
try dbQueue.write { db in
    try player.insert(db)
}
player.id               // not nil
player.creationDate     // not nil
player.modificationDate // not nil
```

In the rest of the article, we'll address insertion first, then updates, and see a way to avoid those optional timestamps. The article ends with a sample protocol that your app may adapt and reuse.

- <doc:RecordTimestamps#Insertion-Timestamp>
- <doc:RecordTimestamps#Modification-Timestamp>
- <doc:RecordTimestamps#Dealing-with-Optional-Timestamps>
- <doc:RecordTimestamps#Sample-code-TimestampedRecord>

## Insertion Timestamp

On insertion, the `Player` record should get fresh `creationDate` and `modificationDate`. The ``MutablePersistableRecord`` protocol provides the necessary tooling, with the ``MutablePersistableRecord/willInsert(_:)-1xfwo`` persistence callback. Before insertion, the record sets both its `creationDate` and `modificationDate`:

```swift
extension Player: Encodable, MutablePersistableRecord {
    /// Sets both `creationDate` and `modificationDate` to the
    /// transaction date, if they are not set yet.
    mutating func willInsert(_ db: Database) throws {
        if creationDate == nil {
            creationDate = try db.transactionDate
        }
        if modificationDate == nil {
            modificationDate = try db.transactionDate
        }
    }
    
    /// Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

try dbQueue.write { db in
    // An inserted record has both a creation and a modification date.
    var player = Player(name: "Arthur", score: 1000)
    try player.insert(db)
    player.creationDate     // not nil
    player.modificationDate // not nil

    // We can still customize those dates
    let date: Date = ...
    var player = Player(creationDate: date, modificationDate: date, name: "Barbara", score: 2000)
    try player.insert(db)
    player.creationDate     // date
    player.modificationDate // date
}
```

Note that the `willInsert` callback uses the ``Database/transactionDate`` instead of `Date()`. This has two advantages:

- Within a write transaction, all inserted players get the same timestamp:
    
    ```swift
    // All players have the same timestamp.
    try dbQueue.write { db in
        for var player in players {
            try player.insert(db)
        }
    }
    ```
    
- The transaction date can be configured with ``Configuration/transactionClock``, so that your tests and previews can control the date.

## Modification Timestamp

Let's now deal with updates. The `update` persistence method won't automatically bump the timestamp as the `insert` method does. We have to explicitly deal with the modification date:

```swift
// Increment the player score (two different ways).
try dbQueue.write { db in
    var player: Player
    
    // Update all columns
    player.score += 1
    player.modificationDate = try db.transactionDate
    try player.update(db)

    // Alternatively, update only the modified columns
    try player.updateChanges(db) {
         $0.score += 1
         $0.modificationDate = try db.transactionDate
    }
}
```

Again, we use ``Database/transactionDate``, so that all modified players get the same timestamp within a given write transaction.

> Note: Unlike the insertion case, where we set the timestamps in the ``MutablePersistableRecord/willInsert(_:)-1xfwo`` persistence callback, updates are not handled with ``MutablePersistableRecord/willSave(_:)-6jitc`` or ``MutablePersistableRecord/willUpdate(_:columns:)-3oko4``. Instead, the modification date is explicitly modified when needed.
>
> This may look like an inconvenience, but there are several reasons for this:
>
> 1. The first reason is purely technical: the persistence methods that perform database updates are not declared as a mutating methods. This mean that `player.update(db)` is unable to modify the player's modification date.
>
> 2. The second reason is that the library indeed discourages automatic changes to the modification date from the general `update` method.
>
>     While convenient-looking at first sight, users eventually want to disable those automatic updates in specific circumstances. That's because application requirements happen to change, and developers happen to overlook some corner cases. And that's totally fine.
>
>     Existing libraries that provide automatic modification timestamps know that users want to occasionally disable the feature. [ActiveRecord](https://stackoverflow.com/questions/861448/is-there-a-way-to-avoid-automatically-updating-rails-timestamp-fields) uses globals (not thread-safe). [Django ORM](https://stackoverflow.com/questions/7499767/temporarily-disable-auto-now-auto-now-add) does not make it easy. [Fluent](https://github.com/vapor/fluent-kit/issues/355) does not allow it.
>
>     Based on this experience, automatic modification timestamps appear as a wobbly convenience that is better avoided.
>
> 3. Finally, not all applications need one modification timestamp. Some need one timestamp per property, or per group of properties.
>
> By not providing this feature, all applications are treated equally. They can help themselves by introducing a protocol dedicated to their particular handling of timestamps. See <doc:RecordTimestamps#Sample-code-TimestampedRecord> below.

## Dealing with Optional Timestamps

When you fetch timestamped records from the database, it may be inconvenient to deal with optional dates, even though the database columns are guaranteed to be not null:

```swift
let player = try dbQueue.read { db 
    try Player.find(db, id: 1)
}
player.creationDate     // optional 😕
player.modificationDate // optional 😕
```

A possible technique is to define two record types.

One record can deal with unsaved players:

```swift
struct Player: Identifiable {
    var id: Int64?
    var creationDate: Date?
    var modificationDate: Date?
    var name: String
    var score: Int
}

extension Player: Encodable, MutablePersistableRecord {
    /// Updates auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    /// Sets both `creationDate` and `modificationDate` to the
    /// transaction date, if they are not set yet.
    mutating func willInsert(_ db: Database) throws {
        if creationDate == nil {
            creationDate = try db.transactionDate
        }
        if modificationDate == nil {
            modificationDate = try db.transactionDate
        }
    }
}
```

The other record only deals with saved players:

```swift
struct TimestampedPlayer: Identifiable {
    let id: Int64
    let creationDate: Date
    var modificationDate: Date
    var name: String
    var score: Int
}

extension TimestampedPlayer: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "player" }
}
```

Usage:

```swift
// Fetch
let timestampedPlayer = try dbQueue.read { db 
    try TimestampedPlayer.find(db, id: 1)
}
timestampedPlayer.creationDate     // not optional
timestampedPlayer.modificationDate // not optional

// Insert
try dbQueue.write { db in
    var player = Player(id: nil, name: "Arthur", score: 1000)
    
    let timestampedPlayer = try player.insertAndFetch(db, as: TimestampedPlayer.self)
    
    timestampedPlayer.id               // not optional
    timestampedPlayer.creationDate     // not optional
    timestampedPlayer.modificationDate // not optional
}
```

See ``MutablePersistableRecord/insertAndFetch(_:onConflict:as:)`` and related methods for more information.

## Sample code: TimestampedRecord

This section provides a sample protocol for records that track their creation and modification dates.

You can copy it in your application. Make sure it fits the needs of your application! Not all apps have the same needs regarding timestamps. Perform adaptations when needed.

It provides the following features and methods:

- Insertion sets timestamps if not set yet:

    ```swift
    extension Player: Codable, TimestampedRecord, FetchableRecord {
        /// Update auto-incremented id upon successful insertion
        mutating func didInsert(_ inserted: InsertionSuccess) {
            id = inserted.rowID
        }
    }

    try dbQueue.write { db in
        // An inserted record has both a creation and a modification date.
        var player = Player(name: "Arthur", score: 1000)
        try player.insert(db)
        player.creationDate     // not nil
        player.modificationDate // not nil
    }
    ```

    Note that `TimestampedRecord` types that customize their ``MutablePersistableRecord/willInsert(_:)-1xfwo`` callback should call `initializeTimestamps()` from their implementation, because the Swift language won't do it automatically. Our `Player` type doesn't customize `willInsert`, so it gets timestamps "for free".

- `updateWithTimestamp()` behaves like ``MutablePersistableRecord/update(_:onConflict:)``, but it also bumps the modification date.
    
    ```swift
    // updateWithTimestamp() bumps the modification date
    // and updates all columns in the database.
    player.score += 1
    try player.updateWithTimestamp(db)
    ```

- `updateChangesWithTimestamp()` behaves like ``MutablePersistableRecord/updateChanges(_:onConflict:modify:)``, but it also bumps the modification date if the record is modified.

    ```swift
    // updateChangesWithTimestamp() only bumps the modification date
    // if record is changed, and only updates the changed columns.
    try player.updateChangesWithTimestamp(db) {
        $0.score = 1000
    }

    // Prefer updateChanges() if the modification date should always be
    // updated, even if other columns are not changed.
    try player.updateChanges(db) {
        $0.score = 1000
        $0.modificationDate = try db.transactionDate
    }
    ```

- `touch()` only updates the modification date in the database, just like the `touch` unix command.
    
    ```swift
    // touch() only updates the modification date in the database.
    try player.touch(db)
    try player.touch(db, modificationDate: Date())
    ```

- Note that there is no `TimestampedRecord.saveWithTimestamp()` method that would insert or update, like ``MutablePersistableRecord/save(_:onConflict:)``. You are encouraged to write instead (and maybe extend your version of `TimestampedRecord` so that it supports this pattern):
    
    ```swift
    extension Player {
        /// If the player has a non-nil primary key and a matching row in
        /// the database, the player is updated. Otherwise, it is inserted.
        mutating func saveWithTimestamp(_ db: Database) throws {
            if id == nil {
                try insert(db)
            } else {
                do {
                    try updateWithTimestamp(db)
                } catch RecordError.recordNotFound {
                    // No row was updated: fallback on insert.
                    try insert(db)
                }
            }
        }
    }
    ```

The full implementation of `TimestampedRecord` follows:

```swift
/// A record type that tracks its creation and modification dates. See
/// <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/recordtimestamps>
protocol TimestampedRecord: MutablePersistableRecord {
    var creationDate: Date? { get set }
    var modificationDate: Date? { get set }
}

extension TimestampedRecord {
    /// By default, `TimestampedRecord` types set `creationDate` and
    /// `modificationDate` to the transaction date, if they are nil,
    /// before insertion.
    ///
    /// `TimestampedRecord` types that customize the `willInsert`
    /// persistence callback should call `initializeTimestamps` from
    /// their implementation.
    mutating func willInsert(_ db: Database) throws {
        try initializeTimestamps(db)
    }
    
    /// Sets `creationDate` and `modificationDate` to the transaction date,
    /// if they are nil.
    mutating func initializeTimestamps(_ db: Database) throws {
        if creationDate == nil {
            creationDate = try db.transactionDate
        }
        if modificationDate == nil {
            modificationDate = try db.transactionDate
        }
    }
    
    /// Sets `modificationDate`, and executes an `UPDATE` statement
    /// on all columns.
    ///
    /// - parameter modificationDate: The modification date. If nil, the
    ///   transaction date is used.
    mutating func updateWithTimestamp(_ db: Database, modificationDate: Date? = nil) throws {
        self.modificationDate = try modificationDate ?? db.transactionDate
        try update(db)
    }
    
    /// Modifies the record according to the provided `modify` closure, and,
    /// if and only if the record was modified, sets `modificationDate` and
    /// executes an `UPDATE` statement that updates the modified columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     var player = Player.find(db, id: 1)
    ///     let modified = try player.updateChangesWithTimestamp(db) {
    ///         $0.score = 1000
    ///     }
    ///     if modified {
    ///         print("player was modified")
    ///     } else {
    ///         print("player was not modified")
    ///     }
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - modificationDate: The modification date. If nil, the
    ///       transaction date is used.
    ///     - modify: A closure that modifies the record.
    /// - returns: Whether the record had changes.
    @discardableResult
    mutating func updateChangesWithTimestamp(
        _ db: Database,
        modificationDate: Date? = nil,
        modify: (inout Self) -> Void)
    throws -> Bool
    {
        // Grab the changes performed by `modify`
        let initialChanges = try databaseChanges(modify: modify)
        if initialChanges.isEmpty {
            return false
        }
        
        // Update modification date and grab its column name
        let dateChanges = try databaseChanges(modify: {
            $0.modificationDate = try modificationDate ?? db.transactionDate
        })
        
        // Update the modified columns
        let modifiedColumns = Set(initialChanges.keys).union(dateChanges.keys)
        try update(db, columns: modifiedColumns)
        return true
    }
    
    /// Sets `modificationDate`, and executes an `UPDATE` statement that
    /// updates the `modificationDate` column, if and only if the record
    /// was modified.
    ///
    /// - parameter modificationDate: The modification date. If nil, the
    ///   transaction date is used.
    mutating func touch(_ db: Database, modificationDate: Date? = nil) throws {
        try updateChanges(db) {
            $0.modificationDate = try modificationDate ?? db.transactionDate
        }
    }
}
```
