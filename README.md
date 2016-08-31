GRDB.swift [![Swift](https://img.shields.io/badge/swift-2.2-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/GRDB.swift.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/groue/GRDB.swift.svg?maxAge=2592000)](/LICENSE)
==========

### A Swift application toolkit for SQLite databases.

**Latest release**: August 17, 2016 &bull; version 0.79.4 &bull; [CHANGELOG](CHANGELOG.md)

**Requirements**: iOS 8.0+ / OSX 10.9+ &bull; Xcode 7.3+ &bull; Swift 2.2 (see the [Swift3](https://github.com/groue/GRDB.swift/tree/Swift3) branch for Swift 3).

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

GRDB ships with a **low-level SQLite API**, and high-level tools that help dealing with databases:

- **Records**: fetching and persistence methods for your custom structs and class hierarchies
- **Query Interface**: a swift way to avoid the SQL language
- **WAL Mode Support**: that means extra performance for multi-threaded applications
- **Migrations**: transform your database as your application evolves
- **Database Changes Observation**: perform post-commit and post-rollback actions
- **Fetched Records Controller**: automated tracking of changes in a query results, and UITableView animations
- **Encryption** with SQLCipher
- **Support for custom SQLite builds**

More than a set of tools that leverage SQLite abilities, GRDB is also:

- **Safer**: read the blog post [Four different ways to handle SQLite concurrency](https://medium.com/@gwendal.roue/four-different-ways-to-handle-sqlite-concurrency-db3bcc74d00e)
- **Faster**: see [Comparing the Performances of Swift SQLite libraries](https://github.com/groue/GRDB.swift/wiki/Performance)
- Well documented & tested

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
dbQueue.inDatabase { db in
    for row in Row.fetch(db, "SELECT * FROM pointOfInterests") {
        let title: String = row.value(named: "title")
        let favorite: Bool = row.value(named: "favorite")
        let coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),
            row.value(named: "longitude"))
    }

    let poiCount = Int.fetchOne(db, "SELECT COUNT(*) FROM pointOfInterests")! // Int
    let poiTitles = String.fetchAll(db, "SELECT title FROM pointOfInterests") // [String]
}

// Extraction
let poiCount = dbQueue.inDatabase { db in
    Int.fetchOne(db, "SELECT COUNT(*) FROM pointOfInterests")!
}
```

Insert and fetch [records](#records):

```swift
struct PointOfInterest {
    var id: Int64?
    var title: String
    var favorite: Bool
    var coordinate: CLLocationCoordinate2D
}

// snip: turn PointOfInterest into a "record" by adopting the protocols that
// provide fetching and persistence methods.

try dbQueue.inDatabase { db in
    var berlin = PointOfInterest(
        id: nil,
        title: "Berlin",
        favorite: false,
        coordinate: CLLocationCoordinate2DMake(52.52437, 13.41053))
    
    try berlin.insert(db)
    berlin.id // some value
    
    berlin.favorite = true
    try berlin.update(db)
    
    // Fetch [PointOfInterest] from SQL
    let pois = PointOfInterest.fetchAll(db, "SELECT * FROM pointOfInterests")
}
```

Avoid SQL with the [query interface](#the-query-interface):

```swift
dbQueue.inDatabase { db in
    try db.create(table: "pointOfInterests") { t in
        t.column("id", .Integer).primaryKey()
        t.column("title", .Text).notNull()
        t.column("favorite", .Boolean).notNull().defaults(to: false)
        t.column("longitude", .Double).notNull()
        t.column("latitude", .Double).notNull()
    }
    
    // PointOfInterest?
    let paris = PointOfInterest.fetchOne(db, key: 1)
    
    // PointOfInterest?
    let titleColumn = SQLColumn("title")
    let berlin = PointOfInterest.filter(titleColumn == "Berlin").fetchOne(db)
    
    // [PointOfInterest]
    let favoriteColumn = SQLColumn("favorite")
    let favoritePois = PointOfInterest
        .filter(favoriteColumn)
        .order(titleColumn)
        .fetchAll(db)
}
```


Documentation
=============

**GRDB runs on top of SQLite**: you should get familiar with the [SQLite FAQ](http://www.sqlite.org/faq.html). For general and detailed information, jump to the [SQLite Documentation](http://www.sqlite.org/docs.html).

**Reference**

- [GRDB Reference](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/index.html) (on cocoadocs.org)

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
- [Database Changes Observation](#database-changes-observation): Perform post-commit and post-rollback actions.
- [FetchedRecordsController](#fetchedrecordscontroller): Automatic database changes tracking, plus UITableView animations.
- [Encryption](#encryption): Encrypt your database with SQLCipher.
- [Backup](#backup): Dump the content of a database to another.

**Good to Know**

- [Avoiding SQL Injection](#avoiding-sql-injection)
- [Error Handling](#error-handling)
- [Unicode](#unicode)
- [Memory Management](#memory-management)
- [Concurrency](#concurrency)
- [Performance](#performance)

[FAQ](#faq)

[Sample Code](#sample-code)


### Installation

#### CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Xcode projects.

To use GRDB with CocoaPods, specify in your Podfile:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

pod 'GRDB.swift'
```

> :point_up: **Note**: [SQLCipher](#encryption) and [custom SQLite builds](#custom-sqlite-builds) are not available via CocoaPods.


#### Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency manager for Xcode projects.

To use GRDB with Carthage, specify in your Cartfile:

```
github "groue/GRDB.swift"
```

> :point_up: **Note**: [custom SQLite builds](#custom-sqlite-builds) are not available via Carthage.


#### Manually

1. Download a copy of GRDB.swift.
2. Embed the `GRDB.xcodeproj` project in your own project.
3. Add the `GRDBOSX` or `GRDBiOS` target in the **Target Dependencies** section of the **Build Phases** tab of your application target.
4. Add `GRDB.framework` to the **Embedded Binaries** section of the **General**  tab of your target.

See [GRDBDemoiOS](DemoApps/GRDBDemoiOS) for an example of such integration.


#### Custom SQLite builds

**By default, GRDB uses the SQLite library that ships with the operating system.** You can build GRDB with custom SQLite sources and options, through [swiftlyfalling/SQLiteLib](https://github.com/swiftlyfalling/SQLiteLib). See [installation instructions](SQLiteCustom/README.md).


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
    if let poi = PointOfInterest.fetchOne(db, key: 1) {
        try poi.delete(db)
    }
    return .Commit
}

// Read values:
dbQueue.inDatabase { db in
    let pois = PointOfInterest.fetchAll(db)
    let poiCount = PointOfInterest.fetchCount(db)
}

// Extract a value from the database:
let poiCount = dbQueue.inDatabase { db in
    PointOfInterest.fetchCount(db)
}
```


**Your application should create a single DatabaseQueue per database file.** See, for example, [DemoApps/GRDBDemoiOS/Database.swift](DemoApps/GRDBDemoiOS/GRDBDemoiOS/Database.swift) for a sample code that properly sets up a single database queue that is available throughout the application.

If you do otherwise, you may well experience concurrency issues, and you don't want that. See [Concurrency](#concurrency) for more information.


**Configure database queues:**

```swift
var config = Configuration()
config.readonly = true
config.foreignKeysEnabled = true // The default is already true
config.trace = { print($0) }     // Prints all SQL statements
config.fileAttributes = [NSFileProtectionKey: ...]  // Configure database protection

let dbQueue = try DatabaseQueue(
    path: "/path/to/database.sqlite",
    configuration: config)
```

See [Configuration](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/Structs/Configuration.html) for more details.


## Database Pools

[Database Queues](#database-queues) are simple, but they prevent concurrent accesses: at every moment, there is no more than a single thread that is using the database.

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
    if let poi = PointOfInterest.fetchOne(db, key: 1) {
        try poi.delete(db)
    }
    return .Commit
}

// Read values:
dbPool.read { db in
    let pois = PointOfInterest.fetchAll(db)
    let poiCount = PointOfInterest.fetchCount(db)
}

// Extract a value from the database:
let poiCount = dbPool.read { db in
    PointOfInterest.fetchCount(db)
}
```


**Your application should create a single DatabasePool per database file.**

If you do otherwise, you may well experience concurrency issues, and you don't want that. See [Concurrency](#concurrency) for more information.


**Database pools allows several threads to access the database at the same time:**

- When you don't need to modify the database, prefer the `read` method, because several threads can perform reads in parallel.

- The total number of concurrent reads is limited. When the maximum number has been reached, a read waits for another read to complete. That maximum number can be configured (see below).

- Conversely, writes are serialized. They still can happen in parallel with reads, but GRDB makes sure that those parallel writes are not visible inside a `read` closure.

See [Concurrency](#concurrency) for more information.


**Configure database pools:**

```swift
var config = Configuration()
config.readonly = true
config.foreignKeysEnabled = true // The default is already true
config.trace = { print($0) }     // Prints all SQL statements
config.fileAttributes = [NSFileProtectionKey: ...]  // Configure database protection
config.maximumReaderCount = 10   // The default is 5

let dbPool = try DatabasePool(
    path: "/path/to/database.sqlite",
    configuration: config)
```

See [Configuration](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/Structs/Configuration.html) for more details.


Database pools are more memory-hungry than database queues. See [Memory Management](#memory-management) for more information.


SQLite API
==========

**In this section of the documentation, we will talk SQL only.** Jump to the [query interface](#the-query-interface) if SQL if not your cup of tea.

- [Executing Updates](#executing-updates)
- [Fetch Queries](#fetch-queries)
    - [Fetching Methods](#fetching-methods)
    - [Row Queries](#row-queries)
    - [Value Queries](#value-queries)
- [Values](#values)
    - [NSData](#nsdata-and-memory-savings)
    - [NSDate and NSDateComponents](#nsdate-and-nsdatecomponents)
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

The `?` and colon-prefixed keys like `:name` in the SQL query are the **statements arguments**. You pass arguments with arrays or dictionaries, as in the example above. See [Values](#values) for more information on supported arguments types (Bool, Int, String, NSDate, Swift enums, etc.).

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
if let row = Row.fetchOne(db, "SELECT * FROM wines WHERE id = ?", arguments: [1]) {
    let name: String = row.value(named: "name")
    let color: Color = row.value(named: "color")
    print(name, color)
}
```


**Values** are the Bool, Int, String, NSDate, Swift enums, etc. stored in row columns:

```swift
for url in NSURL.fetch(db, "SELECT url FROM wines") {
    print(url)
}
```


**Records** are your application objects that can initialize themselves from rows:

```swift
let wines = Wine.fetchAll(db, "SELECT * FROM wines")
```

- [Fetching Methods](#fetching-methods)
- [Row Queries](#row-queries)
- [Value Queries](#value-queries)
- [Records](#records)


### Fetching Methods

**Throughout GRDB**, you can always fetch *sequences*, *arrays*, or *single values* of any fetchable type (database [row](#row-queries), simple [value](#value-queries), or custom [record](#records)):

```swift
Type.fetch(...)    // DatabaseSequence<Type>
Type.fetchAll(...) // [Type]
Type.fetchOne(...) // Type?
```

- `fetch` returns a **sequence** that is memory efficient, but must be consumed in a protected dispatch queue (you'll get a fatal error if you do otherwise).
    
    ```swift
    for row in Row.fetch(db, "SELECT ...") { // DatabaseSequence<Row>
        ...
    }
    ```
    
    Don't modify the database during a sequence iteration:
    
    ```swift
    // Undefined behavior
    for row in Row.fetch(db, "SELECT * FROM persons") {
        try db.execute("DELETE FROM persons ...")
    }
    ```
    
    A sequence fetches a new set of results each time it is iterated.
    
- `fetchAll` returns an **array** that can be consumed on any thread. It contains copies of database values, and can take a lot of memory:
    
    ```swift
    let persons = Person.fetchAll(db, "SELECT ...") // [Person]
    ```

- `fetchOne` returns a **single optional value**, and consumes a single database row (if any).
    
    ```swift
    let count = Int.fetchOne(db, "SELECT COUNT(*) ...") // Int?
    ```


### Row Queries

- [Fetching Rows](#fetching-rows)
- [Column Values](#column-values)
- [DatabaseValue](#databasevalue)
- [Rows as Dictionaries](#rows-as-dictionaries)


#### Fetching Rows

Fetch **sequences** of rows, **arrays**, or **single** rows (see [fetching methods](#fetching-methods)):

```swift
Row.fetch(db, "SELECT ...", arguments: ...)     // DatabaseSequence<Row>
Row.fetchAll(db, "SELECT ...", arguments: ...)  // [Row]
Row.fetchOne(db, "SELECT ...", arguments: ...)  // Row?

for row in Row.fetch(db, "SELECT * FROM wines") {
    let name: String = row.value(named: "name")
    let color: Color = row.value(named: "color")
    print(name, color)
}
```

Arguments are optional arrays or dictionaries that fill the positional `?` and colon-prefixed keys like `:name` in the query:

```swift
let rows = Row.fetchAll(db,
    "SELECT * FROM persons WHERE name = ?",
    arguments: ["Arthur"])

let rows = Row.fetchAll(db,
    "SELECT * FROM persons WHERE name = :name",
    arguments: ["name": "Arthur"])
```

See [Values](#values) for more information on supported arguments types (Bool, Int, String, NSDate, Swift enums, etc.).

Unlike row arrays that contain copies of the database rows, row sequences are close to the SQLite metal, and require a little care:

> :point_up: **Don't turn a row sequence into an array** with `Array(rowSequence)` or `rowSequence.filter { ... }`: you would not get the distinct rows you expect. To get an array, use `Row.fetchAll(...)`.
> 
> :point_up: **Make sure you copy a row** whenever you extract it from a sequence for later use: `row.copy()`.


#### Column Values

**Read column values** by index or column name:

```swift
let name: String = row.value(atIndex: 0)    // 0 is the leftmost column
let name: String = row.value(named: "name") // Leftmost matching column - lookup is case-insensitive
let name: String = row.value(nameColumn)    // Using query interface's SQLColumn
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
let date: NSDate       = row.value(named: "date")       // NSDate
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
    - Blob SQLite values to NSData.
    
    See [Values](#values) for more information on supported types (Bool, Int, String, NSDate, Swift enums, etc.)

- **NULL returns nil.**

    ```swift
    let row = Row.fetchOne(db, "SELECT NULL")!
    row.value(atIndex: 0) as Int? // nil
    row.value(atIndex: 0) as Int  // fatal error: could not convert NULL to Int.
    ```
    
- **Missing columns return nil.**
    
    ```swift
    let row = Row.fetchOne(db, "SELECT 'foo' AS foo")!
    row.value(named: "missing") as String? // nil
    row.value(named: "missing") as String  // fatal error: no such column: missing
    ```
    
    You can explicitly check for a column presence with the `hasColumn` method.

- **Invalid conversions throw a fatal error.**
    
    ```swift
    let row = Row.fetchOne(db, "SELECT 'foo'")!
    row.value(atIndex: 0) as String  // "foo"
    row.value(atIndex: 0) as NSDate? // fatal error: could not convert "foo" to NSDate.
    row.value(atIndex: 0) as NSDate  // fatal error: could not convert "foo" to NSDate.
    ```
    
    This fatal error can be avoided with the [DatabaseValueConvertible.fromDatabaseValue()](#custom-value-types) method.
    
- **SQLite has a weak type system, and provides [convenience conversions](https://www.sqlite.org/c3ref/column_blob.html) that can turn Blob to String, String to Int, etc.**
    
    GRDB will sometimes let those conversions go through:
    
    ```swift
    for row in Row.fetch(db, "SELECT 'foo'") {
        row.value(atIndex: 0) as Int   // 0
    }
    ```
    
    Don't freak out: those conversions did not prevent SQLite from becoming the immensely successful database engine you want to use. And GRDB adds safety checks described just above. You can also prevent those convenience conversions altogether by using the [DatabaseValue](#databasevalue) type.


#### DatabaseValue

**DatabaseValue is an intermediate type between SQLite and your values, which gives information about the raw value stored in the database.**

```swift
let dbv = row.databaseValue(atIndex: 0)    // 0 is the leftmost column
let dbv = row.databaseValue(named: "name") // leftmost matching column - lookup is case-insensitive

// Check for NULL:
dbv.isNull    // Bool

// All the five storage classes supported by SQLite:
switch dbv.storage {
case .Null:                 print("NULL")
case .Int64(let int64):     print("Int64: \(int64)")
case .Double(let double):   print("Double: \(double)")
case .String(let string):   print("String: \(string)")
case .Blob(let data):       print("NSData: \(data)")
}
```

You can extract [values](#values) (Bool, Int, String, NSDate, Swift enums, etc.) from DatabaseValue with the [DatabaseValueConvertible.fromDatabaseValue()](#custom-value-types) method:

```swift
let dbv = row.databaseValue(named: "bookCount")
let bookCount   = Int.fromDatabaseValue(dbv)   // Int?
let bookCount64 = Int64.fromDatabaseValue(dbv) // Int64?
let hasBooks    = Bool.fromDatabaseValue(dbv)  // Bool?, false when 0

let dbv = row.databaseValue(named: "date")
let string = String.fromDatabaseValue(dbv)     // "2015-09-11 18:14:15.123"
let date   = NSDate.fromDatabaseValue(dbv)     // NSDate?
```

`fromDatabaseValue` returns nil for invalid conversions:

```swift
let row = Row.fetchOne(db, "SELECT 'foo'")!
let dbv = row.databaseValue(at: 0)
let string = String.fromDatabaseValue(dbv) // "foo"
let int    = Int.fromDatabaseValue(dbv)    // nil
let date   = NSDate.fromDatabaseValue(dbv) // nil
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
let row = Row(nsDictionary) // nil if invalid NSDictionary
```

Yet rows are not real dictionaries: they are ordered, and may contain duplicate keys:

```swift
let row = Row.fetchOne(db, "SELECT 1 AS foo, 2 AS foo")!
row.columnNames     // ["foo", "foo"]
row.databaseValues  // [1, 2]
row.databaseValue(named: "foo") // 1 (the value for the leftmost column "foo")
for (columnName, databaseValue) in row { ... } // ("foo", 1), ("foo", 2)
```


### Value Queries

Instead of rows, you can directly fetch **[values](#values)**. Like rows, fetch them as **sequences**, **arrays**, or **single** values (see [fetching methods](#fetching-methods)). Values are extracted from the leftmost column of the SQL queries:

```swift
Int.fetch(db, "SELECT ...", arguments: ...)     // DatabaseSequence<Int>
Int.fetchAll(db, "SELECT ...", arguments: ...)  // [Int]
Int.fetchOne(db, "SELECT ...", arguments: ...)  // Int?

// When database may contain NULL:
Optional<Int>.fetch(db, "SELECT ...", arguments: ...)    // DatabaseSequence<Int?>
Optional<Int>.fetchAll(db, "SELECT ...", arguments: ...) // [Int?]
```

`fetchOne` returns an optional value which is nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value.

There are many supported value types (Bool, Int, String, NSDate, Swift enums, etc.). See [Values](#values) for more information:

```swift
let count = Int.fetchOne(db, "SELECT COUNT(*) FROM persons")! // Int
let urls = NSURL.fetchAll(db, "SELECT url FROM links")        // [NSURL]
```


## Values

GRDB ships with built-in support for the following value types:

- **Swift Standard Library**: Bool, Double, Float, Int, Int32, Int64, String, [Swift enums](#swift-enums).
    
- **Foundation**: [NSData](#nsdata-and-memory-savings), [NSDate](#nsdate-and-nsdatecomponents), [NSDateComponents](#nsdate-and-nsdatecomponents), NSNull, [NSNumber](#nsnumber-and-nsdecimalnumber), NSString, NSURL, [NSUUID](#nsuuid).
    
- **CoreGraphics**: CGFloat.

- Generally speaking, all types that adopt the [DatabaseValueConvertible](#custom-value-types) protocol.

Values can be used as [statement arguments](#executing-updates):

```swift
let url: NSURL = ...
let verified: Bool = ...
try db.execute(
    "INSERT INTO links (url, verified) VALUES (?, ?)",
    arguments: [url, verified])
```

Values can be [extracted from rows](#column-values):

```swift
for row in Row.fetch(db, "SELECT * FROM links") {
    let url: NSURL = row.value(named: "url")
    let verified: Bool = row.value(named: "verified")
}
```

Values can be [directly fetched](#value-queries):

```swift
let urls = NSURL.fetchAll(db, "SELECT url FROM links")  // [NSURL]
```

Use values in [Records](#records):

```swift
class Link : Record {
    var url: NSURL
    var verified: Bool
    
    required init(_ row: Row) {
        url = row.value(named: "url")
        verified = row.value(named: "verified")
        super.init(row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["url": url, "verified": verified]
    }
}
```

Use values in the [query interface](#the-query-interface):

```swift
let url: NSURL = ...
let link = Link.filter(urlColumn == url).fetchOne(db)
```


### NSData (and Memory Savings)

**NSData** suits the BLOB SQLite columns. It can be stored and fetched from the database just like other [value types](#values).

Yet, when extracting NSData from a row, **you have the opportunity to save memory by not copying the data fetched by SQLite**, using the `dataNoCopy()` method:

```swift
for row in Row.fetch(db, "SELECT data, ...") {
    let data = row.dataNoCopy(named: "data")     // NSData?
}
```

> :point_up: **Note**: the non-copied data does not live longer than the iteration step: make sure that you do not use it past this point.

Compare with the **anti-patterns** below:

```swift
for row in Row.fetch(db, "SELECT data, ...") {
    // This data is copied:
    let data: NSData = row.value(named: "data")
    
    // This data is copied:
    if let databaseValue = row.databaseValue(named: "data") {
        let data: NSData = databaseValue.value()
    }
    
    // This data is copied:
    let copiedRow = row.copy()
    let data = copiedRow.dataNoCopy(named: "data")
}

// All rows have been copied when the loop begins:
let rows = Row.fetchAll(db, "SELECT data, ...") // [Row]
for row in rows {
    // Too late to do the right thing:
    let data = row.dataNoCopy(named: "data")
}
```


### NSDate and NSDateComponents

[**NSDate**](#nsdate) and [**NSDateComponents**](#nsdatecomponents) can be stored and fetched from the database.

Here is the support provided by GRDB for the various [date formats](https://www.sqlite.org/lang_datefunc.html) supported by SQLite:

| SQLite format                | NSDate       | NSDateComponents |
|:---------------------------- |:------------:|:----------------:|
| YYYY-MM-DD                   |     Read ¹   |    Read/Write    |
| YYYY-MM-DD HH:MM             |     Read ¹   |    Read/Write    |
| YYYY-MM-DD HH:MM:SS          |     Read ¹   |    Read/Write    |
| YYYY-MM-DD HH:MM:SS.SSS      | Read/Write ¹ |    Read/Write    |
| YYYY-MM-DD**T**HH:MM         |     Read ¹   |       Read       |
| YYYY-MM-DD**T**HH:MM:SS      |     Read ¹   |       Read       |
| YYYY-MM-DD**T**HH:MM:SS.SSS  |     Read ¹   |       Read       |
| HH:MM                        |              |    Read/Write    |
| HH:MM:SS                     |              |    Read/Write    |
| HH:MM:SS.SSS                 |              |    Read/Write    |
| Julian Day Number            |     Read ²   |                  |
| `now`                        |              |                  |

¹ NSDates are stored and read in the UTC time zone. Missing components are assumed to be zero.

² See https://en.wikipedia.org/wiki/Julian_day


#### NSDate

**NSDate** can be stored and fetched from the database just like other [value types](#values):

```swift
try db.execute(
    "INSERT INTO persons (creationDate, ...) VALUES (?, ...)",
    arguments: [NSDate(), ...])

let creationDate: NSDate = row.value(named: "creationDate")
```

Dates are stored using the format "YYYY-MM-DD HH:MM:SS.SSS" in the UTC time zone. It is precise to the millisecond.

> :point_up: **Note**: this format was chosen because it is the only format that is:
> 
> - Comparable (`ORDER BY date` works)
> - Comparable with the SQLite keyword NOW (`WHERE date > NOW` works)
> - Able to feed [SQLite date & time functions](https://www.sqlite.org/lang_datefunc.html)
> - Precise enough
> 
> Yet this format may not fit your needs. For example, you may want to store dates as timestamps. In this case, store and load Doubles instead of Date, and perform the required conversions.


#### NSDateComponents

NSDateComponents is indirectly supported, through the **DatabaseDateComponents** helper type.

DatabaseDateComponents reads date components from all [date formats supported by SQLite](https://www.sqlite.org/lang_datefunc.html), and stores them in the format of your choice, from HH:MM to YYYY-MM-DD HH:MM:SS.SSS.

DatabaseDateComponents can be stored and fetched from the database just like other [value types](#values):

```swift
let components = NSDateComponents()
components.year = 1973
components.month = 9
components.day = 18

// Store "1973-09-18"
let dbComponents = DatabaseDateComponents(components, format: .YMD)
try db.execute(
    "INSERT INTO persons (birthDate, ...) VALUES (?, ...)",
    arguments: [dbComponents, ...])

// Read "1973-09-18"
let row = Row.fetchOne(db, "SELECT birthDate ...")!
let dbComponents: DatabaseDateComponents = row.value(named: "birthDate")
dbComponents.format         // .YMD (the actual format found in the database)
dbComponents.dateComponents // NSDateComponents
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
let sum = NSDecimalNumber.fetchOne(db, "SELECT SUM(amount) FROM transfers")!

// Yikes! 0.3000000000000000512
print(sum)
```

Don't blame SQLite or GRDB, and instead store your decimal numbers differently.

A classic technique is to store *integers* instead, since SQLite performs exact computations of integers. For example, don't store Euros, but store cents instead:

```swift
// Store
let amount = NSDecimalNumber(string: "0.1")                            // 0.1
let integer = amount                                                   // 100
    .decimalNumberByMultiplyingByPowerOf10(2)
    .longLongValue
// INSERT INTO transfers (amount) VALUES (100)
try db.execute("INSERT INTO transfers (amount) VALUES (?)", arguments: [integer])

// Read
let integer = Int64.fetchOne(db, "SELECT SUM(amount) FROM transfers")! // 100
let amount = NSDecimalNumber(longLong: integer)                        // 0.1
    .decimalNumberByMultiplyingByPowerOf10(-2)
```


### NSUUID

**NSUUID** can be stored and fetched from the database just like other [values](#values). GRDB stores uuids as 16-bytes data blobs.


### Swift Enums

**Swift enums** and generally all types that adopt the [RawRepresentable](https://developer.apple.com/library/tvos/documentation/Swift/Reference/Swift_RawRepresentable_Protocol/index.html) protocol can be stored and fetched from the database just like their raw [values](#values):

```swift
enum Color : Int {
    case Red, White, Rose
}

enum Grape : String {
    case Chardonnay, Merlot, Riesling
}

// Declare empty DatabaseValueConvertible adoption
extension Color : DatabaseValueConvertible { }
extension Grape : DatabaseValueConvertible { }

// Store
try db.execute(
    "INSERT INTO wines (grape, color) VALUES (?, ?)",
    arguments: [Grape.Merlot, Color.Red])

// Read
for rows in Row.fetch(db, "SELECT * FROM wines") {
    let grape: Grape = row.value(named: "grape")
    let color: Color = row.value(named: "color")
}
```

**When a database value does not match any enum case**, you get a fatal error. This fatal error can be avoided with the [DatabaseValueConvertible.fromDatabaseValue()](#custom-value-types) method:

```swift
let row = Row.fetchOne(db, "SELECT 'Syrah'")!

row.value(atIndex: 0) as String  // "Syrah"
row.value(atIndex: 0) as Grape?  // fatal error: could not convert "Syrah" to Grape.
row.value(atIndex: 0) as Grape   // fatal error: could not convert "Syrah" to Grape.

let dbv = row.databaseValue(atIndex: 0)
String.fromDatabaseValue(dbv) // "Syrah"
Grape.fromDatabaseValue(dbv)  // nil
```


## Transactions and Savepoints

The `DatabaseQueue.inTransaction()` and `DatabasePool.writeInTransaction()` methods open an SQLite transaction and run their closure argument in a protected dispatch queue. They block the current thread until your database statements are executed:

```swift
try dbQueue.inTransaction { db in
    let wine = Wine(color: .Red, name: "Pomerol")
    try wine.insert(db)
    return .Commit
}
```

If an error is thrown within the transaction body, the transaction is rollbacked and the error is rethrown by the `inTransaction` method. If you return `.Rollback` from your closure, the transaction is also rollbacked, but no error is thrown.

If you want to insert a transaction between other database statements, you can use the Database.inTransaction() function:

```swift
try dbQueue.inDatabase { db in  // or dbPool.write { db in
    ...
    try db.inTransaction {
        ...
        return .Commit
    }
    ...
}
```

You can ask a database if a transaction is currently opened:

```swift
func myCriticalMethod(db: Database) throws {
    precondition(db.isInsideTransaction, "This method requires a transaction")
    try ...
}
```

Yet, you have a better option than checking for transactions: critical sections of your application should use savepoints, described below:

```swift
func myCriticalMethod(db: Database) throws {
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
        return .Commit
    }
    
    // Other savepoints, etc...
    return .Commit
}
```

If an error is thrown within the savepoint body, the savepoint is rollbacked and the error is rethrown by the `inSavepoint` method. If you return `.Rollback` from your closure, the body is also rollbacked, but no error is thrown.

**Unlike transactions, savepoints can be nested.** They implicitly open a transaction if no one was opened when the savepoint begins. As such, they behave just like nested transactions. Yet the database changes are only committed to disk when the outermost savepoint is committed:

```swift
try dbQueue.inDatabase { db in
    try db.inSavepoint {
        ...
        try db.inSavepoint {
            ...
            return .Commit
        }
        ...
        return .Commit  // writes changes to disk
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
config.defaultTransactionKind = .Deferred
let dbQueue = try DatabaseQueue(path: "...", configuration: config)

// Opens a DEFERRED transaction:
dbQueue.inTransaction { db in ... }

// Opens an EXCLUSIVE transaction:
dbQueue.inTransaction(.Exclusive) { db in ... }
```


## Custom Value Types

Conversion to and from the database is based on the `DatabaseValueConvertible` protocol:

```swift
public protocol DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns a value initialized from databaseValue, if possible.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self?
}
```

All types that adopt this protocol can be used like all other [value types](#values) (Bool, Int, String, NSDate, Swift enums, etc.)

The `databaseValue` property returns [DatabaseValue](#databasevalue), a type that wraps the five values supported by SQLite: NULL, Int64, Double, String and NSData. DatabaseValue has no public initializer: to create one, use `DatabaseValue.Null`, or another type that already adopts the protocol: `1.databaseValue`, `"foo".databaseValue`, etc.

The `fromDatabaseValue()` factory method returns an instance of your custom type if the databaseValue contains a suitable value. If the databaseValue does not contain a suitable value, such as "foo" for NSDate, the method returns nil.


## Prepared Statements

**Prepared Statements** let you prepare an SQL query and execute it later, several times if you need, with different arguments.

There are two kinds of prepared statements: **select statements**, and **update statements**:

```swift
try dbQueue.inDatabase { db in
    let updateSQL = "INSERT INTO persons (name, age) VALUES (:name, :age)"
    let updateStatement = try db.updateStatement(updateSQL)
    
    let selectSQL = "SELECT * FROM persons WHERE name = ?"
    let selectStatement = try db.selectStatement(selectSQL)
}
```

The `?` and colon-prefixed keys like `:name` in the SQL query are the statement arguments. You set them with arrays or dictionaries (arguments are actually of type StatementArguments, which happens to adopt the ArrayLiteralConvertible and DictionaryLiteralConvertible protocols).

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
for row in Row.fetch(selectStatement) { ... }
let persons = Person.fetchAll(selectStatement)
let person = Person.fetchOne(selectStatement)
```

You can set the arguments at the moment of the statement execution:

```swift
try updateStatement.execute(arguments: ["name": "Arthur", "age": 41])
let person = Person.fetchOne(selectStatement, arguments: ["Arthur"])
```

> :point_up: **Note**: a prepared statement that has failed can not be reused.

See [row queries](#row-queries), [value queries](#value-queries), and [Records](#records) for more information.


### Prepared Statements Cache

When the same query will be used several times in the lifetime of your application, you may feel a natural desire to cache prepared statements.

**Don't cache statements yourself.**

> :point_up: **Note**: This is because you don't have the necessary tools. Statements are tied to specific SQLite connections and dispatch queues which you don't manage yourself, especially when you use [database pools](#database-pools). A change in the database schema [may, or may not](https://www.sqlite.org/compile.html#max_schema_retry) invalidate a statement. On systems earlier than iOS 8.2 and OSX 10.10 that don't have the [sqlite3_close_v2 function](https://www.sqlite.org/c3ref/close.html), SQLite connections won't close properly if statements have been kept alive.

Instead, use the `cachedUpdateStatement` and `cachedSelectStatement` methods. GRDB does all the hard caching and [memory management](#memory-management) stuff for you:

```swift
let updateStatement = try db.cachedUpdateStatement(updateSQL)
let selectStatement = try db.cachedSelectStatement(selectSQL)
```


## Custom SQL Functions

**SQLite lets you define SQL functions.**

A custom SQL function extends SQLite. It can be used in raw SQL queries. And when SQLite needs to evaluate it, it calls your custom code.

```swift
let reverseString = DatabaseFunction(
    "reverseString",  // The name of the function
    argumentCount: 1, // Number of arguments
    pure: true,       // True means that the result only depends on input
    function: { (databaseValues: [DatabaseValue]) in
        // Extract string value, if any...
        guard let string = String.fromDatabaseValue(databaseValues[0]) else {
            return nil
        }
        // ... and return reversed string:
        return String(string.characters.reverse())
    })
dbQueue.addFunction(reverseString)   // Or dbPool.addFunction(...)

dbQueue.inDatabase { db in
    // "oof"
    String.fetchOne(db, "SELECT reverseString('foo')")!
}
```

The *function* argument takes an array of [DatabaseValue](#databasevalue), and returns any valid [value](#values) (Bool, Int, String, NSDate, Swift enums, etc.) The number of database values is guaranteed to be *argumentCount*.

SQLite has the opportunity to perform additional optimizations when functions are "pure", which means that their result only depends on their arguments. So make sure to set the *pure* argument to true when possible.


**Functions can take a variable number of arguments:**

When you don't provide any explicit *argumentCount*, the function can take any number of arguments:

```swift
let averageOf = DatabaseFunction("averageOf", pure: true) { (databaseValues: [DatabaseValue]) in
    let doubles = databaseValues.flatMap { Double.fromDatabaseValue($0) }
    return doubles.reduce(0, combine: +) / Double(doubles.count)
}
dbQueue.addFunction(averageOf)

dbQueue.inDatabase { db in
    // 2.0
    Double.fetchOne(db, "SELECT averageOf(1, 2, 3)")!
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
    t.column("id", .Integer).primaryKey()
    t.column("name", .Text)
}

// <Row type:"table" name:"persons" tbl_name:"persons" rootpage:2
//      sql:"CREATE TABLE persons(id INTEGER PRIMARY KEY, name TEXT)">
for row in Row.fetch(db, "SELECT * FROM sqlite_master") {
    print(row)
}

// <Row cid:0 name:"id" type:"INTEGER" notnull:0 dflt_value:NULL pk:1>
// <Row cid:1 name:"name" type:"TEXT" notnull:0 dflt_value:NULL pk:0>
for row in Row.fetch(db, "PRAGMA table_info('persons')") {
    print(row)
}
```

GRDB provides four high-level methods as well:

```swift
db.tableExists("persons")    // Bool, true if the table exists
db.indexes(on: "persons")    // [IndexInfo], the indexes defined on the table
try db.table("persons", hasUniqueKey: ["email"]) // Bool, true if column(s) is a unique key
try db.primaryKey("persons") // PrimaryKeyInfo?
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
let row = Row.fetchOne(db, "SELECT 'Hello' AS produced", adapter: adapter)!

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
for row in Row.fetch(db, sql, adapter: adapter) {
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
> for book in Book.fetch(db, sql, adapter: adapter) {
>     book.title        // Moby-Dick
>     book.author?.name // Melville
> }
> ```
> 
> And Person and Book can still be fetched without row adapters:
> 
> ```swift
> let books = Book.fetchAll(db, "SELECT * FROM books")
> let persons = Person.fetchAll(db, "SELECT * FROM persons")
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

for row in Row.fetch(db, sql, adapter: adapter) {
    // The fetched row, adapted with mainAdapter:
    row.value(named: "id")   // 1
    row.value(named: "name") // Arthur
    
    // The "bestFriend" scope, with bestFriendAdapter:
    if let bestFriendRow = row.scoped(on: "bestFriend") {
        bestFriendRow.value(named: "id")    // 2
        bestFriendRow.value(named: "name")  // Barbara
    }
}

// Assuming Person.init(row) consumes the "bestFriend" scope:
for person in Person.fetch(db, sql, adapter: adapter) {
    person.name             // Arthur
    person.bestFriend?.name // Barbara
}
```


For more information about row adapters, see the documentation of:

- [RowAdapter](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/Protocols/RowAdapter.html): the protocol that lets you define your custom row adapters
- [ColumnMapping](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/Structs/ColumnMapping.html): a row adapter that renames row columns
- [SuffixRowAdapter](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/Structs/SuffixRowAdapter.html): a row adapter that hides the first columns of a row
- [ScopeAdapter](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/Structs/ScopeAdapter.html): the row adapter that groups several adapters together to define scopes


## Raw SQLite Pointers

Not all SQLite APIs are exposed in GRDB.

The `Database.sqliteConnection` and `Statement.sqliteStatement` properties provide the raw pointers that are suitable for [SQLite C API](https://www.sqlite.org/c3ref/funclist.html):

```swift
try dbQueue.inDatabase { db in
    // The raw pointer to a database connection:
    let sqliteConnection = db.sqliteConnection

    // The raw pointer to a statement:
    let statement = try db.selectStatement("SELECT ...")
    let sqliteStatement = statement.sqliteStatement
}
```

> :point_up: **Notes**
>
> - Those pointers are owned by GRDB: don't close connections or finalize statements created by GRDB.
> - SQLite connections are opened in the "[multi-thread mode](https://www.sqlite.org/threadsafe.html)", which (oddly) means that **they are not thread-safe**. Make sure you touch raw databases and statements inside their dedicated dispatch queues.

Before jumping in the low-level wagon, here is a reminder of most SQLite APIs used by GRDB:

- Connections & statements, obviously.
- Errors (pervasive)
    - [sqlite3_errmsg](https://www.sqlite.org/c3ref/errcode.html)
    - [sqlite3_errcode](https://www.sqlite.org/c3ref/errcode.html)
- Inserted Row IDs (`Database.lastInsertedRowID`).
    - [sqlite3_last_insert_rowid](https://www.sqlite.org/c3ref/last_insert_rowid.html)
- Changes count (`Database.changesCount` and `Database.totalChangesCount`).
    - [sqlite3_changes](https://www.sqlite.org/c3ref/changes.html)
    - [sqlite3_total_changes](https://www.sqlite.org/c3ref/total_changes.html)
- Custom SQL functions (see [Custom SQL Functions](#custom-sql-functions))
    - [sqlite3_create_function_v2](https://www.sqlite.org/c3ref/create_function.html)
- Custom collations (see [String Comparison](#string-comparison))
    - [sqlite3_create_collation_v2](https://www.sqlite.org/c3ref/create_collation.html)
- Busy mode (see [Concurrency](#concurrency)).
    - [sqlite3_busy_handler](https://www.sqlite.org/c3ref/busy_handler.html)
    - [sqlite3_busy_timeout](https://www.sqlite.org/c3ref/busy_timeout.html)
- Update, commit and rollback hooks (see [Database Changes Observation](#database-changes-observation)):
    - [sqlite3_update_hook](https://www.sqlite.org/c3ref/update_hook.html)
    - [sqlite3_commit_hook](https://www.sqlite.org/c3ref/commit_hook.html)
    - [sqlite3_rollback_hook](https://www.sqlite.org/c3ref/commit_hook.html)
- Backup (see [Backup](#backup)):
    - [sqlite3_backup_init](https://www.sqlite.org/c3ref/backup_finish.html)
    - [sqlite3_backup_step](https://www.sqlite.org/c3ref/backup_finish.html)
    - [sqlite3_backup_finish](https://www.sqlite.org/c3ref/backup_finish.html)
- Authorizations callbacks are *reserved* by GRDB:
    - [sqlite3_set_authorizer](https://www.sqlite.org/c3ref/set_authorizer.html)


Records
=======

**On top of the [SQLite API](#sqlite-api), GRDB provides protocols and a class** that help manipulating database rows as regular objects named "records":

```swift
if let poi = PointOfInterest.fetchOne(db, key: 1) {
    poi.isFavorite = true
    try poi.update(db)
}
```

Your custom structs and classes can adopt each protocol individually, and opt in to focused sets of features. Or you can subclass the `Record` class, and get the full toolkit in one go: fetching methods, persistence methods, and changes tracking.

> :point_up: **Note**: if you are familiar with Core Data's NSManagedObject or Realm's Object, you may experience a cultural shock: GRDB records are not uniqued, and do not auto-update. This is both a purpose, and a consequence of protocol-oriented programming. You should read [How to build an iOS application with SQLite and GRDB.swift](https://medium.com/@gwendal.roue/how-to-build-an-ios-application-with-sqlite-and-grdb-swift-d023a06c29b3) for a general introduction.


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
let persons = Person.fetchAll(db, "SELECT ...", arguments: ...)
```

Add the [TableMapping](#tablemapping-protocol) protocol and you can stop writing SQL:

```swift
let persons = Person.filter(emailColumn != nil).order(nameColumn).fetchAll(db)
let person = Person.fetchOne(db, key: 1)
let person = Person.fetchOne(db, key: ["email": "arthur@example.com"])
let countries = Country.fetchAll(db, keys: ["FR", "US"])
```

To learn more about querying records, check the [query interface](#the-query-interface).


### Updating Records

[Record](#record-class) subclasses and types that adopt the [Persistable](#persistable-protocol) protocol can be updated in the database:

```swift
let person = Person.fetchOne(db, key: 1)!
person.name = "Arthur"
try person.update(db)
```

[Record](#record-class) subclasses track changes:

```swift
let person = Person.fetchOne(db, key: 1)!
person.name = "Arthur"
if person.hasPersistentChangedValues {
    try person.update(db)
}
```

For batch updates, you have to execute an [SQL query](#executing-updates):

```swift
try db.execute("UPDATE persons SET synchronized = 1")
```


### Deleting Records

[Record](#record-class) subclasses and types that adopt the [Persistable](#persistable-protocol) protocol can be deleted from the database:

```swift
let person = Person.fetchOne(db, key: 1)!
try person.delete(db)
```

The [TableMapping](#tablemapping-protocol) protocol gives you methods that delete according to primary key or any unique index:

```swift
try Person.deleteOne(db, key: 1)
try Person.deleteOne(db, key: ["email": "arthur@example.com"])
try Country.deleteAll(db, keys: ["FR", "US"])
```

Other deletions require an [SQL query](#executing-updates):

```swift
try db.execute("DELETE FROM persons")
```


### Counting Records

[Record](#record-class) subclasses and types that adopt the [TableMapping](#tablemapping-protocol) protocol can be counted:

```swift
let personWithEmailCount = Person.filter(emailColumn != nil).fetchCount(db)  // Int
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
    init(_ row: Row)
    
    /// Optional method which gives adopting types an opportunity to complete
    /// their initialization after being fetched. Do not call it directly.
    mutating func awakeFromFetch(row row: Row)
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
    init(_ row: Row) {
        id = row.value(named: "id")
        title = row.value(named: "title")
        coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),
            row.value(named: "longitude"))
    }
}
```

See [column values](#column-values) for more information about the `row.value()` method.

> :point_up: **Note**: for performance reasons, the same row argument to `init(_:Row)` is reused during the iteration of a fetch query. If you want to keep the row for later use, make sure to store a copy: `self.row = row.copy()`.

RowConvertible allows adopting types to be fetched from SQL queries:

```swift
PointOfInterest.fetch(db, "SELECT ...", arguments:...)    // DatabaseSequence<PointOfInterest>
PointOfInterest.fetchAll(db, "SELECT ...", arguments:...) // [PointOfInterest]
PointOfInterest.fetchOne(db, "SELECT ...", arguments:...) // PointOfInterest?
```

See [fetching methods](#fetching-methods) for information about the `fetch`, `fetchAll` and `fetchOne` methods. See [fetching rows](#fetching-rows) for more information about the query arguments.


### RowConvertible and Row Adapters

RowConvertible types usually consume rows by column name:

```swift
extension PointOfInterest : RowConvertible {
    init(_ row: Row) {
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
    static func databaseTableName() -> String
}
```

**To use TableMapping**, subclass the [Record](#record-class) class, or adopt it explicitely. For example:

```swift
extension PointOfInterest : TableMapping {
    static func databaseTableName() -> String {
        return "pointOfInterests"
    }
}
```

Adopting types can be fetched without SQL, using the [query interface](#the-query-interface):

```swift
let paris = PointOfInterest.filter(nameColumn == "Paris").fetchOne(db)
```

You can also fetch and delete records according to their primary key:

```swift
// Fetch:
Person.fetchOne(db, key: 1)              // Person?
Person.fetchAll(db, keys: [1, 2, 3])     // [Person]

Country.fetchOne(db, key: "FR")          // Country?
Country.fetchAll(db, keys: ["FR", "US"]) // [Country]

// Use a dictionary for composite primary keys:
Citizenship.fetchOne(db, key: ["personID": 1, "countryISOCode": "FR"]) // Citizenship?

// Delete records:
try Person.deleteOne(db, key: 1)
try Country.deleteAll(db, keys: ["FR", "US"])
```

When given dictionaries, `fetchOne`, `deleteOne`, `fetchAll` and `deleteAll` accept any set of columns that uniquely identify rows. These are the primary key columns, or any columns involved in a unique index:

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


## Persistable Protocol

**GRDB provides two protocols that let adopting types store themselves in the database:**

```swift
public protocol MutablePersistable : TableMapping {
    /// The name of the database table (from TableMapping)
    static func databaseTableName() -> String
    
    /// The values persisted in the database
    var persistentDictionary: [String: DatabaseValueConvertible?] { get }
    
    /// Optional method that lets your adopting type store its rowID upon
    /// successful insertion. Don't call it directly: it is called for you.
    mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?)
}
```

```swift
public protocol Persistable : MutablePersistable {
    /// Non-mutating version of the optional didInsertWithRowID(:forColumn:)
    func didInsertWithRowID(rowID: Int64, forColumn column: String?)
}
```

Yes, two protocols instead of one. Both grant exactly the same advantages. Here is how you pick one or the other:

- *If your type is a struct that mutates on insertion*, choose `MutablePersistable`.
    
    For example, your table has an INTEGER PRIMARY KEY and you want to store the inserted id on successful insertion. Or your table has a UUID primary key, and you want to automatically generate one on insertion.

- Otherwise, stick with `Persistable`. Particularly if your type is a class.

The `persistentDictionary` property returns a dictionary whose keys are column names, and values any DatabaseValueConvertible value (Bool, Int, String, NSDate, Swift enums, etc.) See [Values](#values) for more information.

The optional `didInsertWithRowID` method lets the adopting type store its rowID after successful insertion. If your table has an INTEGER PRIMARY KEY column, you are likely to define this method. Otherwise, you can safely ignore it. It is called from a protected dispatch queue, and serialized with all database updates.

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
    mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
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

- `update` can also throw a PersistenceError of type NotFound, should the update fail because there is no matching row in the database.
    
    When saving an object that may or may not already exist in the database, prefer the `save` method:

- `save` makes sure your values are stored in the database.

    It performs an UPDATE if the record has a non-null primary key, and then, if no row was modified, an INSERT. It directly perfoms an INSERT if the record has no primary key, or a null primary key.
    
    Despite the fact that it may execute two SQL statements, `save` behaves as an atomic operation: GRDB won't allow any concurrent thread to sneak in (see [concurrency](#concurrency)).

- `delete` returns whether a database row was deleted or not.

**All primary keys are supported**, including primary keys that span several columns.


### Customizing the Persistence Methods

Your custom type may want to perform extra work when the persistence methods are invoked.

For example, it may want to have its UUID automatically set before inserting. Or it may want to validate its values before saving.

When you subclass [Record](#record-class), you simply have to override the customized method, and call `super`:

```swift
class Person : Record {
    var uuid: NSUUID?
    
    override func insert(db: Database) throws {
        if uuid == nil {
            uuid = NSUUID()
        }
        try super.insert(db)
    }
}
```

If you use the raw [Persistable](#persistable-protocol) protocol, use one of the *special methods* `performInsert`, `performUpdate`, `performSave`, `performDelete`, or `performExists`:

```swift
struct Link : Persistable {
    var url: NSURL
    
    func insert(db: Database) throws {
        try validate()
        try performInsert(db)
    }
    
    func update(db: Database, columns: Set<String>) throws {
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
    class func databaseTableName() -> String
    
    /// Initialize from a database row
    required init(_ row: Row)
    
    /// The values persisted in the database
    var persistentDictionary: [String: DatabaseValueConvertible?]
    
    /// Optionally update record ID after a successful insertion
    func didInsertWithRowID(rowID: Int64, forColumn column: String?)
}
```

For example, here is a fully functional Record subclass:

```swift
class PointOfInterest : Record {
    var id: Int64?
    var title: String
    var coordinate: CLLocationCoordinate2D
    
    /// The table name
    override class func databaseTableName() -> String {
        return "pointOfInterests"
    }
    
    /// Initialize from a database row
    required init(_ row: Row) {
        id = row.value(named: "id")
        title = row.value(named: "title")
        coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),
            row.value(named: "longitude"))
        super.init(row)
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
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
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
let pois = PointOfInterest.order(titleColumn).fetchAll(db)

// By key
let poi = PointOfInterest.fetchOne(db, key: 1)

// Using SQL
let pois = PointOfInterest.fetchAll(db, "SELECT ...", arguments: ...)
```


**Update records** (see [persistence methods](#persistence-methods)):

```swift
let poi = PointOfInterest.fetchOne(db, key: 1)!
poi.coordinate = ...
try poi.update(db)
```


**Delete records** (see [persistence methods](#persistence-methods)):

```swift
let poi = PointOfInterest.fetchOne(db, key: 1)!
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


The Query Interface
===================

**The query interface lets you write pure Swift instead of SQL:**

```swift
try db.create(table: "wines") { t in ... }
let count = Wine.filter(color == Color.Red).fetchCount(db)
let wines = Wine.filter(origin == "Burgundy").order(price).fetchAll(db)
```

Please bear in mind that the query interface can not generate all possible SQL queries. You may also *prefer* writing SQL, and this is just OK. From little snippets to full queries, your SQL skills are welcome:

```swift
try db.execute("CREATE TABLE wines (...)")
let count = Wine.filter(sql: "color = ?", arguments: [Color.Red]).fetchCount(db)
let wines = Wine.fetchAll(db, "SELECT * FROM wines WHERE origin = ? ORDER BY price", arguments: ["Burgundy"])
```

So don't miss the [SQL API](#sqlite-api).

- [Database Schema](#database-schema)
- [Requests](#requests)
- [Expressions](#expressions)
    - [SQL Operators](#sql-operators)
    - [SQL Functions](#sql-functions)
- [Fetching from Requests](#fetching-from-requests)
- [Fetching by Primary Key](#fetching-by-primary-key)
- [Fetching Aggregated Values](#fetching-aggregated-values)


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
    t.column("id", .Integer).primaryKey()
    t.column("title", .Text)
    t.column("favorite", .Boolean).notNull().defaults(to: false)
    t.column("longitude", .Double).notNull()
    t.column("latitude", .Double).notNull()
}
```

The `create(table:)` method covers nearly all SQLite table creation features.

Relevant SQLite documentation:

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
    t.column("name", .Text)
    t.column("creationDate", .Datetime)
```

Define **not null** columns, and set **default** values:

```swift
    // email TEXT NOT NULL,
    t.column("email", .Text).notNull()
    
    // name TEXT NOT NULL DEFAULT 'Anonymous',
    t.column("name", .Text).notNull().defaults(to: "Anonymous")
```
    
Use an individual column as **primary**, **unique**, or **foreign key**. When defining a foreign key, the referenced column is the primary key of the referenced table (unless you specify otherwise):

```swift
    // id INTEGER PRIMARY KEY,
    t.column("id", .Integer).primaryKey()
    
    // email TEXT UNIQUE,
    t.column("email", .Text).unique()
    
    // countryCode TEXT REFERENCES countries(code) ON DELETE CASCADE,
    t.column("countryCode", .Text).references("countries", onDelete: .Cascade)
```

**Perform integrity checks** on individual columns, and SQLite will only let conforming rows in. In the example below, the `$0` closure variable is a column which lets you build any SQL [expression](#expressions).

```swift
    // name TEXT CHECK (LENGTH(name) > 0)
    // age INTEGER CHECK (age > 0)
    t.column("name", .Text).check { length($0) > 0 }
    t.column("age", .Integer).check(sql: "age > 0")
```

Other **table constraints** can involve several columns:

```swift
    // PRIMARY KEY (a, b),
    t.primaryKey(["a", "b"])
    
    // UNIQUE (a, b) ON CONFLICT REPLACE,
    t.uniqueKey(["a", "b"], onConfict: .Replace)
    
    // FOREIGN KEY (a, b) REFERENCES parents(c, d),
    t.foreignKey(["a", "b"], references: "parent")
    
    // CHECK (a + b < 10),
    t.check(SQLColumn("a") + SQLColumn("b") < 10)
    
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
    t.add(column: "url", .Text)
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
let persons = request.fetchAll(db)  // [Person]
let count = request.fetchCount(db)  // Int
```

All requests start from **a type** that adopts the `TableMapping` protocol, such as a `Record` subclass (see [Records](#records)):

```swift
class Person : Record { ... }
```

Declare the table **columns** that you want to use for filtering, or sorting:

```swift
let idColumn = SQLColumn("id")
let nameColumn = SQLColumn("name")
```

You can now build requests with the following methods: `all`, `select`, `distinct`, `filter`, `group`, `having`, `order`, `reverse`, `limit`. All those methods return another request, which you can further refine by applying another method: `Person.select(...).filter(...).order(...)`.

- `all()`: the request for all rows.

    ```swift
    // SELECT * FROM persons
    Person.all()
    ```

- `select(expression, ...)` defines the selected columns.
    
    ```swift
    // SELECT id, name FROM persons
    Person.select(idColumn, nameColumn)
    
    // SELECT MAX(age) AS maxAge FROM persons
    Person.select(max(ageColumn).aliased("maxAge"))
    ```

- `distinct` performs uniquing:
    
    ```swift
    // SELECT DISTINCT name FROM persons
    Person.select(nameColumn).distinct
    ```

- `filter(expression)` applies conditions.
    
    ```swift
    // SELECT * FROM persons WHERE id IN (1, 2, 3)
    Person.filter([1,2,3].contains(idColumn))
    
    // SELECT * FROM persons WHERE (name IS NOT NULL) AND (height > 1.75)
    Person.filter(nameColumn != nil && heightColumn > 1.75)
    ```

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

- `reverse()` reverses the eventual orderings.
    
    ```swift
    // SELECT * FROM persons ORDER BY score ASC, name DESC
    Person.order(scoreColumn.desc, nameColumn).reverse()
    ```
    
    If no ordering was specified, the result is ordered by rowID in reverse order.
    
    ```swift
    // SELECT * FROM persons ORDER BY _rowid_ DESC
    Person.all().reverse()
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

The `select`, `order`, `group`, and `limit` methods ignore and replace previously applied selection, orderings, grouping, and limits. On the opposite, `filter`, and `having` methods extend the query:

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
    
    // SELECT * FROM persons WHERE (age <> 18)
    Person.filter(ageColumn != 18)
    
    // SELECT * FROM persons WHERE (age IS NOT 18)
    Person.filter(ageColumn !== 18)
    
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
    Person.filter((0..<18).contains(ageColumn))
    
    // SELECT * FROM persons WHERE age BETWEEN 0 AND 17
    Person.filter((0...17).contains(ageColumn))
    
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
    
    Instead, GRDB extends SQLite with SQL functions that call the Swift built-in string functions `capitalizedString`, `lowercaseString`, `uppercaseString`, `localizedCapitalizedString`, `localizedLowercaseString` and `localizedUppercaseString`:
    
    ```swift
    Person.select(nameColumn.uppercaseString)
    ```
    
    > :point_up: **Note**: When *comparing* strings, you'd rather use a [custom comparison function](#string-comparison).

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
request.fetch(db)    // DatabaseSequence<Person>
request.fetchAll(db) // [Person]
request.fetchOne(db) // Person?
```

See [fetching methods](#fetching-methods) for information about the `fetch`, `fetchAll` and `fetchOne` methods.

For example:

```swift
let allPersons = Person.fetchAll(db)                            // [Person]
let arthur = Person.filter(nameColumn == "Arthur").fetchOne(db) // Person?
```


**When the selected columns don't fit the source type**, change your target: any other type that adopts the [RowConvertible](#rowconvertible-protocol) protocol, plain [database rows](#fetching-rows), and even [values](#values):

```swift
// Double
let request = Person.select(min(heightColumn))
let minHeight = Double.fetchOne(db, request)

// Row
let request = Person.select(min(heightColumn), max(heightColumn))
let row = Row.fetchOne(db, request)!
let minHeight = row.value(atIndex: 0) as Double?
let maxHeight = row.value(atIndex: 1) as Double?
```


## Fetching By Primary Key

**Fetching records according to their primary key** is a very common task. It has a shortcut which accepts any single-column primary key:

```swift
// SELECT * FROM persons WHERE id = 1
Person.fetchOne(db, key: 1)              // Person?

// SELECT * FROM persons WHERE id IN (1, 2, 3)
Person.fetchAll(db, keys: [1, 2, 3])     // [Person]

// SELECT * FROM persons WHERE isoCode = 'FR'
Country.fetchOne(db, key: "FR")          // Country?

// SELECT * FROM countries WHERE isoCode IN ('FR', 'US')
Country.fetchAll(db, keys: ["FR", "US"]) // [Country]
```

For multiple-column primary keys, provide a dictionary:

```swift
// SELECT * FROM citizenships WHERE personID = 1 AND countryISOCode = 'FR'
Citizenship.fetchOne(db, key: ["personID": 1, "countryISOCode": "FR"]) // Citizenship?
```

You can use generally use a dictionary for any **unique key** (primary key and columns involved in a unique index):

```swift
Person.fetchOne(db, key: ["email": "arthur@example.com"]) // Person?
```


## Fetching Aggregated Values

**Requests can count.** The `fetchCount()` method returns the number of rows that would be returned by a fetch request:

```swift
// SELECT COUNT(*) FROM persons
let count = Person.fetchCount(db) // Int

// SELECT COUNT(*) FROM persons WHERE email IS NOT NULL
let count = Person.filter(emailColumn != nil).fetchCount(db)

// SELECT COUNT(DISTINCT name) FROM persons
let count = Person.select(nameColumn).distinct.fetchCount(db)

// SELECT COUNT(*) FROM (SELECT DISTINCT name, age FROM persons)
let count = Person.select(nameColumn, ageColumn).distinct.fetchCount(db)
```


**Other aggregated values** can also be selected and fetched (see [SQL Functions](#sql-functions)):

```swift
let request = Person.select(min(heightColumn))
let minHeight = Double.fetchOne(db, request)

let request = Person.select(min(heightColumn), max(heightColumn))
let row = Row.fetchOne(db, request)!
let minHeight = row.value(atIndex: 0) as Double?
let maxHeight = row.value(atIndex: 1) as Double?
```


Application Tools
=================

On top of the APIs described above, GRDB provides a toolkit for applications. While none of those are mandatory, all of them help dealing with the database:

- [Migrations](#migrations): Transform your database as your application evolves.
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
        t.column("id", .Integer).primaryKey()
        t.column("name", .Text).notNull()
    }
    try db.execute("INSERT INTO new_persons SELECT * FROM persons")
    try db.drop(table: "persons")
    try db.rename(table: "new_persons", to: "persons")
}
```

While your migration code runs with disabled foreign key checks, those are re-enabled and checked at the end of the migration, regardless of eventual errors.


## Database Changes Observation

The `TransactionObserverType` protocol lets you **observe database changes**:

```swift
public protocol TransactionObserverType : class {
    /// Notifies a database change:
    /// - event.kind (insert, update, or delete)
    /// - event.tableName
    /// - event.rowID
    ///
    /// For performance reasons, the event is only valid for the duration of
    /// this method call. If you need to keep it longer, store a copy:
    /// event.copy().
    func databaseDidChangeWithEvent(event: DatabaseEvent)
    
    /// An opportunity to rollback pending changes by throwing an error.
    func databaseWillCommit() throws
    
    /// Database changes have been committed.
    func databaseDidCommit(db: Database)
    
    /// Database changes have been rollbacked.
    func databaseDidRollback(db: Database)
}
```

To activate a transaction observer, add it to the database queue or pool:

```swift
let observer = MyObserver()
dbQueue.addTransactionObserver(observer)
```

Database holds weak references to its transaction observers: they are not retained, and stop getting notifications after they are deallocated.

Unless specified otherwise (see below), **a transaction observer is notified of all database changes**: inserts, updates and deletes, including indirect ones triggered by ON DELETE and ON UPDATE actions associated to [foreign keys](https://www.sqlite.org/foreignkeys.html#fk_actions).

Changes are not actually applied until `databaseDidCommit` is called. On the other side, `databaseDidRollback` confirms their invalidation:

```swift
try dbQueue.inTransaction { db in
    try db.execute("INSERT ...") // 1. didChange
    try db.execute("UPDATE ...") // 2. didChange
    return .Commit               // 3. willCommit, 4. didCommit
}

try dbQueue.inTransaction { db in
    try db.execute("INSERT ...") // 1. didChange
    try db.execute("UPDATE ...") // 2. didChange
    return .Rollback             // 3. didRollback
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
    
    return .Commit                          // 4. willCommit, 5. didCommit
}
```


**Eventual errors** thrown from `databaseWillCommit` are exposed to the application code:

```swift
do {
    try dbQueue.inTransaction { db in
        ...
        return .Commit           // 1. willCommit (throws), 2. didRollback
    }
} catch {
    // 3. The error thrown by the transaction observer.
}
```

> :point_up: **Note**: all callbacks are called in a protected dispatch queue, and serialized with all database updates.
>
> :point_up: **Note**: the databaseDidChangeWithEvent and databaseWillCommit callbacks must not touch the SQLite database. This limitation does not apply to databaseDidCommit and databaseDidRollback which can use their database argument.

[FetchedRecordsController](#fetchedrecordscontroller) is based on the TransactionObserverType protocol.

See also [TableChangeObserver.swift](https://gist.github.com/groue/2e21172719e634657dfd), which shows a transaction observer that notifies of modified database tables with NSNotificationCenter.


### Filtering Database Events

**Transaction observers can avoid being notified of some database changes they are not interested in.**

At first sight, this looks somewhat redundant with the checks that observers can perform in their `databaseDidChangeWithEvent` method. But the code below is inefficient:

```swift
// BAD: An inefficient way to track the "persons" table:
class PersonObserver : TransactionObserverType {
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        guard event.tableName == "persons" else {
            return
        }
        // Process change to the "persons" table
    }
}
```

The `databaseDidChangeWithEvent` method is invoked for each insertion, deletion, and update of individual rows. When there are many changed rows, the observer will spend of a lot of time performing the same check again and again.

More, when you're interested in specific table columns, you're out of luck, because `databaseDidChangeWithEvent` does not know about columns: it just knows that a row has been inserted, deleted, or updated, without further detail.

Instead, provide an event filter to the `addTransactionObserver` method, as below:

```swift
// This observer will only be notified of changes to the "name" column
// of the "persons" table.
dbQueue.addTransactionObserver(observer, forDatabaseEvents: { event in
    switch event {
    case .Insert(let tableName):
        return tableName == "persons"
    case .Delete(let tableName):
        return tableName == "persons"
    case .Update(let tableName, let columnNames):
        return tableName == "persons" && columnNames.contains("name")
    }
})
```

This technique is *much more* efficient, because GRDB will apply the filter only once for each update statement, instead of once for each modified row.

> :point_up: **Note**: avoid referring to the observer itself in the event filter closure, because the database would then keep a strong reference to the observer - this is usually undesired.


### Support for SQLite Pre-Update Hooks

A [custom SQLite build](#custom-sqlite-builds) can activate [SQLite "preupdate hooks"](http://www.sqlite.org/sessions/c3ref/preupdate_count.html). In this case, TransactionObserverType gets an extra callback which lets you observe individual column values in the rows modified by a transaction:

```swift
public protocol TransactionObserverType : class {
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    /// Notifies before a database change (insert, update, or delete)
    /// with change information (initial / final values for the row's
    /// columns).
    ///
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy: event.copy().
    func databaseWillChangeWithEvent(event: DatabasePreUpdateEvent)
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
    request: Person.order(SQLColumn("name")))

// Using SQL, and eventual arguments:
let controller = FetchedRecordsController<Person>(
    dbQueue,
    sql: "SELECT * FROM persons ORDER BY name WHERE countryIsoCode = ?",
    arguments: ["FR"])
```

The fetch request can involve several database tables:

```swift
let controller = FetchedRecordsController<Person>(
    dbQueue,
    sql: "SELECT persons.*, COUNT(books.id) AS bookCount " +
         "FROM persons " +
         "LEFT JOIN books ON books.authorId = persons.id " +
         "GROUP BY persons.id " +
         "ORDER BY persons.name")
```


After creating an instance, you invoke `performFetch()` to actually execute
the fetch.

```swift
controller.performFetch()
```


### Responding to Changes

In general, FetchedRecordsController is designed to respond to changes at *the database layer*, by [notifying](#the-changes-notifications) when *database rows* change location or values.

Changes are not reflected until they are applied in the database by a successful [transaction](#transactions-and-savepoints). Transactions can be explicit, or implicit:

```swift
try dbQueue.inTransaction { db in
    try person1.insert(db)
    try person2.insert(db)
    return .Commit         // Explicit transaction
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
controller.trackChanges(
    // controller's records are about to change:
    recordsWillChange: { controller in ... },
    
    // (iOS only) notification of individual record changes:
    tableViewEvent: { (controller, record, event) in ... },
    
    // controller's records have changed:
    recordsDidChange: { controller in ... })
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

**Callbacks are invoked asynchronously.** This means that changes made from the main thread are *not* immediately notified:

```swift
// On the main thread
try dbQueue.inDatabase { db in
    try Person(...).insert(db)
}
// Here changes have not yet been notified.
```

When you need to take immediate action, force the controller to refresh immediately with its `performFetch` method. In this case, changes callbacks are *not* called.


**Values fetched from inside callbacks may be inconsistent with the controller's records.** This is because after database has changed, and before the controller had the opportunity to invoke callbacks in the main thread, other database changes can happen.

To avoid inconsistencies, provide a `fetchAlongside` argument to the `trackChanges` method, as below:

```swift
controller.trackChanges(
    fetchAlongside: { db in
        // Fetch any extra value, for example the number of fetched records:
        return Person.fetchCount(db)
    },
    recordsDidChange: { (controller, count) in
        // The extra value is the second argument.
        let recordsCount = controller.fetchedRecords!.count
        assert(count == recordsCount) // guaranteed
    })
```



### Modifying the Fetch Request

You can change a fetched records controller's fetch request or SQL query.

The [notification callbacks](#the-changes-notifications) are notified of changes in the fetched records:

```swift
controller.setRequest(Person.order(SQLColumn("name")))
controller.setRequest(sql: "SELECT ...", arguments: ...)
```

> :point_up: **Note**: This behavior differs from Core Data's NSFetchedResultsController, which does not notify of record changes when the fetch request is replaced.


### Implementing the Table View Datasource Methods

On iOS, the table view data source asks the fetched records controller to provide relevant information:

```swift
func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return fetchedRecordsController.sections.count
}

func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return fetchedRecordsController.sections[section].numberOfRecords
}

func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = ...
    let record = fetchedRecordsController.recordAtIndexPath(indexPath)
    // Configure the cell
    return cell
}
```

> :point_up: **Note**: In its current state, FetchedRecordsController does not support grouping table view rows into custom sections: it generates a unique section.


### Implementing Table View Updates

On iOS, FetchedRecordsController can notify that the controller’s fetched records have been changed due to some add, remove, move, or update operations, and help your applying the changes in a UITableView.


#### Record Identity

Updates and moves are nicer to the eye when you perform table view animations. They require the controller to identify individual records in the fetched database rows. You must tell the controller how to do so:

```swift
let controller = FetchedRecordsController<Person>(
    dbQueue,
    request: ...,
    isSameRecord: { (person1, person2) in person1.id == person2.id })
```

When the fetched type adopts the [TableMapping](#tablemapping-protocol) protocol, such as [Record](#record-class) subclasses, you can use the `compareRecordsByPrimaryKey` shortcut:

```swift
let controller = FetchedRecordsController<Person>(
    dbQueue,
    request: ...,
    compareRecordsByPrimaryKey: true)
```


#### Typical Table View Updates

You can use the `recordsWillChange` and `recordsDidChange` callbacks to bracket updates to a table view whose content is provided by the fetched records controller, as illustrated in the following example:

```swift
// Assume self has a tableView property, and a configureCell(_:atIndexPath:)
// method which updates the contents of a given cell.

self.controller.trackChanges(
    // controller's records are about to change:
    recordsWillChange: { [unowned self] _ in
        self.tableView.beginUpdates()
    },
    
    // notification of individual record changes:
    tableViewEvent: { [unowned self] (controller, record, event) in
        switch event {
        case .Insertion(let indexPath):
            self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            
        case .Deletion(let indexPath):
            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            
        case .Update(let indexPath, _):
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) {
                self.configureCell(cell, atIndexPath: indexPath)
            }
            
        case .Move(let indexPath, let newIndexPath, _):
            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            self.tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)

            // // Alternate technique which actually moves cells around:
            // let cell = self.tableView.cellForRowAtIndexPath(indexPath)
            // self.tableView.moveRowAtIndexPath(indexPath, toIndexPath: newIndexPath)
            // if let cell = cell {
            //     self.configureCell(cell, atIndexPath: newIndexPath)
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

The database itself can be read and modified from [any thread](#database-connections), but fetched records controller methods like `performFetch` or `trackChanges` are constrained:

By default, they must be used from the main thread. Record changes are also [notified](#the-changes-notifications) on the main thread.

When you create a controller, you can give it a serial dispatch queue. The controller must then be used from this queue, and record changes are notified on this queue as well.


## Encryption

**GRDB can encrypt your database with [SQLCipher](http://sqlcipher.net).**

In the [installation](#installation) phase, don't use the GRDB framework, and use the GRDBCipher framework instead. CocoaPods is not supported. The manual installation needs you to download the embedded copy of SQLCipher with the `git submodule update --init` command.

**You create and open an encrypted database** by providing a passphrase to your [database connection](#database-connections):

```swift
import GRDBCipher

var configuration = Configuration()
configuration.passphrase = "secret"
let dbQueue = try DatabaseQueue(path: "...", configuration: configuration)
```

**You can change the passphrase** of an already encrypted database:

```swift
try dbQueue.changePassphrase("newSecret")
```

Providing a passphrase won't encrypt a clear-text database that already exists, though. SQLCipher can't do that, and you will get an error instead: `SQLite error 26: file is encrypted or is not a database`.

**To encrypt an existing clear-text database**, you have to create a new and empty encrypted database, and copy the content of the clear-text database in it. The technique to do that is [documented](https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/868/1) by SQLCipher. With GRDB, it gives:

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
} catch PersistenceError.NotFound {
    // There was nothing to update
}
```


### Fatal Errors

**Fatal errors notify that the program, or the database, has to be changed.**

They uncover programmer errors, false assumptions, and prevent misuses. Here are a few examples:

- The code contains a wrong SQL query:
    
    ```swift
    // fatal error:
    // SQLite error 1 with statement `SELECT * FROM boooks`:
    // no such table: boooks
    Row.fetchAll(db, "SELECT * FROM boooks")
    ```
    
    Solution: fix the SQL query:
    
    ```swift
    Row.fetchAll(db, "SELECT * FROM books")
    ```
    
    If you do have to run untrusted SQL queries, jump to [untrusted databases](#how-to-deal-with-untrusted-inputs).

- The code asks for a non-optional value, when the database contains NULL:
    
    ```swift
    // fatal error: could not convert NULL to String.
    let name: String = row.value(named: "name")
    ```
    
    Solution: fix the contents of the database, use [NOT NULL constraints](#create-tables), or load an optional:
    
    ```swift
    let name: String? = row.value(named: "name")
    ```

- The code asks for an NSDate, when the database contains garbage:
    
    ```swift
    // fatal error: could not convert "Mom's birthday" to NSDate.
    let date: NSDate? = row.value(named: "date")
    ```
    
    Solution: fix the contents of the database, or use [DatabaseValue](#databasevalue) to handle all possible cases:
    
    ```swift
    let dbv = row.databaseValue(named: "date")
    if dbv.isNull {
        // Handle NULL
    if let date = NSDate.fromDatabaseValue(dbv) {
        // Handle valid date
    } else {
        // Handle invalid date
    }
    ```

- Database connections are not reentrant:
    
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
// Some untrusted SQL query
let sql = "SELECT ..."

// Some untrusted arguments for the query
let arguments: NSDictionary = ...

for row in Row.fetchAll(db, sql, arguments: StatementArguments(arguments)) {
    // Some untrusted database value:
    let date: NSDate? = row.value(atIndex: 0)
}
```

It has several opportunities to throw fatal errors:

- The sql string may contain invalid sql, or refer to non-existing tables or columns.
- The dictionary may contain objects that can't be converted to database values.
- The dictionary may miss values required by the statement.
- The row may contain a non-null value that can't be turned into a date.

In such a situation where nothing can be trusted, you can still avoid fatal errors, but you have to expose and handle each failure point by going down one level in GRDB API:

```swift
// SQL may be invalid
let statement = try db.selectStatement(sql)

// NSDictionary arguments may contain invalid values or keys:
if let arguments = StatementArguments(arguments) {
    
    // Arguments may not fit the statement
    try statement.validateArguments(arguments)
    
    // OK we can fetch now
    statement.unsafeSetArguments(arguments) // no need to check twice
    for row in Row.fetchAll(statement) {
        
        // Database value may not be convertible to NSDate
        let dbv = row.databaseValue(atIndex: 0)
        if let date = NSDate.fromDatabaseValue(dbv) {
            // use date
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
String.fetchOne(db, "SELECT UPPER('Jérôme')")
```

GRDB extends SQLite with [SQL functions](#custom-sql-functions) that call the Swift built-in string functions `capitalizedString`, `lowercaseString`, `uppercaseString`, `localizedCapitalizedString`, `localizedLowercaseString` and `localizedUppercaseString`:

```swift
// "JÉRÔME"
let uppercaseString = DatabaseFunction.uppercaseString
String.fetchOne(db, "SELECT \(uppercaseString.name)('Jérôme')")
```

Those unicode-aware string functions are also readily available in the [query interface](#sql-functions):

```
Person.select(nameColumn.uppercaseString)
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
    t.column("email", .Text).unique().collate(.Nocase)
    
    // Sort names in a localized case insensitive way
    t.column("name", .Text).collate(.localizedCaseInsensitiveCompare)
}

// Persons are sorted in a localized case insensitive way:
let persons = Person.order(nameColumn).fetchAll(db)
```

> :warning: **Warning**: SQLite *requires* host applications to provide the definition of any collation other than binary, nocase and rtrim. When a database file has to be shared or migrated to another SQLite library of platform (such as the Android version of your application), make sure you provide a compatible collation.

If you can't or don't want to define the comparison behavior of a column (see warning above), you can still use an explicit collation in SQL requests and in the [query interface](#the-query-interface):

```swift
let collation = DatabaseCollation.localizedCaseInsensitiveCompare
let persons = Person.fetchAll(db,
    "SELECT * FROM persons ORDER BY name COLLATE \(collation.name))")
let persons = Person.order(nameColumn.collating(collation)).fetchAll(db)
```


**You can also define your own collations**:

```swift
let collation = DatabaseCollation("customCollation") { (lhs, rhs) -> NSComparisonResult in
    // return the comparison of lhs and rhs strings.
}
dbQueue.addCollation(collation) // Or dbPool.addCollation(...)
```


## Memory Management

**You can reclaim memory used by GRDB.**

The most obvious way is to release your [database queues](#database-queues) and [pools](#database-pools):

```swift
// Eventually release all memory, after all database accesses are completed:
dbQueue = nil
dbPool = nil
```

Yet both SQLite and GRDB use non-essential memory that help them perform better. You can claim this memory with the `releaseMemory` method:

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
dbQueue.setupMemoryManagement(application: UIApplication.sharedApplication())
```


## Concurrency

**Concurrency with GRDB is easy: there are two rules to follow.**

GRDB ships with support for two concurrency modes:

- [DatabaseQueue](#database-queues) opens a single database connection, and serializes all database accesses.
- [DatabasePool](#database-pools) manages a pool of several database connections, serializes writes, and allows concurrent reads and writes.

**Rule 1: Your application should have a unique instance of DatabaseQueue or DatabasePool connected to a database file. You may experience concurrency trouble if you do otherwise.**

Now let's talk about the consistency of your data: you generally want to prevent your application threads from any conflict.

Since it is difficult to synchronize threads, both [DatabaseQueue](#database-queues) and [DatabasePool](#database-pools) offer methods that isolate your statements, and guarantee a stable database state regardless of parallel threads:

```swift
dbQueue.inDatabase { db in  // or dbPool.read, or dbPool.write
    // Those two values are guaranteed to be equal:
    let count1 = PointOfInterest.fetchCount(db)
    let count2 = PointOfInterest.fetchCount(db)
}
```

Isolation is only guaranteed *inside* the closure argument of those methods. Two consecutive calls don't guarantee isolation:

```swift
// Those two values may be different because some other thread may have inserted
// or deleted a point of interest between the two statements:
let count1 = dbQueue.inDatabase { db in
    PointOfInterest.fetchCount(db)
}
let count2 = dbQueue.inDatabase { db in
    PointOfInterest.fetchCount(db)
}
```

**Rule 2: Group your related statements within the safe and isolated `inDatabase`, `inTransaction`, `read`, `write` and `writeInTransaction` methods.**


### Advanced Concurrency

SQLite concurrency is a wiiide topic.

First have a detailed look at the full API of [DatabaseQueue](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/Classes/DatabaseQueue.html) and [DatabasePool](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/Classes/DatabasePool.html). Both adopt the [DatabaseReader](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/Protocols/DatabaseReader.html) and [DatabaseWriter](http://cocoadocs.org/docsets/GRDB.swift/0.79.4/Protocols/DatabaseWriter.html) protocols, so that you can write code that targets both classes.

If the built-in queues and pools do not fit your needs, or if you can not guarantee that a single queue or pool is accessing your database file, you may have a look at:

- General discussion about isolation in SQLite: https://www.sqlite.org/isolation.html
- Types of locks and transactions: https://www.sqlite.org/lang_transaction.html
- WAL journal mode: https://www.sqlite.org/wal.html
- Busy handlers: https://www.sqlite.org/c3ref/busy_handler.html

See also [Transactions](#transactions-and-savepoints) for more precise handling of transactions, and [Configuration](GRDB/Core/Configuration.swift) for more precise handling of eventual SQLITE_BUSY errors.


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
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
    dbQueue.inDatabase { db in
        // Perform database work
    }
    dispatch_async(dispatch_get_main_queue()) {
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
Person.fetchAll(db)

// SELECT id, name FROM persons
Person.select(idColumn, nameColumn).fetchAll(db)
```

If your Person type can't be built without other columns (it has non-optional properties for other columns), *do define and use a different type*.


**Don't fetch rows you don't use**

Use [fetchOne](#fetching-methods) when you need a single value, and otherwise limit your queries at the database level:

```swift
// Wrong way: this code may discard hundreds of useless database rows
let persons = Person.order(scoreColumn.desc).fetchAll(db)
let hallOfFame = persons.prefix(5)

// Better way
let hallOfFame = Person.order(scoreColumn.desc).limit(5).fetchAll(db)
```


**Don't copy values unless necessary**

Particularly: the Array returned by the `fetchAll` method, and the sequence returned by `fetch` aren't the same:

`fetchAll` copies all values from the database into memory, when `fetch` iterates database results as they are generated by SQLite, taking profit from SQLite efficiency.

You should only load arrays if you need to keep them for later use (such as iterating their contents in the main thread). Otherwise, use `fetch`.

See [fetching methods](#fetching-methods) for more information about `fetchAll` and `fetch`. See also the [Row.dataNoCopy](#nsdata-and-memory-savings) method.


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
let authors = Author.fetchAll(db)
for author in authors {
    // SELECT COUNT(*) FROM books WHERE authorId = ...
    author.bookCount = Book.filter(authorIdColumn == author.id).fetchCount(db)
}
```

Instead, perform *a single query*:

```swift
let sql = "SELECT authors.*, COUNT(books.id) AS bookCount " +
          "FROM authors " +
          "LEFT JOIN books ON books.authorId = authors.id " +
          "GROUP BY authors.id"
let authors = Author.fetchAll(db, sql)
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
for person in Person.fetch(db) {
    ...
}

// Column indexes
// SELECT id, name, email FROM persons
let request = Person.select(idColumn, nameColumn, emailColumn)
for row in Row.fetch(db, request) {
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

- **How do I close a database connection?**
    
    The short answer is:
    
    ```swift
    // Eventually close all database connections
    dbQueue = nil
    dbPool = nil
    ```
    
    You do not explicitely close a database connection: it is managed by a [database queue](#database-queues) or [pool](#database-pools). The connection is closed when all usages of this connection are completed, and when its database queue or pool gets deallocated.
    
    Database accesses that run in background threads postpone the closing of connections.
    
    The `releaseMemory` method of DatabasePool ([documentation](#memory-management)) will actually close some connections, but the pool will open another connection as soon as you access the database again.


- **How do I open a database stored as a resource of my application?**
    
    If your application does not need to modify the database, open a read-only [connection](#database-connections) to your resource:
    
    ```swift
    var configuration = Configuration()
    configuration.readonly = true
    let dbPath = NSBundle.mainBundle().pathForResource("db", ofType: "sqlite")!
    let dbQueue = try! DatabaseQueue(path: dbPath, configuration: configuration)
    ```
    
    If the application should modify the database, you need to copy it to a place where it can be modified. For example, in the Documents folder. Only then, open a [connection](#database-connections):
    
    ```swift
    let fm = NSFileManager.defaultManager()
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
    let dbPath = (documentsPath as NSString).stringByAppendingPathComponent("db.sqlite")
    if !fm.fileExistsAtPath(dbPath) {
        let dbResourcePath = NSBundle.mainBundle().pathForResource("db", ofType: "sqlite")!
        try! fm.copyItemAtPath(dbResourcePath, toPath: dbPath)
    }
    let dbQueue = DatabaseQueue(path: dbPath)
    ```

- **Generic parameter 'T' could not be inferred**
    
    You may get this error when using DatabaseQueue.inDatabase, DatabasePool.read, or DatabasePool.write:
    
    ```swift
    // Generic parameter 'T' could not be inferred
    let x = dbQueue.inDatabase { db in
        let result = String.fetchOne(db, ...)
        return result
    }
    ```
    
    This is a Swift compiler issue (see [SR-1570](https://bugs.swift.org/browse/SR-1570)).
    
    The general workaround is to explicitly declare the type of the closure result:
    
    ```swift
    // General Workaround
    let x = dbQueue.inDatabase { db -> String? in
        let result = String.fetchOne(db, ...)
        return result
    }
    ```
    
    You can also, when possible, write a single-line closure:
    
    ```swift
    // Single-line closure workaround:
    let x = dbQueue.inDatabase { db in
        String.fetchOne(db, ...)
    }
    ```


Sample Code
===========

- The [Documentation](#documentation) is full of GRDB snippets.
- [GRDBDemoiOS](DemoApps/GRDBDemoiOS): A sample iOS application.
- Check `GRDB.xcworkspace`: it contains GRDB-enabled playgrounds to play with.
- How to synchronize a database table with a JSON payload: [JSONSynchronization.playground](Playgrounds/JSONSynchronization.playground/Contents.swift)
- A class that behaves like NSUserDefaults, but backed by SQLite: [UserDefaults.playground](Playgrounds/UserDefaults.playground/Contents.swift)
- How to notify view controllers of database changes: [TableChangeObserver.swift](https://gist.github.com/groue/2e21172719e634657dfd)


---

**Thanks**

- [Pierlis](http://pierlis.com), where we write great software.
- [Vladimir Babin](https://github.com/Chiliec), [Pascal Edmond](https://github.com/pakko972), [Cristian Filipov](https://github.com/cfilipov), [@peter-ss](https://github.com/peter-ss), [Pierre-Loïc Raynaud](https://github.com/pierlo), [Steven Schveighoffer](https://github.com/schveiguy) and [@swiftlyfalling](https://github.com/swiftlyfalling) for their contributions, help, and feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [Mathieu "Kali" Poumeyrol](https://github.com/kali) because SQL.
- [ccgus/fmdb](https://github.com/ccgus/fmdb) for its excellency.
