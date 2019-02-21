SQL Interpolation
=================

- [Introduction]
- [SQLLiteral]
- [SQL Interpolation and Record Protocols]
- [SQL Interpolation Reference]

## Introduction

**SQL Interpolation**, available in Swift 5, lets you embed values in your SQL queries by wrapping them inside `\(` and `)`:

```swift
let name: String = ...
let id: Int64 = ...
try db.execute(literal: "UPDATE player SET name = \(name) WHERE id = \(id)")
```

SQL interpolation looks and feel just like regular [Swift interpolation]:

```swift
let name = "World"
print("Hello \(name)!") // prints "Hello World!"
```

The difference is that it generates valid SQL which does not suffer from syntax errors or [SQL injection]. For example, you do not need to validate input or process single quotes:

```swift
// Executes `UPDATE player SET name = 'O''Brien' WHERE id = 42`
let name = "O'Brien"
let id = 42
try db.execute(literal: "UPDATE player SET name = \(name) WHERE id = \(id)")
```

Under the hood, SQL interpolation generates a plain SQL string, as well as [statement arguments]. It runs exactly as below:

```swift
try db.execute(sql: "UPDATE player SET name = ? WHERE id = ?", arguments: [name, id])
```

Plain SQL strings are indeed still available, and SQL interpolation only kicks in when you ask for it. There is a simple rule to remember:

- For raw SQL strings, you will always use the `sql` argument label:

    ```swift
    // sql: Plain SQL string
    try db.execute(sql: "UPDATE player SET name = ? WHERE id = ?", arguments: [name, id])
    ```

- For SQL interpolation, you will always use the `literal` argument label:

    ```swift
    // literal: SQL Interpolation
    try db.execute(literal: "UPDATE player SET name = \(name) WHERE id = \(id)")
    ```


## SQLLiteral

**SQLLiteral** is the type that looks like a plain String, but profits from SQL interpolation:

```swift
let query: SQLLiteral = "UPDATE player SET name = \(name) WHERE id = \(id)"
try db.execute(literal: query)
```

**SQLLiteral is not a Swift String.** You can not use the `execute(literal:)` method with a String argument:

```swift
// Compiler error:
// Cannot convert value of type 'String' to expected argument type 'SQLLiteral'
let query = "UPDATE player SET name = \(name) WHERE id = \(id)" // a String
try db.execute(literal: query)
```

SQLLiteral can build your queries step by step, with regular operators and methods:

```swift
// +, +=, append(literal:)
var query: SQLLiteral = "UPDATE player "
query += "SET name = \(name) "
query.append(literal: "WHERE id = \(id)")

// joined(), joined(separator:)
let components: [SQLLiteral] = [
    "UPDATE player",
    "SET name = \(name)",
    "WHERE id = \(id)"
]
let query = components.joined(separator: " ")
```

Extract the plain SQL string from a literal:

```swift
let query: SQLLiteral = "UPDATE player SET name = \(name) WHERE id = \(id)"
print(query.sql)       // prints "UPDATE player SET name = ? WHERE id = ?"
print(query.arguments) // prints ["O'Brien", 42]
```

Build a literal from a plain SQL string:

```swift
let query = SQLLiteral(
    sql: "UPDATE player SET name = ? WHERE id = ?",
    arguments: [name, id])
```

SQLLiteral can embed any [value], as we have seen above, but not only. Please keep on reading the next chapter, or jump directly to the [SQL Interpolation Reference].


## SQL Interpolation and Record Protocols

The [record protocols] extend your application types with database abilities.

For example, when a type adopts both [FetchableRecord] and [Decodable], it can right away decode raw database rows:

```swift
struct Player {
    var id: Int64
    var name: String
    var score: Int?
}

extension Player: FetchableRecord, Decodable { }
let players = try Player.fetchAll(db, sql: "SELECT * FROM player") // [Player]
```

Add [TableRecord], and the type knows its database table:
    
```swift
extension Player: TableRecord {
    static let databaseTableName = "player"
}
```

**Such a record type contains a lot of information about the schema of the underlying database table**. The `databaseTableName` property contains the table name. [Coding keys] contain the column names.

SQL Interpolation puts this knowledge to good use, so that you can build robust queries that consistently use correct table and column names:

