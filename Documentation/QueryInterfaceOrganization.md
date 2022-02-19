Query Interface Organization
============================

**The [query interface] is a Swift API that approximates the [SQLite SELECT query grammar](https://sqlite.org/lang_select.html) through a hierarchy of values and protocols.**

This document exposes its inner organization, so that you can leverage the most of those types and protocols when you want it.

In the diagram below, protocols are pale blue and have rounded corners, and standard types are grey rectangles. Solid arrows read "inherits from", and dashed arrows read "produces". Generic types are marked as such, as well as "PATs" (protocols with associated types).

<img src="https://github.com/groue/GRDB.swift/raw/master/Documentation/Images/QueryInterfaceOrganization2.png" width="100%">

Diagram items are described below:

- [Association]
- [Column]
- [ColumnExpression]
- [DatabaseRegionConvertible]
- [DatabaseValue]
- [DatabaseValueConvertible]
- [DerivableRequest]
- [FetchRequest]
- [Int, String, Date…]
- [QueryInterfaceRequest]
- [SQL]
- [SQLExpression]
- [SQLExpressible]
- [SQLOrderingTerm]
- [SQLOrdering]
- [SQLRequest]
- [SQLSelectable]
- [SQLSelection]
- [SQLSpecificExpressible]
- [SQLSubquery]
- [SQLSubqueryable]

---

### Association

`Association` is the protocol for all [associations]. It is adopted by `BelongsToAssociation`, `HasManyAssociation`, etc. It conforms to [DerivableRequest].

```swift
protocol Association: DerivableRequest {
    associatedtype OriginRowDecoder
    func forKey(_ key: String) -> Self
}
```

Association has two sub-protocols:

```swift
protocol AssociationToOne: Association { }
protocol AssociationToMany: Association { }
```

`AssociationToMany`, adopted by `HasManyAssociation` and `HasManyThroughAssociation`, leverages [association aggregates].

### Column

`Column` is the type for database columns. It conforms to [ColumnExpression].

```swift
Column("name")
Column("id")
Column.rowID
```


### ColumnExpression

`ColumnExpression` is the protocol for database columns. It is adopted by [Column]. It conforms to [SQLSpecificExpressible].

```swift
protocol ColumnExpression: SQLSpecificExpressible {
    /// The name of a database column.
    var name: String { get }
}
```

Columns can be used, for example, to query database rows:

```swift
let row = try Row.fetchOne(db, sql: "SELECT 'Arthur' AS name")!
let name: String = try row[Column("name")] // "Arthur"
```

Columns are special expressions that allow some optimizations and niceties:

- Database observation: When a request is limited to a known list of rowids in a database table, changes applied to other rows do not trigger the observation. GRDB needs column expressions in order to apply this optimization:
    
    ```swift
    // Optimized Observations
    ValueObservation.tracking { db in
        try Player.fetchOne(db, id: 1)
        // or
        try Player.filter(Column("id") == 1).fetchOne(db)
    }
    
    // Non-optimized observations
    ValueObservation.tracking { db in
        try SQLRequest<Player>("SELECT * FROM player WHERE id = 1").fetchOne(db)
        // or
        try Player.filter(sql: "id = 1").fetchOne(db)
    }
    ```
    
-  SQL generation: when it generates SQL queries, GRDB appends `LIMIT 1` or not, depending on the primary key and unique indexes used on the queried table. GRDB needs column expressions in order to improve its SQL generation:
    
    ```swift
    // Nicer SQL
    // SELECT * FROM player WHERE id = 1
    try Player.fetchOne(db, id: 1)
    try Player.filter(Column("id") == 1).fetchOne(db)
    
    // Less nice SQL
    // SELECT * FROM player WHERE id = 1 LIMIT 1
    try Player.filter(sql: "id = 1").fetchOne(db)
    ```

### DatabaseRegionConvertible

`DatabaseRegionConvertible` is the protocol for observable requests. It is adopted by [FetchRequest].

```swift
protocol DatabaseRegionConvertible {
    func databaseRegion(_ db: Database) throws -> DatabaseRegion
}
```

DatabaseRegionConvertible feeds [DatabaseRegionObservation], which tracks database transactions that impact a particular database region:

```swift
let request = Player.all()
let observation = DatabaseRegionObservation(tracking: request)
let observer = try observation.start(in: dbQueue) { (db: Database) in
    print("Players were changed")
}
```

### DatabaseValue

`DatabaseValue` is the type for SQL values (integers, doubles, strings, blobs, and NULL). It conforms to [SQLSpecificExpressible].

You generally build a DatabaseValue from a [DatabaseValueConvertible] type:

```swift
1.databaseValue
"Hello".databaseValue
DatabaseValue.null
```

The query interface will sometimes not accept raw [SQLExpressible] values such as [Int, String, Date], etc. In this case, turn those values into DatabaseValue so that you leverage APIs that need [SQLSpecificExpressible]. For example:

```swift
// SQL: firstName || ' ' || lastName
let fullname = [
    Column("firstName"), 
    " ".databaseValue,
    Column("lastName"),
    ].joined(operator: .concat)
```

### DatabaseValueConvertible

`DatabaseValueConvertible` is the protocol for types that can provide [DatabaseValue]: SQL integers, doubles, strings, blobs, and NULL. It is adopted by [Int, String, Date], etc. It conforms to [SQLExpressible] because all SQL values are SQL expressions.

```swift
protocol DatabaseValueConvertible: SQLExpressible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns a value initialized from `dbValue`, if possible.
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self?
}
```

### DerivableRequest

`DerivableRequest` is the protocol for query interface requests and associations that can be refined. It is adopted by [QueryInterfaceRequest] and [Association].

```swift
protocol DerivableRequest: AggregatingRequest, FilteredRequest,
                           JoinableRequest, OrderedRequest,
                           SelectionRequest, TableRequest
{
    func distinct() -> Self
    func with<RowDecoder>(_ cte: CommonTableExpression<RowDecoder>) -> Self
}
```

- `AggregatingRequest` provides grouping methods such as `groupByPrimaryKey()`
- `FilteredRequest` provides filtering methods such as `filter(expression)` or `filter(id: value)`
- `JoinableRequest` provides association methods such as `joining(required: association)` or `including(all: association)`
- `OrderedRequest` provides ordering methods such as `order(ordering)` or `reversed()`
- `SelectionRequest` provides selection methods such as `select(selection)` or `annotated(with: selection)`
- `TableRequest` provides table targeting methods such as `aliased(tableAlias)`

DerivableRequest makes it possible to build reusable code snippets that apply to both requests and associations. You'll read more about it in the [Good Practices for Designing Record Types](GoodPracticesForDesigningRecordTypes.md) and [Associations](AssociationsBasics.md).

### FetchRequest

`FetchRequest` is the protocol for requests that can fetch. It is adopted by [QueryInterfaceRequest] and [SQLRequest]. It conforms to [SQLSubqueryable] and [DatabaseRegionConvertible].

```swift
protocol FetchRequest: SQLSubqueryable, DatabaseRegionConvertible {
    /// The type that tells how fetched database rows should be interpreted.
    associatedtype RowDecoder
    
    /// Returns a PreparedRequest that is ready to be executed.
    func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest
    
    /// Returns the number of rows fetched by the request.
    func fetchCount(_ db: Database) throws -> Int
}
```

FetchRequest can fetch values from the database as long as its `RowDecoder` associated type is `Row`, a [DatabaseValueConvertible] type, or a [FetchableRecord] type.

```swift
let row: Row? = try SQLRequest<Row>("SELECT * FROM player").fetchOne(db)
let players: [Player] = try Player.all().fetchAll(db)
```

FetchRequest usually executes a single SQL query:

```swift
// SELECT * FROM player
let request = Player.all()
try request.fetchAll(db)
```

This single SQL query is exposed through `makePreparedRequest(_:forSingleResult:)`:

```swift
let request = Player.all()
let preparedRequest = try request.makePreparedRequest(db)
print(preparedRequest.statement.sql) // SELECT * FROM player
```

But not all fetch requests execute a single SQL query. A [QueryInterfaceRequest] that involves [associations] can execute several:

```swift
// SELECT * FROM player
// SELECT * FROM award WHERE playerId IN (...)
struct PlayerInfo: Decodable, FetchableRecord {
    var player: Player
    var awards: [Award]
}
let playerInfos = try Player
    .including(all: Player.awards)
    .asRequest(of: PlayerInfo.self)
    .fetchAll(db)
```

Those supplementary SQL queries are an implementation detail of `PreparedRequest`, and are not currently exposed.

### Int, String, Date…

The basic value types conform to [DatabaseValueConvertible] so that they can feed database queries with [DatabaseValue]:

```swift
// SELECT * FROM player WHERE name = 'O''Brien'
//                                   ~~~~~~~~~~
Player.filter(Column("name") == "O'Brien")
```

### QueryInterfaceRequest

`QueryInterfaceRequest` is the type of fetch requests built by the GRDB query builder. It conforms to [FetchRequest] and [DerivableRequest].

It is generic on the type of fetched values:

```swift
struct PlayerInfo: Decodable, FetchableRecord {
    var player: Player
    var awards: [Award]
}

// QueryInterfaceRequest<Player>
let playerRequest = Player.all()

// QueryInterfaceRequest<String>
let nameRequest = Player.select(Column("name"), as: String.self)

// QueryInterfaceRequest<PlayerInfo>
let playerInfoRequest = Player
    .including(all: Player.awards)
    .asRequest(of: PlayerInfo.self)

try playerRequest.fetchAll(db)     // [Player]
try nameRequest.fetchAll(db)       // [String]
try playerInfoRequest.fetchAll(db) // [PlayerInfo]
```

For more information on QueryInterfaceRequest, see [Requests](../README.md#requests) and [Associations](AssociationsBasics.md).

### SQL

`SQL` is the type for SQL literals that support [SQL Interpolation]. It can feed all GRDB APIs that have a `literal` argument:

```swift
let literal: SQL = "SELECT * FROM player"
let request = SQLRequest<Player>(literal: literal)
let players: [Player] = try request.fetchAll(db)
```

`SQL` conforms to [SQLSpecificExpressible], and thus behaves as an [SQLite expression](https://sqlite.org/syntax/expr.html) by default:

```swift
let literal: SQL = "name = \("O'Brien")"
let request = Player.filter(literal)
let players: [Player] = try request.fetchAll(db)
```

:warning: **Warning**: Not all SQL snippets are expressions. It is not recommended to pass `SQL` literals around, or you may end up forgetting their content, and eventually generate invalid SQL. When possible, prefer building an explicit [SQLExpression], [SQLOrdering], [SQLSelection], [SQLRequest], or [SQLSubquery], depending on what you want to express:

```swift
// SQLExpression
SQL("name = \("O'Brien")").sqlExpression

// SQLOrdering
SQL("name DESC)").sqlOrdering

// SQLSelection
SQL("score + bonus AS total)").sqlSelection
SQL("*").sqlSelection

// SQLRequest
SQLRequest<Player>(literal: "SELECT * FROM player")

// SQLSubquery
SQLRequest(literal: "SELECT * FROM player").sqlSubquery
```

### SQLExpression

`SQLExpression` is the opaque type for all [SQLite expressions](https://sqlite.org/syntax/expr.html). It adopts [SQLSpecificExpressible], and is built from [SQLExpressible].

```swift
struct SQLExpression: SQLSpecificExpressible {
    // opaque implementation
}
```

Functions and methods that build an SQL expression should return an SQLExpression value:

```swift
// SELECT * FROM player WHERE LENGTH(name) > 0
let expression = length(Column("name")) > 0 // SQLExpression
Player.filter(expression)
```

When it looks like GRDB APIs are unable to build a particular expression, use [SQL]:

```swift
func date(_ value: SQLSpecificExpressible) -> SQLExpression {
    SQL("DATE(\(value))").sqlExpression
}

// SELECT * FROM player WHERE DATE(createdAt) = '2020-01-23'
let request = Player.filter(date(Column("createdAt")) == "2020-01-23")
```

This technique, based on [SQL Interpolation], is composable and works well even when several tables are involved. See how the `createdAt` column below is correctly attributed to the `player` table:

```swift
// SELECT player.*, team.* FROM player
// JOIN team ON team.id = player.teamId
// WHERE DATE(player.createdAt) = '2020-01-23'
let request = Player
    .filter(date(Column("createdAt")) == "2020-01-23")
    .including(required: Player.team)
```

### SQLExpressible

`SQLExpressible` is the protocol for all [SQLite expressions](https://sqlite.org/syntax/expr.html). It is adopted by [Column], [SQL], [SQLExpression], and also [Int, String, Date], etc. It has an `sqlExpression` property which returns an [SQLExpression].

```swift
protocol SQLExpressible {
    var sqlExpression: SQLExpression { get }
}
```

SQLExpressible-conforming types include types which are not directly related to SQL, such as [Int, String, Date], etc. Because of this, SQLExpressible has limited powers that prevent misuses and API pollution. For full-fledged SQL expressions, see [SQLSpecificExpressible]. For example, compare:

```swift
Player.filter(1)     // Compiler warning (will become an error in the next major release)
Player.select(1)     // Compiler error
Player.order("name") // Compiler error
length("name")       // Compiler error
"name".desc          // Compiler error
```

```swift
Player.filter(id: 1)           // OK
Player.filter(1.databaseValue) // Odd, but OK
Player.select(1.databaseValue) // Odd, but OK
Player.order(Column("name"))   // OK
length(Column("name"))         // OK
Column("name").desc            // OK
```

### SQLOrderingTerm

`SQLOrderingTerm` is the protocol for all [SQLite ordering terms](https://sqlite.org/syntax/ordering-term.html). It is adopted by [SQLSpecificExpressible]. It has an `sqlOrdering` property which returns an [SQLOrdering].

```swift
protocol SQLOrderingTerm {
    var sqlOrdering: SQLOrdering { get }
}
```

SQLOrderingTerm feeds the `order()` method of the query interface:

```swift
// SELECT * FROM player
// ORDER BY score DESC, name COLLATE ...
Player.order(
    Column("score").desc, 
    Column("name").collating(.localizedCaseInsensitiveCompare))
```

All [SQLSpecificExpressible] values are ordering terms. [SQLExpressible] values are not: `Player.order("name")` does not compile. Instead, use:

```swift
// SELECT * FROM player ORDER BY name   -- Order according to a column
Player.order(Column("name"))

// SELECT * FROM player ORDER BY 'name' -- Order according to a constant string (why not)
Player.order("name".databaseValue)
```

### SQLOrdering

`SQLOrdering` is the opaque type for all [SQLite ordering terms](https://sqlite.org/syntax/ordering-term.html). An SQLOrdering adopts and is built from [SQLOrderingTerm].

```swift
struct SQLOrdering: SQLOrderingTerm {
    // opaque implementation
}
```

Functions and methods that build ordering terms should return an SQLOrdering value:

```swift
// SELECT * FROM player ORDER BY score DESC
let ordering = Column("score").desc // SQLOrdering
Player.order(ordering)
```

To build an SQLOrdering without applying any `DESC` or `ASC` qualifier, use `sqlOrdering` (from [SQLOrderingTerm], inherited by [SQLSpecificExpressible], [ColumnExpression]...):

```swift
let ordering = Column("score").sqlOrdering // SQLOrdering
```

### SQLRequest

`SQLRequest` is the type of fetch requests expressed with raw SQL. It conforms to [FetchRequest].

It is generic on the type of fetched values (which defaults to `Row`):

```swift
let rowRequest = SQLRequest(sql: "SELECT * FROM player")             // SQLRequest<Row>
let playerRequest = SQLRequest<Player>(sql: "SELECT * FROM player")  // SQLRequest<Player>
let nameRequest = SQLRequest<String>(sql: "SELECT name FROM player") // SQLRequest<String>

try rowRequest.fetchAll(db)    // [Row]
try playerRequest.fetchAll(db) // [Player]
try nameRequest.fetchAll(db)   // [String]

try rowRequest.fetchOne(db)    // Row?
try playerRequest.fetchOne(db) // Player?
try nameRequest.fetchOne(db)   // String?
```

SQLRequest supports [SQL Interpolation]:

```swift
// SELECT * FROM player WHERE name = 'O''Brien'
let playerRequest: SQLRequest<Player> = """
    SELECT * FROM player WHERE name = \("O'Brien")
    """
```

### SQLSelectable

`SQLSelectable` is the protocol for all [SQLite result columns](https://sqlite.org/syntax/result-column.html). It is adopted by [SQLSpecificExpressible]. It has an `sqlSelection` property which returns an [SQLSelection].

```swift
protocol SQLSelectable {
    var sqlSelection: SQLSelection { get }
}
```

SQLSelectable feeds the `select()` method of the query interface:

```swift
Player.select(AllColumns())
Player.select(Column("name"), Column("score"))
```

All [SQLSpecificExpressible] values are selectable. Other selectable values are:

```swift
// SELECT * FROM player
Player.select(AllColumns())

// SELECT MAX(score) AS maxScore FROM player
Player.select(max(Column("score")).forKey("maxScore"))
```

[SQLExpressible] values are not selectable: `Player.select("name")` does not compile. Instead, use:

```swift
// SELECT name FROM player   -- Selects a column
Player.select(Column("name"))

// SELECT 'name' FROM player -- Selects a constant string (why not)
Player.select("name".databaseValue)
```

### SQLSelection

`SQLSelection` is the opaque type for all [SQLite result columns](https://sqlite.org/syntax/result-column.html). An SQLSelection adopts and is built from [SQLSelectable].

```swift
struct SQLSelection: SQLSelectable {
    // opaque implementation
}
```

Functions and methods that build result columns should return an SQLSelection value:

```swift
// SELECT (score + bonus) AS total
let selection = (Column("score") + Column("bonus")).forKey("total") // SQLSelection
Player.select(selection)
```

### SQLSpecificExpressible

`SQLSpecificExpressible` is the protocol for all SQL expressions, except values such as [Int, String, Date], etc. It conforms to [SQLExpressible], [SQLSelectable], and [SQLOrderingTerm]. It is adopted by [Column], [SQL], and [SQLExpression]. It is also adopted through [SQLSubqueryable] by [QueryInterfaceRequest] and [SQLRequest].

```swift
protocol SQLSpecificExpressible: SQLExpressible, SQLSelectable, SQLOrderingTerm { }
```

Use SQLSpecificExpressible when you want to operate on expressions, except [Int, String, Date] and other types which are not directly related to SQL. For example, the built-in `length(_:)` GRDB function accepts SQLSpecificExpressible:

```swift
/// The LENGTH SQL function
func length(_ value: SQLSpecificExpressible) -> SQLExpression { ... }

length(Column("name")) // OK
length("name")         // Compiler error
```

### SQLSubquery

`SQLSubquery` is the opaque type for all [SQLite SELECT queries](https://sqlite.org/syntax/select-stmt.html). An SQLSubquery adopts and is built from [SQLSubqueryable].

```swift
struct SQLSubquery: SQLSubqueryable {
    // opaque implementation
}
```

### SQLSubqueryable

`SQLSubqueryable` is the protocol for all [SQLite SELECT queries](https://sqlite.org/syntax/select-stmt.html). It conforms to [SQLSpecificExpressible], and is adopted by [FetchRequest], [QueryInterfaceRequest], [SQLRequest]. It has an `sqlSubquery` property which returns an [SQLSubquery].

```swift
protocol SQLSubqueryable: SQLSpecificExpressible {
    var sqlSubquery: SQLSubquery { get }
}
```

SQLSubqueryable provides the GRDB support for subqueries. Its [SQLSpecificExpressible] facet lets you use any request as an expression:

```swift
// SELECT * FROM player
// WHERE score >= (SELECT AVG(score) FROM player)
let averageScore = Player.select(average(Column("score")))
Player.filter(Column("score") >= averageScore)
```

SQLSubqueryable has the `contains(_:)` and `exists()` methods that support the `value IN (subquery)` and `EXISTS (subquery)` expressions.

Use SQLSubqueryable in order to define a function that requires a subquery argument:

```swift
func myRequest(_ nameSubquery: SQLSubqueryable) -> SQLRequest<Player> {
    """
    SELECT * FROM player
    WHERE name IN (\(nameSubquery) UNION ...)
    """
}

myRequest(SQLRequest("SELECT ..."))
myRequest(Player.select(...).filter(...))
```

[Association]: #association
[associations]: AssociationsBasics.md
[association aggregates]: AssociationsBasics.md#association-aggregates
[Column]: #column
[ColumnExpression]: #columnexpression
[DatabaseRegionConvertible]: #databaseregionconvertible
[DatabaseRegionObservation]: ../README.md#databaseregionobservation
[DatabaseValue]: #databasevalue
[DatabaseValueConvertible]: #databasevalueconvertible
[DerivableRequest]: #derivablerequest
[FetchableRecord]: ../README.md#fetchablerecord-protocol
[FetchRequest]: #fetchrequest
[Int, String, Date…]: #int-string-date
[Int, String, Date]: #int-string-date
[query interface]: ../README.md#the-query-interface
[QueryInterfaceRequest]: #queryinterfacerequest
[SQL]: #sql
[SQL Interpolation]: SQLInterpolation.md
[SQLExpression]: #sqlexpression
[SQLExpressible]: #sqlexpressible
[SQLOrderingTerm]: #sqlorderingterm
[SQLOrdering]: #sqlordering
[SQLRequest]: #sqlrequest
[SQLSelectable]: #sqlselectable
[SQLSelection]: #sqlselection
[SQLSpecificExpressible]: #sqlspecificexpressible
[SQLSubquery]: #sqlsubquery
[SQLSubqueryable]: #sqlsubqueryable
