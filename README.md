GRDB.swift
==========

GRDB.swift is an [SQLite](https://www.sqlite.org) toolkit for Swift 2, from the author of [GRMustache](https://github.com/groue/GRMustache).

It ships with a low-level database API, plus application-level tools.

**September 4, 2015: GRDB.swift 0.11.0 is out** - [Release notes](RELEASE_NOTES.md). Follow [@groue](http://twitter.com/groue) on Twitter for release announcements and usage tips.

Jump to:

- [Usage](#usage)
- [Installation](#installation)
- [Documentation](#documentation)


Features
--------

- **A low-level SQLite API** that leverages the Swift 2 standard library.
- **No ORM, no smart query builder, no table introspection**. Your SQL skills are welcome here.
- **A Model class** that wraps result sets, eats your custom SQL queries for breakfast, and provides basic CRUD operations.
- **Swift type freedom**: pick the right Swift type that fits your data. Use Int64 when needed, or stick with the convenient Int. Store and read NSDate or NSDateComponents. Declare Swift enums for discrete data types. Define your own database-convertible types.
- **Database Migrations**


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

pod 'GRDB.swift', '0.11.0'
```


### Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency manager for Xcode projects.

To use GRDB.swift with Carthage, specify in your Cartfile:

```
github "groue/GRDB.swift" == 0.11.0
```

Before running `carthage update`, select Xcode-beta as the active developer directory by running the following command:

```
sudo xcode-select  -s /Applications/Xcode-beta.app
```


### Manually

Download a copy of GRDB.swift, embed the `GRDB.xcodeproj` project in your own project, and add the `GRDBOSX` or `GRDBiOS` target as a dependency of your own target.


Documentation
=============

To fiddle with the library, open the `GRDB.xcworkspace` workspace: it contains a GRDB-enabled Playground at the top of the files list.

**Reference**

- [GRDB Reference](http://cocoadocs.org/docsets/GRDB.swift/0.11.0/index.html) on cocoadocs.org

**Guides**

- SQLite API:
    
    - [Database Queues](#database-queues)
    - [Transactions](#transactions)
    - [Fetch Queries](#fetch-queries)
        - [Row Queries](#row-queries)
        - [Value Queries](#value-queries)
    - [Values](#values)
        - [NSDate and NSDateComponents](#nsdate-and-nsdatecomponents)
        - [Swift enums](#swift-enums)
        - [Custom Value Types](#custom-value-types)
    - [Prepared Statements](#prepared-statements)
    - [Error Handling](#error-handling)

- Application tools:
    
    - [Migrations](#migrations)
    - [Row Models](#row-models)
        - [Core Methods](#core-methods)
        - [Fetching Row Models](#fetching-row-models)
        - [Ad Hoc Subclasses](#ad-hoc-subclasses)
        - [Compound Properties](#compound-properties)
        - [Tables and Primary Keys](#tables-and-primary-keys)
        - [Insert, Update and Delete](#insert-update-and-delete)
        - [Preventing Useless UPDATE Statements](#preventing-useless-update-statements)
        - [RowModel Errors](#rowmodel-errors)
        - [Advice](#advice)


## Database Queues

You access SQLite databases through thread-safe database queues (inspired by [ccgus/fmdb](https://github.com/ccgus/fmdb)):

```swift
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
```

Configure databases:

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

To open an in-memory database, don't provide any path:

```swift
let inMemoryDBQueue = DatabaseQueue()
```

Database connections get closed when the database queue gets deallocated.

To create tables, we recommend using [migrations](#migrations).


## Transactions

**Transactions** wrap the queries that alter the database content:

```swift
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

A rollback statement is issued if an error is thrown from the transaction block.


## Fetch Queries

You can fetch **rows**, **values**, and **[row models](#row-models)**:

```swift
dbQueue.inDatabase { db in
    Row.fetch(db, "SELECT ...", arguments: ...)        // AnySequence<Row>
    Row.fetchAll(db, "SELECT ...", arguments: ...)     // [Row]
    Row.fetchOne(db, "SELECT ...", arguments: ...)     // Row?
    
    Int.fetch(db, "SELECT ...", arguments: ...)        // AnySequence<Int?>
    Int.fetchAll(db, "SELECT ...", arguments: ...)     // [Int?]
    Int.fetchOne(db, "SELECT ...", arguments: ...)     // Int?
    
    Person.fetch(db, "SELECT ...", arguments: ...)     // AnySequence<Person>
    Person.fetchAll(db, "SELECT ...", arguments: ...)  // [Person]
    Person.fetchOne(db, "SELECT ...", arguments: ...)  // Person?
}
```

- [Row Queries](#row-queries)
- [Value Queries](#value-queries)


### Row Queries

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

// Extract the desired Swift type from the column value:
let bookCount: Int = row.value(named: "bookCount")!
let bookCount64: Int64 = row.value(named: "bookCount")!
let hasBooks: Bool = row.value(named: "bookCount")!     // false when 0
```

**WARNING**: type casting requires a very careful use of the `as` operator (see [rdar://problem/21676393](http://openradar.appspot.com/radar?id=4951414862249984)):

```swift
row.value(named: "bookCount")! as Int   // OK: Int
row.value(named: "bookCount") as Int?   // OK: Int?
row.value(named: "bookCount") as! Int   // NO NO NO DON'T DO THAT!
row.value(named: "bookCount") as? Int   // NO NO NO DON'T DO THAT!
```

#### Rows as Dictionaries

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


### Value Queries

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

The `fetchOne(db,sql,arguments)` method returns an optional value which is nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value. If this ambiguity does not fit your need, use `Row.fetchOne()`.


## Values

The library ships with built-in support for `Bool`, `Int`, `Int32`, `Int64`, `Double`, `String`, `Blob`, [NSDate](#nsdate-and-nsdatecomponents), [NSDateComponents](#nsdate-and-nsdatecomponents), and [Swift enums](#swift-enums).

Custom value types are supported as well through the [DatabaseValueConvertible](#custom-value-types) protocol.


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

Support for NSDate is given by the **DatabaseDate** helper type.

DatabaseDate stores dates using the format "yyyy-MM-dd HH:mm:ss.SSS" in the UTC time zone.

> The storage format of DatabaseDate is lexically comparable with SQLite's CURRENT_TIMESTAMP, which means that your ORDER BY clauses will behave as expected.
>
> Of course, if this format does not fit your needs, feel free to create your own helper type: the [DatabaseValueConvertible](#custom-value-types) protocol is there to help you store dates as ISO-8601 strings, timestamp numbers, etc. We provide sample code for storing dates as timestamps [below](#custom-value-types).


Declare DATETIME columns in your tables:

```swift
try db.execute(
    "CREATE TABLE persons (" +
    "birthDate DATETIME, " +
    "creationDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP " +
    "...)")
```

Store NSDate into the database:

```swift
let birthDate = NSDate()
try db.execute("INSERT INTO persons (birthDate, ...) " +
                            "VALUES (?, ...)",
                         arguments: [DatabaseDate(birthDate), ...])
```

Extract NSDate from the database:

```swift
let row = Row.fetchOne(db, "SELECT birthDate, ...")!
let date = (row.value(named: "birthDate") as DatabaseDate?)?.date    // NSDate?

DatabaseDate.fetch(db, "SELECT ...")       // AnySequence<DatabaseDate?>
DatabaseDate.fetchAll(db, "SELECT ...")    // [DatabaseDate?]
DatabaseDate.fetchOne(db, "SELECT ...")    // DatabaseDate?
```

Use NSDate in a [Row Model](#row-models):

```swift
class Person : RowModel {
    var birthDate: NSDate?

    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["birthDate": DatabaseDate(birthDate), ...]
    }

    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "birthDate": birthDate = (dbv.value() as DatabaseDate?)?.date
        case ...
        default: super.setDatabaseValue(dbv, forColumn: column)
        }
    }
}
```


#### NSDateComponents

Support for NSDateComponents is given by the **DatabaseDateComponents** helper type.

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

Use NSDateComponents in a [Row Model](#row-models):

```swift
class Person : RowModel {
    var birthDateComponents: NSDateComponents?

    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        // Store birth date as YYYY-MM-DD:
        let dbComponents = DatabaseDateComponents(
            birthDateComponents,
            format: .YMD)
        return ["birthDate": dbComponents, ...]
    }

    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "birthDate":
            let dbComponents: DatabaseDateComponents? = dbv.value()
            birthDateComponents = dbComponents?.dateComponents
        case ...
        default: super.setDatabaseValue(dbv, forColumn: column)
        }
    }
}
```


### Swift Enums

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


### Custom Types

Conversion to and from the database is based on the `DatabaseValueConvertible` protocol:

```swift
public protocol DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Create an instance initialized to `databaseValue`.
    init?(databaseValue: DatabaseValue)
}
```

All types that adopt this protocol can be used wherever the built-in types `Int`, `String`, etc. are used. without any limitation or caveat.

> Unfortunately not all types can adopt this protocol: **Swift won't allow non-final classes to adopt DatabaseValueConvertible, and this prevents all our NSObject fellows to enter the game.**

As an example, let's write an alternative to the built-in [DatabaseDate](#nsdate-and-nsdatecomponents), and store dates as timestamps. DatabaseTimestamp applies all the best practices for a great GRDB.swift integration:

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
    
    /// Create an instance initialized to `databaseValue`.
    init?(databaseValue: DatabaseValue) {
        // Double itself adopts DatabaseValueConvertible. So let's avoid
        // handling the raw DatabaseValue, and use built-in Double conversion:
        guard let timeInterval = Double(databaseValue: databaseValue) else {
            return nil
        }
        self.init(NSDate(timeIntervalSince1970: timeInterval))
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


### Value Extraction in Details

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


## Prepared Statements

**Prepared Statements** can be reused.

Update statements:

```swift
try dbQueue.inTransaction { db in
    
    let sql = "INSERT INTO persons (name, age) VALUES (:name, :age)"
    let statement = try db.updateStatement(sql)
    
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

Select statements can fetch rows, values, and [Row Models](#row-models).

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


## Error Handling

**No SQLite error goes unnoticed.** Yet when such an error happens, some GRDB.swift functions throw a DatabaseError error, and some crash with a fatal error.

**The rule** is:

- All methods that *read* data crash.
- All methods that *write* data throw.

> Rationale: we assume that *all* reading errors are either SQL errors that the developer should fix (a syntax error, a wrong column name), or external I/O errors that are beyond repair and better hidden behind a crash. Write errors may be relational errors (violated unique index, missing reference) and you may want to handle relational errors yourselves.
>
> Please open an [issue](https://github.com/groue/GRDB.swift/issues) if you need fine tuning of select errors.

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

## Row Models

**RowModel** is a class that wraps a table row, or the result of any query. It is designed to be subclassed.

Let's first have a quick look at the RowModel API. RowModel can be **stored** or **deleted**:

```swift
class Person : RowModel { ... }
let person = Person(...)
try person.insert(db)   // INSERT INTO persons (...) VALUES (...)
try person.update(db)   // UPDATE persons SET ...
try person.save(db)     // inserts or updates
try person.delete(db)   // DELETE FROM persons WHERE ...
```

Database tables usually have a **primary key**, and eventually secondary keys:

```swift
person.exists(db)                   // true or false
try person.reload(db)               // SELECT * FROM persons WHERE ...
Person.fetchOne(db, primaryKey: 12) // Person?
Citizenship.fetchOne(db, key: ["personId": 12, "countryId": 45]) // Citizenship?
```

RowModels can be fetched from custom **SQL queries**...

```swift
Person.fetch(db, "SELECT ...", arguments: ...)      // AnySequence<Person>
Person.fetchAll(db, "SELECT ...", arguments: ...)   // [Person]
Person.fetchOne(db, "SELECT ...", arguments: ...)   // Person?
```

... or from **prepared statements**:

```swift
let statement = db.selectStatement("SELECT ...")
Person.fetch(statement, arguments: ...)             // AnySequence<Person>
Person.fetchAll(statement, arguments: ...)          // [Person]
Person.fetchOne(statement, arguments: ...)          // Person?
```

- [Core Methods](#core-methods)
- [Fetching Row Models](#fetching-row-models)
- [Ad Hoc Subclasses](#ad-hoc-subclasses)
- [Compound Properties](#compound-properties)
- [Tables and Primary Keys](#tables-and-primary-keys)
- [Insert, Update and Delete](#insert-update-and-delete)
- [Preventing Useless UPDATE Statements](#preventing-useless-update-statements)
- [RowModel Errors](#rowmodel-errors)
- [Advice](#advice)

### Core Methods

Subclasses opt in RowModel features by overriding all or part of the core methods that define their relationship with the database:

| Core Methods                     | fetch | insert | update | delete | reload |
|:-------------------------------- |:-----:|:------:|:------:|:------:|:------:|
| `setDatabaseValue(_:forColumn:)` |   ✓   |   ¹    |        |        |   ✓    |
| `databaseTable`                  |       |   ✓    |   ✓ ²  |   ✓ ²  |   ✓ ²  |
| `storedDatabaseDictionary`       |       |   ✓    |   ✓    |   ✓    |   ✓    |

¹ Insertion requires `setDatabaseValue(_:forColumn:)` when SQLite automatically generates row IDs.

² Update, delete & reload require a primary key.


### Fetching Row Models

The Person subclass below will be our guinea pig. It declares properties for the `persons` table:

```swift
class Person : RowModel {
    var id: Int64!            // matches "id" not null column
    var age: Int?             // matches "age" column
    var name: String?         // matches "name" column
}
```

The `setDatabaseValue(_:forColumn:)` method assigns database values to properties:

```swift
class Person : RowModel {
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "id":   id = dbv.value()    // Extract Int64!
        case "age":  age = dbv.value()   // Extract Int?
        case "name": name = dbv.value()  // Extract String?
        default:     super.setDatabaseValue(dbv, forColumn: column)
        }
    }
}
```

See [Rows as Dictionaries](#rows-as-dictionaries) for more information about the `DatabaseValue` type, and [Values](#values) about the supported property types.

Now you can fetch **lazy sequences** of row models, **arrays**, or **single** instances:

```swift

dbQueue.inDatabase { db in
    // With custom SQL:
    Person.fetch(db, "SELECT ...", arguments:...)    // AnySequence<Person>
    Person.fetchAll(db, "SELECT ...", arguments:...) // [Person]
    Person.fetchOne(db, "SELECT ...", arguments:...) // Person?
    
    // With a key dictionary:
    Person.fetchOne(db, key: ["id": 123])            // Person?
}
```

The `fetchOne(db,key)` method eats any key dictionary, and returns the first RowModel with matching values. Its result is undefined unless the dictionary is *actually* a key.

Lazy sequences can not be consumed outside of a database queue, but arrays are OK:

```swift
let persons = dbQueue.inDatabase { db in
    return Person.fetchAll(db, "SELECT ...")             // [Person]
    return Person.fetch(db, "SELECT ...").filter { ... } // [Person]
}
for person in persons { ... } // OK
```


### Ad Hoc Subclasses

Swift makes it very easy to create small and private types. This is a wonderful opportunity to create **ad hoc subclasses** that provide support for custom queries with extra columns.

We think that this is the killer feature of GRDB.swift :bowtie:. For example:

```swift
class PersonsViewController: UITableViewController {
    
    // Private subclass of Person, with an extra `bookCount` property:
    private class PersonViewModel : Person {
        var bookCount: Int!
        
        override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
            switch column {
            case "bookCount": bookCount = dbv.value()
            default: super.setDatabaseValue(dbv, forColumn: column)
            }
        }
    }
    
    var persons: [PersonViewModel]!
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        persons = dbQueue.inDatabase { db in
            PersonViewModel.fetchAll(db,
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


### Compound Properties

Some properties don't fit well in a single column:

```swift
class Placemark : RowModel {
    // Stored in two columns: latitude and longitude
    var coordinate: CLLocationCoordinate2D?
}
```

A solution is of course to declare two convenience properties, latitude and longitude, and implement coordinate on top of them, as a computed property. `setDatabaseValue()` would then update latitude and longitude separately:

```swift
// Solution 1: computed property:
class Placemark : RowModel {
    var latitude: CLLocationDegrees?
    var longitude: CLLocationDegrees?
    var coordinate: CLLocationCoordinate2D? {
        switch (latitude, longitude) {
        case (let latitude?, let longitude?):
            // Both latitude and longitude are not nil.
            return CLLocationCoordinate2DMake(latitude, longitude)
        default:
            return nil
        }
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "latitude": latitude = dbv.value()
        case "longitude": longitude = dbv.value()
        default: super.setDatabaseValue(dbv, forColumn: column)
        }
    }
}
```

Another solution is to override the `updateFromRow()` method, where you can process a row as a whole:

```swift
// Solution 2: process rows as a whole:
class Placemark : RowModel {
    var coordinate: CLLocationCoordinate2D?
    
    override func updateFromRow(row: Row) {
        if let latitude = row["latitude"], let longitude = row["longitude"] {
            // Both columns are present.
            switch (latitude.value() as Double?, longitude.value() as Double?) {
            case (let latitude?, let longitude?):
                // Both latitude and longitude are not nil.
                coordinate = CLLocationCoordinate2DMake(latitude, longitude)
            default:
                coordinate = nil
            }
        }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
}
```

The remaining columns are handled by `setDatabaseValue()` as described above.


### Tables and Primary Keys

Declare a **Table** given its **name** and **primary key** in order to fetch row models by ID:

```swift
class Person : RowModel {
    override class var databaseTable: Table? {
        return Table(named: "persons", primaryKey: .RowID("id"))
    }
}

try dbQueue.inDatabase { db in
    // Fetch
    let person = Person.fetchOne(db, primaryKey: 123)  // Person?
}
```

Primary key is not mandatory. But when there is a primary key, it is one of:

- **RowID**: use it when you rely on automatically generated IDs in an `INTEGER PRIMARY KEY` column. Beware RowModel does not support the implicit `ROWID` column (see https://www.sqlite.org/autoinc.html for more information).
    
- **Column**: for single-column primary keys that are not managed by SQLite.
    
- **Columns**: for primary keys that span accross several columns.
    
RowModels with a multi-column primary key are not supported by `fetchOne(db,primaryKey)`, which accepts a single value as a key. Instead, use `fetchOne(db,key)` that uses a dictionary.


### Insert, Update and Delete

With one more method, you get the `insert`, `update`, `delete` methods, plus the convenience `save` and `reload` methods.

```swift
class Person : RowModel {
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

Models that declare a `RowID` primary key have their id automatically set after successful insertion.

Other primary keys (single or multiple columns) are not managed by GRDB: you have to manage them yourself. You can for example override the `insert` primitive method, and make sure your primary key is set before calling `super.insert`.


### Preventing Useless UPDATE Statements

The `update()` method always executes an UPDATE statement. When the row model has not been edited, this database access is generally useless.

Avoid it with the `edited` property, which returns whether the row model has changes that have not been saved:

```swift
let json = ...
try dbQueue.inTransaction { db in
    // Fetches or create a new person given its ID:
    let person = Person.fetchOne(db, primaryKey: json["id"]) ?? Person()
    
    // Apply json payload:
    person.updateFromJSON(json)
                 
    // Saves the person if it is edited (fetched then modified, or created):
    if person.edited {
        person.save(db) // inserts or updates
    }
    
    return .Commit
}
```

Note that `edited` is based on value comparison: **setting a property to the same value does not set the edited flag**.


### RowModel Errors

RowModel methods can throw [DatabaseError](#error-handling) and also specific errors of type **RowModelError**:

- **RowModelError.RowModelNotFound**: thrown by `update` and `reload` when the primary key does not match any row in the database.


### Advice

**RowModel is not a smart class.** It is no replacement for Core Data. It does not provide any uniquing. It does not perform any SQL request behind your back. It has no knowledge of your database schema, and no notion of external references and model relationships.

Based on those facts, here are a few hints:

- [Autoincrement](#autoincrement)
- [Validation](#validation)
- [Default Values](#default-values)
- [INSERT OR REPLACE](#insert-or-replace)


#### Autoincrement

**For "autoincremented" ids**, declare your id column as INTEGER PRIMARY KEY, and declare a RowID primary key:

```sql
CREATE TABLE persons {
    id INTEGER PRIMARY KEY,
    ...
}
```

```swift
class Person : RowModel {
    id: Int64!
    
    /// The table definition.
    override class var databaseTable: Table? {
        return Table(named: "persons", primaryKey: .RowID("id"))
    }
    
    /// The values that should be stored in the database.
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, ...]
    }
    
    /// Updates `self` with a database value.
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "id": id = dbv.value()
        case ...
        default:   super.setDatabaseValue(dbv, forColumn: column)
        }
    }
}

let person = Person(...)
person.id   // nil
try person.insert(db)
person.id   // some value
```


#### Validation

RowModel does not provide any built-in validation.

You can use some external library such as [GRValidation](https://github.com/groue/GRValidation) in the update() and insert() methods:

```swift
class Person : RowModel, Validable {
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

**Avoid default values in table declarations.** RowModel doesn't know about them, and those default values won't be present in a row model after it has been inserted.
    
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
class Person : RowModel {
    override func insert(db: Database) throws {
        if creationDate == nil {
            creationDate = NSDate()
        }
        try super.insert(db)
    }
}
```


#### INSERT OR REPLACE

**RowModel does not provide any API which executes a INSERT OR REPLACE query.** Instead, consider adding an ON CONFLICT clause to your table definition, and let the simple insert() method perform the eventual replacement:

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
