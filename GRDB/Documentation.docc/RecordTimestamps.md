# Record Timestamps and Transaction Date

Learn how applications can save creation and modification dates of records.

## Overview

Record timestamps are the responsibility of your application. This article provides some sample code that you can adapt for your specific needs.

> Note: Creation and modification timestamps can be automatically handled by [SQLite triggers](https://www.sqlite.org/lang_createtrigger.html). We'll explore a different technique.
>
> This is not an advice against triggers, and you won't feel hindered in any way if you prefer to use triggers. Still, consider:
>
> - A trigger does not suffer any exception, when some applications eventually want to fine-tune timestamps, or to perform migrations without touching timestamps.
> - The "current time" according to SQLite can't be controlled in tests and previews.
> - The "current time" according to SQLite is not guaranteed to be constant in a given transaction, and this may create undesired timestamp variations.

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

In the rest of the article, we'll address insertion first, then updates, and finally we'll see a way to avoid those optional timestamps.

## Insertion Timestamp

On insertion, the record should get fresh `creationDate` and `modificationDate`. The ``MutablePersistableRecord`` protocol provides the necessary tooling:

```swift
extension Player: Encodable, MutablePersistableRecord {
    // Update timestamps before insertion
    mutating func willInsert(_ db: Database) throws {
        creationDate = try db.transactionDate
        modificationDate = try db.transactionDate
    }
    
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

Note that we are using the ``Database/transactionDate`` instead of `Date()`. This has two advantages:

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
// Increment the player score.
try dbQueue.write { db in
    var player: Player
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
> 2. The second reason is that the library indeed discourages automatic changes to the modification date from the general `update` method.
>
>     While convenient-looking at first sight, users eventually want to disable those automatic updates. That's because application requirements can change, and developers can overlook some corner cases. And that's totally fine.
>
>     How do existing libraries that provide automatic timestamps help those users? Well, this is not pretty. [ActiveRecord](https://stackoverflow.com/questions/861448/is-there-a-way-to-avoid-automatically-updating-rails-timestamp-fields) uses globals (not thread-safe). [Django ORM](https://stackoverflow.com/questions/7499767/temporarily-disable-auto-now-auto-now-add)... I don't know how Django help users.
>
> 2. Not all applications need one modification timestamp. Some need one timestamp per property, or per group of property.
>
> All in all, by not providing this feature, all applications are treated equally: they are responsible for bumping timestamps when they need.
>
> Applications can help themselves, though. For example, if several records share the same timestamps, it is possible to introduce a dedicated protocol:
>
> ```swift
> // The protocol for timestamps records 
> protocol TimestampedRecord {
>     var creationDate: Date? { get set }
>     var modificationDate: Date? { get set }
> }
>
> extension MutablePersistableRecord where Self: TimestampedRecord {
>     // Bumps the modification date, and executes an UPDATE statement on all columns.
>     mutating func updateWithTimestamp(_ db: Database) throws {
>         self.modificationDate = try db.transactionDate
>         try update(db)
>     }
> }
> 
> private struct Player: Codable, MutablePersistableRecord, TimestampedRecord {
>     var id: Int64?
>     var creationDate: Date?
>     var modificationDate: Date?
>     var name: String
>     var score: Int
> }
>
> // Increment the player score.
> try dbQueue.write { db in
>     var player: Player
>     player.score += 1
>     try player.updateWithTimestamp(db) // instead of update(db)
> }
> ```


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
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    // Update timestamps before insertion
    mutating func willInsert(_ db: Database) throws {
        creationDate = try db.transactionDate
        modificationDate = try db.transactionDate
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
    static var databaseTableName: String { Player.databaseTableName }
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
