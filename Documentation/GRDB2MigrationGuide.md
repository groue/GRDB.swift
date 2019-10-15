Migrating From GRDB 2 to GRDB 3
===============================

GRDB 3 comes with new features, but also a few breaking changes, and a set of updated good practices. This guide aims at helping you upgrading your applications.

**For all users**

- [Swift 4.1 Required]
- [iOS 8 Sunsetting]
- [Database Schema Recommendations]
- [Record Protocols Renaming]
- [Columns Definition]

**By topic**

- [If You Use Database Queues]
- [If You Use Database Pools]
- [If You Use Database Snapshots]
- [If You Use Record Types]
- [If You Use Custom Requests]
- [If You Use RxGRDB]
- [Notable Documentation Updates]


## Swift 4.1 Required

GRDB 3 uses [conditional conformances], introduced in Swift 4.1. It can only be built on Xcode 9.3+.


## iOS 8 Sunsetting

GRDB 3 is only tested on iOS 9+, due to a limitation in Xcode 9.3. Code that targets older versions of SQLite and iOS is still there, but is not supported.


## Database Schema Recommendations

GRDB 2 was totally schema-agnostic, and would gladly accept any database.

GRDB 3 still accepts any database, but brings two schema recommendations:

- :bulb: Integer primary keys should be auto-incremented, in order to avoid any row id to be reused.
    
    When ids can be reused, your app and [database observation tools] may think that a row was updated, when it was actually deleted, then replaced. Depending on your application needs, this may be OK. Or not.
    
    GRDB 3 thus comes with a new good practice: use the `autoIncrementedPrimaryKey` method when you create a database table with an integer primary key:
    
    ```diff
     try db.create(table: "author") { t in
    -    t.column("id", .integer).primaryKey() // GRDB 2
    +    t.autoIncrementedPrimaryKey("id")     // GRDB 3 recommendation
         t.column("name", .text).notNull()
     }
    ```

- :bulb: Database table names should be singular, and camel-cased. Make them look like Swift identifiers: `place`, `country`, `postalAddress`, 'httpRequest'.
    
    This will help you using the new [Associations] feature when you need it. Database table names that follow another naming convention are totally OK, but you will need to perform extra configuration.
    
    This convention is applied by the default implementation of the `TableRecord.databaseTableName`: see [If You Use Record Types] below.

Since you are reading this guide, your application has already defined its database schema. You can migrate it in order to apply the new recommendations, if needed. Below is a sample code that uses [DatabaseMigrator], the recommended tool for managing your database schema:

```swift
var migrator = DatabaseMigrator()

// Existing GRDB 2 migration:
migrator.registerMigration("initial") { db in
    try db.create(table: "authors") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text).notNull()
    }
    try db.create(table: "books") { t in
        t.column("id", .integer).primaryKey()
        t.column("authorId", .integer).notNull().references("authors")
        t.column("title", .text).notNull()
    }
}

// New GRDB 3 migration:
// - Rename tables so that they look like Swift identifiers (singular and camelCased)
// - Make integer primary keys auto-incremented
//
// Since several tables are recreated from scratch, referential integrity
// constraints may break during the process. The
// registerMigrationWithDeferredForeignKeyCheck method makes sure that foreign
// key checks are temporarily disabled, and checked at the end:
migrator.registerMigrationWithDeferredForeignKeyCheck("GRDB3") { db in
    try db.create(table: "author") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
    }
    try db.create(table: "book") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("authorId", .integer).notNull().references("author")
        t.column("title", .text).notNull()
    }
    try db.execute("""
        INSERT INTO author SELECT * FROM authors;
        INSERT INTO book SELECT * FROM books;
        """)
    try db.drop(table: "authors")
    try db.drop(table: "books")
}
```


## Record Protocols Renaming

GRDB 3 has renamed the [record protocols]:

- `RowConvertible` -> `FetchableRecord`
- `TableMapping` -> `TableRecord`
- `Persistable` -> `PersistableRecord`
- `MutablePersistable` -> `MutablePersistableRecord`

After upgrading, build your project: the compiler will guide you through the renaming by the way of fixits.


## Columns Definition

GRDB 2 has you define columns of the query interface with the Column type:

