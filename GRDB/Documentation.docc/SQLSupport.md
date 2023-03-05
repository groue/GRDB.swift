# SQL, Prepared Statements, Rows, and Values

SQL is the fundamental language for accessing SQLite databases.

## Overview

This section of the documentation focuses on low-level SQLite concepts: the SQL language, prepared statements, database rows and values.

If SQL is not your cup of tea, jump to <doc:QueryInterface> 🙂

## SQL Support

GRDB has a wide support for SQL.

Once connected with one of the <doc:DatabaseConnections>, you can execute raw SQL statements:

```swift
try dbQueue.write { db in
    try db.execute(sql: """
        INSERT INTO player (name, score) VALUES (?, ?);
        INSERT INTO player (name, score) VALUES (?, ?);
        """, arguments: ["Arthur", 500, "Barbara", 1000])
}
```

Build a prepared ``Statement`` and lazily iterate a ``DatabaseCursor`` of ``Row``:

```swift
try dbQueue.read { db in
    let sql = "SELECT id, score FROM player WHERE name = ?"  
    let statement = try db.makeStatement(sql: sql)
    let rows = try Row.fetchCursor(statement, arguments: ["O'Brien"])
    while let row = try rows.next() {
        let id: Int64 = row[0]
        let score: Int = row[1]
    }
}
```

Leverage ``SQLRequest`` and ``FetchableRecord`` for defining streamlined apis with powerful SQL interpolation features:

```swift
struct Player: Decodable {
    var id: Int64
    var name: String
    var score: Int
}

extension Player: FetchableRecord {
    static func filter(name: String) -> SQLRequest<Player> {
        "SELECT * FROM player WHERE name = \(name)"
    }

    static func maximumScore() -> SQLRequest<Int> {
        "SELECT MAX(score) FROM player"
    }
}

try dbQueue.read { db in
    let players = try Player.filter(name: "O'Reilly").fetchAll(db) // [Player]
    let maxScore = try Player.maximumScore().fetchOne(db)          // Int?
}
```

For a more detailed overview, see [SQLite API](https://github.com/groue/GRDB.swift/blob/master/README.md#sqlite-api).

## Topics

### Fundamental Database Types

- ``Statement``
- ``Row``
- ``DatabaseValue``
- ``DatabaseCursor``

### SQL Literals and Requests

- ``SQL``
- ``SQLRequest``
- ``databaseQuestionMarks(count:)``

### Database Values

- ``DatabaseDateComponents``
- ``DatabaseValueConvertible``
- ``StatementColumnConvertible``

### Supporting Types

- ``Cursor``
- ``FetchRequest``
