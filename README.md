GRDB.swift
==========

GRDB.swift is an SQLite toolkit for Swift 2.

It provides an SQL API and application tools.

**February 11, 2016: GRDB.swift 0.45.1 is out** ([changelog](CHANGELOG.md)). Follow [@groue](http://twitter.com/groue) on Twitter for release announcements and usage tips.

**Requirements**: iOS 7.0+ / OSX 10.9+, Xcode 7+


### Usage

Open a connection to the [database](#database-queues):

```swift
import GRDB
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
```

Execute [SQL queries](#executing-updates):

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
    
    let parisId = try db.execute(
        "INSERT INTO pointOfInterests (title, favorite, latitude, longitude) " +
        "VALUES (?, ?, ?, ?)",
        arguments: ["Paris", true, 48.85341, 2.3488]).insertedRowID
    
    for row in Row.fetch(db, "SELECT * FROM pointOfInterests") {
        let title: String = row.value(named: "title")
        let favorite: Bool = row.value(named: "favorite")
        print(title, favorite)
    }
}
```

Insert and fetch [Records](#records):

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
    // INSERT INTO "pointOfInterests" ...
    var berlin = PointOfInterest(id: nil, title: "Berlin", favorite: false, coordinate: CLLocationCoordinate2DMake(52.52437, 13.41053))
    try berlin.insert(db)
    print(berlin.id)
    
    // UPDATE "pointOfInterests" ...
    berlin.favorite = true
    try berlin.update(db)
    
    // Fetch from SQL
    let pois = PointOfInterest.fetchAll(db, "SELECT * FROM pointOfInterests")
}
```

Turn Swift into SQL with the [query interface](#the-query-interface):

```swift
let title = SQLColumn("title")
let favorite = SQLColumn("favorite")

dbQueue.inDatabase { db in
    // SELECT * FROM "pointOfInterests" WHERE "title" = 'Paris'
    let paris = PointOfInterest.filter(title == "Paris").fetchOne(db)
    
    // SELECT * FROM "pointOfInterests" WHERE "favorite" ORDER BY "title"
    let favoritePois = PointOfInterest.filter(favorite).order(title).fetchAll(db)
}
```
  

### Documentation

- [GRDB Reference](http://cocoadocs.org/docsets/GRDB.swift/0.45.1/index.html) (on cocoadocs.org)
- [Installation](#installation)
- [SQLite API](#sqlite-api): SQL & SQLite
- [Records](#records): Fetching and persistence methods for your custom structs and class hierarchies.
- [Query Interface](#the-query-interface): A swift way to generate SQL.
- [Migrations](#migrations): Transform your database as your application evolves.
- [Database Changes Observation](#database-changes-observation): Perform post-commit and post-rollback actions.
- [Sample Code](#sample-code)


### Installation

#### iOS7

You can use GRDB in a project targetting iOS7. See [GRDBDemoiOS7](DemoApps/GRDBDemoiOS7) for more information.


#### CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Xcode projects.

To use GRDB with Cocoapods, specify in your Podfile:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

pod 'GRDB.swift', '~> 0.45.1'
```


#### Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency manager for Xcode projects.

To use GRDB with Carthage, specify in your Cartfile:

```
github "groue/GRDB.swift" ~> 0.45.1
```


#### Manually

1. Download a copy of GRDB.swift.
2. Embed the `GRDB.xcodeproj` project in your own project.
3. Add the `GRDBOSX` or `GRDBiOS` target in the **Target Dependencies** section of the **Build Phases** tab of your application target.
4. Add `GRDB.framework` to the **Embedded Binaries** section of the **General**  tab of your target.

See [GRDBDemoiOS](DemoApps/GRDBDemoiOS) for an example of such integration.


SQLite API
==========

**Overview**

```swift
import GRDB

// Open connection to database
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

try dbQueue.inDatabase { db in
    // Create tables
    try db.execute("CREATE TABLE wines (...)")
    
    // Insert
    let wineId = try db.execute("INSERT INTO wines (color, name) VALUES (?, ?)",
        arguments: [Color.Red, "Pomerol"]).insertedRowID
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

- [Database Queues](#database-queues)
- [Executing Updates](#executing-updates)
- [Fetch Queries](#fetch-queries)
    - [Row Queries](#row-queries)
    - [Value Queries](#value-queries)
- [Values](#values)
    - [NSData](#nsdata-and-memory-savings)
    - [NSDate and NSDateComponents](#nsdate-and-nsdatecomponents)
    - [NSNumber and NSDecimalNumber](#nsnumber-and-nsdecimalnumber)
    - [Swift enums](#swift-enums)
- [String Comparison](#string-comparison)
- [Transactions](#transactions)
- [Error Handling](#error-handling)
- Advanced topics:
    - [Custom Value Types](#custom-value-types)
    - [Prepared Statements](#prepared-statements)
    - [Concurrency](#concurrency)
    - [Custom SQL Functions](#custom-sql-functions)
    - [Raw SQLite Pointers](#raw-sqlite-pointers)


## Database Queues

You access SQLite databases through **database queues** (inspired by [ccgus/fmdb](https://github.com/ccgus/fmdb)):

```swift
import GRDB

let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let inMemoryDBQueue = DatabaseQueue()
```

SQLite creates the database file if it does not already exist. The connection is closed when the database queue gets deallocated.

**A database queue can be used from any thread.** The `inDatabase` and `inTransaction` methods block the current thread until your database statements are executed:

```swift
// Execute database statements:
dbQueue.inDatabase { db in
    for row in Row.fetch(db, "SELECT * FROM wines") {
        let name: String = row.value(named: "name")
        let color: Color = row.value(named: "color")
        print(name, color)
    }
}

// Wrap database statements in a transaction:
try dbQueue.inTransaction { db in
    try db.execute("INSERT ...")
    try db.execute("DELETE FROM ...")
    return .Commit
}

// Extract values from the database:
let wineCount = dbQueue.inDatabase { db in
    Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
}
print(wineCount)
```


**You can configure databases:**

```swift
var config = Configuration()
config.readonly = true
config.foreignKeysEnabled = true // The default is already true
config.trace = { print($0) }     // Prints all SQL statements

let dbQueue = try DatabaseQueue(
    path: "/path/to/database.sqlite",
    configuration: config)
```

See [Configuration](http://cocoadocs.org/docsets/GRDB.swift/0.45.1/Structs/Configuration.html) and [Concurrency](#concurrency) for more details.

> :bowtie: **Tip**: see [DemoApps/GRDBDemoiOS/Database.swift](DemoApps/GRDBDemoiOS/GRDBDemoiOS/Database.swift) for a sample code that sets up a GRDB database.


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
        "INSERT INTO persons (name, age) VALUES (:name, :age)",
        arguments: ["name": "Barbara", "age": 39])
    
    // Join multiple statements with a semicolon:
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (?, ?); " +
        "INSERT INTO persons (name, age) VALUES (?, ?)",
        arguments: ["Arthur", 36, "Barbara", 39])
}
```

The `?` and colon-prefixed keys like `:name` in the SQL query are the **statements arguments**. You pass arguments in with arrays or dictionaries, as in the example above. See [Values](#values) for more information on supported arguments types (Bool, Int, String, NSDate, Swift enums, etc.).

**After an INSERT statement**, you extract the inserted Row ID from the result of the `execute` method:

```swift
let personID = try db.execute(
    "INSERT INTO persons (name, age) VALUES (?, ?)",
    arguments: ["Arthur", 36]).insertedRowID
```

Don't miss [Records](#records), that provide classic **persistence methods**:

```swift
let person = Person(name: "Arthur", age: 36)
try person.insert(db)
print("Inserted \(person.id)")
```


## Fetch Queries

You can fetch database rows, plain values, and custom models aka "records".

**Rows** are the raw results of SQL queries:

```swift
dbQueue.inDatabase { db in
    for row in Row.fetch(db, "SELECT * FROM wines") {
        let name: String = row.value(named: "name")
        let color: Color = row.value(named: "color")
    }
}
```


**Values** are the Bool, Int, String, NSDate, Swift enums, etc. stored in row columns:

```swift
dbQueue.inDatabase { db in
    let wineCount = Int.fetchOne(db, "SELECT COUNT(*) FROM wines")! // Int
    let urls = NSURL.fetchAll(db, "SELECT url FROM wines")          // [NSURL]
}
```


**Records** are your application objects that can initialize themselves from rows:

```swift
dbQueue.inDatabase { db in
    let wines = Wine.fetchAll(db,                                   // [Wine]
        "SELECT * FROM wines WHERE origin = ? ORDER BY price",
        arguments: ["Burgundy"])
    let favoriteWine = Wine.fetchOne(db, key: favoriteWineID)       // Wine?
}
```

- [Fetching Methods](#fetching-methods)
- [Row Queries](#row-queries)
- [Value Queries](#value-queries)
- [Records](#records)


### Fetching Methods

**Throughout GRDB**, values can always be fetched as a *sequence*, as an *array*, or as a *single value*:

```swift
Value.fetch(...)    // DatabaseSequence<Value>
Value.fetchAll(...) // [Value]
Value.fetchOne(...) // Value?
```

- `fetch` returns a sequence that is memory efficient, but must be consumed in the database queue (you'll get a fatal error if you do otherwise). The sequence fetches a new set of results each time it is iterated.
- `fetchAll` performs a single request, and returns an array that can be iterated on any thread. It can take a lot of memory.
- `fetchOne` consumes a single database row, if any is available.


### Row Queries

- [Fetching Rows](#fetching-rows)
- [Column Values](#column-values)
- [Rows as Dictionaries](#rows-as-dictionaries)


#### Fetching Rows

Fetch **sequences** of rows, **arrays**, or **single** rows (see [fetching methods](#fetching-methods)):

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
    
    Notably, NULL won't turn to anything:
    
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

- **The convenience conversions of SQLite, such as Blob to String, String to Int, or huge Double values to Int, are not guaranteed to apply.** You must not rely on them.


#### Rows as Dictionaries

**Rows can be seen as dictionaries** of `DatabaseValue`, an intermediate type between SQLite and your values:

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


**You can build rows from scratch** using the dictionary and NSDictionary initializers (see [Values](#values) for more information on supported types):

```swift
let row = Row(["name": "foo", "date": nil])
```


**Rows are standard [collections](https://developer.apple.com/library/ios/documentation/Swift/Reference/Swift_CollectionType_Protocol/index.html)**:

```swift
// the number of columns
row.count

// All the (columnName, databaseValue) tuples, from left to right:
for (columnName, databaseValue) in row {
    ...
}
```


**Rows may contain duplicate keys**:

```swift
let row = Row.fetchOne(db, "SELECT 1 AS foo, 2 AS foo")!
row.columnNames     // ["foo", "foo"]
row.databaseValues  // [1, 2]
row["foo"]          // 1 (the value for the leftmost column "foo")
for (columnName, databaseValue) in row { ... } // ("foo", 1), ("foo", 2)
```


### Value Queries

Instead of rows, you can directly fetch **[values](#values)**. Like rows, fetch them as **sequences**, **arrays**, or **single** values (see [fetching methods](#fetching-methods)). Values are extracted from the leftmost column of the SQL queries:

```swift
dbQueue.inDatabase { db in
    Int.fetch(db, "SELECT ...", arguments: ...)     // DatabaseSequence<Int>
    Int.fetchAll(db, "SELECT ...", arguments: ...)  // [Int]
    Int.fetchOne(db, "SELECT ...", arguments: ...)  // Int?

    // When database may contain NULL:
    Optional<Int>.fetch(db, "SELECT ...", arguments: ...)    // DatabaseSequence<Int?>
    Optional<Int>.fetchAll(db, "SELECT ...", arguments: ...) // [Int?]
}
```

`fetchOne` returns an optional value which is nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value.

There are many supported value types (Bool, Int, String, NSDate, Swift enums, etc.). See [Values](#values) for more information:

```swift
dbQueue.inDatabase { db in
    // The number of persons with an email ending in @example.com:
    let count: Int = Int.fetchOne(db,
        "SELECT COUNT(*) FROM persons WHERE email LIKE ?",
        arguments: ["%@example.com"])!
    
    // All URLs:
    let urls: [NSURL] = NSURL.fetchAll(db, "SELECT url FROM links")
    
    // The emails of people who own at least two pets:
    let emails: [String?] = Optional<String>.fetchAll(db,
        "SELECT persons.email " +
        "FROM persons " +
        "JOIN pets ON pets.masterId = persons.id " +
        "GROUP BY persons.id " +
        "HAVING COUNT(pets.id) >= 2")
}
```


## Values

GRDB ships with built-in support for the following value types:

- **Swift Standard Library**: Bool, Double, Float, Int, Int32, Int64, String, [Swift enums](#swift-enums).
    
- **Foundation**: [NSData](#nsdata-and-memory-savings), [NSDate](#nsdate-and-nsdatecomponents), [NSDateComponents](#nsdate-and-nsdatecomponents), NSNull, [NSNumber](#nsnumber-and-nsdecimalnumber), NSString, NSURL.
    
- **CoreGraphics**: CGFloat.

All types that adopt the [DatabaseValueConvertible](#custom-value-types) protocol are supported.

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

Values can be [directly fetched](#value-queries) from the database:

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
let url = NSURL(string: "http://example.com")!
let link = Link.filter(Col.url == url).fetchOne(db)
let urlCount = Int.fetchOne(db, Link.select(count(distinct: Col.url)))!
```


### NSData (and Memory Savings)

**NSData** suits the BLOB SQLite columns. It can be stored and fetched from the database just like other [value types](#values).

Yet, when extracting NSData from a row, **you have the opportunity to save memory by not copying the data fetched by SQLite**, using the `dataNoCopy()` method:

```swift
for row in Row.fetch(db, "SELECT data, ...") {
    let data = row.dataNoCopy(named: "data")     // NSData?
}
```

> :point_up: **Note**: The non-copied data does not live longer than the iteration step: make sure that you do not use it past this point.

Compare with the **anti-patterns** below:

```swift
for row in Row.fetch(db, "SELECT data, ...") {
    // This data is copied:
    let data: NSData = row.value(named: "data")
    
    // This data is copied:
    if let databaseValue = row["data"] {
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
try db.execute("INSERT INTO persons (creationDate, ...) " +
                            "VALUES (?, ...)",
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
try db.execute("INSERT INTO persons (birthDate, ...) " +
                            "VALUES (?, ...)",
                         arguments: [dbComponents, ...])

// Read "1973-09-18"
let row = Row.fetchOne(db, "SELECT birthDate ...")!
let dbComponents: DatabaseDateComponents = row.value(named: "birthDate")
dbComponents.format         // .YMD (the actual format found in the database)
dbComponents.dateComponents // NSDateComponents
```


### NSNumber and NSDecimalNumber

While NSNumber deserves no special discussion, NSDecimalNumber does.

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
let amount = NSDecimalNumber(string: "0.1")
let integerAmount = amount
    .decimalNumberByMultiplyingByPowerOf10(2)
    .longLongValue
// INSERT INTO transfers (amount) VALUES (100)
try db.execute("INSERT INTO transfers (amount) VALUES (?)", arguments: [integerAmount])

// Read
let integerAmount = Int64.fetchOne(db, "SELECT SUM(amount) FROM transfers")!
let amount = NSDecimalNumber(longLong: integerAmount)
    .decimalNumberByMultiplyingByPowerOf10(-2)
```


### Swift Enums

**Swift enums** get full support from GRDB as long as their raw values are Int, Int32, Int64 or String:

```swift
enum Color : Int {
    case Red, White, Rose
}

enum Grape : String {
    case Chardonnay, Merlot, Riesling
}
```

Add conformance to a protocol, and the enum type can be stored and fetched from the database just like other [value types](#values):

```swift
extension Color : DatabaseIntRepresentable { } // DatabaseInt32Representable for Int32, DatabaseInt64Representable for Int64
extension Grape : DatabaseStringRepresentable { }

// Store
try db.execute("INSERT INTO wines (grape, color) VALUES (?, ?)",
               arguments: [Grape.Merlot, Color.Red])

// Read
for rows in Row.fetch(db, "SELECT * FROM wines") {
    let grape: Grape = row.value(named: "grape")
    let color: Color = row.value(named: "color")
}
```

Database values that do not match any enum case are extracted as nil:

```swift
let row = Row.fetchOne(db, "SELECT 'Syrah'")!
row.value(atIndex: 0) as String  // "Syrah"
row.value(atIndex: 0) as Grape?  // nil
row.value(atIndex: 0) as Grape   // fatal error: could not convert "Syrah" to Grape.
```


## String Comparison

SQLite compares strings in many occasions: when you sort rows according to a string column, or when you use a comparison operator such as `=` and `<=`.

The comparison result comes from a *collating function*, or *collation*. SQLite comes with [three built-in collations](https://www.sqlite.org/datatype3.html#collation):

- `binary`, the default, which considers "Foo" and "foo" to be inequal, and "Jérôme" and "Jerome" to be inequal because it has no Unicode support.
- `nocase`, which considers "Foo" and "foo" to be equal, but "Jérôme" and "Jerome" to be inequal because it has no Unicode support.
- `rtrim`: the same as `binary`, except that trailing space characters are ignored.

**You can define your own collations**, based on the rich set of Swift string comparisons:

```swift
let collation = DatabaseCollation("localized_case_insensitive") { (lhs, rhs) in
    return (lhs as NSString).localizedCaseInsensitiveCompare(rhs)
}

dbQueue.inDatabase { db in
    db.addCollation(collation)
}
```

Once defined, the custom collation can be applied to a table column. All comparisons involving this column will automatically trigger your comparison function:
    
```swift
dbQueue.inDatabase { db in
    // Apply the custom collation to the `name` column
    try db.execute(
        "CREATE TABLE persons (" +
            "name TEXT COLLATE localized_case_insensitive" + // The name of the collation
        ")")
    
    // Persons are sorted as expected:
    let persons = Person.order(name).fetchAll(db)
    
    // Matches "Jérôme", "jerome", etc.
    let persons = Person.filter(name == "Jérôme").fetchAll(db)
}
```

If you can't or don't want to define the comparison behavior of a column, you can still use an explicit collation on particular requests:

```swift
// SELECT * FROM "persons" WHERE ("name" = 'foo' COLLATE NOCASE)
let persons = Person.filter(name.collating("NOCASE") == "foo").fetchAll(db)

// SELECT * FROM "persons" WHERE ("name" = 'Jérôme' COLLATE localized_case_insensitive)
let persons = Person.filter(name.collating(collation) == "Jérôme").fetchAll(db)
```

See the [query interface](#the-query-interface) for more information.


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

If you want to insert a transaction between other database statements, and group those in a single block of code protected by the database queue, you can use the Database.inTransaction() function:

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

**No SQLite error goes unnoticed.**

When an [SQLite error](https://www.sqlite.org/rescode.html) happens, some GRDB functions throw a DatabaseError, and some crash with a fatal error:

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


**Fatal errors can be avoided.** For example, let's consider the code below:

```swift
let sql = "..."
let arguments: NSDictionary = ...
let rows = Row.fetchAll(db, sql, arguments: StatementArguments(arguments))
```

It has many opportunities to fail:

- The sql string may contain invalid sql, or refer to non-existing tables or columns.
- The arguments dictionary may contain unsuitable values.
- The arguments dictionary may miss values required by the statement.

Compare with the safe version:

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

The `databaseValue` property returns [DatabaseValue](GRDB/Core/DatabaseValue.swift), a type that wraps the five types supported by SQLite: NULL, Int64, Double, String and NSData. DatabaseValue has no public initializer: to create one, use `DatabaseValue.Null`, or another type that already adopts the protocol: `1.databaseValue`, `"foo".databaseValue`, etc.

The `fromDatabaseValue()` factory method returns an instance of your custom type, if the databaseValue contains a suitable value.

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

Select statements can be used wherever a raw SQL query would fit (see [fetch queries](#fetch-queries)):

```swift
Row.fetch(statement, arguments: ...)        // DatabaseSequence<Row>
Row.fetchAll(statement, arguments: ...)     // [Row]
Row.fetchOne(statement, arguments: ...)     // Row?

String.fetch(statement, arguments: ...)     // DatabaseSequence<String>
String.fetchAll(statement, arguments: ...)  // [String]
String.fetchOne(statement, arguments: ...)  // String?

Optional<String>.fetch(statement, arguments: ...)    // DatabaseSequence<String?>
Optional<String>.fetchAll(statement, arguments: ...) // [String?]

Person.fetch(statement, arguments: ...)     // DatabaseSequence<Person>
Person.fetchAll(statement, arguments: ...)  // [Person]
Person.fetchOne(statement, arguments: ...)  // Person?
```

See [row queries](#row-queries), [value queries](#value-queries), and [Records](#records) for more information.


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
    let unicodeUpper = DatabaseFunction(
        "unicodeUpper",   // The name of the function
        argumentCount: 1, // Number of arguments
        pure: true,       // True means that the result only depends on input
        function: { (databaseValues: [DatabaseValue]) in
            guard let string: String = databaseValues[0].value() else {
                return nil
            }
            return string.uppercaseString })
    
    db.addFunction(unicodeUpper)
    
    // "JÉRÔME"
    String.fetchOne(db, "SELECT unicodeUpper(?)", arguments: ["Jérôme"])!
    
    // "JéRôME"
    String.fetchOne(db, "SELECT upper(?)", arguments: ["Jérôme"])!
}
```

The *function* argument takes an array of [DatabaseValue](#rows-as-dictionaries), and returns any valid [value](#values) (Bool, Int, String, NSDate, Swift enums, etc.) The number of database values is guaranteed to be *argumentCount*.

SQLite has the opportunity to perform additional optimizations when functions are "pure", which means that their result only depends on their arguments. So make sure to set the *pure* argument to true when possible.


**Functions can take a variable number of arguments:**

When you don't provide any explicit *argumentCount*, the function can take any number of arguments:

```swift
dbQueue.inDatabase { db in
    let averageOf = DatabaseFunction("averageOf", pure: true) { (databaseValues: [DatabaseValue]) in
        let doubles: [Double] = databaseValues.flatMap { $0.value() }
        return doubles.reduce(0, combine: +) / Double(doubles.count)
    }
    db.addFunction(averageOf)
    
    // 2.0
    Double.fetchOne(db, "SELECT averageOf(1, 2, 3)")!
}
```


**Functions can throw:**

```swift
dbQueue.inDatabase { db in
    let sqrt = DatabaseFunction("sqrt", argumentCount: 1, pure: true) { (databaseValues: [DatabaseValue]) in
        let dbv = databaseValues[0]
        guard let double: Double = dbv.value() else {
            return nil
        }
        guard double >= 0.0 else {
            throw DatabaseError(message: "Invalid negative value in function sqrt()")
        }
        return sqrt(double)
    }
    db.addFunction(sqrt)
    
    // fatal error: SQLite error 1 with statement `SELECT sqrt(-1)`:
    // Invalid negative value in function sqrt()
    Double.fetchOne(db, "SELECT sqrt(-1)")
}
```

See [error handling](#error-handling) for more information on database errors.


**Use custom functions in the [query interface](#the-query-interface):**

```swift
// SELECT unicodeUpper("name") AS "uppercaseName" FROM persons
Person.select(unicodeUpper.apply(Col.name).aliased("uppercaseName"))
```


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
> - SQLite connections are opened in the [multi-thread mode](https://www.sqlite.org/threadsafe.html), which means that **they are not thread-safe**. Make sure you touch raw databases and statements inside the database queues.

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
- Custom collations (see [String Comparison](#string-comparison))
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

- [Records](#records): Fetching and persistence methods for your custom structs and class hierarchies.
- [Query Interface](#the-query-interface): A swift way to generate SQL.
- [Migrations](#migrations): Transform your database as your application evolves.
- [Database Changes Observation](#database-changes-observation): Perform post-commit and post-rollback actions.


## Records

**On top of the [SQLite API](#sqlite-api), GRDB provides protocols and a class** that help manipulating database rows as regular objects named "records".

Your custom structs and classes can adopt each protocol individually, and opt in to focused sets of features. Or you can subclass the `Record` class, and get the full toolkit in one go: fetching methods, persistence methods, and changes tracking.


#### Inserting Records

To insert a record in the database, subclass the [Record](#record-class) class or adopt the [Persistable](#persistable-protocol) protocol, and call the `insert` method:

```swift
class Person : Record { ... }

let person = Person(name: "Arthur", email: "arthur@example.com")
try dbQueue.inDatabase { db in
    try person.insert(db)
}
```

Of course, you need to open a [database connection](#database-queues), and [create a database table](#executing-updates) first.


#### Fetching Records

[Record](#record-class) subclasses and types that adopt the [RowConvertible](#rowconvertible-protocol) protocol can be fetched from the database:

```swift
class Person : Record { ... }

dbQueue.inDatabase { db in
    // Using the query interface
    let persons = Person.filter(email != nil).order(name).fetchAll(db)
    
    // By key
    let person = Person.fetchOne(db, key: 1)
    
    // Using SQL
    let persons = Person.fetchAll(db, "SELECT ...", arguments: ...)
}
```

To learn more about querying records, check the [query interface](#the-query-interface).


#### Updating Records

[Record](#record-class) subclasses and types that adopt the [Persistable](#persistable-protocol) protocol can be updated in the database:

```swift
try dbQueue.inDatabase { db in
    let person = Person.fetchOne(db, key: 1)!
    person.name = "Arthur"
    try person.update(db)
}
```

[Record](#record-class) subclasses track changes:

```swift
try dbQueue.inDatabase { db in
    let person = Person.fetchOne(db, key: 1)!
    person.name = "Arthur"
    if person.hasPersistentChangedValues {
        try person.update(db)
    }
}
```

For batch updates, you have to execute an [SQL query](#executing-updates):

```swift
try dbQueue.inDatabase { db in
    try db.execute("UPDATE persons SET synchronized = 1")
}
```


#### Deleting Records

[Record](#record-class) subclasses and types that adopt the [Persistable](#persistable-protocol) protocol can be deleted from the database:

```swift
try dbQueue.inDatabase { db in
    let person = Person.fetchOne(db, key: 1)!
    try person.delete(db)
}
```

For batch deletions, you have to execute an [SQL query](#executing-updates):

```swift
try dbQueue.inDatabase { db in
    try db.execute("DELETE FROM persons")
}
```


#### Counting Records

[Record](#record-class) subclasses and types that adopt the [TableMapping](#tablemapping-protocol) protocol can be counted:

```swift
let personWithEmailCount = dbQueue.inDatabase { db in
    Person.filter(email != nil).fetchCount(db)  // Int
}
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
    mutating func awakeFromFetch(row row: Row, database: Database)
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
    init(_ row: Row){
        id = row.value(named: "id")
        title = row.value(named: "title")
        coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),
            row.value(named: "longitude"))
    }
}
```

See [column values](#column-values) for more information about the `row.value()` method.

> :point_up: **Note**: For performance reasons, the same row argument to `init(_:Row)` is reused during the iteration of a fetch query. If you want to keep the row for later use, make sure to store a copy: `self.row = row.copy()`.

RowConvertible allows adopting types to be fetched from SQL queries:

```swift
PointOfInterest.fetch(db, "SELECT ...", arguments:...)    // DatabaseSequence<PointOfInterest>
PointOfInterest.fetchAll(db, "SELECT ...", arguments:...) // [PointOfInterest]
PointOfInterest.fetchOne(db, "SELECT ...", arguments:...) // PointOfInterest?
```

See [fetching methods](#fetching-methods) for information about the `fetch`, `fetchAll` and `fetchOne` methods. See [fetching rows](#fetching-rows) for more information about the query arguments.


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

Adopting types can be fetched using the [query interface](#the-query-interface):

```swift
let paris = dbQueue.inDatabase { db in
    PointOfInterest.filter(name == "Paris").fetchOne(db)?
}
```

You can also fetch records according to their primary key (see [fetching methods](#fetching-methods)):

```swift
PointOfInterest.fetch(db, keys: ...)    // DatabaseSequence<PointOfInterest>
PointOfInterest.fetchAll(db, keys: ...) // [PointOfInterest]
PointOfInterest.fetchOne(db, key: ...)  // PointOfInterest?
```

Any single-column primary key is OK:

```swift
// SELECT * FROM pointOfInterests WHERE id IN (1, 2, 3)
PointOfInterest.fetchAll(db, keys: [1, 2, 3])

// SELECT * FROM pointOfInterests WHERE id = 1
PointOfInterest.fetchOne(db, key: 1)

// SELECT * FROM countries WHERE isoCode = 'FR'
Country.fetchOne(db, key: "FR")
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

- *If your type is a struct that mutates on insertion*, choose `MutablePersistable`. For example, your table has an INTEGER PRIMARY KEY and you want to store the inserted id on successful insertion. Or your table has a UUID primary key, and you want to automatically generate one on insertion.
- Otherwise, stick with `Persistable`. Particularly if your type is a class.

The `persistentDictionary` property returns a dictionary whose keys are column names, and values any DatabaseValueConvertible value (Bool, Int, String, NSDate, Swift enums, etc.) See [Values](#values) for more information.

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

try dbQueue.inDatabase { db in
    try paris.insert(db)
    paris.id   // some value
}
```


#### Persistence Methods

[Record](#record-class) subclasses and types that adopt [Persistable](#persistable-protocol) are given default implementations for methods that insert, update, and delete:

```swift
try object.insert(db) // INSERT
try object.update(db) // UPDATE
try object.save(db)   // Inserts or updates
try object.delete(db) // DELETE
object.exists(db)     // Bool
```

- `insert`, `update`, `save` and `delete` can throw a [DatabaseError](#error-handling) whenever an SQLite integrity check fails.

- `update` can also throw a PersistenceError of type NotFound, should the update fail because there is no matching row in the database.
    
    When saving an object that may or may not already exist in the database, prefer the `save` method: it performs the UPDATE or INSERT statement that makes sure your values are saved in the database.

- `delete` returns whether a database row was deleted or not.


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

> :point_up: **Note**: The special methods `performInsert`, `performUpdate`, etc. are reserved for your custom implementations. Do not use them elsewhere. Do not provide another implementation for those methods.
>
> :point_up: **Note**: It is recommended that you do not implement your own version of the `save` method. Its default implementation forwards the job to `update` or `insert`: these are the methods that may need customization, not `save`.


### Record Class

**Record** is a class that builds on top of the [RowConvertible](#rowconvertible-protocol), [TableMapping](#tablemapping-protocol) and [Persistable](#persistable-protocol) protocols, and is designed to be subclassed.

It provides [persistence methods](#persistence-methods), [changes tracking](#changes-tracking), and the [query interface](#the-query-interface).

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
    func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
    }
}
```


**Insert records** (see [persistence methods](#persistence-methods)):

```swift
let poi = PointOfInterest(...)
try dbQueue.inDatabase { db in
    try poi.insert(db)
}
```


**Fetch records** (see [RowConvertible](#rowconvertible-protocol) and the [query interface](#the-query-interface)):

```swift
dbQueue.inDatabase { db in
    // Using the query interface
    let pois = PointOfInterest.order(title).fetchAll(db)
    
    // By key
    let poi = PointOfInterest.fetchOne(db, key: 1)
    
    // Using SQL
    let pois = PointOfInterest.fetchAll(db, "SELECT ...", arguments: ...)
}
```


**Update records** (see [persistence methods](#persistence-methods)):

```swift
try dbQueue.inDatabase { db in
    let poi = PointOfInterest.fetchOne(db, key: 1)!
    poi.coordinate = ...
    try poi.update(db)
}
```


**Delete records** (see [persistence methods](#persistence-methods)):

```swift
try dbQueue.inDatabase { db in
    let poi = PointOfInterest.fetchOne(db, key: 1)!
    try poi.delete(db)
}
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

The `hasPersistentChangedValues` flag is false after a record has been fetched or saved into the database. Subsequent modifications may set it: `hasPersistentChangedValues` is based on value comparison. **Setting a property to the same value does not set the changed flag**:

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
let wines = Wine.filter(origin == "Burgundy").order(price).fetchAll(db)
```

Please bear in mind that the query interface can not generate all possible SQL queries. You may also *prefer* writing SQL:

```swift
let wines = Wine.fetchAll(db,
    "SELECT * FROM wines WHERE origin = ? ORDER BY price",
    arguments: ["Burgundy"])
```

So don't miss the [SQL API](#fetch-queries).

- [Requests](#requests)
- [Expressions](#expressions)
    - [SQL Operators](#sql-operators)
    - [SQL Functions](#sql-functions)
- [Fetching from Requests](#fetching-from-requests)
- [Fetching Aggregated Values](#fetching-aggregated-values)


### Requests

Everything starts from **a type** that adopts the `TableMapping` protocol, such as a `Record` subclass (see [Records](#records)):

```swift
class Person: Record {
    static func databaseTableName() -> String {
        return "persons"
    }
}
```

Declare the table **columns** that you want to use for filtering, or sorting:

```swift
let id = SQLColumn("id")
let name = SQLColumn("name")
```

> :bowtie: **Tip**: you don't want to lock a variable such as `name` for GRDB's fancy API, do you? My own practice is to declare a dedicated `Col` struct as below (see example [declaration](DemoApps/GRDBDemoiOS/GRDBDemoiOS/Database.swift#L3-L11) and [usage](DemoApps/GRDBDemoiOS/GRDBDemoiOS/MasterViewController.swift#L25-L29)):
>
> ```swift
> struct Col {
>    static let id = SQLColumn("id")
>    static let name = SQLColumn("name")
> }
> ```

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
    Person.select(Col.id, Col.name)
    
    // SELECT UPPER("name") FROM "persons"
    Person.select(Col.name.uppercaseString)
    
    // SELECT UPPER("name") AS "uppercaseName" FROM "persons"
    Person.select(Col.name.uppercaseString.aliased("uppercaseName"))
    ```

- `distinct` performs uniquing:
    
    ```swift
    // SELECT DISTINCT "name" FROM "persons"
    Person.select(Col.name).distinct
    ```

- `filter(expression)` applies conditions.
    
    ```swift
    // SELECT * FROM "persons" WHERE ("id" IN (1, 2, 3))
    Person.filter([1,2,3].contains(Col.id))
    
    // SELECT * FROM "persons" WHERE (("name" IS NOT NULL) AND ("height" > 1.75))
    Person.filter(Col.name != nil && Col.height > 1.75)
    ```

- `group(expression, ...)` groups rows.
    
    ```swift
    // SELECT "name", MAX("age") FROM "persons" GROUP BY "name"
    Person
        .select(Col.name, max(Col.age))
        .group(Col.name)
    ```

- `having(expression)` applies conditions on grouped rows.
    
    ```swift
    // SELECT "name", MAX("age") FROM "persons" GROUP BY "name" HAVING MIN("age") >= 18
    Person
        .select(Col.name, max(Col.age))
        .group(Col.name)
        .having(min(Col.age) >= 18)
    ```

- `order(sortDescriptor, ...)` sorts.
    
    ```swift
    // SELECT * FROM "persons" ORDER BY "name"
    Person.order(Col.name)
    
    // SELECT * FROM "persons" ORDER BY UPPER("name") DESC, "email" ASC
    Person.order(Col.name.uppercaseString.desc, Col.email.asc)
    ```

- `reverse()` reverses the eventual sort descriptors.
    
    ```swift
    // SELECT * FROM "persons" ORDER BY "name" DESC
    Person.order(Col.name).reverse()

    // SELECT * FROM "persons" ORDER BY UPPER("name") ASC, "email" DESC
    Person.order(Col.name.uppercaseString.desc, Col.email.asc)reverse()
    ```
    
    If no ordering was specified, the result is ordered by the primary key in reverse order.
    
    ```swift
    // SELECT * FROM "persons" ORDER BY "id" DESC
    Person.all().reverse()
    ```

- `limit(limit, offset: offset)` limits and pages results.
    
    ```swift
    // SELECT * FROM "persons" LIMIT 5
    Person.limit(5)
    
    // SELECT * FROM "persons" LIMIT 5 OFFSET 10
    Person.limit(5, offset: 10)
    ```

You can refine requests by chaining those methods, in any order.

```swift
// SELECT * FROM "persons" WHERE ("email" IS NOT NULL) ORDER BY "name"
Person.order(Col.name).filter(Col.email != nil)
```

The `select`, `group` and `limit` methods ignore and replace previously applied selection, grouping and limits. On the opposite, `filter`, `having`, and `order` methods extend the query:

```swift
Person                          // SELECT * FROM "persons"
    .filter(Col.name != nil)    // WHERE (("name" IS NOT NULL)
    .filter(Col.email != nil)   //        AND ("email IS NOT NULL"))
    .order(Col.name)            // ORDER BY "name"
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
    Person.filter(Col.name == "Arthur")
    
    // SELECT * FROM "persons" WHERE ("name" IS NULL)
    Person.filter(Col.name == nil)
    
    // SELECT * FROM "persons" WHERE ("age" <> 18)
    Person.filter(Col.age != 18)
    
    // SELECT * FROM "persons" WHERE ("age" IS NOT 18)
    Person.filter(Col.age !== 18)
    
    // SELECT * FROM "rectangles" WHERE ("width" < "height")
    Rectangle.filter(Col.width < Col.height)
    ```
    
    > :point_up: **Note**: SQLite string comparison, by default, is case-sensitive and not Unicode-aware. See [string comparison](#string-comparison) if you need more control.
    

- `*`, `/`, `+`, `-`
    
    SQLite arithmetic operators are derived from their Swift equivalent:
    
    ```swift
    // SELECT (("temperature" * 1.8) + 32) AS "farenheit" FROM "persons"
    Planet.select((Col.temperature * 1.8 + 32).aliased("farenheit"))
    ```
    
    > :point_up: **Note**: an expression like `Col.name + "rrr"` will be interpreted by SQLite as a numerical addition (with funny results), not as a string concatenation.

- `AND`, `OR`, `NOT`
    
    The SQL logical operators are derived from the Swift `&&`, `||` and `!`:
    
    ```swift
    // SELECT * FROM "persons" WHERE ((NOT "verified") OR ("age" < 18))
    Person.filter(!Col.verified || Col.age < 18)
    ```

- `BETWEEN`, `IN`, `IN (subquery)`, `NOT IN`, `NOT IN (subquery)`
    
    To check inclusion in a collection, call the `contains` method on any Swift sequence:
    
    ```swift
    // SELECT * FROM "persons" WHERE ("id" IN (1, 2, 3))
    Person.filter([1, 2, 3].contains(Col.id))
    
    // SELECT * FROM "persons" WHERE ("id" NOT IN (1, 2, 3))
    Person.filter(![1, 2, 3].contains(Col.id))
    
    // SELECT * FROM "persons" WHERE ("age" BETWEEN 0 AND 17)
    Person.filter((0..<18).contains(Col.age))
    
    // SELECT * FROM "persons" WHERE ("age" BETWEEN 0 AND 17)
    Person.filter((0...17).contains(Col.age))
    
    // SELECT * FROM "persons" WHERE ("name" BETWEEN 'A' AND 'z')
    Person.filter(("A"..."z").contains(Col.name))
    
    // SELECT * FROM "persons" WHERE (("name" >= 'A') AND ("name" < 'z'))
    Person.filter(("A"..<"z").contains(Col.name))
    ```
    
    > :point_up: **Note**: SQLite string comparison, by default, is case-sensitive and not Unicode-aware. See [string comparison](#string-comparison) if you need more control.
    
    To check inclusion in a subquery, call the `contains` method on another request:
    
    ```swift
    // SELECT * FROM "events"
    //  WHERE ("userId" IN (SELECT "id" FROM "persons" WHERE "verified"))
    let verifiedUsers = User.filter(Col.verified)
    Event.filter(verifiedPersonIds.select(Col.id).contains(Col.userId))
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
    Person.select(min(Col.age), max(Col.age))
    
    // SELECT COUNT("name") FROM persons
    Person.select(count(Col.name))
    
    // SELECT COUNT(DISTINCT "name") FROM persons
    Person.select(count(distinct: Col.name))
    ```

- `IFNULL`
    
    Use the Swift `??` operator:
    
    ```swift
    // SELECT IFNULL("name", 'Anonymous') FROM persons
    Person.select(Col.name ?? "Anonymous")
    
    // SELECT IFNULL("name", "email") FROM persons
    Person.select(Col.name ?? Col.email)
    ```

- `LOWER`, `UPPER`
    
    Use the `lowercaseString` and `uppercaseString` methods:
    
    ```swift
    // SELECT * FROM persons WHERE LOWER(name) = 'arthur'
    Person.filter(Col.name.lowercaseString == 'arthur)
    ```
    
    > :point_up: **Note**: SQLite support for case translation is limited to ASCII characters. When comparing strings as in the example abobe, you may prefer a [custom comparison function](#string-comparison). When you actually want to transform strings in an Unicode-aware fashion, use a [custom SQL function](#custom-sql-functions).

- Custom SQL functions
    
    You can apply your own [custom SQL functions](#custom-sql-functions):
    
    ```swift
    let unicodeUpper = DatabaseFunction("unicodeUpper", ...)
    
    // SELECT unicodeUpper("name") AS "uppercaseName" FROM persons
    Person.select(unicodeUpper.apply(Col.name).aliased("uppercaseName"))
    ```

    
### Fetching from Requests

Once you have a request, you can fetch the records at the origin of the request:

```swift
dbQueue.inDatabase { db in
    // Some request based on `Person`
    let request = Person.filter(...)...
    
    // Fetch persons:
    request.fetch(db)    // DatabaseSequence<Person>
    request.fetchAll(db) // [Person]
    request.fetchOne(db) // Person?
}
```

See [fetching methods](#fetching-methods) for information about the `fetch`, `fetchAll` and `fetchOne` methods.

For example:

```swift
for person in Person.filter(Col.name != nil).fetch(db) {
    print(person)
}
let allPersons = Person.fetchAll(db)                            // [Person]
let arthur = Person.filter(Col.name == "Arthur").fetchOne(db)   // Person?
```


**When the selected columns don't fit the source type**, you just have to change your target: any other type that adopts the [RowConvertible](#rowconvertible-protocol) protocol, plain [database rows](#column-values), and even [values](#values):

```swift
dbQueue.inDatabase { db in
    let request = Person....
    
    // Alternative records:
    Other.fetch(db, request)    // DatabaseSequence<Other>
    Other.fetchAll(db, request) // [Other]
    Other.fetchOne(db, request) // Other?
    
    // Rows:
    Row.fetch(db, request)      // DatabaseSequence<Row>
    Row.fetchAll(db, request)   // [Row]
    Row.fetchOne(db, request)   // Row?
    
    // Values:
    Int.fetch(db, request)      // DatabaseSequence<Int>
    Int.fetchAll(db, request)   // [Int]
    Int.fetchOne(db, request)   // Int?
}
```

For example:

```swift
// Int
let request = Person.select(min(Col.height))
let minHeight = Int.fetchOne(db, request)!

// Row
let request = Person.select(min(Col.height), max(Col.height))
let row = Row.fetchOne(db, request)!
let minHeight = row.value(atIndex: 0) as Int
let maxHeight = row.value(atIndex: 1) as Int
```

See [column values](#column-values) for more information about the `row.value()` method.

**Fetching records according to their primary key** is a very common task. It has a shortcut which accepts any single-column primary key:

```swift
// SELECT * FROM persons WHERE id = 1
Person.fetchOne(db, key: 1)!

// SELECT * FROM persons WHERE id IN (1, 2, 3)
Person.fetchAll(db, keys: [1, 2, 3])!

// SELECT * FROM persons WHERE isoCode = 'FR'
Country.fetchOne(db, key: "FR")!

// SELECT * FROM countries WHERE isoCode IN ('FR', 'US')
Country.fetchAll(db, keys: ["FR", "US"])!
```


### Fetching Aggregated Values

**Requests can count:**

```swift
dbQueue.inDatabase { db in
    // SELECT COUNT(*) FROM "persons"
    let count = Person.fetchCount(db) // Int
    
    // SELECT COUNT(*) FROM "persons" WHERE "email" IS NOT NULL
    let count = Person.filter(Col.email != nil).fetchCount(db) // Int
}
```

Other aggregated values can also be selected and fetched (see [SQL Functions](#sql-functions)):

```swift
dbQueue.inDatabase { db in
    // SELECT MIN("age") FROM "persons"
    let request = Person.select(min(Col.age))
    let minAge = Int.fetchOne(db, request)  // Int?
    
    // SELECT MIN("height"), MAX("height") FROM "persons"
    let request = Person.select(min(Col.height), max(Col.height))
    let row = Row.fetchOne(db, request)!
    let minHeight = row.value(atIndex: 0) as Int?
    let maxHeight = row.value(atIndex: 1) as Int?
}
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

try migrator.migrate(dbQueue)
```

**Each migration runs in a separate transaction.** Should one throw an error, its transaction is rollbacked, subsequent migrations do not run, and the error is eventually thrown by `migrator.migrate(dbQueue)`.

**The memory of applied migrations is stored in the database itself** (in a reserved table).


### Advanced Database Schema Changes

SQLite does not support many schema changes, and won't let you drop a table column with "ALTER TABLE ... DROP COLUMN ...", for example.

Yet any kind of schema change is still possible. The SQLite documentation explains in detail how to do so: https://www.sqlite.org/lang_altertable.html#otheralter. This technique requires the temporary disabling of foreign key checks, and is supported by the `withDisabledForeignKeyChecks` argument:

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

To activate a transaction observer, add it to the database:

```swift
let observer = MyObserver()
dbQueue.inDatabase { db in
    db.addTransactionObserver(observer)
}
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

> :point_up: **Note**: All callbacks are called on the database queue.
>
> :point_up: **Note**: The databaseDidChangeWithEvent and databaseWillCommit callbacks must not touch the SQLite database. This limitation does not apply to databaseDidCommit and databaseDidRollback which can use their database argument.

Check [TableChangeObserver.swift](https://gist.github.com/groue/2e21172719e634657dfd) for a transaction observer that notifies, on the main thread, of modified database tables. Your view controllers can listen to those notifications and update their views accordingly.


Sample Code
===========

- The [Documentation](#documentation) is full of GRDB snippets.
- [GRDBDemoiOS](DemoApps/GRDBDemoiOS): A sample iOS application.
- [GRDBDemoiOS7](DemoApps/GRDBDemoiOS7): A sample iOS7 application.
- Check `GRDB.xcworkspace`: it contains GRDB-enabled playgrounds to play with.
- How to read and write NSDate as timestamp: [DatabaseTimestamp.playground](Playgrounds/DatabaseTimestamp.playground/Contents.swift)
- How to synchronize a database table with a JSON payload: [JSONSynchronization.playground](Playgrounds/JSONSynchronization.playground/Contents.swift)
- A class that behaves like NSUserDefaults, but backed by SQLite: [UserDefaults.playground](Playgrounds/UserDefaults.playground/Contents.swift)
- How to notify view controllers of database changes: [TableChangeObserver.swift](https://gist.github.com/groue/2e21172719e634657dfd)


---

**Thanks**

- [Pierlis](http://pierlis.com), where we write great software.
- [@Chiliec](https://github.com/Chiliec), [@pakko972](https://github.com/pakko972), [@peter-ss](https://github.com/peter-ss) and [@pierlo](https://github.com/pierlo) for their feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [@kali](https://github.com/kali) because SQL.
- [ccgus/fmdb](https://github.com/ccgus/fmdb) for its excellency.
