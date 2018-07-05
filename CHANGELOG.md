Release Notes
=============

## 3.1.0

Released June 17, 2018 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v3.0.0...v3.1.0)

### New

- [#371](https://github.com/groue/GRDB.swift/pull/371): Database can have a label.
- [#372](https://github.com/groue/GRDB.swift/pull/372): Upgrade custom SQLite builds to 3.24.0.


## 3.0.0

Released June 7, 2018 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.10.0...v3.0.0)

GRDB 3 is a release focused on **modernization**, **safety**, and **associations between record types**.

It comes with new features, but also a few breaking changes, and a set of updated good practices. The [GRDB 2 Migration Guide](Documentation/GRDB2MigrationGuide.md) will help you upgrading your applications.


### New

- Associations and Joins ([#319](https://github.com/groue/GRDB.swift/pull/319)).
- Enhancements to logical operators ([#336](https://github.com/groue/GRDB.swift/pull/336)).
- Foster auto-incremented primary keys ([#337](https://github.com/groue/GRDB.swift/pull/337)).
- ColumnExpression Protocol ([#340](https://github.com/groue/GRDB.swift/pull/340)).
- Improved parsing of dates and date components ([#334](https://github.com/groue/GRDB.swift/pull/334) by @sobri909).
- Common API for requests and associations derivation ([#347](https://github.com/groue/GRDB.swift/pull/347)).
- `DatabaseMigrator.appliedMigrations(in:)` returns the set of applied migrations identifiers in a database ([#321](https://github.com/groue/GRDB.swift/pull/321)).
- `Database.isSQLiteInternalTable(_:)` returns whether a table name is an internal SQLite table ([#321](https://github.com/groue/GRDB.swift/pull/321)).
- `Database.isGRDBInternalTable(_:)` returns whether a table name is an internal GRDB table ([#321](https://github.com/groue/GRDB.swift/pull/321)).
- Upgrade custom SQLite builds to [v3.23.0](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).
- Improve Row descriptions ([#331](https://github.com/groue/GRDB.swift/pull/331)).
- Request derivation protocols ([#329](https://github.com/groue/GRDB.swift/pull/329)).
- Preliminary Linux support for the main framework ([#354](https://github.com/groue/GRDB.swift/pull/354)).
- Automatic table name generation ([#355](https://github.com/groue/GRDB.swift/pull/355)).
- Delayed Request Ordering ([#365](https://github.com/groue/GRDB.swift/pull/365)).


### Breaking Changes

- Swift 4.1 is now required.
- iOS 8 sunsetting: GRDB 3 is only tested on iOS 9+, due to a limitation in Xcode 9.3. Code that targets older versions of SQLite and iOS is still there, but is not supported.
- The Record protocols have been renamed: `RowConvertible` to `FetchableRecord`, `Persistable` to `PersistableRecord`, and `TableMapping` to `TableRecord` ([#314](https://github.com/groue/GRDB.swift/pull/314)).
- Implicit transaction in DatabasePool.write and DatabaseQueue.write ([#332](https://github.com/groue/GRDB.swift/pull/332)).
- `Request` and `TypedRequest` protocols have been merged into `FetchRequest` ([#311](https://github.com/groue/GRDB.swift/pull/311), [#328](https://github.com/groue/GRDB.swift/pull/328), [#348](https://github.com/groue/GRDB.swift/pull/348)).
- Reversing unordered requests has no effect ([#342](https://github.com/groue/GRDB.swift/pull/342)).
- The `IteratorCursor` type has been removed. Use `AnyCursor` instead ([#312](https://github.com/groue/GRDB.swift/pull/312)).
- Row scopes collection, breadth-first scope search ([#335](https://github.com/groue/GRDB.swift/pull/335)).
- Expressions are no longer PATs ([#330](https://github.com/groue/GRDB.swift/pull/330)).
- Deprecated APIs have been removed.


### Documentation Diff

- [Associations](Documentation/AssociationsBasics.md): Discover the major GRDB 3 feature
- [Database Queues](README.md#database-queues): focus on the `read` and `write` methods.
- [Database Pools](README.md#database-pools): focus on the `read` and `write` methods.
- [Transactions and Savepoints](README.md#transactions-and-savepoints): the chapter has been rewritten in order to introduce transactions as a power-user feature.
- [ScopeAdapter](README.md#scopeadapter): do you use row adapters? If so, have a look.
- [TableRecord Protocol](README.md#tablerecord-protocol): updated for the new automatic generation of database table name.
- [Examples of Record Definitions](README.md#examples-of-record-definitions): this new chapter provides a handy reference of the three main ways to define record types (Codable, plain struct, Record subclass).
- [SQL Operators](README.md#sql-operators): the chapter introduces the new `joined(operator:)` method that lets you join a chain of expressions with `AND` or `OR` without nesting: `[cond1, cond2, ...].joined(operator: .and)`.
- [Custom Requests](README.md#custom-requests): the old `Request` and `TypedRequest` protocols have been replaced with `FetchRequest`. If you want to know more about custom requests, check this chapter.
- [Customized Decoding of Database Rows](README.md#customized-decoding-of-database-rows): learn how to escape the ready-made `FetchableRecord` protocol when it does not fit your needs.
- [Migrations](README.md#migrations): learn how to check if a migration has been applied (very useful for migration tests).


## 2.10.0

Released March 30, 2018 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.9.0...v2.10.0)

### New

- Support for Swift 4.1 and Xcode 9.3
- Added `Cursor.compactMap` ([SE-0187](https://github.com/apple/swift-evolution/blob/master/proposals/0187-introduce-filtermap.md))

### Deprecated

- `Cursor.flatMap` is deprecated. Use `compactMap` instead.


## 2.9.0

Released February 25, 2018 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.8.0...v2.9.0)

### New

- **Changes tracking overhaul**: changes tracking, a feature previously restricted to the `Record` class and its subclasses, is now available for all records. And it has a better looking API ([documentation](https://github.com/groue/GRDB.swift/blob/master/README.md#changes-tracking)).
- **Database snapshots**: Database pools can now take database snapshots. A snapshot sees an unchanging database content, as it existed at the moment the snapshot was created ([documentation](https://github.com/groue/GRDB.swift/blob/master/README.md#database-snapshots)).
- **Improved support for joined queries**: more than a set on new APIs, we provide a set of guidelines that will help you deal with your wildest joined queries. Check the new [Joined Queries Support](https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support) documentation chapter.
- `Database.columns(in:)` returns information about the columns of a table.
- `Request.adapted(_:)` is no longer experimental.
- `Configuration.allowsUnsafeTransactions` lets you leave transactions opened between two database accesses (see below).
- Support for explicit transaction management, via the new `Database.beginTransaction`, `commit`, and `rollback` methods.


### Fixed

- It is now a programmer error to leave a transaction opened at the end of a database access block:
    
    ```swift
    // Fatal error: A transaction has been left opened at the end of a database access
    try dbQueue.inDatabase { db in
        try db.beginTransaction()
    }
    ```
    
    One can still opt-in for the unsafe behavior by setting the new `allowsUnsafeTransactions` configuration flag:
    
    ```swift
    var config = Configuration()
    config.allowsUnsafeTransactions = true
    let dbQueue = DatabaseQueue(configuration: config)
    
    // OK
    try dbQueue.inDatabase { db in
        try db.beginTransaction()
    }
    ```


### Deprecated

- `Database.columnCount(in:)` is deprecated. Use `db.columns(in:).count` instead.
- `RecordBox`, introduced in [2.7.0](#270), was ill-advised. It has been deprecated. Use [changes tracking](https://github.com/groue/GRDB.swift/blob/master/README.md#changes-tracking) methods on the Persistable protocol instead.
- `Record.hasPersistentChangedValues` has been deprecated, renamed `hasDatabaseChanges`.
- `Record.persistentChangedValues` has been deprecated, renamed `databaseChanges`.


### Documentation Diff

- The [Changes Tracking](https://github.com/groue/GRDB.swift/blob/master/README.md#changes-tracking) chapter has been updated for the new universal support for record changes.
- A new [Database Snapshots](https://github.com/groue/GRDB.swift/blob/master/README.md#database-snapshots) chapter has been added.
- The [Concurrency](https://github.com/groue/GRDB.swift/blob/master/README.md#concurrency) chapter has been updated for database snapshots.
- A new [Differences between Database Queues and Pools](https://github.com/groue/GRDB.swift/blob/master/README.md#differences-between-database-queues-and-pools) chapter has been added, that attempts at visually show how much database pools are different from database queues.
- A new [Joined Queries Support](https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support) chapter has been added.
- The [Row Adapters](https://github.com/groue/GRDB.swift/blob/master/README.md#row-adapters) chapter has been made consistent with the new chapter on joined queries.
- The [Codable Records](https://github.com/groue/GRDB.swift/blob/master/README.md#codable-records) chapter has been made consistent with the new chapter on joined queries.
- The [Database Schema Introspection](https://github.com/groue/GRDB.swift/blob/master/README.md#database-schema-introspection) has been updated for `Database.columns(in:)`


### API diff

```diff
+struct ColumnInfo {
+    let name: String
+    let type: String
+    let isNotNull: Bool
+    let defaultValueSQL: String?
+    let primaryKeyIndex: Int
+}

 struct Configuration {
+    var allowsUnsafeTransactions: Bool
 }
 
 class Database {
+     @available(*, deprecated, message: "Use db.columns(in: tableName).count instead")
      func columnCount(in tableName: String) throws -> Int
+     func columns(in tableName: String) throws -> [ColumnInfo]
+     func beginTransaction(_ kind: TransactionKind? = nil) throws
+     func rollback() throws
+     func commit() throws
 }
 
 class DatabasePool {
+    func makeSnapshot() throws -> DatabaseSnapshot
 }
 
+class DatabaseSnapshot: DatabaseReader { }

 extension MutablePersistable {
+    @discardableResult
+    func updateChanges(_ db: Database, from record: MutablePersistable) throws -> Bool
+    func databaseEqual(_ record: Self) -> Bool
+    func databaseChanges(from record: MutablePersistable) -> [String: DatabaseValue]
 }
 class Record {
-    final func updateChanges(_ db: Database) throws
+    @discardableResult
+    final func updateChanges(_ db: Database) throws -> Bool
 }
 
+@available(*, deprecated, message: "Prefer changes methods defined on the MutablePersistable protocol: databaseEqual(_:), databaseChanges(from:), updateChanges(from:)")
 class RecordBox: Record { }

 class Row {
+    var unscoped: Row
+    var containsNonNullValue: Bool
+    func hasNull(atIndex index: Int) -> Bool
+    subscript<Record: RowConvertible>(_ scope: String) -> Record
+    subscript<Record: RowConvertible>(_ scope: String) -> Record?
 }

 extension TableMapping {
+    static func selectionSQL(alias: String? = nil) -> String
+    static func numberOfSelectedColumns(_ db: Database) throws -> Int
 }

+struct EmptyRowAdapter: RowAdapter { }

 struct ScopeAdapter {
+    init(base: RowAdapter, scopes: [String: RowAdapter])
 }

+func splittingRowAdapters(columnCounts: [Int]) -> [RowAdapter]
```


## 2.8.0

Released January 29, 2018 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.7.0...v2.8.0)

**New**

- Upgrade custom SQLite builds to [v3.22.0](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).
- The FTS5 full-text search engine has been enhanced with [initial token queries](https://sqlite.org/fts5.html#carrotq), and FTS5Pattern has gained a new initializer: `FTS5Pattern(matchingPrefixPhrase:)`
- The `Cursor` protocol is extended with more methods inspired by the standard Sequence protocol: `drop(while:)`, `dropFirst()`, `dropFirst(_:)`, `dropLast()`, `dropLast(_:)`, `joined(separator:)`, `prefix(_:)`, `max()`, `max(by:)`, `min()`, `min(by:)`, `prefix(while:)`, `reduce(into:_:)`, `suffix(_:)`, 


## 2.7.0

Released January 21, 2018 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.6.1...v2.7.0)

**New**

- The new RecordBox class brings changes tracking to any record type ([documentation](https://github.com/groue/GRDB.swift/blob/master/README.md#recordbox-class)):
    
    ```swift
    // A regular record struct
    struct Player: RowConvertible, MutablePersistable { ... }
    
    try dbQueue.inDatabase { db in
        // Fetch a boxed player
        if let boxedPlayer = try RecordBox<Player>.fetchOne(db, key: 1) {
            // boxedPlayer.value is Player
            boxedPlayer.value.score = 300
            
            if boxedPlayer.hasPersistentChangedValues {
                print("player has been modified")
            }
            
            // Does nothing if player has not been modified:
            try boxedPlayer.updateChanges(db)
        }
    }
    ```


## 2.6.1

Released January 19, 2018 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.6.0...v2.6.1)

**Fixed**

- Fixed a crash that could happen when a transaction observer uses the `stopObservingDatabaseChangesUntilNextTransaction()` method.


## 2.6.0

Released January 18, 2018 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.5.0...v2.6.0)

### New

- Database observation has been enhanced:
    
    - `TransactionObserver.stopObservingDatabaseChangesUntilNextTransaction()` allows transaction observers to stop observing the database for the remaining extent of a transaction.
    - GRDB no longer prevents the [truncate optimization](https://www.sqlite.org/lang_delete.html#truncateopt) when no transaction observers are interested in deleted rows.
    - FetchedRecordsController now avoids checking for changes in untracked rowIds.
    - `DatabaseRegion` is a new public type that helps transaction observers recognize impactful database changes. This type is not documented in the main documentation. For more information, see [DatabaseRegion reference](http://groue.github.io/GRDB.swift/docs/2.6/Structs/DatabaseRegion.html), and look at [FetchedRecordsController implementation](https://github.com/groue/GRDB.swift/blob/master/GRDB/Record/FetchedRecordsController.swift).
    - `TransactionObserver` protocol provides default implementations for rarely used callbacks.
    
- `Row` adopts RandomAccessCollection

### API diff

```diff
 extension TransactionObserver {
+    func stopObservingDatabaseChangesUntilNextTransaction()
+
+    // Default implementation
+    func databaseWillCommit() throws
+
+    #if SQLITE_ENABLE_PREUPDATE_HOOK
+    // Default implementation
+    func databaseWillChange(with event: DatabasePreUpdateEvent)
+    #endif
 }

+struct DatabaseRegion: Equatable {
+    var isEmpty: Bool
+
+    init()
+
+    func union(_ other: DatabaseRegion) -> DatabaseRegion
+    mutating func formUnion(_ other: DatabaseRegion)
+
+    func isModified(byEventsOfKind eventKind: DatabaseEventKind) -> Bool
+    func isModified(by event: DatabaseEvent) -> Bool
+}

 class SelectStatement {
+    var fetchedRegion: DatabaseRegion
+
+    @available(*, deprecated, renamed:"DatabaseRegion")
+    typealias SelectionInfo = DatabaseRegion
+    
+    @available(*, deprecated, renamed:"fetchedRegion")
+    var selectionInfo: DatabaseRegion
 }

 enum DatabaseEventKind {
-    func impacts(_ selectionInfo: SelectStatement.SelectionInfo) -> Bool
+    @available(*, deprecated, message: "Use DatabaseRegion.isModified(byEventsOfKind:) instead")
+    func impacts(_ region: DatabaseRegion) -> Bool
 }
 
 protocol Request {
+    // Default implementation
+    func fetchedRegion(_ db: Database) throws -> DatabaseRegion
 }
 
+extension Row: RandomAccessCollection {
+}
+extension RowIndex: Strideable {
}
```


## 2.5.0

Released January 11, 2018 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.4.2...v2.5.0)

### Fixed

- [Transaction observers](https://github.com/groue/GRDB.swift/blob/master/README.md#transactionobserver-protocol) used to be notified of some database changes they were not interested into, in case of complex statements with side effects (foreign key cascades or sql triggers). This has been fixed.


### New

- The query interface has learned to build requests from any key (primary keys and unique keys) ([documentation](https://github.com/groue/GRDB.swift/blob/master/README.md#fetching-by-key)):
    
    ```swift
    // SELECT * FROM players WHERE id = 1
    let request = Player.filter(key: 1)
    let player = try request.fetchOne(db)    // Player?
    
    // SELECT * FROM countries WHERE isoCode IN ('FR', 'US')
    let request = Country.filter(keys: ["FR", "US"])
    let countries = try request.fetchAll(db) // [Country]
    
    // SELECT * FROM players WHERE email = 'arthur@example.com'
    let request = Player.filter(key: ["email": "arthur@example.com"])
    let player = try request.fetchOne(db)    // Player?
    ```
    
    This feature has been introduced in order to ease the use of [RxGRDB](http://github.com/RxSwiftCommunity/RxGRDB):
    
    ```swift
    // New
    Player.filter(key: 1).rx
        .fetchOne(in: dbQueue)
        .subscribe(onNext: { player: Player? in
            print("Player 1 has changed")
        })
    ```


### API diff

```diff
 extension TableMapping {
+    static func filter<PrimaryKeyType: DatabaseValueConvertible>(key: PrimaryKeyType?) -> QueryInterfaceRequest<Self>
+    static func filter<Sequence: Swift.Sequence>(keys: Sequence) -> QueryInterfaceRequest<Self> where Sequence.Element: DatabaseValueConvertible
+    static func filter(key: [String: DatabaseValueConvertible?]?) -> QueryInterfaceRequest<Self>
+    static func filter(keys: [[String: DatabaseValueConvertible?]]) -> QueryInterfaceRequest<Self>
 }
 
 extension QueryInterfaceRequest where T: TableMapping {
+    func filter<PrimaryKeyType: DatabaseValueConvertible>(key: PrimaryKeyType?) -> QueryInterfaceRequest<T>
+    func filter<Sequence: Swift.Sequence>(keys: Sequence) -> QueryInterfaceRequest<T> where Sequence.Element: DatabaseValueConvertible
+    func filter(key: [String: DatabaseValueConvertible?]?) -> QueryInterfaceRequest<T>
+    func filter(keys: [[String: DatabaseValueConvertible?]]) -> QueryInterfaceRequest<T>
 }
 
 extension RowConvertible where Self: TableMapping {
-    static func fetchOne(_ db: Database, key: [String: DatabaseValueConvertible?]) throws -> Self?
+    static func fetchOne(_ db: Database, key: [String: DatabaseValueConvertible?]?) throws -> Self?
 }
```


## 2.4.2

Released January 6, 2018 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.4.1...v2.4.2)

**Fixed**

- When using a database pool, the schema introspection methods could return wrong values whenever the database schema was concurrently read and modified. This has been fixed.
- `DatabasePool.readFromCurrentState` no longer accepts to spawn a reader when a transaction is currently opened on the writer connection.


## 2.4.1

Released December 16, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.4.0...v2.4.1)

**Fixed**

- [#284](https://github.com/groue/GRDB.swift/pull/284): fixes a misuse of the sqlite3_config() function when configuring the global SQLite [Error Log](https://github.com/groue/GRDB.swift/blob/master/README.md#error-log)


## 2.4.0

Released December 3, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.3.1...v2.4.0)

**New**

- [#280](https://github.com/groue/GRDB.swift/pull/280): It is now possible to add an untyped column to an existing table.
    
    ```swift
    try db.alter(table: "players") { t in
        t.add(column: "score")
    }
    ```

- [#281](https://github.com/groue/GRDB.swift/pull/280): The `Database.dropFTS4SynchronizationTriggers` & `Database.dropFTS5SynchronizationTriggers` method help cleaning up synchronized full-text table ([documentation](https://github.com/groue/GRDB.swift/blob/master/README.md#deleting-synchronized-full-text-tables))

**Breaking Change**

- [#282](https://github.com/groue/GRDB.swift/issues/282): This version comes with a breaking change that affects users who manually embed the GRDBCipher and GRDBCustom frameworks in their projects. This change does not affect users of the GRDB framework, or users of GRDBCipher through CocoaPods. Now, instead of embedding the GRDB.xcodeproj project, you have to embed the GRDBCipher.xcodeproj or  GRDBCustom.xcodeproj. Please have a look at the updated [Encryption](https://github.com/groue/GRDB.swift/blob/master/README.md#encryption) and [Custom SQLite Builds](https://github.com/groue/GRDB.swift/blob/master/Documentation/CustomSQLiteBuilds.md) documentation chapters.


## 2.3.1

Released November 8, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.3.0...v2.3.1)

**Fixed**

- GRDB 2.2.0 has introduced a fix in the way [transaction observers](https://github.com/groue/GRDB.swift/blob/master/README.md#transactionobserver-protocol) are notified of empty deferred transactions (`BEGIN; COMMIT;`). That fix was incomplete, and inconsistent.
    
    Now all transactions are notified, without any exception, including:
    
    ```swift
    try db.execute("BEGIN; COMMIT;")
    try db.execute("SAVEPOINT foo; RELEASE SAVEPOINT foo;")
    ```
    
    [Rationale](https://github.com/groue/GRDB.swift/commit/820bc87cfeee701743da852f3634e2c695e911ee#diff-3e791e9db648cd302590c9b86c70757fR376)


## 2.3.0

Released November 5, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.2.0...v2.3.0)

**New**

- Upgrade custom SQLite builds to [v3.21.0](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).


## 2.2.0

Released October 31, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.1.0...v2.2.0)

**New**

- `Database.viewExists(_:)` returns whether a view exists in the database.
- `Database.triggerExists(_:)` returns whether a trigger exists in the database.

**Fixed**

- `DROP VIEW` statements would not drop views ([#267](https://github.com/groue/GRDB.swift/issues/267))
- GRDB used to incorrectly send incomplete transaction notifications to [transaction observers](https://github.com/groue/GRDB.swift/blob/master/README.md#transactionobserver-protocol) in the case of empty deferred transactions. This is no longer the case. Since empty deferred transactions have SQLite consider that no transaction started at all, they are no longer notified to transaction observers:

    ```sql
    -- Nothing happens, and thus no notification is sent
    BEGIN TRANSACTION
    COMMIT
    ```
    
    Those empty deferred transactions still count for the [afterNextTransactionCommit](https://github.com/groue/GRDB.swift/blob/master/README.md#after-commit-hook) database method, and the `.nextTransaction` [observation extent](https://github.com/groue/GRDB.swift/blob/master/README.md#observation-extent).


## 2.1.0

Released October 24, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.0.3...v2.1.0)

### New

- GRDBCipher can now build from command line ([groue/sqlcipher/pull/1](https://github.com/groue/sqlcipher/pull/1) by  [Darren Clark](https://github.com/darrenclark))
- Upgrade custom SQLite builds to [v3.20.1](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).
- The new method `Request.asSQLRequest` allows to inspect the sql and arguments of any request:
    
    ```swift
    let request = Player.all()
    let sql = try request.asSQLRequest(db).sql
    print(sql) // Prints "SELECT * FROM players"
    ```
    
- StatementArguments adopts Equatable


### Fixed

- `DROP TABLE` statements would not drop temporary tables.


### Documentation Diff

- New FAQ: [How do I create a database in my application?](https://github.com/groue/GRDB.swift/blob/master/README.md#how-do-i-create-a-database-in-my-application)
- New FAQ: [How do I print a request as SQL?](https://github.com/groue/GRDB.swift/blob/master/README.md#how-do-i-print-a-request-as-sql)
- The [Codable Record](https://github.com/groue/GRDB.swift/blob/master/README.md#codable-records) chapter has been enhanced with more information and sample code.


### API diff

```diff
 extension Request {
+    func asSQLRequest(_ db: Database, cached: Bool = false) throws -> SQLRequest
}
struct SQLRequest {
+    let sql: String
+    let arguments: StatementArguments?
+    let adapter: RowAdapter?
 }
```


## 2.0.3

Released October 9, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.0.2...v2.0.3)

**Fixed**: Record types that conform to Encodable now encode their null columns.


## 2.0.2

Released October 5, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.0.1...v2.0.2)

**Fixed**: `DROP TABLE` statements would not drop tables when run through a prepared statement.


## 2.0.1

Released September 17, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v2.0...v2.0.1)

**Fixed**: restored support for Swift Package Manager


## 2.0

Released September 16, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v1.3.0...v2.0)

**GRDB 2.0 brings support for Swift 4.** Notable changes are:

- **Use subscript notation when extracting row values** ([documentation](https://github.com/groue/GRDB.swift#column-values)):
    
    ```swift
    let name: String = row[0]              // 0 is the leftmost column
    let name: String = row["name"]         // Leftmost matching column - lookup is case-insensitive
    let name: String = row[Column("name")] // Using query interface's Column
    ```

- **Support for the `Codable` protocol** ([documentation](https://github.com/groue/GRDB.swift#codable-records))
    
    Record types that adopt the standard `Codable` protocol are granted with automatic adoption of GRDB record protocols. This means that you no longer have to write boilerplate code :tada::
    
    ```swift
    struct Player : RowConvertible, Persistable, Codable {
        static let databaseTableName = "players"
        let name: String
        let score: Int
    }
    
    // Automatically derived:
    //
    // extension Player {
    //     init(row: Row) {
    //         name = row["name"]
    //         score = row["score"]
    //     }
    //     
    //     func encode(to container: inout PersistenceContainer) {
    //         container["name"] = name
    //         container["score"] = score
    //     }
    // }
    
    try dbQueue.inDatabase { db in
        let arthur = Player(name: "Arthur", score: 100)
        try arthur.insert(db)
        let players = try Player.fetchAll(db) // [Players]
    }
    ```

- **Records can now specify the columns they feed from** ([documentation](https://github.com/groue/GRDB.swift#columns-selected-by-a-request)).
    
    In previous versions of GRDB, `SELECT *` was the norm. GRDB 2.0 introduces `databaseSelection`, which allows any type to define its preferred set of columns:
    
    ```swift
    struct Player : RowConvertible, TableMapping {
        let id: Int64
        let name: String
        
        enum Columns {
            static let id = Column("id")
            static let name = Column("name")
        }
        
        init(row: Row) {
            id = row[Columns.id]
            name = row[Columns.name]
        }
        
        static let databaseTableName = "players"
        static let databaseSelection: [SQLSelectable] = [Columns.id, Columns.name]
    }
    
    // SELECT id, name FROM players
    let players = Player.fetchAll(db)
    ```

- **Record protocols have more precise semantics**: RowConvertible *reads database rows*, TableMapping *builds SQL requests*, and Persistable *writes* ([documentation](https://github.com/groue/GRDB.swift#record-protocols-overview)).
    
    This means that with GRDB 2.0, being able to write `Player.fetchAll(db)` does not imply that `Player.deleteAll(db)` is available: you have a better control on the abilities of your record types.


### Fixed

- GRDB is now able to store and load zero-length blobs.


### New

New features have been added in order to plug a few holes and support the [RxGRDB](http://github.com/RxSwiftCommunity/RxGRDB) and [GRDBObjc](http://github.com/groue/GRDBObjc) companion projects:

- Persistable records can export themselves as dictionaries:
    
    ```swift
    let player = try Player.fetchOne(db, key: 1)
    let dict = player.databaseDictionary // [String: DatabaseValue]
    print(dict)
    // Prints {"id": 1, "name": "Arthur", "score": 1000}
    ```

- Query interface requests learned how to limit the number of deleted rows:
    
    ```swift
    // Delete the last ten players:
    // DELETE FROM players ORDER BY score LIMIT 10
    let request = Player.order(scoreColumn).limit(10)
    try request.deleteAll(db)
    ```

- Prepared statements know the index of their columns:
    
    ```swift
    let statement = try db.makeSelectStatement("SELECT a, b FROM t")
    statement.index(ofColumn: "b")  // 1
    ```

- Row cursors (of type RowCursor) expose their underlying statement:
    
    ```swift
    let rows = try Row.fetchCursor(db, "SELECT ...")
    let statement = rows.statement
    ```

- One can build a Set from a cursor:
    
    ```swift
    let strings = try Set(String.fetchCursor(...))
    ```

- The new `AnyDatabaseReader` and `AnyDatabaseWriter` type erasers help dealing with the `DatabaseReader` and `DatabaseWriter` protocols.


### Breaking Changes

- Requirements have changed: Xcode 9+ / Swift 4

- WatchOS extension targets no longer need `libsqlite3.tbd` to be added to the *Linked Frameworks and Libraries* section of their *General* tab.

- The `Row.value` method has been replaced with subscript notation:

    ```diff
    -row.value(atIndex: 0)
    -row.value(named: "id")
    -row.value(Column("id"))
    +row[0]
    +row["id"]
    +row[Column("id")]
    ```

- Date and NSDate now interpret numerical database values as timestamps that fuel `Date(timeIntervalSince1970:)`. Previous version of GRDB would interpret numbers as [julian days](https://en.wikipedia.org/wiki/Julian_day) (a date representation supported by SQLite). Support for julian days remains, with the `Date(julianDay:)` initializer.

- All `TableMapping` methods that would modify the database have moved to `MutablePersistable`, now the only record protocol that is able to write.

- The `TableMapping.selectsRowID` property has been replaced with `TableMapping.databaseSelection`.
    
    To upgrade, replace:
    
    ```diff
     struct Player: TableMapping {
    -    static let selectsRowID = true
    +    static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
     }
    ```

- The `DatabaseCursor` type has been removed, and replaced with several concrete types that all adopt the `Cursor` protocol. Those new types allow dedicated optimizations depending on the type of the fetched elements.
    
    If your application has code that depends on `DatabaseCursor`, make it target the new concrete types, or make it generic on the `Cursor` protocol, just like you'd write generic methods on the Swift `Sequence` protocol.

- `RowConvertible.fetchCursor(_:keys:)` returns a non-optional cursor.

- `Database.primaryKey(_:)` returns a non-optional PrimaryKeyInfo. When a table has no explicit primary key, the result is the hidden rowid column.

- The deprecated `TableMapping.primaryKeyRowComparator` method has been removed.


### Documentation Diff

- [WatchOS installation procedure](https://github.com/groue/GRDB.swift#installation) has been updated with new instructions.
- The [introduction to multithreading with database pools](https://github.com/groue/GRDB.swift#database-pools) has been enhanced.
- The [Rows as Dictionaries](https://github.com/groue/GRDB.swift#rows-as-dictionaries) chapter has been enhanced with instructions for converting a row into a dictionary.
- The [description of cursors](https://github.com/groue/GRDB.swift#cursors) better explains how to choose between a cursor and an array.
- The [Date and DateComponents](https://github.com/groue/GRDB.swift#date-and-datecomponents) chapter has been updated for the new support for unix timestamps.
- The [Fatal Errors](https://github.com/groue/GRDB.swift#fatal-errors) chapter has an enhanced description of value conversion errors and how to handle them.
- The [Usage of raw SQLite pointers](https://github.com/groue/GRDB.swift#raw-sqlite-pointers) chapter has been updated for the new `SQLite3` standard module that comes with Swift4.
- A new [Record Protocols Overview](https://github.com/groue/GRDB.swift#record-protocols-overview) chapter has been added.
- A new [Codable Records](https://github.com/groue/GRDB.swift#codable-records) chapter has been added.
- A new [Columns Selected by a Request](https://github.com/groue/GRDB.swift#columns-selected-by-a-request) chapter describes the new `TableMapping.databaseSelection` property.
- The [Exposing the RowID Column](https://github.com/groue/GRDB.swift#exposing-the-rowid-column) chapter has been updated for the new `TableMapping.databaseSelection` property.


### API diff

```diff
 class Row {
-    func value(atIndex index: Int) -> DatabaseValueConvertible?
-    func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value?
-    func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value
-    func value(named columnName: String) -> DatabaseValueConvertible?
-    func value<Value: DatabaseValueConvertible>(named columnName: String) -> Value?
-    func value<Value: DatabaseValueConvertible>(named columnName: String) -> Value
-    func value(_ column: Column) -> DatabaseValueConvertible?
-    func value<Value: DatabaseValueConvertible>(_ column: Column) -> Value?
-    func value<Value: DatabaseValueConvertible>(_ column: Column) -> Value
+    subscript(_ index: Int) -> DatabaseValueConvertible?
+    subscript<Value: DatabaseValueConvertible>(_ index: Int) -> Value?
+    subscript<Value: DatabaseValueConvertible>(_ index: Int) -> Value
+    subscript(_ columnName: String) -> DatabaseValueConvertible?
+    subscript<Value: DatabaseValueConvertible>(_ columnName: String) -> Value?
+    subscript<Value: DatabaseValueConvertible>(_ columnName: String) -> Value
+    subscript(_ column: Column) -> DatabaseValueConvertible?
+    subscript<Value: DatabaseValueConvertible>(_ column: Column) -> Value?
+    subscript<Value: DatabaseValueConvertible>(_ column: Column) -> Value
 }

 class SelectStatement {
+    func index(ofColumn columnName: String) -> Int?
 }
 
+extension MutablePersistable {
+    var databaseDictionary: [String: DatabaseValue]
+}
 
-extension TableMapping {
+extension MutablePersistable {
     @discardableResult static func deleteAll(_ db: Database) throws -> Int
     @discardableResult static func deleteAll<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> Int where Sequence.Element: DatabaseValueConvertible
     @discardableResult static func deleteOne<PrimaryKeyType: DatabaseValueConvertible>(_ db: Database, key: PrimaryKeyType?) throws -> Bool
     @discardableResult static func deleteAll(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) throws -> Int
     @discardableResult static func deleteOne(_ db: Database, key: [String: DatabaseValueConvertible?]) throws -> Bool
 }
-extension QueryInterfaceRequest {
+extension QueryInterfaceRequest where RowDecoder: MutablePersistable {
     @discardableResult func deleteAll(_ db: Database) throws -> Int
 }

 protocol TableMapping {
-    static var selectsRowID: Bool { get }
+    static var databaseSelection: [SQLSelectable] { get }
 }
 class Record {
-    open class var selectsRowID: Bool
+    open class var databaseSelection: [SQLSelectable]
 }
+struct AllColumns {
+    init()
+}

 class Database {
-    func primaryKey(_ tableName: String) throws -> PrimaryKeyInfo?
+    func primaryKey(_ tableName: String) throws -> PrimaryKeyInfo
 }
 struct PrimaryKeyInfo {
+    var isRowID: Bool { get }
 }

+extension Set {
+    init<C: Cursor>(_ cursor: C) throws where C.Element == Element
+}

-final class DatabaseCursor { }
+final class ColumnCursor<Value: DatabaseValueConvertible & StatementColumnConvertible> : Cursor {
+    typealias Element = Value
+}
+final class DatabaseValueCursor<Value: DatabaseValueConvertible> : Cursor  {
+    typealias Element = Value
+}
+final class NullableColumnCursor<Value: DatabaseValueConvertible & StatementColumnConvertible> : Cursor  {
+    typealias Element = Value?
+}
+final class NullableDatabaseValueCursor<Value: DatabaseValueConvertible> : Cursor  {
+    typealias Element = Value?
+}
+final class RecordCursor<Record: RowConvertible> : Cursor  {
+    typealias Element = Record
+}
+final class RowCursor : Cursor {
+    typealias Element = Row
+    let statement: SelectStatement
+}
 extension DatabaseValueConvertible {
-    static func fetchCursor(...) throws -> DatabaseCursor<Self>
+    static func fetchCursor(...) throws -> DatabaseValueCursor<Self>
 }
 extension DatabaseValueConvertible where Self: StatementColumnConvertible {
+    static func fetchCursor(...) throws -> ColumnCursor<Self>
 }
 extension Optional where Wrapped: DatabaseValueConvertible {
-    static func fetchCursor(...) throws -> DatabaseCursor<Wrapped?>
+    static func fetchCursor(...) throws -> NullableDatabaseValueCursor<Wrapped>
 }
 extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible {
+    static func fetchCursor(...) throws -> NullableColumnCursor<Wrapped>
 }
 extension Row {
-    static func fetchCursor(...) throws -> DatabaseCursor<Row>
+    static func fetchCursor(...) throws -> RowCursor
 }
 extension RowConvertible where Self: TableMapping {
-    static func fetchCursor(...) throws -> DatabaseCursor<Self>?
+    static func fetchCursor(...) throws -> RecordCursor<Self>
 }
 extension TypedRequest where RowDecoder: RowConvertible {
-    func fetchCursor(_ db: Database) throws -> DatabaseCursor<RowDecoder>
+    func fetchCursor(_ db: Database) throws -> RecordCursor<RowDecoder>
 }
 extension TypedRequest where RowDecoder: DatabaseValueConvertible {
-    func fetchCursor(_ db: Database) throws -> DatabaseCursor<RowDecoder>
+    func fetchCursor(_ db: Database) throws -> DatabaseValueCursor<RowDecoder>
 }
 extension TypedRequest where RowDecoder: DatabaseValueConvertible & StatementColumnConvertible {
+    func fetchCursor(_ db: Database) throws -> ColumnCursor<RowDecoder>
 }
 extension TypedRequest where RowDecoder: _OptionalProtocol, RowDecoder._Wrapped: DatabaseValueConvertible {
-    func fetchCursor(_ db: Database) throws -> DatabaseCursor<RowDecoder._Wrapped?>
+    func fetchCursor(_ db: Database) throws -> NullableDatabaseValueCursor<RowDecoder._Wrapped>
 }
 extension TypedRequest where RowDecoder: _OptionalProtocol, RowDecoder._Wrapped: DatabaseValueConvertible & StatementColumnConvertible {
+    func fetchCursor(_ db: Database) throws -> NullableColumnCursor<RowDecoder._Wrapped>
 }
 extension TypedRequest where RowDecoder: Row {
-    func fetchCursor(_ db: Database) throws -> DatabaseCursor<Row>
+    func fetchCursor(_ db: Database) throws -> RowCursor
 }

 extension TableMapping {
-    @available(*, deprecated) static func primaryKeyRowComparator(_ db: Database) throws -> (Row, Row) -> Bool
 }

+final class AnyDatabaseReader : DatabaseReader {
+     init(_ base: DatabaseReader)
+}
+final class AnyDatabaseWriter : DatabaseWriter {
+     init(_ base: DatabaseWriter)
+}
```

### Experimental API diff

```diff
 enum SQLCount {
-    case star
+    case all
 }
```


## 1.3.0

Released August 18, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v1.2.2...v1.3.0)

**New**

- Upgrade custom SQLite builds to [v3.20.0](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).
- Complete support for all signed and unsigned integer types: from Int8 toUInt64, all integers can be stored and loaded from the database.

**API diff**

```diff
+extension Int8: DatabaseValueConvertible, StatementColumnConvertible { }
+extension Int16: DatabaseValueConvertible, StatementColumnConvertible { }
+extension UInt8: DatabaseValueConvertible, StatementColumnConvertible { }
+extension UInt16: DatabaseValueConvertible, StatementColumnConvertible { }
+extension UInt32: DatabaseValueConvertible, StatementColumnConvertible { }
+extension UInt64: DatabaseValueConvertible, StatementColumnConvertible { }
+extension UInt: DatabaseValueConvertible, StatementColumnConvertible { }
```


## 1.2.2

Released July 20, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v1.2.1...v1.2.2)

**Fixed**

- The `Configuration.trace` function no longer leaks memory.


## 1.2.1

Released July 19, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v1.2...v1.2.1)

**Fixed**

- Upgrade custom SQLite builds to [v3.19.3](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).
- The [Query Interface](https://github.com/groue/GRDB.swift/#the-query-interface) now generates `IS NULL` SQL snippets for comparisons with `DatabaseValue.null`:
    
    ```swift
    // SELECT * FROM players WHERE email IS NULL
    Player.filter(Column("email") == DatabaseValue.null)
    ```
    
    It used to generate `= NULL` which would not behave as expected. 
    

## 1.2

Released July 13, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v1.1...v1.2)

**New**

- Record types that do not provide values for all table columns in their `encode(to:)` method are now supported.

- The table creation API has been enhanced:

    - SQLite supports untyped columns:
    
        ```swift
        try dbQueue.inDatabase { db in
            // CREATE TABLE t(a, b)
            try db.create(table: "t") { t in
                t.column("a")
                t.column("b")
            }
        }
        ```
        
        Untyped columns behave like decimal, boolean, date columns, and generally all columns with [NUMERIC type affinity](https://sqlite.org/datatype3.html#type_affinity).
        
        This feature addresses [#169](https://github.com/groue/GRDB.swift/issues/169).

    - The `indexed()` methods lets you create a non-unique index on a table column:
    
        ```swift
        try dbQueue.inDatabase { db in
            // CREATE TABLE rounds(score INTEGER)
            // CREATE INDEX rounds_on_score ON rounds(score)
            try db.create(table: "rounds") { t in
                t.column("score", .integer).indexed()
            }
        }
        ```
    
    - It is now possible to define references to tables without any explicit primary key. The generated SQL then uses the `rowid` hidden primary key column:
    
        ```swift
        try dbQueue.inDatabase { db in
            // CREATE TABLE nodes(
            //   name TEXT,
            //   parentId INTEGER REFERENCES nodes(rowid)
            // )
            try db.create(table: "nodes") { t in
                t.column("name", .text)
                t.column("parentId", .integer).references("nodes")
            }
        }
        ```

- `DatabaseQueue`, `DatabasePool` and their common protocol `DatabaseReader` can now perform "unsafe reentrant reads" ([documentation](https://github.com/groue/GRDB.swift#unsafe-concurrency-apis)):
    
    ```swift
    try dbPool.read { db in
        // This is allowed
        try dbPool.unsafeReentrantRead { db in
            ...
        }
    }
    ```


**Fixed**

- `DatabasePool.read`, and `DatabasePool.unsafeRead` now raise a fatal error when used in a reentrant way:
    
    ```swift
    try dbPool.read { db in
        // fatal error: "Database methods are not reentrant."
        try dbPool.read { db in
            ...
        }
    }
    ```
    
    While this change may appear as a breaking change, it is really a fix: reentrant reads deadlock as soon as the maximum number of readers has been reached.


**API diff**

```diff
 final class ColumnDefinition {
+    @discardableResult func indexed() -> Self
 }
 
 final class TableDefinition {
-    func column(_ name: String, _ type: Database.ColumnType) -> ColumnDefinition
+    func column(_ name: String, _ type: Database.ColumnType? = nil) -> ColumnDefinition
 }
 
 protocol DatabaseReader {
+    func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T
 }
```


## 1.1

Released July 1, 2017 &bull; [diff](https://github.com/groue/GRDB.swift/compare/v1.0...v1.1)

**New**

- `DatabaseAggregate` is the protocol for custom aggregate functions (fixes [#236](https://github.com/groue/GRDB.swift/issues/236), [documentation](https://github.com/groue/GRDB.swift#custom-aggregates)):
    
    ```swift
    struct MySum : DatabaseAggregate {
        var sum: Int = 0
        
        mutating func step(_ dbValues: [DatabaseValue]) {
            if let int = Int.fromDatabaseValue(dbValues[0]) {
                sum += int
            }
        }
        
        func finalize() -> DatabaseValueConvertible? {
            return sum
        }
    }
    
    let dbQueue = DatabaseQueue()
    let fn = DatabaseFunction("mysum", argumentCount: 1, aggregate: MySum.self)
    dbQueue.add(function: fn)
    try dbQueue.inDatabase { db in
        try db.execute("CREATE TABLE test(i)")
        try db.execute("INSERT INTO test(i) VALUES (1)")
        try db.execute("INSERT INTO test(i) VALUES (2)")
        try Int.fetchOne(db, "SELECT mysum(i) FROM test")! // 3
    }
    ```

**Fixed**

- `QueryInterfaceRequest.order(_:)` clears the eventual reversed flag, and better reflects the documentation of this method: "Any previous ordering is replaced."

**Deprecated**

- `TableMapping.primaryKeyRowComparator` is deprecated, without any replacement.

**API diff**

```diff
 final class DatabaseFunction {
+    init<Aggregate: DatabaseAggregate>(_ name: String, argumentCount: Int32? = nil, pure: Bool = false, aggregate: Aggregate.Type)
 }
 
+protocol DatabaseAggregate {
+    init()
+    mutating func step(_ dbValues: [DatabaseValue]) throws
+    func finalize() throws -> DatabaseValueConvertible?
+}

 extension TableMapping {
+    @available(*, deprecated)
     static func primaryKeyRowComparator(_ db: Database) throws -> (Row, Row) -> Bool
 }
```


## 1.0 :tada:

Released June 20, 2017

**GRDB 1.0 comes with enhancements, and API stability.**

It comes with breaking changes, but the good news is that they are the last (until GRDB 2.0) :sweat_smile:!

- **Requirements have changed: Xcode 8.3+ / Swift 3.1**
    
    As a matter of fact, GRDB 1.0 still supports Xcode 8.1 and Swift 3.0. But future versions are free to use Swift 3.1 features, and will require Xcode 8.3+.
    
    The targetted operating systems are unchanged: iOS 8.0+ / OSX 10.9+ / watchOS 2.0+

- **[Record types](https://github.com/groue/GRDB.swift#records) have their `persistentDictionary` property replaced with the `encode(to:)` method:**
    
    ```swift
    struct Player : Persistable {
        let name: String
        let score: Int
    
        // Old
    //    var persistentDictionary: [String: DatabaseValueConvertible?] {
    //        return [
    //            "name": name,
    //            "score": score,
    //        ]
    //    }
    
        // New
        func encode(to container: inout PersistenceContainer) {
            container["name"] = name
            container["score"] = score
        }
    }
    ```
    
    This is good for applications that declare lists of columns:
    
    ```swift
    struct Player : RowConvertible, Persistable {
        let name: String
        let score: Int
        
        static let databaseTableName = "players"
        
        // Declare Player columns
        enum Columns {
            static let name = Column("name")
            static let score = Column("score")
        }
        
        // Use columns in `init(row:)`
        init(row: Row) {
            name = row.value(Columns.name)
            score = row.value(Columns.score)
        }
        
        // Use columns in the new `encode(to:)` method:
        func encode(to container: inout PersistenceContainer) {
            container[Columns.name] = name
            container[Columns.score] = score
        }
    }
    ```

- **[Database Observation](https://github.com/groue/GRDB.swift#database-changes-observation) has been enhanced:**
    
    `Database.afterNextTransactionCommit(_:)` is the simplest way to handle successful [transactions](https://github.com/groue/GRDB.swift#transactions-and-savepoints), and synchronize the database with other resources such as files, or system sensors ([documentation](https://github.com/groue/GRDB.swift#after-commit-hook)).
    
    ```swift
    // Make sure the database is inside a transaction
    db.inSavepoint {
        // Perform some database job
        try ...
        
        // Register extra job that is only executed after database changes
        // have been committed and written to disk.
        db.afterNextTransactionCommit { ... }
    }
    ```
    
    On the low-level side, applications can now specify the extent of database observation ([documentation](https://github.com/groue/GRDB.swift#observation-extent)).

- **DatabaseMigrator is easier to test**, with its `DatabaseMigrator.migrate(_:upTo:)` method which partially migrates your databases ([documentation](https://github.com/groue/GRDB.swift#migrations)).

- On the side of database schema introspection, the new `Database.foreignKeys(on:)` method lists the foreign keys defined on a table.

**Full list of changes**

```diff
 class Database {
-    func add(transactionObserver: TransactionObserver)
+    func add(transactionObserver: TransactionObserver, extent: TransactionObservationExtent = .observerLifetime)
+    func afterNextTransactionCommit(_ closure: @escaping (Database) -> ())
+    func foreignKeys(on tableName: String) throws -> [ForeignKeyInfo]
 }

-struct DatabaseCoder: DatabaseValueConvertible

 struct DatabaseMigrator {
+    func migrate(_ writer: DatabaseWriter, upTo targetIdentifier: String) throws
 }

 protocol DatabaseWriter : DatabaseReader {
-    func add(transactionObserver: TransactionObserver)
+    func add(transactionObserver: TransactionObserver, extent: TransactionObservationExtent = .observerLifetime)
 }

 protocol MutablePersistable : TableMapping {
-    var persistentDictionary: [String: DatabaseValueConvertible?] { get }
+    func encode(to container: inout PersistenceContainer)
 }

 extension QueryInterfaceRequest {
-    func contains(_ value: SQLExpressible) -> SQLExpression
-    func exists() -> SQLExpression
 }

 extension Request {
-    func adapted(_ adapter: @escaping (Database) throws -> RowAdapter) -> AnyRequest
+    func adapted(_ adapter: @escaping (Database) throws -> RowAdapter) -> AdaptedRequest<Self>
 }

protocol TypedRequest : Request {
-    associatedtype Fetched
+    associatedtype RowDecoder
}

 extension TypedRequest {
-    func adapted(_ adapter: @escaping (Database) throws -> RowAdapter) -> AnyTypedRequest<Fetched>
+    func adapted(_ adapter: @escaping (Database) throws -> RowAdapter) -> AdaptedTypedRequest<Self>
 }
```


## 0.110.0

Released May 28, 2017

**New**

- Upgrade custom SQLite builds to [v3.19.2](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).
- Upgrade SQLCipher to v3.4.1 ([announcement](https://discuss.zetetic.net/t/sqlcipher-3-4-1-release/1962), [changelog](https://github.com/sqlcipher/sqlcipher/blob/master/CHANGELOG.md))
- A [large test suite](https://travis-ci.org/groue/GRDB.swift) that runs on Travis-CI, thanks to [@swiftlyfalling](https://github.com/swiftlyfalling) in [PR #213](https://github.com/groue/GRDB.swift/pull/213)

**Fixed**

- Remove deprecation warning about `sqlite3_trace`() for [custom SQLite builds](https://github.com/groue/GRDB.swift/blob/master/Documentation/CustomSQLiteBuilds.md) (addresses [#100](https://github.com/groue/GRDB.swift/issues/100))


## 0.109.0

Released May 22, 2017

**Fixed**

- Failed value conversions now consistently crash with a fatal error.

**New**

- `DatabaseValue.losslessConvert()` performs a lossless conversion to a value type.

**Breaking Changes**

- `DatabaseEventKind.impacts(_ selectionInfo:SelectStatement.SelectionInfo)` now returns an non-optional boolean.
- `DatabaseWriter.availableDatabaseConnection` has been replaced by `DatabaseWriter.unsafeReentrantWrite()`.
- `Request.bound(to:)` has been renamed `Request.asRequest(of:)`.
    

## 0.108.0

Released May 17, 2017

**New**

- Use CocoaPods to install GRDB with [SQLCipher](https://github.com/groue/GRDB.swift#encryption):
    
    ```ruby
    pod 'GRDBCipher'
    ```


**Breaking Changes**

- `RowConvertible.awakeFromFetch()` has been removed.


## 0.107.0

Released May 5, 2017

**New**

- `SQLRequest` learned how to reuse cached prepared statements: `SQLRequest("SELECT ...", cached: true)`

- `Database.logError` lets you register a global error logging function:
    
    ```swift
    Database.logError = { resultCode, message in
        NSLog("%@", "SQLite error \(resultCode): \(message)")
    }
    ```


## 0.106.1

Released April 12, 2017

No change, but a better support for Swift Package Manager at the git repository level.


## 0.106.0

Released April 11, 2017

**New**

- Swift Package Manager, thanks to [Andrey Fidrya](https://github.com/zmeyc) in [PR #202](https://github.com/groue/GRDB.swift/pull/202).


## 0.105.0

Released April 6, 2017

**Fixed**

- [FetchedRecordsController](https://github.com/groue/GRDB.swift#fetchedrecordscontroller) used to be able to miss changes performed on requests that use the `COUNT` SQL function. This is fixed. 


**New**

- `DatabaseWriter.availableDatabaseConnection` allows reentrant uses of GRDB, and improves support for [reactive](http://reactivex.io) programming.


**Breaking Changes**

- `DatabaseEventKind.impacts(_ selectionInfo:SelectStatement.SelectionInfo)` now returns an optional boolean which, when nil, tells that GRDB doesn't know if a statement has any impact on the selection of a request. In practice, this happens as soon as a request uses the `COUNT` SQL function. 


## 0.104.0

Released April 3, 2017

**New**

- Support for Xcode 8.3 and Swift 3.1 (Xcode 8.1 and Swift 3 are still supported).
- Upgrade custom SQLite builds to [v3.18.0](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).
- Support for [reactive](http://reactivex.io) extensions:
    - `SelectStatement.SelectionInfo` is an opaque value that knows which database tables and columns are read by a [select statement](https://github.com/groue/GRDB.swift#prepared-statements).
    - `DatabaseEventKind.impacts(_ selectionInfo:SelectStatement.SelectionInfo)` tells whether a database change has any impact on the results of a select statement. See [Database Changes Observation](https://github.com/groue/GRDB.swift#database-changes-observation)
    - `TableMapping.primaryKeyRowComparator(_ db: Database)` returns a function that compares two database rows and return true if and only if they have the same non-null primary key.

**Breaking Changes**

- SQLite C API is now available right from the GRBD module: you don't need any longer to import `SQLiteiPhoneOS` module et al (see documentation for [Raw SQLite Pointers](https://github.com/groue/GRDB.swift#raw-sqlite-pointers)).
- The [manual installation procedure for WatchOS extensions](https://github.com/groue/GRDB.swift#installation) has changed.
- [Carthage](https://github.com/Carthage/Carthage) is no longer supported. At the present time it is unable to support the various frameworks built by GRDB (system SQLite, SQLCipher, custom SQLite builds, etc.)


## 0.103.0

Released March 26, 2017

**Fixed**

- `DatabaseError` conversion to `NSError` preserves extended result codes.
- `DatabaseQueue.read` and `DatabaseQueue.readFromCurrentState` throw an error upon database modifications.
- Added missing availability checks for SQLite features that are not available on all versions of iOS, macOS, watchOS.
- Removed useless availability checks for SQLite features that are available with [SQLCipher](https://github.com/groue/GRDB.swift#encryption) and [custom SQLite builds](https://github.com/groue/GRDB.swift/blob/master/Documentation/CustomSQLiteBuilds.md).
- Prevent [wrong linking of SQLCipher](https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688)

**Breaking Changes**

- `DatabaseQueue.writeInTransaction`, alias for `DatabaseQueue.inTransaction`, has been removed.
- `DatabaseValue.value()` has been removed, in favor of `DatabaseValue.storage`.


## 0.102.0

Released March 2, 2017

**New: Error Handling** (fixes [#171](https://github.com/groue/GRDB.swift/issues/171))

- GRDB activates SQLite's [extended result codes](https://www.sqlite.org/rescode.html) for more detailed error reporting.
- The new `ResultCode` type defines constants for all SQLite [result codes and extended result codes](https://www.sqlite.org/rescode.html).
- The SQLite error code of `DatabaseError` can be queried with `resultCode`, or `extendedResultCode`, depending on the level of details you need ([documentation](https://github.com/groue/GRDB.swift#databaseerror)):
    
    ```swift
    do {
        ...
    } catch let error as DatabaseError where error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY {
        // handle foreign key constraint error
    } catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
        // handle any other constraint error
    }
    ```


**New: Request**

- The Request protocol for [custom requests](https://github.com/groue/GRDB.swift#custom-requests) learned how to count:
    
    ```swift
    let request: Request = ...
    let count = try request.fetchCount(db) // Int
    ```
    
    Default implementation performs a naive counting based on the request SQL: `SELECT COUNT(*) FROM (...)`. Adopting types can refine the counting SQL by providing their own `fetchCount` implementation.
    
    Thanks [David Hart](https://github.com/hartbit) for this [suggestion](https://github.com/groue/GRDB.swift/issues/176#issuecomment-282783884).


**Breaking Changes**

- `DatabaseError.code` has been removed, replaced with `DatabaseError.resultCode` and `DatabaseError.extendedResultCode` ([documentation](https://github.com/groue/GRDB.swift#databaseerror)).
- `DatabaseMigrator.registerMigrationWithDisabledForeignKeyChecks` has been renamed `DatabaseMigrator.registerMigrationWithDeferredForeignKeyCheck` ([documentation](https://github.com/groue/GRDB.swift#advanced-database-schema-changes))


## 0.101.1

Released January 20, 2017

**New**

- `DatabaseEventKind.tableName` makes it easier to track any change that may happen to a database table ([documentation](https://github.com/groue/GRDB.swift#filtering-database-events))
- `FetchedRecordsController.allowBackgroundChangesTracking(in:)`: call this [FetchedRecordsController](https://github.com/groue/GRDB.swift#fetchedrecordscontroller) method when changes performed while the application is in the background should be processed before the application enters the suspended state.


**Breaking Changes**

- `Configuration.fileAttributes` has been removed (see [Data Protection](https://github.com/groue/GRDB.swift#data-protection))


## 0.100.0

Released January 10, 2017

**New**

- `Row` adopts the Hashable protocol
- [FetchedRecordsController](https://github.com/groue/GRDB.swift#fetchedrecordscontroller) now outputs request changes on all platforms, for both table and collection views. Merged [#160](https://github.com/groue/GRDB.swift/pull/160) by [@kdubb](https://github.com/kdubb).
- Upgrade custom SQLite builds to [v3.16.2](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).

**Breaking Changes**

- It is now a programmer error to invoke `FetchedRecordsController.fetchedRecords` before `performFetch()`:
    
    ```diff
    final class FetchedRecordsController<Record: RowConvertible> {
    -    var fetchedRecords: [Record]?
    +    var fetchedRecords: [Record]
    }
    ```
    
- The fetched record type of a FetchedRecordsController is now infered from the request that feeds the controller:
    
    ```diff
    final class FetchedRecordsController<Record: RowConvertible> {
    -    convenience init(...:request: Request) throws
    +    convenience init<Request>(...:request: Request) throws where Request: TypedRequest, Request.Fetched == Record
    }
    ```
    
- FetchedRecordsController now automatically compares records by primary key when the record type adopts the TableMapping protocol, such as all Record subclasses. This feature used to require an explicit `compareRecordsByPrimaryKey` initialization parameter:
    
    ```diff
    extension FetchedRecordsController where Record: TableMapping {
    -    convenience init(...:compareRecordsByPrimaryKey: Bool) throws
    }
    ```
    
- Change tracking APIs have been modified:
    
    ```diff
    final class FetchedRecordsController<Record: RowConvertible> {
    -    func trackChanges(recordsWillChange:tableViewEvent:recordsDidChange:)
    +    func trackChanges(willChange:onChange:didChange:)
    }
    ```


## 0.99.2

Released December 22, 2016

**Fixed**

- `Database.cachedSelectStatement()` no longer returns a statement that can not be reused because it has already failed. 


## 0.99.1

Released December 21, 2016

**Fixed**

- An awful bug where SQLite would not drop any table ([#157](https://github.com/groue/GRDB.swift/issues/157))
- [Transaction Observers](https://github.com/groue/GRDB.swift#database-changes-observation) are no longer blinded by the [truncate optimization](https://www.sqlite.org/lang_delete.html#truncateopt) (fixes [#156](https://github.com/groue/GRDB.swift/issues/156))


## 0.99.0 (don't use)

Released December 20, 2016

**Fixed**

- [Transaction Observers](https://github.com/groue/GRDB.swift#database-changes-observation) are no longer blinded by the [truncate optimization](https://www.sqlite.org/lang_delete.html#truncateopt) (fixes [#156](https://github.com/groue/GRDB.swift/issues/156))

**New**

- [FetchedRecordsController](https://github.com/groue/GRDB.swift#fetchedrecordscontroller) no longer crashes whenever an error prevents it from looking for changes after a transaction has potentially modified the tracked request. Instead, it notifies its optional error handler:
    
    ```swift
    controller.trackErrors { (controller, error) in
        print("Missed a transaction because \(error)")
    }
    ```


## 0.98.0

Released December 16, 2016

**New**

- StatementArguments can be concatenated with the `append(contentsOf:)` method and the `+`, `&+`, `+=` operators ([documentation](https://github.com/groue/GRDB.swift/blob/v0.98.0/GRDB/Core/Statement.swift#L443))

- Rows expressed as dictionary literals now preserve column ordering, and allow duplicated column names:
    
    ```swift
    let row: Row = ["foo": 1, "foo": Date(), "baz": nil]
    print(row)
    // Prints <Row foo:1 foo:"2016-12-16 13:19:49.230" baz:NULL>
    ```


## 0.97.0

Released December 15, 2016

**Fixed**

- DatabasePool `read` and `readFromCurrentState` methods now properly throw errors whenever they can't acquire an isolated access to the database.

**New**

- Raw transaction and savepoint SQL statements are properly reflected in [transaction observers](https://github.com/groue/GRDB.swift#database-changes-observation), `Database.isInsideTransaction`, etc.


## 0.96.0

Released December 11, 2016

**New**

- `Request.adapted` modifies a request with a [row adapter](https://github.com/groue/GRDB.swift#row-adapters).
    
    ```swift
    // Person has `email` column, but User expects `identifier` column:
    Person.all()
        .adapted { _ in ColumnMapping(["identifier": "email"]) }
        .bound(to: User.self)
    ```

**Breaking Changes**

- `RowAdapter` protocol has been refactored. This only affects your code if you implement your own [row adapter](https://github.com/groue/GRDB.swift#row-adapters).


## 0.95.0

Released December 9, 2016

**New**

- `SQLRequest`, `AnyRequest`, `TypedRequest` and `AnyTypedRequest` are new protocols and concrete types that let you build [custom fetch requests](https://github.com/groue/GRDB.swift#custom-requests).
- `RangeRowAdapter` is a new kind of [row adapter](https://github.com/groue/GRDB.swift#row-adapters) which exposes a range of columns.

**Breaking Changes**

- `FetchRequest` protocol has been renamed `Request`.


## 0.94.0

Released December 7, 2016

**New**

- `Database.columnCount(in:)` returns the number of columns in a database table. This helps building [row adapters](https://github.com/groue/GRDB.swift#row-adapters) for joined requests.


## 0.93.1

Released December 7, 2016

**Fixed**

- Removed `Record.hasPersistentChangedValues` dependency on `awakeFromFetch()`. This makes it easier to wrap records in other RowConvertible types, since `awakeFromFetch()` can be overlooked without bad consequences on [changes tracking](https://github.com/groue/GRDB.swift#changes-tracking).


## 0.93.0

Released December 4, 2016

**New**

- Upgrade custom SQLite builds to [v3.15.2](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).


## 0.92.1

Released December 2, 2016

**Fixed**

- `Database.execute(_:)` now iterates all rows of statements (and executes any side effect performed by the evaluation of each row).


## 0.92.0

Released December 1, 2016

**Fixed**

- Fixed a bug in `DatabasePool.readFromCurrentState` where its block argument could see database changes that it should not have seen ([documentation](https://github.com/groue/GRDB.swift#advanced-databasepool)).

**Breaking Changes**

- `DatabaseWriter.readFromWrite` has been renamed `DatabaseWriter.readFromCurrentState`
- `DatabaseReader.nonIsolatedRead` has been renamed `DatabaseReader.unsafeRead`


## 0.91.0

Released November 30, 2016

**Breaking Changes**

Generally speaking, fetching methods can now throw errors. The `fetch` method have been removed, along with `DatabaseSequence` and `DatabaseIterator`, replaced by the `fetchCursor` method and `DatabaseCursor` ([documentation](https://github.com/groue/GRDB.swift#fetching-methods)):

```swift
// No longer supported
let persons = Person.fetch(db) // DatabaseSequence<Person>
for person in persons {        // Person
    ...
}

// New
let persons = try Person.fetchCursor(db) // DatabaseCursor<Person>
while person = try persons.next() {      // Person
    ...
}
```

Many APIs were changed:

### Database Connections

```diff
 final class Database {
-    func tableExists(_ tableName: String) -> Bool
-    func indexes(on tableName: String) -> [IndexInfo]
+    func tableExists(_ tableName: String) throws -> Bool
+    func indexes(on tableName: String) throws -> [IndexInfo]
 }
 
 final class DatabasePool {
-    func read<T>(_ block: (Database) throws -> T) rethrows -> T
-    func nonIsolatedRead<T>(_ block: (Database) throws -> T) rethrows -> T
-    func readFromWrite(_ block: @escaping (Database) -> Void)
+    func read<T>(_ block: (Database) throws -> T) throws -> T
+    func nonIsolatedRead<T>(_ block: (Database) throws -> T) throws -> T
+    func readFromWrite(_ block: @escaping (Database) -> Void) throws
 }
 
 protocol DatabaseReader {
-    func read<T>(_ block: (Database) throws -> T) rethrows -> T
-    func nonIsolatedRead<T>(_ block: (Database) throws -> T) rethrows -> T
+    func read<T>(_ block: (Database) throws -> T) throws -> T
+    func nonIsolatedRead<T>(_ block: (Database) throws -> T) throws -> T
 }
 
 protocol DatabaseWriter {
-    func readFromWrite(_ block: @escaping (Database) -> Void)
+    func readFromWrite(_ block: @escaping (Database) -> Void) throws
 }
```

### Fetching Rows and Values

```diff
 final class Row {
-    static func fetch(...) -> DatabaseSequence<Row>
-    static func fetchAll(...) -> [Row]
-    static func fetchOne(...) -> Row?
+    static func fetchCursor(...) -> DatabaseCursor<Row>
+    static func fetchAll(...) throws -> [Row] {
+    static func fetchOne(...) throws -> Row?
 }
 
 extension DatabaseValueConvertible {
-    static func fetch(...) -> DatabaseSequence<Self>
-    static func fetchAll(...) -> [Self]
-    static func fetchOne(...) -> Self?
+    static func fetchCursor(...) -> DatabaseCursor<Self>
+    static func fetchAll(...) throws -> [Self]
+    static func fetchOne(...) throws -> Self?
 }
 
 extension Optional where Wrapped: DatabaseValueConvertible {
-    static func fetch(...) -> DatabaseSequence<Wrapped?>
-    static func fetchAll(...) -> [Wrapped?]
+    static func fetchCursor(...) throws -> DatabaseCursor<Wrapped?>
+    static func fetchAll(...) throws -> [Wrapped?]
 }
```

### Records and the Query Interface

```diff
 final class FetchedRecordsController<Record: RowConvertible> {
-    init(...)
-    func performFetch(...)
-    func setRequest(...)
+    init(...) throws
+    func performFetch(...) throws
+    func setRequest(...) throws
 }
 
 protocol MutablePersistable : TableMapping {
-    func exists(_ db: Database) -> Bool
+    func exists(_ db: Database) throws -> Bool
 }
 
 extension MutablePersistable {
-    func performExists(_ db: Database) -> Bool
+    func performExists(_ db: Database) throws -> Bool
 }

 extension QueryInterfaceRequest {
-    func fetchCount(...) -> Int
+    func fetchCount(...) throws -> Int
 }
 
 extension QueryInterfaceRequest where T: RowConvertible {
-    func fetch(...) -> DatabaseSequence<T>
-    func fetchAll(...) -> [T]
-    func fetchOne(...) -> T?
+    func fetchCursor(...) throws -> DatabaseCursor<T>
+    func fetchAll(...) throws -> [T]
+    func fetchOne(...) throws -> T?
 }
 
 extension RowConvertible {
-    static func fetch(...) -> DatabaseSequence<Self>
-    static func fetchAll(...) -> [Self]
-    static func fetchOne(...) -> Self?
+    static func fetchCursor(...) throws -> DatabaseCursor<Self> {
+    static func fetchAll(...) throws -> [Self] {
+    static func fetchOne(...) throws -> Self?
 }
 
 extension TableMapping {
-    static func fetchCount(_ db: Database) -> Int
+    static func fetchCount(_ db: Database) throws -> Int
 }
```

### Cursors

```diff
-struct DatabaseSequence<Element>: Sequence
-final class DatabaseIterator<Element>: IteratorProtocol

+extension Array {
+    init<C : Cursor>(_ cursor: C) throws where C.Element == Element
+}

+class AnyCursor<Element> : Cursor {
+    init<C : Cursor>(_ base: C) where C.Element == Element
+    init(_ body: @escaping () throws -> Element?)
+}

+protocol Cursor : class {
+    associatedtype Element
+    func next() throws -> Element?
+}

+extension Cursor {
+    func contains(where predicate: (Element) throws -> Bool) throws -> Bool
+    func enumerated() -> EnumeratedCursor<Self>
+    func filter(_ isIncluded: @escaping (Element) throws -> Bool) -> FilterCursor<Self>
+    func first(where predicate: (Element) throws -> Bool) throws -> Element?
+    func flatMap<ElementOfResult>(_ transform: @escaping (Element) throws -> ElementOfResult?) -> MapCursor<FilterCursor<MapCursor<Self, ElementOfResult?>>, ElementOfResult>
+    func flatMap<SegmentOfResult : Sequence>(_ transform: @escaping (Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<Self, IteratorCursor<SegmentOfResult.Iterator>>>
+    func flatMap<SegmentOfResult : Cursor>(_ transform: @escaping (Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<Self, SegmentOfResult>>
+    func forEach(_ body: (Element) throws -> Void) throws
+    func map<T>(_ transform: @escaping (Element) throws -> T) -> MapCursor<Self, T>
+    func reduce<Result>(_ initialResult: Result, _ nextPartialResult: (Result, Element) throws -> Result) throws -> Result
+}

+extension Cursor where Element: Equatable {
+    func contains(_ element: Element) throws -> Bool
+}

+extension Cursor where Element: Cursor {
+    func joined() -> FlattenCursor<Self>
+}

+extension Cursor where Element: Sequence {
+    func joined() -> FlattenCursor<MapCursor<Self, IteratorCursor<Self.Element.Iterator>>>
+}

+final class DatabaseCursor<Element> : Cursor
+final class EnumeratedCursor<Base : Cursor> : Cursor
+final class FilterCursor<Base : Cursor> : Cursor
+final class FlattenCursor<Base: Cursor> : Cursor where Base.Element: Cursor
+final class MapCursor<Base : Cursor, Element> : Cursor
+final class IteratorCursor<Base : IteratorProtocol> : Cursor {
+    init(_ base: Base)
+    init<S : Sequence>(_ s: S) where S.Iterator == Base
+}

+extension Sequence {
+    func flatMap<SegmentOfResult : Cursor>(_ transform: @escaping (Iterator.Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<IteratorCursor<Self.Iterator>, SegmentOfResult>>
+}
```


## 0.90.1

Released November 18, 2016

**Fixed**

- Fixed a couple Xcode 8.1 warnings

## 0.90.0

Released November 5, 2016

**New**

- Upgrade custom SQLite builds to [v3.15.1](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).

**Fixed**

- FetchedRecordsController no longer exposes record comparison options to platforms that don't need them. The `isSameRecord` and `compareRecordsByPrimaryKey` parameters are now [iOS only](https://github.com/groue/GRDB.swift#fetchedrecordscontroller-on-ios):
    
    ```swift
    // iOS only
    let controller = FetchedRecordsController<MyRecord>(
        dbQueue,
        request: ...,
        compareRecordsByPrimaryKey: true)
    
    // All platforms
    let controller = FetchedRecordsController<MyRecord>(
        dbQueue,
        request: ...)
    ```


## 0.89.2

Released October 26, 2016

**Fixed**

- Query Interface: `CountableRange.contains()` no longer generates BETWEEN operator.
    
    For example, `1..<10.contains(Column("x"))` now generates `x >= 1 AND x < 10` instead of `x BETWEEN 1 AND 9`. This should better reflect the user intent whenever an Int range tests Double values.


## 0.89.1

Released October 19, 2016

**Fixed**

- When `Database.create(virtualTable:using:)` throws, it is now guaranteed that the virtual table table is not created.
- [FetchedRecordsController](https://github.com/groue/GRDB.swift#fetchedrecordscontroller) learned about `TableMapping.selectsRowID`, and is now able to animate table views populated with [records without explicit primary key](https://github.com/groue/GRDB.swift#the-implicit-rowid-primary-key).
- Restored SQLCipher installation procedure


## 0.89.0

Released October 17, 2016

**Fixed**

- [FetchedRecordsController](https://github.com/groue/GRDB.swift#fetchedrecordscontroller) could miss database changes after its fetch request was modified. Now it properly updates the set of tracked columns and tables.

**New**

- `TableMapping.none()`: a fetch request which fetches nothing.


## 0.88.0

Released October 16, 2016

**New**

- Full-text matching methods accept nil search patterns:
    
    ```swift
    let pattern = FTS3SearchPattern(matchingAllTokensIn: "") // nil
    let documents = Document.matching(pattern).fetchAll(db)  // Empty array
    ```

- Synchronization of an FTS4 or FTS5 full-text table with an external content table ([documentation](https://github.com/groue/GRDB.swift#external-content-full-text-tables)):
    
    ```swift
    // A regular table
    try db.create(table: "books") { t in
        t.column("author", .text)
        t.column("title", .text)
        t.column("content", .text)
        ...
    }

    // A full-text table synchronized with the regular table
    try db.create(virtualTable: "books_ft", using: FTS4()) { t in // or FTS5()
        t.synchronize(withTable: "books")
        t.column("author")
        t.column("title")
        t.column("content")
    }
    ```

- Upgrade custom SQLite builds to [v3.15.0](http://www.sqlite.org/changes.html) (thanks to [@swiftlyfalling](https://github.com/swiftlyfalling/SQLiteLib)).


**Breaking Change**

- The `VirtualTableModule` protocol has been modified:
    
    ```diff
     protocol VirtualTableModule {
    -    func moduleArguments(_ definition: TableDefinition) -> [String]
    +    func moduleArguments(for definition: TableDefinition, in db: Database) throws -> [String]
    +    func database(_ db: Database, didCreate tableName: String, using definition: TableDefinition) throws
     }
    ```

## 0.87.0

Released October 12, 2016

**New**

- Support for custom full-text FTS5 tokenizers ([documentation](https://github.com/groue/GRDB.swift/blob/master/Documentation/FTS5Tokenizers.md))

**Breaking Changes**

- `FTS3Tokenizer` has been renamed `FTS3TokenizerDescriptor`
- `FTS5Tokenizer` has been renamed `FTS5TokenizerDescriptor`


## 0.86.0

Released October 8, 2016

**New**

- **Full-Text Search**. GRDB learned about FTS3, FTS4 and FTS5 full-text engines of SQLite ([documentation](https://github.com/groue/GRDB.swift#full-text-search)).

- **Improved support for the hidden "rowid" column**:

    - `TableMapping.selectsRowID`: this optional static property allows records to fetch their hidden rowID column ([documentation](https://github.com/groue/GRDB.swift#the-implicit-rowid-primary-key)):
    
        ```swift
        // SELECT *, rowid FROM books
        Book.fetchAll(db)
        ```
    
    - `fetchOne(_:key:)`, `fetch(_:keys:)`, `fetchAll(_:keys:)`, `deleteOne(_:key:)`, `deleteAll(_:keys:)` now use the hidden `rowid` column when the table has no explicit primary key.
    
        ```swift
        // DELETE FROM books WHERE rowid = 1
        try Book.deleteOne(db, key: 1)
        ```

- Upgrade custom SQLite builds to [v3.14.2](http://www.sqlite.org/changes.html).

**Breaking Changes**

- `Row.value(column:)` has lost its parameter name: `row.value(Column("id"))`.
- `QueryInterfaceRequest` has lost its public initializer.


## 0.85.0

Released September 28, 2016

**New**

- **Enhanced extensibility**. The low-level types that fuel the query interface [requests](https://github.com/groue/GRDB.swift/#requests) and [expressions](https://github.com/groue/GRDB.swift/#expressions) have been refactored, have lost their underscore prefix, and are stabilizing. A new [GRDB Extension Guide](https://github.com/groue/GRDB.swift/blob/master/Documentation/ExtendingGRDB.md) covers common extension use cases.

- `TableMapping` protocol learned how to delete all records right from the adopting type:
    
    ```swift
    try Person.deleteAll(db)
    ```

- Support for the `LIKE` operator (fixes [#133](https://github.com/groue/GRDB.swift/issues/133)):
    
    ```swift
    // SELECT * FROM persons WHERE email LIKE '%@example.com'
    Person.filter(Column("email").like("%@example.com")).fetchAll(db)
    ```
    
**Breaking Changes**

- The SQLForeignKeyAction, SQLColumnType, SQLConflictResolution, and SQLCollation types have been renamed Database.ForeignKeyAction, Database.ColumnType, Database.ConflictResolution, and Database.CollationName.


## 0.84.0

Released September 16, 2016

**New**

- The Persistable protocol learned about conflict resolution, and can run `INSERT OR REPLACE` queries ([documentation](https://github.com/groue/GRDB.swift#conflict-resolution), fixes [#118](https://github.com/groue/GRDB.swift/issues/118)).


## 0.83.0

Released September 16, 2016

**New**

- Upgrade custom SQLite builds to [v3.14.1](http://www.sqlite.org/changes.html).

**Fixed**

- Restore support for SQLite [pre-update hooks](https://github.com/groue/GRDB.swift#support-for-sqlite-pre-update-hooks)
- `DatabaseValue.fromDatabaseValue()` returns `.Null` for NULL input, instead of nil (fixes [#119](https://github.com/groue/GRDB.swift/issues/119))

**Breaking Change**

- `Row.databaseValue(atIndex:)` and `Row.databaseValue(named:)` have been removed. Use `value(atIndex:)` and `value(named:)` instead:
    
    ```diff
    -let dbValue = row.databaseValue(atIndex: 0)
    +let dbValue: DatabaseValue = row[0]
    ```


## 0.82.1

Released September 14, 2016

**Fixed**

- GRDB builds in the Release configuration (fix [#116](https://github.com/groue/GRDB.swift/issues/116), [#117](https://github.com/groue/GRDB.swift/issues/117), workaround [SR-2623](https://bugs.swift.org/browse/SR-2623))


## 0.82.0

Released September 11, 2016

**New**

- Swift 3

**Breaking Changes**

- The Swift 3 *Grand Renaming* has impacted GRDB a lot.
    
    **General**
    
    - All enum cases now start with a lowercase letter.
    
    **Database Connections**
    
    ```diff
    -typealias BusyCallback = (numberOfTries: Int) -> Bool
    -enum BusyMode
    -enum CheckpointMode
    -enum TransactionKind
    -enum TransactionCompletion
     struct Configuration {
    -    var fileAttributes: [String: AnyObject]?
    +    var fileAttributes: [FileAttributeKey: Any]
     }
     class Database {
    +    typealias BusyCallback = (_ numberOfTries: Int) -> Bool
    +    enum BusyMode {
    +        case immediateError
    +        case timeout(TimeInterval)
    +        case callback(BusyCallback)
    +    }
    +    enum CheckpointMode: Int32 {
    +        case passive
    +        case full
    +        case restart
    +        case truncate
    +    }
    +    enum TransactionKind {
    +        case deferred
    +        case immediate
    +        case exclusive
    +    }
    +    enum TransactionCompletion {
    +        case commit
    +        case rollback
    +    }
     }
     class DatabasePool {
    #if os(iOS)
    -    func setupMemoryManagement(application application: UIApplication)
    +    func setupMemoryManagement(in application: UIApplication) 
    #endif
    #if SQLITE_HAS_CODEC
    -    func changePassphrase(passphrase: String) throws
    +    func change(passphrase: String) throws
    #endif
     }
     class DatabaseQueue {
    #if os(iOS)
    -    func setupMemoryManagement(application application: UIApplication)
    +    func setupMemoryManagement(in application: UIApplication) 
    #endif
    #if SQLITE_HAS_CODEC
    -    func changePassphrase(passphrase: String) throws
    +    func change(passphrase: String) throws
    #endif
     }
    ```
    
    **Rows**
    
    ```diff
     final class Row {
    -    init?(_ dictionary: NSDictionary)
    -    func toNSDictionary() -> NSDictionary
    +    init?(_ dictionary: [AnyHashable: Any])
     }
    ```
    
    **Values**
    
    ```diff
     struct DatabaseValue {
    -    init?(object: AnyObject)
    -    func toAnyObject() -> AnyObject
    +    init?(value: Any)
     }
     protocol DatabaseValueConvertible {
    -    static func fromDatabaseValue(dbValue: DatabaseValue) -> DatabaseValue?
    +    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> DatabaseValue?
     }
    +extension Data : DatabaseValueConvertible
    +extension Date : DatabaseValueConvertible
    +extension URL : DatabaseValueConvertible
    +extension UUID : DatabaseValueConvertible
    ```
    
    **SQL Functions**
    
    ```diff
     class Database {
    -    func addFunction(function: DatabaseFunction)
    -    func removeFunction(function: DatabaseFunction)
    +    func add(function: DatabaseFunction)
    +    func remove(function: DatabaseFunction)
     }
     class DatabasePool {
    -    func addFunction(function: DatabaseFunction)
    -    func removeFunction(function: DatabaseFunction)
    +    func add(function: DatabaseFunction)
    +    func remove(function: DatabaseFunction)
     }
     class DatabaseQueue {
    -    func addFunction(function: DatabaseFunction)
    -    func removeFunction(function: DatabaseFunction)
    +    func add(function: DatabaseFunction)
    +    func remove(function: DatabaseFunction)
     }
     protocol DatabaseReader {
    -    func addFunction(function: DatabaseFunction)
    -    func removeFunction(function: DatabaseFunction)
    +    func add(function: DatabaseFunction)
    +    func remove(function: DatabaseFunction)
     }
     extension DatabaseFunction {
    -static let capitalizedString: DatabaseFunction
    -static let lowercaseString: DatabaseFunction
    -static let uppercaseString: DatabaseFunction
    -static let localizedCapitalizedString: DatabaseFunction
    -static let localizedLowercaseString: DatabaseFunction
    -static let localizedUppercaseString: DatabaseFunction
    +static let capitalize: DatabaseFunction
    +static let lowercase: DatabaseFunction
    +static let uppercase: DatabaseFunction
    +static let localizedCapitalize: DatabaseFunction
    +static let localizedLowercase: DatabaseFunction
    +static let localizedUppercase: DatabaseFunction
     }
    ```
    
    
    **SQL Collations**
    
    ```diff
     class Database {
    -    func addCollation(collation: DatabaseCollation)
    -    func removeCollation(collation: DatabaseCollation)
    +    func add(collation: DatabaseCollation)
    +    func remove(collation: DatabaseCollation)
     }
     class DatabasePool {
    -    func addCollation(collation: DatabaseCollation)
    -    func removeCollation(collation: DatabaseCollation)
    +    func add(collation: DatabaseCollation)
    +    func remove(collation: DatabaseCollation)
     }
     class DatabaseQueue {
    -    func addCollation(collation: DatabaseCollation)
    -    func removeCollation(collation: DatabaseCollation)
    +    func add(collation: DatabaseCollation)
    +    func remove(collation: DatabaseCollation)
     }
     protocol DatabaseReader {
    -    func addCollation(collation: DatabaseCollation)
    -    func removeCollation(collation: DatabaseCollation)
    +    func add(collation: DatabaseCollation)
    +    func remove(collation: DatabaseCollation)
     }
    ```
    
    **Prepared Statements**
    
    ```diff
     class Database {
    -    func selectStatement(sql: String) throws -> SelectStatement
    -    func updateStatement(sql: String) throws -> SelectStatement
    +    func makeSelectStatement(_ sql: String) throws -> SelectStatement
    +    func makeUpdateStatement(_ sql: String) throws -> SelectStatement
     }
     class Statement {
    -    func validateArguments(arguments: StatementArguments) throws
    +    func validate(arguments: StatementArguments) throws
     }
     struct StatementArguments {
    -    init?(_ array: NSArray)
    -    init?(_ dictionary: NSDictionary)
    +    init?(_ array: [Any])
    +    init?(_ dictionary: [AnyHashable: Any])
     }
    ```
    
    **Transaction Observers**
    
    Database events filtering is now performed by transaction observers themselves, in the new `observes(eventsOfKind:)` method of the `TransactionObserver` protocol.
    
    ```diff
     class Database {
    -    func addTransactionObserver(transactionObserver: TransactionObserverType, forDatabaseEvents filter: ((DatabaseEventKind) -> Bool)? = nil)
    -    func removeTransactionObserver(transactionObserver: TransactionObserverType)
    +    func add(transactionObserver: TransactionObserver)
    +    func remove(transactionObserver: TransactionObserver)
     }
     protocol DatabaseWriter : DatabaseReader {
    -    func addTransactionObserver(transactionObserver: TransactionObserverType, forDatabaseEvents filter: ((DatabaseEventKind) -> Bool)? = nil)
    -    func removeTransactionObserver(transactionObserver: TransactionObserverType)
    +    func add(transactionObserver: TransactionObserver)
    +    func remove(transactionObserver: TransactionObserver)
     }
    -protocol TransactionObserverType : class {
    +protocol TransactionObserver : class {
    -    func databaseDidChangeWithEvent(event: DatabaseEvent)
    -    func databaseDidCommit(db: Database)
    -    func databaseDidRollback(db: Database)
    +    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool
    +    func databaseDidChange(with event: DatabaseEvent)
    +    func databaseDidCommit(_ db: Database)
    +    func databaseDidRollback(_ db: Database)
     #if SQLITE_ENABLE_PREUPDATE_HOOK
    -    func databaseWillChangeWithEvent(event: DatabasePreUpdateEvent)
    +    func databaseWillChange(with event: DatabasePreUpdateEvent)
     #endif
     }
    ```
    
    **Records**
    
    ```diff
     protocol RowConvertible {
    -    init(_ row: Row)
    +    init(row: Row)
     }
     protocol MutablePersistable {
    -    mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    -    mutating func insert(db: Database) throws
    -    func update(db: Database, columns: Set<String>) throws
    -    mutating func save(db: Database) throws
    -    func delete(db: Database) throws -> Bool
    -    func exists(db: Database) -> Bool
    +    mutating func didInsert(with rowID: Int64, for column: String?)
    +    mutating func insert(_ db: Database) throws
    +    func update(_ db: Database, columns: Set<String>) throws
    +    mutating func save(_ db: Database) throws
    +    @discardableResult func delete(_ db: Database) throws -> Bool
    +    func exists(_ db: Database) -> Bool
     }
     protocol Persistable : MutablePersistable {
    -    func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    -    func insert(db: Database) throws
    -    func save(db: Database) throws
    +    func didInsert(with rowID: Int64, for column: String?)
    +    func insert(_ db: Database) throws
    +    func save(_ db: Database) throws
     }
     protocol TableMapping {
    -    static func databaseTableName() -> String
    +    static var databaseTableName: String { get }
     }
    -public class Record : RowConvertible, TableMapping, Persistable {
    +open class Record : RowConvertible, TableMapping, Persistable {
    -    required init(_ row: Row)
    -    class func databaseTableName() -> String
    -    func awakeFromFetch(row row: Row)
    -    func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    -    func update(db: Database, columns: Set<String>) throws
    -    func insert(db: Database) throws
    -    func save(db: Database) throws
    -    func delete(db: Database) throws -> Bool
    +    required init(row: Row)
    +    class var databaseTableName: String
    +    func awakeFromFetch(row: Row)
    +    func didInsert(with rowID: Int64, for column: String?)
    +    func update(_ db: Database, columns: Set<String>) throws
    +    func insert(_ db: Database) throws
    +    func save(_ db: Database) throws
    +    @discardableResult func delete(_ db: Database) throws -> Bool
     }
    ```
    
    **Query Interface**
    
    ```diff
     protocol FetchRequest {
    -    func prepare(db: Database) throws -> (SelectStatement, RowAdapter?)
    +    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?)
     }
    -struct SQLColumn {}
    +struct Column {}
     struct QueryInterfaceRequest<T> {
    -    var distinct: QueryInterfaceRequest<T> { get }
    -    var exists: _SQLExpression { get }
    -    func reverse() -> QueryInterfaceRequest<T>
    +    func distinct() -> QueryInterfaceRequest<T>
    +    func exists() -> _SQLExpression
    +    func reversed() -> QueryInterfaceRequest<T>
     }
     extension _SpecificSQLExpressible {
    -    var capitalizedString: _SQLExpression { get }
    -    var lowercaseString: _SQLExpression { get }
    -    var uppercaseString: _SQLExpression { get }
    -    var localizedCapitalizedString: _SQLExpression { get }
    -    var localizedLowercaseString: _SQLExpression { get }
    -    var localizedUppercaseString: _SQLExpression { get }
    +    var capitalized: _SQLExpression { get }
    +    var lowercased: _SQLExpression { get }
    +    var uppercased: _SQLExpression { get }
    +    var localizedCapitalized: _SQLExpression { get }
    +    var localizedLowercased: _SQLExpression { get }
    +    var localizedUppercased: _SQLExpression { get }
     }
    ```


## 0.81.2 (Swift 2.3)

Released September 28, 2016

**New**

- Added missing `@noescape` qualifiers. Merged [#130](https://github.com/groue/GRDB.swift/pull/130) by [@swiftlyfalling](https://github.com/swiftlyfalling).


## 0.81.1 (Swift 2.3)

Released September 16, 2016

**New**

- Upgrade custom SQLite builds to v3.14.1.

**Fixed**

- `DatabaseValue.fromDatabaseValue()` returns `.Null` for NULL input, instead of nil (fixes [#119](https://github.com/groue/GRDB.swift/issues/119))

**Breaking Change**

- `Row.databaseValue(atIndex:)` and `Row.databaseValue(named:)` have been removed. Use `value(atIndex:)` and `value(named:)` instead:
    
    ```diff
    -let dbValue = row.databaseValue(atIndex: 0)
    +let dbValue: DatabaseValue = row[0]
    ```
    

## 0.81.0 (Swift 2.3)

Released September 10, 2016

**New**

- Swift 2.3


## 0.80.2 (Swift 2.2)

Released September 9, 2016

**Fixed**

- WatchOS framework


## 0.80.1

Released September 8, 2016

**Fixed**

- WatchOS framework is now available through CocoaPods.


## 0.80.0

Released September 7, 2016

**Fixed**

- `Database.tableExists()` learned about temporary tables

**New**

- WatchOS support

- `QueryInterfaceRequest.deleteAll()` deletes database rows:

    ```swift
    try Wine.filter(corked == true).deleteAll(db)
    ```


## 0.79.4

Released August 17, 2016

**Fixed**

- [DatabasePool](https://github.com/groue/GRDB.swift#database-pools) can now open an existing database which is not yet in the WAL mode, and then immediately read from it. It used to crash unless at least one write operation was performed before any read (fixes [#102](https://github.com/groue/GRDB.swift/issues/102)).


## 0.79.3

Released August 16, 2016

**Fixed**

- [Table creation DSL](https://github.com/groue/GRDB.swift#database-schema) accepts auto references with implicit primary key:

    ```swift
    try db.create(table: "nodes") { t in
        t.column("id", .Integer).primaryKey()
        t.column("parentId", .Integer).references("nodes")
    }
    ```

**New**

- Use SQLColumn of the [query interface](https://github.com/groue/GRDB.swift/#the-query-interface) when extracting values from rows:
    
    ```swift
    let nameColumn = SQLColumn("name")
    let name: String = row.value(nameColumn)
    ```


## 0.79.2

Released August 10, 2016

**Fixed**

- Persistable used to generate sub optimal UPDATE requests.


## 0.79.1

Released August 10, 2016

**Fixed**

- [ColumnDefinition](https://github.com/groue/GRDB.swift#database-schema) `check` and `references` methods can now define several constraints:
    
    ```swift
    try db.create(table: "users") { t in
        t.column("name", .Text).notNull()
            .check { length($0) > 0 }
            .check { !["root", "admin"].contains($0) }
    }
    ```

- [Persistable](https://github.com/groue/GRDB.swift#persistable-protocol) `update`, `exists` and `delete` methods now work with objects that have a nil primary key. They used to crash.

- The `update(_:columns:)` method, which performs partial updates, no longer ignores unknown columns.


## 0.79.0

Released August 8, 2016

**Breaking Change**

- Column creation method `defaults(_:)` has been renamed `defaults(to:)`.
    
    ```swift
    try db.create(table: "pointOfInterests") { t in
        t.column("favorite", .Boolean).notNull().defaults(to: false)
        ...
    }
    ```

## 0.78.0

Released August 6, 2016

**New**

- Upgrade sqlcipher to v3.4.0 ([announcement](https://discuss.zetetic.net/t/sqlcipher-3-4-0-release/1273), [changelog](https://github.com/sqlcipher/sqlcipher/blob/master/CHANGELOG.md))

- DSL for table creation and updates (closes [#83](https://github.com/groue/GRDB.swift/issues/83), [documentation](https://github.com/groue/GRDB.swift#database-schema)):

    ```swift
    try db.create(table: "pointOfInterests") { t in
        t.column("id", .Integer).primaryKey()
        t.column("title", .Text)
        t.column("favorite", .Boolean).notNull()
        t.column("longitude", .Double).notNull()
        t.column("latitude", .Double).notNull()
    }
    ```

- Support for the `length` SQLite built-in function:
    
    ```swift
    try db.create(table: "persons") { t in
        t.column("name", .Text).check { length($0) > 0 }
    }
    ```

- Row adopts DictionaryLiteralConvertible:

    ```swift
    let row: Row = ["name": "foo", "date": NSDate()]
    ```


**Breaking Changes**

- Built-in SQLite collations used to be named by string: "NOCASE", etc. Now use the SQLCollation enum: `.Nocase`, etc.

- PrimaryKey has been renamed PrimaryKeyInfo:

    ```swift
    let pk = db.primaryKey("persons")
    pk.columns  // ["id"]
    ```


## 0.77.0

Released July 28, 2016

**New**

- `Database.indexes(on:)` returns the indexes defined on a database table.

- `Database.table(_:hasUniqueKey:)` returns true if a sequence of columns uniquely identifies a row, that is to say if the columns are the primary key, or if there is a unique index on them.

- MutablePersistable types, including Record subclasses, support partial updates:
    
    ```swift
    try person.update(db)                     // Full update
    try person.update(db, columns: ["name"])  // Only updates the name column
    ```

**Breaking Changes**

- MutablePersistable `update` and `performUpdate` methods have changed their signatures. You only have to care about this change if you customize the protocol `update` method.
    
    ```diff
     protocol MutablePersistable : TableMapping {
    -func update(db: Database) throws
    +func update(db: Database, columns: Set<String>) throws
     }
     
     extension MutablePersistable {
     func update(db: Database) throws
    +func update(db: Database, columns: Set<String>) throws
    +func update<S: SequenceType where S.Generator.Element == SQLColumn>(db: Database, columns: S) throws
    +func update<S: SequenceType where S.Generator.Element == String>(db: Database, columns: S) throws
    -func performUpdate(db: Database) throws
    +func performUpdate(db: Database, columns: Set<String>) throws
     }
    ```


## 0.76.0

Released July 19, 2016

**Breaking Change**

- The query interface `order` method now replaces any previously applied ordering (related issue: [#85](https://github.com/groue/GRDB.swift/issues/85)):
    
    ```swift
    // SELECT * FROM "persons" ORDER BY "name"
    Person.order(scoreColumn).order(nameColumn)
    ```


## 0.75.2

Released July 18, 2016

**Fixed**

- Fixed crashes that could happen when using virtual tables (fixes [#82](https://github.com/groue/GRDB.swift/issues/82))


## 0.75.1

Released July 8, 2016

**Fixed**

- Fixed a crash that would happen when performing a full text search in a DatabasePool (fixes [#80](https://github.com/groue/GRDB.swift/issues/80))


## 0.75.0

Released July 8, 2016

**Breaking change**

- Row adapters have been refactored ([documentation](https://github.com/groue/GRDB.swift#row-adapters)).

    ```diff
     // Row "variants" have been renamed row "scopes":
     struct Row {
    -    func variant(named name: String) -> Row?
    +    func scoped(on name: String) -> Row?
     }
     
     // Scope definition: VariantRowAdapter has been renamed ScopeAdapter:
    -struct VariantRowAdapter : RowAdapter {
    -    init(variants: [String: RowAdapter])
    -}
    +struct ScopeAdapter : RowAdapter {
    +    init(_ scopes: [String: RowAdapter])
    +}
     
     // Adding scopes to an existing adapter:
     extension RowAdapter {
    -    func adapterWithVariants(variants: [String: RowAdapter]) -> RowAdapter
    +    func addingScopes(scopes: [String: RowAdapter]) -> RowAdapter
     }
     
     // Implementing custom adapters
     protocol ConcreteRowAdapter {
    -    var variants: [String: ConcreteRowAdapter] { get }
    +    var scopes: [String: ConcreteRowAdapter] { get }
     }
    ```


## 0.74.0

Released July 6, 2016

**New**

- TableMapping protocol lets you delete rows identified by their primary keys, or any columns involved in a unique index (closes [#56](https://github.com/groue/GRDB.swift/issues/56), [documentation](https://github.com/groue/GRDB.swift/tree/Issue56#tablemapping-protocol)):

    ```swift
    try Person.deleteOne(db, key: 1)
    try Person.deleteOne(db, key: ["email": "arthur@example.com"])
    try Citizenship.deleteOne(db, key: ["personID": 1, "countryCode": "FR"])
    try Country.deleteAll(db, keys: ["FR", "US"])
    ```

**Breaking change**

- The `fetch(_:keys:)`, `fetchAll(_:keys:)` and `fetchOne(_:key:)` methods used to accept any dictionary of column/value pairs to identify rows. Now these methods raise a fatal error if the columns are not guaranteed, at the database level, to uniquely identify rows: columns must be the primary key, or involved in a unique index:

    ```swift
    // CREATE TABLE persons (
    //   id INTEGER PRIMARY KEY, -- can fetch and delete by id
    //   email TEXT UNIQUE,      -- can fetch and delete by email
    //   name TEXT               -- nope
    // )
    Person.fetchOne(db, key: ["id": 1])                       // Person?
    Person.fetchOne(db, key: ["email": "arthur@example.com"]) // Person?
    Person.fetchOne(db, key: ["name": "Arthur"]) // fatal error: table persons has no unique index on column name.
    ```
    
    This change harmonizes the behavior of those fetching methods with the new `deleteOne(_:key:)` and `deleteAll(_:keys:)`.


## 0.73.0

Released June 20, 2016

**Improved**

- [FetchedRecordsController](https://github.com/groue/GRDB.swift#fetchedrecordscontroller) doesn't check for changes when a database transaction modifies columns that are not present in the request it tracks.

**New**

- The query interface lets you provide arguments to your sql snippets ([documentation](https://github.com/groue/GRDB.swift/#the-query-interface)):
    
    ```swift
    let wines = Wine.filter(sql: "origin = ?", arguments: ["Burgundy"]).fetchAll(db)
    ```

- Transaction observers can efficiently filter the database changes they are interested in ([documentation](https://github.com/groue/GRDB.swift#filtering-database-events)).

- Support for NSUUID ([documentation](https://github.com/groue/GRDB.swift/#nsuuid))


## 0.72.0

Released June 9, 2016

**Improved**

- NSDecimalNumber used to store as a double in the database, for all values. Now decimal numbers that contain integers fitting Int64 attempt to store integers in the database.

**Breaking Changes**

- Row adapters have been refactored ([documentation](https://github.com/groue/GRDB.swift#row-adapters)).


## 0.71.0

Released June 5, 2016

**Fixed**

- Fix a crash that would sometimes happen when a FetchedRecordsController's callbacks avoid retain cycles by capturing unowned references.
- Improved handling of numeric overflows. Fixes [#68](https://github.com/groue/GRDB.swift/issues/68).


**New**

- GRDB can now use a custom SQLite build ([documentation](https://github.com/groue/GRDB.swift/tree/master/SQLiteCustom)). Merged [#62](https://github.com/groue/GRDB.swift/pull/62) by [@swiftlyfalling](https://github.com/swiftlyfalling).
- With a custom SQLite build, transaction observers can observe individual column values in the rows modified by a transaction ([documentation](https://github.com/groue/GRDB.swift#support-for-sqlite-pre-update-hooks)). Merged [#63](https://github.com/groue/GRDB.swift/pull/63) by [@swiftlyfalling](https://github.com/swiftlyfalling).
- FetchedRecordsController can now fetch other values alongside the fetched records. This grants you the ability to fetch values that are consistent with the notified changes. ([documentation](https://github.com/groue/GRDB.swift#the-changes-notifications))


**Breaking Changes**

- iOS7 is no longer supported.


## 0.70.1

Released May 30, 2016

**Fixed**

- `Database.cachedUpdateStatement(sql)` no longer returns a statement that can not be reused because it has already failed.


## 0.70.0

Released May 28, 2016

**New**

- `Database.inSavepoint()` allows fine-grained committing and rollbacking of database statements ([documentation](https://github.com/groue/GRDB.swift#transactions-and-savepoints)). Closes [#61](https://github.com/groue/GRDB.swift/issues/61).


## 0.69.0

Released May 28, 2016

**Fixed**

- Database changes that are on hold because of a [savepoint](https://www.sqlite.org/lang_savepoint.html) are only notified to [transaction observers](https://github.com/groue/GRDB.swift#database-changes-observation) after the savepoint has been released. In previous versions of GRDB, savepoints had the opportunity to rollback a subset of database events, and mislead transaction observers about the actual content of a transaction. Related issue: [#61](https://github.com/groue/GRDB.swift/issues/61).

**New**

- `DatabaseEvent.copy()` lets you store a database event notified to a transaction observer ([documentation](https://github.com/groue/GRDB.swift#database-changes-observation)).


## 0.68.0

Released May 28, 2016

**New**

This release provides tools for your custom persistence mechanisms that don't use the built-in [Persistable](https://github.com/groue/GRDB.swift#persistable-protocol) protocol, and addresses issue [#60](https://github.com/groue/GRDB.swift/issues/60).

- `Database.primaryKey(tableName)` lets you introspect a table's primary key ([documentation](https://github.com/groue/GRDB.swift#database-schema-introspection)).
- `Database.cachedSelectStatement(sql)` and `Database.cachedUpdateStatement(sql)` provide robust caching of prepared statements ([documentation](https://github.com/groue/GRDB.swift#prepared-statements-cache))


## 0.67.0

Released May 22, 2016

**New**

- **Row adapters** let you map column names for easier row consumption ([documentation](https://github.com/groue/GRDB.swift#row-adapters)). Fixes [#50](https://github.com/groue/GRDB.swift/issues/50).


## 0.66.0

Released May 21, 2016

**Fixed**

- The Record class no longer adopts the CustomStringConvertible protocol. This frees the `description` identifier for your record properties. Fixes [#58](https://github.com/groue/GRDB.swift/issues/58).

- Several database connections can now be used at the same time: you can move values from one database to another. Fixes [#55](https://github.com/groue/GRDB.swift/issues/55).

**Breaking Changes**

- The maximum number of reader connections in a database pool is now configured in a Configuration object.

    ```diff
     final class DatabasePool {
    -    init(path: String, configuration: Configuration = default, maximumReaderCount: Int = default) throws
    +    init(path: String, configuration: Configuration = default) throws
     }
     struct Configuration {
    +    var maximumReaderCount: Int = default
     }
    ```


## 0.65.0

Released May 19, 2016

**Fixed**

- GRDB throws an early error when a connection to a file can not be established because it has the wrong format, or is encrypted. Fixes [#54](https://github.com/groue/GRDB.swift/issues/54).

**Breaking Change**

- The `FetchRequest` struct has been renamed `QueryInterfaceRequest`. A new `FetchRequest` protocol has been introduced. All APIs that used to consume the `FetchRequest` struct now consume the `FetchRequest` protocol.

    This change should not have any consequence on your source code, and paves the way for easier configuration of any piece of "code that fetches".
    
    ```diff
    -struct FetchRequest<T> {
    -}
    +protocol FetchRequest {
    +    func selectStatement(db: Database) throws -> SelectStatement
    +}
    +struct QueryInterfaceRequest<T> : FetchRequest {
    +    init(tableName: String)
    +}
    ```


## 0.64.0

Released May 18, 2016

**Fixed**

- Restored GRDBCipher framework.

**Breaking Changes**

- `DatabaseValue.failableValue()` has been removed. Instead, use DatabaseConvertible.fromDatabaseValue():
    
    ```diff
    -let date = dbValue.failableValue() as NSDate?
    +let date = NSDate.fromDatabaseValue(dbValue)
    ```

- `Row.databaseValue(named:)` now returns an optional DatabaseValue. It is nil when the column does not exist in the row.
    
    ```diff
     class Row {
    -    func databaseValue(named columnName: String) -> DatabaseValue
    +    func databaseValue(named columnName: String) -> DatabaseValue?
     }
    ```

- Row subscripting by column name has been removed. Instead, use `Row.databaseValue(named:)`
    
    ```diff
     class Row {
    -    subscript(columnName: String) -> DatabaseValue?
     }
    ```


## 0.63.0

Released May 17, 2016

**Fixed**

- Restored support for iOS before 8.2 and OS X before 10.10. Fixes [#51](https://github.com/groue/GRDB.swift/issues/51).

**Breaking Changes**

- Support for advanced migrations is not available until iOS 8.2 and OS X 10.10:
    
    ```diff
     struct DatabaseMigrator {
    -    mutating func registerMigration(identifier: String, withDisabledForeignKeyChecks disabledForeignKeyChecks: Bool = false, migrate: (Database) throws -> Void)
    +    mutating func registerMigration(identifier: String, migrate: (Database) throws -> Void)
    +    @available(iOS 8.2, OSX 10.10, *)
    +    mutating func registerMigrationWithDisabledForeignKeyChecks(identifier: String, migrate: (Database) throws -> Void)
    ```


## 0.62.0

Released May 12, 2016

**Breaking Changes**

- FetchedRecordsController has been refactored ([documentation](https://github.com/groue/GRDB.swift#fetchedrecordscontroller)):
    - delegate has been replaced by callbacks
    - features that target UITableView are now iOS only.

    ```diff
     final class FetchedRecordsController<Record: RowConvertible> {
    -    weak var delegate: FetchedRecordsControllerDelegate?
    -    func recordAtIndexPath(indexPath: NSIndexPath) -> Record
    -    func indexPathForRecord(record: Record) -> NSIndexPath?
    -    var sections: [FetchedRecordsSectionInfo<Record>]
    +    #if os(iOS)
    +        typealias WillChangeCallback = FetchedRecordsController<Record> -> ()
    +        typealias DidChangeCallback = FetchedRecordsController<Record> -> ()
    +        typealias TableViewEventCallback = (controller: FetchedRecordsController<Record>, record: Record, event: TableViewEvent) -> ()
    +        func trackChanges(
    +            recordsWillChange willChangeCallback: WillChangeCallback? = nil,
    +            tableViewEvent tableViewEventCallback: TableViewEventCallback? = nil,
    +            recordsDidChange didChangeCallback: DidChangeCallback? = nil)
    +        func recordAtIndexPath(indexPath: NSIndexPath) -> Record
    +        func indexPathForRecord(record: Record) -> NSIndexPath?
    +        var sections: [FetchedRecordsSectionInfo<Record>]
    +    #else
    +        typealias WillChangeCallback = FetchedRecordsController<Record> -> ()
    +        typealias DidChangeCallback = FetchedRecordsController<Record> -> ()
    +        func trackChanges(
    +            recordsWillChange willChangeCallback: WillChangeCallback? = nil,
    +            recordsDidChange didChangeCallback: DidChangeCallback? = nil)
    +    #endif
     }
    -protocol FetchedRecordsControllerDelegate : class { }
    ```


## 0.61.0

Released May 10, 2016

**New**

- `FetchedRecordsController` is now exposed in OSX CocoaPods framework ([documentation](https://github.com/groue/GRDB.swift#fetchedrecordscontroller))

**Fixed**

- Transactions that fail precisely on the COMMIT statement are now rollbacked (they used to remain open).


## 0.60.1

Released May 7, 2016

**Fixed**

- A crash that did happen when DatabasePool would incorrectly share a database statement between several reader connections.
- A memory leak that did happen when a Database connection was deallocated while some database statements were still alive.


## 0.60.0

Released May 5, 2016

**New**

- `DatabaseReader.backup(to destination: DatabaseWriter)` backups a database to another ([documentation](https://github.com/groue/GRDB.swift#backup)).


## 0.59.1

Released April 25, 2016

**Fixed**

- Carthage support is restored. Fixes [#41](https://github.com/groue/GRDB.swift/issues/41).


## 0.59.0

Released April 23, 2016

**New**

- `Database.isInsideTransaction` is true if database is currently inside a transaction.

**Fixed**

- FetchRequest.reverse() sorts by reversed RowID when no base ordering has been specified.


## 0.58.0

Released April 20, 2016

**New**

- `Database.lastInsertedRowID`: The rowID of the most recent successful INSERT.
- `Database.changesCount`: The number of rows modified, inserted or deleted by the most recent successful INSERT, UPDATE or DELETE statement.
- `Database.totalChangesCount`: The total number of rows modified, inserted or deleted by all successful INSERT, UPDATE or DELETE statements since the database connection was opened.

**Breaking Changes**

- `Database.execute()` and `UpdateStatement.execute()` now return Void. To get the last inserted rowId, use the `Database.lastInsertedRowID` property.


## 0.57.0

Released April 8, 2016

**Breaking Changes**

- Direct access to the database through DatabaseQueue and DatabasePool is no longer supported, because it can hide subtle concurrency bugs in your application:
    
    ```swift
    // No longer supported, because too dangerous:
    try dbQueue.execute("INSERT ...")
    let person = Person.fetchOne(dbQueue, key: 1)
    
    // Always use an explicit DatabaseQueue or DatabasePool method instead:
    try dbQueue.inDatabase { db in
        try db.execute("INSERT ...")
        let person = Person.fetchOne(db, key: 1)
    }
    
    // Extract values:
    let person = dbQueue.inDatabase { db in
        Person.fetchOne(db, key: 1)
    }
    ```
    
    For more information, see [database connections](https://github.com/groue/GRDB.swift#database-connections).
    
    If you are interested in the reasons behind a change that may look like a regression, read https://medium.com/@gwendal.roue/four-different-ways-to-handle-sqlite-concurrency-db3bcc74d00e.

- The following methods have changed their signatures:
    
    ```swift
    protocol MutablePersistable {
        mutating func insert(db: Database) throws
        func update(db: Database) throws
        mutating func save(db: Database) throws
        func delete(db: Database) throws -> Bool
        func exists(db: Database) -> Bool
    }
    
    protocol Persistable {
        func insert(db: Database) throws
        func save(db: Database) throws
    }
    
    class Record {
        func insert(db: Database) throws
        func update(db: Database) throws
        func save(db: Database) throws
        func delete(db: Database) throws -> Bool
        func exists(db: Database) -> Bool
    }
    ```


## 0.56.2

Released April 5, 2016

**Fixed**

- The `save()` method accepts again DatabaseQueue and DatabasePool arguments.


## 0.56.1

Released April 5, 2016

**Fixed**

- Restored CocoaPods support for iOS 8+ and OS X 10.9+


## 0.56.0

Released April 5, 2016

**New**

- The new framework GRDBCipher embeds [SQLCipher](http://sqlcipher.net) and can encrypt databases ([documentation](https://github.com/groue/GRDB.swift#encryption))
- `DatabaseQueue.path` and `DatabasePool.path` give the path to the database.

**Fixed**

- Restored iOS 7 compatibility

**Breaking Changes** (reverted in [0.56.2](#0562))

- The `save()` method now only accepts a database connection, and won't accept a database queue or database pool as an argument. This change makes sure that this method that may execute several SQL statements is called in an isolated fashion.


## 0.55.0

Released March 31, 2016

**New (iOS only)**

- `DatabaseQueue.setupMemoryManagement(application:)` and `DatabasePool.setupMemoryManagement(application:)` make sure GRDB manages memory as a good iOS citizen ([documentation](https://github.com/groue/GRDB.swift#memory-management-on-ios)).


## 0.54.2

Released March 31, 2016

**Fixed**

- Messages of failed preconditions are no longer lost when GRDB is built in Release configuration. Fixes [#37](https://github.com/groue/GRDB.swift/issues/37).


## 0.54.1

Released March 29, 2016

This release restores CocoaPods support for iOS 9.0+ and OSX 10.11+. We'll try to bring back CocoaPods support for iOS 8.0+ or OSX 10.9+ in a further release.


## 0.54.0

Released March 29, 2016

**New**

- `FetchedRecordsController` helps feeding a UITableView with the results returned from a database request ([documentation](https://github.com/groue/GRDB.swift#fetchedrecordscontroller)). Many thanks to [Pascal Edmond](https://github.com/pakko972) for this grandiose feature.

- The standard Swift string properties `capitalizedString`, `lowercaseString`, `uppercaseString`, `localizedCapitalizedString`, `localizedLowercaseString`, `localizedUppercaseString` are available for your database requests ([documentation](https://github.com/groue/GRDB.swift#unicode)).

- The standard Swift comparison functions `caseInsensitiveCompare`, `localizedCaseInsensitiveCompare`, `localizedCompare`, `localizedStandardCompare` and `unicodeCompare` are available for your database requests ([documentation](https://github.com/groue/GRDB.swift#unicode)).


**Fixed**

- The query interface `uppercaseString` and `lowercaseString` no longer invoke the non unicode aware UPPER and LOWER SQLite functions. They instead call the  standard Swift String properties `uppercaseString` and `lowercaseString`.


**Breaking Change**

- The following method has changed its signature:

    ```swift
    protocol RowConvertible {
        mutating func awakeFromFetch(row row: Row)
    }
    ```


## 0.53.0

Released March 25, 2016

**Fixed**

- `Row.value()` and `DatabaseValue.value()` now raise a fatal error when they can not convert a non-NULL value to the requested type ([documentation](https://github.com/groue/GRDB.swift/#column-values)), effectively preventing silent data loss.
    
    Use the new `DatabaseValue.failableValue()` method if you need the old behavior that returned nil for failed conversions.

**New**

- `Row.databaseValue(atIndex:)` and `Row.databaseValue(named:)` expose the [DatabaseValues](https://github.com/groue/GRDB.swift/#databasevalue) of a row.
- `DatabaseValue.failableValue()` returns nil when a non-NULL value can not be converted to the requested type.


## 0.52.1

Released March 24, 2016

**Fixed**

- The [query interface](https://github.com/groue/GRDB.swift/#the-query-interface) now generates robust SQL for explicit boolean comparisons.
    
    ```swift
    // SELECT * FROM "pointOfInterests" WHERE "favorite"
    PointOfInterest.filter(favorite == true).fetchAll(db)
    ```
    
    Previous versions used to generate fragile comparisons to 0 and 1 which did badly interpret true values such as 2.


## 0.52.0

Released March 21, 2016

**New**

- Swift 2.2, and Xcode 7.3
- `Row` adopts the standard `Equatable` protocol.


## 0.51.2

Released March 14, 2016

**Fixed**

- A race condition that could prevent `Configuration.fileAttributes` from being applied to some database files.


## 0.51.1

Released March 13, 2016

Nothing new, but performance improvements


## 0.51.0

Released March 13, 2016

**New**

- Support for file attributes
    
    ```swift
    var config = Configuration()
    config.fileAttributes = [NSFileProtectionKey: NSFileProtectionComplete]
    let dbPool = DatabasePool(path: ".../db.sqlite", configuration: config)
    ```
    
    GRDB will take care of applying them to the database file and all its derivatives (`-wal` and `-shm` files created by the [WAL mode](https://www.sqlite.org/wal.html), as well as [temporary files](https://www.sqlite.org/tempfiles.html)).


## 0.50.1

Released March 12, 2016

**Fixed**

- A database connection won't close as long as there is a database sequence being iterated.


## 0.50.0

Released March 12, 2016

**New**

- Database updates no longer need to be executed in a closure:
    
    ```swift
    // Before:
    try dbQueue.inDatabase { db in
        try db.execute("CREATE TABLE ...")
        let person = Person(...)
        try person.insert(db)
    }
    
    // New:
    try dbQueue.execute("CREATE TABLE ...")
    let person = Person(...)
    try person.insert(dbQueue)
    ```

- DatabaseQueue and DatabasePool both adopt the new [DatabaseReader](https://github.com/groue/GRDB.swift/tree/master/GRDB/Core/DatabaseReader.swift) and [DatabaseWriter](https://github.com/groue/GRDB.swift/tree/master/GRDB/Core/DatabaseWriter.swift) protocols.


**Breaking Changes**

- The following methods have changed their signatures:
    
    ```swift
    protocol MutablePersistable {
        mutating func insert(db: DatabaseWriter) throws
        func update(db: DatabaseWriter) throws
        mutating func save(db: DatabaseWriter) throws
        func delete(db: DatabaseWriter) throws -> Bool
        func exists(db: DatabaseReader) -> Bool
    }
    
    protocol Persistable {
        func insert(db: DatabaseWriter) throws
        func save(db: DatabaseWriter) throws
    }
    
    class Record {
        func insert(db: DatabaseWriter) throws
        func update(db: DatabaseWriter) throws
        func save(db: DatabaseWriter) throws
        func delete(db: DatabaseWriter) throws -> Bool
        func exists(db: DatabaseReader) -> Bool
    }
    ```


## 0.49.0

Released March 11, 2016

**New**

- Read-only database pools grant you with concurrent reads on a database, without activating the WAL mode.
- All fetchable types can now be fetched directly from database queues and pools:
    
    ```swift
    // Before:
    let persons = dbQueue.inDatabase { db in
        Person.fetchAll(db)
    }
    
    // New:
    let persons = Person.fetchAll(dbQueue)
    ```

**Breaking Changes**

- [Transaction observers](https://github.com/groue/GRDB.swift#database-changes-observation) are no longer added to Database instances, but to DatabaseQueue and DatabasePool.


## 0.48.0

Released March 10, 2016

**New**

- `DatabaseQueue.releaseMemory()` and `DatabasePool.releaseMemory()` claim non-essential memory ([documentation](https://github.com/groue/GRDB.swift#memory-management))

**Breaking Changes**

- Custom [functions](https://github.com/groue/GRDB.swift#custom-sql-functions) and [collations](https://github.com/groue/GRDB.swift#string-comparison) are no longer added to Database instances, but to DatabaseQueue and DatabasePool.


## 0.47.0

Released March 10, 2016

**New**

- Support for concurrent accesses to the database, using the SQLite [WAL Mode](https://www.sqlite.org/wal.html). ([documentation](https://github.com/groue/GRDB.swift#database-pools))


## 0.46.0

Released March 5, 2016

**New**

- Improved counting support in the query interface ([documentation](https://github.com/groue/GRDB.swift#fetching-aggregated-values))

**Breaking Changes**

- Swift enums that behave like other database values now need to declare `DatabaseValueConvertible` adoption. The `DatabaseIntRepresentable`, `DatabaseInt32Representable`, `DatabaseInt64Representable` and `DatabaseStringRepresentable` protocols have been removed ([documentation](https://github.com/groue/GRDB.swift#swift-enums))


## 0.45.1

Released February 11, 2016

**Fixed**

- Restored iOS 7 compatibility


## 0.45.0

Released February 9, 2016

**Breaking Change**

- Transaction observers are no longer retained ([documentation](https://github.com/groue/GRDB.swift#database-changes-observation)).


## 0.44.0

Released February 9, 2016

**Fixed**

- `row.value(named:)` and `row[_]` reliably returns the value for the leftmost case-insensitive matching column.
- A memory leak

**New**

Support for more SQL expressions in the [query interface](https://github.com/groue/GRDB.swift/#the-query-interface):

- `IN (subquery)`
- `EXISTS (subquery)`


## 0.43.1

Released February 4, 2016

**Fixed**

- SQL queries ending with a semicolon followed by whitespace characters no longer throw errors.


## 0.43.0

Released February 1, 2016

**Breaking Changes**

- Static method `RowConvertible.fromRow(_:Row)` has been replaced by a regular conversion initializer `RowConvertible.init(_:Row)` ([documentation](https://github.com/groue/GRDB.swift#rowconvertible-protocol))


## 0.42.1

Released January 29, 2016

**Fixed**

- Improved consistency of the [query interface](https://github.com/groue/GRDB.swift/#the-query-interface).


## 0.42.0

Released January 28, 2016

**New**

- The query interface lets you write pure Swift instead of SQL ([documentation](https://github.com/groue/GRDB.swift/#the-query-interface)):
    
    ```swift
    let wines = Wine.filter(origin == "Burgundy").order(price).fetchAll(db)
    ```

**Breaking Changes**

- `DatabasePersistable` and `MutableDatabasePersistable` protocols have been renamed `Persistable` and `MutablePersistable` ([documentation](https://github.com/groue/GRDB.swift/#persistable-protocol))
- `DatabaseTableMapping` protocol has been renamed `TableMapping` ([documentation](https://github.com/groue/GRDB.swift/#tablemapping-protocol))


## 0.41.0

Released January 17, 2016

**New**

You can now register several database observers, thanks to [@pakko972](https://github.com/pakko972) ([documentation](https://github.com/groue/GRDB.swift#database-changes-observation)):

- `Database.addTransactionObserver()`
- `Database.removeTransactionObserver()`

**Breaking Changes**

- `Configuration.transactionObserver` has been removed.


## 0.40.0

Released January 14, 2016

**New**

- Various [performance improvements](https://github.com/groue/GRDB.swift/wiki/Performance)
- `Statement.unsafeSetArguments(_)` binds arguments in a prepared statement without checking if arguments fit.


## 0.39.1

Released January 13, 2016

**New**

- Various [performance improvements](https://github.com/groue/GRDB.swift/wiki/Performance)

**Fixed**

- Fixed the change tracking of Record subclasses that mangle the case of column names.


## 0.39.0

Released January 11, 2016

**Breaking Changes**

- Removed partial update introduced in 0.38.0.


## 0.38.2

Released January 10, 2016

**Fixed**

- Preconditions on invalid statements arguments are restored.

## 0.38.1

Released January 10, 2016

**New**

- Various [performance improvements](https://github.com/groue/GRDB.swift/wiki/Performance)


## 0.38.0

Released January 8, 2016

**New**

- `Record.update()` and `DatabasePersistable.update()` can execute partial updates:
    
    ```swift
    try person.update(db)                    // Full update
    try person.update(db, columns: ["age"])  // Only updates the age column
    ```

**Breaking Changes**

- `Statement.arguments` is no longer optional.
- Your Record subclasses and DatabasePersistable types that provide custom implementation of `update` must use the signature below:
    
    ```swift
    func update(db: Database, columns: [String]? = nil) throws
    ```


## 0.37.1

Released January 7, 2016

**Fixed**

- Remove method `fromRow()` from NSData, NSDate, NSNull, NSNumber, NSString and NSURL, which should have been removed in v0.36.0.


## 0.37.0

Released January 7, 2016

**Fixed**

- A named argument such as `:name` can now be used several times in a statement.
- Validation of statement arguments is much more solid (and tested).

**New**

- `Database.execute()` can now execute several statements separated by a semicolon.
- `Statement.validateArguments(_)` throws an error if the arguments parameter doesn't match the prepared statement:
    
    ```swift
    let statement = try db.selectStatement("SELECT * FROM persons WHERE id = ?")
    // OK
    try statement.validateArguments([1])
    // Error: wrong number of statement arguments: 2
    try statement.validateArguments([1, 2])
    ```

**Breaking Changes**

- `Database.executeMultiStatement(sql)` has been removed. To execute several SQL statements separated by a semicolon, use `Database.execute()` instead.


## 0.36.0

Released December 28, 2015

**Fixed**

- `DatabaseValueConvertible` no longer inherits from `RowConvertible`.
- `Database.execute()` now accepts SQL queries that fetch rows ([#15](https://github.com/groue/GRDB.swift/issues/15)).

**Breaking Changes**

- Methods that return prepared statements can now throw errors ([documentation](https://github.com/groue/GRDB.swift#prepared-statements)).
- `Row(dictionary:)` has been renamed `Row(_:)`.
- `RowConvertible.awakeFromFetch()` now takes a database argument ([documentation](https://github.com/groue/GRDB.swift#rowconvertible-protocol)).


## 0.35.0

Released December 22, 2015

The Record class has been refactored so that it gets closer from the RowConvertible and DatabasePersistable protocols. It also makes it easier to write subclasses that have non-optional properties.

Methods names that did not match [Swift 3 API Design Guidelines](https://swift.org/documentation/api-design-guidelines.html) have been refactored.

**New**

- `Float` adopts DatabaseValueConvertible, and can be stored and fetched from the database without Double conversion ([documentation](https://github.com/groue/GRDB.swift#values)).

**Breaking Changes**

Record ([documentation](https://github.com/groue/GRDB.swift#record-class)):

- `Record.storedDatabaseDictionary` has been renamed `persistentDictionary`.
- `Record.reload()` has been removed. You have to provide your own implementation, should you need reloading.
- `Record.init(row: Row)` has been renamed `Record.init(_ row: Row)` (unlabelled row argument).
- `Record.updateFromRow()` has been removed. Override `init(_ row: Row)` instead.
- `Record.didInsertWithRowID(_:forColumn:)` should be overriden by Record subclasses that are interested in their row ids.
- `Record.databaseEdited` has been renamed `hasPersistentChangedValues`.
- `Record.databaseChanges` has been renamed `persistentChangedValues` and now returns `[String: DatabaseValue?]`, the dictionary of old values for changed columns.

Row:

- `Row.value(named:)` and `Row.dataNoCopy(named:)` returns nil if no such column exists in the row. It used to crash with a fatal error ([documentation](https://github.com/groue/GRDB.swift#column-values)).

DatabasePersistable:

- `DatabasePersistable.storedDatabaseDictionary` has been renamed `persistentDictionary` ([documentation](https://github.com/groue/GRDB.swift#persistable-protocol)).

DatabaseValue:

- `DatabaseValue` has no public initializers. To create one, use `DatabaseValue.Null`, or the fact that Int, String, etc. adopt the DatabaseValueConvertible protocol: `1.databaseValue`, `"foo".databaseValue` ([documentation](https://github.com/groue/GRDB.swift#custom-value-types)).

DatabaseMigrator:

- `DatabaseMigrator.registerMigrationWithoutForeignKeyChecks(_:_:)` has been renamed `DatabaseMigrator.registerMigration(_:withDisabledForeignKeyChecks:migrate:)`  ([documentation](https://github.com/groue/GRDB.swift#advanced-database-schema-changes)).


## 0.34.0

Released December 14, 2015

**New**

- `DatabaseValueConvertible` now inherits from `RowConvertible`.

**Breaking Changes**

- `RowConvertible` no longer requires an `init(row:Row)` initializer, but a `static func fromRow(_:Row) -> Self` factory method.
- `RowConvertible` dictionary initializers have been removed.


## 0.33.0

Released December 11, 2015

**New**

- The `DatabasePersistable` and `MutableDatabasePersistable` protocols grant any adopting type the persistence methods that used to be reserved to subclasses of `Record` ([#12](https://github.com/groue/GRDB.swift/issues/12))
- `Database.clearSchemaCache()`

**Breaking Changes**

- `RecordError` has been renamed `PersistenceError`
- `Record.databaseTableName()` now returns a non-optional String.


## 0.32.2

Released December 3, 2015

**Fixed**

- Errors thrown by update statements expose the correct statement arguments.


## 0.32.1

Released December 2, 2015

**Fixed**

- `DatabaseCollation` did incorrectly process strings provided by sqlite.


## 0.32.0

Released November 23, 2015

**New**

- `DatabaseCollation` let you inject custom string comparison functions into SQLite.
- `DatabaseValue` adopts Hashable.
- `DatabaseValue.isNull` is true if a database value is NULL.
- `DatabaseValue.storage` exposes the underlying SQLite storage (NULL, INTEGER, REAL, TEXT, BLOB).


## 0.31.0

Released November 19, 2015

**New**

- `DatabaseFunction` lets you define custom SQL functions.


## 0.30.0

Released November 17, 2015

**Fixed**

- Prepared statements won't execute unless their arguments are all set.


## 0.29.0

Released November 14, 2015

**New**

- `DatabaseValue.init?(object: AnyObject)` initializer.
- `StatementArguments.Default` is the preferred sentinel for functions that have an optional arguments parameter.


**Breaking Changes**

- `Row.init?(dictionary: NSDictionary)` is now a failable initializer which returns nil if the NSDictionary contains invalid values.
- `RowConvertible.init?(dictionary: NSDictionary)` is now a failable initializer which returns nil if the NSDictionary contains invalid values.
- `StatementArguments.init?(_ array: NSArray)` is now a failable initializer which returns nil if the NSArray contains invalid values.
- `StatementArguments.init?(_ dictionary: NSDictionary)` is now a failable initializer which returns nil if the NSDictionary contains invalid values.
- All methods that used to have an `StatementArguments?` parameter with nil default value now have a non-optional `StatementArguments` parameter with `StatementArguments.Default` as a default value. This makes sure failable StatementArguments initializers don't let invalid inputs sneak in your queries.


## 0.28.0

Released November 13, 2015

**Breaking Change**

- The methods of protocol `TransactionObserverType` are no longer optional.


## 0.27.0

Released November 4, 2015

**New**

- `DatabaseCoder` reads and stores objects that conform to NSCoding in the database.
- `Database.inTransaction()` executes a block inside a database transaction.
- `DatabaseMigrator.registerMigrationWithoutForeignKeyChecks()` let you make arbitrary changes to the database schema, as described at https://www.sqlite.org/lang_altertable.html#otheralter.


**Breaking Changes**

- `Record.delete` returns a Bool which tells whether a database row was deleted or not.


## 0.26.1

Released October 31, 2015

**Fixed repository mess introduced by 0.26.0**


## 0.26.0

Released October 31, 2015

**Breaking Changes**

- The `fetch(:primaryKeys:)`, `fetchAll(:primaryKeys:)` and `fetchOne(:primaryKey:)` methods have been renamed `fetch(:keys:)`, `fetchAll(:keys:)` and `fetchOne(:key:)`.


## 0.25.0

Released October 29, 2015

**Fixed**

- `Record.reload(_)` is no longer a final method.
- GRDB always crashes when you try to convert a database NULL to a non-optional value.


**New**

- CGFloat can be stored and read from the database.
- `Person.fetch(_:primaryKeys:)` returns a sequence of objects with matching primary keys.
- `Person.fetchAll(_:primaryKeys:)` returns an array of objects with matching primary keys.
- `Person.fetch(_:keys:)` returns a sequence of objects with matching keys.
- `Person.fetchAll(_:keys:)` returns an array of objects with matching keys.


## 0.24.0

Released October 14, 2015

**Fixed**

- Restored iOS 7 compatibility


## 0.23.0

Released October 13, 2015

**New**

- `Row()` initializes an empty row.

**Breaking Changes**

- NSData is now the canonical type for blobs. The former intermediate `Blob` type has been removed.
- `DatabaseValue.dataNoCopy()` has turned useless, and has been removed.


## 0.22.0

Released October 8, 2015

**New**

- `Database.sqliteConnection`: the raw SQLite connection, suitable for SQLite C API.
- `Statement.sqliteStatement`: the raw SQLite statement, suitable for SQLite C API.


## 0.21.0

Released October 1, 2015

**Fixed**

- `RowConvertible.awakeFromFetch(_)` is declared as `mutating`.


**New**

- Improved value extraction errors.

- `Row.hasColumn(_)`

- `RowConvertible` and `Record` get a dictionary initializer for free:

    ```swift
    class Person: Record { ... }
    let person = Person(dictionary: ["name": "Arthur", "birthDate": nil])
    ```

- Improved Foundation support:
    
    ```swift
    Row(dictionary: NSDictionary)
    Row.toDictionary() -> NSDictionary
    ```

- Int32 and Int64 enums are supported via DatabaseInt32Representable and DatabaseInt64Representable.


**Breaking Changes**

- `TraceFunction` is now defined as `(String) -> ()`


## 0.20.0

Released September 29, 2015

**New**

- Support for NSURL

**Breaking Changes**

- The improved TransactionObserverType protocol lets adopting types modify the database after a successful commit or rollback, and abort a transaction with an error.


## 0.19.0

Released September 28, 2015

**New**

- The `Configuration.transactionObserver` lets you observe database changes.


## 0.18.0

Released September 26, 2015

**Fixed**

- It is now mandatory to provide values for all arguments of an SQL statement. GRDB used to assume NULL for missing ones.

**New**

- `Row.dataNoCopy(atIndex:)` and `Row.dataNoCopy(named:)`.
- `Blob.dataNoCopy`
- `DatabaseValue.dataNoCopy`

**Breaking Changes**

- `String.fetch...` now returns non-optional values. Use `Optional<String>.fetch...` when values may be NULL.


## 0.17.0

Released September 24, 2015

**New**

- Performance improvements.
- You can extract non-optional values from Row and DatabaseValue.
- Types that adopt SQLiteStatementConvertible on top of the DatabaseValueConvertible protocol are granted with faster database access.

**Breaking Changes**

- Rows can be reused during a fetch query iteration. Use `row.copy()` to keep one.
- Database sequences are now of type DatabaseSequence.
- Blob and NSData relationships are cleaner.


## 0.16.0

Released September 14, 2015

**New**

- `Configuration.busyMode` let you specify how concurrent connections should handle database locking.
- `Configuration.transactionType` let you specify the default transaction type.

**Breaking changes**

- Default transaction type has changed from EXCLUSIVE to IMMEDIATE.


## 0.15.0

Released September 12, 2015

**Fixed**

- Usage assertions used to be disabled. They are activated again.

**Breaking changes**

- `DatabaseQueue.inDatabase` and `DatabaseQueue.inTransaction` are no longer reentrant.


## 0.14.0

Released September 12, 2015

**Fixed**

- `DatabaseQueue.inTransaction()` no longer crashes when SQLite returns a SQLITE_BUSY error code.

**Breaking changes**

- `Database.updateStatement(_:)` is no longer a throwing method.
- `DatabaseQueue.inTransaction()` is now declared as `throws`, not `rethrows`.


## 0.13.0

Released September 10, 2015

**New**

- `DatabaseQueue.inDatabase` and `DatabaseQueue.inTransaction` are now reentrant. You can't open a transaction inside another, though.
- `Record.copy()` returns a copy of the receiver.
- `Row[columnName]` and `Row.value(named:)` are now case-insensitive.

**Breaking changes**

- Requires Xcode 7.0 (because of [#2](https://github.com/groue/GRDB.swift/issues/2))
- `RowModel` has been renamed `Record`.
- `Record.copyDatabaseValuesFrom` has been removed in favor of `Record.copy()`.
- `Record.awakeFromFetch()` now takes a row argument.


## 0.12.0

Released September 6, 2015

**New**

- `RowConvertible` and `DatabaseTableMapping` protocols grant any type the fetching methods that used to be a privilege of `RowModel`.
- `Row.columnNames` returns the names of columns in the row.
- `Row.databaseValues` returns the database values in the row.
- `Blob.init(bytes:length:)` is a new initializer.
- `DatabaseValueConvertible` can now be adopted by non-final classes.
- `NSData`, `NSDate`, `NSNull`, `NSNumber` and `NSString` adopt `DatabaseValueConvertible` and can natively be stored and fetched from a database.

**Breaking changes**

- `DatabaseDate` has been removed (replaced by built-in NSDate support).
- `DatabaseValueConvertible`: `init?(dbValue:)` has been replaced by `static func fromDatabaseValue(_:) -> Self?`
- `Blob.init(_:)` has been replaced with `Blob.init(data:)` and `Blob.init(dataNoCopy:)`.
- `RowModel.edited` has been renamed `RowModel.databaseEdited`.
- `RowModel.databaseTable` has been replaced with `RowModel.databaseTableName()` which returns a String.
- `RowModel.setDatabaseValue(_:forColumn:)` has been removed. Use and override `RowModel.updateFromRow(_:)` instead.
- `RowModel.didFetch()` has been renamed `RowModel.awakeFromFetch()`


## 0.11.0

Released September 4, 2015

**Breaking changes**

The fetching methods are now available on the fetched type themselves:

```swift
dbQueue.inDatabase { db in
    Row.fetch(db, "SELECT ...", arguments: ...)        // AnySequence<Row>
    Row.fetchAll(db, "SELECT ...", arguments: ...)     // [Row]
    Row.fetchOne(db, "SELECT ...", arguments: ...)     // Row?
    
    String.fetch(db, "SELECT ...", arguments: ...)     // AnySequence<String?>
    String.fetchAll(db, "SELECT ...", arguments: ...)  // [String?]
    String.fetchOne(db, "SELECT ...", arguments: ...)  // String?
    
    Person.fetch(db, "SELECT ...", arguments: ...)     // AnySequence<Person>
    Person.fetchAll(db, "SELECT ...", arguments: ...)  // [Person]
    Person.fetchOne(db, "SELECT ...", arguments: ...)  // Person?
}
```


## 0.10.0

Released September 4, 2015

**New**

- `DatabaseValue` adopts `DatabaseValueConvertible`: a fetched value can be used as an argument of another query, without having to convert the raw database value into a regular Swift type.
- `Row.init(dictionary)` lets you create a row from scratch.
- `RowModel.didFetch()` is an overridable method that is called after a RowModel has been fetched or reloaded.
- `RowModel.updateFromRow(row)` is an overridable method that helps updating compound properties that do not fit in a single column, such as CLLocationCoordinate2D.


## 0.9.0

Released August 25, 2015

**Fixed**

- Reduced iOS Deployment Target to 8.0, and OSX Deployment Target to 10.9.
- `DatabaseQueue.inTransaction()` is now declared as `rethrows`.

**Breaking changes**

- Requires Xcode 7 beta 6
- `QueryArguments` has been renamed `StatementArguments`.


## 0.8.0

Released August 18, 2015

**New**

- `RowModel.exists(db)` returns whether a row model has a matching row in the database.
- `Statement.arguments` property gains a public setter.
- `Database.executeMultiStatement(sql)` can execute several SQL statements separated by a semi-colon ([#6](http://github.com/groue/GRDB.swift/pull/6) by [peter-ss](https://github.com/peter-ss))

**Breaking changes**

- `UpdateStatement.Changes` has been renamed `DatabaseChanges` ([#6](http://github.com/groue/GRDB.swift/pull/6) by [peter-ss](https://github.com/peter-ss)).


## 0.7.0

Released July 30, 2015

**New**

- `RowModel.delete(db)` returns whether a database row was deleted or not.

**Breaking changes**

- `RowModelError.InvalidPrimaryKey` has been replaced by a fatal error.


## 0.6.0

Released July 30, 2015

**New**

- `DatabaseDate` can read dates stored as Julian Day Numbers.
- `Int32` can be stored and fetched.


## 0.5.0

Released July 22, 2015

**New**

- `DatabaseDate` handles storage of NSDate in the database.
- `DatabaseDateComponents` handles storage of NSDateComponents in the database.

**Fixed**

- `RowModel.save(db)` calls `RowModel.insert(db)` or `RowModel.update(db)` so that eventual overridden versions of `insert` or `update` are invoked.
- `QueryArguments(NSArray)` and `QueryArguments(NSDictionary)` now accept NSData elements.

**Breaking changes**

- "Bindings" has been renamed "QueryArguments", and `bindings` parameters renamed `arguments`.
- Reusable statements no longer expose any setter for their `arguments` property, and no longer accept any arguments in their initializer. To apply arguments, give them to the `execute()` and `fetch()` methods.
- `RowModel.isEdited` and `RowModel.setEdited()` have been replaced by the `RowModel.edited` property.


## 0.4.0

Released July 12, 2015

**Fixed**

- `RowModel.save(db)` makes its best to store values in the database. In particular, when the row model has a non-nil primary key, it will insert when there is no row to update. It used to throw RowModelNotFound in this case.


## v0.3.0

Released July 11, 2015

**New**

- `Blob.init?(NSData?)`

    Creates a Blob from NSData. Returns nil if and only if *data* is nil or zero-length (SQLite can't store empty blobs).

- `RowModel.isEdited`

    A boolean that indicates whether the row model has changes that have not been saved.

    This flag is purely informative: it does not alter the behavior the update() method, which executes an UPDATE statement in every cases.

    But you can prevent UPDATE statements that are known to be pointless, as in the following example:

    ```swift
    let json = ...

    // Fetches or create a new person given its ID:
    let person = Person.fetchOne(db, primaryKey: json["id"]) ?? Person()

    // Apply json payload:
    person.updateFromJSON(json)

    // Saves the person if it is edited (fetched then modified, or created):
    if person.isEdited {
        person.save(db) // inserts or updates
    }
    ```

- `RowModel.copyDatabaseValuesFrom(_:)`

    Updates a row model with values of another one.

- `DatabaseValue` adopts Equatable.

**Breaking changes**

- `RowModelError.UnspecifiedTable` and `RowModelError.InvalidDatabaseDictionary` have been replaced with fatal errors because they are programming errors.

## v0.2.0

Released July 9, 2015

**Breaking changes**

- Requires Xcode 7 beta 3

**New**

- `RowModelError.InvalidDatabaseDictionary`: new error case that helps you designing a fine RowModel subclass.


## v0.1.0

Released July 9, 2015

Initial release
