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


**Fetch queries** allow you load full rows or typed values:

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
