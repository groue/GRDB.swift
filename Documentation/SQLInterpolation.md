SQL Interpolation
=================

Your SQL skills are [welcomed] throughout GRDB. Yet writing raw SQL presents commonplace challenges. For example, you want to make sure your queries don't break whenever the database schema changes as you ship new versions of your application. When you inject user values in the database, you have to use statement arguments, and it is easy to make a mistake in the process.

The query below exemplifies this situation. It even contains a bug that is not quite easy to spot:

```swift
try db.execute(
    sql: """
        UPDATE student
        SET firstName = ?, lastName = ?, department = ?, birthDate = ?,
            registrationDate = ?, mainTeacherId = ?
        WHERE id = ?
        """,
    arguments: [firstName, lastName, department, birthDate,
                registrationDate, mainTeacherId])

```

SQL Interpolation is an answer to these troubles. It is available in Swift 5.

- [Introduction]
- [SQLLiteral]
- [SQL Interpolation and the Query Interface]
- [SQL Interpolation and Record Protocols]
- [SQL Interpolation Reference]


## Introduction

**SQL Interpolation** lets you embed values in your SQL queries by wrapping them inside `\(` and `)`:

```swift
let name: String = ...
let id: Int64 = ...
try db.execute(literal: "UPDATE player SET name = \(name) WHERE id = \(id)")
```

SQL interpolation looks and feel just like regular [String interpolation]:

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

Under the hood, SQL interpolation generates a plain SQL string. It runs exactly as below:

```swift
try db.execute(sql: "UPDATE player SET name = ? WHERE id = ?", arguments: [name, id])
```

Plain SQL strings are indeed still available, and SQL interpolation only kicks in when you ask for it. There is a simple rule to remember:

- For plain SQL strings, use the `sql` argument label:

    ```swift
    try db.execute(sql: "UPDATE player SET name = ? WHERE id = ?", arguments: [name, id])
    ```

- For SQL interpolation, use the `literal` argument label:

    ```swift
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
// +, +=, append
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


## SQL Interpolation and the Query Interface

SQL Interpolation and SQLLiteral let you embed raw SQL snippets in [query interface requests].

For example:

```swift
// SELECT * FROM player WHERE name = 'O''Brien'
let request = Player.filter(literal: "name = \("O'Brien")")

// SELECT * FROM "player" WHERE DATE("createdAt") = '2020-01-23'
let createdAt = Column("createdAt")
let creationDay = SQLLiteral("DATE(\(createdAt))").sqlExpression
let request = Player.filter(creationDay == "2020-01-23")
```


## SQL Interpolation and Record Protocols

The [record protocols] extend your application types with database abilities.

**A record type knows everything about the schema of its underlying database table**. With the [TableRecord] protocol, the `databaseTableName` property contains the table name. With the [Decodable] protocol, the [CodingKeys] enum contain the column names. And with [FetchableRecord], you can decode raw database rows.

SQL Interpolation puts this knowledge to good use, so that you can build robust queries that consistently use correct table and column names:

```swift
struct Player {
    var id: Int64
    var name: String
    var score: Int?
}

extension Player: Decodable, FetchableRecord, TableRecord {
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
    extension Player: Decodable, FetchableRecord, TableRecord {
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
    extension Player: Decodable, FetchableRecord, TableRecord {
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
    
    The return type of this method is `SQLRequest<Player>`. It is one of the GRDB [request types]. And it profits from SQL interpolation: this is why this method can simply return an "SQL literal"".
    
    It embeds `\(self)` (the Player type which adopts the TableRecord protocol) and `\(CodingKeys.id)` (the coding key synthesized by the Decodable protocol), and `\(id)` (a [value]).

- `filter(ids:)`
    
    ```swift
    extension Player: Decodable, FetchableRecord, TableRecord {
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
    extension Player: Decodable, FetchableRecord, TableRecord {
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
    extension Player: Decodable, FetchableRecord, TableRecord {
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
    extension Player: Decodable, FetchableRecord, TableRecord {
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

- Types adopting the [TableRecord] protocol:

    ```swift
    // SELECT * FROM player
    extension Player: TableRecord { }
    "SELECT * FROM \(Player.self)"
    
    // INSERT INTO player ...
    let player: Player = ...
    "INSERT INTO \(tableOf: player) ..."
    ```

- [Expressions] and [values]:

    ```swift
    // SELECT name FROM player
    "SELECT \(Column("name")) FROM player"
    
    // SELECT (score + 100) AS points FROM player
    let bonus = 100
    "SELECT \(Column("score") + bonus) AS points FROM player"
    
    // SELECT (score + 100) AS points FROM player
    "SELECT (score + \(bonus)) AS points FROM player"
    ```

- Coding keys:

    ```swift
    // SELECT name FROM player
    "SELECT \(CodingKeys.name) FROM player"
    ```

- Sequences:
    
    ```swift
    // SELECT * FROM player WHERE id IN (1, 2, 3)
    let ids = [1, 2, 3]
    "SELECT * FROM player WHERE id IN \(ids)"
    ```

- Orderings:
    
    ```swift
    // SELECT * FROM player ORDER BY name DESC
    "SELECT * FROM player WHERE id IN \(Column("name").desc)"
    ```

- SQLRequest:
    
    ```swift
    // SELECT * FROM player WHERE score = (SELECT MAX(score) FROM player)
    let subQuery: SQLRequest<Int> = "SELECT MAX(score) FROM player"
    "SELECT * FROM player WHERE score = \(subQuery)"
    ```

- SQLLiteral:

    ```swift
    // SELECT * FROM player WHERE name = 'O''Brien'
    let condition: SQLLiteral = "name = \("O'Brien")"
    "SELECT * FROM player WHERE \(literal: condition)"
    ```

- Plain SQL strings and eventual arguments:

    ```swift
    // SELECT * FROM player
    "SELECT * FROM \(sql: "player")"
    
    // SELECT * FROM player WHERE name = 'O''Brien'
    "SELECT * FROM player WHERE \(sql: "name = ?", arguments: ["O'Brien"])"
    ```

[Introduction]: #introduction
[SQLLiteral]: #sqlliteral
[SQL Interpolation and the Query Interface]: #sql-interpolation-and-the-query-interface
[SQL Interpolation and Record Protocols]: #sql-interpolation-and-record-protocols
[SQL Interpolation Reference]: #sql-interpolation-reference
[String interpolation]: https://docs.swift.org/swift-book/LanguageGuide/StringsAndCharacters.html#ID292
[SQL injection]: ../README.md#avoiding-sql-injection
[record protocols]: ../README.md#record-protocols-overview
[FetchableRecord]: ../README.md#fetchablerecord-protocol
[TableRecord]: ../README.md#tablerecord-protocol
[Decodable]: ../README.md#codable-records
[CodingKeys]: https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types
[value]: ../README.md#values
[values]: ../README.md#values
[request types]: ../README.md#custom-requests
[row]: ../README.md#row-queries
[record]: ../README.md#records
[Expressions]: ../README.md#expressions
[welcomed]: ../README.md#sqlite-api
[query interface requests]: ../README.md#requests
[SE-0228 Fix ExpressibleByStringInterpolation]: https://github.com/apple/swift-evolution/blob/master/proposals/0228-fix-expressiblebystringinterpolation.md
