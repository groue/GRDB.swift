GRDB.swift
==========

GRDB.swift is an [SQLite](https://www.sqlite.org) toolkit for Swift 2, from the author of [GRMustache](https://github.com/groue/GRMustache).

It ships with a low-level database API, plus application-level tools.

**October 14, 2015: GRDB.swift 0.24.0 is out** - [Release notes](CHANGELOG.md). Follow [@groue](http://twitter.com/groue) on Twitter for release announcements and usage tips.

Jump to:

- [Features](#features)
- [Requirements](#requirements)
- [Usage](#usage)
- [Benchmarks](#benchmarks)
- [Installation](#installation)
- [Documentation](#documentation)


Features
--------

- **A low-level SQLite API** that leverages the Swift 2 standard library.
- **No smart query builder**. Your SQL skills are welcome here.
- **A Record class** that wraps result sets, eats your custom SQL queries for breakfast, and provides basic CRUD operations.
- **Swift type freedom**: pick the right Swift type that fits your data. Use Int64 when needed, or stick with the convenient Int. Store and read NSDate or NSDateComponents. Declare Swift enums for discrete data types. Define your own database-convertible types.
- **Database migrations**
- **Database changes observation hooks**


Requirements
------------

- iOS 7.0+ / OSX 10.9+
- Xcode 7


Usage
-----

**SQLite API**

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
    
    // Fetch values
    let redWineCount = Int.fetchOne(db,
        "SELECT COUNT(*) FROM wines WHERE color = ?",
        arguments: [Color.Red])!
    
    // Fetch rows
    for row in Row.fetch(db, "SELECT * FROM wines") {
        let name: String = row.value(named: "name")
        let color: Color = row.value(named: "color")
        print(name, color)
    }
}
```

**Using Records**

```swift
// Define Record subclass
class Wine : Record { ... }

try dbQueue.inDatabase { db in
    // Store
    let wine = Wine(color: .Red, name: "Pomerol")
    try wine.insert(db)
    print("Inserted wine id: \(wine.id)")
    
    // Track changes
    wine.name = "Pomerol"
    if wine.databaseEdited {    // false since name has not changed.
        try wine.save(db)
    }
    
    // Fetch
    for wine in Wine.fetch(db, "SELECT * FROM wines") {
        print(wine.name, wine.color)
    }
}
```

**Users of [ccgus/fmdb](https://github.com/ccgus/fmdb)** will feel at ease with GRDB.swift. They may find GRDB to be easier when [fetching](#fetch-queries) data from the database. And they'll definitely be happy that [database errors](#error-handling) are handled in the Swift way.

**Users of [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift)** may eventually find that a straightforward API around SQL is not a bad alternative.


Benchmarks
----------

GRDB.swift runs as fast as ccgus/fmdb, or faster.

For precise benchmarks, select the GRDBOSX scheme, run the tests in Release configuration, and check the results under the "Performance" tab in the Xcode Report Navigator.


Installation
------------

### iOS7

You can use GRDB.swift in a project targetting iOS7. See [GRDBDemoiOS7](DemoApps/GRDBDemoiOS7) for more information.


### CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Xcode projects.

To use GRDB.swift with Cocoapods, specify in your Podfile:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

pod 'GRDB.swift', '0.24.0'
```


### Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency manager for Xcode projects.

To use GRDB.swift with Carthage, specify in your Cartfile:

```
github "groue/GRDB.swift" == 0.24.0
```


### Manually

Download a copy of GRDB.swift, embed the `GRDB.xcodeproj` project in your own project, and add the `GRDBOSX` or `GRDBiOS` target as a dependency of your own target. See [GRDBDemoiOS](DemoApps/GRDBDemoiOS) for an example of such integration.


Documentation
=============

To fiddle with the library, open the `GRDB.xcworkspace` workspace: it contains a GRDB-enabled Playground at the top of the files list.

**Reference**

- [GRDB Reference](http://cocoadocs.org/docsets/GRDB.swift/0.24.0/index.html) on cocoadocs.org. Beware that it is incomplete: you may prefer reading the inline documentation right into the [source](https://github.com/groue/GRDB.swift/tree/master/GRDB).

**[SQLite API](#sqlite-api)**

- [SQLite Database](#sqlite-database)
- [Fetch Queries](#fetch-queries)
    - [Row Queries](#row-queries)
    - [Value Queries](#value-queries)
- [Values](#values)
    - [NSData](#nsdata-and-memory-savings)
    - [NSDate and NSDateComponents](#nsdate-and-nsdatecomponents)
    - [Swift enums](#swift-enums)
    - [Custom Value Types](#custom-value-types)
- [Prepared Statements](#prepared-statements)
- [Error Handling](#error-handling)
- [Transactions](#transactions)
- [Concurrency](#concurrency)
- [Raw SQLite Pointers](#raw-sqlite-pointers)

**[Application Tools](#application-tools)**

- [Migrations](#migrations): Transform your database as your application evolves.
- [Database Changes Observation](#database-changes-observation): A robust way to perform post-commit and post-rollback actions.
- [RowConvertible Protocol](#rowconvertible-protocol): Turn database rows into handy types, without sacrificing performance.
- [Records](#records): CRUD operations and changes tracking.

**Sample Code**

- [GRDBDemoiOS](DemoApps/GRDBDemoiOS): A sample iOS application.
- [GRDBDemoiOS7](DemoApps/GRDBDemoiOS7): A sample iOS7 application.


SQLite API
==========

## SQLite Database

You access SQLite databases through thread-safe **database queues** (inspired by [ccgus/fmdb](https://github.com/ccgus/fmdb)):

```swift
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let inMemoryDBQueue = DatabaseQueue()
```

The database connection is closed when the database queue gets deallocated.

**Configure** databases:

```swift
var config = Configuration()
config.foreignKeysEnabled = true // Default true
config.readonly = false          // Default false
config.trace = LogSQL            // The built-in LogSQL function logs all SQL statements with NSLog.

let dbQueue = try DatabaseQueue(
    path: "/path/to/database.sqlite",
    configuration: config)
```

See [Concurrency](#concurrency) for more details on database configuration.

The `inDatabase` and `inTransaction` methods perform your **database statements** in a dedicated, serial, queue:

```swift
// Extract values from the database:
let rows = dbQueue.inDatabase { db in
    Row.fetchAll(db, "SELECT ...")
}

// Execute database statements:
dbQueue.inDatabase { db in
    for person in Person.fetch(db, "SELECT...") {
        ...
    }
    ...
}

// Wrap database statements in a transaction:
try dbQueue.inTransaction { db in
    let insertedRowID = try db.execute(
        "INSERT INTO persons (name, age) VALUES (?, ?)",
        arguments: ["Arthur", 36]).insertedRowID
    
    try db.execute(
        "DELETE FROM persons WHERE name = :name",
        arguments: ["name": "Barbara"])
    
    return .Commit
}
```

See [Transactions](#transactions) for more information about GRDB transaction handling.

To create tables, we recommend using [migrations](#migrations).


## Fetch Queries

You can fetch **Rows**, **Values**, and **Records**:

```swift
dbQueue.inDatabase { db in
    Row.fetch(db, "SELECT ...", ...)             // DatabaseSequence<Row>
    Row.fetchAll(db, "SELECT ...", ...)          // [Row]
    Row.fetchOne(db, "SELECT ...", ...)          // Row?
    
    String.fetch(db, "SELECT ...", ...)          // DatabaseSequence<String>
    String.fetchAll(db, "SELECT ...", ...)       // [String]
    String.fetchOne(db, "SELECT ...", ...)       // String?
    
    Person.fetch(db, "SELECT ...", ...)          // DatabaseSequence<Person>
    Person.fetchAll(db, "SELECT ...", ...)       // [Person]
    Person.fetchOne(db, "SELECT ...", ...)       // Person?
    Person.fetchOne(db, primaryKey: 12)          // Person?
    Person.fetchOne(db, key: ["name": "Arthur"]) // Person?
}
```

The last two methods are the only ones that don't take a custom SQL query as an argument. If SQL is not your cup of tea, then maybe you are looking for a query builder. [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md#selecting-rows) is a pretty popular one.

- [Row Queries](#row-queries)
- [Value Queries](#value-queries)
- [RowConvertible Protocol](#rowconvertible-protocol) and [Records](#records)


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
}
```

Arguments are optional arrays or dictionaries that fill the positional `?` and colon-prefixed keys like `:name` in the query:

```swift
Row.fetch(db, "SELECT * FROM persons WHERE name = ?", arguments: ["Arthur"])
Row.fetch(db, "SELECT * FROM persons WHERE name = :name", arguments: ["name": "Arthur"])
```

Do use those arguments: they prevent nasty users from injecting [nasty SQL snippets](https://en.wikipedia.org/wiki/SQL_injection) into your SQL queries.


**Row sequences grant the fastest and the most memory-efficient access to SQLite**, much more than row arrays that hold copies of the database rows:

```swift
for row in Row.fetch(db, "SELECT ...") {
    // Can't be closer to SQLite
}
```

> :point_up: **Note**: this performance advantage comes with extra precautions when using row sequences:
> 
> - **Don't consume a row sequence outside of the database queue.** Extract a row array with `Row.fetchAll(...)` instead:
> 
>     ```swift
>     let rows = dbQueue.inDatabase { db in
>         Row.fetchAll(db, "SELECT ...")  // [Row]
>     }
>     for row in rows { ... } // OK
>     ```
> 
> - **Don't wrap a row sequence in an array** with `Array(rows)` or `rows.filter { ... }`: you would not get the distinct rows you expect. To get an array, use `Row.fetchAll(...)`.
> 
> - **Make sure you copy a row** whenever you extract it from the sequence for later use: `row.copy()`.


#### Column Values

**Read column values** by index or column name:

```swift
let name: String = row.value(atIndex: 0)    // 0 is the leftmost column
let name: String = row.value(named: "name")
```

Ask for an optional when the value may be NULL:

```swift
let name: String? = row.value(named: "name")
```

The `value` function generally returns the type you ask for:

```swift
let bookCount: Int     = row.value(named: "bookCount")
let bookCount64: Int64 = row.value(named: "bookCount")
let hasBooks: Bool     = row.value(named: "bookCount")  // false when 0

let dateString: String = row.value(named: "date") // "2015-09-11 18:14:15.123"
let date: NSDate       = row.value(named: "date") // NSDate
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

See [Values](#values) for more information on supported types. Don't miss [NSData](#nsdata-and-memory-savings) if you target memory efficiency.


#### Rows as Dictionaries

You may prefer thinking of rows as dictionaries of `DatabaseValue`, an intermediate type between SQLite and your values:

```swift
// Test if the column `date` is present:
if let databaseValue = row["date"] {
    // Pick the type you need:
    let dateString: String = databaseValue.value() // "2015-09-11 18:14:15.123"
    let date: NSDate = databaseValue.value()       // NSDate
    self.date = databaseValue.value() // Depends on the type of the property.
}
```

Iterate all the tuples (columnName, databaseValue) in a row:

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


Still, as a convenience, row can be converted to and from **NSDictionary** (in case of duplicate colum names, the leftmost value is returned):

```swift
row.toDictionary()  // NSDictionary
```


#### Convenience Rows

Rows is a fundamental type in GRDB, used by many other APIs.

From time to time, you'll want to build a custom one from scratch. Use the dictionary initializer:

```swift
Row(dictionary: ["name": "foo", "date": nil])
```

See [Values](#values) for more information on supported types.


### Value Queries

Instead of rows, you can directly fetch **values**. Like rows, fetch them as **sequences**, **arrays**, or **single** values. Values are extracted from the leftmost column of the SQL queries:

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

The `fetchOne(_:sql:arguments:)` method returns an optional value which is nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value.

> :point_up: **Note**: Sequences can not be consumed outside of a database queue, but arrays are OK:
> 
> ```swift
> let names = dbQueue.inDatabase { db in
>     return String.fetchAll(db, "SELECT name FROM ...")             // [String]
>     return String.fetch(db, "SELECT name FROM ...").filter { ... } // [String]
> }
> for name in names { ... } // OK
> ```


## Values

The library ships with built-in support for Bool, Int, Int32, Int64, Double, String, [NSData](#nsdata-and-memory-savings), [NSDate](#nsdate-and-nsdatecomponents), [NSDateComponents](#nsdate-and-nsdatecomponents), NSURL and [Swift enums](#swift-enums).

Custom value types are supported as well through the [DatabaseValueConvertible](#custom-value-types) protocol.


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

> :point_up: **Note**: The non-copied data does not live longer that the iteration step: make sure that you do not use it past this point.

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

See [Value Queries](#value-queries) for more detail on value fetching.


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
let row = Row.fetchOne(db, "SELECT birthDate, ...")!
let dbComponents: DatabaseDateComponents = row.value(named: "birthDate")
dbComponents.format         // .YMD (the actual format found in the database)
dbComponents.dateComponents // NSDateComponents

DatabaseDateComponents.fetch(db, "SELECT ...")    // DatabaseSequence<DatabaseDateComponents>
DatabaseDateComponents.fetchAll(db, "SELECT ...") // [DatabaseDateComponents]
DatabaseDateComponents.fetchOne(db, "SELECT ...") // DatabaseDateComponents?
```

See [Value Queries](#value-queries) for more detail on value fetching.


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

See [Value Queries](#value-queries) for more detail on value fetching.


### Custom Value Types

Conversion to and from the database is based on the `DatabaseValueConvertible` protocol:

```swift
public protocol DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns an instance initialized from databaseValue, if possible.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self?
}
```

All types that adopt this protocol can be used wherever the built-in types `Int`, `String`, etc. are used. without any limitation or caveat. Those built-in types actually adopt it.

The `databaseValue` property returns [DatabaseValue](GRDB/Core/DatabaseValue.swift), a type that wraps the five types supported by SQLite: NULL, Int64, Double, String and NSData.

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
        return DatabaseValue(double: date.timeIntervalSince1970)
    }
    
    /// Returns an instance initialized from *databaseValue*, if possible.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> DatabaseTimestamp? {
        // Double itself adopts DatabaseValueConvertible. So let's avoid
        // handling the raw DatabaseValue, and use built-in Double conversion:
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

See [Value Queries](#value-queries) for more detail on value fetching.


## Prepared Statements

**Prepared Statements** can be reused.

Update statements:

```swift
try dbQueue.inTransaction { db in
    
    let sql = "INSERT INTO persons (name, age) VALUES (:name, :age)"
    let statement = db.updateStatement(sql)
    
    let persons = [
        ["name": "Arthur", "age": 41],
        ["name": "Barbara", "age": 37],
    ]
    
    for person in persons {
        let changes = try statement.execute(arguments: StatementArguments(person))
        changes.changedRowCount // The number of rows changed by the statement.
        changes.insertedRowID   // The inserted Row ID.
    }
    
    return .Commit
}
```

Select statements can fetch [Rows](#row-queries), [Values](#value-queries), and [RowConvertible](#rowconvertible-protocol) types, including [Records](#records).

```swift
dbQueue.inDatabase { db in
    
    let statement = db.selectStatement("SELECT ...")
    
    Row.fetch(statement, arguments: ...)              // DatabaseSequence<Row>
    Row.fetchAll(statement, arguments: ...)           // [Row]
    Row.fetchOne(statement, arguments: ...)           // Row?
    
    Int.fetch(statement, arguments: ...)              // DatabaseSequence<Int>
    Int.fetchAll(statement, arguments: ...)           // [Int]
    Int.fetchOne(statement, arguments: ...)           // Int?
    Optional<Int>.fetch(statement, arguments: ...)    // DatabaseSequence<Int?>
    Optional<Int>.fetchAll(statement, arguments: ...) // [Int?]
    
    Person.fetch(statement, arguments: ...)           // DatabaseSequence<Person>
    Person.fetchAll(statement, arguments: ...)        // [Person]
    Person.fetchOne(statement, arguments: ...)        // Person?
}
```


## Error Handling

**No SQLite error goes unnoticed.** Yet when such an error happens, some GRDB.swift functions throw a DatabaseError error, and some crash with a fatal error.

**The rule** is:

- All methods that *write* to the database throw.
- All other methods crash without notice (but with a detailed error message).

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



## Transactions

The `DatabaseQueue.inTransaction()` method opens a SQLite transaction:

```swift
try dbQueue.inTransaction { db in
    let wine = Wine(grape: .Merlot, color: .Red, name: "Pomerol")
    try wine.insert(db)
    return .Commit
}
```

A ROLLBACK statement is issued if an error is thrown within the transaction block.

Otherwise, transactions are guaranteed to succeed, *provided there is a single DatabaseQueue connected to the database file*. See [Concurrency](#concurrency) for more information about concurrent database access.


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
- Inserted RowIDs (as the result of Database.execute()).
    - [sqlite3_last_insert_rowid](https://www.sqlite.org/c3ref/last_insert_rowid.html)
- Changes count (as the result of Database.execute()).
    - [sqlite3_changes](https://www.sqlite.org/c3ref/changes.html)
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

- [Migrations](#migrations): Transform your database as your application evolves.
- [Database Changes Observation](#database-changes-observation): A robust way to perform post-commit and post-rollback actions.
- [RowConvertible Protocol](#rowconvertible-protocol): Turn database rows into handy types, without sacrificing performance.
- [Records](#records): CRUD operations and changes tracking.


## Migrations

**Migrations** are a convenient way to alter your database schema over time in a consistent and easy way.

Migrations run in order, once and only once. When a user upgrades your application, only non-applied migrations are run.

```swift
var migrator = DatabaseMigrator()

// v1.0 database
migrator.registerMigration("createTables") { db in
    try db.execute("CREATE TABLE persons (...)")
    try db.execute("CREATE TABLE books (...)")
}

// v2.0 database
migrator.registerMigration("AddAgeToPersons") { db in
    try db.execute("ALTER TABLE persons ADD COLUMN age INT")
}

try migrator.migrate(dbQueue)
```

Each migration runs in a separate transaction. Should one throw an error, its transaction is rollbacked, and subsequent migrations do not run.

You might use Database.executeMultiStatement(): this method takes a SQL string containing multiple statements separated by semi-colons:

```swift
migrator.registerMigration("createTables") { db in
    try db.executeMultiStatement(
        "CREATE TABLE persons (...);" +
        "CREATE TABLE books (...);" +
        "...")
}
```

You might even store your migrations as bundle resources:

```swift
// Execute migration01.sql, migration02.sql, etc.
NSBundle.mainBundle()
    .pathsForResourcesOfType("sql", inDirectory: "databaseMigrations")
    .sort()
    .forEach { path in
        let migrationName = (path as NSString).lastPathComponent
        migrator.registerMigration(migrationName) { db in
            let sql = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
            try db.executeMultiStatement(sql)
        }
    }
```

## Database Changes Observation

The TransactionObserverType protocol lets you **observe database changes**:

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

All protocol callbacks are optional, and invoked on the database queue.

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
        self.changedTableNames = []
    }
}
```


## RowConvertible Protocol

**The `RowConvertible` protocol grants fetching methods to any type** that can be initialized from a database row:

```swift
public protocol RowConvertible {
    /// Create an instance initialized with `row`.
    init(row: Row)
    
    /// Optional method which gives adopting types an opportunity to complete
    /// their initialization. Do not call it directly.
    mutating func awakeFromFetch(row: Row)
}
```

Adopting types can be fetched just like rows:

```swift
struct PointOfInterest : RowConvertible {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    
    init(row: Row) {
        coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),
            row.value(named: "longitude"))
        title = row.value(named: "title")
    }
}

PointOfInterest.fetch(db, "SELECT ...")    // DatabaseSequence<PointOfInterest>
PointOfInterest.fetchAll(db, "SELECT ...") // [PointOfInterest]
PointOfInterest.fetchOne(db, "SELECT ...") // PointOfInterest?
```

> :point_up: **Note**: For performance reasons, the same row argument to `init(row:)` is reused during the iteration of a fetch query. If you want to keep the row for later use, make sure to store a copy: `self.row = row.copy()`.

You also get a dictionary initializer for free:

```swift
PointOfInterest(dictionary: [
    "latitude": 41.8919300,
    "longitude": 12.5113300,
    "title": "Rome"])
```

See also the [Record](#records) class, which builds on top of RowConvertible and adds a few extra features like CRUD operations, and changes tracking.


## Records

- [Overview](#record-overview)
- [Core Methods](#core-methods)
- [Fetching Records](#fetching-records)
- [Insert, Update and Delete](#insert-update-and-delete)
- [Record Initializers](#record-initializers)
- [Changes Tracking](#changes-tracking)
- [Record Errors](#record-errors)
- [Advice](#advice)


### Record Overview

**Record** is a class that wraps a table row or the result of any query, provides CRUD operations, and changes tracking. It is designed to be subclassed.

```swift
class Person : Record { ... }
let person = Person(name: "Arthur")
try person.save(db)
```

**Record is not a smart class.** It is no replacement for Core Data's NSManagedObject, or for an Active Record pattern. It does not provide any uniquing. It has no knowledge of your database schema, no notion of external references and table relationships, and will not generate JOIN queries for you.

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

- **It provides the classic CRUD operations.** GRDB supports all primary keys (auto-incremented INTEGER PRIMARY KEY, single column, multiple columns).
    
    ```swift
    let person = Person(...)
    try person.insert(db)   // Automatically fills person.id for INTEGER PRIMARY KEY.
    try person.update(db)
    try person.save(db)     // Inserts or updates
    try person.reload(db)
    try person.delete(db)
    ```
    
- **It tracks changes. Real changes**: setting a column to the same value does not constitute a change.
    
    ```swift
    person = Person.fetch...
    person.name = "Barbara"
    person.age = 41
    person.databaseChanges.keys // ["age"]
    if person.databaseEdited {
        try person.save(db)
    }
    ```


### Core Methods

Subclasses opt in Record features by overriding all or part of the core methods that define their relationship with the database:

| Core Methods               | fetch | insert | update | delete | exists | reload |
|:-------------------------- |:-----:|:------:|:------:|:------:|:------:|:------:|
| `updateFromRow`            |   ✓   |        |        |        |        |   ✓    |
| `databaseTableName`        |       |   ✓    |   ✓    |   ✓    |   ✓    |   ✓    |
| `storedDatabaseDictionary` |       |   ✓    |   ✓    |   ✓    |   ✓    |   ✓    |


**The typical Record boilerplate reads as below:**

```swift
class Person : Record {
    // Declare regular properties
    var id: Int64?
    var age: Int?
    var name: String?
    
    /// The table name
    override class func databaseTableName() -> String? {
        return "persons"
    }
    
    /// Update from a database row
    override func updateFromRow(row: Row) {
        if let dbv = row["id"]   { id = dbv.value() }
        if let dbv = row["age"]  { age = dbv.value() }
        if let dbv = row["name"] { name = dbv.value() }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
    
    /// The values stored in the database:
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "age": age]
    }
}
```

Yes, that's not very [DRY](http://c2.com/cgi/wiki?DontRepeatYourself), and there is no fancy mapping operators. That's because fancy operators make trivial things look magic, and non-trivial things look ugly. Record boilerplate is not magic, and not ugly: it's plain.

**Given those three core methods, you are granted with a lot more:**

```swift
class Person {
    // Initializers
    init()
    init(row: Row)
    convenience init(dictionary: [String: DatabaseValueConvertible?])
    convenience init(dictionary: NSDictionary)
    func copy() -> Self
    
    // Change Tracking
    var databaseEdited: Bool
    var databaseChanges: [String: (old: DatabaseValue?, new: DatabaseValue)]
    
    // CRUD
    func insert(db: Database) throws
    func update(db: Database) throws
    func save(db: Database) throws  // inserts or updates
    func delete(db: Database) throws -> DeletionResult
    func reload(db: Database) throws
    func exists(db: Database) -> Bool
    
    // Fetching from Prepared Statement
    static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil) -> DatabaseSequence<Self>
    static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil) -> [Self]
    static func fetchOne(statement: SelectStatement, arguments: StatementArguments? = nil) -> Self?
    
    // Fetching from Database
    static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> DatabaseSequence<Self>
    static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> [Self]
    static func fetchOne(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> Self?
    
    // Fetching from Keys
    static func fetchOne(db: Database, primaryKey: DatabaseValueConvertible?) -> Self?
    static func fetchOne(db: Database, key: [String: DatabaseValueConvertible?]) -> Self?
    
    // Events
    func awakeFromFetch(row: Row)
    
    // Description
    var description: String
}
```


### Fetching Records

You can fetch **sequences**, **arrays**, or **single** records:

```swift
dbQueue.inDatabase { db in
    Person.fetch(db, "SELECT ...", arguments:...)    // DatabaseSequence<Person>
    Person.fetchAll(db, "SELECT ...", arguments:...) // [Person]
    Person.fetchOne(db, "SELECT ...", arguments:...) // Person?
    Person.fetchOne(db, primaryKey: ...)             // Person?
    Person.fetchOne(db, key: ["name": "Arthur"])     // Person?
}
```

> :point_up: **Note**: Sequences can not be consumed outside of a database queue, but arrays are OK:
> 
> ```swift
> let persons = dbQueue.inDatabase { db in
>     return Person.fetchAll(db, "SELECT ...")             // [Person]
>     return Person.fetch(db, "SELECT ...").filter { ... } // [Person]
> }
> for person in persons { ... } // OK
> ```

The method `fetchOne(_:primaryKey:)` accepts a single value as a key. For Record with multiple-column primary keys, use `fetchOne(_:key:)`.

Those fetching methods are based on the `updateFromRow` and `databaseTableName` core methods:

```swift
class Person : Record {
    /// The table name
    override class func databaseTableName() -> String? {
        return "persons"
    }
    
    /// Update from a database row
    override func updateFromRow(row: Row) {
        if let dbv = row["id"]   { id = dbv.value() }
        if let dbv = row["age"]  { age = dbv.value() }
        if let dbv = row["name"] { name = dbv.value() }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
}
```

See [Rows as Dictionaries](#rows-as-dictionaries) for more information about the `DatabaseValue` type of the `dbv` variable, and [Values](#values) about the supported property types.

> :point_up: **Note**: For performance reasons, the same row argument to `updateFromRow(_)` is reused for all Person records during the iteration of a fetch query. If you want to keep the row for later use, make sure to store a copy: `self.row = row.copy()`.


### Insert, Update and Delete

Records can store themselves in the database through the `storedDatabaseDictionary` core property:

```swift
class Person : Record {
    // The values stored in the database:
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name, "age": age]
    }
}

try dbQueue.inDatabase { db in
    let person = Person(...)
    try person.insert(db)
    try person.update(db)
    try person.save(db)     // Inserts or updates
    try person.reload(db)
    try person.delete(db)
    person.exists(db)       // Bool
}
```

Records whose primary key is declared as "INTEGER PRIMARY KEY" have their id automatically set after successful insertion.

Other primary keys (single or multiple columns) are not managed by GRDB: you have to manage them yourself. You can for example override the `insert` primitive method, and make sure your primary key is set before calling `super.insert`.


### Record Initializers

**Record has four initializers:**

```swift
class Record {
    // Designated initializers:
    init()
    required init(row: Row)
    
    // Convenience initializers:
    convenience init(dictionary: [String: DatabaseValueConvertible?])
    convenience init(dictionary: NSDictionary)
}
```

**Whenever you add your own custom initializer**, Swift requires you to call one of the designated initializers of your Record superclass, and to provide an implementation of the required `init(row:)`:

```swift
class Person : Record {
    var id: Int64?
    var age: Int?
    var name: String?
    
    // Person(name: "Arthur", age: 41)
    init(id: Int64? = nil, name: String?, age: Int?) {
        self.id = id
        self.age = age
        self.name = name
        
        // Required by Swift
        super.init()
    }
    
    // Required by Swift
    required init(row: Row) {
        super.init(row: row)
    }
}
```


### Changes Tracking

The `update()` method always executes an UPDATE statement. When the record has not been edited, this database access is generally useless.

Avoid it with the `databaseEdited` property, which returns whether the record has changes that have not been saved:

```swift
let json = ...
try dbQueue.inTransaction { db in
    // Fetches or create a new person given its ID:
    let person: Person
    if let existingPerson = Person.fetchOne(db, primaryKey: json["id"]) {
        person = existingPerson
    } else {
        person = Person()
    }
    
    // Apply json payload:
    person.updateFromJSON(json)
                 
    // Saves the person if it is edited (fetched then modified, or created):
    if person.databaseEdited {
        try person.save(db) // inserts or updates
    }
    
    return .Commit
}
```

Note that `databaseEdited` is based on value comparison: **setting a property to the same value does not set the edited flag**.


### Record Errors

Record methods can throw [DatabaseError](#error-handling) and also specific errors of type **RecordError**:

- **RecordError.RecordNotFound**: thrown by `update` and `reload` when the primary key does not match any row in the database.


### Advice

- [Autoincrement](#autoincrement)
- [Ad Hoc Subclasses](#ad-hoc-subclasses)
- [Validation](#validation)
- [Default Values](#default-values)
- [INSERT OR REPLACE](#insert-or-replace)


#### Autoincrement

**For "autoincremented" ids**, declare your id column as INTEGER PRIMARY KEY:

```sql
CREATE TABLE persons {
    id INTEGER PRIMARY KEY,
    ...
}
```

```swift
class Person : Record {
    id: Int64?
    
    /// The table definition.
    override class func databaseTableName() -> String? {
        return "persons"
    }
    
    /// The values that should be stored in the database.
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, ...]
    }
    
    /// Updates `self` with a database value.
    override func updateFromRow(row: Row) {
        if let dbv = row["id"] { id = dbv.value() }
        ...
        super.updateFromRow(row) // Subclasses are required to call super.
    }
}

let person = Person(...)
person.id   // nil
try person.insert(db)
person.id   // some value
```


#### Ad Hoc Subclasses

Don't hesitate deriving subclasses from your base records when you have a need for a specific query.

For example, if a view controller needs to display a list of persons along with the number of books they own, it would be unreasonable to fetch the list of persons, and then, for each of them, fetch the number of books they own. That would perform N+1 requests, and [this is a well known issue](http://stackoverflow.com/questions/97197/what-is-the-n1-selects-issue).

Instead, subclass Person:

```swift
class PersonsViewController: UITableViewController {
    private class PersonWithBookCount : Person {
        var bookCount: Int?
    
        override func updateFromRow(row: Row) {
            if dbv = row["bookCount"] { bookCount = dbv.value() }
            super.updateFromRow(row) // Let Person superclass finish the job.
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
            personVC.person = persons[self.tableView.indexPathForSelectedRow!.row]
        }
    }
}
```


#### Validation

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


#### Default Values

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
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
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


#### INSERT OR REPLACE

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


## Thanks

- [Pierlis](http://pierlis.com), where we write great software.
- [@pierlo](https://github.com/pierlo) for his feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [@kali](https://github.com/kali) because SQL.
- [ccgus/fmdb](https://github.com/ccgus/fmdb) for its excellency.
