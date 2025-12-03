The Query Interface
===================

**The query interface lets you write pure Swift instead of SQL:**

```swift
try dbQueue.write { db in
    // Update database schema
    try db.create(table: "player") { t in ... }

    // Fetch records
    let bestPlayers = try Player
        .order(\.score.desc)
        .limit(10)
        .fetchAll(db)

    // Count
    let count = try Player
        .filter { $0.score >= 1000 }
        .fetchCount(db)

    // Batch update
    try Player
        .filter { $0.team == "Reds" }
        .updateAll(db) { $0.score += 100 }

    // Batch delete
    try Player
        .filter { $0.score == 0 }
        .deleteAll(db)
}
```

You need to open a [database connection](DatabaseConnections.md) before you can query the database.

Please bear in mind that the query interface can not generate all possible SQL queries. You may also *prefer* writing SQL, and this is just OK. From little snippets to full queries, your SQL skills are welcome:

```swift
try dbQueue.write { db in
    // Update database schema (with SQL)
    try db.execute(sql: "CREATE TABLE player (...)")

    // Fetch records (with SQL)
    let bestPlayers = try Player.fetchAll(db, sql: """
        SELECT * FROM player ORDER BY score DESC LIMIT 10
        """)

    // Count (with an SQL snippet)
    let minScore = 1000
    let count = try Player
        .filter(sql: "score >= ?", arguments: [minScore])
        .fetchCount(db)

    // Update (with SQL)
    try db.execute(sql: "UPDATE player SET score = score + 100 WHERE team = 'Reds'")

    // Delete (with SQL)
    try db.execute(sql: "DELETE FROM player WHERE score = 0")
}
```

So don't miss the [SQL API](SQLiteAPI.md).

> **Note**: the generated SQL may change between GRDB releases, without notice: don't have your application rely on any specific SQL output.

