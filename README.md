GRDB.swift
==========

GRDB.swift is an [SQLite](https://www.sqlite.org) toolkit for Swift 2, from the author of [GRMustache](https://github.com/groue/GRMustache).

It ships with a low-level database API, plus application-level tools.

**September 14, 2015: GRDB.swift 0.16.0 is out** - [Release notes](CHANGELOG.md). Follow [@groue](http://twitter.com/groue) on Twitter for release announcements and usage tips.

Jump to:

- [Features](#features)
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
- **Database Migrations**

**Users of [ccgus/fmdb](https://github.com/ccgus/fmdb)** will feel at ease with GRDB.swift. They may find GRDB to be easier when [fetching](#fetch-queries) data from the database. And they'll definitely be happy that [database errors](#error-handling) are propertly handled.

**Users of [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift)** may eventually find that `Item.fetchAll(db, "SELECT * FROM items ORDER BY lastModified DESC")` is not a bad alternative to `Array(db["items"].order(ItemColumns.LastModified.desc)).map { Item(row: RowToDictionary($0))! }`.


Usage
-----

```swift
import GRDB

// Open database connection
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

try dbQueue.inTransaction { db in
    let wine = Wine(grape: .Merlot, color: .Red, name: "Pomerol")
    try wine.insert(db)
    return .Commit
}

let redWinesCount = dbQueue.inDatabase { db in       // Int
    Int.fetchOne(db,
        "SELECT COUNT(*) FROM wines WHERE color = ?",
        arguments: [Color.Red])!
}

dbQueue.inDatabase { db in
    let wines = Wine.fetchAll(db, "SELECT ...")      // [Wine]
    for wine in Wine.fetch(db, "SELECT ...") {       // AnySequence<Wine>
        ...
    }
}
```


Benchmarks
----------

In its current state, **GRDB.swift is 4 times slower than ccgus/fmdb at processing fetched rows**.

Those benchmarks are available in [this commit](tree/7a9446fc20864b008eb843c72c5573138b36c8cc): run tests for the GRDBOSX scheme, in Release configuration, and check the results under the "Performance" tab in the Xcode Report Navigator. The work in progress in the [Metal branch](tree/Metal) brings GRDB on a par with fmdb.


Installation
------------

### iOS7

To use GRDB.swift in a project targetting iOS7, you must include the source files directly in your project.


### CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Xcode projects.

To use GRDB.swift with Cocoapods, specify in your Podfile:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

pod 'GRDB.swift', '0.16.0'
```


### Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency manager for Xcode projects.

To use GRDB.swift with Carthage, specify in your Cartfile:

```
github "groue/GRDB.swift" == 0.16.0
```


### Manually

Download a copy of GRDB.swift, embed the `GRDB.xcodeproj` project in your own project, and add the `GRDBOSX` or `GRDBiOS` target as a dependency of your own target.


Documentation
=============

To fiddle with the library, open the `GRDB.xcworkspace` workspace: it contains a GRDB-enabled Playground at the top of the files list.

**Reference**

- [GRDB Reference](http://cocoadocs.org/docsets/GRDB.swift/0.16.0/index.html) on cocoadocs.org. Beware that is it incomplete. You may prefer reading the inline documentation right into the [source](https://github.com/groue/GRDB.swift/tree/master/GRDB).

**Guides**

- [SQLite Database](#sqlite-database)
    - [Fetch Queries](#fetch-queries)
        - [Row Queries](#row-queries)
        - [Value Queries](#value-queries)
    - [Values](#values)
        - [NSDate and NSDateComponents](#nsdate-and-nsdatecomponents)
        - [Swift enums](#swift-enums)
        - [Custom Value Types](#custom-value-types)
    - [Transactions](#transactions)
    - [Prepared Statements](#prepared-statements)
    - [Error Handling](#error-handling)
    - [Concurrency](#concurrency)
- [Migrations](#migrations)
- [Records](#records)
    - [Core Methods](#core-methods)
    - [Fetching Records](#fetching-records)
        - [Ad Hoc Subclasses](#ad-hoc-subclasses)
    - [Tables and Primary Keys](#tables-and-primary-keys)
        - [Insert, Update and Delete](#insert-update-and-delete)
        - [Preventing Useless UPDATE Statements](#preventing-useless-update-statements)
    - [Record Errors](#record-errors)
    - [Advice](#advice)


## SQLite Database

You access SQLite databases through thread-safe **database queues** (inspired by [ccgus/fmdb](https://github.com/ccgus/fmdb)):

```swift
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let inMemoryDBQueue = DatabaseQueue()
```

The database connection is closed when the database queue gets deallocated.

**Configure** databases:

```swift
let configuration = Configuration(
    foreignKeysEnabled: true,   // Default true
    readonly: false,            // Default false
    trace: Configuration.logSQL // An optional trace function.
                                // Configuration.logSQL logs all SQL statements.
)

let dbQueue = try DatabaseQueue(
    path: "/path/to/database.sqlite",
    configuration: configuration)
```

See [Concurrency](#concurrency) for more details on database configuration.

The `inDatabase` and `inTransaction` methods perform your **database statements** in a dedicated, serial, queue:

```swift
// Extract values from the database:
let rows = dbQueue.inDatabase { db in
    Row.fetch(db, "SELECT ...")
}

// Execute database statements:
dbQueue.inDatabase { db in
    let persons = Person.fetchAll(db, "SELECT...")
    let books = Book.fetchAll(db, "SELECT ...")
    ...
}

// Wrap database statements in a transaction:
try dbQueue.inTransaction { db in
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (?, ?)",
        arguments: ["Arthur", 36])
    
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (:name, :age)",
        arguments: ["name": "Barbara", "age": 37])
    
    return .Commit
}
```

See [Transactions](#transactions) for more information about GRDB transaction handling.

To create tables, we recommend using [migrations](#migrations).


### Fetch Queries

You can fetch **Rows**, **Values**, and **Records**:

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
    Person.fetchOne(db, primaryKey: 12)                // Person?
    Person.fetchOne(db, key: ["name": "Arthur"])       // Person?
}
```

The last two methods are the only ones that don't take a custom SQL query as an argument. If SQL is not your cup of tea, then maybe you are looking for a query builder. [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md#selecting-rows) is a pretty popular one.

- [Row Queries](#row-queries)
- [Value Queries](#value-queries)
- [Records](#records)


#### Row Queries

Fetch **lazy sequences** of rows, **arrays**, or a **single** row:

```swift
dbQueue.inDatabase { db in
    Row.fetch(db, "SELECT ...", arguments: ...)     // AnySequence<Row>
    Row.fetchAll(db, "SELECT ...", arguments: ...)  // [Row]
    Row.fetchOne(db, "SELECT ...", arguments: ...)  // Row?
}
```

Arguments are optional arrays or dictionaries that fill the positional `?` and named parameters like `:name` in the query. GRDB.swift only supports colon-prefixed named parameters, even though SQLite supports [other syntaxes](https://www.sqlite.org/lang_expr.html#varparam).


```swift
Row.fetch(db, "SELECT * FROM persons WHERE name = ?", arguments: ["Arthur"])
Row.fetch(db, "SELECT * FROM persons WHERE name = :name", arguments: ["name": "Arthur"])
```

Lazy sequences can not be consumed outside of a database queue, but arrays are OK:

```swift
let rows = dbQueue.inDatabase { db in
    return Row.fetchAll(db, "SELECT ...")             // [Row]
    return Row.fetch(db, "SELECT ...").filter { ... } // [Row]
}
for row in rows { ... } // OK
```


**Read row values** by index or column name:

```swift
let name: String? = row.value(atIndex: 0)
let name: String? = row.value(named: "name")

// Force unwrap when value is not NULL
let id: Int64 = row.value(named: "id")!
```

All types that adopt the [DatabaseValueConvertible](#custom-value-types) protocol can be extracted. Pick the one you need:

```swift
let bookCount: Int      = row.value(named: "bookCount")!
let bookCount64: Int64  = row.value(named: "bookCount")!
let hasBooks: Bool      = row.value(named: "bookCount")! // false when 0

let dateString: String? = row.value(named: "date")       // "2015-09-11 18:14:15.123"
let date: NSDate?       = row.value(named: "date")       // NSDate
let int: Int?           = row.value(named: "date")       // nil (Int can't be extracted from "2015...")
```

**WARNING**: You can use the `as` type casting operator, but beware (see [rdar://21676393](http://openradar.appspot.com/radar?id=4951414862249984)):

```swift
row.value(...)! as Int   // OK: Int
row.value(...) as Int?   // OK: Int?
row.value(...) as! Int   // NO NO NO DON'T DO THAT!
row.value(...) as? Int   // NO NO NO DON'T DO THAT!
```

##### Rows as Dictionaries

The `row.value(named:)` and `row.value(atIndex:)` methods above require that you know the row structure: which columns are available, in which order.

When you process an unknown row, you will prefer thinking of it as a dictionary of `DatabaseValue`, an intermediate type between SQLite and your values:

```swift
// Test if the column `name` is present:
if let databaseValue = row["name"] {
    // Extract the desired Swift type from the database value:
    let name: String? = databaseValue.value()
}
```

You can also iterate all the tuples (columnName, databaseValue) in a row:

```swift
for (columnName, databaseValue) in row {
    ...
}
```

Beware that rows, unlike dictionaries, may contain duplicate keys:

```swift
let row = Row.fetchOne(db, "SELECT 1 AS a, 2 AS a")!
row.columnNames     // ["a", "a"]
row.databaseValues  // [1, 2]
row["a"]            // 1
for (columnName, databaseValue) in row { ... } // ("a", 1), ("a", 2)
```


#### Value Queries

Instead of rows, you can directly fetch **values**, extracted from the first column of the resulting rows.

Like rows, values can be fetched as **lazy sequences**, **arrays**, or **single** value:

```swift
dbQueue.inDatabase { db in
    Int.fetch(db, "SELECT ...", arguments: ...)      // AnySequence<Int?>
    Int.fetchAll(db, "SELECT ...", arguments: ...)   // [Int?]
    Int.fetchOne(db, "SELECT ...", arguments: ...)   // Int?
}
```

Lazy sequences can not be consumed outside of a database queue, but arrays are OK:

```swift
let names = dbQueue.inDatabase { db in
    return String.fetchAll(db, "SELECT name ...")             // [String?]
    return String.fetch(db, "SELECT name ...").filter { ... } // [String?]
}
for name in names { ... } // OK
```

Sequences and arrays contain optional values. When you are sure that all results are not NULL, unwrap the optionals with the bang `!` operator:

```swift
// names is [String]
let names = dbQueue.inDatabase { db in
    String.fetchAll(db, "SELECT name FROM persons").map { $0! }
}
```

The `fetchOne(_:sql:arguments:)` method returns an optional value which is nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value. If this ambiguity does not fit your need, use `Row.fetchOne(_:sql:arguments:)`.


### Values

The library ships with built-in support for `Bool`, `Int`, `Int32`, `Int64`, `Double`, `String`, `NSData`, [NSDate](#nsdate-and-nsdatecomponents), [NSDateComponents](#nsdate-and-nsdatecomponents), and [Swift enums](#swift-enums).

Custom value types are supported as well through the [DatabaseValueConvertible](#custom-value-types) protocol.


#### NSDate and NSDateComponents

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


##### NSDate

GRDB stores NSDate using the format "yyyy-MM-dd HH:mm:ss.SSS" in the UTC time zone.

> This format is lexically comparable with SQLite's CURRENT_TIMESTAMP, which means that your ORDER BY clauses will behave as expected.
>
> Yet, this format may not fit your needs. We provide [below](#custom-value-types) some sample code for storing dates as timestamps. You can adapt it for your application.


Declare DATETIME columns in your tables:

```swift
try db.execute(
    "CREATE TABLE persons (" +
    "birthDate DATETIME, " +
    "...)")
```

Store NSDate into the database:

```swift
let birthDate = NSDate()
try db.execute("INSERT INTO persons (birthDate, ...) " +
                            "VALUES (?, ...)",
                         arguments: [birthDate, ...])
```

Extract NSDate from the database:

```swift
let row = Row.fetchOne(db, "SELECT birthDate, ...")!
let date = row.value(named: "birthDate") as NSDate?

NSDate.fetch(db, "SELECT ...")       // AnySequence<NSDate?>
NSDate.fetchAll(db, "SELECT ...")    // [NSDate?]
NSDate.fetchOne(db, "SELECT ...")    // NSDate?
```

Use NSDate in a Record (see [Fetching Records](#fetching-records) for more information):

```swift
class Person : Record {
    var birthDate: NSDate?
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["birthDate": birthDate, ...]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["birthDate"] { birthDate = dbv.value() }
        ...
    }
}
```

One could reasonably wonder if NSDate is a suitable type for a birth date. Well, NSDateComponents has built-in support in GRDB as well:


##### NSDateComponents

NSDateComponents is indirectly supported, through the **DatabaseDateComponents** helper type.

DatabaseDateComponents reads date components from all [date formats supported by SQLite](https://www.sqlite.org/lang_datefunc.html), and stores them in the format of your choice, from HH:MM to YYYY-MM-DD HH:MM:SS.SSS.

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
let dbComponents = row.value(named: "birthDate")! as DatabaseDateComponents
dbComponents.format         // .YMD (the actual format found in the database)
dbComponents.dateComponents // NSDateComponents

DatabaseDateComponents.fetch(db, "SELECT ...")    // AnySequence<DatabaseDateComponents?>
DatabaseDateComponents.fetchAll(db, "SELECT ...") // [DatabaseDateComponents?]
DatabaseDateComponents.fetchOne(db, "SELECT ...") // DatabaseDateComponents?
```

Use NSDateComponents in a Record (see [Fetching Records](#fetching-records) for more information):

```swift
class Person : Record {
    var birthDateComponents: NSDateComponents?
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        // Store birth date as YYYY-MM-DD:
        let dbComponents = DatabaseDateComponents(
            birthDateComponents,
            format: .YMD)
        return ["birthDate": dbComponents, ...]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["birthDate"] {
            let dbComponents = dbv.value() as DatabaseDateComponents?
            birthDateComponents = dbComponents?.dateComponents
        }
        ...
    }
}
```


#### Swift Enums

**Swift enums** get full support from GRDB.swift as long as their raw values are Int or String.

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
extension Color : DatabaseIntRepresentable { }
extension Grape : DatabaseStringRepresentable { }
```

And both types gain database powers:

```swift
// Store:
try db.execute("INSERT INTO wines (grape, color) VALUES (?, ?)",
               arguments: [Grape.Merlot, Color.Red])

// Extract from row:
for rows in Row.fetch(db, "SELECT * FROM wines") {
    let grape: Grape? = row.value(named: "grape")
    let color: Color? = row.value(named: "color")
}

// Direct fetch:
Color.fetch(db, "SELECT ...", arguments: ...)    // AnySequence<Color?>
Color.fetchAll(db, "SELECT ...", arguments: ...) // [Color?]
Color.fetchOne(db, "SELECT ...", arguments: ...) // Color?
```


#### Custom Value Types

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

The `databaseValue` property returns [DatabaseValue](GRDB/Core/DatabaseValue.swift), an enum for the five types supported by SQLite: NULL, integer, real, string and blob.

The `fromDatabaseValue()` factory method returns an instance of your custom type, if the databaseValue contains a suitable value.

As an example, let's write an alternative to the built-in [NSDate](#nsdate-and-nsdatecomponents) behavior, and store dates as timestamps. Our sample DatabaseTimestamp type applies all the best practices for a great GRDB.swift integration:

```swift
struct DatabaseTimestamp: DatabaseValueConvertible {
    
    // NSDate conversion
    //
    // We consistently use the Swift nil to represent the database NULL: the
    // date property is a non-optional NSDate, and the NSDate initializer is
    // failable:
    
    /// The represented date
    let date: NSDate
    
    /// Creates a DatabaseTimestamp from an NSDate.
    /// The result is nil if and only if *date* is nil.
    init?(_ date: NSDate?) {
        guard let date = date else {
            return nil
        }
        self.date = date
    }
    
    
    // DatabaseValueConvertible adoption
    
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue {
        return .Real(date.timeIntervalSince1970)
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
    let date = (row.value(named: "date") as DatabaseTimestamp?)?.date
}

// Direct fetch:
DatabaseTimestamp.fetch(db, "SELECT ...")    // AnySequence<DatabaseTimestamp?>
DatabaseTimestamp.fetchAll(db, "SELECT ...") // [DatabaseTimestamp?]
DatabaseTimestamp.fetchOne(db, "SELECT ...") // DatabaseTimestamp?
```


#### Value Extraction in Details

SQLite has a funny way to manage values. It is "funny" because it is a rather long read: https://www.sqlite.org/datatype3.html.

The interested reader should know that GRDB.swift *does not* use SQLite built-in casting features when extracting values. Instead, it performs its *own conversions*, based on the storage class of database values:

| Storage class |  Bool   |  Int ³  |  Int32  |  Int64   | Double | String ³  | Blob |
|:------------- |:-------:|:-------:|:--------:|:--------:|:------:|:---------:|:----:|
| NULL          |    -    |    -    |    -    |    -     |   -    |     -     |  -   |
| INTEGER       |  Bool ¹ |  Int ²  | Int32 ² |  Int64   | Double |     -     |  -   |
| REAL          |  Bool ¹ |  Int ²  | Int32 ² | Int64 ²  | Double |     -     |  -   |
| TEXT          |    -    |    -    |    -    |    -     |   -    |  String   |  -   |
| BLOB          |    -    |    -    |    -    |    -     |   -    |     -     | Blob |

¹ The only false numbers are 0 (integer) and 0.0 (real).

² You will get a fatal error if the value is too big for Int, Int32 or Int64.

³ Applies also to Int and String-based [enums](#swift-enums).

Your [Custom Value Types](#custom-value-types) can perform their own conversions to and from SQLite storage classes.


### Transactions

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


### Prepared Statements

**Prepared Statements** can be reused.

Update statements:

```swift
try dbQueue.inTransaction { db in
    
    let sql = "INSERT INTO persons (name, age) VALUES (:name, :age)"
    let statement = db.updateStatement(sql)
    
    let persons = [
        ["name": "Arthur", "age": 41],
        ["name": "Barbara"],
    ]
    
    for person in persons {
        let changes = try statement.execute(arguments: StatementArguments(person))
        changes.changedRowCount // The number of rows changed by the statement.
        changes.insertedRowID   // The inserted Row ID.
    }
    
    return .Commit
}
```

Select statements can fetch rows, values, and [Records](#records).

```swift
dbQueue.inDatabase { db in
    
    let statement = db.selectStatement("SELECT ...")
    
    Row.fetch(statement, arguments: ...)        // AnySequence<Row>
    Row.fetchAll(statement, arguments: ...)     // [Row]
    Row.fetchOne(statement, arguments: ...)     // Row?
    
    Int.fetch(statement, arguments: ...)        // AnySequence<Int?>
    Int.fetchAll(statement, arguments: ...)     // [Int?]
    Int.fetchOne(statement, arguments: ...)     // Int?
    
    Person.fetch(statement, arguments: ...)     // AnySequence<Person>
    Person.fetchAll(statement, arguments: ...)  // [Person]
    Person.fetchOne(statement, arguments: ...)  // Person?
}
```


### Error Handling

**No SQLite error goes unnoticed.** Yet when such an error happens, some GRDB.swift functions throw a DatabaseError error, and some crash with a fatal error.

**The rule** is:

- All methods that *read* data crash without notice.
- All methods that *write* data throw.

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


#### Concurrency

**When your application has a single DatabaseQueue connected to the database file, it has no concurrency issue.** That is because all your database statements are executed in a single serial dispatch queue that is connected alone to the database.

**Things turn more complex as soon as there are several connections to a database file.**

SQLite concurrency management is fragmented. Documents of interest include:

- General discussion about isolation in SQLite: https://www.sqlite.org/isolation.html
- Types of locks and transactions: https://www.sqlite.org/lang_transaction.html
- WAL journal mode: https://www.sqlite.org/wal.html
- Busy handlers: https://www.sqlite.org/c3ref/busy_handler.html

By default, GRDB opens database in the **default journal mode**, uses **IMMEDIATE transactions**, and registers **no busy handler** of any kind.

See [Configuration](GRDB/Core/Configuration.swift) type and [DatabaseQueue.inTransaction()](GRDB/Core/DatabaseQueue.swift) method for more precise handling of transactions and eventual SQLITE_BUSY errors.


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

You might prefer to use Database.executeMultiStatement(). This method takes a SQL string containing multiple statements separated by semi-colons.

```swift
migrator.registerMigration("createTables") { db in
    try db.executeMultiStatement(
        "CREATE TABLE persons (...);" +
        "CREATE TABLE books (...)")
}
```

You might even store your migrations as bundle resources:

```swift
// Load paths to migration01.sql, migration02.sql, etc.
let migrationPaths = NSBundle.mainBundle()
    .pathsForResourcesOfType("sql", inDirectory: "databaseMigrations")
    .sort()
for path in migrationPaths {
    migrator.registerMigration((path as NSString).lastPathComponent) { db in
        try db.executeMultiStatement(String(contentsOfFile: path))
    }
}
```

## Records

**Record** is a class that wraps a table row, or the result of any query. It is designed to be subclassed.

```swift
class Person : Record { ... }
let person = Person(name: "Arthur")
person.save(db)
```

**Record is not a smart class.** It is no replacement for Core Data, or for an Active Record pattern. It does not provide any uniquing. It has no knowledge of your database schema, no notion of external references and table relationships, and will not generate JOIN queries for you.

Yet, it does a few things well:

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

- **It provides the classic CRUD operations.** Primary keys can be an automatically generated RowID, or a multi-column primary key.
    
    ```swift
    let person = Person(name: "Arthur")                  // RowID primary key
    let country = Country(isoCode: "FR", name: "France") // String primary key
    let citizenship = Citizenship(personId: person.id, countryIsoCode: country.isoCode)   // Multiple columns primary key
    
    try person.insert(db)   // Automatically fills person.id
    person.name = "Barbara"
    try person.update(db)
    
    try country.save(db) // inserts or update
    try citizenship.save(db)
    
    try citizenship.delete(db)
    country.exists(db)  // false
    ```
    
- **It tracks changes. Real changes**: setting a column to the same value does not constitute a change.
    
    ```swift
    person = Person.fetch...
    person.name = "Barbara"
    person.age = 41
    person.databaseChanges.keys // ["name"]
    if person.databaseEdited {
        person.save(db)
    }
    ```

- [Core Methods](#core-methods)
- [Fetching Records](#fetching-records)
    - [Ad Hoc Subclasses](#ad-hoc-subclasses)
- [Tables and Primary Keys](#tables-and-primary-keys)
    - [Insert, Update and Delete](#insert-update-and-delete)
    - [Preventing Useless UPDATE Statements](#preventing-useless-update-statements)
- [Record Errors](#record-errors)
- [Advice](#advice)


### Core Methods

Subclasses opt in Record features by overriding all or part of the core methods that define their relationship with the database:

| Core Methods               | fetch | insert | update | delete | reload |
|:-------------------------- |:-----:|:------:|:------:|:------:|:------:|
| `updateFromRow`            |   ✓   |        |        |        |   ✓    |
| `databaseTableName`        |       |   ✓    |   ✓    |   ✓    |   ✓    |
| `storedDatabaseDictionary` |       |   ✓    |   ✓    |   ✓    |   ✓    |


### Fetching Records

The Person subclass below will be our guinea pig. It declares properties for the `persons` table:

```swift
class Person : Record {
    var id: Int64?      // matches "id" column
    var age: Int?       // matches "age" column
    var name: String?   // matches "name" column
}
```

The `updateFromRow` method assigns database values to properties:

```swift
class Person : Record {
    override func updateFromRow(row: Row) {
        if let dbv = row["id"]   { id = dbv.value() }
        if let dbv = row["age"]  { age = dbv.value() }
        if let dbv = row["name"] { name = dbv.value() }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
}
```

See [Rows as Dictionaries](#rows-as-dictionaries) for more information about the `DatabaseValue` type, and [Values](#values) about the supported property types.

Now you can fetch **lazy sequences** of records, **arrays**, or **single** instances:

```swift

dbQueue.inDatabase { db in
    Person.fetch(db, "SELECT ...", arguments:...)    // AnySequence<Person>
    Person.fetchAll(db, "SELECT ...", arguments:...) // [Person]
    Person.fetchOne(db, "SELECT ...", arguments:...) // Person?
}
```

Lazy sequences can not be consumed outside of a database queue, but arrays are OK:

```swift
let persons = dbQueue.inDatabase { db in
    return Person.fetchAll(db, "SELECT ...")             // [Person]
    return Person.fetch(db, "SELECT ...").filter { ... } // [Person]
}
for person in persons { ... } // OK
```


#### Ad Hoc Subclasses

Swift makes it very easy to create small and private types. This is a wonderful opportunity to create **ad hoc subclasses** that provide support for custom queries with extra columns.

We think that this is the killer feature of GRDB.swift :bowtie:. For example:

```swift
class PersonsViewController: UITableViewController {
    
    // Private subclass of Person, with an extra `bookCount` property:
    private class PersonWithBookCount : Person {
        var bookCount: Int!
        
        override func updateFromRow(row: Row) {
            if dbv = row["bookCount"] { bookCount = dbv.value() }
            super.updateFromRow(row) // Let Person superclass finish the job.
        }
    }
    
    var persons: [PersonWithBookCount]!
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        persons = dbQueue.inDatabase { db in
            PersonWithBookCount.fetchAll(db,
                "SELECT persons.*, COUNT(*) AS bookCount " +
                "FROM persons " +
                "JOIN books ON books.ownerID = persons.id " +
                "GROUP BY persons.id")
        }
        
        tableView.reloadData()
    }
    
    ...
}
```


### Tables and Primary Keys

If you declare a **Table name**, GRDB infers your table's primary key automatically and you can fetch instances by ID or any other key.

```swift
class Person : Record {
    override class func databaseTableName() -> String? {
        return "persons"
    }
}

try dbQueue.inDatabase { db in
    // Person?
    let person = Person.fetchOne(db, primaryKey: 123)
    
    // Citizenship?
    let citizenship = Citizenship.fetchOne(db,
        key: ["personId": 123, "countryIsoCode": "FR"])
}
```

Records with a multi-column primary key are not supported by `fetchOne(_:primaryKey:)`, which accepts a single value as a key. Instead, use `fetchOne(_:key:)` that uses a dictionary.

`fetchOne(_:key:)` returns the first Record with matching values. Its result is undefined unless the dictionary is *actually* a key.

[Implicit RowIDs](https://www.sqlite.org/lang_createtable.html#rowid) are not supported.


#### Insert, Update and Delete

With one more override, you get the `insert`, `update`, `delete`, `save`, `reload` and `exists` methods.

```swift
class Person : Record {
    // The values stored in the database:
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name, "age": age]
    }
}

try dbQueue.inTransaction { db in
    
    // Insert
    let person = Person(name: "Arthur", age: 41)
    try person.insert(db)
    
    // Update
    person.age = 42
    try person.update(db)
    
    // Reload
    person.age = 666
    try person.reload(db)
    
    // Delete
    try person.delete(db)
    
    return .Commit
}
```

Records whose primary key is declared as "INTEGER PRIMARY KEY" have their id automatically set after successful insertion.

Other primary keys (single or multiple columns) are not managed by GRDB: you have to manage them yourself. You can for example override the `insert` primitive method, and make sure your primary key is set before calling `super.insert`.


#### Preventing Useless UPDATE Statements

The `update()` method always executes an UPDATE statement. When the record has not been edited, this database access is generally useless.

Avoid it with the `databaseEdited` property, which returns whether the record has changes that have not been saved:

```swift
let json = ...
try dbQueue.inTransaction { db in
    // Fetches or create a new person given its ID:
    let person = Person.fetchOne(db, primaryKey: json["id"]) ?? Person()
    
    // Apply json payload:
    person.updateFromJSON(json)
                 
    // Saves the person if it is edited (fetched then modified, or created):
    if person.databaseEdited {
        person.save(db) // inserts or updates
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




**First, your SELECT queries can fail.** Database may be locked by a writer that and expell a readers from performing aWriters can prevent readers to read
You must wrap your reading statements in transactions when 
Given that SQLite only supports a [single writer](https://www.sqlite.org/isolation.html) on a given database file, things turn more complex as soon as there are several connections to a database file.

Here are a few steps that you *need*






## Thanks

- [Pierlis](http://pierlis.com), where we write great software.
- [@pierlo](https://github.com/pierlo) for his feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [@kali](https://github.com/kali) because SQL.
- [ccgus/fmdb](https://github.com/ccgus/fmdb) for its excellency.