```swift
// GRDB 2
let nameColumn = Column("name")
let arthur = try Player.filter(nameColumn == "Arthur").fetchOne(db)
```

A recommended practice was to define enum namespaces in record types:

```swift
// GRDB 2
struct Player: RowConvertible, TableMapping {
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let score = Column("score")
    }
    
    init(row: Row) {
        id = row[Columns.id]
        name = row[Columns.name]
        score = row[Columns.score]
    }
}
```

In GRDB 3, `Column` is still there, but a new `ColumnExpression` protocol has been introduced in order to streamline column enums:

```swift
// GRDB 3
struct Player: FetchableRecord, TableRecord {
    enum Columns: String, ColumnExpression {
        case id, name, score
    }
    
    init(row: Row) {
        id = row[Columns.id]
        name = row[Columns.name]
        score = row[Columns.score]
    }
}

extension Player {
    static func filter(name: String) -> QueryInterfaceRequest<Player> {
        return filter(Columns.name == name)
    }
    
    static var maximumScore: QueryInterfaceRequest<Int> {
        return select(max(Columns.score), as: Int.self)
    }
}
```

When your record adopts the Codable protocol, you can use its [coding keys](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types) to safely define database columns:

```swift
// GRDB 3
struct Player: Codable {
    var id: Int64
    var name: String
    var score: Int
}

extension Player: FetchableRecord, PersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id.stringValue)
        static let name = Column(CodingKeys.name.stringValue)
        static let score = Column(CodingKeys.score.stringValue)
    }
    
    static func filter(name: String) -> QueryInterfaceRequest<Player> {
        return filter(Columns.name == name)
    }
    
    static var maximumScore: QueryInterfaceRequest<Int> {
        return select(max(Columns.score), as: Int.self)
    }
}
```


## If You Use Database Queues

With GRDB 2, you used to access the database through the `inDatabase` or `inTransaction` [DatabaseQueue] methods:

```swift
// GRDB 2
let players = try dbQueue.inDatabase { db in
    try Player.fetchAll(db)
}

try dbQueue.inDatabase { db in
    try player.updateChanges(db)
}

var balance: Amount! = nil
try dbQueue.inTransaction { db in
    try Credit(destinationAccout, amount).insert(db)
    try Debit(sourceAccount, amount).insert(db)
    balance = try sourceAccount.fetchBalance(db)
    return .commit
}
```

The code above still runs, unchanged, in GRDB 3.

Yet it is now recommended that you use the `read` and `write` methods instead:

```swift
// GRDB 3
let players = try dbQueue.read { db in
    try Player.fetchAll(db)
}

try dbQueue.write { db in
    try player.updateChanges(db)
}

let balance = try dbQueue.write { db in
    try Credit(destinationAccout, amount).insert(db)
    try Debit(sourceAccount, amount).insert(db)
    return try sourceAccount.fetchBalance(db)
}
```

The purpose of the new `read` and `write` methods is to soothe the "transaction mental load" of previous versions of GRDB, a legacy of the [FMDB] heritage. All developers can *forget* to open transactions, with the unfortunate consequence that the database may end up containing inconsistent values. Experienced developers may *wonder* whether they should open transactions or not, even when this doesn't matter a lot.

With GRDB 3, use `read` when you need to read values. It's impossible to write within a `read` block, which means that you can be sure that no unwanted side effect can happen.

When you need to write, use `write`: your database changes are automatically wrapped in a transaction, with the guarantee that all changes are written to disk, or, should any error happen, none at all.

Of course, precise transaction handling sometimes matter. Check the updated [Transactions and Savepoints] chapter.


## If You Use Database Pools

With GRDB 2, you used to access the database through the `read`, `write` or `writeInTransaction` [DatabasePool] methods:

```swift
// GRDB 2
let players = try dbPool.read { db in
    try Player.fetchAll(db)
}

try dbPool.write { db in
    try player.updateChanges(db)
}

var balance: Amount! = nil
try dbPool.writeInTransaction { db in
    try Credit(destinationAccout, amount).insert(db)
    try Debit(sourceAccount, amount).insert(db)
    balance = try sourceAccount.fetchBalance(db)
    return .commit
}
```

In GRDB 3, the `write` method has changed: it now automatically wraps your database changes in a transaction, which means that the last block can be rewritten as below:

