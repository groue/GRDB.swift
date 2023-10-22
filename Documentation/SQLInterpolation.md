SQL Interpolation
=================

Your SQL skills are [welcomed] throughout GRDB. Yet writing raw SQL presents commonplace challenges. For example, you want to make sure your queries don't break whenever the database schema changes as you ship new versions of your application. When you inject user values in the database, you have to use statement arguments, and it is easy to make a mistake in the process.

The query below exemplifies this situation. It even contains a bug that is not quite easy to spot:

```swift
try dbQueue.write { db in
    try db.execute(
        sql: """
            UPDATE student
            SET firstName = ?, lastName = ?, department = ?, birthDate = ?,
                registrationDate = ?, mainTeacherId = ?
            WHERE id = ?
            """,
        arguments: [firstName, lastName, department, birthDate,
                    registrationDate, mainTeacherId])
}
```

SQL Interpolation is an answer to these troubles.

- [Introduction]
- [SQL Literal]
- [SQL Interpolation and the Query Interface]
- [SQL Interpolation and Record Protocols]
- [SQL Interpolation Reference]


## Introduction

**SQL Interpolation** lets you embed values in your SQL queries by wrapping them inside `\(` and `)`:

```swift
let name: String = ...
let id: Int64 = ...
try dbQueue.write { db in
    try db.execute(literal: "UPDATE player SET name = \(name) WHERE id = \(id)")
}
```

SQL interpolation looks and feel just like regular [String interpolation]:

```swift
let name = "World"
print("Hello \(name)!") // prints "Hello World!"
```

The difference is that it generates valid SQL which does not suffer from syntax errors or [SQL injection]. For example, you do not need to validate input or process single quotes:

```swift
let name = "O'Brien"
let id = 42
try dbQueue.write { db in
    // Executes `UPDATE player SET name = 'O''Brien' WHERE id = 42`
    try db.execute(literal: "UPDATE player SET name = \(name) WHERE id = \(id)")
}
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


## SQL Literal

**`SQL`** is the type that looks like a plain String, but profits from SQL interpolation:

```swift
try dbQueue.write { db in
    let query: SQL = "UPDATE player SET name = \(name) WHERE id = \(id)"
    try db.execute(literal: query)
}
```

**`SQL` is not a Swift String.** You can not use the `execute(literal:)` method with a String argument:

```swift
try dbQueue.write { db in
    let query = "UPDATE player SET name = \(name) WHERE id = \(id)" // a regular String
    // Compiler error:
    // Cannot convert value of type 'String' to expected argument type 'SQL'
    try db.execute(literal: query)
}
```

`SQL` can build your queries step by step, with regular operators and methods:

```swift
// +, +=, append
var query: SQL = "UPDATE player "
query += "SET name = \(name) "
query.append(literal: "WHERE id = \(id)")

// joined(), joined(separator:)
let components: [SQL] = [
    "UPDATE player",
    "SET name = \(name)",
    "WHERE id = \(id)"
]
let query = components.joined(separator: " ")
```

To extract the plain SQL string from a literal, you need a `Database` connection such as the one provided by the `read` and `write` methods:

```swift
try dbQueue.read { db in
    let query: SQL = "UPDATE player SET name = \(name) WHERE id = \(id)"
    let (sql, arguments) = try query.build(db)
    print(sql)       // prints "UPDATE player SET name = ? WHERE id = ?"
    print(arguments) // prints ["O'Brien", 42]
}
```

Build a literal from a plain SQL string:

```swift
let query = SQL(
    sql: "UPDATE player SET name = ? WHERE id = ?",
    arguments: [name, id])
