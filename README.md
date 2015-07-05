GRDB.swift
==========

GRDB.swift is a Swift 2 library built around [SQLite](https://www.sqlite.org), from the author of [GRMustache](https://github.com/groue/GRMustache).

It ships with a low-level database API, plus application-level tools.


Features
--------

- **A low-level SQLite API** that leverages the Swift 2 standard library.
- **Full Swift type freedom**: pick the right Swift type that fits your data. Use Int64 when needed, or stick with the convenient Int. Declare Swift enums for discrete data types. Define your own database-convertible types, without any limitation (OK, it won't work for NSObject but that's it).
- **No ORM, no smart query builder, no table introspection**. Instead, a thin class that wraps database rows, eats your custom SQL queries for breakfast, and provides basic CRUD operations.
- **Migrations**


Usage
-----

```swift
import GRDB

let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

let person = Person(name: "Arthur")

try dbQueue.inTransaction { db in
    try person.insert(db)
    return .Commit
}

let persons = dbQueue.inDatabase { db in
    db.fetchAll(Person.type, "SELECT * FROM persons")
}
```


Documentation
=============

SQLite API:

- [Database](#database)
- [Transactions](#transactions)
- [Fetch Queries](#fetch-queries)
- [Swift Enums](#swift-enums)
- [Custom Types](#custom-types)
- [Statements](#statements)

Application tools:

- [Migrations](#migrations)
- [Row Models](#row-models)


## Database

You access SQLite databases through thread-safe database queues (inspired by [ccgus/FMDB](https://github.com/ccgus/fmdb)):

```swift
let dbQueue = try DatabaseQueue(path: "/tmp/GRDB.sqlite")
```

Configure databases:

```swift
let configuration = Configuration(
    foreignKeysEnabled: true,   // Default true, because, come on
    readonly: false,            // Default false
    trace: Configuration.logSQL // An optional trace function.
                                // Configuration.logSQL logs all SQL statements.
)
let dbQueue = try DatabaseQueue(
    path: "/tmp/GRDB.sqlite",
    configuration: configuration)
```

To open an in-memory database, don't provide any path:

```swift
let inMemoryDBQueue = DatabaseQueue()
```

Database connections get closed when the database queue gets deallocated.


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
- [A Note about SQLite Storage Classes](#a-note-about-sqlite-storage-classes)


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
    return Array(fetchRows("SELECT ..."))         // [Row]
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

// WARNING: type inference requires a very careful use of the `as`
// operator (see rdar://problem/21676393):
row.value(named: "bookCount") as Int?   // good
row.value(named: "bookCount") as? Int   // NO NO NO DON'T DO THAT!
```

The subscript operator returns SQLiteValue, an intermediate type between SQLite storage and your values:

```swift
// Test if the column `bookCount` is defined:
if let sqliteValue = row["bookCount"] {
    // Extract the desired Swift type from the SQLite value:
    let bookCount: Int = sqliteValue.value()!
    let bookCount64: Int64 = sqliteValue.value()!
    let hasBooks: Bool = sqliteValue.value()!     // false when 0
}
```


**Rows are collections** of tuples (columnName, sqliteValue):

```swift
let row = db.fetchOneRow("SELECT firstName, lastName FROM persons")!
for (columnName, sqliteValue) in row {
    columnName                      // "firstName", then "lastName".
    sqliteValue.value() as String?  // the first name, then the last name.
}
```


### Value Queries

Instead of rows, you can directly fetch **values**, extracted from the first column of the resulting rows.

The library ships with built-in support for `Bool`, `Int`, `Int64`, `Double`, `String`, `Blob`, and [Swift enums](#swift-enums). Custom types are supported as well through the [SQLiteValueConvertible protocol](#custom-types).

All those types can be fetched as **lazy sequences**, **arrays**, or **single** value:

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
    return Array(db.fetch(String.self, "SELECT name ..."))         // [String?]
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


### A Note about SQLite Storage Classes

SQLite has a funny way to store values in the database. It is "funny" because it is a rather long read: https://www.sqlite.org/datatype3.html.

The interested reader should know that GRDB.swift *does not* use SQLite built-in casting features when converting between types. Instead, it performs its *own conversions*, based on the storage class of database values. It has to do so because you generally consume database values long after the opportunity to use SQLite casting has passed.

For reference:

- **NULL** storage class is always extracted as the Swift nil.

- **INTEGER** storage class can be converted to `Bool`, `Int`, `Int64`, and `Double`.

    You will get a fatal error if you extract a value too big for `Int`.
    
    The only falsey integer is 0.

- **REAL** storage class can be converted to `Bool`, `Int`, `Int64`, and `Double`.
    
    You will get a fatal error if you extract a value too big for `Int` or `Int64`.
    
    The only falsey real is 0.0.

- **TEXT** storage class can be converted to `String`.

- **BLOB** storage class can be converted to `Blob`.

Your custom types can perform their own conversions to and from SQLite storage classes (see [below](#custom-types))


## Swift Enums

**Swift enums** get full support from GRDB.swift as long as their raw values are Int or String.

Given those two enums:

```swift
enum Color : Int {
    case Red
    case White
    case Rose
}

enum Grape : String {
    case Chardonnay = "Chardonnay"
    case Merlot = "Merlot"
    case Riesling = "Riesling"
}
```

Simply add those two lines:

```swift
extension Color : SQLiteIntRepresentable { }
extension Grape : SQLiteStringRepresentable { }
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


## Custom Types

Conversion to and from the database is based on the `SQLiteValueConvertible` protocol. Types that adopt this protocol can be used wherever the built-in types `Int`, `String`, etc. are used, without any limitation or caveat.

> Swift won't allow this protocol to be adopted by non-final classes, and this prevents all our NSObject fellows to enter the game. That's unfortunate.

As an example, let's define the `DBDate` type that stores NSDates as timestamps. It applies all the best practices for a great GRDB.swift integration:

```swift
struct DBDate: SQLiteValueConvertible {
    
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
    
    // SQLiteValue conversion
    //
    // DBDate represents the date as a timestamp in the database.
    
    var sqliteValue: SQLiteValue {
        return .Real(date.timeIntervalSince1970)
    }
    
    init?(sqliteValue: SQLiteValue) {
        // Don't handle the raw SQLiteValue unless you know what you do.
        // It is recommended to use GRDB built-in conversions instead:
        if let timestamp = Double(sqliteValue: sqliteValue) {
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


## Statements

SQLite supports **Prepared Statements** that can be reused.

Update statements:

```swift
try dbQueue.inTransaction { db in
    
    let statement = try db.updateStatement("INSERT INTO persons (name, age) " +
                                           "VALUES (:name, :age)")
    
    let persons = [
        ["name": "Arthur", "age": 41],
        ["name": "Barbara"],
    ]
    
    for person in persons {
        try statement.execute(bindings: Bindings(person))
    }
    
    return .Commit
}
```

Select statements can fetch rows and values:

```swift
try dbQueue.inDatabase { db in
    
    let statement = try db.selectStatement("SELECT ...")
    
    statement.fetchRows(bindings: ...)          // AnySequence<Row>
    statement.fetchAllRows(bindings: ...)       // [Row]
    statement.fetchOneRow(bindings: ...)        // Row?
    
    statement.fetch(Int.self, bindings: ...)    // AnySequence<Int?>
    statement.fetchAll(Int.self, bindings: ...) // [Int?]
    statement.fetchOne(Int.self, bindings: ...) // Int?
}
```

Note that the `Database.selectStatement()` function is the **only** function of GRDB.swift that may throw an error when building a SELECT statement. All other fetching functions prefer dying in a loud and verbose crash when given an invalid SELECT statement.

Compare:

```swift
// fatal error: SQLite error 1 with statement `SELECT foo FROM bar`:
// no such table: bar
db.fetchAllRows("SELECT foo FROM bar")

do {
    let statement = try db.selectStatement("SELECT foo FROM bar")
} catch let error as SQLiteError {
    error.code        // 1: the SQLite error code
    error.message     // "no such table: bar": the eventual SQLite message
    error.sql         // "SELECT foo FROM bar": the eventual erroneous SQL query
    error.description // "SQLite error 1 with statement `SELECT foo FROM bar`: no such table: bar"
}
```


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

**RowModel** is a convenience class that wraps a table row, or the result of any query.

We'll illustrate its features with the Person subclass below. Note how it declares properties for the `persons` table seen above:

```swift
class Person : RowModel {
    var id: Int64?            // matches "id" column
    var name: String?         // matches "name" column
    var age: Int?             // matches "age" columnn
    var creationDate: NSDate? // matches "creationTimestamp" column
}
```

- [Loading](#loading)
- [Insert, Update and Delete](#insert-update-and-delete)


### Loading

By overriding `updateFromDatabaseRow(row: Row)`, you can load row models from the database.

In this method, use the subscript operator to load SQLite values that you can assign to your properties:

```swift
class Person : RowModel {
    var id: Int64?            // matches "id" column
    var name: String?         // matches "name" column
    var age: Int?             // matches "age" columnn
    var creationDate: NSDate? // matches "creationTimestamp" column
    
    override func updateFromDatabaseRow(row: Row) {
        // Set the `id` property if the row has an "id" column:
        if let v = row["id"]   { id = v.value() }     // Int64
        if let v = row["name"] { name = v.value() }   // Int
        if let v = row["age"]  { age = v.value() }    // String
        if let v = row["creationTimestamp"] {         // NSDate
            // Use the DBDate custom type declared above:
            let dbDate = v.value() as DBDate?
            creationDate = dbDate?.date
        }
    }
}
```

Your properties can be assigned if they are `Bool`, `Int`, `Int64`, `Double`, `String`, `Blob`, or [Swift enums](#swift-enums). Custom types like `DBDate` are supported through the [SQLiteValueConvertible protocol](#custom-types).


Fetch **lazy sequences** of row models, **arrays**, or a **single** instance:

```swift

dbQueue.inDatabase { db in
    db.fetch(Person.self, "SELECT ...", bindings:...)    // AnySequence<Person>
    db.fetchAll(Person.self, "SELECT ...", bindings:...) // [Person]
    db.fetchOne(Person.self, "SELECT ...", bindings:...) // Person?
}
```

Lazy sequences can not be consumed outside of a database queue, but arrays are OK:

```swift
let persons = dbQueue.inDatabase { db in
    return db.fetchAll(Person.self, "SELECT name ...")             // [Person]
    return Array(db.fetch(Person.self, "SELECT name ..."))         // [Person]
    return db.fetch(Person.self, "SELECT name ...").filter { ... } // [Person]
}
for person in persons { ... } // OK
```


Declare a **Primary Key** and a **Table name** in order to fetch row models by primary key:

```swift
class Person : RowModel {
    ...
    
    override class var databaseTableName: String? {
        return "persons"
    }
    
    override class var databasePrimaryKey: PrimaryKey {
        return .RowID("id")
    }
}

dbQueue.inDatabase { db in
    db.fetchOne(Person.self, primaryKey: 123)           // Person?
}
```

There are four kinds of primary keys:

- **None** (the default): no primary key

- **RowID**: use it when you rely on SQLite to automatically generate IDs (see https://www.sqlite.org/autoinc.html).
    
    ```swift
    class Person : RowModel {
        override class var databasePrimaryKey: PrimaryKey {
            return .RowID("id")
        }
    }
    db.fetchOne(Person.self, primaryKey: 123)
    ```
    
- **Column**: for single-column primary keys that are not managed by SQLite.
    
    ```swift
    class Book : RowModel {
        override class var databasePrimaryKey: PrimaryKey {
            return .Column("uuid")
        }
    }
    db.fetchOne(Book.self, primaryKey: "b3fc...")
    ```
    
- **Columns**: for primary keys that span accross several columns.
    
    ```swift
    class Citizenship : RowModel {
        override class var databasePrimaryKey: PrimaryKey {
            return .Columns("personID", "countryID")
        }
    }
    db.fetchOne(Citizenship.self, primaryKey: [arthur.id, france.id])
    db.fetchOne(Citizenship.self, primaryKey: ["personID": arthur.id, "countryID": france.id])
    ```
    

The kind of primary key impacts the insert/update/delete methods that we will see below.


**Subclass with ad-hoc classes** when iterating custom queries.

We think that this is the killer feature of GRDB.swift :bowtie:. For example:

```swift
class PersonsViewController: UITableViewController {
    
    // Private subclass of Person, with an extra `bookCount`:
    private class PersonViewModel : Person {
        var bookCount: Int!
        
        override func updateFromDatabaseRow(row: Row) {
            super.updateFromDatabaseRow(row)
            if let v = row["bookCount"] { bookCount = v.value() }
        }
    }
    
    let persons: [PersonViewModel]?
    
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


### Insert, Update and Delete

Those operations require one more method:

```swift
class Person : RowModel {
    ...
    
    // The values stored in the database:
    override var databaseDictionary: [String: SQLiteValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "age": age,
            // The custom type DBDate has been declared above.
            "creationTimestamp": DBDate(creationDate),
        ]
    }
}

try dbQueue.inTransaction { db in
    
    // Insert
    let person = Person(name: "Arthur", age: 41)
    try person.insert(db)
    
    // Update
    person.age = 42
    try person.update(db)
    
    // Delete
    try person.delete(db)
    
    return .Commit
}
```

Models that declare a `RowID` primary key have their id automatically set after insertion:

```swift
class Person : RowModel {
    override class var databasePrimaryKey: PrimaryKey {
        return .RowID("id")
    }
}

let arthur = Person(name: "Arthur")
arthur.id   // nil
try arthur.insert(db)
arthur.id   // some value
```

Other primary keys (single or multiple columns) are not managed by GRDB: you have to manage them yourself.

You can for example **override primitive methods**:

```swift
class Book : RowModel {
    ...
    
    // Before insertion, set uuid primary key if not set yet.
    override func insert(db: Database) throws {
        if uuid == nil {
            uuid = NSUUID().UUIDString
        }
        
        try super.insert(db)
    }
}
```

There are a lot of possible customizations:

```swift
class Person : RowModel {
    ...
    
    override func insert(db: Database) throws {
        creationDate = NSDate()
        try validate()
        try super.insert(db)
    }
}
```


## Thanks

- [Pierlis](http://pierlis.com), where we write great software.
- [@pierlo](https://github.com/pierlo) for his feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [@kali](https://github.com/kali) because SQL.
- [ccgus/FMDB](https://github.com/ccgus/fmdb) for its excellency.
