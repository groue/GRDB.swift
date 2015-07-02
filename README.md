GRDB
====

A sqlite3 wrapper for Swift 2.

## Goals

- [RAII](https://en.wikipedia.org/wiki/Resource_Acquisition_Is_Initialization)
- Leverage the Swift standard library (errors, generators, etc.)
- Foster SQL
- Focus on rows, not on tables.


## Inspirations

- [ccgus/FMDB](https://github.com/ccgus/fmdb)


## Usage (work in progress)

```swift
// GRDB uses database queues for database accesses serialization,
// just like ccgus/FMDB:

let dbQueue = try DatabaseQueue(path: "/tmp/GRDB.sqlite")


// DatabaseMigrator sets up migrations:

var migrator = DatabaseMigrator()
migrator.registerMigration("createPersons") { db in
    try db.execute(
        "CREATE TABLE persons (" +
            "id INTEGER PRIMARY KEY, " +
            "name TEXT, " +
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
        "name TEXT)")
}

try migrator.migrate(dbQueue)


// Transactions:

try dbQueue.inTransaction { db in
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (?, ?)",
        bindings: ["Arthur", 36])
    
    try db.execute(
        "INSERT INTO persons (name, age) VALUES (:name, :age)",
        bindings: [":name": "Barbara", ":age": 37])
    
    return .Commit
}


// Fetching rows and values:

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
    
    // Value sequences require explicit `type` parameter
    for name in db.fetch(String.self, "SELECT name FROM persons") {
        // name is `String?` because some rows may have a NULL name.
        print(name)
    }
}


// Extracting values out of a database block:

let names = dbQueue.inDatabase { db in
    db.fetch(String.self, "SELECT name FROM persons ORDER BY name").map { $0! }
}
// names is [String]: ["Arthur", "Barbara"]
```