```swift
// GRDB 3
let balance = try dbPool.write { db in
    try Credit(destinationAccout, amount).insert(db)
    try Debit(sourceAccount, amount).insert(db)
    return try sourceAccount.fetchBalance(db)
}
```

Side effect: you can no longer open explicit transactions inside a `write` block:

```swift
// GRDB 2: OK
// GRDB 3: SQLite error 1 with statement `BEGIN DEFERRED TRANSACTION`:
//         cannot start a transaction within a transaction
try dbPool.write { db in
    try db.inTransaction { ... }
}
```

When precise transaction handling is needed, check the updated [Transactions and Savepoints] chapter.

The purpose of this change is to prevent an easy misuse of database pools in previous GRDB versions. Unless writes were wrapped inside an explicit transactions, concurrent reads could see an inconsistent state of the database:

```swift
// GRDB 2: unsafe
// GRDB 3: safe
try dbPool.write { db in
    try Credit(destinationAccout, amount).insert(db)
    try Debit(sourceAccount, amount).insert(db)
}
```

Since `write` now wraps your changes in a transaction, you have the guarantee that concurrent reads can't see them until they are all written to disk.


## If You Use Database Snapshots

With GRDB 2, you used to create [database snapshots] with the `makeSnaphot` [DatabasePool] method. For example:

```swift
// GRDB 2
let snapshot: DatabaseSnapshot = try dbPool.write { db in
    try Player.deleteAll()
    return dbPool.makeSnapshot()
}

// Guaranteed to be zero
let count = try snapshot.read { db in
    try Player.fetchCount(db)
}
```

GRDB 3 will crash the above code on the `makeSnapshot()` line, with a fatal error: "makeSnapshot() must not be called from inside a transaction."

To avoid this error, you will need [precise transaction handling]:

```swift
// GRDB 3
let snapshot: DatabaseSnapshot = try dbPool.writeWithoutTransaction { db in
    try Player.deleteAll()
    return dbPool.makeSnapshot()
}
```


## If You Use Record Types

Record types that adopt the former TableMapping protocol, renamed TableRecord, used to declare their table name:

```swift
// GRDB 2
struct Place: TableMapping {
    static let databaseTableName = "place"
}
print(Place.databaseTableName) // print "place"
```

With GRDB 3, the `databaseTableName` property gets a default implementation:

```swift
// GRDB 3
struct Place: TableRecord { }
print(Place.databaseTableName) // print "place"
```

That default name follows the [Database Schema Recommendations]: it is singular, camel-cased, and looks like a Swift identifier:

- Place: `place`
- Country: `country`
- PostalAddress: `postalAddress`
- HTTPRequest: `httpRequest`
- TOEFL: `toefl`

When you subclass the Record class, the Swift compiler won't let you profit from this default name: you have to keep on providing an explicit table name:

```swift
// GRDB 2 and GRDB 3
class Place: Record {
    override var databaseTableName: String {
        return "place"
    }
}
```


## If You Use Custom Requests

[Custom requests] let you escape the limitations of the [query interface], when it can not generate the requests you need.

You may, for example, use `SQLRequest`:

```swift
// GRDB 2
extension Player {
    static func filter(color: Color) -> AnyTypedRequest<Player> {
        let sql = "SELECT * FROM players WHERE color = ?"
        let request = SQLRequest(sql, arguments: [color])
        return request.asRequest(of: Player.self)
    }
}

let players = try Player.filter(color: .red).fetchAll(db)
```

The `AnyTypedRequest` type is no longer available, and `SQLRequest` is now a generic type:

```swift
// GRDB 3
extension Player {
    static func filter(color: Color) -> SQLRequest<Player> {
        let sql = "SELECT * FROM players WHERE color = ?"
        return SQLRequest(sql, arguments: [color])
    }
}

let players = try Player.filter(color: .red).fetchAll(db)
```