- [The Database Schema](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseschema)
- [Requests](#requests)
- [Expressions](#expressions)
    - [SQL Operators](#sql-operators)
    - [SQL Functions](#sql-functions)
- [Embedding SQL in Query Interface Requests](#embedding-sql-in-query-interface-requests)
- [Fetching from Requests](#fetching-from-requests)
- [Fetching by Key](#fetching-by-key)
- [Testing for Record Existence](#testing-for-record-existence)
- [Fetching Aggregated Values](#fetching-aggregated-values)
- [Delete Requests](#delete-requests)
- [Update Requests](#update-requests)
- [Custom Requests](#custom-requests)
- :blue_book: [Associations and Joins](AssociationsBasics.md)
- :blue_book: [Common Table Expressions](CommonTableExpressions.md)
- :blue_book: [Query Interface Organization](QueryInterfaceOrganization.md)

## Requests

**The query interface requests** let you fetch values from the database:

```swift
let request = Player.filter { $0.email != nil }.order(\.name)
let players = try request.fetchAll(db)  // [Player]
let count = try request.fetchCount(db)  // Int
```

Query interface requests usually start from **a type** that adopts the `TableRecord` protocol:

```swift
struct Player: TableRecord { ... }

// The request for all players:
let request = Player.all()
let players = try request.fetchAll(db) // [Player]
```

When you can not use a record type, use `Table`:

```swift
// The request for all rows from the player table:
let table = Table("player")
let request = table.all()
let rows = try request.fetchAll(db)    // [Row]

// The request for all players from the player table:
let table = Table<Player>("player")
let request = table.all()
let players = try request.fetchAll(db) // [Player]
```

Next, declare the table **columns** that you want to use for filtering, or sorting, in a nested type named `Columns`:

```swift
extension Player {
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
    }
}
```

When `Player` is `Codable`, you'll prefer defining columns from coding keys:

```swift
extension Player {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
    }
}
```

You can now build requests with the following methods: `all`, `none`, `select`, `distinct`, `filter`, `matching`, `group`, `having`, `order`, `reversed`, `limit`, `joining`, `including`, `with`. All those methods return another request, which you can further refine by applying another method: `Player.select(...).filter(...).order(...)`.

- [`all()`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/tablerecord/all()), [`none()`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/tablerecord/none()): the requests for all rows, or no row.

- [`select(...)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/selectionrequest/select(_:)-ruzy) and [`select(..., as:)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/queryinterfacerequest/select(_:as:)-58954) define the selected columns. See [Columns Selected by a Request](#columns-selected-by-a-request).

- [`filter(expression)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/filteredrequest/filter(_:)-6xr3d) applies conditions.

- [`order(ordering, ...)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/orderedrequest/order(_:)-9d0hr) sorts.

- [`limit(limit, offset: offset)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/queryinterfacerequest/limit(_:offset:)) limits and pages results.

- [`joining(required:)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/joinablerequest/joining(required:)), [`joining(optional:)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/joinablerequest/joining(optional:)), [`including(required:)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/joinablerequest/including(required:)), [`including(optional:)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/joinablerequest/including(optional:)), and [`including(all:)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/joinablerequest/including(all:)) fetch and join records through [Associations](AssociationsBasics.md).

```swift
// SELECT * FROM player WHERE (email IS NOT NULL) ORDER BY name
Player.order(\.name).filter { $0.email != nil }
```


### Columns Selected by a Request

By default, query interface requests select all columns:

```swift
// SELECT * FROM player
struct Player: TableRecord { ... }
let request = Player.all()
```

**The selection can be changed for each individual requests, or in the case of record-based requests, for all requests built from this record type.**

The `select(...)` and `select(..., as:)` methods change the selection of a single request (see [Fetching from Requests](#fetching-from-requests) for detailed information):

```swift
let request = Player.select { max($0.score) }
let maxScore = try Int.fetchOne(db, request) // Int?

let request = Player.select({ max($0.score) }, as: Int.self)
let maxScore = try request.fetchOne(db)      // Int?
```

The default selection for a record type is controlled by the `databaseSelection` property:

```swift
struct RestrictedPlayer: TableRecord {
    static let databaseTableName = "player"

    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
    }

    static var databaseSelection: [any SQLSelectable] {
        [Columns.id, Columns.name]
    }
}

// SELECT id, name FROM player
let request = RestrictedPlayer.all()
```


## Expressions

Feed [requests](#requests) with SQL expressions built from your Swift code:


### SQL Operators

GRDB comes with a Swift version of many SQLite [built-in operators](https://sqlite.org/lang_expr.html#operators), listed below. But not all: see [Embedding SQL in Query Interface Requests](#embedding-sql-in-query-interface-requests) for a way to add support for missing SQL operators.

- `=`, `<>`, `<`, `<=`, `>`, `>=`, `IS`, `IS NOT`

    Comparison operators are based on the Swift operators `==`, `!=`, `===`, `!==`, `<`, `<=`, `>`, `>=`:

    ```swift
    // SELECT * FROM player WHERE (name = 'Arthur')
    Player.filter { $0.name == "Arthur" }

    // SELECT * FROM player WHERE (name IS NULL)
    Player.filter { $0.name == nil }

    // SELECT * FROM player WHERE (score IS 1000)
    Player.filter { $0.score === 1000 }
    ```

- `*`, `/`, `+`, `-`

    SQLite arithmetic operators are derived from their Swift equivalent:

    ```swift
    // SELECT ((temperature * 1.8) + 32) AS fahrenheit FROM planet
    Planet.select { ($0.temperature * 1.8 + 32).forKey("fahrenheit") }
    ```

- `AND`, `OR`, `NOT`

    The SQL logical operators are derived from the Swift `&&`, `||` and `!`:

    ```swift
    // SELECT * FROM player WHERE ((NOT isVerified) OR (score < 1000))
    Player.filter { !$0.isVerified || $0.score < 1000 }
    ```

- `BETWEEN`, `IN`, `NOT IN`

    To check inclusion in a Swift sequence (array, set, range...), call the `contains` method:

    ```swift
    // SELECT * FROM player WHERE id IN (1, 2, 3)
    Player.filter { [1, 2, 3].contains($0.id) }

    // SELECT * FROM player WHERE score BETWEEN 0 AND 1000
    Player.filter { (0...1000).contains($0.score) }
    ```

- `LIKE`

    The SQLite LIKE operator is available as the `like` method:

    ```swift
    // SELECT * FROM player WHERE (email LIKE '%@example.com')
    Player.filter { $0.email.like("%@example.com") }
    ```


### SQL Functions

GRDB comes with a Swift version of many SQLite [built-in functions](https://sqlite.org/lang_corefunc.html), listed below. But not all: see [Embedding SQL in Query Interface Requests](#embedding-sql-in-query-interface-requests) for a way to add support for missing SQL functions.

- `ABS`, `AVG`, `COALESCE`, `COUNT`, `DATETIME`, `JULIANDAY`, `LENGTH`, `MAX`, `MIN`, `SUM`, `TOTAL`:

    Those are based on the `abs`, `average`, `coalesce`, `count`, `dateTime`, `julianDay`, `length`, `max`, `min`, `sum`, and `total` Swift functions:

    ```swift
    // SELECT MIN(score), MAX(score) FROM player
    Player.select { [min($0.score), max($0.score)] }

    // SELECT COUNT(name) FROM player
    Player.select { count($0.name) }

    // SELECT COUNT(DISTINCT name) FROM player
    Player.select { count(distinct: $0.name) }
    ```

- `IFNULL`

    Use the Swift `??` operator:

    ```swift
    // SELECT IFNULL(name, 'Anonymous') FROM player
    Player.select { $0.name ?? "Anonymous" }
    ```

- Custom SQL functions and aggregates

    You can apply your own [custom SQL functions and aggregates](CustomSQLFunctions.md):

    ```swift
    let myFunction = DatabaseFunction("myFunction", ...)

    // SELECT myFunction(name) FROM player
    Player.select { myFunction($0.name) }
    ```

## Embedding SQL in Query Interface Requests

You will sometimes want to extend your query interface requests with SQL snippets. This can happen because GRDB does not provide a Swift interface for some SQL function or operator, or because you want to use an SQLite construct that GRDB does not support.

The selection, WHERE, GROUP BY, HAVING, and ORDER BY clauses can be provided as raw SQL:

```swift
// SELECT IFNULL(name, 'O''Brien'), score FROM player
let request = Player.select(sql: "IFNULL(name, 'O''Brien'), score")

// SELECT * FROM player WHERE score >= 1000
let minScore = 1000
let request = Player.filter(sql: "score >= ?", arguments: [minScore])
```

You can also use [SQL Interpolation](SQLInterpolation.md):

```swift
// SELECT IFNULL(name, 'O''Brien'), score FROM player
let defaultName = "O'Brien"
let request = Player.select(literal: "IFNULL(name, \(defaultName)), score")

// SELECT * FROM player WHERE score >= 1000
let minScore = 1000
let request = Player.filter(literal: "score >= \(minScore)")
```


## Fetching from Requests

Once you have a request, you can fetch the records at the origin of the request:

```swift
// Some request based on `Player`
let request = Player.filter(...)... // QueryInterfaceRequest<Player>
let players = try request.fetchAll(db) // [Player]
```

See [fetching methods](SQLiteAPI.md#fetching-methods) for information about the `fetchCursor`, `fetchAll`, `fetchSet` and `fetchOne` methods.

You sometimes want to fetch other values.

The simplest way is to use the `fetchCount` method, available on all requests:

```swift
let count = try request.fetchCount(db) // Int
```

You can change the fetched type with the `select(..., as:)` method:

```swift
// Fetch an Int
let request = Player.select({ max($0.score) }, as: Int.self)
if let maxScore = try request.fetchOne(db) {
    print("The maximum score is \(maxScore)")
}

// Fetch a Row
let request = Player.select({ [$0.id, $0.name] }, as: Row.self)
let rows = try request.fetchAll(db)
```


## Fetching by Key

**Fetching records according to their primary key** is a common task.

[Identifiable Records](Records.md#identifiable-records) are given the `find`, `fetchOne`, `fetchAll`, and `fetchSet` methods:

```swift
try Player.find(db, id: 1)                // Player
try Player.fetchOne(db, id: 1)            // Player?
try Country.fetchAll(db, ids: ["FR", "US"]) // [Country]
```

Records with a multi-column primary key, use a key dictionary:

```swift
let key: [String: DatabaseValueConvertible] = ["a": 1, "b": 2]
try Citizenship.fetchOne(db, key: key) // Citizenship?
```


## Testing for Record Existence

**You can check if a request has matching rows in the database.**

```swift
// Some request based on `Player`
let request = Player.filter(...)...

// Check for existence
let exists = try request.isEmpty(db) // Bool
```

[Identifiable Records](Records.md#identifiable-records) are given the `exists` method:

```swift
// Check for existence
let player = Player(id: 1, name: "Arthur")
let exists = try player.exists(db) // Bool
```


## Fetching Aggregated Values

**Requests can count.** The `fetchCount()` method returns the number of rows in the request:

```swift
// SELECT COUNT(*) FROM player
let count = try Player.fetchCount(db) // Int

// SELECT COUNT(*) FROM player WHERE email IS NOT NULL
let count = try Player.filter { $0.email != nil }.fetchCount(db)
```


## Delete Requests

**Requests can delete records**, with the `deleteAll()` method:

```swift
// DELETE FROM player
try Player.deleteAll(db)

// DELETE FROM player WHERE team = 'red'
try Player
    .filter { $0.team == "red" }
    .deleteAll(db)
```

[Identifiable Records](Records.md#identifiable-records) can be deleted by primary key:

```swift
try Player.deleteOne(db, id: 1)
try Player.deleteAll(db, ids: [1, 2, 3])
```


## Update Requests

**Requests can batch update records**. The `updateAll()` method accepts *column assignments* defined with the `set(to:)` method:

```swift
// UPDATE player SET score = 0, isHealthy = true
try Player.updateAll(db) { [$0.score.set(to: 0), $0.isHealthy.set(to: true)] }

// UPDATE player SET score = score + 1000 WHERE team = 'blue'
try Player
    .filter { $0.team == "blue" }
    .updateAll(db) { $0.score += 1000 }

// UPDATE player SET score = score * 2 WHERE score > 0
try Player
    .filter { $0.score > 0 }
    .updateAll(db) { $0.score *= 2 }
```


## Custom Requests

**When the query interface can not generate the SQL you need**, you can still fallback to [raw SQL](SQLiteAPI.md#fetch-queries):

```swift
// Custom SQL is always welcome
try Player.fetchAll(db, sql: "SELECT ...")   // [Player]
```

But you may prefer to bring some elegance back in, and build custom requests.

[`SQLRequest`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/sqlrequest) is a fetch request built from raw SQL:

```swift
extension Player {
    static func filter(color: Color) -> SQLRequest<Player> {
        SQLRequest<Player>(
            sql: "SELECT * FROM player WHERE color = ?"
            arguments: [color])
    }
}

// [Player]
try Player.filter(color: .red).fetchAll(db)
```

SQLRequest supports [SQL Interpolation](SQLInterpolation.md):

```swift
extension Player {
    static func filter(color: Color) -> SQLRequest<Player> {
        "SELECT * FROM player WHERE color = \(color)"
    }
}
```


## String Comparison

SQLite compares strings in many occasions: when you sort rows according to a string column, or when you use a comparison operator such as `=` and `<=`.

The comparison result comes from a *collating function*, or *collation*. SQLite comes with [three built-in collations](https://www.sqlite.org/datatype3.html#collation) that do not support Unicode. GRDB comes with built-in collations that leverage unicode-aware Swift methods.

A request can specify a comparison:

```swift
// SELECT * FROM "player" WHERE ("name" = 'foo' COLLATE NOCASE)
Player.filter { $0.name.collating(.nocase) == "foo" }

// SELECT * FROM "player" WHERE ("name" = 'Jérôme' COLLATE caseInsensitiveCompare)
Player.filter { $0.name.collating(.caseInsensitiveCompare) == "Jérôme" }

// SELECT * FROM "player" ORDER BY "name" COLLATE localized
Player.order { $0.name.collating(.localizedStandardCompare) }
```

See the [`collating(_:)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/sqlspecificexpressible/collating(_:)-2nqo4) method for more information.
