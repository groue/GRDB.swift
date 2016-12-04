GRDB.swift [![Swift](https://img.shields.io/badge/swift-3-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/GRDB.swift.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/groue/GRDB.swift.svg?maxAge=2592000)](/LICENSE)
==========

### A Swift application toolkit for SQLite databases.

**Latest release**: December 4, 2016 &bull; version 0.93.0 &bull; [CHANGELOG](CHANGELOG.md)

**Requirements**: iOS 8.0+ / OSX 10.9+ / watchOS 2.0+ &bull; Xcode 8+ &bull; Swift 3

- Swift 2.2: use the [version 0.80.2](https://github.com/groue/GRDB.swift/tree/v0.80.2)
- Swift 2.3: use the [version 0.81.2](https://github.com/groue/GRDB.swift/tree/v0.81.2)

Follow [@groue](http://twitter.com/groue) on Twitter for release announcements and usage tips.

---

<p align="center">
    <a href="#features">Features</a> &bull;
    <a href="#usage">Usage</a> &bull;
    <a href="#installation">Installation</a> &bull;
    <a href="#documentation">Documentation</a> &bull;
    <a href="#faq">FAQ</a>
</p>

---

## Features

GRDB ships with a **[low-level SQLite API](#sqlite-api)**, and high-level tools that help dealing with databases:

- **[Records](#records)**: fetching and persistence methods for your custom structs and class hierarchies
- **[Query Interface](#the-query-interface)**: a swift way to avoid the SQL language
- **[WAL Mode Support](#database-pools)**: that means extra performance for multi-threaded applications
- **[Migrations](#migrations)**: transform your database as your application evolves
- **[Database Changes Observation](#database-changes-observation)**: perform post-commit and post-rollback actions
- **[Fetched Records Controller](#fetchedrecordscontroller)**: automated tracking of changes in a query results, and UITableView animations
- **[Full-Text Search](#full-text-search)**: Perform efficient and customizable full-text searches.
- **[Encryption](#encryption)** with SQLCipher
- **[Support for custom SQLite builds](Documentation/CustomSQLiteBuilds.md)**

More than a set of tools that leverage SQLite abilities, GRDB is also:

- **Safer**: read the blog post [Four different ways to handle SQLite concurrency](https://medium.com/@gwendal.roue/four-different-ways-to-handle-sqlite-concurrency-db3bcc74d00e)
- **Faster**: see [Comparing the Performances of Swift SQLite libraries](https://github.com/groue/GRDB.swift/wiki/Performance)
- Well [documented](#documentation) & tested

For a general overview of how a protocol-oriented library impacts database accesses, have a look at [How to build an iOS application with SQLite and GRDB.swift](https://medium.com/@gwendal.roue/how-to-build-an-ios-application-with-sqlite-and-grdb-swift-d023a06c29b3).


## Usage

Open a [connection](#database-connections) to the database:

```swift
import GRDB
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
```

[Execute SQL statements](#executing-updates):

```swift
try dbQueue.inDatabase { db in
    try db.execute(
        "CREATE TABLE pointOfInterests (" +
            "id INTEGER PRIMARY KEY, " +
            "title TEXT NOT NULL, " +
            "favorite BOOLEAN NOT NULL DEFAULT 0, " +
            "latitude DOUBLE NOT NULL, " +
            "longitude DOUBLE NOT NULL" +
        ")")

    try db.execute(
        "INSERT INTO pointOfInterests (title, favorite, latitude, longitude) " +
        "VALUES (?, ?, ?, ?)",
        arguments: ["Paris", true, 48.85341, 2.3488])
    
    let parisId = db.lastInsertedRowID
}
```

[Fetch database rows and values](#fetch-queries):

```swift
try dbQueue.inDatabase { db in
    let rows = try Row.fetchCursor(db, "SELECT * FROM pointOfInterests")
    while let row = try rows.next() {
        let title: String = row.value(named: "title")
        let isFavorite: Bool = row.value(named: "favorite")
        let coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),
            row.value(named: "longitude"))
    }

    let poiCount = try Int.fetchOne(db, "SELECT COUNT(*) FROM pointOfInterests")! // Int
    let poiTitles = try String.fetchAll(db, "SELECT title FROM pointOfInterests") // [String]
}

// Extraction
let poiCount = try dbQueue.inDatabase { db in
    try Int.fetchOne(db, "SELECT COUNT(*) FROM pointOfInterests")!
}
```

Insert and fetch [records](#records):

```swift
struct PointOfInterest {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    var coordinate: CLLocationCoordinate2D
}

// snip: turn PointOfInterest into a "record" by adopting the protocols that
// provide fetching and persistence methods.

try dbQueue.inDatabase { db in
    var berlin = PointOfInterest(
        id: nil,
        title: "Berlin",
        isFavorite: false,
        coordinate: CLLocationCoordinate2DMake(52.52437, 13.41053))
    
    try berlin.insert(db)
    berlin.id // some value
    
    berlin.isFavorite = true
    try berlin.update(db)
    
    // Fetch [PointOfInterest] from SQL
    let pois = try PointOfInterest.fetchAll(db, "SELECT * FROM pointOfInterests")
}
```

Avoid SQL with the [query interface](#the-query-interface):

```swift
try dbQueue.inDatabase { db in
    try db.create(table: "pointOfInterests") { t in
        t.column("id", .integer).primaryKey()
        t.column("title", .text).notNull()
        t.column("favorite", .boolean).notNull().defaults(to: false)
        t.column("longitude", .double).notNull()
        t.column("latitude", .double).notNull()
    }
    
    // PointOfInterest?
    let paris = try PointOfInterest.fetchOne(db, key: 1)
    
    // PointOfInterest?
    let titleColumn = Column("title")
    let berlin = try PointOfInterest.filter(titleColumn == "Berlin").fetchOne(db)
    
    // [PointOfInterest]
    let favoriteColumn = Column("favorite")
    let favoritePois = try PointOfInterest
        .filter(favoriteColumn)
        .order(titleColumn)
        .fetchAll(db)
}
```


Documentation
=============

**GRDB runs on top of SQLite**: you should get familiar with the [SQLite FAQ](http://www.sqlite.org/faq.html). For general and detailed information, jump to the [SQLite Documentation](http://www.sqlite.org/docs.html).

**Reference**

- [GRDB Reference](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/index.html) (on cocoadocs.org)

**Getting Started**

- [Installation](#installation)
- [Database Connections](#database-connections): Connect to SQLite databases

**SQLite and SQL**

- [SQLite API](#sqlite-api): The low-level SQLite API &bull; [executing updates](#executing-updates) &bull; [fetch queries](#fetch-queries)

**Records and the Query Interface**

- [Records](#records): Fetching and persistence methods for your custom structs and class hierarchies.
- [Query Interface](#the-query-interface): A swift way to generate SQL &bull; [table creation](#database-schema) &bull; [fetch requests](#requests)

**Application Tools**

- [Migrations](#migrations): Transform your database as your application evolves.
- [Full-Text Search](#full-text-search): Perform efficient and customizable full-text searches.
- [Database Changes Observation](#database-changes-observation): Perform post-commit and post-rollback actions.
- [FetchedRecordsController](#fetchedrecordscontroller): Automatic database changes tracking, plus UITableView animations.
- [Encryption](#encryption): Encrypt your database with SQLCipher.
- [Backup](#backup): Dump the content of a database to another.
- [GRDB Extension Guide](Documentation/ExtendingGRDB.md): When a feature is lacking, extend GRDB right from your application.

**Good to Know**

- [Avoiding SQL Injection](#avoiding-sql-injection)
- [Error Handling](#error-handling)
- [Unicode](#unicode)
- [Memory Management](#memory-management)
- [Concurrency](#concurrency)
- [Performance](#performance)

[FAQ](#faq)

[Sample Code](#sample-code)


Installation
============

**The installation procedures below have GRDB use the version of SQLite that ships with the target operating system.**

See [Encryption](#encryption) for the installation procedure of GRDB with SQLCipher.

See [Custom SQLite builds](Documentation/CustomSQLiteBuilds.md) for the installation procedure of GRDB with a customized build of SQLite 3.15.2.


## CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Xcode projects. To use GRDB.swift with CocoaPods:

1. Make sure Xcode is installed in the /Applications folder, with its regular name Xcode.

2. Install cocoapods version 1.1 or higher

3. Specify in your Podfile:

    ```ruby
    use_frameworks!
    pod 'GRDB.swift'
    ```


## Carthage

[Carthage](https://github.com/Carthage/Carthage) is a dependency manager for Xcode projects. To use GRDB.swift with Carthage:

1. Make sure Xcode is installed in the /Applications folder, with its regular name Xcode.

2. Specify in your Cartfile:

    ```
    github "groue/GRDB.swift"
    ```


## Manually

1. Make sure Xcode is installed in the /Applications folder, with its regular name Xcode.

2. [Download](https://github.com/groue/GRDB.swift/releases/tag/v0.93.0) a copy of GRDB.swift, or clone its repository and make sure you use the latest tagged version with the `git checkout v0.93.0` command.

3. Embed the `GRDB.xcodeproj` project in your own project.

4. Add the `GRDBOSX`, `GRDBiOS`, or `GRDBWatchOS` target in the **Target Dependencies** section of the **Build Phases** tab of your application target.

5. Add the `GRDB.framework` from the targetted platform to the **Embedded Binaries** section of the **General**  tab of your target.

See [GRDBDemoiOS](DemoApps/GRDBDemoiOS) for an example of such integration.


Database Connections
====================

GRDB provides two classes for accessing SQLite databases: `DatabaseQueue` and `DatabasePool`:

```swift
import GRDB

// Pick one:
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
```

The differences are:

- Database pools allow concurrent database accesses (this can improve the performance of multithreaded applications).
- Unless read-only, database pools open your SQLite database in the [WAL mode](https://www.sqlite.org/wal.html).
- Database queues support [in-memory databases](https://www.sqlite.org/inmemorydb.html).

**If you are not sure, choose DatabaseQueue.** You will always be able to switch to DatabasePool later.

- [Database Queues](#database-queues)
- [Database Pools](#database-pools)


## Database Queues

**Open a database queue** with the path to a database file:

```swift
import GRDB

let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let inMemoryDBQueue = DatabaseQueue()
```

SQLite creates the database file if it does not already exist. The connection is closed when the database queue gets deallocated.


**A database queue can be used from any thread.** The `inDatabase` and `inTransaction` methods block the current thread until your database statements are executed in a protected dispatch queue. They safely serialize the database accesses:

```swift
// Execute database statements:
try dbQueue.inDatabase { db in
    try db.create(table: "pointOfInterests") { ... }
    try PointOfInterest(...).insert(db)
}

// Wrap database statements in a transaction:
try dbQueue.inTransaction { db in
    if let poi = try PointOfInterest.fetchOne(db, key: 1) {
        try poi.delete(db)
    }
    return .commit
}

// Read values:
try dbQueue.inDatabase { db in
    let pois = try PointOfInterest.fetchAll(db)
    let poiCount = try PointOfInterest.fetchCount(db)
}

// Extract a value from the database:
let poiCount = try dbQueue.inDatabase { db in
    try PointOfInterest.fetchCount(db)
}
```

**A database queue needs your application to follow rules in order to deliver its safety guarantees.** Please refer to the [Concurrency](#concurrency) chapter.

See [DemoApps/GRDBDemoiOS/Database.swift](DemoApps/GRDBDemoiOS/GRDBDemoiOS/Database.swift) for a sample code that sets up a database queue on iOS.


### DatabaseQueue Configuration

```swift
var config = Configuration()
config.readonly = true
config.foreignKeysEnabled = true // Default is already true
config.trace = { print($0) }     // Prints all SQL statements
config.fileAttributes = [FileAttributeKey.protectionKey.rawValue: ...]  // Configure database protection

let dbQueue = try DatabaseQueue(
    path: "/path/to/database.sqlite",
    configuration: config)
```

See [Configuration](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Structs/Configuration.html) for more details.


## Database Pools

[Database Queues](#database-queues) prevent concurrent accesses: at every moment, there is no more than a single thread that is using the database.

**A Database Pool can improve your application performance because it allows concurrent database accesses.**

```swift
import GRDB
let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
```

SQLite creates the database file if it does not already exist. The connection is closed when the database pool gets deallocated.

> :point_up: **Note**: unless read-only, a database pool opens your database in the SQLite "WAL mode". The WAL mode does not fit all situations. Please have a look at https://www.sqlite.org/wal.html.


**A database pool can be used from any thread.** The `read`, `write` and `writeInTransaction` methods block the current thread until your database statements are executed in a protected dispatch queue. They safely isolate the database accesses:

```swift
// Execute database statements:
try dbPool.write { db in
    try db.create(table: "pointOfInterests") { ... }
    try PointOfInterest(...).insert(db)
}

// Wrap database statements in a transaction:
try dbPool.writeInTransaction { db in
    if let poi = try PointOfInterest.fetchOne(db, key: 1) {
        try poi.delete(db)
    }
    return .commit
}

// Read values:
try dbPool.read { db in
    let pois = try PointOfInterest.fetchAll(db)
    let poiCount = try PointOfInterest.fetchCount(db)
}

// Extract a value from the database:
let poiCount = try dbPool.read { db in
    try PointOfInterest.fetchCount(db)
}
```

Database pools allow several threads to access the database at the same time:

- When you don't need to modify the database, prefer the `read` method, because several threads can perform reads in parallel.

- The total number of concurrent reads is limited. When the maximum number has been reached, a read waits for another read to complete. That maximum number can be configured (see below).

- Conversely, writes are serialized. They still can happen in parallel with reads, but GRDB makes sure that those parallel writes are not visible inside a `read` closure.

**A database pool needs your application to follow rules in order to deliver its safety guarantees.** Please refer to the [Concurrency](#concurrency) chapter.

See [Advanced DatabasePool](#advanced-databasepool) for more DatabasePool hotness.

For a sample code that sets up a database pool on iOS, see [DemoApps/GRDBDemoiOS/Database.swift](DemoApps/GRDBDemoiOS/GRDBDemoiOS/Database.swift), and replace DatabaseQueue with DatabasePool.


### DatabasePool Configuration

```swift
var config = Configuration()
config.readonly = true
config.foreignKeysEnabled = true // Default is already true
config.trace = { print($0) }     // Prints all SQL statements
config.fileAttributes = [FileAttributeKey.protectionKey.rawValue: ...]  // Configure database protection
config.maximumReaderCount = 10   // The default is 5

let dbPool = try DatabasePool(
    path: "/path/to/database.sqlite",
    configuration: config)
```

See [Configuration](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Structs/Configuration.html) for more details.


Database pools are more memory-hungry than database queues. See [Memory Management](#memory-management) for more information.


SQLite API
==========

**In this section of the documentation, we will talk SQL.** Jump to the [query interface](#the-query-interface) if SQL is not your cup of tea.

- [Executing Updates](#executing-updates)
- [Fetch Queries](#fetch-queries)
    - [Fetching Methods](#fetching-methods)
    - [Row Queries](#row-queries)
    - [Value Queries](#value-queries)
- [Values](#values)
    - [Data](#data-and-memory-savings)
    - [Date and DateComponents](#date-and-datecomponents)
    - [NSNumber and NSDecimalNumber](#nsnumber-and-nsdecimalnumber)
    - [Swift enums](#swift-enums)
- [Transactions and Savepoints](#transactions-and-savepoints)

Advanced topics:

- [Custom Value Types](#custom-value-types)
- [Prepared Statements](#prepared-statements)
- [Custom SQL Functions](#custom-sql-functions)
- [Database Schema Introspection](#database-schema-introspection)
- [Row Adapters](#row-adapters)
- [Raw SQLite Pointers](#raw-sqlite-pointers)


## Executing Updates

Once granted with a [database connection](#database-connections), the `execute` method executes the SQL statements that do not return any database row, such as `CREATE TABLE`, `INSERT`, `DELETE`, `ALTER`, etc.

For example:

```swift
try db.execute(
    "CREATE TABLE persons (" +
        "id INTEGER PRIMARY KEY," +
        "name TEXT NOT NULL," +
        "age INT" +
    ")")

try db.execute(
    "INSERT INTO persons (name, age) VALUES (:name, :age)",
    arguments: ["name": "Barbara", "age": 39])

// Join multiple statements with a semicolon:
try db.execute(
    "INSERT INTO persons (name, age) VALUES (?, ?); " +
    "INSERT INTO persons (name, age) VALUES (?, ?)",
    arguments: ["Arthur", 36, "Barbara", 39])
```

The `?` and colon-prefixed keys like `:name` in the SQL query are the **statements arguments**. You pass arguments with arrays or dictionaries, as in the example above. See [Values](#values) for more information on supported arguments types (Bool, Int, String, Date, Swift enums, etc.).

Never ever embed values directly in your SQL strings, and always use arguments instead. See [Avoiding SQL Injection](#avoiding-sql-injection) for more information.

**After an INSERT statement**, you can get the row ID of the inserted row:

```swift
try db.execute(
    "INSERT INTO persons (name, age) VALUES (?, ?)",
    arguments: ["Arthur", 36])
let personId = db.lastInsertedRowID
```

Don't miss [Records](#records), that provide classic **persistence methods**:

```swift
let person = Person(name: "Arthur", age: 36)
try person.insert(db)
let personId = person.id
```


## Fetch Queries

You can fetch database rows, plain values, and custom models aka "records".

**Rows** are the raw results of SQL queries:

```swift
if let row = try Row.fetchOne(db, "SELECT * FROM wines WHERE id = ?", arguments: [1]) {
    let name: String = row.value(named: "name")
    let color: Color = row.value(named: "color")
    print(name, color)
}
```


**Values** are the Bool, Int, String, Date, Swift enums, etc. stored in row columns:

```swift
let urls = try URL.fetchCursor(db, "SELECT url FROM wines")
while let url = try urls.next() {
    print(url)
}
```


**Records** are your application objects that can initialize themselves from rows:

```swift
let wines = try Wine.fetchAll(db, "SELECT * FROM wines")
```

- [Fetching Methods](#fetching-methods) and [Cursors](#cursors)
- [Row Queries](#row-queries)
- [Value Queries](#value-queries)
- [Records](#records)


### Fetching Methods

**Throughout GRDB**, you can always fetch *cursors*, *arrays*, or *single values* of any fetchable type (database [row](#row-queries), simple [value](#value-queries), or custom [record](#records)):

```swift
try Type.fetchCursor(...) // DatabaseCursor<Type>
try Type.fetchAll(...)    // [Type]
try Type.fetchOne(...)    // Type?
```

- `fetchCursor` returns a **[cursor](#cursors)** over fetched values:
    
    ```swift
    let rows = try Row.fetchCursor(db, "SELECT ...") // DatabaseCursor<Row>
    while let row = try rows.next() {
        ...
    }
    ```
    
- `fetchAll` returns an **array**:
    
    ```swift
    let persons = try Person.fetchAll(db, "SELECT ...") // [Person]
    ```

- `fetchOne` returns a **single optional value**, and consumes a single database row (if any).
    
    ```swift
    let count = try Int.fetchOne(db, "SELECT COUNT(*) ...") // Int?
    ```


#### Cursors

**Whenever you consume several rows from the database, you can fetch a Cursor, or an Array**.

Array contains copies of database values and may be consumed on any thread. But they can take a lot of memory. Conversely, cursors iterate over database results in a lazy fashion, don't consume much memory, and are generally more efficient. But they must be consumed in a [protected dispatch queue](#database-connections):

```swift
let rows = try Row.fetchAll(db, "SELECT * FROM links")    // [Row]
let rows = try Row.fetchCursor(db, "SELECT * FROM links") // DatabaseCursor<Row>
```


A common way to iterate over the elements of a cursor is to use a `while` loop:

```swift
let rows = try Row.fetchCursor(db, "SELECT * FROM links")
while let row = try rows.next() {
    let url: URL = row.value(named: "url")
    print(url)
}
```

You can also use the `forEach` method:

```swift
try rows.forEach { row in
    let url: URL = row.value(named: "url")
    print(url)
}
```

Don't modify the database during a cursor iteration:

```swift
// Undefined behavior
while let row = try rows.next() {
    try db.execute("DELETE FROM link ...")
}
```

Cursors come with default implementations for many operations similar to those defined by [lazy sequences of the Swift Standard Library](https://developer.apple.com/reference/swift/lazysequenceprotocol): `contains`, `enumerated`, `filter`, `first`, `flatMap`, `forEach`, `joined`, `map`, `reduce`:

```swift
// Enumerate all Github links
try URL.fetchCursor(db, "SELECT url FROM links")
    .filter { url in url.host == "github.com" }
    .enumerated()
    .forEach { (index, url) in ... }
```


### Row Queries

- [Fetching Rows](#fetching-rows)
- [Column Values](#column-values)
- [DatabaseValue](#databasevalue)
- [Rows as Dictionaries](#rows-as-dictionaries)


#### Fetching Rows

Fetch **cursors** of rows, **arrays**, or **single** rows (see [fetching methods](#fetching-methods)):

```swift
try Row.fetchCursor(db, "SELECT ...", arguments: ...) // DatabaseCursor<Row>
try Row.fetchAll(db, "SELECT ...", arguments: ...)    // [Row]
try Row.fetchOne(db, "SELECT ...", arguments: ...)    // Row?

let rows = try Row.fetchCursor(db, "SELECT * FROM wines")
while let row = try rows.next() {
    let name: String = row.value(named: "name")
    let color: Color = row.value(named: "color")
    print(name, color)
}
```

Arguments are optional arrays or dictionaries that fill the positional `?` and colon-prefixed keys like `:name` in the query:

```swift
let rows = try Row.fetchAll(db,
    "SELECT * FROM persons WHERE name = ?",
    arguments: ["Arthur"])

let rows = try Row.fetchAll(db,
    "SELECT * FROM persons WHERE name = :name",
    arguments: ["name": "Arthur"])
```

See [Values](#values) for more information on supported arguments types (Bool, Int, String, Date, Swift enums, etc.).

Unlike row arrays that contain copies of the database rows, row cursors are close to the SQLite metal, and require a little care:

> :point_up: **Don't turn a row cursor into an array**, with `Array(rowCursor)` for example: you would not get the distinct rows you expect. To get a row array, use `Row.fetchAll(...)`. Generally speaking, make sure you copy a row whenever you extract it from a cursor for later use: `row.copy()`.


#### Column Values

**Read column values** by index or column name:

```swift
let name: String = row.value(atIndex: 0)     // 0 is the leftmost column
let name: String = row.value(named: "name")  // Leftmost matching column - lookup is case-insensitive
let name: String = row.value(Column("name")) // Using query interface's Column
```

Make sure to ask for an optional when the value may be NULL:

```swift
let name: String? = row.value(named: "name")
```

The `value` function returns the type you ask for. See [Values](#values) for more information on supported value types:

```swift
let bookCount: Int     = row.value(named: "bookCount")
let bookCount64: Int64 = row.value(named: "bookCount")
let hasBooks: Bool     = row.value(named: "bookCount")  // false when 0

let string: String     = row.value(named: "date")       // "2015-09-11 18:14:15.123"
let date: Date         = row.value(named: "date")       // Date
self.date = row.value(named: "date") // Depends on the type of the property.
```

You can also use the `as` type casting operator:

```swift
row.value(...) as Int
row.value(...) as Int?
```

> :warning: **Warning**: avoid the `as!` and `as?` operators, because they misbehave in the context of type inference (see [rdar://21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
> 
> ```swift
> if let int = row.value(...) as? Int { ... } // BAD - doesn't work
> if let int = row.value(...) as Int? { ... } // GOOD
> ```

Generally speaking, you can extract the type you need, *provided it can be converted from the underlying SQLite value*:

- **Successful conversions include:**
    
    - All numeric SQLite values to all numeric Swift types, and Bool (zero is the only false boolean).
    - Text SQLite values to Swift String.
    - Blob SQLite values to Foundation Data.
    
    See [Values](#values) for more information on supported types (Bool, Int, String, Date, Swift enums, etc.)

- **NULL returns nil.**

    ```swift
    let row = try Row.fetchOne(db, "SELECT NULL")!
    row.value(atIndex: 0) as Int? // nil
    row.value(atIndex: 0) as Int  // fatal error: could not convert NULL to Int.
    ```
    
    There is one exception, though: the [DatabaseValue](#databasevalue) type:
    
    ```swift
    row.value(atIndex: 0) as DatabaseValue // DatabaseValue.null
    ```
    
- **Missing columns return nil.**
    
    ```swift
    let row = try Row.fetchOne(db, "SELECT 'foo' AS foo")!
    row.value(named: "missing") as String? // nil
    row.value(named: "missing") as String  // fatal error: no such column: missing
    ```
    
    You can explicitly check for a column presence with the `hasColumn` method.

- **Invalid conversions throw a fatal error.**
    
    ```swift
    let row = try Row.fetchOne(db, "SELECT 'Mom’s birthday'")!
    row.value(atIndex: 0) as String // "Mom’s birthday"
    row.value(atIndex: 0) as Date?  // fatal error: could not convert "Mom’s birthday" to Date.
    row.value(atIndex: 0) as Date   // fatal error: could not convert "Mom’s birthday" to Date.
    ```
    
    This fatal error can be avoided with the [DatabaseValueConvertible.fromDatabaseValue()](#custom-value-types) method.
    
- **SQLite has a weak type system, and provides [convenience conversions](https://www.sqlite.org/c3ref/column_blob.html) that can turn Blob to String, String to Int, etc.**
    
    GRDB will sometimes let those conversions go through:
    
    ```swift
    let rows = try Row.fetchCursor(db, "SELECT '20 small cigars'")
    while let row = try rows.next() {
        row.value(atIndex: 0) as Int   // 20
    }
    ```
    
    Don't freak out: those conversions did not prevent SQLite from becoming the immensely successful database engine you want to use. And GRDB adds safety checks described just above. You can also prevent those convenience conversions altogether by using the [DatabaseValue](#databasevalue) type.


#### DatabaseValue

**DatabaseValue is an intermediate type between SQLite and your values, which gives information about the raw value stored in the database.**

You get DatabaseValue just like other value types:

```swift
let dbv: DatabaseValue = row.value(atIndex: 0)
let dbv: DatabaseValue = row.value(named: "name")

// Check for NULL:
dbv.isNull // Bool

// All the five storage classes supported by SQLite:
switch dbv.storage {
case .null:                 print("NULL")
case .int64(let int64):     print("Int64: \(int64)")
case .double(let double):   print("Double: \(double)")
case .string(let string):   print("String: \(string)")
case .blob(let data):       print("Data: \(data)")
}
```

You can extract regular [values](#values) (Bool, Int, String, Date, Swift enums, etc.) from DatabaseValue with the [DatabaseValueConvertible.fromDatabaseValue()](#custom-value-types) method:

```swift
let dbv: DatabaseValue = row.value(named: "bookCount")
let bookCount   = Int.fromDatabaseValue(dbv)   // Int?
let bookCount64 = Int64.fromDatabaseValue(dbv) // Int64?
let hasBooks    = Bool.fromDatabaseValue(dbv)  // Bool?, false when 0

let dbv: DatabaseValue = row.value(named: "date")
let string = String.fromDatabaseValue(dbv)     // "2015-09-11 18:14:15.123"
let date   = Date.fromDatabaseValue(dbv)       // Date?
```

`fromDatabaseValue` returns nil for invalid conversions:

```swift
let row = try Row.fetchOne(db, "SELECT 'Mom’s birthday'")!
let dbv: DatabaseValue = row.value(at: 0)
let string = String.fromDatabaseValue(dbv) // "Mom’s birthday"
let int    = Int.fromDatabaseValue(dbv)    // nil
let date   = Date.fromDatabaseValue(dbv)   // nil
```

This turns out useful when you process untrusted databases. Compare:

```swift
let date: Date? = row.value(atIndex: 0)  // fatal error: could not convert "Mom’s birthday" to Date.
let date = Date.fromDatabaseValue(row.value(atIndex: 0)) // nil
```


#### Rows as Dictionaries

Row adopts the standard [CollectionType](https://developer.apple.com/library/ios/documentation/Swift/Reference/Swift_CollectionType_Protocol/index.html) protocol, and can be seen as a dictionary of [DatabaseValue](#databasevalue):

```swift
// All the (columnName, databaseValue) tuples, from left to right:
for (columnName, databaseValue) in row {
    ...
}
```

**You can build rows from dictionaries** (standard Swift dictionaries and NSDictionary). See [Values](#values) for more information on supported types:

```swift
let row: Row = ["name": "foo", "date": nil]
let row = Row(["name": "foo", "date": nil])
let row = Row(/* [AnyHashable: Any] */) // nil if invalid dictionary
```

Yet rows are not real dictionaries: they are ordered, and may contain duplicate keys:

```swift
let row = try Row.fetchOne(db, "SELECT 1 AS foo, 2 AS foo")!
row.columnNames     // ["foo", "foo"]
row.databaseValues  // [1, 2]
for (columnName, databaseValue) in row { ... } // ("foo", 1), ("foo", 2)
```


### Value Queries

Instead of rows, you can directly fetch **[values](#values)**. Like rows, fetch them as **cursors**, **arrays**, or **single** values (see [fetching methods](#fetching-methods)). Values are extracted from the leftmost column of the SQL queries:

```swift
try Int.fetchCursor(db, "SELECT ...", arguments: ...) // DatabaseCursor<Int>
try Int.fetchAll(db, "SELECT ...", arguments: ...)    // [Int]
try Int.fetchOne(db, "SELECT ...", arguments: ...)    // Int?

// When database may contain NULL:
try Optional<Int>.fetchCursor(db, "SELECT ...", arguments: ...) // DatabaseCursor<Int?>
try Optional<Int>.fetchAll(db, "SELECT ...", arguments: ...)    // [Int?]
```

`fetchOne` returns an optional value which is nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value.

There are many supported value types (Bool, Int, String, Date, Swift enums, etc.). See [Values](#values) for more information:

```swift
let count = try Int.fetchOne(db, "SELECT COUNT(*) FROM persons")! // Int
let urls = try URL.fetchAll(db, "SELECT url FROM links")          // [URL]
```


## Values

GRDB ships with built-in support for the following value types:

- **Swift Standard Library**: Bool, Double, Float, Int, Int32, Int64, String, [Swift enums](#swift-enums).
    
- **Foundation**: [Data](#data-and-memory-savings), [Date](#date-and-datecomponents), [DateComponents](#date-and-datecomponents), NSNull, [NSNumber](#nsnumber-and-nsdecimalnumber), NSString, URL, [UUID](#uuid).
    
- **CoreGraphics**: CGFloat.

- **[DatabaseValue](#databasevalue)**, the type which gives information about the raw value stored in the database.

- **Full-Text Patterns**: [FTS3Pattern](#fts3pattern) and [FTS5Pattern](#fts5pattern).

- Generally speaking, all types that adopt the [DatabaseValueConvertible](#custom-value-types) protocol.

Values can be used as [statement arguments](#executing-updates):

```swift
let url: URL = ...
let verified: Bool = ...
try db.execute(
    "INSERT INTO links (url, verified) VALUES (?, ?)",
    arguments: [url, verified])
```

Values can be [extracted from rows](#column-values):

```swift
let rows = try Row.fetchCursor(db, "SELECT * FROM links")
while let row = try rows.next() {
    let url: URL = row.value(named: "url")
    let verified: Bool = row.value(named: "verified")
}
```

Values can be [directly fetched](#value-queries):

```swift
let urls = try URL.fetchAll(db, "SELECT url FROM links")  // [URL]
```

Use values in [Records](#records):

```swift
class Link : Record {
    var url: URL
    var isVerified: Bool
    
    required init(row: Row) {
        url = row.value(named: "url")
        isVerified = row.value(named: "verified")
        super.init(row: row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["url": url, "verified": isVerified]
    }
}
```

Use values in the [query interface](#the-query-interface):

```swift
let url: URL = ...
let link = try Link.filter(urlColumn == url).fetchOne(db)
```


### Data (and Memory Savings)

**Data** suits the BLOB SQLite columns. It can be stored and fetched from the database just like other [values](#values):

```swift
let rows = try Row.fetchCursor(db, "SELECT data, ...")
while let row = try rows.next() {
    let data: Data = row.value(named: "data")
}
```

At each step of the request iteration, the `row.value` method creates *two copies* of the database bytes: one fetched by SQLite, and another, stored in the Swift Data value.

**You have the opportunity to save memory** by not copying the data fetched by SQLite:

```swift
while let row = try rows.next() {
    let data = row.dataNoCopy(named: "data") // Data?
}
```

The non-copied data does not live longer than the iteration step: make sure that you do not use it past this point.


### Date and DateComponents

[**Date**](#date) and [**DateComponents**](#datecomponents) can be stored and fetched from the database.

Here is the support provided by GRDB for the various [date formats](https://www.sqlite.org/lang_datefunc.html) supported by SQLite:

| SQLite format                | Date         | DateComponents |
|:---------------------------- |:------------:|:--------------:|
| YYYY-MM-DD                   |     Read ¹   |   Read/Write   |
| YYYY-MM-DD HH:MM             |     Read ¹   |   Read/Write   |
| YYYY-MM-DD HH:MM:SS          |     Read ¹   |   Read/Write   |
| YYYY-MM-DD HH:MM:SS.SSS      | Read/Write ¹ |   Read/Write   |
| YYYY-MM-DD**T**HH:MM         |     Read ¹   |      Read      |
| YYYY-MM-DD**T**HH:MM:SS      |     Read ¹   |      Read      |
| YYYY-MM-DD**T**HH:MM:SS.SSS  |     Read ¹   |      Read      |
| HH:MM                        |              |   Read/Write   |
| HH:MM:SS                     |              |   Read/Write   |
| HH:MM:SS.SSS                 |              |   Read/Write   |
| Julian Day Number            |     Read ²   |                |
| `now`                        |              |                |

¹ Dates are stored and read in the UTC time zone. Missing components are assumed to be zero.

² See https://en.wikipedia.org/wiki/Julian_day


#### Date

**Date** can be stored and fetched from the database just like other [values](#values):

```swift
try db.execute(
    "INSERT INTO persons (creationDate, ...) VALUES (?, ...)",
    arguments: [Date(), ...])

let creationDate: Date = row.value(named: "creationDate")
```

Dates are stored using the format "YYYY-MM-DD HH:MM:SS.SSS" in the UTC time zone. It is precise to the millisecond.

> :point_up: **Note**: this format was chosen because it is the only format that is:
> 
> - Comparable (`ORDER BY date` works)
> - Comparable with the SQLite keyword CURRENT_TIMESTAMP (`WHERE date > CURRENT_TIMESTAMP` works)
> - Able to feed [SQLite date & time functions](https://www.sqlite.org/lang_datefunc.html)
> - Precise enough
> 
> Yet this format may not fit your needs. For example, you may want to store dates as timestamps. In this case, store and load Doubles instead of Date, and perform the required conversions.


#### DateComponents

DateComponents is indirectly supported, through the **DatabaseDateComponents** helper type.

DatabaseDateComponents reads date components from all [date formats supported by SQLite](https://www.sqlite.org/lang_datefunc.html), and stores them in the format of your choice, from HH:MM to YYYY-MM-DD HH:MM:SS.SSS.

DatabaseDateComponents can be stored and fetched from the database just like other [values](#values):

```swift
let components = DateComponents()
components.year = 1973
components.month = 9
components.day = 18

// Store "1973-09-18"
let dbComponents = DatabaseDateComponents(components, format: .YMD)
try db.execute(
    "INSERT INTO persons (birthDate, ...) VALUES (?, ...)",
    arguments: [dbComponents, ...])

// Read "1973-09-18"
let row = try Row.fetchOne(db, "SELECT birthDate ...")!
let dbComponents: DatabaseDateComponents = row.value(named: "birthDate")
dbComponents.format         // .YMD (the actual format found in the database)
dbComponents.dateComponents // DateComponents
```


### NSNumber and NSDecimalNumber

**NSNumber** can be stored and fetched from the database just like other [values](#values). Floating point NSNumbers are stored as Double. Integer and boolean, as Int64. Integers that don't fit Int64 won't be stored: you'll get a fatal error instead. Be cautious when an NSNumber contains an UInt64, for example.

NSDecimalNumber deserves a longer discussion:

**SQLite has no support for decimal numbers.** Given the table below, SQLite will actually store integers or doubles:

```sql
CREATE TABLE transfers (
    amount DECIMAL(10,5) -- will store integer or double, actually
)
```

This means that computations will not be exact:

```swift
try db.execute("INSERT INTO transfers (amount) VALUES (0.1)")
try db.execute("INSERT INTO transfers (amount) VALUES (0.2)")
let sum = try NSDecimalNumber.fetchOne(db, "SELECT SUM(amount) FROM transfers")!

// Yikes! 0.3000000000000000512
print(sum)
```

Don't blame SQLite or GRDB, and instead store your decimal numbers differently.

A classic technique is to store *integers* instead, since SQLite performs exact computations of integers. For example, don't store Euros, but store cents instead:

```swift
// Store
let amount = NSDecimalNumber(string: "0.1")                       // 0.1
let integerAmount = amount.multiplying(byPowerOf10: 2).int64Value // 100
try db.execute("INSERT INTO transfers (amount) VALUES (?)", arguments: [integerAmount])

// Read
let integerAmount = try Int64.fetchOne(db, "SELECT SUM(amount) FROM transfers")!    // 100
let amount = NSDecimalNumber(value: integerAmount).multiplying(byPowerOf10: -2) // 0.1
```


### UUID

**UUID** can be stored and fetched from the database just like other [values](#values). GRDB stores uuids as 16-bytes data blobs.


### Swift Enums

**Swift enums** and generally all types that adopt the [RawRepresentable](https://developer.apple.com/library/tvos/documentation/Swift/Reference/Swift_RawRepresentable_Protocol/index.html) protocol can be stored and fetched from the database just like their raw [values](#values):

```swift
enum Color : Int {
    case red, white, rose
}

enum Grape : String {
    case chardonnay, merlot, riesling
}

// Declare empty DatabaseValueConvertible adoption
extension Color : DatabaseValueConvertible { }
extension Grape : DatabaseValueConvertible { }

// Store
try db.execute(
    "INSERT INTO wines (grape, color) VALUES (?, ?)",
    arguments: [Grape.merlot, Color.red])

// Read
let rows = try Row.fetchCursor(db, "SELECT * FROM wines")
while let row = try rows.next() {
    let grape: Grape = row.value(named: "grape")
    let color: Color = row.value(named: "color")
}
```

**When a database value does not match any enum case**, you get a fatal error. This fatal error can be avoided with the [DatabaseValueConvertible.fromDatabaseValue()](#custom-value-types) method:

```swift
let row = try Row.fetchOne(db, "SELECT 'syrah'")!

row.value(atIndex: 0) as String  // "syrah"
row.value(atIndex: 0) as Grape?  // fatal error: could not convert "syrah" to Grape.
row.value(atIndex: 0) as Grape   // fatal error: could not convert "syrah" to Grape.
Grape.fromDatabaseValue(row.value(atIndex: 0))  // nil
```


## Transactions and Savepoints

The `DatabaseQueue.inTransaction()` and `DatabasePool.writeInTransaction()` methods open an SQLite transaction and run their closure argument in a protected dispatch queue. They block the current thread until your database statements are executed:

```swift
try dbQueue.inTransaction { db in
    let wine = Wine(color: .red, name: "Pomerol")
    try wine.insert(db)
    return .commit
}
```

If an error is thrown within the transaction body, the transaction is rollbacked and the error is rethrown by the `inTransaction` method. If you return `.rollback` from your closure, the transaction is also rollbacked, but no error is thrown.

If you want to insert a transaction between other database statements, you can use the Database.inTransaction() function:

```swift
try dbQueue.inDatabase { db in  // or dbPool.write { db in
    ...
    try db.inTransaction {
        ...
        return .commit
    }
    ...
}
```

You can ask a database if a transaction is currently opened:

```swift
func myCriticalMethod(_ db: Database) throws {
    precondition(db.isInsideTransaction, "This method requires a transaction")
    try ...
}
```

Yet, you have a better option than checking for transactions: critical sections of your application should use savepoints, described below:

```swift
func myCriticalMethod(_ db: Database) throws {
    try db.inSavepoint {
        // Here the database is guaranteed to be inside a transaction.
        try ...
    }
}
```


### Savepoints

**Statements grouped in a savepoint can be rollbacked without invalidating a whole transaction:**

```swift
try dbQueue.inTransaction { db in
    try db.inSavepoint { 
        try db.execute("DELETE ...")
        try db.execute("INSERT ...") // need to rollback the delete above if this fails
        return .commit
    }
    
    // Other savepoints, etc...
    return .commit
}
```

If an error is thrown within the savepoint body, the savepoint is rollbacked and the error is rethrown by the `inSavepoint` method. If you return `.rollback` from your closure, the body is also rollbacked, but no error is thrown.

**Unlike transactions, savepoints can be nested.** They implicitly open a transaction if no one was opened when the savepoint begins. As such, they behave just like nested transactions. Yet the database changes are only committed to disk when the outermost savepoint is committed:

```swift
try dbQueue.inDatabase { db in
    try db.inSavepoint {
        ...
        try db.inSavepoint {
            ...
            return .commit
        }
        ...
        return .commit  // writes changes to disk
    }
}
```

SQLite savepoints are more than nested transactions, though. For advanced savepoints uses, use [SQL queries](https://www.sqlite.org/lang_savepoint.html).


### Transaction Kinds

SQLite supports [three kinds of transactions](https://www.sqlite.org/lang_transaction.html): deferred, immediate, and exclusive. GRDB defaults to immediate.

The transaction kind can be changed in the database configuration, or for each transaction:

```swift
// A connection with default DEFERRED transactions:
var config = Configuration()
config.defaultTransactionKind = .deferred
let dbQueue = try DatabaseQueue(path: "...", configuration: config)

// Opens a DEFERRED transaction:
dbQueue.inTransaction { db in ... }

// Opens an EXCLUSIVE transaction:
dbQueue.inTransaction(.exclusive) { db in ... }
```


## Custom Value Types

Conversion to and from the database is based on the `DatabaseValueConvertible` protocol:

```swift
public protocol DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns a value initialized from databaseValue, if possible.
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self?
}
```

All types that adopt this protocol can be used like all other [values](#values) (Bool, Int, String, Date, Swift enums, etc.)

The `databaseValue` property returns [DatabaseValue](#databasevalue), a type that wraps the five values supported by SQLite: NULL, Int64, Double, String and Data. Since DatabaseValue has no public initializer, use `DatabaseValue.null`, or another type that already adopts the protocol: `1.databaseValue`, `"foo".databaseValue`, etc. Conversion to DatabaseValue *must not* fail.

The `fromDatabaseValue()` factory method returns an instance of your custom type if the databaseValue contains a suitable value. If the databaseValue does not contain a suitable value, such as "foo" for Date, `fromDatabaseValue` *must* return nil (GRDB will interpret this nil result as a conversion error, and react accordingly).

The [GRDB Extension Guide](Documentation/ExtendingGRDB.md) contains sample code that has UIColor adopt DatabaseValueConvertible.


## Prepared Statements

**Prepared Statements** let you prepare an SQL query and execute it later, several times if you need, with different arguments.

There are two kinds of prepared statements: **select statements**, and **update statements**:

```swift
try dbQueue.inDatabase { db in
    let updateSQL = "INSERT INTO persons (name, age) VALUES (:name, :age)"
    let updateStatement = try db.makeUpdateStatement(updateSQL)
    
    let selectSQL = "SELECT * FROM persons WHERE name = ?"
    let selectStatement = try db.makeSelectStatement(selectSQL)
}
```

The `?` and colon-prefixed keys like `:name` in the SQL query are the statement arguments. You set them with arrays or dictionaries (arguments are actually of type StatementArguments, which happens to adopt the ExpressibleByArrayLiteral and ExpressibleByDictionaryLiteral protocols).

```swift
updateStatement.arguments = ["name": "Arthur", "age": 41]
selectStatement.arguments = ["Arthur"]
```

After arguments are set, you can execute the prepared statement:

```swift
try updateStatement.execute()
```

Select statements can be used wherever a raw SQL query string would fit (see [fetch queries](#fetch-queries)):

```swift
let rows = try Row.fetchCursor(selectStatement)    // DatabaseCursor<Row>
let persons = try Person.fetchAll(selectStatement) // [Person]
let person = try Person.fetchOne(selectStatement)  // Person?
```

You can set the arguments at the moment of the statement execution:

```swift
try updateStatement.execute(arguments: ["name": "Arthur", "age": 41])
let person = try Person.fetchOne(selectStatement, arguments: ["Arthur"])
```

> :point_up: **Note**: it is a programmer error to reuse a prepared statement that has failed: GRDB may crash if you do so.

See [row queries](#row-queries), [value queries](#value-queries), and [Records](#records) for more information.


### Prepared Statements Cache

When the same query will be used several times in the lifetime of your application, you may feel a natural desire to cache prepared statements.

**Don't cache statements yourself.**

> :point_up: **Note**: This is because you don't have the necessary tools. Statements are tied to specific SQLite connections and dispatch queues which you don't manage yourself, especially when you use [database pools](#database-pools). A change in the database schema [may, or may not](https://www.sqlite.org/compile.html#max_schema_retry) invalidate a statement. On systems earlier than iOS 8.2 and OSX 10.10 that don't have the [sqlite3_close_v2 function](https://www.sqlite.org/c3ref/close.html), SQLite connections won't close properly if statements have been kept alive.

Instead, use the `cachedUpdateStatement` and `cachedSelectStatement` methods. GRDB does all the hard caching and [memory management](#memory-management) stuff for you:

```swift
let updateStatement = try db.cachedUpdateStatement(sql)
let selectStatement = try db.cachedSelectStatement(sql)
```

Should a cached prepared statement throw an error, don't reuse it (it is a programmer error). Instead, reload it from the cache.


## Custom SQL Functions

**SQLite lets you define SQL functions.**

A custom SQL function extends SQLite. It can be used in raw SQL queries. And when SQLite needs to evaluate it, it calls your custom code.

```swift
let reverseString = DatabaseFunction("reverseString", argumentCount: 1, pure: true) { (values: [DatabaseValue]) in
    // Extract string value, if any...
    guard let string = String.fromDatabaseValue(values[0]) else {
        return nil
    }
    // ... and return reversed string:
    return String(string.characters.reversed())
}
dbQueue.add(function: reverseString)   // Or dbPool.add(function: ...)

try dbQueue.inDatabase { db in
    // "oof"
    try String.fetchOne(db, "SELECT reverseString('foo')")!
}
```

The *function* argument takes an array of [DatabaseValue](#databasevalue), and returns any valid [value](#values) (Bool, Int, String, Date, Swift enums, etc.) The number of database values is guaranteed to be *argumentCount*.

SQLite has the opportunity to perform additional optimizations when functions are "pure", which means that their result only depends on their arguments. So make sure to set the *pure* argument to true when possible.


**Functions can take a variable number of arguments:**

When you don't provide any explicit *argumentCount*, the function can take any number of arguments:

```swift
let averageOf = DatabaseFunction("averageOf", pure: true) { (values: [DatabaseValue]) in
    let doubles = values.flatMap { Double.fromDatabaseValue($0) }
    return doubles.reduce(0, +) / Double(doubles.count)
}
dbQueue.add(function: averageOf)

try dbQueue.inDatabase { db in
    // 2.0
    try Double.fetchOne(db, "SELECT averageOf(1, 2, 3)")!
}
```


**Functions can throw:**

```swift
let sqrt = DatabaseFunction("sqrt", argumentCount: 1, pure: true) { (values: [DatabaseValue]) in
    guard let double = Double.fromDatabaseValue(values[0]) else {
        return nil
    }
    guard double >= 0 else {
        throw DatabaseError(message: "invalid negative number")
    }
    return sqrt(double)
}
dbQueue.add(function: sqrt)

// SQLite error 1 with statement `SELECT sqrt(-1)`: invalid negative number
try dbQueue.inDatabase { db in
    try Double.fetchOne(db, "SELECT sqrt(-1)")!
}
```


**Use custom functions in the [query interface](#the-query-interface):**

```swift
// SELECT reverseString("name") FROM persons
Person.select(reverseString.apply(nameColumn))
```


**GRDB ships with built-in SQL functions that perform unicode-aware string transformations.** See [Unicode](#unicode).


## Database Schema Introspection

**SQLite provides database schema introspection tools**, such as the [sqlite_master](https://www.sqlite.org/faq.html#q7) table, and the pragma [table_info](https://www.sqlite.org/pragma.html#pragma_table_info):

```swift
try db.create(table: "persons") { t in
    t.column("id", .integer).primaryKey()
    t.column("name", .text)
}

// <Row type:"table" name:"persons" tbl_name:"persons" rootpage:2
//      sql:"CREATE TABLE persons(id INTEGER PRIMARY KEY, name TEXT)">
for row in try Row.fetchAll(db, "SELECT * FROM sqlite_master") {
    print(row)
}

// <Row cid:0 name:"id" type:"INTEGER" notnull:0 dflt_value:NULL pk:1>
// <Row cid:1 name:"name" type:"TEXT" notnull:0 dflt_value:NULL pk:0>
for row in try Row.fetchAll(db, "PRAGMA table_info('persons')") {
    print(row)
}
```

GRDB provides four high-level methods as well:

```swift
try db.tableExists("persons") // Bool, true if the table exists
try db.indexes(on: "persons") // [IndexInfo], the indexes defined on the table
try db.table("persons", hasUniqueKey: ["email"]) // Bool, true if column(s) is a unique key
try db.primaryKey("persons")  // PrimaryKeyInfo?
```

Primary key is nil when table has no primary key:

```swift
// CREATE TABLE items (name TEXT)
let itemPk = try db.primaryKey("items") // nil
```

Primary keys have one or several columns. Single-column primary keys may contain the auto-incremented [row id](https://www.sqlite.org/autoinc.html):

```swift
// CREATE TABLE persons (
//   id INTEGER PRIMARY KEY,
//   name TEXT
// )
let personPk = try db.primaryKey("persons")!
personPk.columns     // ["id"]
personPk.rowIDColumn // "id"

// CREATE TABLE countries (
//   isoCode TEXT NOT NULL PRIMARY KEY
//   name TEXT
// )
let countryPk = db.primaryKey("countries")!
countryPk.columns     // ["isoCode"]
countryPk.rowIDColumn // nil

// CREATE TABLE citizenships (
//   personID INTEGER NOT NULL REFERENCES persons(id)
//   countryIsoCode TEXT NOT NULL REFERENCES countries(isoCode)
//   PRIMARY KEY (personID, countryIsoCode)
// )
let citizenshipsPk = db.primaryKey("citizenships")!
citizenshipsPk.columns     // ["personID", "countryIsoCode"]
citizenshipsPk.rowIDColumn // nil
```


## Row Adapters

**Row adapters let you map column names for easier row consumption.**

They basically help two incompatible row interfaces to work together. For example, a row consumer expects a column named "consumed", but the produced row has a column named "produced":

```swift
// An adapter that maps column 'consumed' to column 'produced':
let adapter = ColumnMapping(["consumed": "produced"])

// Fetch a column named 'produced', and apply adapter:
let row = try Row.fetchOne(db, "SELECT 'Hello' AS produced", adapter: adapter)!

// The adapter in action:
row.value(named: "consumed") // "Hello"
```


**Row adapters can also define row "scopes".** Scopes help several consumers feed on a single row and can reveal useful with joined queries.

For example, let's build a query which loads books along with their author:

```swift
let sql = "SELECT books.id, books.title, " +
          "       books.authorID, persons.name AS authorName " +
          "FROM books " +
          "JOIN persons ON books.authorID = persons.id"
```

The author columns are "authorID" and "authorName". Let's say that we prefer to consume them as "id" and "name". For that we define a scope named "author":

```swift
let authorMapping = ColumnMapping(["id": "authorID", "name": "authorName"])
let adapter = ScopeAdapter(["author": authorMapping])
```

Use the `Row.scoped(on:)` method to access the "author" scope:

```swift
let rows = try Row.fetchCursor(db, sql, adapter: adapter)
while let row = try rows.next() {
    // The fetched row, without adaptation:
    row.value(named: "id")          // 1
    row.value(named: "title")       // Moby-Dick
    row.value(named: "authorID")    // 10
    row.value(named: "authorName")  // Melville
    
    // The "author" scope, with mapped columns:
    if let authorRow = row.scoped(on: "author") {
        authorRow.value(named: "id")    // 10
        authorRow.value(named: "name")  // Melville
    }
}
```

> :bowtie: **Tip**: now that we have nice "id" and "name" columns, we can leverage [RowConvertible](#rowconvertible-protocol) types such as [Record](#record-class) subclasses. For example, assuming the Book type consumes the "author" scope in its row initializer and builds a Person from it, the same row can be consumed by both the Book and Person types:
> 
> ```swift
> let books = try Book.fetchCursor(db, sql, adapter: adapter)
> while let book = try books.next() {
>     book.title        // Moby-Dick
>     book.author?.name // Melville
> }
> ```
> 
> And Person and Book can still be fetched without row adapters:
> 
> ```swift
> let books = try Book.fetchAll(db, "SELECT * FROM books")
> let persons = try Person.fetchAll(db, "SELECT * FROM persons")
> ```


**You can mix a main adapter with scopes:**

```swift
let sql = "SELECT main.id AS mainID, main.name AS mainName, " +
          "       friend.id AS friendID, friend.name AS friendName, " +
          "FROM persons main " +
          "LEFT JOIN persons friend ON friend.id = main.bestFriendID"

let mainAdapter = ColumnMapping(["id": "mainID", "name": "mainName"])
let bestFriendAdapter = ColumnMapping(["id": "friendID", "name": "friendName"])
let adapter = mainAdapter.addingScopes(["bestFriend": bestFriendAdapter])

let rows = try Row.fetchCursor(db, sql, adapter: adapter)
while let row = try rows.next() {
    // The fetched row, adapted with mainAdapter:
    row.value(named: "id")   // 1
    row.value(named: "name") // Arthur
    
    // The "bestFriend" scope, with bestFriendAdapter:
    if let bestFriendRow = row.scoped(on: "bestFriend") {
        bestFriendRow.value(named: "id")    // 2
        bestFriendRow.value(named: "name")  // Barbara
    }
}

// Assuming Person.init(row:) consumes the "bestFriend" scope:
let persons = try Person.fetchCursor(db, sql, adapter: adapter)
while let person = try persons.next() {
    person.name             // Arthur
    person.bestFriend?.name // Barbara
}
```


For more information about row adapters, see the documentation of:

- [RowAdapter](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Protocols/RowAdapter.html): the protocol that lets you define your custom row adapters
- [ColumnMapping](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Structs/ColumnMapping.html): a row adapter that renames row columns
- [SuffixRowAdapter](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Structs/SuffixRowAdapter.html): a row adapter that hides the first columns of a row
- [ScopeAdapter](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Structs/ScopeAdapter.html): the row adapter that groups several adapters together to define scopes


## Raw SQLite Pointers

**If not all SQLite APIs are exposed in GRDB, you can still use the [SQLite C Interface](https://www.sqlite.org/c3ref/intro.html).**

The **setup** depends on the version of GRDB you are using.

If you use a [custom SQLite build](Documentation/CustomSQLiteBuilds.md) or [SQLCipher](#encryption), then the C API is available right from the GRDB module:

```swift
// Just enough for SQLCipher and custom SQLite builds:
import GRDBCipher // or import GRDBCustomSQLite

let sqliteVersion = String(cString: sqlite3_libversion())
```

Otherwise (the regular case):

1. Link your application with the SQLite library that ships with your SDK: add `libsqlite3.tbd` to the **Linked Frameworks and Libraries** of the **General**  tab of your target.

2. Import the SQLite module in the file that uses the SQLite C Interface. That module, unfortunately, changes name depending on your platform:
    
    ```swift
    // Necessary unless you use a custom SQLite build, or SQLCipher:
    import GRDB
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
    
    let sqliteVersion = String(cString: sqlite3_libversion())
    ```

The `Database.sqliteConnection` and `Statement.sqliteStatement` properties provide the raw pointers that are suitable for the [SQLite C functions](https://www.sqlite.org/c3ref/funclist.html):

```swift
try dbQueue.inDatabase { db in
    // The raw pointer to a database connection:
    let sqliteConnection = db.sqliteConnection

    // The raw pointer to a statement:
    let statement = try db.makeSelectStatement("SELECT ...")
    let sqliteStatement = statement.sqliteStatement
}
```

> :point_up: **Notes**
>
> - Those pointers are owned by GRDB: don't close connections or finalize statements created by GRDB.
> - SQLite connections are opened in the "[multi-thread mode](https://www.sqlite.org/threadsafe.html)", which (oddly) means that **they are not thread-safe**. Make sure you touch raw databases and statements inside their dedicated dispatch queues.
> - Use the raw SQLite C Interface at your own risk. GRDB won't prevent you from shooting yourself in the foot.

Before jumping in the low-level wagon, here is the list of all SQLite APIs used by GRDB:

- `sqlite3_backup_finish`, `sqlite3_backup_init`, `sqlite3_backup_step`: see [Backup](#backup)
- `sqlite3_bind_blob`, `sqlite3_bind_double`, `sqlite3_bind_int64`, `sqlite3_bind_null`, `sqlite3_bind_parameter_count`, `sqlite3_bind_parameter_name`, `sqlite3_bind_text`, `sqlite3_clear_bindings`, `sqlite3_column_blob`, `sqlite3_column_bytes`, `sqlite3_column_count`, `sqlite3_column_double`, `sqlite3_column_int64`, `sqlite3_column_name`, `sqlite3_column_text`, `sqlite3_column_type`, `sqlite3_exec`, `sqlite3_finalize`, `sqlite3_prepare_v2`, `sqlite3_reset`, `sqlite3_step`: see [Executing Updates](#executing-updates), [Fetch Queries](#fetch-queries), [Prepared Statements](#prepared-statements), [Values](#values)
- `sqlite3_busy_handler`, `sqlite3_busy_timeout`: see [Configuration.busyMode](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Structs/Configuration.html)
- `sqlite3_changes`, `sqlite3_total_changes`: see [Database.changesCount and Database.totalChangesCount](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Classes/Database.html)
- `sqlite3_close`, `sqlite3_close_v2`, `sqlite3_next_stmt`, `sqlite3_open_v2`: see [Database Connections](#database-connections)
- `sqlite3_commit_hook`, `sqlite3_rollback_hook`, `sqlite3_update_hook`: see [Database Changes Observation](#database-changes-observation), [FetchedRecordsController](#fetchedrecordscontroller)
- `sqlite3_create_collation_v2`: see [String Comparison](#string-comparison)
- `sqlite3_create_function_v2`, `sqlite3_result_blob`, `sqlite3_result_double`, `sqlite3_result_error`, `sqlite3_result_error_code`, `sqlite3_result_int64`, `sqlite3_result_null`, `sqlite3_result_text`, `sqlite3_user_data`, `sqlite3_value_blob`, `sqlite3_value_bytes`, `sqlite3_value_double`, `sqlite3_value_int64`, `sqlite3_value_text`, `sqlite3_value_type`: see [Custom SQL Functions](#custom-sql-functions)
- `sqlite3_db_release_memory`: see [Memory Management](#memory-management)
- `sqlite3_errcode`, `sqlite3_errmsg`: see [Error Handling](#error-handling)
- `sqlite3_key`, `sqlite3_rekey`: see [Encryption](#encryption)
- `sqlite3_last_insert_rowid`: see [Executing Updates](#executing-updates)
- `sqlite3_preupdate_count`, `sqlite3_preupdate_depth`, `sqlite3_preupdate_hook`, `sqlite3_preupdate_new`, `sqlite3_preupdate_old`: see [Support for SQLite Pre-Update Hooks](#support-for-sqlite-pre-update-hooks)
- `sqlite3_set_authorizer`: **reserved by GRDB**
- `sqlite3_sql`: see [Statement.sql](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Classes/Statement.html)
- `sqlite3_trace`: see [Configuration.trace](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Structs/Configuration.html)
- `sqlite3_wal_checkpoint_v2`: see [DatabasePool.checkpoint](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Classes/DatabasePool.html)


Records
=======

**On top of the [SQLite API](#sqlite-api), GRDB provides protocols and a class** that help manipulating database rows as regular objects named "records":

```swift
if let poi = try PointOfInterest.fetchOne(db, key: 1) {
    poi.isFavorite = true
    try poi.update(db)
}
```

Your custom structs and classes can adopt each protocol individually, and opt in to focused sets of features. Or you can subclass the `Record` class, and get the full toolkit in one go: fetching methods, persistence methods, and changes tracking.

> :point_up: **Note**: if you are familiar with Core Data's NSManagedObject or Realm's Object, you may experience a cultural shock: GRDB records are not uniqued, and do not auto-update. This is both a purpose, and a consequence of protocol-oriented programming. You should read [How to build an iOS application with SQLite and GRDB.swift](https://medium.com/@gwendal.roue/how-to-build-an-ios-application-with-sqlite-and-grdb-swift-d023a06c29b3) for a general introduction.

**Overview**

- [Inserting Records](#inserting-records)
- [Fetching Records](#fetching-records)
- [Updating Records](#updating-records)
- [Deleting Records](#deleting-records)
- [Counting Records](#counting-records)

**Protocols and the Record class**

- [RowConvertible Protocol](#rowconvertible-protocol)
- [TableMapping Protocol](#tablemapping-protocol)
- [Persistable Protocol](#persistable-protocol)
    - [Persistence Methods](#persistence-methods)
    - [Customizing the Persistence Methods](#customizing-the-persistence-methods)
    - [Conflict Resolution](#conflict-resolution)
- [Record Class](#record-class)
    - [Changes Tracking](#changes-tracking)
- [The Implicit RowID Primary Key](#the-implicit-rowid-primary-key)
- **[List of Record Methods](#list-of-record-methods)**


### Inserting Records

To insert a record in the database, subclass the [Record](#record-class) class or adopt the [Persistable](#persistable-protocol) protocol, and call the `insert` method:

```swift
class Person : Record { ... }

let person = Person(name: "Arthur", email: "arthur@example.com")
try person.insert(db)
```

Of course, you need to open a [database connection](#database-connections), and [create a database table](#database-schema) first.


### Fetching Records

[Record](#record-class) subclasses and types that adopt the [RowConvertible](#rowconvertible-protocol) protocol can be fetched from the database:

```swift
class Person : Record { ... }
let persons = try Person.fetchAll(db, "SELECT ...", arguments: ...) // [Person]
```

Add the [TableMapping](#tablemapping-protocol) protocol and you can stop writing SQL:

```swift
let persons = try Person.filter(emailColumn != nil).order(nameColumn).fetchAll(db) // [Person]
let person = try Person.fetchOne(db, key: 1)                                       // Person?
let person = try Person.fetchOne(db, key: ["email": "arthur@example.com"])         // Person?
let countries = try Country.fetchAll(db, keys: ["FR", "US"])                       // [Country]
```

See [fetching methods](#fetching-methods), and the [query interface](#the-query-interface).


### Updating Records

[Record](#record-class) subclasses and types that adopt the [Persistable](#persistable-protocol) protocol can be updated in the database:

```swift
let person = try Person.fetchOne(db, key: 1)!
person.name = "Arthur"
try person.update(db)
```

[Record](#record-class) subclasses track changes, so that you can avoid useless updates:

```swift
let person = try Person.fetchOne(db, key: 1)!
person.name = "Arthur"
if person.hasPersistentChangedValues {
    try person.update(db)
}
```

For batch updates, execute an [SQL query](#executing-updates):

```swift
try db.execute("UPDATE persons SET synchronized = 1")
```


### Deleting Records

[Record](#record-class) subclasses and types that adopt the [Persistable](#persistable-protocol) protocol can be deleted from the database:

```swift
let person = try Person.fetchOne(db, key: 1)!
try person.delete(db)
```

The [TableMapping](#tablemapping-protocol) protocol gives you methods that delete according to primary key or any unique index:

```swift
try Person.deleteOne(db, key: 1)
try Person.deleteOne(db, key: ["email": "arthur@example.com"])
try Country.deleteAll(db, keys: ["FR", "US"])
```

For batch deletes, see the [query interface](#the-query-interface):

```swift
try Person.filter(emailColumn == nil).deleteAll(db)
```


### Counting Records

[Record](#record-class) subclasses and types that adopt the [TableMapping](#tablemapping-protocol) protocol can be counted:

```swift
let personWithEmailCount = try Person.filter(emailColumn != nil).fetchCount(db)  // Int
```


You can now jump to:

- [RowConvertible Protocol](#rowconvertible-protocol)
- [TableMapping Protocol](#tablemapping-protocol)
- [Persistable Protocol](#persistable-protocol)
- [Record Class](#record-class)
- [The Query Interface](#the-query-interface)


## RowConvertible Protocol

**The RowConvertible protocol grants fetching methods to any type** that can be built from a database row:

```swift
public protocol RowConvertible {
    /// Row initializer
    init(row: Row)
    
    /// Optional method which gives adopting types an opportunity to complete
    /// their initialization after being fetched. Do not call it directly.
    mutating func awakeFromFetch(row: Row)
}
```

**To use RowConvertible**, subclass the [Record](#record-class) class, or adopt it explicitely. For example:

```swift
struct PointOfInterest {
    var id: Int64?
    var title: String
    var coordinate: CLLocationCoordinate2D
}

extension PointOfInterest : RowConvertible {
    init(row: Row) {
        id = row.value(named: "id")
        title = row.value(named: "title")
        coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),
            row.value(named: "longitude"))
    }
}
```

See [column values](#column-values) for more information about the `row.value()` method.

> :point_up: **Note**: for performance reasons, the same row argument to `init(row:)` is reused during the iteration of a fetch query. If you want to keep the row for later use, make sure to store a copy: `self.row = row.copy()`.

RowConvertible allows adopting types to be fetched from SQL queries:

```swift
try PointOfInterest.fetchCursor(db, "SELECT ...", arguments:...) // DatabaseCursor<PointOfInterest>
try PointOfInterest.fetchAll(db, "SELECT ...", arguments:...)    // [PointOfInterest]
try PointOfInterest.fetchOne(db, "SELECT ...", arguments:...)    // PointOfInterest?
```

See [fetching methods](#fetching-methods) for information about the `fetchCursor`, `fetchAll` and `fetchOne` methods. See [fetching rows](#fetching-rows) for more information about the query arguments.


### RowConvertible and Row Adapters

RowConvertible types usually consume rows by column name:

```swift
extension PointOfInterest : RowConvertible {
    init(row: Row) {
        id = row.value(named: "id")              // "id"
        title = row.value(named: "title")        // "title"
        coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),        // "latitude"
            row.value(named: "longitude"))       // "longitude"
    }
}
```

Occasionnally, you'll want to write a complex SQL query that uses different column names. In this case, [row adapters](#row-adapters) are there to help you mapping raw column names to the names expected by your RowConvertible types.


## TableMapping Protocol

**Adopt the TableMapping protocol** on top of [RowConvertible](#rowconvertible-protocol), and you are granted with the full [query interface](#the-query-interface).

```swift
public protocol TableMapping {
    static var databaseTableName: String { get }
    static var selectsRowID: Bool { get }
}
```

The `databaseTableName` type property is the name of a database table. `selectsRowID` is optional, and documented in the [The Implicit RowID Primary Key](#the-implicit-rowid-primary-key) chapter.

**To use TableMapping**, subclass the [Record](#record-class) class, or adopt it explicitely. For example:

```swift
extension PointOfInterest : TableMapping {
    static let databaseTableName = "pointOfInterests"
}
```

Adopting types can be fetched without SQL, using the [query interface](#the-query-interface):

```swift
let paris = try PointOfInterest.filter(nameColumn == "Paris").fetchOne(db)
```

TableMapping can also fetch and delete records by primary key:

```swift
// Fetch
try Person.fetchOne(db, key: 1)              // Person?
try Person.fetchAll(db, keys: [1, 2, 3])     // [Person]

try Country.fetchOne(db, key: "FR")          // Country?
try Country.fetchAll(db, keys: ["FR", "US"]) // [Country]

// Delete
try Person.deleteOne(db, key: 1)
try Country.deleteAll(db, keys: ["FR", "US"])
```

When the table has no explicit primary key, GRDB uses the [hidden "rowid" column](#the-implicit-rowid-primary-key):

```swift
// SELECT * FROM documents WHERE rowid = 1
try Document.fetchOne(db, key: 1)            // Document?

// DELETE FROM documents WHERE rowid = 1
try Document.deleteOne(db, key: 1)
```

For multiple-column primary keys and unique keys defined by unique indexes, provide a dictionary:

```swift
// SELECT * FROM citizenships WHERE personID = 1 AND countryISOCode = 'FR'
try Citizenship.fetchOne(db, key: ["personID": 1, "countryISOCode": "FR"]) // Citizenship?

// DELETE FROM persons WHERE email = 'arthur@example.com'
try Person.deleteOne(db, key: ["email": "arthur@example.com"])
```


## Persistable Protocol

**GRDB provides two protocols that let adopting types store themselves in the database:**

```swift
public protocol MutablePersistable : TableMapping {
    /// The name of the database table (from TableMapping)
    static var databaseTableName: String { get }
    
    /// The values persisted in the database
    var persistentDictionary: [String: DatabaseValueConvertible?] { get }
    
    /// Optional method that lets your adopting type store its rowID upon
    /// successful insertion. Don't call it directly: it is called for you.
    mutating func didInsert(with rowID: Int64, for column: String?)
}
```

```swift
public protocol Persistable : MutablePersistable {
    /// Non-mutating version of the optional didInsert(with:for:)
    func didInsert(with rowID: Int64, for column: String?)
}
```

Yes, two protocols instead of one. Both grant exactly the same advantages. Here is how you pick one or the other:

- *If your type is a struct that mutates on insertion*, choose `MutablePersistable`.
    
    For example, your table has an INTEGER PRIMARY KEY and you want to store the inserted id on successful insertion. Or your table has a UUID primary key, and you want to automatically generate one on insertion.

- Otherwise, stick with `Persistable`. Particularly if your type is a class.

The `persistentDictionary` property returns a dictionary whose keys are column names, and values any DatabaseValueConvertible value (Bool, Int, String, Date, Swift enums, etc.) See [Values](#values) for more information.

The optional `didInsert` method lets the adopting type store its rowID after successful insertion. If your table has an INTEGER PRIMARY KEY column, you are likely to define this method. Otherwise, you can safely ignore it. It is called from a protected dispatch queue, and serialized with all database updates.

**To use those protocols**, subclass the [Record](#record-class) class, or adopt one of them explicitely. For example:

```swift
extension PointOfInterest : MutablePersistable {
    
    /// The values persisted in the database
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "title": title,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude]
    }
    
    // Update id upon successful insertion:
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

var paris = PointOfInterest(
    id: nil,
    title: "Paris",
    coordinate: CLLocationCoordinate2DMake(48.8534100, 2.3488000))

try paris.insert(db)
paris.id   // some value
```


### Persistence Methods

[Record](#record-class) subclasses and types that adopt [Persistable](#persistable-protocol) are given default implementations for methods that insert, update, and delete:

```swift
try pointOfInterest.insert(db)               // INSERT
try pointOfInterest.update(db)               // UPDATE
try pointOfInterest.update(db, columns: ...) // UPDATE
try pointOfInterest.save(db)                 // Inserts or updates
try pointOfInterest.delete(db)               // DELETE
pointOfInterest.exists(db)                   // Bool
```

- `insert`, `update`, `save` and `delete` can throw a [DatabaseError](#error-handling) whenever an SQLite integrity check fails.

- `update` can also throw a PersistenceError of type recordNotFound, should the update fail because there is no matching row in the database.
    
    When saving an object that may or may not already exist in the database, prefer the `save` method:

- `save` makes sure your values are stored in the database.

    It performs an UPDATE if the record has a non-null primary key, and then, if no row was modified, an INSERT. It directly perfoms an INSERT if the record has no primary key, or a null primary key.
    
    Despite the fact that it may execute two SQL statements, `save` behaves as an atomic operation: GRDB won't allow any concurrent thread to sneak in (see [concurrency](#concurrency)).

- `delete` returns whether a database row was deleted or not.

**All primary keys are supported**, including composite primary keys that span several columns, and the [implicit rowid primary key](#the-implicit-rowid-primary-key).


### Customizing the Persistence Methods

Your custom type may want to perform extra work when the persistence methods are invoked.

For example, it may want to have its UUID automatically set before inserting. Or it may want to validate its values before saving.

When you subclass [Record](#record-class), you simply have to override the customized method, and call `super`:

```swift
class Person : Record {
    var uuid: UUID?
    
    override func insert(_ db: Database) throws {
        if uuid == nil {
            uuid = UUID()
        }
        try super.insert(db)
    }
}
```

If you use the raw [Persistable](#persistable-protocol) protocol, use one of the *special methods* `performInsert`, `performUpdate`, `performSave`, `performDelete`, or `performExists`:

```swift
struct Link : Persistable {
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

> :point_up: **Note**: the special methods `performInsert`, `performUpdate`, etc. are reserved for your custom implementations. Do not use them elsewhere. Do not provide another implementation for those methods.
>
> :point_up: **Note**: it is recommended that you do not implement your own version of the `save` method. Its default implementation forwards the job to `update` or `insert`: these are the methods that may need customization, not `save`.


### Conflict Resolution

**Insertions and updates can create conflicts**: for example, a query may attempt to insert a duplicate row that violates a unique index.

Those conflicts normally end with an error. Yet SQLite let you alter the default behavior, and handle conflicts with specific policies. For example, the `INSERT OR REPLACE` statement handles conflicts with the "replace" policy which replaces the conflicting row instead of throwing an error.

The [five different policies](https://www.sqlite.org/lang_conflict.html) are: abort (the default), replace, rollback, fail, and ignore.

**SQLite let you specify conflict policies at two different places:**

- At the table level
    
    ```swift
    // CREATE TABLE persons (
    //     id INTEGER PRIMARY KEY,
    //     email TEXT UNIQUE ON CONFLICT REPLACE
    // )
    try db.create(table: "persons") { t in
        t.column("id", .integer).primaryKey()
        t.column("email", .text).unique(onConflict: .replace) // <--
    }
    
    // Despite the unique index on email, both inserts succeed.
    // The second insert replaces the first row:
    try db.execute("INSERT INTO persons (email) VALUES (?)", arguments: ["arthur@example.com"])
    try db.execute("INSERT INTO persons (email) VALUES (?)", arguments: ["arthur@example.com"])
    ```
    
- At the query level:
    
    ```swift
    // CREATE TABLE persons (
    //     id INTEGER PRIMARY KEY,
    //     email TEXT UNIQUE
    // )
    try db.create(table: "persons") { t in
        t.column("id", .integer).primaryKey()
        t.column("email", .text)
    }
    
    // Again, despite the unique index on email, both inserts succeed.
    try db.execute("INSERT OR REPLACE INTO persons (email) VALUES (?)", arguments: ["arthur@example.com"])
    try db.execute("INSERT OR REPLACE INTO persons (email) VALUES (?)", arguments: ["arthur@example.com"])
    ```

When you want to handle conflicts at the query level, specify a custom `persistenceConflictPolicy` in your type that adopts the MutablePersistable or Persistable protocol. It will alter the INSERT and UPDATE queries run by the `insert`, `update` and `save` [persistence methods](#persistence-methods):

```swift
public protocol MutablePersistable {
    /// The policy that handles SQLite conflicts when records are inserted
    /// or updated.
    ///
    /// This property is optional: its default value uses the ABORT policy
    /// for both insertions and updates, and has GRDB generate regular
    /// INSERT and UPDATE queries.
    static var persistenceConflictPolicy: PersistenceConflictPolicy { get }
}

struct Person : MutablePersistable {
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace)
}

// INSERT OR REPLACE INTO persons (...) VALUES (...)
try person.insert(db)
```

> :point_up: **Note**: the `ignore` policy does not play well at all with the `didInsert` method which notifies the rowID of inserted records. Choose your poison:
>
> - if you specify the `ignore` policy at the table level, don't implement the `didInsert` method: it will be called with some random id in case of failed insert.
> - if you specify the `ignore` policy at the query level, the `didInsert` method is never called.
>
> :warning: **Warning**: [`ON CONFLICT REPLACE`](https://www.sqlite.org/lang_conflict.html) may delete rows so that inserts and updates can succeed. Those deletions are not reported to [transaction observers](#database-changes-observation) (this might change in a future release of SQLite).


## Record Class

**Record** is a class that is designed to be subclassed, and provides the full GRDB Record toolkit in one go:

- Fetching methods (from the [RowConvertible](#rowconvertible-protocol) protocol)
- [Persistence methods](#persistence-methods) (from the [Persistable](#persistable-protocol) protocol)
- The [query interface](#the-query-interface) (from the [TableMapping](#tablemapping-protocol) protocol)
- [Changes tracking](#changes-tracking) (unique to the Record class)

**Record subclasses override the four core methods that define their relationship with the database:**

```swift
class Record {
    /// The table name
    class var databaseTableName: String { get }
    
    /// Initialize from a database row
    required init(row: Row)
    
    /// The values persisted in the database
    var persistentDictionary: [String: DatabaseValueConvertible?]
    
    /// Optionally update record ID after a successful insertion
    func didInsert(with rowID: Int64, for column: String?)
}
```

For example, here is a fully functional Record subclass:

```swift
class PointOfInterest : Record {
    var id: Int64?
    var title: String
    var coordinate: CLLocationCoordinate2D
    
    /// The table name
    override class var databaseTableName: String {
        return "pointOfInterests"
    }
    
    /// Initialize from a database row
    required init(row: Row) {
        id = row.value(named: "id")
        title = row.value(named: "title")
        coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),
            row.value(named: "longitude"))
        super.init(row: row)
    }
    
    /// The values persisted in the database
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "title": title,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude]
    }
    
    /// Update record ID after a successful insertion
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
```


**Insert records** (see [persistence methods](#persistence-methods)):

```swift
let poi = PointOfInterest(...)
try poi.insert(db)
```


**Fetch records** (see [RowConvertible](#rowconvertible-protocol) and the [query interface](#the-query-interface)):

```swift
// Using the query interface
let pois = try PointOfInterest.order(titleColumn).fetchAll(db)

// By key
let poi = try PointOfInterest.fetchOne(db, key: 1)

// Using SQL
let pois = try PointOfInterest.fetchAll(db, "SELECT ...", arguments: ...)
```


**Update records** (see [persistence methods](#persistence-methods)):

```swift
let poi = try PointOfInterest.fetchOne(db, key: 1)!
poi.coordinate = ...
try poi.update(db)
```


**Delete records** (see [persistence methods](#persistence-methods)):

```swift
let poi = try PointOfInterest.fetchOne(db, key: 1)!
try poi.delete(db)
```


### Changes Tracking

**The [Record](#record-class) class provides changes tracking.**

The `update()` [method](#persistence-methods) always executes an UPDATE statement. When the record has not been edited, this costly database access is generally useless.

Avoid it with the `hasPersistentChangedValues` property, which returns whether the record has changes that have not been saved:

```swift
// Saves the person if it has changes that have not been saved:
if person.hasPersistentChangedValues {
    try person.save(db)
}
```

The `hasPersistentChangedValues` flag is false after a record has been fetched or saved into the database. Subsequent modifications may set it, or not: `hasPersistentChangedValues` is based on value comparison. **Setting a property to the same value does not set the changed flag**:

```swift
let person = Person(name: "Barbara", age: 35)
person.hasPersistentChangedValues // true

try person.insert(db)
person.hasPersistentChangedValues // false

person.name = "Barbara"
person.hasPersistentChangedValues // false

person.age = 36
person.hasPersistentChangedValues // true
person.persistentChangedValues    // ["age": 35]
```

For an efficient algorithm which synchronizes the content of a database table with a JSON payload, check [JSONSynchronization.playground](Playgrounds/JSONSynchronization.playground/Contents.swift).


## The Implicit RowID Primary Key

**All SQLite tables have a primary key.** Even when the primary key is not explicit:

```swift
// No explicit primary key
try db.create(table: "events") { t in
    t.column("message", .text)
    t.column("date", .datetime)
}

// No way to define an explicit primary key
try db.create(virtualTable: "books", using: FTS4()) { t in
    t.column("title")
    t.column("author")
    t.column("body")
}
```

The implicit primary key is stored in the hidden column `rowid`. Hidden means that `SELECT *` does not select it, and yet it can be selected and queried: `SELECT *, rowid ... WHERE rowid = 1`.

Some GRDB methods will automatically use this hidden column when a table has no explicit primary key:

```swift
// SELECT * FROM events WHERE rowid = 1
let event = try Event.fetchOne(db, key: 1)

// DELETE FROM books WHERE rowid = 1
try Book.deleteOne(db, key: 1)
```


### Exposing the RowID Column

**A record type that wraps a table without any explicit primary key doesn't know about the hidden rowid column.**

Without primary key, records don't have any identity, and the [persistence method](#persistence-methods) can behave in undesired fashion: `update()` throws errors, `save()` always performs insertions and may break constraints, `exists()` is always false.

When SQLite won't let you provide an explicit primary key (as in [full-text](#full-text-search) tables, for example), you may want to make your record type fully aware of the hidden rowid column:

1. Have the `selectsRowID` static property from the [TableMapping](#tablemapping-protocol) protocol be true.
    
    ```swift
    struct Event : TableMapping {
        static let selectsRowID = true
    }
    
    // When you subclass Record, you need an override:
    class Book : Record {
        override class var selectsRowID: Bool {
            return true
        }
    }
    ```
    
    GRDB will then select the `rowid` column by default:
    
    ```swift
    // SELECT *, rowid FROM events
    let events = try Event.fetchAll(db)
    ```

2. Have `init(row:)` from the [RowConvertible](#rowconvertible-protocol) protocol consume the "rowid" column:
    
    ```swift
    struct Event : RowConvertible {
        var id: Int64?
        
        init(row: Row) {
            id = row.value(named: "rowid")
        }
    }
    ```
    
    If you prefer using the Column type from the [query interface](#the-query-interface), use the `Column.rowID` constant:
    
    ```swift
    init(row: Row) {
        id = row.value(Column.rowID)
    }
    ```
    
    Your fetched records will then know their ids:
    
    ```swift
    let event = try Event.fetchOne(db)!
    event.id // some value
    ```

3. Include the rowid in your `persistentDictionary`, and keep it in the `didInsert(with:for:)` method (both from the [Persistable and MutablePersistable](#persistable-protocol) protocols):
    
    ```swift
    struct Event : MutablePersistable {
        var id: Int64?
        
        var persistentDictionary: [String: DatabaseValueConvertible?] {
            return [
                "rowid": id,
                "message": message,
                "date": date,
            ]
        }
        
        mutating func didInsert(with rowID: Int64, for column: String?) {
            id = rowID
        }
    }
    ```
    
    You will then be able to track your record ids, update them, or check for their existence:
    
    ```swift
    let event = Event(message: "foo", date: Date())
    
    // Insertion sets the record id:
    try event.insert(db)
    event.id // some value
    
    // Record can be updated:
    event.message = "bar"
    try event.update(db)
    
    // Record knows if it exists:
    event.exists(db) // true
    ```


## List of Record Methods

This is the list of record methods, along with their required protocols. The [Record Class](#record-class) adopts all these protocols.

| Method | Protocols | Notes |
| ------ | --------- | :---: |
| **Inserting and Updating Records** | | |
| `try record.insert(db)` | [Persistable](#persistable-protocol) | |
| `try record.save(db)` | [Persistable](#persistable-protocol) | |
| `try record.update(db)` | [Persistable](#persistable-protocol) | |
| `try record.update(db, columns: ...)` | [Persistable](#persistable-protocol) | |
| **Checking Record Existence** | | |
| `record.exists(db)` | [Persistable](#persistable-protocol) | |
| **Deleting Records** | | |
| `try record.delete(db)` | [Persistable](#persistable-protocol) | |
| `try Type.deleteOne(db, key: ...)` | [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-1">¹</a> |
| `try Type.deleteAll(db)` | [TableMapping](#tablemapping-protocol) | |
| `try Type.deleteAll(db, keys: ...)` | [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-1">¹</a> |
| `try Type.filter(...).deleteAll(db)` | [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-2">²</a> |
| **Counting Records** | | |
| `Type.fetchCount(db)` | [TableMapping](#tablemapping-protocol) | |
| `Type.filter(...).fetchCount(db)` | [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-2">²</a> |
| **Fetching Record Cursors** | | |
| `Type.fetch(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | |
| `Type.fetch(db, keys: ...)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetch(db, sql)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-3">³</a> |
| `Type.fetch(statement)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-4">⁴</a> |
| `Type.filter(...).fetch(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-2">²</a> |
| **Fetching Record Arrays** | | |
| `Type.fetchAll(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | |
| `Type.fetchAll(db, keys: ...)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchAll(db, sql)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-3">³</a> |
| `Type.fetchAll(statement)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-4">⁴</a> |
| `Type.filter(...).fetchAll(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-2">²</a> |
| **Fetching Individual Records** | | |
| `Type.fetchOne(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | |
| `Type.fetchOne(db, key: ...)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchOne(db, sql)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-3">³</a> |
| `Type.fetchOne(statement)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-4">⁴</a> |
| `Type.filter(...).fetchOne(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-2">²</a> |
| **Changes Tracking** | | |
| `record.hasPersistentChangedValues` | [Record](#record-class) | |
| `record.persistentChangedValues` | [Record](#record-class) | |

<a name="list-of-record-methods-1">¹</a> All unique keys are supported: primary keys (single-column, composite, [implicit RowID](#the-implicit-rowid-primary-key)) and unique indexes:

```swift
try Person.fetchOne(db, key: 1)                               // Person?
try Person.fetchOne(db, key: ["email": "arthur@example.com"]) // Person?
try Country.fetchAll(db, keys: ["FR", "US"])                  // [Country]
```

<a name="list-of-record-methods-2">²</a> See [Fetch Requests](#requests):

```swift
let request = Person.filter(emailColumn != nil).order(nameColumn)
let persons = try request.fetchAll(db)  // [Person]
let count = try request.fetchCount(db)  // Int
```

<a name="list-of-record-methods-3">³</a> See [SQL queries](#fetch-queries):

```swift
let persons = try request.fetchAll("SELECT * FROM persons WHERE id = ?", arguments: [1])  // [Person]
```

<a name="list-of-record-methods-4">⁴</a> See [Prepared Statements](#prepared-statements):

```swift
let statement = try db.makeSelectStatement("SELECT * FROM persons WHERE id = ?")
let persons = try request.fetchAll(statement, arguments: [1])  // [Person]
```


The Query Interface
===================

**The query interface lets you write pure Swift instead of SQL:**

```swift
// Update database schema
try db.create(table: "wines") { t in ... }

// Fetch
let wines = try Wine.filter(origin == "Burgundy").order(price).fetchAll(db)

// Count
let count = try Wine.filter(color == Color.red).fetchCount(db)

// Delete
try Wine.filter(corked == true).deleteAll(db)
```

Please bear in mind that the query interface can not generate all possible SQL queries. You may also *prefer* writing SQL, and this is just OK. From little snippets to full queries, your SQL skills are welcome:

```swift
try db.execute("CREATE TABLE wines (...)")
let count = try Wine.filter(sql: "color = ?", arguments: [Color.red]).fetchCount(db)
let wines = try Wine.fetchAll(db, "SELECT * FROM wines WHERE origin = ? ORDER BY price", arguments: ["Burgundy"])
try db.execute("DELETE FROM wines WHERE corked")
```

So don't miss the [SQL API](#sqlite-api).

- [Database Schema](#database-schema)
- [Requests](#requests)
- [Expressions](#expressions)
    - [SQL Operators](#sql-operators)
    - [SQL Functions](#sql-functions)
- [Fetching from Requests](#fetching-from-requests)
- [Fetching by Key](#fetching-by-key)
- [Fetching Aggregated Values](#fetching-aggregated-values)
- [Delete Requests](#delete-requests)
- [GRDB Extension Guide](Documentation/ExtendingGRDB.md)


## Database Schema

Once granted with a [database connection](#database-connections), you can setup your database schema without writing SQL:

- [Create Tables](#create-tables)
- [Modify Tables](#modify-tables)
- [Drop Tables](#drop-tables)
- [Create Indexes](#create-indexes)


### Create Tables

```swift
// CREATE TABLE pointOfInterests (
//   id INTEGER PRIMARY KEY,
//   title TEXT,
//   favorite BOOLEAN NOT NULL DEFAULT 0,
//   latitude DOUBLE NOT NULL,
//   longitude DOUBLE NOT NULL
// )
try db.create(table: "pointOfInterests") { t in
    t.column("id", .integer).primaryKey()
    t.column("title", .text)
    t.column("favorite", .boolean).notNull().defaults(to: false)
    t.column("longitude", .double).notNull()
    t.column("latitude", .double).notNull()
}
```

The `create(table:)` method covers nearly all SQLite table creation features. For virtual tables, see [Full-Text Search](#full-text-search), or use raw SQL.

SQLite has many reference documents about table creation:

- [CREATE TABLE](https://www.sqlite.org/lang_createtable.html)
- [Datatypes In SQLite Version 3](https://www.sqlite.org/datatype3.html)
- [SQLite Foreign Key Support](https://www.sqlite.org/foreignkeys.html)
- [ON CONFLICT](https://www.sqlite.org/lang_conflict.html)
- [The WITHOUT ROWID Optimization](https://www.sqlite.org/withoutrowid.html)

**Configure table creation**:

```swift
// CREATE TABLE example ( ... )
try db.create(table: "example") { t in ... }
    
// CREATE TEMPORARY TABLE example IF NOT EXISTS (
try db.create(table: "example", temporary: true, ifNotExists: true) { t in
```

**Add regular columns** with their name and type (text, integer, double, numeric, boolean, blob, date and datetime) - see [SQLite data types](https://www.sqlite.org/datatype3.html):

```swift
    // name TEXT,
    // creationDate DATETIME,
    t.column("name", .text)
    t.column("creationDate", .datetime)
```

Define **not null** columns, and set **default** values:

```swift
    // email TEXT NOT NULL,
    t.column("email", .text).notNull()
    
    // name TEXT NOT NULL DEFAULT 'Anonymous',
    t.column("name", .text).notNull().defaults(to: "Anonymous")
```
    
Use an individual column as **primary**, **unique**, or **foreign key**. When defining a foreign key, the referenced column is the primary key of the referenced table (unless you specify otherwise):

```swift
    // id INTEGER PRIMARY KEY,
    t.column("id", .integer).primaryKey()
    
    // email TEXT UNIQUE,
    t.column("email", .text).unique()
    
    // countryCode TEXT REFERENCES countries(code) ON DELETE CASCADE,
    t.column("countryCode", .text).references("countries", onDelete: .cascade)
```

**Perform integrity checks** on individual columns, and SQLite will only let conforming rows in. In the example below, the `$0` closure variable is a column which lets you build any SQL [expression](#expressions).

```swift
    // name TEXT CHECK (LENGTH(name) > 0)
    // age INTEGER CHECK (age > 0)
    t.column("name", .text).check { length($0) > 0 }
    t.column("age", .integer).check(sql: "age > 0")
```

Other **table constraints** can involve several columns:

```swift
    // PRIMARY KEY (a, b),
    t.primaryKey(["a", "b"])
    
    // UNIQUE (a, b) ON CONFLICT REPLACE,
    t.uniqueKey(["a", "b"], onConfict: .replace)
    
    // FOREIGN KEY (a, b) REFERENCES parents(c, d),
    t.foreignKey(["a", "b"], references: "parent")
    
    // CHECK (a + b < 10),
    t.check(Column("a") + Column("b") < 10)
    
    // CHECK (a + b < 10)
    t.check(sql: "a + b < 10")
}
```

### Modify Tables

SQLite lets you rename tables, and add columns to existing tables:

```swift
// ALTER TABLE referers RENAME TO referrers
try db.rename(table: "referers", to: "referrers")

// ALTER TABLE persons ADD COLUMN url TEXT
try db.alter(table: "persons") { t in
    t.add(column: "url", .text)
}
```

> :point_up: **Note**: SQLite restricts the possible table alterations, and may require you to recreate dependent triggers or views. See the documentation of the [ALTER TABLE](https://www.sqlite.org/lang_altertable.html) for details. See [Advanced Database Schema Changes](#advanced-database-schema-changes) for a way to lift restrictions.


### Drop Tables

Drop tables with the `drop(table:)` method:

```swift
try db.drop(table: "obsolete")
```

### Create Indexes

Create indexes with the `create(index:)` method:

```swift
// CREATE UNIQUE INDEX byEmail ON users(email)
try db.create(index: "byEmail", on: "users", columns: ["email"], unique: true)
```

Relevant SQLite documentation:

- [CREATE INDEX](https://www.sqlite.org/lang_createindex.html)
- [Indexes On Expressions](https://www.sqlite.org/expridx.html)
- [Partial Indexes](https://www.sqlite.org/partialindex.html)


## Requests

**The query interface requests** let you fetch values from the database:

```swift
let request = Person.filter(emailColumn != nil).order(nameColumn)
let persons = try request.fetchAll(db)  // [Person]
let count = try request.fetchCount(db)  // Int
```

All requests start from **a type** that adopts the `TableMapping` protocol, such as a `Record` subclass (see [Records](#records)):

```swift
class Person : Record { ... }
```

Declare the table **columns** that you want to use for filtering, or sorting:

```swift
let idColumn = Column("id")
let nameColumn = Column("name")
```

You can now build requests with the following methods: `all`, `none`, `select`, `distinct`, `filter`, `matching`, `group`, `having`, `order`, `reversed`, `limit`. All those methods return another request, which you can further refine by applying another method: `Person.select(...).filter(...).order(...)`.

- `all()`, `none()`: the requests for all rows, or no row.

    ```swift
    // SELECT * FROM persons
    Person.all()
    ```
    
    The hidden `rowid` column can be selected as well [when you need it](#the-implicit-rowid-primary-key).

- `select(expression, ...)` defines the selected columns.
    
    ```swift
    // SELECT id, name FROM persons
    Person.select(idColumn, nameColumn)
    
    // SELECT MAX(age) AS maxAge FROM persons
    Person.select(max(ageColumn).aliased("maxAge"))
    ```

- `distinct()` performs uniquing.
    
    ```swift
    // SELECT DISTINCT name FROM persons
    Person.select(nameColumn).distinct()
    ```

- `filter(expression)` applies conditions.
    
    ```swift
    // SELECT * FROM persons WHERE id IN (1, 2, 3)
    Person.filter([1,2,3].contains(idColumn))
    
    // SELECT * FROM persons WHERE (name IS NOT NULL) AND (height > 1.75)
    Person.filter(nameColumn != nil && heightColumn > 1.75)
    ```

- `matching(pattern)` performs [full-text search](#full-text-search).
    
    ```swift
    // SELECT * FROM documents WHERE documents MATCH 'sqlite database'
    let pattern = FTS3Pattern(matchingAllTokensIn: "SQLite database")
    Document.matching(pattern)
    ```
    
    When the pattern is nil, no row will match.

- `group(expression, ...)` groups rows.
    
    ```swift
    // SELECT name, MAX(age) FROM persons GROUP BY name
    Person
        .select(nameColumn, max(ageColumn))
        .group(nameColumn)
    ```

- `having(expression)` applies conditions on grouped rows.
    
    ```swift
    // SELECT name, MAX(age) FROM persons GROUP BY name HAVING MIN(age) >= 18
    Person
        .select(nameColumn, max(ageColumn))
        .group(nameColumn)
        .having(min(ageColumn) >= 18)
    ```

- `order(ordering, ...)` sorts.
    
    ```swift
    // SELECT * FROM persons ORDER BY name
    Person.order(nameColumn)
    
    // SELECT * FROM persons ORDER BY score DESC, name
    Person.order(scoreColumn.desc, nameColumn)
    ```
    
    Each `order` call clears any previous ordering:
    
    ```swift
    // SELECT * FROM persons ORDER BY name
    Person.order(scoreColumn).order(nameColumn)
    ```

- `reversed()` reverses the eventual orderings.
    
    ```swift
    // SELECT * FROM persons ORDER BY score ASC, name DESC
    Person.order(scoreColumn.desc, nameColumn).reversed()
    ```
    
    If no ordering was specified, the result is ordered by rowID in reverse order.
    
    ```swift
    // SELECT * FROM persons ORDER BY _rowid_ DESC
    Person.all().reversed()
    ```

- `limit(limit, offset: offset)` limits and pages results.
    
    ```swift
    // SELECT * FROM persons LIMIT 5
    Person.limit(5)
    
    // SELECT * FROM persons LIMIT 5 OFFSET 10
    Person.limit(5, offset: 10)
    ```

You can refine requests by chaining those methods:

```swift
// SELECT * FROM persons WHERE (email IS NOT NULL) ORDER BY name
Person.order(nameColumn).filter(emailColumn != nil)
```

The `select`, `order`, `group`, and `limit` methods ignore and replace previously applied selection, orderings, grouping, and limits. On the opposite, `filter`, `matching`, and `having` methods extend the query:

```swift
Person                          // SELECT * FROM persons
    .filter(nameColumn != nil)  // WHERE (name IS NOT NULL)
    .filter(emailColumn != nil) //        AND (email IS NOT NULL)
    .order(nameColumn)          // - ignored -
    .order(ageColumn)           // ORDER BY age
    .limit(20, offset: 40)      // - ignored -
    .limit(10)                  // LIMIT 10
```


Raw SQL snippets are also accepted, with eventual arguments:

```swift
// SELECT DATE(creationDate), COUNT(*) FROM persons WHERE name = 'Arthur' GROUP BY date(creationDate)
Person
    .select(sql: "DATE(creationDate), COUNT(*)")
    .filter(sql: "name = ?", arguments: ["Arthur"])
    .group(sql: "DATE(creationDate)")
```


## Expressions

Feed [requests](#requests) with SQL expressions built from your Swift code:


### SQL Operators

- `=`, `<>`, `<`, `<=`, `>`, `>=`, `IS`, `IS NOT`
    
    Comparison operators are based on the Swift operators `==`, `!=`, `===`, `!==`, `<`, `<=`, `>`, `>=`:
    
    ```swift
    // SELECT * FROM persons WHERE (name = 'Arthur')
    Person.filter(nameColumn == "Arthur")
    
    // SELECT * FROM persons WHERE (name IS NULL)
    Person.filter(nameColumn == nil)
    
    // SELECT * FROM persons WHERE (age === 18)
    Person.filter(ageColumn === 18)
    
    // SELECT * FROM rectangles WHERE width < height
    Rectangle.filter(widthColumn < heightColumn)
    ```
    
    > :point_up: **Note**: SQLite string comparison, by default, is case-sensitive and not Unicode-aware. See [string comparison](#string-comparison) if you need more control.

- `*`, `/`, `+`, `-`
    
    SQLite arithmetic operators are derived from their Swift equivalent:
    
    ```swift
    // SELECT ((temperature * 1.8) + 32) AS farenheit FROM persons
    Planet.select((temperatureColumn * 1.8 + 32).aliased("farenheit"))
    ```
    
    > :point_up: **Note**: an expression like `nameColumn + "rrr"` will be interpreted by SQLite as a numerical addition (with funny results), not as a string concatenation.

- `AND`, `OR`, `NOT`
    
    The SQL logical operators are derived from the Swift `&&`, `||` and `!`:
    
    ```swift
    // SELECT * FROM persons WHERE ((NOT verified) OR (age < 18))
    Person.filter(!verifiedColumn || ageColumn < 18)
    ```

- `BETWEEN`, `IN`, `IN (subquery)`, `NOT IN`, `NOT IN (subquery)`
    
    To check inclusion in a collection, call the `contains` method on any Swift sequence:
    
    ```swift
    // SELECT * FROM persons WHERE id IN (1, 2, 3)
    Person.filter([1, 2, 3].contains(idColumn))
    
    // SELECT * FROM persons WHERE id NOT IN (1, 2, 3)
    Person.filter(![1, 2, 3].contains(idColumn))
    
    // SELECT * FROM persons WHERE age BETWEEN 0 AND 17
    Person.filter((0...17).contains(ageColumn))
    
    // SELECT * FROM persons WHERE (age >= 0) AND (age < 18)
    Person.filter((0..<18).contains(ageColumn))
    
    // SELECT * FROM persons WHERE name BETWEEN 'A' AND 'z'
    Person.filter(("A"..."z").contains(nameColumn))
    
    // SELECT * FROM persons WHERE (name >= 'A') AND (name < 'z')
    Person.filter(("A"..<"z").contains(nameColumn))
    ```
    
    > :point_up: **Note**: SQLite string comparison, by default, is case-sensitive and not Unicode-aware. See [string comparison](#string-comparison) if you need more control.
    
    To check inclusion in a subquery, call the `contains` method on another request:
    
    ```swift
    // SELECT * FROM events
    //  WHERE userId IN (SELECT id FROM persons WHERE verified)
    let verifiedUserIds = User.select(idColumn).filter(verifiedColumn)
    Event.filter(verifiedUserIds.contains(userIdColumn))
    ```

- `EXISTS (subquery)`, `NOT EXISTS (subquery)`

    To check is a subquery would return any row, use the `exists` property on another request:
    
    ```swift
    // SELECT * FROM persons
    // WHERE EXISTS (SELECT * FROM books
    //                WHERE books.ownerId = persons.id)
    Person.filter(Book.filter(sql: "books.ownerId = persons.id").exists)
    ```

- `LIKE`
    
    The SQLite LIKE operator is available as the `like` method:
    
    ```swift
    // SELECT * FROM persons WHERE (email LIKE '%@example.com')
    Person.filter(emailColumn.like("%@example.com"))
    ```
    
    > :point_up: **Note**: the SQLite LIKE operator is case-unsensitive but not Unicode-aware. For example, the expression `'a' LIKE 'A'` is true but `'æ' LIKE 'Æ'` is false.

- `MATCH`
    
    The full-text MATCH operator is available through [FTS3Pattern](#fts3pattern) (for FTS3 and FTS4 tables) and [FTS5Pattern](#fts5pattern) (for FTS5):
    
    FTS3 and FTS4:
    
    ```swift
    let pattern = FTS3Pattern(matchingAllTokensIn: "SQLite database")
    
    // SELECT * FROM documents WHERE documents MATCH 'sqlite database'
    Document.matching(pattern)
    
    // SELECT * FROM documents WHERE content MATCH 'sqlite database'
    Document.filter(contentColumn.match(pattern))
    ```
    
    FTS5:
    
    ```swift
    let pattern = FTS5Pattern(matchingAllTokensIn: "SQLite database")
    
    // SELECT * FROM documents WHERE documents MATCH 'sqlite database'
    Document.matching(pattern)
    ```


### SQL Functions

- `ABS`, `AVG`, `COUNT`, `LENGTH`, `MAX`, `MIN`, `SUM`:
    
    Those are based on the `abs`, `average`, `count`, `length`, `max`, `min` and `sum` Swift functions:
    
    ```swift
    // SELECT MIN(age), MAX(age) FROM persons
    Person.select(min(ageColumn), max(ageColumn))
    
    // SELECT COUNT(name) FROM persons
    Person.select(count(nameColumn))
    
    // SELECT COUNT(DISTINCT name) FROM persons
    Person.select(count(distinct: nameColumn))
    ```

- `IFNULL`
    
    Use the Swift `??` operator:
    
    ```swift
    // SELECT IFNULL(name, 'Anonymous') FROM persons
    Person.select(nameColumn ?? "Anonymous")
    
    // SELECT IFNULL(name, email) FROM persons
    Person.select(nameColumn ?? emailColumn)
    ```

- `LOWER`, `UPPER`
    
    The query interface does not give access to those SQLite functions. Nothing against them, but they are not unicode aware.
    
    Instead, GRDB extends SQLite with SQL functions that call the Swift built-in string functions `capitalized`, `lowercased`, `uppercased`, `localizedCapitalized`, `localizedLowercased` and `localizedUppercased`:
    
    ```swift
    Person.select(nameColumn.uppercased())
    ```
    
    > :point_up: **Note**: When *comparing* strings, you'd rather use a [collation](#string-comparison):
    >
    > ```swift
    > let name: String = ...
    >
    > // Not recommended
    > nameColumn.uppercased() == name.uppercased()
    >
    > // Better
    > nameColumn.collating(.caseInsensitiveCompare) == name
    > ```

- Custom SQL functions
    
    You can apply your own [custom SQL functions](#custom-sql-functions):
    
    ```swift
    let f = DatabaseFunction("f", ...)
    
    // SELECT f(name) FROM persons
    Person.select(f.apply(nameColumn))
    ```

    
## Fetching from Requests

Once you have a request, you can fetch the records at the origin of the request:

```swift
// Some request based on `Person`
let request = Person.filter(...)... // QueryInterfaceRequest<Person>

// Fetch persons:
try request.fetchCursor(db) // DatabaseCursor<Person>
try request.fetchAll(db)    // [Person]
try request.fetchOne(db)    // Person?
```

See [fetching methods](#fetching-methods) for information about the `fetchCursor`, `fetchAll` and `fetchOne` methods.

For example:

```swift
let allPersons = try Person.fetchAll(db)                            // [Person]
let arthur = try Person.filter(nameColumn == "Arthur").fetchOne(db) // Person?
```


**When the selected columns don't fit the source type**, change your target: any other type that adopts the [RowConvertible](#rowconvertible-protocol) protocol, plain [database rows](#fetching-rows), and even [values](#values):

```swift
let request = Person.select(min(heightColumn))
let minHeight = try Double.fetchOne(db, request) // Double?

let request = Person.select(min(heightColumn), max(heightColumn))
let row = try Row.fetchOne(db, request)!
let minHeight: Double? = row.value(atIndex: 0)
let maxHeight: Double? = row.value(atIndex: 1)
```


## Fetching By Key

**Fetching records according to their primary key** is a very common task. It has a shortcut which accepts any single-column primary key:

```swift
// SELECT * FROM persons WHERE id = 1
try Person.fetchOne(db, key: 1)              // Person?

// SELECT * FROM persons WHERE id IN (1, 2, 3)
try Person.fetchAll(db, keys: [1, 2, 3])     // [Person]

// SELECT * FROM persons WHERE isoCode = 'FR'
try Country.fetchOne(db, key: "FR")          // Country?

// SELECT * FROM countries WHERE isoCode IN ('FR', 'US')
try Country.fetchAll(db, keys: ["FR", "US"]) // [Country]
```

When the table has no explicit primary key, GRDB uses the [hidden "rowid" column](#the-implicit-rowid-primary-key):

```swift
// SELECT * FROM documents WHERE rowid = 1
try Document.fetchOne(db, key: 1)            // Document?
```

For multiple-column primary keys and unique keys defined by unique indexes, provide a dictionary:

```swift
// SELECT * FROM citizenships WHERE personID = 1 AND countryISOCode = 'FR'
try Citizenship.fetchOne(db, key: ["personID": 1, "countryISOCode": "FR"]) // Citizenship?

// SELECT * FROM persons WHERE email = 'arthur@example.com'
try Person.fetchOne(db, key: ["email": "arthur@example.com"])              // Person?
```


## Fetching Aggregated Values

**Requests can count.** The `fetchCount()` method returns the number of rows that would be returned by a fetch request:

```swift
// SELECT COUNT(*) FROM persons
let count = try Person.fetchCount(db) // Int

// SELECT COUNT(*) FROM persons WHERE email IS NOT NULL
let count = try Person.filter(emailColumn != nil).fetchCount(db)

// SELECT COUNT(DISTINCT name) FROM persons
let count = try Person.select(nameColumn).distinct().fetchCount(db)

// SELECT COUNT(*) FROM (SELECT DISTINCT name, age FROM persons)
let count = try Person.select(nameColumn, ageColumn).distinct().fetchCount(db)
```


**Other aggregated values** can also be selected and fetched (see [SQL Functions](#sql-functions)):

```swift
let request = Person.select(min(heightColumn))
let minHeight = try Double.fetchOne(db, request) // Double?

let request = Person.select(min(heightColumn), max(heightColumn))
let row = try Row.fetchOne(db, request)!
let minHeight: Double? = row.value(atIndex: 0)
let maxHeight: Double? = row.value(atIndex: 1)
```


## Delete Requests

**Requests can delete records**, with the `deleteAll()` method:

```swift
// DELETE FROM persons WHERE email IS NULL
let request = Person.filter(emailColumn == nil)
try request.deleteAll(db)
```

**Deleting records according to their primary key** is also quite common. It has a shortcut which accepts any single-column primary key:

```swift
// DELETE FROM persons WHERE id = 1
try Person.deleteOne(db, key: 1)

// DELETE FROM persons WHERE id IN (1, 2, 3)
try Person.deleteAll(db, keys: [1, 2, 3])

// DELETE FROM persons WHERE isoCode = 'FR'
try Country.deleteOne(db, key: "FR")

// DELETE FROM countries WHERE isoCode IN ('FR', 'US')
try Country.deleteAll(db, keys: ["FR", "US"])
```

When the table has no explicit primary key, GRDB uses the [hidden "rowid" column](#the-implicit-rowid-primary-key):

```swift
// DELETE FROM documents WHERE rowid = 1
try Document.deleteOne(db, key: 1)
```

For multiple-column primary keys and unique keys defined by unique indexes, provide a dictionary:

```swift
// DELETE FROM citizenships WHERE personID = 1 AND countryISOCode = 'FR'
try Citizenship.deleteOne(db, key: ["personID": 1, "countryISOCode": "FR"])

// DELETE FROM persons WHERE email = 'arthur@example.com'
Person.deleteOne(db, key: ["email": "arthur@example.com"])
```



Application Tools
=================

On top of the APIs described above, GRDB provides a toolkit for applications. While none of those are mandatory, all of them help dealing with the database:

- [Migrations](#migrations): Transform your database as your application evolves.
- [Full-Text Search](#full-text-search): Perform efficient and customizable full-text searches.
- [Database Changes Observation](#database-changes-observation): Perform post-commit and post-rollback actions.
- [FetchedRecordsController](#fetchedrecordscontroller): Automatic database changes tracking, plus UITableView animations.
- [Encryption](#encryption): Encrypt your database with SQLCipher.
- [Backup](#backup): Dump the content of a database to another.


## Migrations

**Migrations** are a convenient way to alter your database schema over time in a consistent and easy way.

Migrations run in order, once and only once. When a user upgrades your application, only non-applied migrations are run.

Inside each migration, you typically [define and update your database tables](#database-schema) according to your evolving application needs:

```swift
var migrator = DatabaseMigrator()

// v1 database
migrator.registerMigration("v1") { db in
    try db.create(table: "persons") { t in ... }
    try db.create(table: "books") { t in ... }
    try db.create(index: ...)
}

// v2 database
migrator.registerMigration("v2") { db in
    try db.alter(table: "persons") { t in ... }
}

// Migrations for future versions will be inserted here:
//
// // v3 database
// migrator.registerMigration("v3") { db in
//     ...
// }

try migrator.migrate(dbQueue) // or migrator.migrate(dbPool)
```

**Each migration runs in a separate transaction.** Should one throw an error, its transaction is rollbacked, subsequent migrations do not run, and the error is eventually thrown by `migrator.migrate(dbQueue)`.

**The memory of applied migrations is stored in the database itself** (in a reserved table).


### Advanced Database Schema Changes

SQLite does not support many schema changes, and won't let you drop a table column with "ALTER TABLE ... DROP COLUMN ...", for example.

Yet any kind of schema change is still possible. The SQLite documentation explains in detail how to do so: https://www.sqlite.org/lang_altertable.html#otheralter. This technique requires the temporary disabling of foreign key checks, and is supported by the `registerMigrationWithDisabledForeignKeyChecks` function:

```swift
// Add a NOT NULL constraint on persons.name:
migrator.registerMigrationWithDisabledForeignKeyChecks("AddNotNullCheckOnName") { db in
    try db.create(table: "new_persons") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text).notNull()
    }
    try db.execute("INSERT INTO new_persons SELECT * FROM persons")
    try db.drop(table: "persons")
    try db.rename(table: "new_persons", to: "persons")
}
```

While your migration code runs with disabled foreign key checks, those are re-enabled and checked at the end of the migration, regardless of eventual errors.


## Full-Text Search

**Full-Text Search is an efficient way to search a corpus of textual documents.**

```swift
// Create full-text tables
try db.create(virtualTable: "books", using: FTS4()) { t in // or FTS3(), or FTS5()
    t.column("author")
    t.column("title")
    t.column("body")
}

// Populate full-text table with records or SQL
try Book(...).insert(db)
try db.execute(
    "INSERT INTO books (author, title, body) VALUES (?, ?, ?)",
    arguments: [...])

// Build search patterns
let pattern = FTS3Pattern(matchingPhrase: "Moby-Dick")

// Search with the query interface or SQL
let books = try Book.matching(pattern).fetchAll(db)
let books = try Book.fetchAll(db,
    "SELECT * FROM books WHERE books MATCH ?",
    arguments: [pattern])
```

- **[Choosing the Full-Text Engine](#choosing-the-full-text-engine)**
- **Create Full-Text Virtual Tables**: [FTS3/4](#create-fts3-and-fts4-virtual-tables), [FTS5](#create-fts5-virtual-tables)
- **Choosing a Tokenizer**: [FTS3/4](#fts3-and-fts4-tokenizers), [FTS5](#fts5-tokenizers)
- **Search Patterns**: [FTS3/4](#fts3pattern), [FTS5](#fts5pattern)
- **Sorting by Relevance**: [FTS5](#fts5-sorting-by-relevance)
- **External Content Full-Text Tables**: [FTS4/5](#external-content-full-text-tables)
- **Full-Text Record**s: [FTS3/4/5](#full-text-records)
- **Unicode Full-Text Gotchas**: [FTS3/4/5](#unicode-full-text-gotchas). Unicorns don't exist.
- **Custom Tokenizers**: [FTS5](Documentation/FTS5Tokenizers.md). Leverage extra full-text features such as synonyms or stop words. Avoid [unicode gotchas](#unicode-full-text-gotchas).
- **Sample Code**: [WWDC Companion](https://github.com/groue/WWDCCompanion), an iOS app that stores, displays, and lets the user search the WWDC 2016 sessions.



### Choosing the Full-Text Engine

**SQLite supports three full-text engines: [FTS3, FTS4](https://www.sqlite.org/fts3.html) and [FTS5](https://www.sqlite.org/fts5.html).**

Generally speaking, FTS5 is better than FTS4 which improves on FTS3. But this does not really tell which engine to choose for your application. Instead, make your choice depend on:

- **The full-text features needed by the application**:
    
    | Full-Text Needs                                                            | FTS3 | FTS4 | FTS5 |
    | -------------------------------------------------------------------------- | :--: | :--: | :--: |
    | :question: Queries                                                         |      |      |      |
    | **Words searches** (documents that contain "database")                     |  X   |  X   |  X   |
    | **Prefix searches** (documents that contain a word starting with "data")   |  X   |  X   |  X   |
    | **Phrases searches** (documents that contain the phrase "SQLite database") |  X   |  X   |  X   |
    | **Boolean searches** (documents that contain "SQLite" or "database")       |  X   |  X   |  X   |
    | **Proximity search** (documents that contain "SQLite" near "database")     |  X   |  X   |  X   |
    | :scissors: Tokenization                                                    |      |      |      |
    | **Ascii case insensitivity** (have "DATABASE" match "database")            |  X   |  X   |  X   |
    | **Unicode case insensitivity** (have "ÉLÉGANCE" match "élégance")          |  X   |  X   |  X   |
    | **Latin diacritics insensitivity** (have "elegance" match "élégance")      |  X   |  X   |  X   |
    | **English Stemming** (have "frustration" match "frustrated")               |  X   |  X   |  X   |
    | **English Stemming and Ascii case insensitivity**                          |  X   |  X   |  X   |
    | **English Stemming and Unicode case insensitivity**                        |      |      |  X   |
    | **English Stemming and Latin diacritics insensitivity**                    |      |      |  X   |
    | **Synonyms** (have "1st" match "first")                                    |  ¹   |  ¹   | X ²  |
    | **Pinyin and Romaji** (have "romaji" match "ローマ字")                         |  ¹   |  ¹   | X ²  |
    | **Stop words** (don't index, and don't match words like "and" and "the")   |  ¹   |  ¹   | X ²  |
    | **Spell checking** (have "alamaba" match "alabama")                        |  ¹   |  ¹   |  ¹   |
    | :bowtie: Other Features                                                    |      |      |      |
    | **Ranking** (sort results by relevance)                                    |  ¹   |  ¹   |  X   |
    | **Snippets** (display a few words around a match)                          |  X   |  X   |  X   |
    
    ¹ Requires extra setup, possibly hard to implement.
    
    ² Requires a [custom tokenizer](Documentation/FTS5Tokenizers.md).
    
    For a full feature list, read the SQLite documentation. Some missing features can be achieved with extra application code.
    
- **The speed versus disk space constraints.** Roughly speaking, FTS4 and FTS5 are faster than FTS3, but use more space. FTS4 only supports content compression.

- **The location of the indexed text in your database schema.** Only FTS4 and FTS5 support "contentless" and "external content" tables.

- **The SQLite library integrated in your application.** The version of SQLite that ships with iOS, macOS and watchOS support FTS3 and FTS4 out of the box, but not FTS5. To use FTS5, you'll need a [custom SQLite build](Documentation/CustomSQLiteBuilds.md) that activates the `SQLITE_ENABLE_FTS5` compilation option.

- See [FST3 vs. FTS4](https://www.sqlite.org/fts3.html#differences_between_fts3_and_fts4) and [FTS5 vs. FTS3/4](https://www.sqlite.org/fts5.html#appendix_a) for more differences.

> :point_up: **Note**: In case you were still wondering, it is recommended to read the SQLite documentation: [FTS3 & FTS4](https://www.sqlite.org/fts3.html) and [FTS5](https://www.sqlite.org/fts5.html).


### Create FTS3 and FTS4 Virtual Tables

**FTS3 and FTS4 full-text tables store and index textual content.**

Create tables with the `create(virtualTable:using:)` method:

```swift
// CREATE VIRTUAL TABLE documents USING fts3(content)
try db.create(virtualTable: "documents", using: FTS3()) { t in
    t.column("content")
}

// CREATE VIRTUAL TABLE documents USING fts4(content)
try db.create(virtualTable: "documents", using: FTS4()) { t in
    t.column("content")
}
```

**All columns in a full-text table contain text.** If you need to index a table that contains other kinds of values, you need an ["external content" full-text table](#external-content-full-text-tables).

You can specify a [tokenizer](#fts3-and-fts4-tokenizers):

```swift
// CREATE VIRTUAL TABLE books USING fts4(
//   tokenize=porter,
//   author,
//   title,
//   body
// )
try db.create(virtualTable: "books", using: FTS4()) { t in
    t.tokenizer = .porter
    t.column("author")
    t.column("title")
    t.column("body")
}
```

FTS4 supports [options](https://www.sqlite.org/fts3.html#fts4_options):

```swift
// CREATE VIRTUAL TABLE books USING fts4(
//   content,
//   uuid,
//   content="",
//   compress=zip,
//   uncompress=unzip,
//   prefix="2,4",
//   notindexed=uuid,
//   languageid=lid
// )
try db.create(virtualTable: "documents", using: FTS4()) { t in
    t.content = ""
    t.compress = "zip"
    t.uncompress = "unzip"
    t.prefixes = [2, 4]
    t.column("content")
    t.column("uuid").notIndexed()
    t.column("lid").asLanguageId()
}
```

The `content` option is involved in "contentless" and "external content" full-text tables. GRDB can help you defining full-text tables that automatically synchronize with their content table. See [External Content Full-Text Tables](#external-content-full-text-tables).


See [SQLite documentation](https://www.sqlite.org/fts3.html) for more information.


### FTS3 and FTS4 Tokenizers

**A tokenizer defines what "matching" means.** Depending on the tokenizer you choose, full-text searches won't return the same results.

SQLite ships with three built-in FTS3/4 tokenizers: `simple`, `porter` and `unicode61` that use different algorithms to match queries with indexed content:

```swift
try db.create(virtualTable: "books", using: FTS4()) { t in
    // Pick one:
    t.tokenizer = .simple // default
    t.tokenizer = .porter
    t.tokenizer = .unicode61(...)
}
```

See below some examples of matches:

| content     | query      | simple | porter | unicode61 |
| ----------- | ---------- | :----: | :----: | :-------: |
| Foo         | Foo        |   X    |   X    |     X     |
| Foo         | FOO        |   X    |   X    |     X     |
| Jérôme      | Jérôme     |   X ¹  |   X ¹  |     X ¹   |
| Jérôme      | JÉRÔME     |        |        |     X ¹   |
| Jérôme      | Jerome     |        |        |     X ¹   |
| Database    | Databases  |        |   X    |           |
| Frustration | Frustrated |        |   X    |           |

¹ Don't miss [Unicode Full-Text Gotchas](#unicode-full-text-gotchas)

- **simple**
    
    ```swift
    try db.create(virtualTable: "books", using: FTS4()) { t in
        t.tokenizer = .simple   // default
    }
    ```
    
    The default "simple" tokenizer is case-insensitive for ASCII characters. It matches "foo" with "FOO", but not "Jérôme" with "JÉRÔME".
    
    It does not provide stemming, and won't match "databases" with "database".
    
    It does not strip diacritics from latin script characters, and won't match "jérôme" with "jerome".
    
- **porter**
    
    ```swift
    try db.create(virtualTable: "books", using: FTS4()) { t in
        t.tokenizer = .porter
    }
    ```
    
    The "porter" tokenizer compares English words according to their roots: it matches "database" with "databases", and "frustration" with "frustrated".
    
    It does not strip diacritics from latin script characters, and won't match "jérôme" with "jerome".

- **unicode61**
    
    ```swift
    try db.create(virtualTable: "books", using: FTS4()) { t in
        t.tokenizer = .unicode61()
        t.tokenizer = .unicode61(removeDiacritics: false)
    }
    ```
    
    The "unicode61" tokenizer is case-insensitive for unicode characters. It matches "Jérôme" with "JÉRÔME".
    
    It strips diacritics from latin script characters by default, and matches "jérôme" with "jerome". This behavior can be disabled, as in the example above.
    
    It does not provide stemming, and won't match "databases" with "database".

See [SQLite tokenizers](https://www.sqlite.org/fts3.html#tokenizer) for more information.


### FTS3Pattern

**Full-text search in FTS3 and FTS4 tables is performed with search patterns:**

- `database` matches all documents that contain "database"
- `data*` matches all documents that contain a word starting with "data"
- `SQLite database` matches all documents that contain both "SQLite" and "database"
- `SQLite OR database` matches all documents that contain "SQLite" or "database"
- `"SQLite database"` matches all documents that contain the "SQLite database" phrase

**Not all search patterns are valid**: they must follow the [Full-Text Index Queries Grammar](https://www.sqlite.org/fts3.html#full_text_index_queries).

The FTS3Pattern type helps you validating patterns, and building valid patterns from untrusted strings (such as strings typed by users):

```swift
struct FTS3Pattern {
    init(rawPattern: String) throws
    init?(matchingAnyTokenIn string: String)
    init?(matchingAllTokensIn string: String)
    init?(matchingPhrase string: String)
}
```

The first initializer validates your raw patterns against the query grammar, and may throw a [DatabaseError](#databaseerror):

```swift
// OK: FTS3Pattern
let pattern = try FTS3Pattern(rawPattern: "sqlite AND database")
// DatabaseError: malformed MATCH expression: [AND]
let pattern = try FTS3Pattern(rawPattern: "AND")
```

The three other initializers don't throw. They build a valid pattern from any string, **including strings provided by users of your application**. They let you find documents that match all given words, any given word, or a full phrase, depending on the needs of your application:

```swift
let query = "SQLite database"
// Matches documents that contain "SQLite" or "database"
let pattern = FTS3Pattern(matchingAnyTokenIn: query)
// Matches documents that contain both "SQLite" and "database"
let pattern = FTS3Pattern(matchingAllTokensIn: query)
// Matches documents that contain "SQLite database"
let pattern = FTS3Pattern(matchingPhrase: query)
```

They return nil when no pattern could be built from the input string:

```swift
let pattern = FTS3Pattern(matchingAnyTokenIn: "")  // nil
let pattern = FTS3Pattern(matchingAnyTokenIn: "*") // nil
```

FTS3Pattern are regular [values](#values). You can use them as query arguments:

```swift
let documents = try Document.fetchAll(db,
    "SELECT * FROM documents WHERE content MATCH ?",
    arguments: [pattern])
```

Use them in the [query interface](#the-query-interface):

```swift
// Search in all columns
let documents = try Document.matching(pattern).fetchAll(db)

// Search in a specific column:
let documents = try Document.filter(Column("content").match(pattern)).fetchAll(db)
```


### Create FTS5 Virtual Tables

**FTS5 full-text tables store and index textual content.**

To use FTS5, you'll need a [custom SQLite build](Documentation/CustomSQLiteBuilds.md) that activates the `SQLITE_ENABLE_FTS5` compilation option.

Create FTS5 tables with the `create(virtualTable:using:)` method:

```swift
// CREATE VIRTUAL TABLE documents USING fts5(content)
try db.create(virtualTable: "documents", using: FTS5()) { t in
    t.column("content")
}
```

**All columns in a full-text table contain text.** If you need to index a table that contains other kinds of values, you need an ["external content" full-text table](#external-content-full-text-tables).

You can specify a [tokenizer](#fts5-tokenizers):

```swift
// CREATE VIRTUAL TABLE books USING fts5(
//   tokenize='porter',
//   author,
//   title,
//   body
// )
try db.create(virtualTable: "books", using: FTS5()) { t in
    t.tokenizer = .porter()
    t.column("author")
    t.column("title")
    t.column("body")
}
```

FTS5 supports [options](https://www.sqlite.org/fts5.html#fts5_table_creation_and_initialization):

```swift
// CREATE VIRTUAL TABLE books USING fts5(
//   content,
//   uuid UNINDEXED,
//   content='table',
//   content_rowid='id',
//   prefix='2 4',
//   columnsize=0,
//   detail=column
// )
try db.create(virtualTable: "documents", using: FTS5()) { t in
    t.column("content")
    t.column("uuid").notIndexed()
    t.content = "table"
    t.contentRowID = "id"
    t.prefixes = [2, 4]
    t.columnSize = 0
    t.detail = "column"
}
```

The `content` and `contentRowID` options are involved in "contentless" and "external content" full-text tables. GRDB can help you defining full-text tables that automatically synchronize with their content table. See [External Content Full-Text Tables](#external-content-full-text-tables).

See [SQLite documentation](https://www.sqlite.org/fts5.html) for more information.


### FTS5 Tokenizers

**A tokenizer defines what "matching" means.** Depending on the tokenizer you choose, full-text searches won't return the same results.

SQLite ships with three built-in FTS5 tokenizers: `ascii`, `porter` and `unicode61` that use different algorithms to match queries with indexed content.

```swift
try db.create(virtualTable: "books", using: FTS5()) { t in
    // Pick one:
    t.tokenizer = .unicode61() // default
    t.tokenizer = .unicode61(...)
    t.tokenizer = .ascii
    t.tokenizer = .porter(...)
}
```

See below some examples of matches:

| content     | query      | ascii  | unicode61 | porter on ascii | porter on unicode61 |
| ----------- | ---------- | :----: | :-------: | :-------------: | :-----------------: |
| Foo         | Foo        |   X    |     X     |        X        |          X          |
| Foo         | FOO        |   X    |     X     |        X        |          X          |
| Jérôme      | Jérôme     |   X ¹  |     X ¹   |        X ¹      |          X ¹        |
| Jérôme      | JÉRÔME     |        |     X ¹   |                 |          X ¹        |
| Jérôme      | Jerome     |        |     X ¹   |                 |          X ¹        |
| Database    | Databases  |        |           |        X        |          X          |
| Frustration | Frustrated |        |           |        X        |          X          |

¹ Don't miss [Unicode Full-Text Gotchas](#unicode-full-text-gotchas)

- **unicode61**
    
    ```swift
    try db.create(virtualTable: "books", using: FTS5()) { t in
        t.tokenizer = .unicode61()
        t.tokenizer = .unicode61(removeDiacritics: false)
    }
    ```
    
    The default "unicode61" tokenizer is case-insensitive for unicode characters. It matches "Jérôme" with "JÉRÔME".
    
    It strips diacritics from latin script characters by default, and matches "jérôme" with "jerome". This behavior can be disabled, as in the example above.
    
    It does not provide stemming, and won't match "databases" with "database".

- **ascii**
    
    ```swift
    try db.create(virtualTable: "books", using: FTS5()) { t in
        t.tokenizer = .ascii
    }
    ```
    
    The "ascii" tokenizer is case-insensitive for ASCII characters. It matches "foo" with "FOO", but not "Jérôme" with "JÉRÔME".
    
    It does not provide stemming, and won't match "databases" with "database".
    
    It does not strip diacritics from latin script characters, and won't match "jérôme" with "jerome".
    
- **porter**
    
    ```swift
    try db.create(virtualTable: "books", using: FTS5()) { t in
        t.tokenizer = .porter()       // porter wrapping unicode61 (the default)
        t.tokenizer = .porter(.ascii) // porter wrapping ascii
        t.tokenizer = .porter(.unicode61(removeDiacritics: false)) // porter wrapping unicode61 without diacritics stripping
    }
    ```
    
    The porter tokenizer is a wrapper tokenizer which compares English words according to their roots: it matches "database" with "databases", and "frustration" with "frustrated".
    
    It strips diacritics from latin script characters if it wraps unicode61, and does not if it wraps ascii (see the example above).

See [SQLite tokenizers](https://www.sqlite.org/fts5.html#tokenizers) for more information, and [custom FTS5 tokenizers](Documentation/FTS5Tokenizers.md) in order to add your own tokenizers.


### FTS5Pattern

**Full-text search in FTS5 tables is performed with search patterns:**

- `database` matches all documents that contain "database"
- `data*` matches all documents that contain a word starting with "data"
- `SQLite database` matches all documents that contain both "SQLite" and "database"
- `SQLite OR database` matches all documents that contain "SQLite" or "database"
- `"SQLite database"` matches all documents that contain the "SQLite database" phrase

**Not all search patterns are valid**: they must follow the [Full-Text Query Syntax](https://www.sqlite.org/fts5.html#full_text_query_syntax).

The FTS5Pattern type helps you validating patterns, and building valid patterns from untrusted strings (such as strings typed by users):

```swift
extension Database {
    func makeFTS5Pattern(rawPattern: String, forTable table: String) throws -> FTS5Pattern
}

struct FTS5Pattern {
    init?(matchingAnyTokenIn string: String)
    init?(matchingAllTokensIn string: String)
    init?(matchingPhrase string: String)
}
```

The `Database.makeFTS5Pattern(rawPattern:forTable:)` method validates your raw patterns against the query grammar and the columns of the targeted table, and may throw a [DatabaseError](#databaseerror):

```swift
// OK: FTS5Pattern
try db.makeFTS5Pattern(rawPattern: "sqlite", forTable: "books")
// DatabaseError: syntax error near \"AND\"
try db.makeFTS5Pattern(rawPattern: "AND", forTable: "books")
// DatabaseError: no such column: missing
try db.makeFTS5Pattern(rawPattern: "missing: sqlite", forTable: "books")
```

The FTS5Pattern initializers don't throw. They build a valid pattern from any string, **including strings provided by users of your application**. They let you find documents that match all given words, any given word, or a full phrase, depending on the needs of your application:

```swift
let query = "SQLite database"
// Matches documents that contain "SQLite" or "database"
let pattern = FTS5Pattern(matchingAnyTokenIn: query)
// Matches documents that contain both "SQLite" and "database"
let pattern = FTS5Pattern(matchingAllTokensIn: query)
// Matches documents that contain "SQLite database"
let pattern = FTS5Pattern(matchingPhrase: query)
```

They return nil when no pattern could be built from the input string:

```swift
let pattern = FTS5Pattern(matchingAnyTokenIn: "")  // nil
let pattern = FTS5Pattern(matchingAnyTokenIn: "*") // nil
```

FTS5Pattern are regular [values](#values). You can use them as query arguments:

```swift
let documents = try Document.fetchAll(db,
    "SELECT * FROM documents WHERE documents MATCH ?",
    arguments: [pattern])
```

Use them in the [query interface](#the-query-interface):

```swift
let documents = try Document.matching(pattern).fetchAll(db)
```


### FTS5: Sorting by Relevance

**FTS5 can sort results by relevance** (most to least relevant):

```swift
// SQL
let documents = try Document.fetchAll(db,
    "SELECT * FROM documents WHERE documents MATCH ? ORDER BY rank",
    arguments: [pattern])

// Query Interface
let documents = try Document.matching(pattern).order(Column.rank).fetchAll(db)
```

For more information about the ranking algorithm, as well as extra options, read [Sorting by Auxiliary Function Results](https://www.sqlite.org/fts5.html#sorting_by_auxiliary_function_results)

GRDB does not provide any ranking for FTS3 and FTS4. See SQLite's [Search Application Tips](https://www.sqlite.org/fts3.html#appendix_a) if you really need it.


### External Content Full-Text Tables

**An external content table does not store the indexed text.** Instead, it indexes the text stored in another table.

This is very handy when you want to index a table that can not be declared as a full-text table (because it contains non-textual values, for example). You just have to define an external content full-text table that refers to the regular table.

The two tables must be kept up-to-date, so that the full-text index matches the content of the regular table. This synchronization happens automatically if you use the `synchronize(withTable:)` method in your full-text table definition:

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

The eventual content already present in the regular table is indexed, and every insert, update or delete that happens in the regular table is automatically applied to the full-text index by the mean of SQL triggers.

For more information, see the SQLite documentation about external content tables: [FTS4](https://www.sqlite.org/fts3.html#_external_content_fts4_tables_), [FTS5](https://sqlite.org/fts5.html#external_content_tables).

See also [WWDC Companion](https://github.com/groue/WWDCCompanion), a sample app that uses external content tables to store, display, and let the user search the WWDC 2016 sessions.


### Full-Text Records

**You can define [record](#records) types around the full-text virtual tables.**

However these tables don't have any explicit primary key. Instead, they use the [implicit rowid primary key](#the-implicit-rowid-primary-key): a special hidden column named `rowid`.

You will have to [expose this hidden column](#exposing-the-rowid-column) in order to fetch, delete, and update full-text records by primary key.


### Unicode Full-Text Gotchas

The SQLite built-in tokenizers for [FTS3, FTS4](#fts3-and-fts4-tokenizers) and [FTS5](#fts5-tokenizers) are generally unicode-aware, with a few caveats, and limitations.

Generally speaking, matches may fail when content and query don't use the same [unicode normalization](http://unicode.org/reports/tr15/). SQLite actually exhibits inconsistent behavior in this regard.

For example, for "aimé" to match "aimé", they better have the same normalization: the NFC "aim\u{00E9}" form may not match its NFD "aime\u{0301}" equivalent. Most strings that you get from Swift, UIKit and Cocoa use NFC, so be careful with NFD inputs (such as strings from the HFS+ file system, or strings that you can't trust like network inputs). Use [String.precomposedStringWithCanonicalMapping](https://developer.apple.com/reference/swift/string/1407210-precomposedstringwithcanonicalma) to turn a string into NFC.

Besides, if you want "fi" to match the ligature "&#xfb01;" (U+FB01), then you need to normalize your indexed contents and inputs to NFKC or NFKD. Use [String.precomposedStringWithCompatibilityMapping](https://developer.apple.com/reference/swift/string/1407834-precomposedstringwithcompatibili) to turn a string into NFKC.

Unicode normalization is not the end of the story, because it won't help "Encyclopaedia" match "Encyclopædia", "Mueller", "Müller", "Grossmann", "Großmann", or "Diyarbakır", "DIYARBAKIR". The [String.applyingTransform](https://developer.apple.com/reference/swift/string/1643133-applyingtransform) method can help.

GRDB lets you write [custom FTS5 tokenizers](Documentation/FTS5Tokenizers.md) that can transparently deal with all these issues. For FTS3 and FTS4, you'll need to pre-process your strings before injecting them in the full-text engine.

Happy indexing!


## Database Changes Observation

The `TransactionObserver` protocol lets you **observe database changes**:

```swift
public protocol TransactionObserver : class {
    /// Filters database changes that should be notified the the
    /// `databaseDidChange(with:)` method.
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool
    
    /// Notifies a database change:
    /// - event.kind (insert, update, or delete)
    /// - event.tableName
    /// - event.rowID
    ///
    /// For performance reasons, the event is only valid for the duration of
    /// this method call. If you need to keep it longer, store a copy:
    /// event.copy().
    func databaseDidChange(with event: DatabaseEvent)
    
    /// An opportunity to rollback pending changes by throwing an error.
    func databaseWillCommit() throws
    
    /// Database changes have been committed.
    func databaseDidCommit(_ db: Database)
    
    /// Database changes have been rollbacked.
    func databaseDidRollback(_ db: Database)
}
```

To activate a transaction observer, add it to the database queue or pool:

```swift
let observer = MyObserver()
dbQueue.add(transactionObserver: observer)
```

Database holds weak references to its transaction observers: they are not retained, and stop getting notifications after they are deallocated.

**A transaction observer is notified of all database changes**: inserts, updates and deletes. This includes indirect changes triggered by ON DELETE and ON UPDATE actions associated to [foreign keys](https://www.sqlite.org/foreignkeys.html#fk_actions).

> :point_up: **Note**: the changes that are not notified are changes to internal system tables (such as `sqlite_master`), changes to [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) tables, and the deletion of duplicate rows triggered by [`ON CONFLICT REPLACE`](https://www.sqlite.org/lang_conflict.html) clauses (this last exception might change in a future release of SQLite).

Notified changes are not actually written to disk until `databaseDidCommit` is called. On the other side, `databaseDidRollback` confirms their invalidation:

```swift
try dbQueue.inTransaction { db in
    try db.execute("INSERT ...") // 1. didChange
    try db.execute("UPDATE ...") // 2. didChange
    return .commit               // 3. willCommit, 4. didCommit
}

try dbQueue.inTransaction { db in
    try db.execute("INSERT ...") // 1. didChange
    try db.execute("UPDATE ...") // 2. didChange
    return .rollback             // 3. didRollback
}
```

Database statements that are executed outside of an explicit transaction do not drop off the radar:

```swift
try dbQueue.inDatabase { db in
    try db.execute("INSERT ...") // 1. didChange, 2. willCommit, 3. didCommit
    try db.execute("UPDATE ...") // 4. didChange, 5. willCommit, 6. didCommit
}
```

Changes that are on hold because of a [savepoint](https://www.sqlite.org/lang_savepoint.html) are only notified after the savepoint has been released. This makes sure that notified events are only events that have an opportunity to be committed:

```swift
try dbQueue.inTransaction { db in
    try db.execute("INSERT ...")            // 1. didChange
    
    try db.execute("SAVEPOINT foo")
    try db.execute("UPDATE ...")            // delayed
    try db.execute("UPDATE ...")            // delayed
    try db.execute("RELEASE SAVEPOINT foo") // 2. didChange, 3. didChange
    
    try db.execute("SAVEPOINT foo")
    try db.execute("UPDATE ...")            // not notified
    try db.execute("ROLLBACK TO SAVEPOINT foo")
    
    return .commit                          // 4. willCommit, 5. didCommit
}
```


**Eventual errors** thrown from `databaseWillCommit` are exposed to the application code:

```swift
do {
    try dbQueue.inTransaction { db in
        ...
        return .commit           // 1. willCommit (throws), 2. didRollback
    }
} catch {
    // 3. The error thrown by the transaction observer.
}
```

> :point_up: **Note**: all callbacks are called in a protected dispatch queue, and serialized with all database updates.
>
> :point_up: **Note**: the databaseDidChange(with:) and databaseWillCommit() callbacks must not touch the SQLite database. This limitation does not apply to databaseDidCommit and databaseDidRollback which can use their database argument.

[FetchedRecordsController](#fetchedrecordscontroller) is based on the TransactionObserver protocol.

See also [TableChangeObserver.swift](https://gist.github.com/groue/2e21172719e634657dfd), which shows a transaction observer that notifies of modified database tables with NSNotificationCenter.


### Filtering Database Events

**Transaction observers can avoid being notified of some database changes they are not interested in.**

At first sight, this looks somewhat redundant with the checks that observers can perform in their `databaseDidChange` method. But the code below is inefficient:

```swift
// BAD: An inefficient way to track the "persons" table:
class PersonObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        // Observe all events
        return true
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        guard event.tableName == "persons" else {
            return
        }
        // Process change
    }
}
```

The `databaseDidChange` method is invoked for each insertion, deletion, and update of individual rows. When there are many changed rows, the observer will spend of a lot of time performing the same check again and again.

More, when you're interested in specific table columns, you're out of luck, because `databaseDidChange` does not know about columns: it just knows that a row has been inserted, deleted, or updated, without further detail.

Instead, filter events in the `observes(eventsOfKind:)` method, as below:

```swift
class PersonObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        // Only observe changes to the "name" column of the "persons" table.
        switch eventKind {
        case .insert(let tableName):
            return tableName == "persons"
        case .delete(let tableName):
            return tableName == "persons"
        case .update(let tableName, let columnNames):
            return tableName == "persons" && columnNames.contains("name")
        }
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        // Process change
    }
}
```

This technique is *much more* efficient, because GRDB will apply the filter only once for each update statement, instead of once for each modified row.


### Support for SQLite Pre-Update Hooks

A [custom SQLite build](Documentation/CustomSQLiteBuilds.md) can activate [SQLite "preupdate hooks"](http://www.sqlite.org/sessions/c3ref/preupdate_count.html). In this case, TransactionObserverType gets an extra callback which lets you observe individual column values in the rows modified by a transaction:

```swift
public protocol TransactionObserverType : class {
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


## FetchedRecordsController

**You use FetchedRecordsController to track changes in the results of an SQLite request.**

**On iOS, FetchedRecordsController can feed a UITableView, and animate rows when the results of the request change.**

It looks and behaves very much like [Core Data's NSFetchedResultsController](https://developer.apple.com/library/ios/documentation/CoreData/Reference/NSFetchedResultsController_Class/).

Given a fetch request, and a type that adopts the [RowConvertible](#rowconvertible-protocol) protocol, such as a subclass of the [Record](#record-class) class, a FetchedRecordsController is able to track changes in the results of the fetch request, and notify of those changes.

On iOS, FetchedRecordsController is able to return the results of the request in a form that is suitable for a UITableView, with one table view row per fetched record.

See [GRDBDemoiOS](DemoApps/GRDBDemoiOS) for an sample app that uses FetchedRecordsController.

- [Creating the Fetched Records Controller](#creating-the-fetched-records-controller)
- [Responding to Changes](#responding-to-changes)
- [The Changes Notifications](#the-changes-notifications)
- [Modifying the Fetch Request](#modifying-the-fetch-request)
- [FetchedRecordsController on iOS](#fetchedrecordscontroller-on-ios)
    - [Implementing the Table View Datasource Methods](#implementing-the-table-view-datasource methods)
    - [Implementing Table View Updates](#implementing-table-view-updates)
- [FetchedRecordsController Concurrency](#fetchedrecordscontroller-concurrency)


### Creating the Fetched Records Controller

When you initialize a fetched records controller, you provide the following mandatory information:

- A [database connection](#database-connections)
- The type of the fetched records. It must be a type that adopts the [RowConvertible](#rowconvertible-protocol) protocol, such as a subclass of the [Record](#record-class) class
- A fetch request

```swift
class Person : Record { ... }
let dbQueue = DatabaseQueue(...)    // Or DatabasePool

// Using a FetchRequest from the Query Interface:
let controller = FetchedRecordsController<Person>(
    dbQueue,
    request: Person.order(Column("name")))

// Using SQL, and eventual arguments:
let controller = FetchedRecordsController<Person>(
    dbQueue,
    sql: "SELECT * FROM persons ORDER BY name WHERE countryIsoCode = ?",
    arguments: ["FR"])
```

The fetch request can involve several database tables. The fetched records controller will only track changes in the columns and tables used by the fetch request.

```swift
let controller = FetchedRecordsController<Person>(
    dbQueue,
    sql: "SELECT persons.name, COUNT(books.id) AS bookCount " +
         "FROM persons " +
         "LEFT JOIN books ON books.authorId = persons.id " +
         "GROUP BY persons.id " +
         "ORDER BY persons.name")
```


After creating an instance, you invoke `performFetch()` to actually execute
the fetch.

```swift
try controller.performFetch()
```


### Responding to Changes

In general, FetchedRecordsController is designed to respond to changes at *the database layer*, by [notifying](#the-changes-notifications) when *database rows* change location or values.

Changes are not reflected until they are applied in the database by a successful [transaction](#transactions-and-savepoints). Transactions can be explicit, or implicit:

```swift
try dbQueue.inTransaction { db in
    try person1.insert(db)
    try person2.insert(db)
    return .commit         // Explicit transaction
}

try dbQueue.inDatabase { db in
    try person1.insert(db) // Implicit transaction
    try person2.insert(db) // Implicit transaction
}
```

When you apply several changes to the database, you should group them in a single explicit transaction. The controller will then notify of all changes together.


### The Changes Notifications

An instance of FetchedRecordsController notifies that the controller’s fetched records have been changed by the mean of *callbacks*:

```swift
let controller = try FetchedRecordsController(...)

controller.trackChanges(
    // controller's records are about to change:
    recordsWillChange: { controller in ... },
    
    // (iOS only) notification of individual record changes:
    tableViewEvent: { (controller, record, event) in ... },
    
    // controller's records have changed:
    recordsDidChange: { controller in ... })

try controller.performFetch()
```

See [Implementing Table View Updates](#implementing-table-view-updates) for more detail on table view updates on iOS.

**All callbacks are optional.** When you only need to grab the latest results, you can omit the `recordsDidChange` argument name:

```swift
controller.trackChanges { controller in
    let newPersons = controller.fetchedRecords! // [Person]
}
```

Callbacks have the fetched record controller itself as an argument: use it in order to avoid memory leaks:

```swift
// BAD: memory leak
controller.trackChanges { _ in
    let newPersons = controller.fetchedRecords!
}

// GOOD
controller.trackChanges { controller in
    let newPersons = controller.fetchedRecords!
}
```

**Callbacks are invoked asynchronously.** See [FetchedRecordsController Concurrency](#fetchedrecordscontroller-concurrency) for more information.

**Values fetched from inside callbacks may be inconsistent with the controller's records.** This is because after database has changed, and before the controller had the opportunity to invoke callbacks in the main thread, other database changes can happen.

To avoid inconsistencies, provide a `fetchAlongside` argument to the `trackChanges` method, as below:

```swift
controller.trackChanges(
    fetchAlongside: { db in
        // Fetch any extra value, for example the number of fetched records:
        return try Person.fetchCount(db)
    },
    recordsDidChange: { (controller, count) in
        // The extra value is the second argument.
        let recordsCount = controller.fetchedRecords!.count
        assert(count == recordsCount) // guaranteed
    })
```



### Modifying the Fetch Request

You can change a fetched records controller's fetch request or SQL query.

```swift
controller.setRequest(Person.order(Column("name")))
controller.setRequest(sql: "SELECT ...", arguments: ...)
```

The [notification callbacks](#the-changes-notifications) are notified of eventual changes if the new request fetches a different set of records.

> :point_up: **Note**: This behavior differs from Core Data's NSFetchedResultsController, which does not notify of record changes when the fetch request is replaced.

**Change callbacks are invoked asynchronously.** This means that modifying the request from the main thread does *not* immediately triggers callbacks. When you need to take immediate action, force the controller to refresh immediately with its `performFetch` method. In this case, changes callbacks are *not* called:

```swift
// Change request on the main thread:
controller.setRequest(Person.order(Column("name")))
// Here callbacks have not been called yet.
// You can cancel them, and refresh records immediately:
try controller.performFetch()
```

### FetchedRecordsController on iOS

On iOS, FetchedRecordsController provides extra APIs that help feeding table views, and keeping them up-to-date with the database content.

This require an extra step in the controller initialization, so that it can *identify* records.

Records are usually identified by their primary key. When the record type adopts the [TableMapping](#tablemapping-protocol) protocol, such as [Record](#record-class) subclasses, you will generally use the `compareRecordsByPrimaryKey` initialization argument:

```swift
let controller = FetchedRecordsController<Person>(
    dbQueue,
    request: ...,
    compareRecordsByPrimaryKey: true)
```

When the record type does not adopt the [TableMapping](#tablemapping-protocol) protocol, be explicit:

```swift
let controller = FetchedRecordsController<Person>(
    dbQueue,
    request: ...,
    isSameRecord: { (person1, person2) in person1.id == person2.id })
```


#### Implementing the Table View Datasource Methods

The table view data source asks the fetched records controller to provide relevant information:

```swift
func numberOfSections(in tableView: UITableView) -> Int {
    return fetchedRecordsController.sections.count
}

func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return fetchedRecordsController.sections[section].numberOfRecords
}

func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = ...
    let record = fetchedRecordsController.record(at: indexPath)
    // Configure the cell
    return cell
}
```

> :point_up: **Note**: In its current state, FetchedRecordsController does not support grouping table view rows into custom sections: it generates a unique section.


#### Implementing Table View Updates

When changes in the fetched records should reload the whole table view, you can simply tell so:

```swift
controller.trackChanges { [unowned self] _ in
    self.tableView.reloadData()
}
```

Yet, FetchedRecordsController can notify that the controller’s fetched records have been changed due to some add, remove, move, or update operations, and help applying animated changes to a UITableView.


##### Typical Table View Updates

For animated table view updates, use the `recordsWillChange` and `recordsDidChange` callbacks to bracket events provided by the fetched records controller, as illustrated in the following example:

```swift
// Assume self has a tableView property, and a cell configuration
// method named configure(_:at:).

controller.trackChanges(
    // controller's records are about to change:
    recordsWillChange: { [unowned self] _ in
        self.tableView.beginUpdates()
    },
    
    // notification of individual record changes:
    tableViewEvent: { [unowned self] (controller, record, event) in
        switch event {
        case .insertion(let indexPath):
            self.tableView.insertRows(at: [indexPath], with: .fade)
            
        case .deletion(let indexPath):
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            
        case .update(let indexPath, _):
            if let cell = self.tableView.cellForRow(at: indexPath) {
                self.configure(cell, at: indexPath)
            }
            
        case .move(let indexPath, let newIndexPath, _):
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            self.tableView.insertRows(at: [newIndexPath], with: .fade)

            // // Alternate technique which actually moves cells around:
            // let cell = self.tableView.cellForRow(at: indexPath)
            // self.tableView.moveRow(at: indexPath, to: newIndexPath)
            // if let cell = cell {
            //     self.configure(cell, at: newIndexPath)
            // }
        }
    },
    
    // controller's records have changed:
    recordsDidChange: { [unowned self] _ in
        self.tableView.endUpdates()
    })
```

See [GRDBDemoiOS](DemoApps/GRDBDemoiOS) for an sample app that uses FetchedRecordsController.

> :point_up: **Note**: our sample code above uses `unowned` references to the table view controller. This is a safe pattern as long as the table view controller owns the fetched records controller, and is deallocated from the main thread (this is usually the case). In other situations, prefer weak references.


### FetchedRecordsController Concurrency

**A fetched records controller *can not* be used from any thread.**

When the database itself can be read and modified from [any thread](#database-connections), fetched records controllers **must** be used from the main thread. Record changes are also [notified](#the-changes-notifications) on the main thread.

**Change callbacks are invoked asynchronously.** This means that changes made from the main thread are *not* immediately notified. When you need to take immediate action, force the controller to refresh immediately with its `performFetch` method. In this case, changes callbacks are *not* called:

```swift
// Change database on the main thread:
try dbQueue.inDatabase { db in
    try Person(...).insert(db)
}
// Here callbacks have not been called yet.
// You can cancel them, and refresh records immediately:
try controller.performFetch()
```

> :point_up: **Note**: when the main thread does not fit your needs, give a serial dispatch queue to the controller initializer: the controller must then be used from this queue, and record changes are notified on this queue as well.
>
> ```swift
> let queue = DispatchQueue()
> queue.async {
>     let controller = try FetchedRecordsController(..., queue: queue)
>     controller.trackChanges { /* in queue */ }
>     try controller.performFetch()
> }
> ```


## Encryption

**GRDB can encrypt your database with [SQLCipher](http://sqlcipher.net) v3.4.0.**

This requires a manual installation of GRDB:

1. Clone the GRDB.swift git repository, checkout the latest tagged version, and download SQLCipher sources:
    
    ```sh
    cd [GRDB.swift directory]
    git checkout v0.93.0
    git submodule update --init SQLCipher/src
    ````
    
2. Embed the `GRDB.xcodeproj` project in your own project.

3. Add the `GRDBCipherOSX` or `GRDBCipheriOS` target in the **Target Dependencies** section of the **Build Phases** tab of your application target.

4. Add the `GRDBCipher.framework` from the targetted platform to the **Embedded Binaries** section of the **General**  tab of your target.

**You create and open an encrypted database** by providing a passphrase to your [database connection](#database-connections):

```swift
import GRDBCipher

var configuration = Configuration()
configuration.passphrase = "secret"
let dbQueue = try DatabaseQueue(path: "...", configuration: configuration)
```

**You can change the passphrase** of an already encrypted database:

```swift
try dbQueue.change(passphrase: "newSecret")
```

Providing a passphrase won't encrypt a clear-text database that already exists, though. SQLCipher can't do that, and you will get an error instead: `SQLite error 26: file is encrypted or is not a database`.

**To encrypt an existing clear-text database**, create a new and empty encrypted database, and copy the content of the clear-text database in it. The technique to do that is [documented](https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/868/1) by SQLCipher. With GRDB, it gives:

```swift
// The clear-text database
let clearDBQueue = try DatabaseQueue(path: "/path/to/clear.db")

// The encrypted database, at some distinct location:
var configuration = Configuration()
configuration.passphrase = "secret"
let encryptedDBQueue = try DatabaseQueue(path: "/path/to/encrypted.db", configuration: config)

try clearDBQueue.inDatabase { db in
    try db.execute("ATTACH DATABASE ? AS encrypted KEY ?", arguments: [encryptedDBQueue.path, "secret"])
    try db.execute("SELECT sqlcipher_export('encrypted')")
    try db.execute("DETACH DATABASE encrypted")
}

// Now the copy is done, and the clear-text database can be deleted.
```


## Backup

**You can backup (copy) a database into another.**

Backups can for example help you copying an in-memory database to and from a database file when you implement NSDocument subclasses.

```swift
let source: DatabaseQueue = ...      // or DatabasePool
let destination: DatabaseQueue = ... // or DatabasePool
try source.backup(to: destination)
```

The `backup` method blocks the current thread until the destination database contains the same contents as the source database.

When the source is a [database pool](#database-pools), concurrent writes can happen during the backup. Those writes may, or may not, be reflected in the backup, but they won't trigger any error.


Good To Know
============

This chapter covers general topics that you should be aware of.

- [Avoiding SQL Injection](#avoiding-sql-injection)
- [Error Handling](#error-handling)
- [Unicode](#unicode)
- [Memory Management](#memory-management)
- [Concurrency](#concurrency)
- [Performance](#performance)


## Avoiding SQL Injection

SQL injection is a technique that lets an attacker nuke your database.

> ![XKCD: Exploits of a Mom](https://imgs.xkcd.com/comics/exploits_of_a_mom.png)
>
> https://xkcd.com/327/

Here is an example of code that is vulnerable to SQL injection:

```swift
// BAD BAD BAD
let name = textField.text
try dbQueue.inDatabase { db in
    try db.execute("UPDATE students SET name = '\(name)' WHERE id = \(id)")
}
```

If the user enters a funny string like `Robert'; DROP TABLE students; --`, SQLite will see the following SQL, and drop your database table instead of updating a name as intended:

```sql
UPDATE students SET name = 'Robert';
DROP TABLE students;
--' WHERE id = 1
```

To avoid those problems, **never embed raw values in your SQL queries**. The only correct technique is to provide arguments to your SQL queries:

```swift
// Good
let name = textField.text
try dbQueue.inDatabase { db in
    try db.execute(
        "UPDATE students SET name = ? WHERE id = ?",
        arguments: [name, id])
}
```

See [Executing Updates](#executing-updates) for more information on statement arguments.


## Error Handling

GRDB can throw [DatabaseError](#databaseerror), [PersistenceError](#persistenceerror), or crash your program with a [fatal error](#fatal-errors).

Considering that a local database is not some JSON loaded from a remote server, GRDB focuses on **trusted databases**. Dealing with [untrusted databases](#how-to-deal-with-untrusted-inputs) requires extra care.


### DatabaseError

**DatabaseError** are thrown on SQLite errors (see [the list of SQLite error codes](https://www.sqlite.org/rescode.html)):

```swift
do {
    try db.execute(
        "INSERT INTO pets (masterId, name) VALUES (?, ?)",
        arguments: [1, "Bobby"])
} catch let error as DatabaseError {
    // The SQLite error code: 19 (SQLITE_CONSTRAINT)
    error.code
    
    // The eventual SQLite message: FOREIGN KEY constraint failed
    error.message
    
    // The eventual erroneous SQL query
    // "INSERT INTO pets (masterId, name) VALUES (?, ?)"
    error.sql

    // Full error description:
    // "SQLite error 19 with statement `INSERT INTO pets (masterId, name)
    //  VALUES (?, ?)` arguments [1, "Bobby"]: FOREIGN KEY constraint failed""
    error.description
}
```


### PersistenceError

**PersistenceError** is thrown by the [Persistable](#persistable-protocol) protocol, in a single case: when the `update` method could not find any row to update:

```swift
do {
    try person.update(db)
} catch PersistenceError.recordNotFound {
    // There was nothing to update
}
```


### Fatal Errors

**Fatal errors notify that the program, or the database, has to be changed.**

They uncover programmer errors, false assumptions, and prevent misuses. Here are a few examples:

- **The code asks for a non-optional value, when the database contains NULL:**
    
    ```swift
    // fatal error: could not convert NULL to String.
    let name: String = row.value(named: "name")
    ```
    
    Solution: fix the contents of the database, use [NOT NULL constraints](#create-tables), or load an optional:
    
    ```swift
    let name: String? = row.value(named: "name")
    ```

- **The code asks for a Date, when the database contains garbage:**
    
    ```swift
    // fatal error: could not convert "Mom’s birthday" to Date.
    let date: Date? = row.value(named: "date")
    ```
    
    Solution: fix the contents of the database, or use [DatabaseValue](#databasevalue) to handle all possible cases:
    
    ```swift
    let dbv: DatabaseValue = row.value(named: "date")
    if dbv.isNull {
        // Handle NULL
    if let date = Date.fromDatabaseValue(dbv) {
        // Handle valid date
    } else {
        // Handle invalid date
    }
    ```

- **The database can't guarantee that the code does what it says:**

    ```swift
    // fatal error: table persons has no unique index on column email
    try Person.deleteOne(db, key: ["email": "arthur@example.com"])
    ```
    
    Solution: add a unique index to the persons.email column, or use the `deleteAll` method to make it clear that you may delete more than one row:
    
    ```swift
    try Person.filter(Column("email") == "arthur@example.com").deleteAll(db)
    ```

- **Database connections are not reentrant:**
    
    ```swift
    // fatal error: Database methods are not reentrant.
    dbQueue.inDatabase { db in
        dbQueue.inDatabase { db in
            ...
        }
    }
    ```
    
    Solution: avoid reentrancy, and instead pass a database connection along.


### How to Deal with Untrusted Inputs

Let's consider the code below:

```swift
let sql = "SELECT ..."

// Some untrusted arguments for the query
let arguments: [String: Any] = ...
let rows = try Row.fetchCursor(db, sql, arguments: StatementArguments(arguments))

while let row = try rows.next() {
    // Some untrusted database value:
    let date: Date? = row.value(atIndex: 0)
}
```

It has two opportunities to throw fatal errors:

- **Untrusted arguments**: The dictionary may contain values that do not conform to the [DatabaseValueConvertible protocol](#values), or may miss keys required by the statement.
- **Untrusted database content**: The row may contain a non-null value that can't be turned into a date.

In such a situation, you can still avoid fatal errors by exposing and handling each failure point, one level down in the GRDB API:

```swift
// Untrusted arguments
if let arguments = StatementArguments(arguments) {
    let statement = try db.makeSelectStatement(sql)
    try statement.validate(arguments: arguments)
    statement.unsafeSetArguments(arguments)
    
    var cursor = try Row.fetchCursor(statement)
    while let row = try iterator.next() {
        // Untrusted database content
        let dbv: DatabaseValue = row.value(atIndex: 0)
        if dbv.isNull {
            // Handle NULL
        if let date = Date.fromDatabaseValue(dbv) {
            // Handle valid date
        } else {
            // Handle invalid date
        }
    }
}
```

See [prepared statements](#prepared-statements) and [DatabaseValue](#databasevalue) for more information.


## Unicode

SQLite lets you store unicode strings in the database.

However, SQLite does not provide any unicode-aware string transformations or comparisons.


### Unicode functions

The `UPPER` and `LOWER` built-in SQLite functions are not unicode-aware:

```swift
// "JéRôME"
try String.fetchOne(db, "SELECT UPPER('Jérôme')")
```

GRDB extends SQLite with [SQL functions](#custom-sql-functions) that call the Swift built-in string functions `capitalized`, `lowercased`, `uppercased`, `localizedCapitalized`, `localizedLowercased` and `localizedUppercased`:

```swift
// "JÉRÔME"
let uppercase = DatabaseFunction.uppercase
try String.fetchOne(db, "SELECT \(uppercased.name)('Jérôme')")
```

Those unicode-aware string functions are also readily available in the [query interface](#sql-functions):

```
Person.select(nameColumn.uppercased)
```


### String Comparison

SQLite compares strings in many occasions: when you sort rows according to a string column, or when you use a comparison operator such as `=` and `<=`.

The comparison result comes from a *collating function*, or *collation*. SQLite comes with three built-in collations that do not support Unicode: [binary, nocase, and rtrim](https://www.sqlite.org/datatype3.html#collation).

GRDB comes with five extra collations that leverage unicode-aware comparisons based on the standard Swift String comparison functions and operators:

- `unicodeCompare` (uses the built-in `<=` and `==` Swift operators)
- `caseInsensitiveCompare`
- `localizedCaseInsensitiveCompare`
- `localizedCompare`
- `localizedStandardCompare`

A collation can be applied to a table column. All comparisons involving this column will then automatically trigger the comparison function:
    
```swift
try db.create(table: "persons") { t in
    // Guarantees case-insensitive email unicity
    t.column("email", .text).unique().collate(.nocase)
    
    // Sort names in a localized case insensitive way
    t.column("name", .text).collate(.localizedCaseInsensitiveCompare)
}

// Persons are sorted in a localized case insensitive way:
let persons = try Person.order(nameColumn).fetchAll(db)
```

> :warning: **Warning**: SQLite *requires* host applications to provide the definition of any collation other than binary, nocase and rtrim. When a database file has to be shared or migrated to another SQLite library of platform (such as the Android version of your application), make sure you provide a compatible collation.

If you can't or don't want to define the comparison behavior of a column (see warning above), you can still use an explicit collation in SQL requests and in the [query interface](#the-query-interface):

```swift
let collation = DatabaseCollation.localizedCaseInsensitiveCompare
let persons = try Person.fetchAll(db,
    "SELECT * FROM persons ORDER BY name COLLATE \(collation.name))")
let persons = try Person.order(nameColumn.collating(collation)).fetchAll(db)
```


**You can also define your own collations**:

```swift
let collation = DatabaseCollation("customCollation") { (lhs, rhs) -> NSComparisonResult in
    // return the comparison of lhs and rhs strings.
}
dbQueue.add(collation: collation) // Or dbPool.add(collation: ...)
```


## Memory Management

Both SQLite and GRDB use non-essential memory that help them perform better.

You can reclaim this memory with the `releaseMemory` method:

```swift
// Release as much memory as possible.
dbQueue.releaseMemory()
dbPool.releaseMemory()
```

This method blocks the current thread until all current database accesses are completed, and the memory collected.


### Memory Management on iOS

**The iOS operating system likes applications that do not consume much memory.**

[Database queues](#database-queues) and [pools](#database-pools) can call the `releaseMemory` method for you, when application receives memory warnings, and when application enters background: call the `setupMemoryManagement` method after creating the queue or pool instance:

```
let dbQueue = try DatabaseQueue(...)
dbQueue.setupMemoryManagement(in: UIApplication.sharedApplication())
```


## Concurrency

- [Guarantees and Rules](#guarantees-and-rules)
- [Advanced DatabasePool](#advanced-databasepool)
- [DatabaseWriter and DatabaseReader Protocols](#databasewriter-and-databasereader-protocols)
- [Dealing with External Connections](#dealing-with-external-connections)


### Guarantees and Rules

GRDB ships with two concurrency modes:

- [DatabaseQueue](#database-queues) opens a single database connection, and serializes all database accesses.
- [DatabasePool](#database-pools) manages a pool of several database connections, and allows concurrent reads and writes.

**Both foster application safety**: regardless of the concurrency mode you choose, GRDB provides you with the same guarantees, as long as you follow three rules.

- **Guarantee 1**: writes are always *serialized*. At every moment, there is no more than a single thread that is writing into the database.

- **Guarantee 2**: reads are always *isolated*. This means that you can perform subsequent reads without fearing eventual concurrent writes to mess with your application logic:
    
    ```swift
    try dbPool.read { db in // or dbQueue.inDatabase { ... }
        // Guaranteed to be equal
        let count1 = try Person.fetchCount(db)
        let count2 = try Person.fetchCount(db)
    }
    ```

Those guarantees hold as long as you follow three rules:

- **Rule 1**: Have a unique instance of DatabaseQueue or DatabasePool connected to any database file.
    
    This means that opening a new connection each time you access the database is probably a very bad idea. Do share a single connection instead.
    
    See, for example, [DemoApps/GRDBDemoiOS/Database.swift](DemoApps/GRDBDemoiOS/GRDBDemoiOS/Database.swift) for a sample code that properly sets up a single database queue that is available throughout the application.
    
    If there are several instances of database queues or pools that access the same database, a multi-threaded application will eventually face "database is locked" errors. See [Dealing with External Connections](#dealing-with-external-connections).
    
- **Rule 2**: Group related statements within a single call to the `DatabaseQueue.inDatabase`, `DatabaseQueue.inTransaction`, `DatabasePool.read`, `DatabasePool.write` and `DatabasePool.writeInTransaction` methods.
    
    Those methods isolate your groups of related statements against eventual database updates performed by other threads, and guarantee a consistent view of the database. This isolation is only guaranteed *inside* the closure argument of those methods. Two consecutive calls *do not* guarantee isolation:
    
    ```swift
    // SAFE CONCURRENCY
    try dbPool.read { db in  // or dbQueue.inDatabase { ... }
        // Guaranteed to be equal:
        let count1 = try PointOfInterest.fetchCount(db)
        let count2 = try PointOfInterest.fetchCount(db)
    }
    
    // UNSAFE CONCURRENCY
    // Those two values may be different because some other thread may have
    // modified the database between the two statements:
    let count1 = try dbPool.read { db in try PointOfInterest.fetchCount(db) }
    let count2 = try dbPool.read { db in try PointOfInterest.fetchCount(db) }
    ```

- **Rule 3**: When you perform several modifications of the database that temporarily put the database in an inconsistent state, group those modifications within a [transaction](#transactions-and-savepoints):
    
    ```swift
    // SAFE CONCURRENCY
    try dbPool.writeInTransaction { db in  // or dbQueue.inTransaction { ... }
        try Credit(destinationAccout, amount).insert(db)
        try Debit(sourceAccount, amount).insert(db)
        return .commit
    }
    
    // UNSAFE CONCURRENCY
    try dbPool.write { db in  // or dbQueue.inDatabase { ... }
        try Credit(destinationAccout, amount).insert(db)
        try Debit(sourceAccount, amount).insert(db)
    }
    ```
    
    Without transaction, `DatabasePool.read { ... }` may see the first statement, but not the second, and access a database where the balance of accounts is not zero. A highly bug-prone situation.
    
    So do use [transactions](#transactions-and-savepoints) in order to guarantee database consistency accross your application threads: that's what they are made for.


### Advanced DatabasePool

[Database pools](#database-pools) are very concurrent, since all reads can run in parallel, and can even run during write operations. But writes are still serialized: at any given point in time, there is no more than a single thread that is writing into the database.

When your application modifies the database, and then reads some value that depends on those modifications, you may want to avoid locking the writer queue longer than necessary:

```swift
try dbPool.write { db in
    // Increment the number of persons
    try Person(...).insert(db)
    
    // Read the number of persons. The writer queue is still locked :-(
    let count = try Person.fetchCount(db)
}
```

A wrong solution is to chain a write then a read, as below. Don't do that, because another thread may modify the database in between, and make the read unreliable:

```swift
// WRONG
try dbPool.write { db in
    // Increment the number of persons
    try Person(...).insert(db)
}
try dbPool.read { db in
    // Read some random value :-(
    let count = try Person.fetchCount(db)
}
```

The correct solution is the `readFromCurrentState` method, which must be called from within a write block:

```swift
// CORRECT
try dbPool.write { db in
    // Increment the number of persons
    try Person(...).insert(db)
    
    try dbPool.readFromCurrentState { db
        // Read the number of persons. The writer queue has been unlocked :-)
        let count = try Person.fetchCount(db)
    }
}
```

`readFromCurrentState` blocks until it can guarantee its closure argument an isolated access to the last committed state of the database. It then asynchronously executes the closure.

The closure can run concurrently with eventual updates performed after `readFromCurrentState`: those updates won't be visible from within the closure. In the example below, the number of persons is guaranteed to be non-zero, even though it is fetched concurrently with the person deletion:

```swift
try dbPool.write { db in
    // Increment the number of persons
    try Person(...).insert(db)
    
    try dbPool.readFromCurrentState { db
        // Guaranteed to be non-zero
        let count = try Person.fetchCount(db)
    }
    
    try Person.deleteAll(db)
}
```

[Transaction Observers](#database-changes-observation) can also use `readFromCurrentState` in their `databaseDidCommit` method in order to process database changes without blocking other threads that want to write into the database.


### DatabaseWriter and DatabaseReader Protocols

Both DatabaseQueue and DatabasePool adopt the [DatabaseReader](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Protocols/DatabaseReader.html) and [DatabaseWriter](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Protocols/DatabaseWriter.html) protocols.

Those protocols provide a unified API that lets you write safe concurrent code that targets both classes.


### Dealing with External Connections

The first rule of GRDB is:

- **[Rule 1](#guarantees-and-rules)**: Have a unique instance of DatabaseQueue or DatabasePool connected to any database file.

This means that dealing with external connections is not a focus of GRDB. [Guarantees](#guarantees-and-rules) of GRDB may or may not hold as soon as some external connection modifies a database.

If you absolutely need multiple connections, then:

- Reconsider your position
- Read about [isolation in SQLite](https://www.sqlite.org/isolation.html)
- Learn about [locks and transactions](https://www.sqlite.org/lang_transaction.html)
- Become a master of the [WAL mode](https://www.sqlite.org/wal.html)
- Prepare to setup a [busy handler](https://www.sqlite.org/c3ref/busy_handler.html) with [Configuration.busyMode](http://cocoadocs.org/docsets/GRDB.swift/0.93.0/Structs/Configuration.html)
- [Ask questions](https://github.com/groue/GRDB.swift/issues)


## Performance

GRDB is a reasonably fast library, and can deliver quite efficient SQLite access. See [Comparing the Performances of Swift SQLite libraries](https://github.com/groue/GRDB.swift/wiki/Performance) for an overview.

You'll find below general advice when you do look after performance:

- Focus
- Know your platform
- Use transactions
- Don't do useless work
- Learn about SQL strengths and weaknesses
- Avoid strings & dictionaries


### Performance tip: focus

You don't know which part of your program needs improvement until you have run a benchmarking tool.

Don't make any assumption, avoid optimizing code too early, and use [Instruments](https://developer.apple.com/library/ios/documentation/ToolsLanguages/Conceptual/Xcode_Overview/MeasuringPerformance.html).


### Performance tip: know your platform

If your application processes a huge JSON file and inserts thousands of rows in the database right from the main thread, it will quite likely become unresponsive, and provide a sub-quality user experience.

If not done yet, read the [Concurrency Programming Guide](https://developer.apple.com/library/ios/documentation/General/Conceptual/ConcurrencyProgrammingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008091) and learn how to perform heavy computations without blocking your application.

Most GRBD APIs are [synchronous](#database-connections). Spawning them into parallel queues is as easy as:

```swift
DispatchQueue.global().async { 
    dbQueue.inDatabase { db in
        // Perform database work
    }
    DispatchQueue.main.async { 
        // update your user interface
    }
}
```


### Performance tip: use transactions

Performing multiple updates to the database is much faster when executed inside a [transaction](#transactions-and-savepoints). This is because a transaction allows SQLite to postpone writing changes to disk until the final commit:

```swift
// Inefficient
try dbQueue.inDatabase { db in
    for person in persons {
        try person.insert(db)
    }
}

// Efficient
try dbQueue.inTransaction { db in
    for person in persons {
        try person.insert(db)
    }
    return .Commit
}
```


### Performance tip: don't do useless work

Obviously, no code is faster than any code.


**Don't fetch columns you don't use**

```swift
// SELECT * FROM persons
try Person.fetchAll(db)

// SELECT id, name FROM persons
try Person.select(idColumn, nameColumn).fetchAll(db)
```

If your Person type can't be built without other columns (it has non-optional properties for other columns), *do define and use a different type*.


**Don't fetch rows you don't use**

Use [fetchOne](#fetching-methods) when you need a single value, and otherwise limit your queries at the database level:

```swift
// Wrong way: this code may discard hundreds of useless database rows
let persons = try Person.order(scoreColumn.desc).fetchAll(db)
let hallOfFame = persons.prefix(5)

// Better way
let hallOfFame = try Person.order(scoreColumn.desc).limit(5).fetchAll(db)
```


**Don't copy values unless necessary**

Particularly: the Array returned by the `fetchAll` method, and the cursor returned by `fetchCursor` aren't the same:

`fetchAll` copies all values from the database into memory, when `fetchCursor` iterates database results as they are generated by SQLite, taking profit from SQLite efficiency.

You should only load arrays if you need to keep them for later use (such as iterating their contents in the main thread). Otherwise, use `fetchCursor`.

See [fetching methods](#fetching-methods) for more information about `fetchAll` and `fetchCursor`. See also the [Row.dataNoCopy](#data-and-memory-savings) method.


**Don't update rows unless necessary**

An UPDATE statement is costly: SQLite has to look for the updated row, update values, and write changes to disk.

When the overwritten values are the same as the existing ones, it's thus better to avoid performing the UPDATE statement.

The [Record](#record-class) class can help you: it provides [changes tracking](#changes-tracking):

```swift
if person.hasPersistentChangedValues {
    try person.update(db)
}
```


### Performance tip: learn about SQL strengths and weaknesses

Consider a simple use case: your store application has to display a list of authors with the number of available books:

- J. M. Coetzee (6)
- Herman Melville (1)
- Alice Munro (3)
- Kim Stanley Robinson (7)
- Oliver Sacks (4)

The following code is inefficient. It is an example of the [N+1 problem](http://stackoverflow.com/questions/97197/what-is-the-n1-selects-issue), because it performs one query to load the authors, and then N queries, as many as there are authors. This turns very inefficient as the number of authors grows:

```swift
// SELECT * FROM authors
let authors = try Author.fetchAll(db)
for author in authors {
    // SELECT COUNT(*) FROM books WHERE authorId = ...
    author.bookCount = try Book.filter(authorIdColumn == author.id).fetchCount(db)
}
```

Instead, perform *a single query*:

```swift
let sql = "SELECT authors.*, COUNT(books.id) AS bookCount " +
          "FROM authors " +
          "LEFT JOIN books ON books.authorId = authors.id " +
          "GROUP BY authors.id"
let authors = try Author.fetchAll(db, sql)
```

In the example above, consider extending your Author with an extra bookCount property, or define and use a different type.

Generally, define indexes on your database tables, and use SQLite's efficient query planning:

- [Query Planning](https://www.sqlite.org/queryplanner.html)
- [CREATE INDEX](https://www.sqlite.org/lang_createindex.html)
- [The SQLite Query Planner](https://www.sqlite.org/optoverview.html)
- [EXPLAIN QUERY PLAN](https://www.sqlite.org/eqp.html)


### Performance tip: avoid strings & dictionaries

The String and Dictionary Swift types are better avoided when you look for the best performance.

Now GRDB [records](#records), for your convenience, do use strings and dictionaries:

```swift
class Person : Record {
    var id: Int64?
    var name: String
    var email: String
    
    required init(_ row: Row) {
        id = row.value(named: "id")       // String
        name = row.value(named: "name")   // String
        email = row.value(named: "email") // String
        super.init()
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name, "email": email] // Dictionary
    }
}
```

When convenience hurts performance, you can still use records, but you have better avoiding their string and dictionary-based methods.

For example, when fetching values, prefer loading columns by index:

```swift
// Strings & dictionaries
let persons = try Person.fetchAll(db)

// Column indexes
// SELECT id, name, email FROM persons
let request = Person.select(idColumn, nameColumn, emailColumn)
let rows = try Row.fetchCursor(db, request)
while let row = try rows.next() {
    let id: Int64 = row.value(atIndex: 0)
    let name: String = row.value(atIndex: 1)
    let email: String = row.value(atIndex: 2)
    let person = Person(id: id, name: name, email: email)
    ...
}
```

When inserting values, use reusable [prepared statements](#prepared-statements), and set statements values with an *array*:

```swift
// Strings & dictionaries
for person in persons {
    try person.insert(db)
}

// Prepared statement
let insertStatement = db.prepareStatement("INSERT INTO persons (name, email) VALUES (?, ?)")
for person in persons {
    // Only use the unsafe arguments setter if you are sure that you provide
    // all statement arguments. A mistake can store unexpected values in
    // the database.
    insertStatement.unsafeSetArguments([person.name, person.email])
    try insertStatement.execute()
}
```


FAQ
===

- [How do I close a database connection?](#how-do-i-close-a-database-connection)
- [How do I open a database stored as a resource of my application?](#how-do-i-open-a-database-stored-as-a-resource-of-my-application)
- [Generic parameter 'T' could not be inferred](#generic-parameter-t-could-not-be-inferred)
- [Compilation takes a long time](#compilation-takes-a-long-time) 


### How do I close a database connection?
    
The short answer is:

```swift
// Eventually close all database connections
dbQueue = nil
dbPool = nil
```

You do not explicitely close a database connection: it is managed by a [database queue](#database-queues) or [pool](#database-pools). The connection is closed when all usages of this connection are completed, and when its database queue or pool gets deallocated.

Database accesses that run in background threads postpone the closing of connections.

The `releaseMemory` method of DatabasePool ([documentation](#memory-management)) will actually close some connections, but the pool will open another connection as soon as you access the database again.


### How do I open a database stored as a resource of my application?

If your application does not need to modify the database, open a read-only [connection](#database-connections) to your resource:

```swift
var configuration = Configuration()
configuration.readonly = true
let dbPath = Bundle.main.path(forResource: "db", ofType: "sqlite")!
let dbQueue = try DatabaseQueue(path: dbPath, configuration: configuration)
```

If the application should modify the database, you need to copy it to a place where it can be modified. For example, in the Documents folder. Only then, open a [connection](#database-connections):

```swift
let fm = FileManager.default
let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
let dbPath = (documentsPath as NSString).appendingPathComponent("db.sqlite")
if !fm.fileExists(atPath: dbPath) {
    let dbResourcePath = Bundle.main.path(forResource: "db", ofType: "sqlite")!
    try fm.copyItem(atPath: dbResourcePath, toPath: dbPath)
}
let dbQueue = try DatabaseQueue(path: dbPath)
```


### Generic parameter 'T' could not be inferred
    
You may get this error when using DatabaseQueue.inDatabase, DatabasePool.read, or DatabasePool.write:

```swift
// Generic parameter 'T' could not be inferred
let x = try dbQueue.inDatabase { db in
    let result = try String.fetchOne(db, ...)
    return result
}
```

This is a Swift compiler issue (see [SR-1570](https://bugs.swift.org/browse/SR-1570)).

The general workaround is to explicitly declare the type of the closure result:

```swift
// General Workaround
let string = try dbQueue.inDatabase { db -> String? in
    let result = try String.fetchOne(db, ...)
    return result
}
```

You can also, when possible, write a single-line closure:

```swift
// Single-line closure workaround:
let string = try dbQueue.inDatabase { db in
    try String.fetchOne(db, ...)
}
```


### Compilation takes a long time
    
When your [record type](#records) is very slow to compile, it is usually because its `persistentDictionary` property builds a long dictionary literal:

```swift
var persistentDictionary: [String: DatabaseValueConvertible?] {
    // Long dictionary literals are slow to compile
    return [
        "a": a,
        "b": b,
        ...
}
```

That's annoying, but the Swift compiler finds it difficult to compile such a dictionary. We can only hope that compiler improves over time.

To speed up compilation, build your dictionary step by step:

```swift
var persistentDictionary: [String: DatabaseValueConvertible?] {
    var dict: [String: DatabaseValueConvertible?] = [:]
    dict.updateValue(a, forKey: "a")
    dict.updateValue(b, forKey: "b")
    ...
    return dict
}
```

> :point_up: **Note**: it is important that you use the `updateValue` method, and not the subscript setter:
> 
> ```swift
> // GOOD
> dict.updateValue(a, forKey: "a")
> // BAD: when the value is nil, this erases the key instead of setting it to nil.
> dict["a"] = a
> ```


Sample Code
===========

- The [Documentation](#documentation) is full of GRDB snippets.
- [GRDBDemoiOS](DemoApps/GRDBDemoiOS): A sample iOS application.
- [WWDC Companion](https://github.com/groue/WWDCCompanion): A sample iOS application.
- Check `GRDB.xcworkspace`: it contains GRDB-enabled playgrounds to play with.
- How to synchronize a database table with a JSON payload: [JSONSynchronization.playground](Playgrounds/JSONSynchronization.playground/Contents.swift)
- How to notify view controllers of database changes: [TableChangeObserver.swift](https://gist.github.com/groue/2e21172719e634657dfd)


---

**Thanks**

- [Pierlis](http://pierlis.com), where we write great software.
- [Vladimir Babin](https://github.com/Chiliec), [Pascal Edmond](https://github.com/pakko972), [Cristian Filipov](https://github.com/cfilipov), [@peter-ss](https://github.com/peter-ss), [Pierre-Loïc Raynaud](https://github.com/pierlo), [Steven Schveighoffer](https://github.com/schveiguy), [@swiftlyfalling](https://github.com/swiftlyfalling), and [Kevin Wooten](https://github.com/kdubb) for their contributions, help, and feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [Mathieu "Kali" Poumeyrol](https://github.com/kali) because SQL.
- [ccgus/fmdb](https://github.com/ccgus/fmdb) for its excellency.
