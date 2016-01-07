GRDB.swift
==========

GRDB.swift is an [SQLite](https://www.sqlite.org) toolkit for Swift 2.

It ships with a low-level database API, plus application-level tools.

**January 7, 2016: GRDB.swift 0.37.1 is out** - [Release notes](CHANGELOG.md). Follow [@groue](http://twitter.com/groue) on Twitter for release announcements and usage tips.

**Requirements**: iOS 7.0+ / OSX 10.9+, Xcode 7+

**Swift Package Manager**: Use the [Swift2.2 branch](https://github.com/groue/GRDB.swift/tree/Swift2.2).


But Why?
--------

Why GRDB, when we already have the excellent [ccgus/fmdb](https://github.com/ccgus/fmdb), and the very popular [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift)?

**GRDB owes a lot to FMDB.** You will use the familiar and safe [database queues](#database-queues) you are used to. Yet you may appreciate that [database errors](#error-handling) are handled in the Swift way, and that [fetching data](#fetch-queries) is somewhat easier.

**Your SQL skills are rewarded here.** GRDB grants equal treatment to all queries, simple or complex.

**GRDB provides [protocols and a Record class](#database-protocols-and-record)** that help isolating database management code into database layer types, and avoid cluterring the rest of your application.

**GRDB is fast**. As fast, and usually faster, than FMDB and SQLite.swift.

**You can query your database [right from the debugger](https://twitter.com/groue/status/679347658557902849).**


Features
--------

- **A low-level [SQLite API](#sqlite-api)** that leverages the Swift 2 standard library.
- **[Protocols and a ready-made class](#database-protocols-and-record)** that eat your SQL queries for breakfast, provide persistence, and changes tracking.
- **[Swift type freedom](#values)**: pick the right Swift type that fits your data. Use Int64 when needed, or stick with the convenient Int. Store and read NSDate or NSDateComponents. Declare Swift enums for discrete data types. Define your own database-convertible types.
- **[Database migrations](#migrations)**
- **[Database changes observation hooks](#database-changes-observation)**


Documentation
=============

- **[GRDB Reference](http://cocoadocs.org/docsets/GRDB.swift/0.37.1/index.html)** (on cocoadocs.org)

- **[Installation](#installation)**

- **[SQLite API](#sqlite-api)**
    - [SQLite API Overview](#sqlite-api-overview)
    - [Database Queues](#database-queues)
    - [Executing Updates](#executing-updates)
    - [Fetch Queries](#fetch-queries)
        - [Row Queries](#row-queries)
        - [Value Queries](#value-queries)
    - [Values](#values)
        - [NSData](#nsdata-and-memory-savings)
        - [NSDate and NSDateComponents](#nsdate-and-nsdatecomponents)
        - [Swift enums](#swift-enums)
        - [Custom Value Types](#custom-value-types)
    - [Transactions](#transactions)
    - [Error Handling](#error-handling)
    - Advanced topics:
        - [Prepared Statements](#prepared-statements)
        - [Concurrency](#concurrency)
        - [Custom SQL Functions](#custom-sql-functions)
        - [Custom Collations](#custom-collations)
        - [Raw SQLite Pointers](#raw-sqlite-pointers)
    
    
- **[Migrations](#migrations)**: Transform your database as your application evolves.

- **[Database Protocols, and Record](#database-protocols-and-record)**
    - [RowConvertible Protocol](#rowconvertible-protocol): Don't fetch rows, fetch your custom types instead.
    - [DatabasePersistable Protocol](#databasepersistable-protocol): Grant any type with persistence methods.
    - [Record](#record): The class that wraps a table row or the result of any query, provides persistence methods, and changes tracking.

- **[Database Changes Observation](#database-changes-observation)**: A robust way to perform post-commit and post-rollback actions.

- **[Sample Code](#sample-code)**


Installation
============

### iOS7

You can use GRDB.swift in a project targetting iOS7. See [GRDBDemoiOS7](DemoApps/GRDBDemoiOS7) for more information.


### CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Xcode projects.

To use GRDB.swift with Cocoapods, specify in your Podfile:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

pod 'GRDB.swift', '0.37.1'
```


### Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency manager for Xcode projects.

To use GRDB.swift with Carthage, specify in your Cartfile:

```
github "groue/GRDB.swift" == 0.37.1
```


### Manually

1. Download a copy of GRDB.swift.
2. Embed the `GRDB.xcodeproj` project in your own project.
3. Add the `GRDBOSX` or `GRDBiOS` target in the **Target Dependencies** section of the **Build Phases** tab of your application target.
4. Add `GRDB.framework` to the **Embedded Binaries** section of the **General**  tab of your target.

See [GRDBDemoiOS](DemoApps/GRDBDemoiOS) for an example of such integration.


SQLite API
==========

## SQLite API Overview

```swift
import GRDB

// Open connection to database
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

try dbQueue.inDatabase { db in
    // Create tables
    try db.execute("CREATE TABLE wines (...)")
    
    // Insert
    let changes = try db.execute("INSERT INTO wines (color, name) VALUES (?, ?)",
        arguments: [Color.Red, "Pomerol"])
    let wineId = changes.insertedRowID
    print("Inserted wine id: \(wineId)")
    
    // Fetch rows
    for row in Row.fetch(db, "SELECT * FROM wines") {
        let name: String = row.value(named: "name")
        let color: Color = row.value(named: "color")
        print(name, color)
    }
    
    // Fetch values
    let redWineCount = Int.fetchOne(db,
        "SELECT COUNT(*) FROM wines WHERE color = ?",
        arguments: [Color.Red])!
}
```


## Database Queues

You access SQLite databases through **thread-safe database queues** (inspired by [ccgus/fmdb](https://github.com/ccgus/fmdb)):

```swift
import GRDB

let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let inMemoryDBQueue = DatabaseQueue()
```

SQLite creates the database file if it does not already exist.

The connection is closed when the database queue gets deallocated.


**Configure** databases:

```swift
var config = Configuration()
config.trace = { print($0) } // Prints all SQL statements

let dbQueue = try DatabaseQueue(
    path: "/path/to/database.sqlite",
    configuration: config)
```

See [Configuration](http://cocoadocs.org/docsets/GRDB.swift/0.37.1/Structs/Configuration.html) and [Concurrency](#concurrency) for more details.


Once connected, the `inDatabase` and `inTransaction` methods perform your **database statements** in a dedicated, serial, queue:

```swift
// Execute database statements:
dbQueue.inDatabase { db in
    for row in Row.fetch(db, "SELECT * FROM wines") {
        let name: String = row.value(named: "name")
        let color: Color = row.value(named: "color")
        print(name, color)
    }
}

// Extract values from the database:
let wineCount = dbQueue.inDatabase { db in
    Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
}

// Wrap database statements in a transaction:
try dbQueue.inTransaction { db in
    try db.execute("INSERT ...")
    try db.execute("DELETE FROM ...")
    return .Commit
}
```

See [Transactions](#transactions) for more information about GRDB transaction handling.


## Executing Updates

The `Database.execute` method executes the SQL statements that do not return any database row, such as `CREATE TABLE`, `INSERT`, `DELETE`, `ALTER`, etc.

For example:

```swift
try dbQueue.inDatabase { db in
    try db.execute(
        "CREATE TABLE persons (" +
            "id INTEGER PRIMARY KEY," +
            "name TEXT NOT NULL," +
            "age INT" +
        ")")
        
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (?, ?)",
        arguments: ["Arthur", 36])
        
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (:name, :age)",
        arguments: ["name": "Barbara", "age": 39])
}
```

The `?` and colon-prefixed keys like `:name` in the SQL query are the **statements arguments**. You pass arguments in with arrays or dictionaries, as in the example above (arguments are actually of type StatementArguments, which happens to adopt the ArrayLiteralConvertible and DictionaryLiteralConvertible protocols).

See [Values](#values) for more information on supported arguments types (Bool, Int, String, NSDate, Swift enums, etc.).

**After an INSERT statement**, you extract the inserted Row ID from the result of the `execute` method:

```swift
let insertedRowID = try db.execute(
    "INSERT INTO persons (name, age) VALUES (?, ?)",
    arguments: ["Arthur", 36]).insertedRowID
```


## Fetch Queries

GRDB lets you fetch **rows**, **values**, and **custom models**.

**Rows** are the results of SQL queries (see [row queries](#row-queries)):

```swift
dbQueue.inDatabase { db in
    for row in Row.fetch(db, "SELECT * FROM wines") {
        let name: String = row.value(named: "name")
        let color: Color = row.value(named: "color")
        print(name, color)
    }
}
```

**Values** are the Bool, Int, String, NSDate, Swift enums, etc that feed your application (see [value queries](#value-queries)):

```swift
dbQueue.inDatabase { db in
    let redWineCount = Int.fetchOne(db,
        "SELECT COUNT(*) FROM wines WHERE color = ?",
        arguments: [Color.Red])!
}
```

**Custom models** are your application objects that can initialize themselves from rows (see the [RowConvertible protocol](#rowconvertible-protocol) and the [Record class](#record)):

```swift
dbQueue.inDatabase { db in
    let wines = Wine.fetchAll(db, "SELECT * FROM wines ORDER BY name")
    let favoriteWine = Wine.fetchOne(db, key: user.favoriteWineId)
}
```


### Row Queries

- [Fetching Rows](#fetching-rows)
- [Column Values](#column-values)
- [Rows as Dictionaries](#rows-as-dictionaries)
- [Convenience Rows](#convenience-rows)


#### Fetching Rows

Fetch **sequences** of rows, **arrays**, or a **single** row:

```swift
dbQueue.inDatabase { db in
    Row.fetch(db, "SELECT ...", arguments: ...)     // DatabaseSequence<Row>
    Row.fetchAll(db, "SELECT ...", arguments: ...)  // [Row]
    Row.fetchOne(db, "SELECT ...", arguments: ...)  // Row?
    
    for row in Row.fetch(db, "SELECT * FROM wines") {
        let name: String = row.value(named: "name")
        let color: Color = row.value(named: "color")
        print(name, color)
    }
}
```

Arguments are optional arrays or dictionaries that fill the positional `?` and colon-prefixed keys like `:name` in the query:

```swift
let rows = Row.fetch(db,
    "SELECT * FROM persons WHERE name = ?",
    arguments: ["Arthur"])

let rows = Row.fetch(db,
    "SELECT * FROM persons WHERE name = :name",
    arguments: ["name": "Arthur"])
```

See [Values](#values) for more information on supported arguments types (Bool, Int, String, NSDate, Swift enums, etc.).

Both `fetch` and `fetchAll` let you iterate the full list of fetched rows. The differences are:

- `fetchAll` performs a single request, and returns an array that can be iterated on any thread. It can take a lot of memory.
- `fetch` returns a sequence that performs a new request each time it is iterated. It must be consumed in the database queue (you'll get a fatal error if you do otherwise).

Row sequences also grant the fastest access to the database. This performance advantage comes with extra precautions:

> :point_up: **Don't turn a row sequence into an array** with `Array(rowSequence)` or `rowSequence.filter { ... }`: you would not get the distinct rows you expect. To get an array, use `Row.fetchAll(...)`.
> 
> :point_up: **Make sure you copy a row** whenever you extract it from a sequence for later use: `row.copy()`. This does not apply to row arrays, which already contain independent copies of the database rows.


#### Column Values

**Read column values** by index or column name:

```swift
let name: String = row.value(atIndex: 0)    // 0 is the leftmost column
let name: String = row.value(named: "name")
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
let dateString: String = row.value(named: "date")       // "2015-09-11 18:14:15.123"
let date: NSDate       = row.value(named: "date")       // NSDate
self.date = row.value(named: "date") // Depends on the type of the property.
```

You can also use the `as` type casting operator:

```swift
row.value(...) as Int
row.value(...) as Int?
row.value(...) as Int!
```

> :warning: **Warning**: avoid the `as!` and `as?` operators (see [rdar://21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
> 
> ```swift
> row.value(...) as! Int   // NO NO NO DON'T DO THAT!
> row.value(...) as? Int   // NO NO NO DON'T DO THAT!
> ```

When you ask for a missing column, you will get nil, or a fatal error:

```swift
let row = Row.fetchOne(db, "SELECT 'foo' AS foo")!
row.value(named: "missing") as String? // nil
row.value(named: "missing") as String  // fatal error: no such column: missing
row.value(atIndex: 1)                  // fatal error: row index out of range
```

You can explicitly check for a column presence with the `hasColumn` method.

Generally speaking, you can extract the type you need, *provided it can be converted from the underlying SQLite value*:

- **Successful conversions include:**
    
    - Numeric (integer and real) SQLite values to Swift Int, Int32, Int64, Double and Bool (zero is the only false boolean).
    - Text SQLite values to Swift String.
    - Blob SQLite values to NSData.
    
    See [Values](#values) for more information on supported types (NSDate, Swift enums, etc.).

- **Invalid conversions return nil.**

    ```swift
    let row = Row.fetchOne(db, "SELECT 'foo'")!
    row.value(atIndex: 0) as String  // "foo"
    row.value(atIndex: 0) as NSDate? // nil
    row.value(atIndex: 0) as NSDate  // fatal error: could not convert "foo" to NSDate.
    ```

- **GRDB crashes when you try to convert NULL to a non-optional value.**
    
    This behavior is notably different from SQLite C API, or from ccgus/fmdb, that both turn NULL to 0 when extracting an integer, for example:
    
    ```swift
    let row = Row.fetchOne(db, "SELECT NULL")!
    row.value(atIndex: 0) as Int? // nil
    row.value(atIndex: 0) as Int  // fatal error: could not convert NULL to Int.
    ```

- **The convenience conversions of SQLite, such as Blob to String, String to Int, or huge Double values to Int, are not guaranteed to apply.** You must not rely on them.


#### Rows as Dictionaries

You may prefer thinking of rows as dictionaries of `DatabaseValue`, an intermediate type between SQLite and your values:

```swift
// Test if the column `date` is present:
if let databaseValue = row["date"] {
    
    // Pick the type you need:
    let dateString: String = databaseValue.value() // "2015-09-11 18:14:15.123"
    let date: NSDate = databaseValue.value()       // NSDate
    self.date = databaseValue.value() // Depends on the type of the property.
    
    // Check for NULL:
    if databaseValue.isNull {
        print("NULL")
    }
    
    // The five SQLite storage classes:
    switch databaseValue.storage {
    case .Null:
        print("NULL")
    case .Int64(let int64):
        print("Int64: \(int64)")
    case .Double(let double):
        print("Double: \(double)")
    case .String(let string):
        print("String: \(string)")
    case .Blob(let data):
        print("NSData: \(data)")
    }
}
```

Iterate all the tuples (columnName, databaseValue) in a row, from left to right:

```swift
for (columnName, databaseValue) in row {
    ...
}
```

Rows are not real dictionaries, though. They may contain duplicate keys:

```swift
let row = Row.fetchOne(db, "SELECT 1 AS foo, 2 AS foo")!
row.columnNames     // ["foo", "foo"]
row.databaseValues  // [1, 2]
row["foo"]          // 1 (the value for the leftmost column "foo")
for (columnName, databaseValue) in row { ... } // ("foo", 1), ("foo", 2)
```


#### Convenience Rows

From time to time, you'll want to build a custom Row from scratch. Use the dictionary and NSDictionary initializers:

```swift
Row(["name": "foo", "date": nil])
```

See [Values](#values) for more information on supported types.


### Value Queries

Instead of rows, you can directly fetch **[values](#values)**. Like rows, fetch them as **sequences**, **arrays**, or **single** values. Values are extracted from the leftmost column of the SQL queries:

```swift
dbQueue.inDatabase { db in
    Int.fetch(db, "SELECT ...", arguments: ...)    // DatabaseSequence<Int>
    Int.fetchAll(db, "SELECT ...", arguments: ...) // [Int]
    Int.fetchOne(db, "SELECT ...", arguments: ...) // Int?

    // When database may contain NULL:
    Optional<Int>.fetch(db, "SELECT ...", arguments: ...)    // DatabaseSequence<Int?>
    Optional<Int>.fetchAll(db, "SELECT ...", arguments: ...) // [Int?]
}
```

There are many supported value types (Bool, Int, String, NSDate, Swift enums, etc.). See [Values](#values) for more information:

```swift
dbQueue.inDatabase { db in
    // The number of persons with an email ending in @example.com:
    let count = Int.fetchOne(db,
        "SELECT COUNT(*) FROM persons WHERE email LIKE ?",
        arguments: ["%@example.com"])!
    
    // All URLs:
    let urls = NSURL.fetchAll(db, "SELECT url FROM links")
    
    // The emails of people who own at least two pets:
    let emails = Optional<String>.fetchAll(db,
        "SELECT persons.email " +
        "FROM persons " +
        "JOIN pets ON pets.masterId = persons.id " +
        "GROUP BY persons.id " +
        "HAVING COUNT(pets.id) >= 2")
}
```

Both `fetch` and `fetchAll` let you iterate the full list of fetched values. The differences are:

- `fetchAll` performs a single request, and returns an array that can be iterated on any thread. It can take a lot of memory.
- `fetch` returns a sequence that performs a new request each time it is iterated. It must be consumed in the database queue (you'll get a fatal error if you do otherwise).

`fetchOne` returns an optional value which is nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value.


## Values

GRDB ships with built-in support for the following value types:

- **Swift Standard Library**: Bool, Float, Double, Int, Int32, Int64, String, [Swift enums](#swift-enums).
    
- **Foundation**: [NSData](#nsdata-and-memory-savings), [NSDate](#nsdate-and-nsdatecomponents), [NSDateComponents](#nsdate-and-nsdatecomponents), NSNull, NSNumber, NSString, NSURL.
    
- **CoreGraphics**: CGFloat.

All those types can be used as [statement arguments](#executing-updates):

```swift
let url: NSURL = ...
let verified: Bool = ...
try db.execute(
    "INSERT INTO links (url, verified) VALUES (?, ?)",
    arguments: [url, verified])
```

They can be [extracted from rows](#column-values):

```swift
for row in Row.fetch(db, "SELECT * FROM links") {
    let url: NSURL = row.value(named: "url")
    let verified: Bool = row.value(named: "verified")
}
```

They can be [directly fetched](#value-queries) from the database:

```swift
let urls = NSURL.fetchAll(db, "SELECT url FROM links")  // [NSURL]
```

Use them in the `persistentDictionary` property of [DatabasePersistable protocol](#databasepersistable-protocol) and [Record subclasses](#record):

```swift
class Link : Record {
    var url: NSURL?
    var verified: Bool
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["url": url, "verified": verified]
    }
}
```

Your custom value types are supported as well, through the [DatabaseValueConvertible](#custom-value-types) protocol.


### NSData (and Memory Savings)

**NSData** suits the BLOB SQLite columns. It can be stored and fetched from the database just like other value types:

```swift
let row = Row.fetchOne(db, "SELECT data, ...")!
let data: NSData = row.value(named: "data")

NSData.fetch(db, "SELECT ...")       // DatabaseSequence<NSData>
NSData.fetchAll(db, "SELECT ...")    // [NSData]
NSData.fetchOne(db, "SELECT ...")    // NSData?
```

Yet, when extracting NSData from a row, **you have the opportunity to save memory by not copying the data fetched by SQLite**, using the `dataNoCopy()` method:

```swift
for row in Row.fetch(db, "SELECT data, ...") {
    let data = row.dataNoCopy(named: "data")     // NSData?

    // When the column `data` may not be there:
    if row.hasColumn("data") {
        let data = row.dataNoCopy(named: "data") // NSData?
    }
}
```

> :point_up: **Note**: The non-copied data does not live longer than the iteration step: make sure that you do not use it past this point.

Compare with the **anti-patterns** below:

```swift
for row in Row.fetch(db, "SELECT data, ...") {
    // Data is copied, row after row:
    let data: NSData = row.value(named: "data")
    
    // Data is copied, row after row:
    if let databaseValue = row["data"] {
        let data: NSData = databaseValue.value()
    }
}

// All rows have been copied in memory when the loop begins:
for row in Row.fetchAll(db, "SELECT data, ...") {
    // Too late to do the right thing:
    let data = row.dataNoCopy(named: "data")
}
```


### NSDate and NSDateComponents

[**NSDate**](#nsdate) and [**NSDateComponents**](#nsdatecomponents) can be stored and fetched from the database.

Here is the support provided by GRDB.swift for the various [date formats](https://www.sqlite.org/lang_datefunc.html) supported by SQLite:

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

**GRDB stores NSDate using the format "yyyy-MM-dd HH:mm:ss.SSS" in the UTC time zone.**

> :point_up: **Note**: This format is lexically comparable with SQLite's CURRENT_TIMESTAMP, which means that your ORDER BY clauses will behave as expected.
>
> Yet, this format may not fit your needs. We provide below some sample code for [storing dates as timestamps](#custom-value-types). You can adapt it for your application.

Declare DATETIME columns in your tables:

```swift
try db.execute(
    "CREATE TABLE persons (" +
    "creationDate DATETIME, " +
    "...)")
```

Store NSDate into the database:

```swift
let creationDate = NSDate()
try db.execute("INSERT INTO persons (creationDate, ...) " +
                            "VALUES (?, ...)",
                         arguments: [creationDate, ...])
```

Extract NSDate from the database:

```swift
let row = Row.fetchOne(db, "SELECT creationDate, ...")!
let date: NSDate = row.value(named: "creationDate")

NSDate.fetch(db, "SELECT ...")       // DatabaseSequence<NSDate>
NSDate.fetchAll(db, "SELECT ...")    // [NSDate]
NSDate.fetchOne(db, "SELECT ...")    // NSDate?
```

See [Column Values](#column-values) and [Value Queries](#value-queries) for more information.


#### NSDateComponents

NSDateComponents is indirectly supported, through the **DatabaseDateComponents** helper type.

DatabaseDateComponents reads date components from all [date formats supported by SQLite](https://www.sqlite.org/lang_datefunc.html), and stores them in the format of your choice, from HH:MM to YYYY-MM-DD HH:MM:SS.SSS.

Declare DATETIME columns in your tables:

```swift
try db.execute(
    "CREATE TABLE persons (" +
    "birthDate DATETIME, " +
    "...)")
```

Store NSDateComponents into the database:

```swift
let components = NSDateComponents()
components.year = 1973
components.month = 9
components.day = 18

// The .YMD format stores "1973-09-18" in the database.
let dbComponents = DatabaseDateComponents(components, format: .YMD)
try db.execute("INSERT INTO persons (birthDate, ...) " +
                            "VALUES (?, ...)",
                         arguments: [dbComponents, ...])
```

Extract NSDateComponents from the database:

```swift
let row = Row.fetchOne(db, "SELECT birthDate ...")!
let dbComponents: DatabaseDateComponents = row.value(named: "birthDate")
dbComponents.format         // .YMD (the actual format found in the database)
dbComponents.dateComponents // NSDateComponents

DatabaseDateComponents.fetch(db, "SELECT ...")    // DatabaseSequence<DatabaseDateComponents>
DatabaseDateComponents.fetchAll(db, "SELECT ...") // [DatabaseDateComponents]
DatabaseDateComponents.fetchOne(db, "SELECT ...") // DatabaseDateComponents?
```

See [Column Values](#column-values) and [Value Queries](#value-queries) for more information.


### Swift Enums

**Swift enums** get full support from GRDB.swift as long as their raw values are Int, Int32, Int64 or String.

Given those two enums:

```swift
enum Color : Int {
    case Red
    case White
    case Rose
}

enum Grape : String {
    case Chardonnay
    case Merlot
    case Riesling
}
```

Simply add those two lines:

```swift
extension Color : DatabaseIntRepresentable { } // DatabaseInt32Representable for Int32, DatabaseInt64Representable for Int64
extension Grape : DatabaseStringRepresentable { }
```

And both types gain database powers:

```swift
// Store:
try db.execute("INSERT INTO wines (grape, color) VALUES (?, ?)",
               arguments: [Grape.Merlot, Color.Red])

// Extract from row:
for rows in Row.fetch(db, "SELECT * FROM wines") {
    let grape: Grape = row.value(named: "grape")
    let color: Color = row.value(named: "color")
}

// Direct fetch:
Color.fetch(db, "SELECT ...", arguments: ...)    // DatabaseSequence<Color>
Color.fetchAll(db, "SELECT ...", arguments: ...) // [Color]
Color.fetchOne(db, "SELECT ...", arguments: ...) // Color?
```

See [Column Values](#column-values) and [Value Queries](#value-queries) for more information.


### Custom Value Types

Conversion to and from the database is based on the `DatabaseValueConvertible` protocol:

```swift
public protocol DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns a value initialized from databaseValue, if possible.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self?
}
```

All types that adopt this protocol can be used wherever the built-in types `Int`, `String`, etc. are used. without any limitation or caveat. Those built-in types actually adopt it.

The `databaseValue` property returns [DatabaseValue](GRDB/Core/DatabaseValue.swift), a type that wraps the five types supported by SQLite: NULL, Int64, Double, String and NSData. DatabaseValue has no public initializer: to create one, use `DatabaseValue.Null`, or the fact that Int, String, etc. adopt the protocol: `1.databaseValue`, `"foo".databaseValue`.

The `fromDatabaseValue()` factory method returns an instance of your custom type, if the databaseValue contains a suitable value.

As an example, let's write an alternative to the built-in [NSDate](#nsdate-and-nsdatecomponents) behavior, and store dates as timestamps. Our sample DatabaseTimestamp type applies all the best practices for a great GRDB.swift integration:

```swift
struct DatabaseTimestamp: DatabaseValueConvertible {
    
    // NSDate conversion
    //
    // Value types should consistently use the Swift nil to represent the
    // database NULL: the date property is a non-optional NSDate.
    let date: NSDate
    
    // As a convenience, the NSDate initializer accepts an optional NSDate, and
    // is failable: the result is nil if and only if *date* is nil.
    init?(_ date: NSDate?) {
        guard let date = date else {
            return nil
        }
        self.date = date
    }
    
    
    // DatabaseValueConvertible adoption
    
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue {
        // Double itself adopts DatabaseValueConvertible:
        return date.timeIntervalSince1970.databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> DatabaseTimestamp? {
        // Double itself adopts DatabaseValueConvertible:
        guard let timeInterval = Double.fromDatabaseValue(databaseValue) else {
            // No Double, no NSDate!
            return nil
        }
        return DatabaseTimestamp(NSDate(timeIntervalSince1970: timeInterval))
    }
}
```

As a DatabaseValueConvertible adopter, DatabaseTimestamp can be stored and fetched from the database just like simple types Int and String:

```swift
// Store NSDate
let date = NSDate()
try db.execute("INSERT INTO persons (date, ...) " +
                            "VALUES (?, ...)",
                         arguments: [DatabaseTimestamp(date), ...])

// Extract NSDate from row:
for rows in Row.fetch(db, "SELECT ...") {
    let date = (row.value(named: "date") as DatabaseTimestamp).date
}

// Direct fetch:
DatabaseTimestamp.fetch(db, "SELECT ...")    // DatabaseSequence<DatabaseTimestamp>
DatabaseTimestamp.fetchAll(db, "SELECT ...") // [DatabaseTimestamp]
DatabaseTimestamp.fetchOne(db, "SELECT ...") // DatabaseTimestamp?
```

See [Column Values](#column-values) and [Value Queries](#value-queries) for more information.


## Transactions

The `DatabaseQueue.inTransaction()` method opens an SQLite transaction:

```swift
try dbQueue.inTransaction { db in
    let wine = Wine(color: .Red, name: "Pomerol")
    try wine.insert(db)
    return .Commit
}
```

A ROLLBACK statement is issued if an error is thrown within the transaction block.

Otherwise, transactions are guaranteed to succeed, *provided there is a single DatabaseQueue connected to the database file*. See [Concurrency](#concurrency) for more information about concurrent database access.

If you want to insert a transaction between other database statements, and group those in a single block of code protected by the the database queue, you can use the Database.inTransaction() function:

```swift
try dbQueue.inDatabase { db in
    ...
    try db.inTransaction {
        ...
        return .Commit
    }
    ...
}
```

SQLite supports [three kinds of transactions](https://www.sqlite.org/lang_transaction.html): DEFERRED, IMMEDIATE, and EXCLUSIVE. GRDB defaults to IMMEDIATE.

The transaction kind can be changed in the database configuration, or for each transaction:

```swift
var config = Configuration()
config.defaultTransactionKind = .Deferred
let dbQueue = try DatabaseQueue(path: "...", configuration: config)

// Opens a DEFERRED transaction:
dbQueue.inTransaction { db in ... }

// Opens an EXCLUSIVE transaction:
dbQueue.inTransaction(.Exclusive) { db in ... }
```


## Error Handling

**No SQLite error goes unnoticed.** Yet when such an error happens, some GRDB.swift functions throw a DatabaseError error, and some crash with a fatal error:

```swift
// fatal error:
// SQLite error 1 with statement `SELECT foo FROM bar`: no such table: bar
Row.fetchAll(db, "SELECT foo FROM bar")

do {
    try db.execute(
        "INSERT INTO pets (masterId, name) VALUES (?, ?)",
        arguments: [1, "Bobby"])
} catch let error as DatabaseError {
    // SQLite error 19 with statement `INSERT INTO pets (masterId, name)
    // VALUES (?, ?)` arguments [1, "Bobby"]: FOREIGN KEY constraint failed
    error.description
    
    // The SQLite result code: 19 (SQLITE_CONSTRAINT)
    error.code
    
    // The eventual SQLite message
    // "FOREIGN KEY constraint failed"
    error.message
    
    // The eventual erroneous SQL query
    // "INSERT INTO pets (masterId, name) VALUES (?, ?)"
    error.sql
}
```

See [SQLite Result Codes](https://www.sqlite.org/rescode.html).


**Fatal errors can be avoided.** For example, let's consider a scenario where your application has to perform a fetch query with untrusted SQL and query arguments.

The following code is dangerous for your application, because it has many opportunities to crash:

```swift
func fetchUserQuery(db: Database, sql: String, arguments: NSDictionary) throws -> [Row] {
    // Dictionary arguments may contain invalid values
    guard let arguments = StatementArguments(arguments) else {
        throw NSError(
            domain: "MyDomain",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Invalid arguments"])
    }
    
    // Crashes if sql is invalid, or if arguments don't fit the SQL query
    // (too few, or too many values):
    return Row.fetchAll(db, sql, arguments: arguments)
}

// fatal error: no such table: foo
try fetchUserQuery(db, sql: "SELECT * FROM foo", arguments: NSDictionary())

// fatal error: SQLite statement argument names mismatch: got [:name] instead of [:id].
try fetchUserQuery(db, sql: "SELECT * FROM persons WHERE id = :id", arguments: NSDictionary(dictionary: ["name": "Arthur"]))
```

Compare with the safe version:

```swift
func fetchUserQuery(db: Database, sql: String, arguments: NSDictionary) throws -> [Row] {
    // Dictionary arguments may contain invalid values
    guard let arguments = StatementArguments(arguments) else {
        throw NSError(
            domain: "MyDomain",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Invalid arguments"])
    }
    
    // SQL may be invalid
    let statement = try db.selectStatement(sql)
    
    // Arguments may not fit the statement (too few, or too many values)
    try statement.validateArguments(arguments)
    
    return Row.fetchAll(statement, arguments: arguments)
}
```


## Prepared Statements

**Prepared Statements** let you prepare an SQL query and execute it later, several times if you need, with different arguments.

There are two kinds of prepared statements: **select statements**, and **update statements**:

```swift
try dbQueue.inTransaction { db in
    let updateSQL = "INSERT INTO persons (name, age) VALUES (:name, :age)"
    let updateStatement = try db.updateStatement(updateSQL)
    
    let selectSQL = "SELECT * FROM persons WHERE name = ?"
    let selectStatement = try db.selectStatement(selectSQL)
}
```

The `?` and colon-prefixed keys like `:name` in the SQL query are the statement arguments. You set them with arrays or dictionaries (arguments are actually of type StatementArguments, which happens to adopt the ArrayLiteralConvertible and DictionaryLiteralConvertible protocols).

```swift
// INSERT INTO persons (name, age) VALUES (:name, :age)
updateStatement.arguments = ["name": "Arthur", "age": 41]

// SELECT * FROM persons WHERE name = ?
selectStatement.arguments = ["Arthur"]
```

After arguments are set, you can execute the prepared statement:

```swift
let changes = try updateStatement.execute()
changes.changedRowCount // The number of rows changed by the statement.
changes.insertedRowID   // For INSERT statements, the inserted Row ID.

for row in Row.fetch(selectStatement) { ... }
for person in Person.fetch(selectStatement) { ... }
```

It is possible to set the arguments at the moment of the statement execution:

```swift
// INSERT INTO persons (name, age) VALUES (:name, :age)
try statement.execute(arguments: ["name": "Arthur", "age": 41])

// SELECT * FROM persons WHERE name = ?
let person = Person.fetchOne(selectStatement, arguments: ["Arthur"])
```

Select statements can be used wherever a raw SQL query would fit:

```swift
Row.fetch(statement, arguments: ...)       // DatabaseSequence<Row>
Row.fetchAll(statement, arguments: ...)    // [Row]
Row.fetchOne(statement, arguments: ...)    // Row?

String.fetch(statement, arguments: ...)    // DatabaseSequence<String>
String.fetchAll(statement, arguments: ...) // [String]
String.fetchOne(statement, arguments: ...) // String?

Person.fetch(statement, arguments: ...)    // DatabaseSequence<Person>
Person.fetchAll(statement, arguments: ...) // [Person]
Person.fetchOne(statement, arguments: ...) // Person?
```

See [Row Queries](#row-queries), [Value Queries](#value-queries), [RowConvertible](#rowconvertible-protocol), and [Records](#fetching-records) for more information.


## Concurrency

**When your application has a single DatabaseQueue connected to the database file, it has no concurrency issue.** That is because all your database statements are executed in a single serial dispatch queue that is connected alone to the database.

**Things turn more complex as soon as there are several connections to a database file.**

SQLite concurrency management is fragmented. Documents of interest include:

- General discussion about isolation in SQLite: https://www.sqlite.org/isolation.html
- Types of locks and transactions: https://www.sqlite.org/lang_transaction.html
- WAL journal mode: https://www.sqlite.org/wal.html
- Busy handlers: https://www.sqlite.org/c3ref/busy_handler.html

By default, GRDB opens database in the **default journal mode**, uses **IMMEDIATE transactions**, and registers **no busy handler** of any kind.

See [Configuration](GRDB/Core/Configuration.swift) type and [DatabaseQueue.inTransaction()](GRDB/Core/DatabaseQueue.swift) method for more precise handling of transactions and eventual SQLITE_BUSY errors.


## Custom SQL Functions

**SQLite lets you define SQL functions.**

You can for example use the Unicode support of Swift strings, and go beyond the ASCII limitations of the built-in SQLite `upper()` function:

```swift
dbQueue.inDatabase { db in
    let fn = DatabaseFunction("unicodeUpper", argumentCount: 1, pure: true) { (databaseValues: [DatabaseValue]) in
        // databaseValues is guaranteed to have `argumentCount` elements:
        let dbv = databaseValues[0]
        guard let string: String = dbv.value() else {
            return nil
        }
        return string.uppercaseString
    }
    db.addFunction(fn)
    
    // "É"
    String.fetchOne(db, "SELECT unicodeUpper(?)", arguments: ["é"])!

    // "é"
    String.fetchOne(db, "SELECT upper(?)", arguments: ["é"])!
}
```

See [Rows as Dictionaries](#rows-as-dictionaries) for more information about the `DatabaseValue` type.

The result of a *pure* function only depends on its arguments (unlike the built-in `random()` SQL function, for example). SQLite has the opportunity to perform additional optimizations when functions are pure.

See [Values](#values) for more information on supported arguments and return types (Bool, Int, String, NSDate, Swift enums, etc.).


**Functions can take a variable number of arguments:**

```swift
dbQueue.inDatabase { db in
    let fn = DatabaseFunction("sumOf", pure: true) { (databaseValues: [DatabaseValue]) in
        let ints: [Int] = databaseValues.flatMap { $0.value() }
        return ints.reduce(0, combine: +)
    }
    db.addFunction(fn)
    
    // 6
    Int.fetchOne(db, "SELECT sumOf(1, 2, 3)")!
}
```


**Functions can throw:**

```swift
dbQueue.inDatabase { db in
    let fn = DatabaseFunction("sqrt", argumentCount: 1, pure: true) { (databaseValues: [DatabaseValue]) in
        let dbv = databaseValues[0]
        guard let double: Double = dbv.value() else {
            return nil
        }
        guard double >= 0.0 else {
            throw DatabaseError(message: "Invalid negative value in function sqrt()")
        }
        return sqrt(double)
    }
    db.addFunction(fn)
    
    // fatal error: SQLite error 1 with statement `SELECT sqrt(-1)`:
    // Invalid negative value in function sqrt()
    Double.fetchOne(db, "SELECT sqrt(-1)")
}
```

See [Error Handling](#error-handling) for more information on database errors.


## Custom Collations

**When SQLite compares two strings, it uses a collating function** to determine which string is greater or if the two strings are equal.

SQLite lets you define your own collating functions. This is how you can bring support for unicode or localization when comparing strings:

```swift
dbQueue.inDatabase { db in
    // Define the localized_case_insensitive collation:
    let collation = DatabaseCollation("localized_case_insensitive") { (lhs, rhs) in
        return (lhs as NSString).localizedCaseInsensitiveCompare(rhs)
    }
    db.addCollation(collation)
    
    // Put it to some use:
    try db.execute("CREATE TABLE persons (lastName TEXT COLLATE LOCALIZED_CASE_INSENSITIVE)")
    
    // Persons are sorted as expected:
    Person.fetchAll(db, "SELECT * FROM persons ORDER BY lastName")
}
```

Check https://www.sqlite.org/datatype3.html#collation for more information.


## Raw SQLite Pointers

Not all SQLite APIs are exposed in GRDB.

The `Database.sqliteConnection` and `Statement.sqliteStatement` properties provide the raw pointers that are suitable for [SQLite C API](https://www.sqlite.org/c3ref/funclist.html):

```swift
dbQueue.inDatabase { db in
    let sqliteConnection = db.sqliteConnection
    sqlite3_db_config(sqliteConnection, ...)
    
    let statement = db.selectStatement("SELECT ...")
    let sqliteStatement = statement.sqliteStatement
    sqlite3_step(sqliteStatement)
}
```

> :point_up: **Notes**
>
> - Those pointers are owned by GRDB: don't close connections or finalize statements created by GRDB.
> - SQLite connections are opened in the [Multi-thread mode](https://www.sqlite.org/threadsafe.html), which means that **they are not thread-safe**. Make sure you touch raw databases and statements inside the database queues.

Before jumping in the low-level wagon, here is a reminder of SQLite APIs supported by GRDB:

- Connections & statements, obviously.
- Errors (pervasive)
    - [sqlite3_errmsg](https://www.sqlite.org/c3ref/errcode.html)
- Inserted Row IDs (as the result of Database.execute()).
    - [sqlite3_last_insert_rowid](https://www.sqlite.org/c3ref/last_insert_rowid.html)
- Changes count (as the result of Database.execute()).
    - [sqlite3_changes](https://www.sqlite.org/c3ref/changes.html)
- Custom SQL functions (see [Custom SQL Functions](#custom-sql-functions))
    - [sqlite3_create_function_v2](https://www.sqlite.org/c3ref/create_function.html)
- Custom collations (see [Custom Collations](#custom-collations))
    - [sqlite3_create_collation_v2](https://www.sqlite.org/c3ref/create_collation.html)
- Busy mode (see [Concurrency](#concurrency)).
    - [sqlite3_busy_handler](https://www.sqlite.org/c3ref/busy_handler.html)
    - [sqlite3_busy_timeout](https://www.sqlite.org/c3ref/busy_timeout.html)
- Update, commit and rollback hooks (see [Database Changes Observation](#database-changes-observation)):
    - [sqlite3_update_hook](https://www.sqlite.org/c3ref/update_hook.html)
    - [sqlite3_commit_hook](https://www.sqlite.org/c3ref/commit_hook.html)
    - [sqlite3_rollback_hook](https://www.sqlite.org/c3ref/commit_hook.html)


Application Tools
=================

On top of the SQLite API described above, GRDB provides a toolkit for applications. While none of those are mandatory, all of them help dealing with the database:

- **[Migrations](#migrations)**: Transform your database as your application evolves.
- **[Database Protocols, and Record](#database-protocols-and-record)**
    - [RowConvertible Protocol](#rowconvertible-protocol): Don't fetch rows, fetch your custom types instead.
    - [DatabasePersistable Protocol](#databasepersistable-protocol): Grant any type with persistence methods.
    - [Record](#record): The class that wraps a table row or the result of any query, provides persistence methods, and changes tracking.
- **[Database Changes Observation](#database-changes-observation)**: A robust way to perform post-commit and post-rollback actions.


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
migrator.registerMigration("AddAgeToPersons") { db in
    try db.execute(
        "ALTER TABLE persons ADD COLUMN age INT; " +
        "ALTER TABLE books ADD COLUMN year INT")
}

// (Insert migrations for future versions here)

try migrator.migrate(dbQueue)
```

**Each migration runs in a separate transaction.** Should one throw an error, its transaction is rollbacked, subsequent migrations do not run, and the error is eventually thrown by `migrator.migrate(dbQueue)`.

**The memory of applied migrations is stored in the database itself** (in a reserved table). When you are tuning your migrations, you may need to execute one several times. All you need then is to feed your application with a database file from a previous state.


### Advanced Database Schema Changes

SQLite does not support many schema changes, and won't let you drop a table column with "ALTER TABLE ... DROP COLUMN ...", for example.

Yet any kind of schema change is still possible. The SQLite documentation explains in detail how to do so: https://www.sqlite.org/lang_altertable.html#otheralter. This technique requires the temporary disabling of foreign key checks:

```swift
// Add a NOT NULL constraint on persons.name:
migrator.registerMigration("AddNotNullCheckOnName", withDisabledForeignKeyChecks: true) { db in
    try db.execute(
        "CREATE TABLE new_persons (id INTEGER PRIMARY KEY, name TEXT NOT NULL);" +
        "INSERT INTO new_persons SELECT * FROM persons;" +
        "DROP TABLE persons;" +
        "ALTER TABLE new_persons RENAME TO persons;")
}
```

While your migration code runs with disabled foreign key checks, those are re-enabled and checked at the end of the migration, regardless of eventual errors.


## Database Protocols, and Record

**GRDB provides protocols and a Record class** that help isolating database management code into database layer types, and avoid cluterring the rest of your application.

- The [RowConvertible protocol](#rowconvertible-protocol) grants adopting types with fetching methods:
    
    ```swift
    struct Person : RowConvertible { ... }
    let persons = Person.fetchAll(db, "SELECT * FROM persons")
    let person = let Person.fetchOne(db, key: 1)
    ```
    
- The [DatabasePersistable protocol](#databasepersistable-protocol) grants adopting types with persistence methods:
    
    ```swift
    struct Person : DatabasePersistable { ... }
    try Person(name: "Arthur").insert(db)
    ```
    
- The [Record class](#record) grants its subclasses with fetching methods, persistence methods, and changes tracking:
    
    ```swift
    class Person : Record { ... }
    let person = Person.fetchOne(db, key: 1)!
    person.name = "Barbara"
    if person.hasPersistentChangedValues {
        try person.update(db)
    }
    ```


### RowConvertible Protocol

**The `RowConvertible` protocol grants fetching methods to any type** that can be built from a database row:

```swift
public protocol RowConvertible {
    /// Returns a value initialized from `row`.
    static func fromRow(row: Row) -> Self
    
    /// Optional method which gives adopting types an opportunity to complete
    /// their initialization after being fetched. Do not call it directly.
    mutating func awakeFromFetch(row row: Row, database: Database)
}
```

Adopting types can be fetched just like rows:

```swift
struct PointOfInterest : RowConvertible {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    
    static func fromRow(row: Row) -> PointOfInterest {
        return PointOfInterest(
            coordinate: CLLocationCoordinate2DMake(
                row.value(named: "latitude"),
                row.value(named: "longitude")),
            title: row.value(named: "title"))
    }
}

PointOfInterest.fetch(db, "SELECT ...")    // DatabaseSequence<PointOfInterest>
PointOfInterest.fetchAll(db, "SELECT ...") // [PointOfInterest]
PointOfInterest.fetchOne(db, "SELECT ...") // PointOfInterest?
```

See [Column Values](#column-values) for more information about the `row.value()` method.

Both `fetch` and `fetchAll` let you iterate the full list of fetched objects. The differences are:

- `fetchAll` performs a single request, and returns an array that can be iterated on any thread. It can take a lot of memory.
- `fetch` returns a sequence that performs a new request each time it is iterated. It must be consumed in the database queue (you'll get a fatal error if you do otherwise).

> :point_up: **Note**: For performance reasons, the same row argument to `fromRow(:)` is reused during the iteration of a fetch query. If you want to keep the row for later use, make sure to store a copy: `result.row = row.copy()`.

See also the [Record](#record) class, which builds on top of RowConvertible and adds a few extra features like persistence methods, and changes tracking.


#### Fetching by Key

**Adopt the `DatabaseTableMapping` protocol** on top of `RowConvertible`:

```swift
public protocol DatabaseTableMapping {
    /// The name of the database table
    static func databaseTableName() -> String
}
```

For example:

```swift
// CREATE TABLE persons (
//   id INTEGER PRIMARY KEY,
//   name TEXT,
//   email TEXT UNIQUE COLLATE NOCASE
// )
struct Person : RowConvertible, DatabaseTableMapping {
    var id: Int64?
    var name: String?
    var email: String?
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    static func fromRow(row: Row) -> Person {
        return Person(
            id: row.value(named: "id"),
            name: row.value(named: "name"),
            email: row.value(named: "email"))
    }
}
```

You are then granted with fetching methods based on database keys:

```swift
Person.fetch(db, keys: ...)     // DatabaseSequence<Person>
Person.fetchAll(db, keys: ...)  // [Person]
Person.fetchOne(db, key: ...)   // Person?
```

Both `fetch` and `fetchAll` let you iterate the full list of fetched objects. The differences are:

- `fetchAll` performs a single request, and returns an array that can be iterated on any thread. It can take a lot of memory.
- `fetch` returns a sequence that performs a new request each time it is iterated. It must be consumed in the database queue (you'll get a fatal error if you do otherwise).

The order of sequences and arrays returned by the key-based methods is undefined. To specify the order of returned elements, use a raw SQL query.


**When the database table has a single column primary key**, you can fetch given key values:

```swift
// SELECT * FROM persons WHERE id = 1
Person.fetchOne(db, key: 1)

// SELECT * FROM persons WHERE id IN (1,2,3)
Person.fetch(db, keys: [1,2,3])

// SELECT * FROM countries WHERE isoCode = 'FR'
Country.fetchOne(db, key: "FR")

// SELECT * FROM countries WHERE isoCode IN ('FR', 'ES', 'US')
Country.fetchAll(db, keys: ["FR", "ES", "US"])
```

**For multi-column primary keys and secondary keys**, use a key dictionary:

```swift
// SELECT * FROM persons WHERE email = 'me@example.com'
Person.fetchOne(db, key: ["email": "me@example.com"])

// SELECT * FROM citizenships WHERE personId = 1 AND countryIsoCode = 'FR'
Citizenship.fetchOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
```


#### Optional Columns

**Your RowConvertible type can accept rows that do not always contain the same columns.**

This allows you to load only a subset of a table columns, or to load extra columns joined from other tables. For example:

```swift
struct Person : RowConvertible {
    let id: Int64?
    let name: String
    let bookCount: Int? // Only set when person is fetched from fetchAllWithBookCount()
    
    static func fromRow(row: Row) -> Person {
        return Person(
            id: row.value(named: "id"),
            name: row.value(named: "name"),
            bookCount: row.value(named: "bookCount")) // nil if column is missing
    }
    
    // The returned persons have a value in their bookCount property:
    static func fetchAllWithBookCount(db: Database) -> [Person] {
        return fetchAll(db,
            "SELECT persons.*, COUNT(books.id) AS bookCount " +
            "FROM persons " +
            "LEFT JOIN books ON books.ownerId = persons.id " +
            "GROUP BY persons.id")
    }
}
```

See [Column Values](#column-values) for more information about the `row.value()` method.


### DatabasePersistable Protocol

**GRDB provides two protocols that let adopting types store themselves in the database:**

```swift
public protocol MutableDatabasePersistable : DatabaseTableMapping {
    /// The name of the database table (from DatabaseTableMapping)
    static func databaseTableName() -> String
    
    /// Returns the values that should be persisted in the database.
    var persistentDictionary: [String: DatabaseValueConvertible?] { get }
    
    /// Optional method that lets your adopting type store its rowID upon
    /// successful insertion. Don't call it directly: it is called for you.
    mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?)
}

public protocol DatabasePersistable : MutableDatabasePersistable {
    /// Non-mutating version of the optional didInsertWithRowID(:forColumn:)
    func didInsertWithRowID(rowID: Int64, forColumn column: String?)
}
```

That's one more protocol that one could expect, and `MutableDatabasePersistable` may sound intimidating.

Yet, here is the rule:

- If your type is a struct that mutates on insertion, choose `MutableDatabasePersistable`. For example, if your table has an INTEGER PRIMARY KEY, you want to store the inserted id on successful insertion.
- Otherwise, stick with `DatabasePersistable`.

For example, the Country struct below has no INTEGER PRIMARY KEY, and is not mutated on insertion. On the other side, the Person struct is interested in its rowID, and mutates itself on insertion:

```swift
// CREATE TABLE countries (
//   isoCode TEXT NOT NULL PRIMARY KEY,
//   name TEXT NOT NULL
// )
struct Country : DatabasePersistable {
    let isoCode: String
    let name: String
    
    static func databaseTableName() -> String {
        return "countries"
    }

    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["isoCode": isoCode, "name": name]
    }
}

// Declare the country as `let`, since its insertion does not mutate it:
let country = Country(isoCode: "FR", name: "France")
try country.insert(db)

// CREATE TABLE persons (
//     id INTEGER PRIMARY KEY,
//     name TEXT
// )
struct Person : MutableDatabasePersistable {
    let id: Int64?
    let name: String?
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
    
    // Update person ID upon successful insertion:
    mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
    }
}

// Declare the person as `var`, since its insertion mutates it:
var person = Person(id: nil, name: "Arthur")
person.id   // nil
try person.insert(db)
person.id   // some value
```

The `persistentDictionary` property returns a dictionary whose keys are column names, and values any DatabaseValueConvertible value (Bool, Int, String, NSDate, Swift enums, etc.) See [Values](#values) for more information.

> :point_up: **Note**: Classes should always prefer adopting `DatabasePersistable` over `MutableDatabasePersistable`, even if they mutate on insertion. This will prevent strange compiler errors when they insert an instance stored in a `let` variable (see [SR-142](https://bugs.swift.org/browse/SR-142)).


#### Persistence Methods

Types that adopt DatabasePersistable or MutableDatabasePersistable are given default implementations for methods that insert, update, and delete:

```swift
try object.insert(db)  // INSERT
try object.update(db)  // UPDATE
try object.save(db)    // Inserts or updates
try object.delete(db)  // DELETE
object.exists(db)      // Bool
```

- `insert`, `update`, `save` and `delete` can throw a [DatabaseError](#error-handling) whenever an SQLite integrity check fails.

- `update` can also throw a PersistenceError of type NotFound, should the update fail because there is no matching row in the database.
    
    When saving an object that may or may not already exist in the database, prefer the `save` method: it performs the UPDATE or INSERT statement that makes sure your values are saved in the database.

- `delete` returns whether a database row was deleted or not.

The differences between `DatabasePersistable` and `MutableDatabasePersistable` only lie in insertion-related methods:

```swift
protocol MutableDatabasePersistable {
    // Insertion can mutate:
    mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    mutating func insert(db: Database) throws
    mutating func save(db: Database) throws
}

protocol DatabasePersistable : MutableDatabasePersistable {
    // Insertion can not mutate:
    func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    func insert(db: Database) throws
    func save(db: Database) throws
}
```


#### Customizing the Persistence Methods

Your custom type may want to perform extra work when the persistence methods are invoked.

For example, it may want to have its UUID automatically set before inserting. Or it may want to validate its values before saving.

The protocol exposes *special methods* for this exact purpose: `performInsert`, `performUpdate`, `performSave`, `performDelete`, and `performExists`.

```swift
struct Person : MutableDatabasePersistable {
    var uuid: String?
    
    mutating func insert(db: Database) throws {
        if uuid == nil {
            uuid = NSUUID().UUIDString
        }
        try performInsert(db)
    }
}

struct Link : DatabasePersistable {
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

> :point_up: **Note**: The special methods `performInsert`, `performUpdate`, etc. are reserved for your custom implementations. Do not use them elsewhere. Do not provide another implementation for those methods.
>
> :point_up: **Note**: It is recommended that you do not implement your own version of the `save` method. Its default implementation forwards the job to `update` or `insert`: these are the methods that may need customization, not `save`.


### Record

- [Overview](#record-overview)
- [Subclassing Record](#subclassing-record)
- [Fetching Records](#fetching-records)
- [Record Persistence Methods](#record-persistence-methods)
- [Changes Tracking](#changes-tracking)
- [Advice](#advice)


#### Record Overview

**Record** is a class that wraps a table row or the result of any query, provides persistence methods, and changes tracking. It is designed to be subclassed.

```swift
// Define Record subclass
class Person : Record { ... }

try dbQueue.inDatabase { db in
    // Store
    let person = Person(name: "Arthur")
    try person.save(db)
    
    // Fetch
    for person in Person.fetch(db, "SELECT * FROM persons") {
        print(person.name)
    }
}
```

It builds on top of the [RowConvertible](#rowconvertible-protocol) and [DatabasePersistable](#databasepersistable-protocol) protocols.

**Record is not a smart class.** It is no replacement for Core Data’s NSManagedObject, [Realm](https://realm.io)’s Object, or for an Active Record pattern. It does not provide any uniquing, automatic refresh, or synthesized properties. It has no knowledge of external references and table relationships, and will not generate JOIN queries for you.

Yet, it does a few things well:

- **Records can be used from any thread**. Not being a replacement for NSManagedObject comes with advantages.

- **It eats any SQL query.** A Record subclass is often tied to a database table, but this is not a requirement at all.

    ```swift
    let persons = Person.fetchAll(db,
        "SELECT persons.*, COUNT(citizenships.isoCode) AS citizenshipsCount " +
        "FROM persons " +
        "LEFT JOIN citizenships ON citizenships.personId = persons.id " +
        "GROUP BY persons.id")
    let person = persons.first!
    (person.name, person.citizenshipsCount)
    ```

- **It provides the classic CRUD persistence methods.** All primary keys are supported (auto-incremented INTEGER PRIMARY KEY, single column, multiple columns).
    
    ```swift
    let person = Person(...)
    try person.insert(db)   // INSERT
    try person.update(db)   // UPDATE
    try person.save(db)     // Inserts or updates
    try person.delete(db)   // DELETE
    ```
    
- **It tracks changes. Real changes**: setting a column to the same value does not constitute a change.
    
    ```swift
    person = Person.fetch...
    person.name = "Barbara"
    person.age = 41
    person.persistentChangedValues.keys // ["age"]
    if person.hasPersistentChangedValues {
        try person.save(db)
    }
    ```


#### Subclassing Record

**Record subclasses override the four core methods that define their relationship with the database:**

```swift
class Record {
    /// The table name
    class func databaseTableName() -> String
    
    /// Initialize a record from a database row
    required init(_ row: Row)
    
    /// The values persisted in the database
    var persistentDictionary: [String: DatabaseValueConvertible?]
    
    /// Optionally update record ID after a successful insertion
    func didInsertWithRowID(rowID: Int64, forColumn column: String?)
}
```

**Given an implementation of those core methods, you are granted with the full Record toolkit:**

```swift
class Person {
    // Copy
    func copy() -> Self
    
    // Change Tracking
    var hasPersistentChangedValues: Bool
    var persistentChangedValues: [String: DatabaseValue?]
    
    // Persistence
    func insert(db: Database) throws
    func update(db: Database) throws
    func save(db: Database) throws           // inserts or updates
    func delete(db: Database) throws -> Bool
    func exists(db: Database) -> Bool
    
    // Fetching
    static func fetch(...) -> DatabaseSequence<Self>
    static func fetchAll(...) -> [Self]
    static func fetchOne(...) -> Self?
    
    // Events
    func awakeFromFetch(row row: Row, database: Database)
    func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    
    // Description (from the CustomStringConvertible protocol)
    var description: String
}
```

For example, given the following table:

```sql
CREATE TABLE countries (
  isoCode TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL
)
```

The Country class freely defines its properties and initializers. Here we have chosen non optional properties that directly map database columns:

```swift
struct Country : Record {
    let isoCode: String
    let name: String
    
    init(isoCode: String, name: String) {
        self.isoCode = isoCode
        self.name = name
        super.init()
    }
```

Country overrides `databaseTableName()` to return the name of the table that should be used when fetching countries:

```swift
    /// The table name
    override class func databaseTableName() -> String {
        return "countries"
    }
```

Country overrides `persistentDictionary` and returns a dictionary whose keys are column names, and values any `DatabaseValueConvertible` value (Bool, Int, String, NSDate, Swift enums, etc.) See [Values](#values) for more information:

```swift
    /// The values persisted in the database
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["isoCode": isoCode, "name": name]
    }
```

Country overrides `init(row:)` so that it can be fetched:

```swift
    /// Initialize a Country from a row
    required init(_ row: Row) {
        isoCode = row.value(named: "isoCode")
        name = row.value(named: "name")
        super.init(row)
    }
}
```

See [Column Values](#column-values) for more information about the `row.value()` method.

> :point_up: **Note**: For performance reasons, the same row argument to `init(row:)` is reused for all records during the iteration of a fetch query. If you want to keep the row for later use, make sure to store a copy: `self.row = row.copy()`.

The Country class is now ready:

```swift
dbQueue.inDatabase { db in
    let unitedStates = Country.fetchOne(db, key: "US")!
    let country = Country(isoCode: "FR", name: "France")
    country.insert(db)
}
```

When the database table has an INTEGER PRIMARY KEY, make sure to override the `didInsertWithRowID` method so that your record stores its id upon successful insertion:

```swift
// CREATE TABLE persons (
//     id INTEGER PRIMARY KEY,
//     name TEXT
// )
class Person : Record {
    let id: Int64?
    let name: String?
    
    init(name: String) {
        self.id = nil
        self.name = name
        super.init()
    }
    
    // Record overrides
    
    /// The table name
    override class func databaseTableName() -> String {
        return "persons"
    }
    
    /// The values persisted in the database
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
    
    /// Initialize a Person from a row
    required init(_ row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        super.init(row)
    }
    
    /// Update person ID after a successful insertion
    func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
    }
}

let person = Person(...)
person.id   // nil
try person.insert(db)
person.id   // some value
```


#### Fetching Records

You can fetch **sequences**, **arrays**, or **single** records with raw SQL queries, or by key:

```swift
dbQueue.inDatabase { db in
    // SQL
    Person.fetch(db, "SELECT ...", arguments:...)     // DatabaseSequence<Person>
    Person.fetchAll(db, "SELECT ...", arguments:...)  // [Person]
    Person.fetchOne(db, "SELECT ...", arguments:...)  // Person?
    
    // When database table has a single column primary key
    Person.fetch(db, keys: [1,2,3])                   // DatabaseSequence<Person>
    Person.fetchAll(db, keys: [1,2,3])                // [Person]
    Person.fetchOne(db, key: 1)                       // Person?
    
    // For multi-column primary keys and secondary keys
    Person.fetch(db, keys: [["name": "Joe"], ...])    // DatabaseSequence<Person>
    Person.fetchAll(db, keys: [["name": "Joe"], ...]) // [Person]
    Person.fetchOne(db, key: ["name": "Joe"])         // Person?
}
```

Both `fetch` and `fetchAll` let you iterate the full list of fetched records. The differences are:

- `fetchAll` performs a single request, and returns an array that can be iterated on any thread. It can take a lot of memory.
- `fetch` returns a sequence that performs a new request each time it is iterated. It must be consumed in the database queue (you'll get a fatal error if you do otherwise).

For example:

```swift
dbQueue.inDatabase { db in
    // All persons with an email ending in @example.com:
    Person.fetchAll(db,
        "SELECT * FROM persons WHERE email LIKE ?",
        arguments: ["%@example.com"])
    
    // All persons who have a single citizenship:
    Person.fetch(db,
        "SELECT persons.* " +
        "FROM persons " +
        "JOIN citizenships ON citizenships.personId = persons.id " +
        "GROUP BY persons.id " +
        "HAVING COUNT(citizenships.id) = 1")
    
    // SELECT * FROM persons WHERE id = 1
    Person.fetchOne(db, key: 1)
    
    // SELECT * FROM persons WHERE id IN (1,2,3)
    Person.fetch(db, keys: [1,2,3])
    
    // SELECT * FROM countries WHERE isoCode = 'FR'
    Country.fetchOne(db, key: "FR")
    
    // SELECT * FROM countries WHERE isoCode IN ('FR', 'ES', 'US')
    Country.fetchAll(db, keys: ["FR", "ES", "US"])
    
    // SELECT * FROM persons WHERE email = 'me@example.com'
    Person.fetchOne(db, key: ["email": "me@example.com"])
    
    // SELECT * FROM citizenships WHERE personId = 1 AND countryIsoCode = 'FR'
    Citizenship.fetchOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
}
```

The order of sequences and arrays returned by the key-based methods is undefined. To specify the order of returned elements, use a raw SQL query.


#### Record Persistence Methods

Records can store themselves in the database through the `persistentDictionary` core property:

```swift
class Person : Record {
    /// The values stored in the database
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "url": url, "name": name, "email": email]
    }
}

try dbQueue.inDatabase { db in
    let person = Person(...)
    try person.insert(db)   // INSERT
    try person.update(db)   // UPDATE
    try person.save(db)     // Inserts or updates
    try person.delete(db)   // DELETE
    person.exists(db)       // Bool
}
```

- `insert` automatically sets the primary key of record whose primary key is declared as "INTEGER PRIMARY KEY", if you override the `didInsertWithRowID` method:
    
    ```swift
    let person = Person()
    person.id   // nil
    try person.insert(db)
    person.id   // some value
    ```
    
    Other primary keys (single or multiple columns) are not managed by GRDB: you have to manage them yourself. For example, you can override the `insert` primitive method, and generate an UUID before calling `super.insert`.

- `insert`, `update`, `save` and `delete` can throw a [DatabaseError](#error-handling) whenever an SQLite integrity check fails.

- `update` can also throw a PersistenceError of type NotFound, should the update fail because the record does not exist in the database.
    
    When saving a record that may or may not already exist in the database, prefer the `save` method: it performs the UPDATE or INSERT statement that makes sure your values are saved in the database.

- `delete` returns whether a database row was deleted or not.


#### Changes Tracking

The `update()` method always executes an UPDATE statement. When the record has not been edited, this database access is generally useless.

Avoid it with the `hasPersistentChangedValues` property, which returns whether the record has changes that have not been saved:

```swift
// Saves the person if it has changes that have not been saved:
if person.hasPersistentChangedValues {
    try person.save(db)
}
```

Note that `hasPersistentChangedValues` is based on value comparison: **setting a property to the same value does not set the edited flag**.

For an efficient algorithm which synchronizes the content of a database table with a JSON payload, check this [sample code](https://gist.github.com/groue/dcdd3784461747874f41).


#### Advice

- [Ad Hoc Subclasses](#ad-hoc-subclasses)
- [Validation](#validation)
- [Default Values](#default-values)
- [INSERT OR REPLACE](#insert-or-replace)


##### Ad Hoc Subclasses

Don't hesitate deriving subclasses from your base records when you have a need for a specific query.

For example, if a view controller needs to display a list of persons along with the number of books they own, it would be unreasonable to fetch the list of persons, and then, for each of them, fetch the number of books they own. That would perform N+1 requests, and [this is a well known issue](http://stackoverflow.com/questions/97197/what-is-the-n1-selects-issue).

Instead, subclass Person:

```swift
class PersonsViewController: UITableViewController {
    
    // An ad-hoc Person subclass that fits the need of this view controller:
    private class PersonWithBookCount : Person {
        var bookCount: Int?
    
        required init(_ row: Row) {
            bookCount = row.value(named: "bookCount")
            super.init(row)
        }
    }
```

Perform a single request:

```swift
    var persons: [PersonWithBookCount]!
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        persons = dbQueue.inDatabase { db in
            PersonWithBookCount.fetchAll(db,
                "SELECT persons.*, COUNT(books.id) AS bookCount " +
                "FROM persons " +
                "LEFT JOIN books ON books.ownerId = persons.id " +
                "GROUP BY persons.id")
        }
        
        tableView.reloadData()
    }
```

Other application objects that expect a Person will gently accept the private subclass:

```swift
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showPerson" {
            let personVC: PersonViewController = segue...
            personVC.person = persons[tableView.indexPathForSelectedRow!.row]
        }
    }
}
```


##### Validation

Record does not provide any built-in validation.

You can use some external library such as [GRValidation](https://github.com/groue/GRValidation) in the update() and insert() methods:

```swift
class Person : Record, Validable {
    var name: String?
    
    override func update(db: Database) throws {
        // Validate before update
        try validate()
        try super.update(db)
    }
    
    override func insert(db: Database) throws {
        // Validate before insert
        try validate()
        try super.insert(db)
    }
    
    func validate() throws {
        // Name should not be nil
        try validate(property: "name", with: name >>> ValidationNotNil())
    }
}

// fatal error: 'try!' expression unexpectedly raised an error:
// Invalid <Person name:nil>: name should not be nil.
try! Person(name: nil).save(db)
```


##### Default Values

**Avoid default values in table declarations.** Record doesn't know about them, and those default values won't be present in a record after it has been inserted.
    
For example, avoid the table below:

```sql
CREATE TABLE persons (
    id INTEGER PRIMARY KEY,
    creationDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,   -- Avoid
    ...
)
```

Instead, override `insert()` and provide the default value there:

```sql
CREATE TABLE persons (
    id INTEGER PRIMARY KEY,
    creationDate DATETIME NOT NULL,   -- OK
    ...
)
```

```swift
class Person : Record {
    var creationDate: NSDate?
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["creationDate": creationDate, ...]
    }
    
    override func insert(db: Database) throws {
        if creationDate == nil {
            creationDate = NSDate()
        }
        try super.insert(db)
    }
}
```


##### INSERT OR REPLACE

**Record does not provide any API which executes a INSERT OR REPLACE query.** Instead, consider adding an ON CONFLICT clause to your table definition, and let the simple insert() method perform the eventual replacement:

```sql
CREATE TABLE persons (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE ON CONFLICT REPLACE,
    ...
)
```

```swift
let person = Person(name: "Arthur")
person.insert(db)   // Replace any existing person named "Arthur"
```


## Database Changes Observation

The `TransactionObserverType` protocol lets you **observe database changes**:

```swift
public protocol TransactionObserverType : class {
    // Notifies a database change:
    // - event.kind (insert, update, or delete)
    // - event.tableName
    // - event.rowID
    func databaseDidChangeWithEvent(event: DatabaseEvent)
    
    // An opportunity to rollback pending changes by throwing an error.
    func databaseWillCommit() throws
    
    // Database changes have been committed.
    func databaseDidCommit(db: Database)
    
    // Database changes have been rollbacked.
    func databaseDidRollback(db: Database)
}
```

**There is one transaction observer per database:**

```swift
var config = Configuration()
config.transactionObserver = MyObserver()
let dbQueue = try DatabaseQueue(path: databasePath, configuration: config)
```

Protocol callbacks are all invoked on the database queue.

**All database changes are notified** to databaseDidChangeWithEvent, inserts, updates and deletes, including indirect ones triggered by ON DELETE and ON UPDATE actions associated to [foreign keys](https://www.sqlite.org/foreignkeys.html#fk_actions).

Those changes are not actually applied until databaseDidCommit is called. On the other side, databaseDidRollback confirms their invalidation:

```swift
try dbQueue.inTransaction { db in
    try db.execute("INSERT ...") // didChange
    return .Commit               // willCommit, didCommit
}

try dbQueue.inTransaction { db in
    try db.execute("INSERT ...") // didChange
    return .Rollback             // didRollback
}
```

Database statements that are executed outside of an explicit transaction do not drop off the radar:

```swift
try dbQueue.inDatabase { db in
    try db.execute("INSERT ...") // didChange, willCommit, didCommit
    try db.execute("UPDATE ...") // didChange, willCommit, didCommit
}
```

**Eventual errors** thrown from databaseWillCommit are exposed to the application code:

```swift
do {
    try dbQueue.inTransaction { db in
        ...
        return .Commit           // willCommit (throws), didRollback
    }
} catch {
    // The error thrown by the transaction observer.
}
```

> :point_up: **Note**: The databaseDidChangeWithEvent and databaseWillCommit callbacks must not touch the SQLite database. This limitation does not apply to databaseDidCommit and databaseDidRollback which can use their database argument.


### Sample Transaction Observer: TableChangeObserver

Let's write an object that notifies, on the main thread, of modified database tables. Your view controllers can listen to those notifications and update their views accordingly.

```swift
/// The notification posted when database tables have changed:
let DatabaseTablesDidChangeNotification = "DatabaseTablesDidChangeNotification"
let ChangedTableNamesKey = "ChangedTableNames"

/// TableChangeObserver posts a DatabaseTablesDidChangeNotification on the main
/// thread after database tables have changed.
class TableChangeObserver : NSObject, TransactionObserverType {
    private var changedTableNames: Set<String> = []
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        // Remember the name of the changed table:
        changedTableNames.insert(event.tableName)
    }
    
    func databaseWillCommit() throws {
        // Let go
    }
    
    func databaseDidCommit(db: Database) {
        // Extract the names of changed tables, and reset until next
        // database event:
        let changedTableNames = self.changedTableNames
        self.changedTableNames = []
        
        // Notify
        dispatch_async(dispatch_get_main_queue()) {
            NSNotificationCenter.defaultCenter().postNotificationName(
                DatabaseTablesDidChangeNotification,
                object: self,
                userInfo: [ChangedTableNamesKey: changedTableNames])
        }
    }
    
    func databaseDidRollback(db: Database) {
        // Reset until next database event:
        changedTableNames = []
    }
}
```


Sample Code
===========

- The [Documentation](#documentation) is full of GRDB snippets.
- [GRDBDemoiOS](DemoApps/GRDBDemoiOS): A sample iOS application.
- [GRDBDemoiOS7](DemoApps/GRDBDemoiOS7): A sample iOS7 application.
- Check `GRDB.xcworkspace`: it contains GRDB-enabled playgrounds to play with.
- How to synchronize a database table with a JSON payload: https://gist.github.com/groue/dcdd3784461747874f41


---

**Thanks**

- [Pierlis](http://pierlis.com), where we write great software.
- [@Chiliec](https://github.com/Chiliec), [@pakko972](https://github.com/pakko972), [@peter-ss](https://github.com/peter-ss) and [@pierlo](https://github.com/pierlo) for their feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [@kali](https://github.com/kali) because SQL.
- [ccgus/fmdb](https://github.com/ccgus/fmdb) for its excellency.
