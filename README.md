GRDB
====

A sqlite3 wrapper for Swift 2.

Goals:

- [RAII](https://en.wikipedia.org/wiki/Resource_Acquisition_Is_Initialization)
- Leverage the Swift standard library (errors, generators, etc.)
- Foster SQL
- Focus on rows, not on tables.

Usage (work in progress):

```swift
let dbQueue = try DatabaseQueue(path: "/tmp/GRDB.sqlite")

try dbQueue.inTransaction { db -> Void in
    try db.execute("DROP TABLE IF EXISTS persons")
    try db.execute(
        "CREATE TABLE persons (" +
        "id INTEGER PRIMARY KEY, " +
        "name TEXT, " +
        "age INT)")
    try db.execute("INSERT INTO persons (name, age) VALUES (?, ?)", bindings: ["Arthur", 36])
    try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", bindings: [":name": "Barbara", ":age": 37])
}

try dbQueue.inDatabase { db -> Void in
    for row in try db.fetchRows("SELECT * FROM persons") {
        // Leverage Swift type inference
        let name: String? = row.value(atIndex: 1)
        
        // Force unwrap when column is NOT NULL
        let id: Int64 = row.value(named: "id")!
        
        // Both Int and Int64 are supported
        let age: Int? = row.value(named: "age")
        
        print("id: \(id), name: \(name), age: \(age)")
    }
    
    // Value sequences require explicit `type` parameter
    for name in try db.fetchValues("SELECT name FROM persons", type: String.self) {
        // name is `String?` because some rows may have a NULL name.
        print(name)
    }
}

// names is [String]: ["Arthur", "Barbara"]
let names = try dbQueue.inDatabase { db in
    try db.fetchValues("SELECT name FROM persons", type: String.self).map { $0! }
}

```

Inspirations:

- [ccgus/FMDB](https://github.com/ccgus/fmdb)
