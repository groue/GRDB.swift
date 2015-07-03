GRDB.swift
==========

GRDB.swift is a Swift 2 library built around [SQLite](https://www.sqlite.org).

It ships with a low-level database API, plus application-level tools.


Features
--------

- **A low-level SQLite API** that leverages the Swift 2 standard library.
- **Migrations**
- **No ORM, no query builder**. Instead, a thin class that wraps query results, and helps people who like customizing their SQL queries.


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

- [Database queues](#database_queues)
- [Transactions](#transactions)
- [Fetch Queries](#fetch-queries)

Application tools:

- [Migrations](#migrations)
- [Row models](#row-models)


## Database queues

Database queues safely serialize database accesses (inspired by [ccgus/FMDB](https://github.com/ccgus/fmdb)):

```swift
let dbQueue = try DatabaseQueue(path: "/tmp/GRDB.sqlite")
```


## Transactions

Transactions wrap the queries that alter the database content:

```swift
try dbQueue.inTransaction { db in
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (?, ?)",
        bindings: ["Arthur", 36])
    
    try db.execute(
        "INSERT INTO persons (name, age) VALUES ($name, $age)",
        bindings: ["$name": "Barbara", "$age": 37])
    
    return .Commit
}
```

A rollback statement is issued if an error is thrown from the transaction block.


## Fetch Queries

**Row Queries** load database rows:

```swift
dbQueue.inDatabase { db in
    
    // AnySequence[Row]
    let rows = db.fetchRows("SELECT * FROM persons")
    
    for row in rows {
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


// Extract results our of database blocks:

let rows = dbQueue.inDatabase { db in
    db.fetchAllRows("SELECT ...")
}
```

**A row sequence is lazy**. It iterates SQLite results as it is consumed.

You will get a *fatal error* if you iterate such a sequence out of the database queue:

```swift
let rowSequence = dbQueue.inDatabase { db in
    db.fetchRows("SELECT ...")
}

// fatal error: SelectStatement was not iterated on its database queue.
for row in rowSequence {
    ...
}
```

Avoid those errors by extracting arrays, not sequences:

```swift
let rows = dbQueue.inDatabase { db in
    // The `fetchAllRows` variant returns an array of rows:
    return db.fetchAllRows("SELECT ...")
    
    // Generally, any non-lazy collection will do:
    return Array(db.fetchRows("SELECT ..."))
    return db.fetchRows("SELECT ...").filter { ... }
}
```


**Values queries** load value types:

```swift
dbQueue.inDatabase { db in
    
    // Use explicit type to load values, like `String.self` below:
    
    db.fetch(String.self, "SELECT name FROM persons")   // AnySequence[String?]
    db.fetchAll(String.self, "SELECT ...")              // [String?]
    db.fetchOne(String.self, "SELECT ...")              // String?
}
```

GRDB.swift ships with built-in support for `Bool`, `Int`, `Int64`, `Double` and `String` (TODO: binary blob).


**Custom types** can be inserted and loaded by adopting the `DatabaseValue` protocol:

```swift
struct DatabaseDate: DatabaseValue {
    let date: NSDate
    
    // Use a failable initializer to give nil NSDate the behavior of NULL:
    init?(_ date: NSDate?) {
        if let date = date {
            self.date = date
        } else {
            return nil
        }
    }
    
    func bindInSQLiteStatement(statement: SQLiteStatement, atIndex index: Int) -> Int32 {
        let timestamp = date.timeIntervalSince1970
        return timestamp.bindInSQLiteStatement(statement, atIndex: index)
    }
    
    static func fromSQLiteValue(value: SQLiteValue) -> DatabaseDate? {
        switch value {
        case .Double(let timestamp):
            return self.init(NSDate(timeIntervalSince1970: timestamp))
        default:
            // NULL, integer, text or blob:
            return nil
        }
    }
}

// Write

let dbDate = DatabaseDate(NSDate())
try db.execute("INSERT INTO persons (..., creationTimestamp) " +
                            "VALUES (..., ?)",
                          bindings: [..., dbDate])

// Read from row

let row = db.fetchOneRow("SELECT * FROM persons")!
let dbDate: DatabaseDate? = row.value(named: "creationTimestamp")

// Direct read

let dbDate = db.fetchOne(DatabaseDate.self, "SELECT creationTimestamp ...")!
```


## Migrations

Migrations are a convenient way to alter your database schema over time in a consistent and easy way. Define them with a DatabaseMigrator:

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

`RowModel` is a class that wraps a database row. *It is designed to be subclassed.*

We'll illustrate its features with the Person class below. Note how it declares properties for the `persons` table seen above:

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

You opt in RowModel services by overriding methods.

By overriding `updateFromDatabaseRow`, you can load persons:

```swift
class Person : RowModel {
    ...
    
    // Boring and not DRY, but straightforward and trivial:
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("id") {
            id = row.value(named: "id")
        }
        if row.hasColumn("name") {
            name = row.value(named: "name")
        }
        if row.hasColumn("age") {
            age = row.value(named: "age")
        }
        if row.hasColumn("creationTimestamp") {
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


**Subclass with ad-hoc classes** when iterating custom queries:

We think that this is the killer feature of GRDB.swift :bowtie:

```swift
class PersonsViewController: UITableViewController {
    
    let persons: [PersonViewModel]?
    
    // Subclass Person, with an extra `petCount`:
    
    private class PersonViewModel : Person {
        var petCount: Int?
        
        override func updateFromDatabaseRow(row: Row) {
            super.updateFromDatabaseRow(row)
            
            if row.hasColumn("petCount") {
                petCount = row.value(named: "petCount")
            }
        }
    }
    
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

CUD operations require two more methods:

```swift
class Person : RowModel {
    ...

    override class var databaseTableName: String? {
        return "persons"
    }
    
    override var databaseDictionary: [String: DatabaseValue?] {
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
    
    override func insert(db: Database) throws {
        if creationDate == nil {
            creationDate = NSDate()
        }
        
        try super.insert(db)
    }
}
```
