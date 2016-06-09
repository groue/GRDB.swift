GRDB.swift [![Swift](https://img.shields.io/badge/swift-2.2-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/GRDB.swift.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/groue/GRDB.swift.svg?maxAge=2592000)](/LICENSE)
==========

GRDB.swift is an SQLite toolkit for Swift 2.2.

It ships with a **low-level SQLite API**, and high-level tools that help dealing with databases:

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
- Suited for experienced SQLite users as well as beginners.

You should give it a try.

---

**June 9, 2016: GRDB.swift 0.72.0 is out** ([changelog](CHANGELOG.md)). Follow [@groue](http://twitter.com/groue) on Twitter for release announcements and usage tips.

**Requirements**: iOS 7.0+ / OSX 10.9+, Xcode 7.3+


### Usage

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
            "title TEXT, " +
            "favorite BOOLEAN NOT NULL, " +
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
    var title: String?
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

    try berlin.insert(dbQueue)
    berlin.id // some value

    berlin.favorite = true
    try berlin.update(dbQueue)
    
    // Fetch [PointOfInterest] from SQL
    let pois = PointOfInterest.fetchAll(db, "SELECT * FROM pointOfInterests")
}
```

Avoid SQL with the [query interface](#the-query-interface):

```swift
let titleColumn = SQLColumn("title")
let favoriteColumn = SQLColumn("favorite")

dbQueue.inDatabase { db in
    // PointOfInterest?
    let paris = PointOfInterest.fetchOne(db, key: 1)
    
    // PointOfInterest?
    let berlin = PointOfInterest.filter(titleColumn == "Berlin").fetchOne(db)
    
    // [PointOfInterest]
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

- [GRDB Reference](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/index.html) (on cocoadocs.org)

**Getting started**

- [Installation](#installation)
- [Database Connections](#database-connections): Connect to SQLite databases

**SQLite and SQL**

- [SQLite API](#sqlite-api)

**Application tools**

- [Records](#records): Fetching and persistence methods for your custom structs and class hierarchies.
- [Query Interface](#the-query-interface): A swift way to generate SQL.
- [Migrations](#migrations): Transform your database as your application evolves.
- [Database Changes Observation](#database-changes-observation): Perform post-commit and post-rollback actions.
- [FetchedRecordsController](#fetchedrecordscontroller): Automatic database changes tracking, plus UITableView animations.
- [Encryption](#encryption): Encrypt your database with SQLCipher.
- [Backup](#backup): Dump the content of a database to another.

**Good to know**

- [Avoiding SQL Injection](#avoiding-sql-injection)
- [Error Handling](#error-handling)
- [Unicode](#unicode)
- [Memory Management](#memory-management)
- [Concurrency](#concurrency)

[FAQ](#faq)

[Sample Code](#sample-code)


### Installation

#### CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Xcode projects.

To use GRDB with CocoaPods, specify in your Podfile:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

pod 'GRDB.swift', '~> 0.72.0'
```

> :point_up: **Note**: [SQLCipher](#encryption) and [custom SQLite builds](#custom-sqlite-builds) are not available via CocoaPods.


#### Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency manager for Xcode projects.

To use GRDB with Carthage, specify in your Cartfile:

```
github "groue/GRDB.swift" ~> 0.72.0
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
    try db.execute("CREATE TABLE pointOfInterests (...)")
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

See [Configuration](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/Structs/Configuration.html) for more details.


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
    try db.execute("CREATE TABLE pointOfInterests (...)")
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
condig.maximumReaderCount = 10   // The default is 5

let dbPool = try DatabasePool(
    path: "/path/to/database.sqlite",
    configuration: config)
```

See [Configuration](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/Structs/Configuration.html) for more details.


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
let name: String = row.value(named: "name") // lookup is case-insensitive
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

> :warning: **Warning**: avoid the `as!` and `as?` operators (see [rdar://21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
> 
> ```swift
> row.value(...) as! Int   // NO NO NO DON'T DO THAT!
> row.value(...) as? Int   // NO NO NO DON'T DO THAT!
> ```

Generally speaking, you can extract the type you need, *provided it can be converted from the underlying SQLite value*:

- **Successful conversions include:**
    
    - Numeric SQLite values to numeric Swift types, and Bool (zero is the only false boolean).
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
let dbv = row.databaseValue(named: "name") // lookup is case-insensitive

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

You can extract [values](#values) (Bool, Int, String, NSDate, Swift enums, etc.) from DatabaseValue, just like you do from [rows](#column-values):

```swift
let dbv = row.databaseValue(named: "bookCount")
let bookCount: Int     = dbv.value()
let bookCount64: Int64 = dbv.value()
let hasBooks: Bool     = dbv.value() // false when 0

let dbv = row.databaseValue(named: "date")
let string: String = dbv.value()     // "2015-09-11 18:14:15.123"
let date: NSDate   = dbv.value()     // NSDate
self.date          = dbv.value()     // Depends on the type of the property.
```

Invalid conversions from non-NULL values raise a fatal error. This fatal error can be avoided with the [DatabaseValueConvertible.fromDatabaseValue()](#custom-value-types) method:

```swift
let row = Row.fetchOne(db, "SELECT 'foo'")!
let dbv = row.databaseValue(at: 0)
let string = dbv.value() as String  // "foo"
let date = dbv.value() as NSDate?   // fatal error: could not convert "foo" to NSDate.
let date = NSDate.fromDatabaseValue(dbv) // nil
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
let row = Row(["name": "foo", "date": nil])
```

Yet rows are not real dictionaries, because they may contain duplicate keys:

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
    
- **Foundation**: [NSData](#nsdata-and-memory-savings), [NSDate](#nsdate-and-nsdatecomponents), [NSDateComponents](#nsdate-and-nsdatecomponents), NSNull, [NSNumber](#nsnumber-and-nsdecimalnumber), NSString, NSURL.
    
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
        url = row.value("url")
        verified = row.value("verified")
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

**GRDB stores NSDate using the format "yyyy-MM-dd HH:mm:ss.SSS" in the UTC time zone.** It is precise to the millisecond.

This format may not fit your needs. We provide below some sample code for [storing dates as timestamps](#custom-value-types) that you can adapt for your application.

NSDate can be stored and fetched from the database just like other [value types](#values):

```swift
try db.execute(
    "INSERT INTO persons (creationDate, ...) VALUES (?, ...)",
    arguments: [NSDate(), ...])
```


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


### Swift Enums

**Swift enums** and generally all types that adopt the [RawRepresentable](https://developer.apple.com/library/tvos/documentation/Swift/Reference/Swift_RawRepresentable_Protocol/index.html) protocol can be stored and fetched from the database just like their raw [values](#values):

```swift
enum Color : Int {
    case Red, White, Rose
}

enum Grape : String {
    case Chardonnay, Merlot, Riesling
}

// Declare DatabaseValueConvertible adoption
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
dbv.value() as String           // "Syrah"
dbv.value() as Grape?           // fatal error: could not convert "Syrah" to Grape.
Grape.fromDatabaseValue(dbv)    // nil
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

The `databaseValue` property returns [DatabaseValue](GRDB/Core/DatabaseValue.swift), a type that wraps the five values supported by SQLite: NULL, Int64, Double, String and NSData. DatabaseValue has no public initializer: to create one, use `DatabaseValue.Null`, or another type that already adopts the protocol: `1.databaseValue`, `"foo".databaseValue`, etc.

The `fromDatabaseValue()` factory method returns an instance of your custom type if the databaseValue contains a suitable value. If the databaseValue does not contain a suitable value, such as "foo" for NSDate, the method returns nil.

As an example, see [DatabaseTimestamp.playground](Playgrounds/DatabaseTimestamp.playground/Contents.swift): it shows how to store dates as timestamps, unlike the built-in [NSDate](#nsdate-and-nsdatecomponents).


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
try db.execute("CREATE TABLE persons(id INTEGER PRIMARY KEY, name TEXT)")

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

GRDB provides two high-level methods as well:

```swift
db.tableExists("persons")    // Bool, true if the table exists
try db.primaryKey("persons") // PrimaryKey?, throws if the table does not exist
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

They basically help two incompatible row interfaces to work together. For example, a row consumer expects a column named "consumed", but the produced column has a column named "produced":

```swift
// An adapter that maps column 'produced' to column 'consumed':
let adapter = ColumnMapping(["consumed": "produced"])

// Fetch a column named 'produced', and apply adapter:
let row = Row.fetchOne(db, "SELECT 'Hello' AS produced", adapter: adapter)!

// The adapter in action:
row.value(named: "consumed") // "Hello"
```


**Row adapters can also define row variants.** Variants help several consumers feed on a single row and can reveal useful with joined queries.

For example, let's build a query which loads books along with their author:

```swift
let sql = "SELECT books.id, books.title, " +
          "       books.authorID, persons.name AS authorName " +
          "FROM books " +
          "JOIN persons ON books.authorID = persons.id"
```

The author columns are "authorID" and "authorName". Let's say that we prefer to consume them as "id" and "name". For that we build an adapter which defines a variant named "author":

```swift
let authorMapping = ColumnMapping(["id": "authorID", "name": "authorName"])
let adapter = VariantRowAdapter(variants: ["author": authorMapping])
```

Use the `Row.variant(named:)` method to load the "author" variant:

```swift
for row in Row.fetch(db, sql, adapter: adapter) {
    // The fetched row, without adaptation:
    row.value(named: "id")          // 1
    row.value(named: "title")       // Moby-Dick
    row.value(named: "authorID")    // 10
    row.value(named: "authorName")  // Melville
    
    // The "author" variant, with mapped columns:
    if let authorRow = row.variant(named: "author") {
        authorRow.value(named: "id")    // 10
        authorRow.value(named: "name")  // Melville
    }
}
```

> :bowtie: **Tip**: now that we have nice "id" and "name" columns, we can leverage [RowConvertible](#rowconvertible-protocol) types such as [Record](#record-class) subclasses. For example, assuming the Book type consumes the "author" variant in its row initializer and builds a Person from it, the same row can be consumed by both the Book and Person types:
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


**You can mix a main adapter with variant adapters:**

```swift
let sql = "SELECT main.id AS mainID, main.name AS mainName, " +
          "       friend.id AS friendID, friend.name AS friendName, " +
          "FROM persons main " +
          "LEFT JOIN persons friend ON friend.id = main.bestFriendID"

let mainAdapter = ColumnMapping(["id": "mainID", "name": "mainName"])
let bestFriendAdapter = ColumnMapping(["id": "friendID", "name": "friendName"])
let adapter = mainAdapter.adapterWithVariants(["bestFriend": bestFriendAdapter])

for row in Row.fetch(db, sql, adapter: adapter) {
    // The fetched row, adapted with mainAdapter:
    row.value(named: "id")   // 1
    row.value(named: "name") // Arthur
    
    // The "bestFriend" variant, with bestFriendAdapter:
    if let bestFriendRow = row.variant(named: "bestFriend") {
        bestFriendRow.value(named: "id")    // 2
        bestFriendRow.value(named: "name")  // Barbara
    }
}

// Assuming Person.init(row) consumes the "bestFriend" variant:
for person in Person.fetch(db, sql, adapter: adapter) {
    person.name             // Arthur
    person.bestFriend?.name // Barbara
}
```


For more information about row adapters, see the documentation of:

- [RowAdapter](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/Protocols/RowAdapter.html): the protocol that lets you define your custom row adapters
- [ColumnMapping](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/Structs/ColumnMapping.html): a row adapter that renames row columns
- [SuffixRowAdapter](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/Structs/SuffixRowAdapter.html): a row adapter that hides the first columns of a row
- [VariantRowAdapter](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/Structs/VariantRowAdapter.html): the row adapter that groups several adapters together to define named variants


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


Application Tools
=================

On top of the SQLite API described above, GRDB provides a toolkit for applications. While none of those are mandatory, all of them help dealing with the database:

- [Records](#records): Fetching and persistence methods for your custom structs and class hierarchies.
- [Query Interface](#the-query-interface): A swift way to generate SQL.
- [Migrations](#migrations): Transform your database as your application evolves.
- [Database Changes Observation](#database-changes-observation): Perform post-commit and post-rollback actions.
- [FetchedRecordsController](#fetchedrecordscontroller): Automatic database changes tracking, plus UITableView animations.
- [Encryption](#encryption): Encrypt your database with SQLCipher.
- [Backup](#backup): Dump the content of a database to another.


## Records

**On top of the [SQLite API](#sqlite-api), GRDB provides protocols and a class** that help manipulating database rows as regular objects named "records".

Your custom structs and classes can adopt each protocol individually, and opt in to focused sets of features. Or you can subclass the `Record` class, and get the full toolkit in one go: fetching methods, persistence methods, and changes tracking.


#### Inserting Records

To insert a record in the database, subclass the [Record](#record-class) class or adopt the [Persistable](#persistable-protocol) protocol, and call the `insert` method:

```swift
class Person : Record { ... }

let person = Person(name: "Arthur", email: "arthur@example.com")
try person.insert(db)
```

Of course, you need to open a [database connection](#database-connections), and [create a database table](#executing-updates) first.


#### Fetching Records

[Record](#record-class) subclasses and types that adopt the [RowConvertible](#rowconvertible-protocol) protocol can be fetched from the database:

```swift
class Person : Record { ... }
let persons = Person.fetchAll(db, "SELECT ...", arguments: ...)
```

Add the [TableMapping](#tablemapping-protocol) protocol and you can stop writing SQL:

```swift
let persons = Person.filter(emailColumn != nil).order(nameColumn).fetchAll(db)
let person = Person.fetchOne(db, key: 1)
```

To learn more about querying records, check the [query interface](#the-query-interface).


#### Updating Records

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


#### Deleting Records

[Record](#record-class) subclasses and types that adopt the [Persistable](#persistable-protocol) protocol can be deleted from the database:

```swift
let person = Person.fetchOne(db, key: 1)!
try person.delete(db)
```

For batch deletions, you have to execute an [SQL query](#executing-updates):

```swift
try db.execute("DELETE FROM persons")
```


#### Counting Records

[Record](#record-class) subclasses and types that adopt the [TableMapping](#tablemapping-protocol) protocol can be counted:

```swift
let personWithEmailCount = Person.filter(email != nil).fetchCount(db)  // Int
```


You can now jump to:

- [RowConvertible Protocol](#rowconvertible-protocol)
- [TableMapping Protocol](#tablemapping-protocol)
- [Persistable Protocol](#persistable-protocol)
- [Record Class](#record-class)
- [The Query Interface](#the-query-interface)


### RowConvertible Protocol

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
    var title: String?
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


#### RowConvertible and Row Adapters

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


### TableMapping Protocol

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

You can also fetch records according to their primary key:

```swift
// SELECT * FROM persons WHERE id = 1
Person.fetchOne(db, key: 1)              // Person?

// SELECT * FROM persons WHERE id IN (1, 2, 3)
Person.fetchAll(db, keys: [1, 2, 3])     // [Person]

// SELECT * FROM persons WHERE isoCode = 'FR'
Country.fetchOne(db, key: "FR")          // Country?

// SELECT * FROM countries WHERE isoCode IN ('FR', 'US')
Country.fetchAll(db, keys: ["FR", "US"]) // [Country]

// SELECT * FROM citizenships WHERE personID = 1 AND countryISOCode = 'FR'
Citizenship.fetchOne(db, key: ["personID": 1, "countryISOCode": "FR"]) // Citizenship?
```


### Persistable Protocol

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

The optional `didInsertWithRowID` method lets the adopting type store its rowID after successful insertion. It is called from a protected dispatch queue, and serialized with all database updates.

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


#### Persistence Methods

[Record](#record-class) subclasses and types that adopt [Persistable](#persistable-protocol) are given default implementations for methods that insert, update, and delete:

```swift
try pointOfInterest.insert(db) // INSERT
try pointOfInterest.update(db) // UPDATE
try pointOfInterest.save(db)   // Inserts or updates
try pointOfInterest.delete(db) // DELETE
pointOfInterest.exists(db)     // Bool
```

- `insert`, `update`, `save` and `delete` can throw a [DatabaseError](#error-handling) whenever an SQLite integrity check fails.

- `update` can also throw a PersistenceError of type NotFound, should the update fail because there is no matching row in the database.
    
    When saving an object that may or may not already exist in the database, prefer the `save` method:

- `save` makes sure your values are stored in the database.

    It performs an UPDATE if the record has a non-null primary key, and then, if no row was modified, an INSERT. It directly perfoms an INSERT if the record has no primary key, or a null primary key.
    
    Despite the fact that it may execute two SQL statements, `save` behaves as an atomic operation: GRDB won't allow any concurrent thread to sneak in (see [concurrency](#concurrency)).

- `delete` returns whether a database row was deleted or not.

**All primary keys are supported**, including primary keys that span several columns.


#### Customizing the Persistence Methods

Your custom type may want to perform extra work when the persistence methods are invoked.

For example, it may want to have its UUID automatically set before inserting. Or it may want to validate its values before saving.

When you subclass [Record](#record-class), you simply have to override the customized method, and call `super`:

```swift
class Person : Record {
    var uuid: String?
    
    override func insert(db: Database) throws {
        if uuid == nil {
            uuid = NSUUID().UUIDString
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
    
    func update(db: Database) throws {
        try validate()
        try performUpdate(db)
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


### Record Class

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
    var title: String?
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


#### Changes Tracking

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


## The Query Interface

**The query interface lets you write pure Swift instead of SQL:**

```swift
let count = Wine.filter(color == Color.Red).fetchCount(db)
let wines = Wine.filter(origin == "Burgundy").order(price).fetchAll(db)
```

Please bear in mind that the query interface can not generate all possible SQL queries. You may also *prefer* writing SQL, and this is just OK:

```swift
let count = Int.fetchOne(db, "SELECT COUNT(*) FROM wines WHERE color = ?", arguments [Color.Red])!
let wines = Wine.fetchAll(db, "SELECT * FROM wines WHERE origin = ? ORDER BY price", arguments: ["Burgundy"])
```

So don't miss the [SQL API](#sqlite-api).

- [Requests](#requests)
- [Expressions](#expressions)
    - [SQL Operators](#sql-operators)
    - [SQL Functions](#sql-functions)
- [Fetching from Requests](#fetching-from-requests)
- [Fetching by Primary Key](#fetching-by-primary-key)
- [Fetching Aggregated Values](#fetching-aggregated-values)


### Requests

Everything starts from **a type** that adopts the `TableMapping` protocol, such as a `Record` subclass (see [Records](#records)):

```swift
class Person: Record { ... }
```

Declare the table **columns** that you want to use for filtering, or sorting:

```swift
let idColumn = SQLColumn("id")
let nameColumn = SQLColumn("name")
```

You can now derive requests with the following methods:

- `all`
- `select`
- `distinct`
- `filter`
- `group`
- `having`
- `order`
- `reverse`
- `limit`

All the methods above return another request, which you can further refine by applying another derivation method.

- `all()`: the request for all rows.

    ```swift
    // SELECT * FROM "persons"
    Person.all()
    ```

- `select(expression, ...)` defines the selected columns.
    
    ```swift
    // SELECT "id", "name" FROM "persons"
    Person.select(idColumn, nameColumn)
    
    // SELECT MAX("age") AS "maxAge" FROM "persons"
    Person.select(max(ageColumn).aliased("maxAge"))
    ```

- `distinct` performs uniquing:
    
    ```swift
    // SELECT DISTINCT "name" FROM "persons"
    Person.select(nameColumn).distinct
    ```

- `filter(expression)` applies conditions.
    
    ```swift
    // SELECT * FROM "persons" WHERE ("id" IN (1, 2, 3))
    Person.filter([1,2,3].contains(idColumn))
    
    // SELECT * FROM "persons" WHERE (("name" IS NOT NULL) AND ("height" > 1.75))
    Person.filter(nameColumn != nil && heightColumn > 1.75)
    ```

- `group(expression, ...)` groups rows.
    
    ```swift
    // SELECT "name", MAX("age") FROM "persons" GROUP BY "name"
    Person
        .select(nameColumn, max(ageColumn))
        .group(nameColumn)
    ```

- `having(expression)` applies conditions on grouped rows.
    
    ```swift
    // SELECT "name", MAX("age") FROM "persons" GROUP BY "name" HAVING MIN("age") >= 18
    Person
        .select(nameColumn, max(ageColumn))
        .group(nameColumn)
        .having(min(ageColumn) >= 18)
    ```

- `order(ordering, ...)` sorts.
    
    ```swift
    // SELECT * FROM "persons" ORDER BY "name"
    Person.order(nameColumn)
    
    // SELECT * FROM "persons" ORDER BY "score" DESC, "name"
    Person.order(scoreColumn.desc, nameColumn)
    ```

- `reverse()` reverses the eventual orderings.
    
    ```swift
    // SELECT * FROM "persons" ORDER BY "score" ASC, "name" DESC
    Person.order(scoreColumn.desc, nameColumn).reverse()
    ```
    
    If no ordering was specified, the result is ordered by rowID in reverse order.
    
    ```swift
    // SELECT * FROM "persons" ORDER BY "_rowid_" DESC
    Person.all().reverse()
    ```

- `limit(limit, offset: offset)` limits and pages results.
    
    ```swift
    // SELECT * FROM "persons" LIMIT 5
    Person.limit(5)
    
    // SELECT * FROM "persons" LIMIT 5 OFFSET 10
    Person.limit(5, offset: 10)
    ```

You can refine requests by chaining those methods:

```swift
// SELECT * FROM "persons" WHERE ("email" IS NOT NULL) ORDER BY "name"
Person.order(nameColumn).filter(emailColumn != nil)
```

The `select`, `group` and `limit` methods ignore and replace previously applied selection, grouping and limits. On the opposite, `filter`, `having`, and `order` methods extend the query:

```swift
Person                          // SELECT * FROM "persons"
    .filter(nameColumn != nil)  // WHERE (("name" IS NOT NULL)
    .filter(emailColumn != nil) //        AND ("email IS NOT NULL"))
    .order(nameColumn)          // ORDER BY "name"
    .limit(20, offset: 40)      // - ignored -
    .limit(10)                  // LIMIT 10
```


Raw SQL snippets are also accepted:

```swift
// SELECT DATE(creationDate), COUNT(*) FROM "persons" GROUP BY date(creationDate)
Person
    .select(sql: "DATE(creationDate), COUNT(*)")
    .group(sql: "DATE(creationDate)")
```


### Expressions

Feed [requests](#requests) with SQL expressions built from your Swift code:


#### SQL Operators

- `=`, `<>`, `<`, `<=`, `>`, `>=`, `IS`, `IS NOT`
    
    Comparison operators are based on the Swift operators `==`, `!=`, `===`, `!==`, `<`, `<=`, `>`, `>=`:
    
    ```swift
    // SELECT * FROM "persons" WHERE ("name" = 'Arthur')
    Person.filter(nameColumn == "Arthur")
    
    // SELECT * FROM "persons" WHERE ("name" IS NULL)
    Person.filter(nameColumn == nil)
    
    // SELECT * FROM "persons" WHERE ("age" <> 18)
    Person.filter(ageColumn != 18)
    
    // SELECT * FROM "persons" WHERE ("age" IS NOT 18)
    Person.filter(ageColumn !== 18)
    
    // SELECT * FROM "rectangles" WHERE ("width" < "height")
    Rectangle.filter(widthColumn < heightColumn)
    ```
    
    > :point_up: **Note**: SQLite string comparison, by default, is case-sensitive and not Unicode-aware. See [string comparison](#string-comparison) if you need more control.
    

- `*`, `/`, `+`, `-`
    
    SQLite arithmetic operators are derived from their Swift equivalent:
    
    ```swift
    // SELECT (("temperature" * 1.8) + 32) AS "farenheit" FROM "persons"
    Planet.select((temperatureColumn * 1.8 + 32).aliased("farenheit"))
    ```
    
    > :point_up: **Note**: an expression like `nameColumn + "rrr"` will be interpreted by SQLite as a numerical addition (with funny results), not as a string concatenation.

- `AND`, `OR`, `NOT`
    
    The SQL logical operators are derived from the Swift `&&`, `||` and `!`:
    
    ```swift
    // SELECT * FROM "persons" WHERE ((NOT "verified") OR ("age" < 18))
    Person.filter(!verifiedColumn || ageColumn < 18)
    ```

- `BETWEEN`, `IN`, `IN (subquery)`, `NOT IN`, `NOT IN (subquery)`
    
    To check inclusion in a collection, call the `contains` method on any Swift sequence:
    
    ```swift
    // SELECT * FROM "persons" WHERE ("id" IN (1, 2, 3))
    Person.filter([1, 2, 3].contains(idColumn))
    
    // SELECT * FROM "persons" WHERE ("id" NOT IN (1, 2, 3))
    Person.filter(![1, 2, 3].contains(idColumn))
    
    // SELECT * FROM "persons" WHERE ("age" BETWEEN 0 AND 17)
    Person.filter((0..<18).contains(ageColumn))
    
    // SELECT * FROM "persons" WHERE ("age" BETWEEN 0 AND 17)
    Person.filter((0...17).contains(ageColumn))
    
    // SELECT * FROM "persons" WHERE ("name" BETWEEN 'A' AND 'z')
    Person.filter(("A"..."z").contains(nameColumn))
    
    // SELECT * FROM "persons" WHERE (("name" >= 'A') AND ("name" < 'z'))
    Person.filter(("A"..<"z").contains(nameColumn))
    ```
    
    > :point_up: **Note**: SQLite string comparison, by default, is case-sensitive and not Unicode-aware. See [string comparison](#string-comparison) if you need more control.
    
    To check inclusion in a subquery, call the `contains` method on another request:
    
    ```swift
    // SELECT * FROM "events"
    //  WHERE ("userId" IN (SELECT "id" FROM "persons" WHERE "verified"))
    let verifiedUserIds = User.select(idColumn).filter(verifiedColumn)
    Event.filter(verifiedUserIds.contains(userIdColumn))
    ```

- `EXISTS (subquery)`, `NOT EXISTS (subquery)`

    To check is a subquery would return any row, use the `exists` property on another request:
    
    ```swift
    // SELECT * FROM "persons"
    // WHERE EXISTS (SELECT * FROM "books"
    //                WHERE books.ownerId = persons.id)
    Person.filter(Book.filter(sql: "books.ownerId = persons.id").exists)
    ```


#### SQL Functions

- `ABS`, `AVG`, `COUNT`, `MAX`, `MIN`, `SUM`:
    
    Those are based on the `abs`, `average`, `count`, `max`, `min` and `sum` Swift functions:
    
    ```swift
    // SELECT MIN("age"), MAX("age") FROM persons
    Person.select(min(ageColumn), max(ageColumn))
    
    // SELECT COUNT("name") FROM persons
    Person.select(count(nameColumn))
    
    // SELECT COUNT(DISTINCT "name") FROM persons
    Person.select(count(distinct: nameColumn))
    ```

- `IFNULL`
    
    Use the Swift `??` operator:
    
    ```swift
    // SELECT IFNULL("name", 'Anonymous') FROM persons
    Person.select(nameColumn ?? "Anonymous")
    
    // SELECT IFNULL("name", "email") FROM persons
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
    
    // SELECT f("name") FROM persons
    Person.select(f.apply(nameColumn))
    ```

    
### Fetching from Requests

Once you have a request, you can fetch the records at the origin of the request:

```swift
// Some request based on `Person`
let request = Person.filter(...)... // FetchRequest<Person>

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


### Fetching By Primary Key

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


### Fetching Aggregated Values

**Requests can count.** The `fetchCount()` method returns the number of rows that would be returned by a fetch request:

```swift
// SELECT COUNT(*) FROM "persons"
let count = Person.fetchCount(db) // Int

// SELECT COUNT(*) FROM "persons" WHERE "email" IS NOT NULL
let count = Person.filter(emailColumn != nil).fetchCount(db)

// SELECT COUNT(DISTINCT "name") FROM "persons"
let count = Person.select(nameColumn).distinct.fetchCount(db)

// SELECT COUNT(*) FROM (SELECT DISTINCT "name", "age" FROM "persons")
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


## Migrations

**Migrations** are a convenient way to alter your database schema over time in a consistent and easy way.

Migrations run in order, once and only once. When a user upgrades your application, only non-applied migrations are run.

```swift
var migrator = DatabaseMigrator()

// v1.0 database
migrator.registerMigration("createTables") { db in
    try db.execute(
        "CREATE TABLE persons (...); " +
        "CREATE TABLE books (...)")
}

// v2.0 database
migrator.registerMigration("AddBirthDateToPersons") { db in
    try db.execute(
        "ALTER TABLE persons ADD COLUMN birthDate DATE")
}

// Migrations for future versions will be inserted here:
//
// // v3.0 database
// migrator.registerMigration("AddYearAgeToBooks") { db in
//     try db.execute(
//         "ALTER TABLE books ADD COLUMN year INT")
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
    try db.execute(
        "CREATE TABLE new_persons (id INTEGER PRIMARY KEY, name TEXT NOT NULL);" +
        "INSERT INTO new_persons SELECT * FROM persons;" +
        "DROP TABLE persons;" +
        "ALTER TABLE new_persons RENAME TO persons;")
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

**A transaction observer is notified of all database changes**, inserts, updates and deletes, including indirect ones triggered by ON DELETE and ON UPDATE actions associated to [foreign keys](https://www.sqlite.org/foreignkeys.html#fk_actions).

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

Updates and moves are nicer to the eye when your perform table view animations. They require the controller to identify individual records in the fetched database rows. You must tell the controller how to do so:

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

In the [installation](#installation) phase, use the GRDBCipher framework instead of GRDB. CocoaPods is not supported.

Set the `passphrase` property of the database configuration before opening your [database connection](#database-connections):

```swift
import GRDBCipher

var configuration = Configuration()
configuration.passphrase = "secret"
let dbQueue = try DatabaseQueue(path: "...", configuration: configuration)
```

You can change the passphrase of an encrypted database:

```swift
try dbQueue.changePassphrase("newSecret")
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

**No SQLite error goes unnoticed.**

Some GRDB functions throw a DatabaseError (see [the list of SQLite error codes](https://www.sqlite.org/rescode.html)):

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

Fatal errors uncover programmer errors, false assumptions, and prevent misuses:

```swift
// fatal error:
// SQLite error 1 with statement `SELECT * FROM boooks`:
// no such table: boooks
Row.fetchAll(db, "SELECT * FROM boooks")
// solution: fix the SQL query:
Row.fetchAll(db, "SELECT * FROM books")

// fatal error: could not convert NULL to String.
let name: String = row.value(named: "name")
// solution: fix the contents of the database, or load an optional:
let name: String? = row.value(named: "name")

// fatal error: Database methods are not reentrant.
dbQueue.inDatabase { db in
    dbQueue.inDatabase { db in
        ...
    }
}
// solution: avoid reentrancy, and instead pass a database connection along.
```

**Fatal errors can be avoided**. For example, let's consider the code below:

```swift
let sql = "SELECT ..."
let arguments: NSDictionary = ...
let rows = Row.fetchAll(db, sql, arguments: StatementArguments(arguments))
```

It has several opportunities to throw fatal errors:

- The sql string may contain invalid sql, or refer to non-existing tables or columns.
- The dictionary may contain objects that can't be converted to database values.
- The dictionary may miss values required by the statement.

To avoid fatal errors, you have to expose and handle each failure point by going down one level in GRDB API:

```swift
// Dictionary arguments may contain invalid values:
if let arguments = StatementArguments(arguments) {
    
    // SQL may be invalid
    let statement = try db.selectStatement(sql)
    
    // Arguments may not fit the statement
    try statement.validateArguments(arguments)
    
    // OK now
    let rows = Row.fetchAll(statement, arguments: arguments)
}
```

See [prepared statements](#prepared-statements) for more information.


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

The comparison result comes from a *collating function*, or *collation*. SQLite comes with [three built-in collations](https://www.sqlite.org/datatype3.html#collation) that do not support Unicode.

GRDB comes with five extra collations that leverage unicode-aware comparisons based on the standard Swift String comparison functions and operators:

- `unicodeCompare` (uses the built-in `<=` and `==` operators)
- `caseInsensitiveCompare`
- `localizedCaseInsensitiveCompare`
- `localizedCompare`
- `localizedStandardCompare`

A collation can be applied to a table column. All comparisons involving this column will then automatically trigger the comparison function:
    
```swift
let collation = DatabaseCollation.localizedCaseInsensitiveCompare
try db.execute(
    "CREATE TABLE persons (" +
        "name TEXT COLLATE \(collation.name)" +
    ")")

// Persons are sorted in a localized case insensitive way:
let persons = Person.order(nameColumn).fetchAll(db)
```

If you can't or don't want to define the comparison behavior of a column, you can still use an explicit collation in SQL requests and in the [query interface](#the-query-interface):

```swift
let collation = DatabaseCollation.localizedCaseInsensitiveCompare
let persons = Person.fetchAll(db,
    "SELECT * FROM persons ORDER BY name COLLATE \(collation.name))")
let persons = Person.order(nameColumn.collating(collation)).fetchAll(db)
let persons = Person.filter(uuidColumn.collating("NOCASE") == uuid).fetchAll(db)
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

First have a detailed look at the full API of [DatabaseQueue](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/Classes/DatabaseQueue.html) and [DatabasePool](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/Classes/DatabasePool.html). Both adopt the [DatabaseReader](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/Protocols/DatabaseReader.html) and [DatabaseWriter](http://cocoadocs.org/docsets/GRDB.swift/0.72.0/Protocols/DatabaseWriter.html) protocols, so that you can write code that targets both classes.

If the built-in queues and pools do not fit your needs, or if you can not guarantee that a single queue or pool is accessing your database file, you may have a look at:

- General discussion about isolation in SQLite: https://www.sqlite.org/isolation.html
- Types of locks and transactions: https://www.sqlite.org/lang_transaction.html
- WAL journal mode: https://www.sqlite.org/wal.html
- Busy handlers: https://www.sqlite.org/c3ref/busy_handler.html

See also [Transactions](#transactions-and-savepoints) for more precise handling of transactions, and [Configuration](GRDB/Core/Configuration.swift) for more precise handling of eventual SQLITE_BUSY errors.


FAQ
===

- **Generic parameter 'T' could not be inferred**
    
    You may get this error when using DatabaseQueue.inDatabase, DatabasePool.read, or DatabasePool.write:
    
    ```swift
    // Generic parameter 'T' could not be inferred
    let x = dbQueue.inDatabase { db in
        let result = String.fetchOne(db, ...)
        return result
    }
    ```
    
    This is a Swift compiler bug (see [SR-1570](https://bugs.swift.org/browse/SR-1570)).
    
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


Sample Code
===========

- The [Documentation](#documentation) is full of GRDB snippets.
- [GRDBDemoiOS](DemoApps/GRDBDemoiOS): A sample iOS application.
- Check `GRDB.xcworkspace`: it contains GRDB-enabled playgrounds to play with.
- How to read and write NSDate as timestamp: [DatabaseTimestamp.playground](Playgrounds/DatabaseTimestamp.playground/Contents.swift)
- How to synchronize a database table with a JSON payload: [JSONSynchronization.playground](Playgrounds/JSONSynchronization.playground/Contents.swift)
- A class that behaves like NSUserDefaults, but backed by SQLite: [UserDefaults.playground](Playgrounds/UserDefaults.playground/Contents.swift)
- How to notify view controllers of database changes: [TableChangeObserver.swift](https://gist.github.com/groue/2e21172719e634657dfd)


---

**Thanks**

- [Pierlis](http://pierlis.com), where we write great software.
- [Vladimir Babin](https://github.com/Chiliec), [Pascal Edmond](https://github.com/pakko972), [@peter-ss](https://github.com/peter-ss), [Pierre-Loïc Raynaud](https://github.com/pierlo), [Steven Schveighoffer](https://github.com/schveiguy) and [@swiftlyfalling](https://github.com/swiftlyfalling) for their contributions, help, and feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [Mathieu "Kali" Poumeyrol](https://github.com/kali) because SQL.
- [ccgus/fmdb](https://github.com/ccgus/fmdb) for its excellency.