```

`SQL` can embed any [value], as we have seen above, but not only. Please keep on reading the next chapter, or jump directly to the [SQL Interpolation Reference].


## SQL Interpolation and the Query Interface

SQL Interpolation and `SQL` let you embed raw SQL snippets in [query interface requests].

For example:

```swift
// SELECT * FROM player WHERE name = 'O''Brien'
let request = Player.filter(literal: "name = \("O'Brien")")
```

You can also build literals from other expressions. For example, let's call the `DATE` SQLite function on a query interface column:

```swift
// SELECT * FROM player WHERE DATE(createdAt) = '2020-01-23'
let createdAt = Column("createdAt")
let creationDay = SQL("DATE(\(createdAt))")
let request = Player.filter(creationDay == "2020-01-23")
```

Such literals play well with the query interface, even when several tables are involved with [associations](AssociationsBasics.md):

```swift
// SELECT player.*, team.*
// FROM player
// JOIN team ON team.id = player.teamID
// WHERE DATE(player.createdAt) = '2020-01-23'
//       ~~~~~~~~~~~~~~~~~~~~~~
//       automatic table disambiguation
let request = Player
    .filter(creationDay == "2020-01-23")
    .including(required: Player.team)
```

This allows you to define Swift functions that you can use in all circumstances:

```swift
func date(_ expression: SQLExpressible) -> SQLExpression {
    SQL("DATE(\(expression))").sqlExpression
}

let request = Player.filter(date(Column("createdAt")) == "2020-01-23")
```


## SQL Interpolation and Record Protocols

The [record protocols] extend your application types with database abilities.

**A record type knows everything about the schema of its underlying database table**. With the [TableRecord] protocol, the `databaseTableName` property contains the table name. With the [Decodable] protocol, the [CodingKeys] enum contain the column names. And with [FetchableRecord], you can decode raw database rows.

SQL Interpolation puts this knowledge to good use, so that you can build robust queries that consistently use correct table and column names. Let's start from this record:

```swift
struct Player {
    var id: Int64
    var name: String
    var score: Int?
}

extension Player: Decodable, TableRecord, FetchableRecord { }
```

Let's extend Player with database methods.

- `Player.deleteAllWithoutScore(_:)`
    
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

- `Player.filter(id:)`
    
    ```swift
    extension Player {
        /// "Simple" version
        static func filter(id: Int64) -> SQLRequest<Player> {
            "SELECT * FROM player WHERE id = \(id)"
        }
        
        /// "Future-proof" version
        static func filter(id: Int64) -> SQLRequest<Player> {
            """
            SELECT \(columnsOf: self)
            FROM \(self)
            WHERE \(CodingKeys.id) = \(id)
            """
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
    
    The return type of this method is `SQLRequest<Player>`. It is one of the GRDB [request types]. It profits from SQL interpolation, and this is why this method simply returns an "SQL literal"".
    
    The first "simple" version only embeds the `\(id)` [value].
    
    The second "robust" version embeds `\(columnsOf: self)`, the [columns selected by the record](#columns-selected-by-a-request), `\(self)` (the Player type which adopts the TableRecord protocol), `\(CodingKeys.id)` (the coding key synthesized by the Decodable protocol), and the `\(id)` [value].

- `filter(ids:)`
    
    ```swift
    extension Player: Decodable, FetchableRecord, TableRecord {
        /// "Simple" version
        static func filter(ids: [Int64]) -> SQLRequest<Player> {
            "SELECT * FROM player WHERE id IN \(ids)"
        }
        
        /// "Future-proof" version
        static func filter(ids: [Int64]) -> SQLRequest<Player> {
            """
            SELECT \(columnsOf: self)
            FROM \(self)
            WHERE \(CodingKeys.id) IN \(ids)
            """
        }
    }
    ```
    
    Usage:
    
    ```swift
    let players = try dbQueue.read { db in
        // SELECT * FROM player WHERE id IN (1, 2, 3)
        try Player.filter(ids: [1, 2, 3]).fetchAll(db) // [Player]
    }
    ```
    
    It embeds `\(ids)`, an array of ids. All [value] sequences are supported (arrays, sets, etc.) Empty sequences are supported as well, with both `IN` and `NOT IN` SQL operators.

- `maximumScore()`
    
    ```swift
    extension Player: Decodable, FetchableRecord, TableRecord {
        /// The maximum score
        static func maximumScore() -> SQLRequest<Int> {
            "SELECT MAX(\(CodingKeys.score)) FROM \(self)"
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

- `bestPlayers()`
    
    ```swift
    extension Player: Decodable, FetchableRecord, TableRecord {
        /// "Simple" version
        static func bestPlayers() -> SQLRequest<Player> {
            "SELECT * FROM player WHERE score = (\(maximumScore()))"
        }
        
        /// "Future-proof" version
        static func bestPlayers() -> SQLRequest<Player> {
            """
            SELECT \(columnsOf: self)
            FROM \(self)
            WHERE \(CodingKeys.score) = (\(maximumScore()))
            """
        }
    }
    ```
    
    Usage:
    
    ```swift
    let bestPlayers = try dbQueue.read { db in
        // SELECT * FROM player WHERE score = (SELECT MAX(score) FROM player)
        try Player.bestPlayers().fetchAll(db) // [Player]
    }
    ```
    
    This request embeds `\(maximumScore())`, the `SQLRequest<Int>` returned by the `maximumScore` method. After values, coding keys, and types that adopt the TableRecord protocol, this ends our quick tour of things you can embed between `\(` and `)`. Check out the [SQL Interpolation Reference] for the full list of supported interpolations.

- `complexRequest()`

    ```swift
    extension Player: Decodable, FetchableRecord, TableRecord {
        /// A complex request
        static func complexRequest() -> SQLRequest<Player> {
            let query: SQL = "SELECT \(columnsOf: self) "
            query += "FROM \(self) "
            query += "JOIN \(Team.self) ON ..."
            query += "GROUP BY ..."
            return SQLRequest(literal: query)
        }
    }
    ```
    
    This last request shows how to build an SQLRequest from an [SQL Literal]. You will need `SQL` when the request can not be written in a single stroke.



## SQL Interpolation Reference

This chapter lists all kinds of supported interpolations.

- Types adopting the [TableRecord] protocol and [Table](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/table) instances:

    ```swift
    struct Player: TableRecord { ... }
    
    // SELECT * FROM player
    "SELECT * FROM \(Player.self)"
    
    // SELECT * FROM player
    let player: Player = ...
    "SELECT * FROM \(tableOf: player) ..."

    // SELECT * FROM player
    let playerTable = Table("player")
    "SELECT * FROM \(playerTable)"
    ```

- Columns selected by [TableRecord]:

    ```swift
    struct Player: TableRecord { ... }
    
    // SELECT player.* FROM player
    "SELECT \(columnsOf: Player.self) FROM player"
    
    // SELECT p.* FROM player p
    "SELECT \(columnsOf: Player.self, tableAlias: "p") FROM player p"
    
    struct AltPlayer: TableRecord {
        static let databaseTableName = "player"
        static let databaseSelection: [any SQLSelectable] = [Column("id"), Column("name")]
    }
    
    // SELECT player.id, player.name FROM player
    "SELECT \(columnsOf: AltPlayer.self) FROM player"
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
    "SELECT * FROM player ORDER BY \(Column("name").desc)"
    ```

- Database Collations:

    ```swift
    "SELECT * FROM player ORDER BY email COLLATING \(.nocase)"
    "SELECT * FROM player ORDER BY email COLLATING \(.localizedCompare)"
    ```
    
- Subqueries:
    
    ```swift
    // SELECT * FROM player WHERE score = (SELECT MAX(score) FROM player)
    let subquery = SQLRequest("SELECT MAX(score) FROM player")
    "SELECT * FROM player WHERE score = (\(subquery))"
    
    // SELECT * FROM player WHERE score = (SELECT MAX(score) FROM player)
    let subquery = Player.select(max(Column("score")))
    "SELECT * FROM player WHERE score = (\(subquery))"
    ```

- Definition and table name of [common table Expressions]:
    
    ```swift
    // WITH name AS (SELECT 'O''Brien') SELECT * FROM name
    let cte = CommonTableExpression<Void>(
       named: "name",
       literal: "SELECT \("O'Brien")")
    "WITH \(definitionFor: cte) SELECT * FROM \(cte)"
    ```

- `SQL` literal:

    ```swift
    // SELECT * FROM player WHERE name = 'O''Brien'
    let condition: SQL = "name = \("O'Brien")"
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
[SQL Literal]: #sql-literal
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
[columns selected by the record]: ../README.md#columns-selected-by-a-request
[common table Expressions]: CommonTableExpressions.md