```swift
extension Player {
    /// Deletes all player with no score
    static func deleteAllWithoutScore(_ db: Database) throws {
        try db.execute(literal: "DELETE FROM \(self) WHERE \(CodingKeys.score) IS NULL")
    }
    
    /// The player with a given id
    static func filter(id: Int64) -> SQLRequest<Player> {
        return "SELECT * FROM \(self) WHERE \(CodingKeys.id) = \(id)"
    }
    
    /// All players with the given ids
    static func filter(ids: [Int64]) -> SQLRequest<Player> {
        return "SELECT * FROM \(self) WHERE \(CodingKeys.id) IN \(ids)"
    }
    
    /// The maximum score
    static func maximumScore() -> SQLRequest<Int> {
        return "SELECT MAX(\(CodingKeys.score)) FROM \(self)"
    }
    
    /// All players whose score is the maximum score
    static func leaders() -> SQLRequest<Player> {
        return """
            SELECT * FROM \(self)
            WHERE \(CodingKeys.score) = \(maximumScore())
            """
    }
    
    /// A complex request
    static func complexRequest() -> SQLRequest<Player> {
        let query: SQLLiteral = "SELECT * FROM \(self) "
        query += "JOIN \(Team.self) ON ..."
        query += "GROUP BY ..."
        return SQLRequest(literal: query)
    }
}
```

Let's breakdown each one of those methods.

- `deleteAllWithoutScore(_:)`
    
    ```swift
    extension Player {
        /// Deletes all player with no score
        static func deleteAllWithoutScore(_ db: Database) throws {
            try db.execute(literal: "DELETE FROM \(self) WHERE \(CodingKeys.score) IS NULL")
        }
    }
    ```
    
    Usage:
    
    ```swift
    try dbQueue.write { db in
        // DELETE FROM player WHERE score IS NULL
        try Player.deleteAllWithoutScore(db)
    }
    ```
    
    `DELETE FROM \(self) ...` embeds the Player type itself. Since Player adopts the [TableRecord] protocol, this embeds `Player.databaseTableName` in the SQL query.
    
    `... \(CodingKeys.score) IS NULL` embeds CodingKeys.score. This one has been synthesized by the Swift compiler because Player adopts the Decodable protocol. It embeds the column name in the SQL query.

- `filter(id:)`

    ```swift
    extension Player {
        /// The player with a given id
        static func filter(id: Int64) -> SQLRequest<Player> {
            return "SELECT * FROM \(self) WHERE \(CodingKeys.id) = \(id)"
        }
    }
    ```
    
    Usage:
    
    ```swift
    let player = try dbQueue.read { db in
        // SELECT * player WHERE id = 42
        try Player.filter(id: 42).fetchOne(db) // Player?
    }
    ```
    
    The return type of this method is `SQLRequest<Player>`. It is one of the GRDB [request types]. And it profits from SQL interpolation: this is why this method can return a string literal.
    
    It embeds `\(self)` (the Player type which adopts the TableRecord protocol) and `\(CodingKeys.id)` (the coding key synthesized by the Decodable protocol), and `\(id)` (a [value]).

- `filter(ids:)`
    
    ```swift
    extension Player {
        /// All players with the given ids
        static func filter(ids: [Int64]) -> SQLRequest<Player> {
            return "SELECT * FROM \(self) WHERE \(CodingKeys.id) IN \(ids)"
        }
    }
    ```
    
    Usage:
    
    ```swift
    let players = try dbQueue.read { db in
        // SELECT * player WHERE id IN (1, 2, 3)
        try Player.filter(ids: [1, 2, 3]).fetchAll(db) // [Player]
    }
    ```
    
    It embeds `\(ids)`, an array of ids. All [value] sequences are supported (arrays, sets, etc.) Empty sequences are supported as well, with both `IN` and `NOT IN` SQL operators.

- `maximumScore()`
    
    ```swift
    extension Player {
        /// The maximum score
        static func maximumScore() -> SQLRequest<Int> {
            return "SELECT MAX(\(CodingKeys.score)) FROM \(self)"
        }
    }
    ```
    
    Usage:
    
    ```swift
    let maximumScore = try dbQueue.read { db in
        // SELECT MAX(score) FROM player
        try Player.maximumScore().fetchOne(db) // Int?
    }
    ```
    
    The result is `SQLRequest<Int>`, unlike previous requests of type `SQLRequest<Player>`. SQLRequest accepts any fetchable type (database [row], simple [value], or custom [record]).

