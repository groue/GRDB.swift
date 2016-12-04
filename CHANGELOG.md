Release Notes
=============

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

**Breaking Change**

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
    -let dbv = row.databaseValue(atIndex: 0)
    +let dbv: DatabaseValue = row.value(atIndex: 0)
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
    -    static func fromDatabaseValue(databaseValue: DatabaseValue) -> DatabaseValue?
    +    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> DatabaseValue?
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
    -let dbv = row.databaseValue(atIndex: 0)
    +let dbv: DatabaseValue = row.value(atIndex: 0)
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
    -let date = dbv.failableValue() as NSDate?
    +let date = NSDate.fromDatabaseValue(dbv)
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
- `DatabaseValueConvertible`: `init?(databaseValue:)` has been replaced by `static func fromDatabaseValue(_:) -> Self?`
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
