GRDB.swift
==========

GRDB.swift is a Swift 2 library built around [SQLite](https://www.sqlite.org).

It ships with a low-level database API, plus application-level tools.


Features
--------

- **A low-level SQLite API** that leverages the Swift 2 standard library.
- **Migrations**
- **No ORM, no smart query builder, no table abstraction**. Instead, a thin class that wraps database rows, eats your custom SQL queries for breakfast, and provides basic CRUD operations.


Usage
-----

```swift
let dbQueue = try DatabaseQueue(path: "/tmp/GRDB.sqlite")

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

- [Database queues](#database-queues)
- [Transactions](#transactions)
- [Fetch Queries](#fetch-queries)
- [Custom Types](#custom-types)
- [Statements](#statements)

Application tools:

- [Migrations](#migrations)
- [Row Models](#row-models)


## Database queues

**Database queues** safely serialize database accesses (inspired by [ccgus/FMDB](https://github.com/ccgus/fmdb)):

```swift
let dbQueue = try DatabaseQueue(path: "/tmp/GRDB.sqlite")
```


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

You can load rows and values from the database.

- [Row Queries](#row-queries)
- [Value Queries](#value-queries)


### Row Queries

You can load row **lazy sequences**, **arrays**, or a **single** row:

```swift
dbQueue.inDatabase { db in
    db.fetchRows("SELECT ...", bindings: ...)     // AnySequence<Row>
    db.fetchAllRows("SELECT ...", bindings: ...)  // [Row]
    db.fetchOneRow("SELECT ...", bindings: ...)   // Row?
}
```

Bindings are optional arrays or dictionaries that fill the `?` and `:name` parameters in the query.

You can extract rows values by index or column name:

```swift
dbQueue.inDatabase { db in
    
    for row in db.fetchRows("SELECT * FROM persons") {
        // Leverage Swift type inference
        let name: String? = row.value(atIndex: 1)
        
        // Force unwrap when column is NOT NULL
        let id: Int64 = row.value(named: "id")!
        
        // Both Int and Int64 are supported
        let age: Int? = row.value(named: "age")
        
        print("id: \(id), name: \(name), age: \(age)")
    }
    
    
    // Shortcuts
    
    db.fetchAllRows("SELECT ...")   // [Row]
    db.fetchOneRow("SELECT ...")    // Row?
}


// Extract results out of database blocks:

let rows = dbQueue.inDatabase { db in
    db.fetchAllRows("SELECT ...")
}
```

**A sequence is lazy**: it iterates SQLite results as it is consumed.

If you iterate such a sequence out of a database queue, you will get a *fatal error*:

```swift
// WRONG: you must not extract sequences out of a database queue.
let rowSequence = dbQueue.inDatabase { db in
    db.fetchRows("SELECT ...")
}

// fatal error: SelectStatement was not iterated on its database queue.
for row in rowSequence {
    ...
}
```

The solution is to dump such a sequence into an array:

```swift
// GOOD: Arrays of rows can safely be used outside of a database queue
let rows = dbQueue.inDatabase { db in
    // The `fetchAllRows` variant returns an array of rows:
    return db.fetchAllRows("SELECT ...")
    
    // Generally, any non-lazy collection will do:
    return Array(db.fetchRows("SELECT ..."))
    return db.fetchRows("SELECT ...").filter { ... }
}
```


### Value Queries

The library ships with built-in support for `Bool`, `Int`, `Int64`, `Double`, `String` and "binary large objects" through the `Blob` type, implemented on top of `NSData`.

You can load **lazy sequences** of values, **arrays**, or a **single** value:

```swift
dbQueue.inDatabase { db in
    
    db.fetch(String.self, "SELECT ...", bindings: ...)    // AnySequence<String?>
    db.fetchAll(String.self, "SELECT ...", bindings: ...) // [String?]
    db.fetchOne(String.self, "SELECT ...", bindings: ...) // String?
}


// Extract results out of database blocks:
//
// names is [String?]
let names = dbQueue.inDatabase { db in
    db.fetchAll(String.self, "SELECT name FROM persons")
}
```

Sequences and arrays contain optional values. When you are sure that all results are not NULL, unwrap the optionals with the bang `!` operator:

```swift
// names is [String]
let names = dbQueue.inDatabase { db in
    db.fetchAll(String.self, "SELECT name FROM persons").map { $0! }
}
```

The `db.fetchOne` function returns an optional value which is nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value.


## Custom Types

A custom type that can be represented as a [SQLIte datatype](https://www.sqlite.org/datatype3.html) (INTEGER, REAL, TEXT, and BLOB) gets full support from GRDB.swift by adopting the `DatabaseValueType` protocol. It can be used wherever the built-in types `Int`, `String`, etc. are used, without any limitation or caveat.

For example, let's define below the `DatabaseDate` type that stores and loads NSDates as timestamps:

```swift
struct DatabaseDate: DatabaseValueType {
    let date: NSDate
    
    // Define a failable initializer in order to consistently use nil as the
    // NULL marker throughout the conversions NSDate <-> DatabaseDate <-> SQLite
    init?(_ date: NSDate?) {
        if let date = date {
            self.date = date
        } else {
            return nil
        }
    }
    
    // Date -> SQLite
    var sqliteValue: SQLiteValue {
        return .Double(date.timeIntervalSince1970)
    }
    
    // SQLite -> Date
    static func fromSQLiteValue(value: SQLiteValue) -> DatabaseDate? {
        if let timestamp = Double.fromSQLiteValue(value) {
            return self.init(NSDate(timeIntervalSince1970: timestamp))
        } else {
            return nil
        }
    }
}

// Write

let date = NSDate()
try db.execute("INSERT INTO persons (creationTimestamp, ...) " +
                            "VALUES (?, ...)",
                          bindings: [DatabaseDate(date), ...])

// Read from row

let row = db.fetchOneRow("SELECT * FROM persons")!
let dbDate: DatabaseDate = row.value(named: "creationTimestamp")!
let date = dbDate.date

// Direct read

let dbDate = db.fetchOne(DatabaseDate.self, "SELECT creationTimestamp ...")!
let date = dbDate.date
```


## Statements

SQLite supports **Prepared Statements** that can be reused. For example:

```swift
try dbQueue.inTransaction { db in
    
    let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
    
    let persons = [
        ["Arthur", 41],
        ["Barbara"],
    ]
    
    for person in persons {
        statement.bindings = Bindings(person)
        try statement.execute()
    }
    
    return .Commit
}
```


## Migrations

**Migrations** are a convenient way to alter your database schema over time in a consistent and easy way. Define them with a DatabaseMigrator:

```swift
var migrator = DatabaseMigrator()

migrator.registerMigration("createPersons") { db in
    try db.execute(
        "CREATE TABLE persons (" +
        "id INTEGER PRIMARY KEY, " +
        "creationTimestamp DOUBLE, " +
        "name TEXT NOT NULL, " +
        "age INT)")
}

migrator.registerMigration("createPets") { db in
    // Support for foreign keys is enabled by default:
    try db.execute(
        "CREATE TABLE pets (" +
        "id INTEGER PRIMARY KEY, " +
        "masterID INTEGER NOT NULL " +
        "         REFERENCES persons(id) " +
        "         ON DELETE CASCADE ON UPDATE CASCADE, " +
        "name TEXT NOT NULL)")
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

By overriding `updateFromDatabaseRow`, you can load persons:

```swift
class Person : RowModel {
    ...
    
    // Boring and not DRY, but straightforward:
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("id")   { id = row.value(named: "id") }     // Int64
        if row.hasColumn("age")  { age = row.value(named: "age") }   // Int
        if row.hasColumn("name") { name = row.value(named: "name") } // String
        if row.hasColumn("creationTimestamp") {                      // NSDate
            // The custom type DatabaseDate that we have declared above turns
            // out handy:
            let dbDate: DatabaseDate? = row.value(named: "creationTimestamp")
            creationDate = dbDate?.date
        }
    }
}

let persons = dbQueue.inDatabase { db in
    db.fetchAll(Person.self, "SELECT * FROM persons")
}
```


Declare a **Primary Key** in order to fetch a specific row model:

```swift
class Person : RowModel {
    ...
    
    override class var databasePrimaryKey: PrimaryKey {
        return .SQLiteRowID("id")
    }
}

let person = dbQueue.inDatabase { db in
    db.fetchOne(Person.self, primaryKey: 123)
}
```

There are four kinds of primary keys:

- **None**: the default
- **SQLiteRowID**: use it when you rely on SQLite to automatically generate IDs (see https://www.sqlite.org/autoinc.html).
- **Single**: for single-column primary keys that are not managed by SQLite.
- **Multiple**: for primary keys that span accross several columns.

By declaring a primary key, you get access to the `Database.fetchOne(type:primaryKey:)` method. The type of the primary key also as an impact on the insert/update/delete methods that we will see below.


**Subclass with ad-hoc classes** when iterating custom queries.

We think that this is the killer feature of GRDB.swift :bowtie:. For example:

```swift
class PersonsViewController: UITableViewController {
    
    // Private subclass of Person, with an extra `petCount`:
    
    private class PersonViewModel : Person {
        var petCount: Int?
        
        override func updateFromDatabaseRow(row: Row) {
            super.updateFromDatabaseRow(row)
            
            if row.hasColumn("petCount") {
                petCount = row.value(named: "petCount")
            }
        }
    }
    
    let persons: [PersonViewModel]?
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let persons = dbQueue.inDatabase { db in
            db.fetchAll(PersonViewModel.self,
                "SELECT persons.*, COUNT(*) AS petCount " +
                "FROM persons " +
                "JOIN pets ON pets.masterID = persons.id " +
                "GROUP BY persons.id")
        }
        
        tableView.reloadData()
    }
    
    ...
}
```


### Insert, Update and Delete

Those operations require two more methods:

```swift
class Person : RowModel {
    ...
    
    // The table name:
    override class var databaseTableName: String? {
        return "persons"
    }
    
    // The saved values:
    override var databaseDictionary: [String: DatabaseValueType?] {
        return [
            "id": id,
            "name": name,
            "age": age,
            // The custom type DatabaseDate has been declared above.
            "creationTimestamp": DatabaseDate(creationDate),
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


**Override primitive methods** to prepare your insertions or updates:

```swift
class Person : RowModel {
    ...
    
    // Before insertion, set creationDate if not set yet.
    override func insert(db: Database) throws {
        if creationDate == nil {
            creationDate = NSDate()
        }
        
        try super.insert(db)
    }
}
```


## Thanks

- [Pierlis](http://pierlis.com), where we write great software.
- [@pierlo](https://github.com/pierlo) for his feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [@kali](https://github.com/kali) because SQL.
- [ccgus/FMDB](https://github.com/ccgus/fmdb) for its excellency.