- `leaders()`
    
    ```swift
    extension Player {
        /// All players whose score is the maximum score
        static func leaders() -> SQLRequest<Player> {
            return """
                SELECT * FROM \(self)
                WHERE \(CodingKeys.score) = \(maximumScore())
                """
        }
    }
    ```
    
    Usage:
    
    ```swift
    let leaders = try dbQueue.read { db in
        // SELECT * FROM player
        // WHERE score = (SELECT MAX(score) FROM player)
        try Player.leaders().fetchAll(db) // [Player]
    }
    ```
    
    This request embeds `\(maximumScore())`, the `SQLRequest<Int>` returned by the `maximumScore` method. After values, coding keys, and types that adopt the TableRecord protocol, this ends our quick tour of things you can embed between `\(` and `)`. Check out the [SQL Interpolation Reference] for the full list of supported interpolations.

- `complexRequest()`

    ```swift
    extension Player {
        /// A complex request
        static func complexRequest() -> SQLRequest<Player> {
            let query: SQLLiteral = "SELECT * FROM \(self) "
            query += "JOIN \(Team.self) ON ..."
            query += "GROUP BY ..."
            return SQLRequest(literal: query)
        }
    }
    ```
    
    This last request shows how to build an SQLRequest from an [SQLLiteral]. You will need SQLLiteral when the request can not be expressed in a single "SQL literal".



## SQL Interpolation Reference

This chapter lists all kinds of supported interpolations.

- Plain SQL strings and eventual arguments

    ```swift
    // SELECT * FROM player
    "SELECT * FROM \(sql: "player")"
    
    // SELECT * FROM player WHERE name = 'O''Brien'
    "SELECT * FROM player WHERE \(sql: "name = ?", arguments: ["O'Brien"])"
    ```

- Types adopting the [TableRecord] protocol

    ```swift
    // SELECT * FROM player
    extension Player: TableRecord { }
    "SELECT * FROM \(Player.self)"
    ```

- [Expressions] and [values]

    ```swift
    // SELECT name FROM player
    "SELECT \(Column("name")) FROM player"
    
    // SELECT (score + 100) AS points FROM player
    let bonus = 100
    "SELECT \(Column("score") + bonus) AS points FROM player"
    
    // SELECT (score + 100) AS points FROM player
    "SELECT (score + \(bonus)) AS points FROM player"
    ```

- Coding keys

    ```swift
    // SELECT name FROM player
    "SELECT \(CodingKeys.name) FROM player"
    ```

- Sequences
    
    ```swift
    // SELECT * FROM player WHERE id IN (1, 2, 3)
    let ids = [1, 2, 3]
    "SELECT * FROM player WHERE id IN \(ids)"
    ```

- Orderings
    
    ```swift
    // SELECT * FROM player ORDER BY name DESC
    "SELECT * FROM player WHERE id IN \(Column("name").desc)"
    ```

- SQLLiteral

    ```swift
    // SELECT * FROM player WHERE name = 'O''Brien'
    let condition: SQLLiteral = "name = \("O'Brien")"
    "SELECT * FROM player WHERE \(literal: condition)"
    ```

- SQLRequest
    
    ```swift
    // SELECT * FROM player WHERE score = (SELECT MAX(score) FROM player)
    let subQuery: SQLRequest<Int> = "SELECT MAX(score) FROM player"
    "SELECT * FROM player WHERE score = \(subQuery)"
    ```

[Introduction]: #introduction
[SQLLiteral]: #sqlliteral
[SQL Interpolation and Record Protocols]: #sql-interpolation-and-record-protocols
[SQL Interpolation Reference]: #sql-interpolation-reference
[Swift interpolation]: https://docs.swift.org/swift-book/LanguageGuide/StringsAndCharacters.html#ID292
[SQL injection]: ../README.md#avoiding-sql-injection
[record protocols]: ../README.md#record-protocols-overview
[FetchableRecord]: ../README.md#fetchablerecord-protocol
[TableRecord]: ../README.md#tablerecord-protocol
[Decodable]: ../README.md#codable-records
[Coding keys]: https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types
[value]: ../README.md#values
[values]: ../README.md#values
[request types]: ../README.md#custom-requests
[row]: ../README.md#row-queries
[record]: ../README.md#records
[Expressions]: ../README.md#expressions
[statement arguments]: http://groue.github.io/GRDB.swift/docs/3.6/Structs/StatementArguments.html