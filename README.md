GRDB.swift
==========

GRDB.swift is an [SQLite](https://www.sqlite.org) toolkit for Swift 2, from the author of [GRMustache](https://github.com/groue/GRMustache).

It ships with a low-level database API, plus application-level tools.

**July 9, 2015: GRDB.swift 0.2.0 is out.** [Release notes](RELEASE_NOTES.md)

Get release announcements and usage tips: follow [@groue on Twitter](http://twitter.com/groue).

Jump to:

- [Usage](#usage)
- [Installation](#installation)
- [Documentation](#documentation)


Features
--------

- **A low-level SQLite API** that leverages the Swift 2 standard library.
- **No ORM, no smart query builder, no table introspection**. Your SQL skills are welcome here.
- **A Model class** that wraps result sets, eats your SQL queries for breakfast, and provides basic CRUD operations.
- **Full Swift type freedom**: pick the right Swift type that fits your data. Use Int64 when needed, or stick with the convenient Int. Declare Swift enums for discrete data types. Define your own database-convertible types, without any limitation (OK, it won't work for NSObject but that's it).
- **Database Migrations**


Usage
-----

```swift
import GRDB

// Open database connection
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

let redWinesCount = dbQueue.inDatabase { db in            // Int
    db.fetchOne(Int.self, "SELECT COUNT(*) FROM wines WHERE color = ?",
                bindings: [Color.Red])!
}

try dbQueue.inTransaction { db in
    try Person(name: "Arthur").insert(db)
    return .Commit
}

dbQueue.inDatabase { db in
    let persons = db.fetchAll(Person.self, "SELECT ...")  // [Person]
    for wine in db.fetch(Wine.self, "SELECT ...") {       // AnySequence<Wine>
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

pod 'GRDB.swift', '0.2.0'
```


### Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency manager for Xcode projects.

To use GRDB.swift with Carthage, specify in your Cartfile:

```
github "groue/GRDB.swift" == 0.2.0
```

Before running `carthage update`, select Xcode-beta as the active developer directory by running the following command:

```
sudo xcode-select  -s /Applications/Xcode-beta.app
```


### Manually

Download a copy of GRDB.swift, embed the `GRDB.xcodeproj` project in your own project, and add the `GRDBOSX` or `GRDBiOS` target as a dependency of your own target.


Documentation
=============

SQLite API:

- [Database](#database)
- [Transactions](#transactions)
- [Fetch Queries](#fetch-queries)
- [Values](#values)
- [Prepared Statements](#prepared-statements)
- [Error Handling](#error-handling)

Application tools:

- [Migrations](#migrations)
- [Row Models](#row-models)


## Database

You access SQLite databases through thread-safe database queues (inspired by [ccgus/FMDB](https://github.com/ccgus/fmdb)):

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
        bindings: ["Arthur", 36])
    
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (:name, :age)",
        bindings: ["name": "Barbara", "age": 37])
    
    return .Commit
}
```

A rollback statement is issued if an error is thrown from the transaction block.


## Fetch Queries

- [Row Queries](#row-queries)
- [Value Queries](#value-queries)


### Row Queries

Fetch **lazy sequences** of rows, **arrays**, or a **single** row:

```swift
dbQueue.inDatabase { db in
    db.fetchRows("SELECT ...", bindings: ...)     // AnySequence<Row>
    db.fetchAllRows("SELECT ...", bindings: ...)  // [Row]
    db.fetchOneRow("SELECT ...", bindings: ...)   // Row?
}
```

Bindings are optional arrays or dictionaries that fill the positional `?` and named parameters like `:name` in the query. GRDB.swift only supports colon-prefixed named parameters, even though SQLite supports [other syntaxes](https://www.sqlite.org/lang_expr.html#varparam).


```swift
db.fetchRows("SELECT * FROM persons WHERE name = ?", bindings: ["Arthur"])
db.fetchRows("SELECT * FROM persons WHERE name = :name", bindings: ["name": "Arthur"])
```

Lazy sequences can not be consumed outside of a database queue, but arrays are OK:

```swift
let rows = dbQueue.inDatabase { db in
    return db.fetchAllRows("SELECT ...")          // [Row]
    return fetchRows("SELECT ...").filter { ... } // [Row]
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
row.value(named: "bookCount") as? Int   // NO NO NO DON'T DO THAT!
```

#### General Row Processing

The `row.value(atIndex:)` and `row.value(named:)` functions above require that you know the row structure: which columns are available, in which order.

When you process an unknown row, you will prefer the subscript operator which returns `DatabaseValue`, an intermediate type between SQLite and your values:

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
    db.fetch(Int.self, "SELECT ...", bindings: ...)      // AnySequence<Int?>
    db.fetchAll(Int.self, "SELECT ...", bindings: ...)   // [Int?]
    db.fetchOne(Int.self, "SELECT ...", bindings: ...)   // Int?
}
```

Lazy sequences can not be consumed outside of a database queue, but arrays are OK:

```swift
let names = dbQueue.inDatabase { db in
    return db.fetchAll(String.self, "SELECT name ...")             // [String?]
    return db.fetch(String.self, "SELECT name ...").filter { ... } // [String?]
}
for name in names { ... } // OK
```

Sequences and arrays contain optional values. When you are sure that all results are not NULL, unwrap the optionals with the bang `!` operator:

```swift
// names is [String]
let names = dbQueue.inDatabase { db in
    db.fetchAll(String.self, "SELECT name FROM persons").map { $0! }
}
```

The `db.fetchOne(type:sql:bindings:)` function returns an optional value which is nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value. If this ambiguity does not fit your need, use `db.fetchOneRow`.


## Values

The library ships with built-in support for `Bool`, `Int`, `Int64`, `Double`, `String`, `Blob`, and [Swift enums](#swift-enums). Custom types are supported as well through the [DatabaseValueConvertible](#custom-types) protocol.


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
               bindings: [Grape.Merlot, Color.Red])

// Extract from row:
for rows in db.fetchRows("SELECT * FROM wines") {
    let grape: Grape? = row.value(named: "grape")
    let color: Color? = row.value(named: "color")
}

// Direct fetch:
db.fetch(Color.self, "SELECT ...", bindings: ...)    // AnySequence<Color?>
db.fetchAll(Color.self, "SELECT ...", bindings: ...) // [Color?]
db.fetchOne(Color.self, "SELECT ...", bindings: ...) // Color?
```


### Custom Types

Conversion to and from the database is based on the `DatabaseValueConvertible` protocol.

All types that adopt this protocol can be used wherever the built-in types `Int`, `String`, etc. are used. without any limitation or caveat.

> Unfortunately not all types can adopt this protocol: **Swift won't allow non-final classes to adopt DatabaseValueConvertible, and this prevents all our NSObject fellows to enter the game.**

As an example, let's define the `DBDate` type that stores NSDates as timestamps. It applies all the best practices for a great GRDB.swift integration:

```swift
struct DBDate: DatabaseValueConvertible {
    
    // NSDate conversion
    //
    // It is good to consistently use the Swift nil to represent the database
    // NULL: the date property is a non-optional NSDate, and the NSDate
    // initializer is failable:
    
    // The represented date
    let date: NSDate
    
    // Creates a DBDate from an NSDate.
    // Returns nil if and only if the NSDate is nil.
    init?(_ date: NSDate?) {
        if let date = date {
            self.date = date
        } else {
            return nil
        }
    }
    
    // DatabaseValue conversion
    //
    // DBDate represents the date as a timestamp in the database.
    
    var databaseValue: DatabaseValue {
        return .Real(date.timeIntervalSince1970)
    }
    
    init?(databaseValue: DatabaseValue) {
        // Don't handle the raw DatabaseValue unless you know what you do.
        // It is recommended to use GRDB built-in conversions instead:
        if let timestamp = Double(databaseValue: databaseValue) {
            self.init(NSDate(timeIntervalSince1970: timestamp))
        } else {
            return nil
        }
    }
}
```

DBDate can now be stored and fetched from the database just like built-in types:

```swift
// Store:
let date = NSDate()
try db.execute("INSERT INTO persons (timestamp, ...) " +
                            "VALUES (?, ...)",
                          bindings: [DBDate(date), ...])

// Extract from row:
for rows in db.fetchRows("SELECT ...") {
    let dbDate: DBDate? = row.value(named: "timestamp")
    let date = dbDate?.date
}

// Direct fetch:
db.fetch(DBDate.self, "SELECT ...", bindings: ...)    // AnySequence<DBDate?>
db.fetchAll(DBDate.self, "SELECT ...", bindings: ...) // [DBDate?]
db.fetchOne(DBDate.self, "SELECT ...", bindings: ...) // DBDate?
```

### Value Extraction in Details

SQLite has a funny way to manage values. It is "funny" because it is a rather long read: https://www.sqlite.org/datatype3.html.

The interested reader should know that GRDB.swift *does not* use SQLite built-in casting features when extracting values. Instead, it performs its *own conversions*, based on the storage class of database values:

| Storage class |  Bool   |  Int ³  |  Int64   | Double | String ³  | Blob |
|:------------- |:-------:|:-------:|:--------:|:------:|:---------:|:----:|
| NULL          |    -    |    -    |    -     |   -    |     -     |  -   |
| INTEGER       |  Bool ¹ |  Int ²  |  Int64   | Double |     -     |  -   |
| REAL          |  Bool ¹ |  Int ²  | Int64 ²  | Double |     -     |  -   |
| TEXT          |    -    |    -    |    -     |   -    |  String   |  -   |
| BLOB          |    -    |    -    |    -     |   -    |     -     | Blob |

¹ The only false numbers are 0 (integer) and 0.0 (real).

² You will get a fatal error if the value is too big for Int or Int64.

³ Applies also to Int and String-based [enums](#swift-enums).

Your [custom types](#custom-types) can perform their own conversions to and from SQLite storage classes.


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
        let changes = try statement.execute(bindings: Bindings(person))
        changes.changedRowCount // The number of rows changed by the statement.
        changes.insertedRowID   // The inserted Row ID.
    }
    
    return .Commit
}
```

Select statements can fetch rows and values:

```swift
dbQueue.inDatabase { db in
    
    let statement = db.selectStatement("SELECT ...")
    
    statement.fetchRows(bindings: ...)          // AnySequence<Row>
    statement.fetchAllRows(bindings: ...)       // [Row]
    statement.fetchOneRow(bindings: ...)        // Row?
    
    statement.fetch(Int.self, bindings: ...)    // AnySequence<Int?>
    statement.fetchAll(Int.self, bindings: ...) // [Int?]
    statement.fetchOne(Int.self, bindings: ...) // Int?
}
```


## Error Handling

**No SQLite error goes unnoticed.** Yet when such an error happens, some GRDB.swift functions throw a DatabaseError error, and some crash with a fatal error.

**The rule** is:

- All methods that *read* data crash.
- All methods that *write* data throw an error.

> Rationale: we assume that *all* reading errors are either SQL errors that the developer should fix (a syntax error, a wrong column name), or external I/O errors that are beyond repair and better hidden behind a crash. Write errors may be relational errors (violated unique index, missing reference) and you may want to handle relational errors yourselves.
>
> Please open an [issue](https://github.com/groue/GRDB.swift/issues) if you need fine tuning of select errors.

```swift
// fatal error:
// SQLite error 1 with statement `SELECT foo FROM bar`: no such table: bar
db.fetchAllRows("SELECT foo FROM bar")

do {
    try db.execute(
        "INSERT INTO pets (masterId, name) VALUES (?, ?)",
        bindings: [1, "Bobby"])
} catch let error as DatabaseError {
    // The SQLite result code: 19 (SQLITE_CONSTRAINT)
    error.code
    
    // The eventual SQLite message
    // "FOREIGN KEY constraint failed"
    error.message
    
    // The eventual erroneous SQL query
    // "INSERT INTO pets (masterId, name) VALUES (?, ?)"
    error.sql
    
    // The full error message
    // "SQLite error 19 with statement `INSERT INTO pets (masterId, name)
    // VALUES (?, ?)` bindings [1, \"Bobby\"]: FOREIGN KEY constraint failed"
    error.description
}
```

See [SQLite Result Codes](https://www.sqlite.org/rescode.html).

## Migrations

**Migrations** are a convenient way to alter your database schema over time in a consistent and easy way.

Migrations run in order, once and only once. When a user upgrades your application, only non-applied migration are run.

```swift
var migrator = DatabaseMigrator()

// v1.0 database
migrator.registerMigration("createPersons") { db in
    try db.execute(
        "CREATE TABLE persons (" +
        "id INTEGER PRIMARY KEY, " +
        "creationTimestamp DOUBLE, " +
        "name TEXT NOT NULL)")
}

migrator.registerMigration("createBooks") { db in
    try db.execute(
        "CREATE TABLE books (" +
        "uuid TEXT PRIMARY KEY, " +
        "ownerID INTEGER NOT NULL " +
        "        REFERENCES persons(id) " +
        "        ON DELETE CASCADE ON UPDATE CASCADE, " +
        "title TEXT NOT NULL)")
}

// v2.0 database
migrator.registerMigration("AddAgeToPersons") { db in
    try db.execute("ALTER TABLE persons ADD COLUMN age INT")
}

try migrator.migrate(dbQueue)
```


## Row Models

**RowModel** is a class that wraps a table row, or the result of any query. It is designed to be subclassed.

Subclasses opt in RowModel features by overriding all or part of the core methods that define their relationship with the database:

| Core Methods                       | fetch | insert | update | delete | reload |
|:---------------------------------- |:-----:|:------:|:------:|:------:|:------:|
| `setDatabaseValue(_:forColumn:)`   |   ✓   |   ✓ ¹  |        |        |   ✓    |
| `databaseTable`                    |       |   ✓    |   ✓ ²  |   ✓ ²  |   ✓ ²  |
| `storedDatabaseDictionary`         |       |   ✓    |   ✓    |   ✓    |   ✓    |

¹ Insertion requires `setDatabaseValue(_:forColumn:)` when SQLite automatically generates row IDs.

² Update, delete & reload require a primary key.

- [Fetching Row Models](#fetching-row-models)
- [Ad Hoc Subclasses](#ad-hoc-subclasses)
- [Tables and Primary Keys](#tables-and-primary-keys)
- [Insert, Update and Delete](#insert-update-and-delete)
- [Preventing Useless UPDATE Statements](#preventing-useless-update-statements)
- [RowModel Errors](#rowmodel-errors)


### Fetching Row Models

The Person subclass below will be our guinea pig. It declares properties for the `persons` table:

```swift
class Person : RowModel {
    var id: Int64!            // matches "id" not null column
    var age: Int?             // matches "age" columnn
    var name: String?         // matches "name" column
}
```

The `setDatabaseValue(_:forColumn:)` method assigns database values to properties:

```swift
class Person : RowModel {
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "id":   id = dbv.value()    // Extract Int64!
        case "name": name = dbv.value()  // Extract String?
        case "age":  age = dbv.value()   // Extract Int?
        default:     super.setDatabaseValue(dbv, forColumn: column)
        }
    }
}
```

See [General Row Processing](#general-row-processing) for more information about the `DatabaseValue` type, and [Values](#values) about the supported property types.

Now you can fetch **lazy sequences** of row models, **arrays**, or **single** instances:

```swift

dbQueue.inDatabase { db in
    // With custom SQL:
    db.fetch(Person.self, "SELECT ...", bindings:...)    // AnySequence<Person>
    db.fetchAll(Person.self, "SELECT ...", bindings:...) // [Person]
    db.fetchOne(Person.self, "SELECT ...", bindings:...) // Person?
    
    // With a key dictionary:
    db.fetchOne(Person.self, key: ["id": 123])           // Person?
}
```

Lazy sequences can not be consumed outside of a database queue, but arrays are OK:

```swift
let persons = dbQueue.inDatabase { db in
    return db.fetchAll(Person.self, "SELECT ...")             // [Person]
    return db.fetch(Person.self, "SELECT ...").filter { ... } // [Person]
}
for person in persons { ... } // OK
```

The `db.fetchOne(type:key:)` eats any dictionary, and just returns the first RowModel with matching values. Its result is undefined unless the dictionary is actually... a key.


### Ad Hoc Subclasses

Swift makes it very easy to create small and private types. This is a wonderful opportunity to create **ad hoc subclasses** that provide support for custom queries with extra columns.

We think that this is the killer feature of GRDB.swift :bowtie:. For example:

```swift
class PersonsViewController: UITableViewController {
    
    // Private subclass of Person, with an extra `bookCount`:
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
            db.fetchAll(PersonViewModel.self,
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

Declare a **Table** given its **name** and **primary key** in order to fetch row models by ID:

```swift
class Person : RowModel {
    override class var databaseTable: Table? {
        return Table(named:"persons", primaryKey: .RowID("id"))
    }
}

try dbQueue.inDatabase { db in
    // Fetch
    let person = db.fetchOne(Person.self, primaryKey: 123)  // Person?
}
```

There are three kinds of primary keys:

- **RowID**: use it when you rely on automatically generated IDs in an `INTEGER PRIMARY KEY` column. Beware RowModel does not support the implicit `ROWID` column (see https://www.sqlite.org/autoinc.html for more information).
    
- **Column**: for single-column primary keys that are not managed by SQLite.
    
- **Columns**: for primary keys that span accross several columns.
    
RowModels with a multi-column primary key are not supported by `Database.fetchOne(type:primaryKey:)`, which accepts a single value as a key. Instead, use `Database.fetchOne(type:key:)` that uses a dictionary.


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

Models that declare a `RowID` primary key have their id automatically set after successful insertion (with the `setDatabaseValue(_:forColumn:)` method).

Other primary keys (single or multiple columns) are not managed by GRDB: you have to manage them yourself. You can for example override the `insert` primitive method, and make sure your primary key is set before calling `super.insert`.


### Preventing Useless UPDATE Statements

The `update()` method always executes an UPDATE statement. When the row model has not been edited, this database access is generally useless.

Avoid it with the `isEdited` property, which returns whether the row model has changes that have not been saved:

```swift
let json = ...
try dbQueue.inTransaction { db in
    // Fetches or create a new person given its ID:
    let person = db.fetchOne(Person.self, primaryKey: json["id"]) ?? Person()
    
    // Apply json payload:
    person.updateFromJSON(json)
                 
    // Saves the person if it is edited (fetched then modified, or created):
    if person.isEdited {
        person.save(db) // inserts or updates
    }
    
    return .Commit
}
```

Note that `isEdited` is based on value comparison: **setting a property to the same value does not set the edited flag**.


### RowModel Errors

RowModel methods can throw [DatabaseError](#error-handling) and also specific errors of type **RowModelError**:

- **RowModelError.UnspecifiedTable**: thrown by `insert`, `update`, `delete` and `reload` when the databaseTable class method returns nil (typically when it has not been overriden yet).

- **RowModelError.InvalidDatabaseDictionary**: thrown by `ìnsert`, `update`, `delete` and `reload` when the storedDatabaseDictionary does not contain enough values (typically when it has not been overriden yet).

- **RowModelError.InvalidPrimaryKey**: thrown by `update`, `delete` and `reload` when the primary key is nil.

- **RowModelError.RowModelNotFound**: thrown by `update` and `reload` when the primary key does not match any row in the database.


## Thanks

- [Pierlis](http://pierlis.com), where we write great software.
- [@pierlo](https://github.com/pierlo) for his feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [@kali](https://github.com/kali) because SQL.
- [ccgus/FMDB](https://github.com/ccgus/fmdb) for its excellency.
