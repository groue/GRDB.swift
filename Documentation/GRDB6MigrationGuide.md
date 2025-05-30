Migrating From GRDB 5 to GRDB 6
===============================

**This guide aims at helping you upgrading your applications from GRDB 5 to GRDB 6.**

- [Preparing the Migration to GRDB 6](#preparing-the-migration-to-grdb-6)
- [New requirements](#new-requirements)
- [Primary Associated Types](#primary-associated-types)
- [Record Changes](#record-changes)
- [Other Changes](#other-changes)


## Preparing the Migration to GRDB 6

If you haven't made it yet, upgrade to the [latest GRDB 5 release](https://github.com/groue/GRDB.swift/tags) first, and fix any deprecation warning prior to the GRDB 6 upgrade.

You can then upgrade to GRDB 6. Due to the breaking changes, it is possible that your application code no longer compiles. Follow the fix-its that suggest simple syntactic changes. Other modifications that you need to apply are described below.

## New requirements

GRDB requirements have been bumped:

- **Swift 5.7+** (was Swift 5.3+)
- **Xcode 14.0+** (was Xcode 12.0+)
- iOS 11.0+ (unchanged)
- **macOS 10.13+** (was macOS 10.10+)
- **tvOS 11.0+** (was tvOS 11.0+)
- **watchOS 4.0+** (was watchOS 2.0+)
- **SQLite 3.19.3+** (was SQLite 3.8.5+)

## Primary Associated Types

Request protocols now come with a primary associated type, enabled by [SE-0346](https://github.com/apple/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md). This is a great opportunity to simplify your extensions:

```diff
-extension DerivableRequest where RowDecoder == Book {
+extension DerivableRequest<Book> {
     /// Order books by title, in a localized case-insensitive fashion
     func orderByTitle() -> Self {
         order(Column("title").collating(.localizedCaseInsensitiveCompare))
     }
 }
```

Your extensions to `QueryInterfaceRequest` can be streamlined as well, thanks to [SE-0361](https://github.com/apple/swift-evolution/blob/main/proposals/0361-bound-generic-extensions.md):

```diff
-extension QueryInterfaceRequest where RowDecoder == Player {
+extension QueryInterfaceRequest<Player> {
     func selectID() -> QueryInterfaceRequest<Int64> {
         selectPrimaryKey()
     }
 }
```

The `Cursor` protocol has also gained a primary associated type (the type of its elements).

## Record Changes

The record protocols have been refactored. We tried to keep the amount of modifications to your existing code as small as possible, but some changes could not be avoided.

- **The `FetchableRecord.init(row:)` initializer can now throw errors.**
    
    ```diff
    -let player = Player(row: row)
    +let player = try Player(row: row)
    ```

    Decodable records that derive their `FetchableRecord` implementation from the standard `Decodable` protocol now throw errors when they find unexpected database values (they used to crash in GRDB 5).
    
    If you subclass the `Record` type, you have to update your override of `init(row:)`:
    
    ```diff
     class Player: Record {
    -    required init(row: Row) {
    +    required init(row: Row) throws {
             self.id = row["id"]
             self.name = row["name"]
    -        super.init(row: row)
    +        try super.init(row: row)
         }
     }
    ```
    
    In record types that do not derive their `FetchableRecord.init(row:)` implementation from the standard `Decodable` protocol, you are responsible for throwing decoding errors, as in the sample code below:
    
    <details>
        <summary>Handling untrusted input</summary>
    
    For example:
    
    ```swift
    struct LogEntry: FetchableRecord {
        var date: Date
        
        init(row: Row) throws {
            let dbValue: DatabaseValue = row["date"]
            if dbValue.isNull {
                // Handle NULL
                throw ...
            } else if let date = Date.fromDatabaseValue(dbValue) {
                self.date = date
            } else {
                // Handle invalid date
                throw ...
            }
        }
    }
    ```
    
    </details>

- **The `EncodableRecord.encode(to:)` method can now throw errors.**
    
    Encodable records that derive their `EncodableRecord` implementation from the standard `Encodable` protocol now throw errors when they can't be encoded into database values (they used to crash in GRDB 5).
    
    If you subclass the `Record` type, you have to update your override of `encode(to:)`:
    
    ```diff
     class Player: Record {
    -    override func encode(to container: inout PersistenceContainer) {
    +    override func encode(to container: inout PersistenceContainer) throws {
             container["id"] = id
             container["name"] = name
         }
     }
    ```
    
    This change has an impact on a few other apis, that can now throw errors as well:
    
    ```diff
    -let dictionary = player.databaseDictionary
    -let changes = newPlayer.databaseChanges(from: oldPlayer)
    -let changes = player.databaseChanges // Record class only
    +let dictionary = try player.databaseDictionary
    +let changes = try newPlayer.databaseChanges(from: oldPlayer)
    +let changes = try player.databaseChanges // Record class only
    ```

- **The signature of the `didInsert` method has changed**.
    
    You have to update all the `didInsert` methods in your application:
    
    ```diff
     struct Player: MutablePersistableRecord {
         var id: Int64?
     
         // Update auto-incremented id upon successful insertion
    -    mutating func didInsert(with rowID: Int64, for column: String?) {
    -        id = rowID
    +    mutating func didInsert(_ inserted: InsertionSuccess) {
    +        id = inserted.rowID
         }
     }
    ```
    
    If you subclass the `Record` class, you have to call `super` at some point of your implementation:
    
    ```diff
     class Player: Record {
         var id: Int64?
     
         // Update auto-incremented id upon successful insertion
    -    override func didInsert(with rowID: Int64, for column: String?) {
    -        id = rowID
    +    override func didInsert(_ inserted: InsertionSuccess) {
    +        super.didInsert(inserted)
    +        id = inserted.rowID
         }
     }
    ```

- **PersistableRecord types now customize persistence methods with "persistence callbacks"**.
    
    It is no longer possible to override persistence methods such as `insert` or `update`. Customizing the persistence methods is now possible with callbacks such as `willSave`, `willInsert`, or `didDelete` (see [persistence callbacks] for the full list of callbacks).
    
    **You have to remove the methods below from your own code base**:
    
    ```swift
    // GRDB 6: remove those methods from your code
    func insert(_ db: Database) throws
    func didInsert(with rowID: Int64, for column: String?)
    func update(_ db: Database, columns: Set<String>) throws
    func save(_ db: Database) throws
    func delete(_ db: Database) throws -> Bool
    func exists(_ db: Database) throws -> Bool
    ```
    
    - `insert(_:)`: customization is now made with [persistence callbacks].
    - `didInsert(with:for:)`: this method was renamed `didInsert(_:)` (see previous bullet point).
    - `update(_:columns:)`: customization is now made with [persistence callbacks].
    - `save(_:)`: customization is now made with [persistence callbacks].
    - `delete(_:)`: customization is now made with [persistence callbacks].
    - `exists(_:)`: this method is no longer customizable.
    
    To help you update your applications with persistence callbacks, let's look at two examples.
    
    First, check the updated [Single-Row Tables](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/singlerowtables) guide, if your application defines a "singleton record".
    
    Next, let's consider a record that performs some validation before insertion and updates. In GRDB 5, this would look like:
    
    ```swift
    // GRDB 5
    struct Link: PersistableRecord {
        var url: URL
        
        func insert(_ db: Database) throws {
            try validate()
            try performInsert(db)
        }
        
        func update(_ db: Database, columns: Set<String>) throws {
            try validate()
            try performUpdate(db, columns: columns)
        }
        
        func validate() throws {
            if url.host == nil {
                throw ValidationError("url must be absolute.")
            }
        }
    }
    ```
    
    With GRDB 6, record validation can be implemented with the `willSave` callback:
    
    ```swift
    // GRDB 6
    struct Link: PersistableRecord {
        var url: URL
        
        func willSave(_ db: Database) throws {
            if url.host == nil {
                throw ValidationError("url must be absolute.")
            }
        }
    }
    
    try link.insert(db) // Calls the willSave callback
    try link.update(db) // Calls the willSave callback
    try link.save(db)   // Calls the willSave callback
    try link.upsert(db) // Calls the willSave callback
    ```
    
    If you subclass the `Record` class, you have to call `super` at some point of your implementation:
    
    ```swift
    // GRDB 6
    class Link: Record {
        var url: URL
        
        override func willSave(_ db: Database) throws {
            try super.willSave(db)
            if url.host == nil {
                throw ValidationError("url must be absolute.")
            }
        }
    }
    ```

- **Handling of the `IGNORE` conflict policy**
    
    The SQLite [IGNORE](https://www.sqlite.org/lang_conflict.html) conflict policy has SQLite skip insertions and updates that violate a schema constraint, without reporting any error. You can skip this paragraph if you do not use this policy.
    
    GRDB 6 has slightly changed the handling of the `IGNORE` policy.
    
    The `didInsert` callback is now always called on `INSERT OR IGNORE` insertions. In GRDB 5, `didInsert` was not called for record types that specify the `.ignore` conflict policy on inserts:
    
    ```swift
    // Given a record with ignore conflict policy for inserts...
    struct Player: TableRecord, FetchableRecord {
        static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .ignore)
    }
    
    // GRDB 5: Does not call didInsert
    // GRDB 6: Calls didInsert
    try player.insert(db)
    ```
    
    Since `INSERT OR IGNORE` may silently fail, the `didInsert` method will be called with some random rowid in case of failed insert. You can detect failed insertions with the new method `insertAndFetch`:
    
    ```swift
    // How to detect failed `INSERT OR IGNORE`:
    // INSERT OR IGNORE INTO player ... RETURNING *
    if let insertedPlayer = try player.insertAndFetch(db) {
        // Succesful insertion
    } else {
        // Ignored failure
    }
    ```
    
## Other Changes

- The initializer of in-memory databases can now throw errors:

    ```diff
    -let dbQueue = DatabaseQueue()
    +let dbQueue = try DatabaseQueue()
    ```

- The `selectID()` method is removed. You can provide your own implementation, based on the new `selectPrimaryKey(as:)` method:

    ```swift
    extension QueryInterfaceRequest<Player> {
        func selectID() -> QueryInterfaceRequest<Int64> {
            selectPrimaryKey()
        }
    }
    ```

- `Cursor.isEmpty` is now a throwing property, instead of a method:
    
    ```diff
    -if try cursor.isEmpty() { ... }
    +if try cursor.isEmpty { ... }
    ```

- The `Record.copy()` method was removed, without replacement.

- The `DerivableRequest.limit(_:offset_:)` method was removed, without replacement.
    
    You can still limit `QueryInterfaceRequest`, but associations can no longer be limited:
    
    ```swift
    // Still OK: a limited request of authors
    let request = Author.limit(10)

    // Still OK: a limited request of books
    let request = author.request(for: Author.books).limit(10)
    
    // No longer possible: including a limited association
    let request = Author.including(all: Author.books.limit(10))
    ```

- `DatabaseRegionObservation.start(in:onError:onChange:)` now returns a cancellable.
    
    ```swift
    let observation = DatabaseRegionObservation.tracking(Player.all())
    
    // GRDB 5
    do {
        let observer = try observation.start(in: dbQueue) { db in
            print("Players were modified")
        }
    } catch {
        // handle error
    }
    
    // GRDB 6
    let cancellable = observation.start(
        in: dbQueue,
        onError: { error in /* handle error */ },
        onChange: { db in
            print("Players were modified")
        })
    ```
    
    The `DatabaseRegionObservation.extent` property was removed. You now control the duration of the observation with the cancellable returned from the `start` method.

- Database cursors no longer have a `statement` property. When you want information about the database statement used by a cursor, use dedicated cursor properties. For example:

    ```diff
    -let sql = cursor.statement.sql
    -let columns = cursor.statement.columnNames
    +let sql = cursor.sql
    +let columns = cursor.columnNames
    ```

- The transaction hook `Database.afterNextTransactionCommit(_:)` was renamed `Database.afterNextTransaction(onCommit:onRollback:)`, and is now able to report rollbacks as well as commits.
    
    ```diff
    -db.afterNextTransactionCommit { db in
    +db.afterNextTransaction { db in
         print("Succesful commit")
     }
    ```

- If your application directly embeds the `GRDB.xcodeproj` or `GRDBCustom.xcodeproj` project, then you have to update your dependencies. Those projects now define cross-platform targets, and you must perform the following actions:

    - In the **Target Dependencies** section of the **Build Phases** tab of your **application targets**, replace the GRDB target with `GRDB` or `GRDBCustom`.
    - In the **Embedded Binaries** section of the **General**  tab of your **application target**, replace the GRDB framework with `GRDB.framework` or `GRDBCustom.framework`.

[persistence callbacks]: ../README.md#persistence-callbacks