See the updated [Custom Requests](../README.md#custom-requests) chapter for more information.


## If You Use RxGRDB

Some RxGRDB APIs have slighly changed. Did you track multiple requests at the same time with "fetch tokens"?

```swift
// GRDB 2
dbQueue.rx
    .fetchTokens(in: [request, ...])
    .mapFetch { db in try fetchResult(db) }
    .subscribe(...)
```

Now you'll write instead:

```swift
// GRDB 3
ValueObservation
    .tracking([request, ...], fetch: { db in try fetchResult(db) })
    .rx
    .fetch(in: dbQueue)
    .subscribe(...)
```

It's just a syntactic change, without any impact on the runtime.

GRDB 3.6 also introduces a new protocol, [DatabaseRegionConvertible], that allows a better encapsulation of complex requests, and a streamlined observable definition.

For example:

```swift
// GRDB 2: Track a team and its players
let teamId = 1
let teamRequest = Team.filter(key: teamId)
let playersRequest = Player.filter(teamId: teamId)
dbQueue.rx
    .fetchTokens(in: [teamRequest, playersRequest])
    .mapFetch { db -> TeamInfo? in
        guard let team = try teamRequest.fetchOne(db) else {
            return nil
        }
        let players = try playersRequest.fetchAll(db)
        return TeamInfo(team: team, players: players)
    }
    .subscribe(onNext: { teamInfo: TeamInfo? in
        ...
    })

// GRDB 3: Track a team and its players
struct TeamInfoRequest: DatabaseRegionConvertible { ... }
let request = TeamInfoRequest(teamId: 1)
ValueObservation.tracking(request, fetch: { try request.fetchOne($0) })
    .rx
    .fetch(in: dbQueue)
    .subscribe(onNext: { teamInfo: TeamInfo? in
        ...
    })
```


## Notable Documentation Updates

If you have time, you may dig deeper in GRDB 3 with those updated documentation chapter:

- [Database Queues](../README.md#database-queues): focus on the new `read` and `write` methods.
- [Transactions and Savepoints](../README.md#transactions-and-savepoints): the chapter has been rewritten in order to introduce transactions as a power-user feature.
- [ScopeAdapter](../README.md#scopeadapter): do you use row adapters? If so, have a look.
- [Examples of Record Definitions](../README.md#examples-of-record-definitions): this new chapter provides a handy reference of the three main ways to define record types (Codable, plain struct, Record subclass).
- [SQL Operators](../README.md#sql-operators): the chapter introduces the new `joined(operator:)` method that lets you join a chain of expressions with `AND` or `OR` without nesting: `[cond1, cond2, ...].joined(operator: .and)`.
- [Custom Requests](../README.md#custom-requests): the old `Request` and `TypedRequest` protocols have been replaced with `FetchRequest`. If you want to know more about custom requests, check this chapter.
- [Migrations](../README.md#migrations): learn how to check if a migration has been applied (very useful for migration tests).


[How To Upgrade]: #how-to-upgrade
[Database Schema Recommendations]: #database-schema-recommendations
[Record Protocols Renaming]: #record-protocols-renaming
[Columns Definition]: #columns-definition
[Swift 4.1 Required]: #swift-41-required
[iOS 8 Sunsetting]: #ios-8-sunsetting
[If You Use Database Queues]: #if-you-use-database-queues
[If You Use Database Pools]: #if-you-use-database-pools
[If You Use Database Snapshots]: #if-you-use-database-snapshots
[If You Use Record Types]: #if-you-use-record-types
[If You Use Custom Requests]: #if-you-use-custom-requests
[If You Use RxGRDB]: #if-you-use-rxgrdb
[Notable Documentation Updates]: #notable-documentation-updates
[RxGRDB]: http://github.com/RxSwiftCommunity/RxGRDB
[Associations]: AssociationsBasics.md
[DatabaseMigrator]: ../README.md#migrations
[database observation tools]: ../README.md#database-changes-observation
[Transactions and Savepoints]: ../README.md#transactions-and-savepoints
[precise transaction handling]: ../README.md#transactions-and-savepoints
[DatabaseQueue]: ../README.md#database-queues
[DatabasePool]: ../README.md#database-pools
[database snapshots]: ../README.md#database-snapshots
[FMDB]: http://github.com/ccgus/fmdb
[record protocols]: ../README.md#record-protocols-overview
[Custom requests]: ../README.md#custom-requests
[query interface]: ../README.md#the-query-interface
[DatabaseRegionConvertible]: https://github.com/groue/GRDB.swift#the-databaseregionconvertible-protocol
[conditional conformances]: https://github.com/apple/swift-evolution/blob/master/proposals/0143-conditional-conformances.md
