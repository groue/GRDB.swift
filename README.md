GRDB.swift
==========

GRDB.swift is a Swift 2 library built around [SQLite](https://www.sqlite.org).

It ships with a low-level database API, plus application-level tools.


Features
--------

- **A low-level SQLite API** that leverages the Swift 2 standard library.
- **Migrations**
- **No ORM, no query builder**. Instead, a thin class that wraps query results, and helps people who like customizing their SQL queries.


## Usage (work in progress)

**Database queues** safely serialize database accesses (inspired by [ccgus/FMDB](https://github.com/ccgus/fmdb)):

```swift
let dbQueue = try DatabaseQueue(path: "/tmp/GRDB.sqlite")
```

**Migrations** are a convenient way to alter your database schema over time in a consistent and easy way. Define them with a DatabaseMigrator:

```swift
var migrator = DatabaseMigrator()

migrator.registerMigration("createPersons") { db in
    try db.execute(
        "CREATE TABLE persons (" +
        "id INTEGER PRIMARY KEY, " +
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


**Transactions** wrap the queries that alter the database content:

```swift
try dbQueue.inTransaction { db in
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (?, ?)",
        bindings: ["Arthur", 36])
    
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (:name, :age)",
        bindings: [":name": "Barbara", ":age": 37])
    
    return .Commit
}
```


**Fetch Queries** load database rows:

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

**Fetch values**:

```swift
dbQueue.inDatabase { db in
    
    // Use explicit type to load values, like `String.self` below:
    
    db.fetch(String.self, "SELECT name FROM persons")   // AnySequence[String?]
    db.fetchAll(String.self, "SELECT ...")              // [String?]
    db.fetchOne(String.self, "SELECT ...")              // String?
}
```

GRDB.swift ships with built-in support for `Bool`, `Int`, `Int64`, `Double` and `String`.

The protocol `DatabaseValue` makes this list extensible:

```swift
struct DatabaseDate: DatabaseValue {
    let date: NSDate
    
    init(_ date: NSDate) {
        self.date = date
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

let date = NSDate()
try db.execute("INSERT INTO dates (timestamp) VALUES (?)", bindings: [DatabaseDate(date)])

// Read from row

let row = db.fetchOneRow("SELECT creationTimestamp FROM stuffs")!
let date: DatabaseDate = row.value(atIndex: 0)!

// Direct read

let date = db.fetchOne(DatabaseDate.self, "SELECT timestamp FROM stuffs")!
```


**Row Models** wrap rows:

```swift
class Person: RowModel {
    var id: Int64?
    var name: String?
    var age: Int?
    
    // Boring and not very DRY, but straightforward:
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("id") { id = row.value(named: "id") }
        if row.hasColumn("name") { name = row.value(named: "name") }
        if row.hasColumn("age") { age = row.value(named: "age") }
    }
}

let persons = dbQueue.inDatabase { db in
    db.fetch(Person.self, "SELECT * FROM persons")
}
```


Declare **Primary Key** in order to fetch a specific row model:

```swift
class Person: RowModel {
    ...

    override class var databasePrimaryKey: PrimaryKey {
        return .SQLiteRowID("id")
    }
}

let person = dbQueue.inDatabase { db in
    db.fetchOne(Person.self, primaryKey: 123)
}
```


**Insert, update and delete** with two more methods:

```swift
class Person: RowModel {
    ...

    override class var databaseTableName: String? {
        return "persons"
    }
    
    override var databaseDictionary: [String: DatabaseValue?] {
        return ["ID": ID, "name": name, "age": age]
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

**Subclass with ad-hoc classes** when iterating custom queries:

```swift
class PersonsViewController: UITableViewController {
    
    let persons: [Person]?
    
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
