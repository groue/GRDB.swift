Common Table Expressions
========================

[**:fire: EXPERIMENTAL**](../README.md#what-are-experimental-features)

---

**Common table expressions** (CTEs) can generally be seen as *SQL views that you define on the fly*.

A certain level of familiarity with SQL databases is helpful before you dive into this guide. The starting point is obviously the [SQLite documentation](https://sqlite.org/lang_with.html). Many CTE tutorials exist online as well, including [this good one](https://blog.expensify.com/2015/09/25/the-simplest-sqlite-common-table-expression-tutorial/).

In this guide, you will learn how to:

- [Define Common Table Expressions]
- [Embed Common Table Expressions in Requests]
- [Fetch Values From Common Table Expressions]
- Join CTEs with [Associations to Common Table Expressions]

> :point_up: **Note**: most code examples will be trivial, and not very "useful". This is because the goal of this guide is to stay focused on the GRDB support for CTEs. Rich setup would just be distracting. So bring your own good ideas with you!


## Define Common Table Expressions

You will create a `CommonTableExpression` definition first. Choose a **name**, and a **request** that provides the content of the common table expression.

The CTE name is like a regular table name: pick one that does not conflict with the names of existing tables.

The CTE request can be provided as a [query interface request]:

```swift
// WITH playerName AS (SELECT name FROM player) ...
let playerNameCTE = CommonTableExpression<Void>(
    named: "playerName", 
    request: Player.select(Column("name")))
```

You can feed a CTE with raw SQL as well (second and third examples use [SQL Interpolation]):

```swift
let name = "O'Brien"

// WITH playerName AS (SELECT 'O''Brien') ...
let playerNameCTE = CommonTableExpression<Void>(
    named: "playerName",
    sql: "SELECT ?", arguments: [name])

// WITH playerName AS (SELECT 'O''Brien') ...
let playerNameCTE = CommonTableExpression<Void>(
    named: "playerName",
    literal: "SELECT \(name)")

// WITH playerName AS (SELECT 'O''Brien') ...
let request: SQLRequest<String> = "SELECT \(name)"
let playerNameCTE = CommonTableExpression<Void>(
    named: "playerName",
    request: requests)
```

All CTEs can be provided with explicit column names:

```swift
// WITH pair(a, b) AS (SELECT 1, 2) ...
let pairCTE = CommonTableExpression<Void>(
    named: "pair", 
    columns: ["a", "b"], 
    sql: "SELECT 1, 2")
```

Recursive CTEs need the `recursive` flag. The example below selects all integers between 1 and 1000:

```swift
// WITH RECURSIVE counter(x) AS
//   (VALUES(1) UNION ALL SELECT x+1 FROM counter WHERE x<1000)
let counterCTE = CommonTableExpression<Int>(
    recursive: true,
    named: "counter",
    columns: ["x"],
    sql: """
        VALUES(1)
        UNION ALL
        SELECT x+1 FROM counter WHERE x<1000
        """)
```

> :point_up: **Note**: many recursive CTEs use the `UNION ALL` SQL operator. The query interface does not provide any Swift support for it, so you'll generally have to write SQL in your definitions of recursive CTEs.

As you can see in all above examples, `CommonTableExpression` is a generic type: `CommonTableExpression<Void>`, `CommonTableExpression<Int>`. The generic argument (`Void`, `Int`) turns useful when you [join common table expressions](#associations-to-common-table-expressions), or when you [fetch values directly from a common table expression](#fetch-values-from-common-table-expressions). Otherwise, you can just use `Void`.


## Embed Common Table Expressions in Requests

A typical SQLite query that uses a common table expression first *defines* the CTE and then *uses* the CTE by mentioning its table name. We'll see below Swift apis that match those two steps.

We will use the (simple) query below as a target. It is the query we'll want to generate in this chapter. It defines a CTE, and uses it in a subquery:

```sql
WITH playerName AS (SELECT 'O''Brien')
SELECT * FROM player
WHERE name = (SELECT * FROM playerName)
```

We first build a `CommonTableExpression`:

```swift
let name = "O'Brien"
let playerNameCTE = CommonTableExpression<Void>(
    named: "playerName", 
    literal: "SELECT \(name)")
```

We can then embed the definition of the CTE in a [query interface request] by calling the `with(_:)` method:

```swift
// WITH playerName AS (SELECT 'O''Brien')
// SELECT * FROM player ...
let request = Player
    .with(playerNameCTE)...
```

And we can then filter the `player` table with a subquery:

```swift
// WITH playerName AS (SELECT 'O''Brien')
// SELECT * FROM player
// WHERE name = (SELECT * FROM playerName)
let request = Player
    .with(playerNameCTE)
    .filter(Column("name") == playerNameCTE.all())
```

> :point_up: **Note**: the `with(_:)` method can be called as many times as a there are common table expressions in your request.
>
> :point_up: **Note**: the `with(_:)` method can be called at any time, as all request methods: `Player.with(...).filter(...).with(...)`.
>
> :point_up: **Note**: the `with(_:)` method replaces any previously embedded CTE that has the same table name. This allows you to embed the same CTE several times if you feel like it.
>
> :point_up: **Note**: the `CommonTableExpression.all()` method builds a regular [query interface request] for the content of the CTE (like `SELECT * FROM <cte name>`, not to be mismatched with the request that was used to define the CTE). You can filter this request, sort it, etc, like all query interface requests:
>
> ```swift
> cte.all().select(...).filter(...).group(...).order(...)
> ```

Common table expressions can also be embedded in [SQLRequest] with [SQL Interpolation]:

```swift
// WITH playerName AS (SELECT 'O''Brien')
// SELECT * FROM player
// WHERE name = (SELECT * FROM playerName)
let request: SQLRequest<Player> = """
    WITH \(definitionFor: playerNameCTE)
    SELECT * FROM player
    WHERE name = (SELECT * FROM \(playerNameCTE))
    """

// WITH playerName AS (SELECT 'O''Brien')
// SELECT * FROM player
// WHERE name = (SELECT * FROM playerName)
let request: SQLRequest<Player> = """
    WITH \(definitionFor: playerNameCTE)
    SELECT * FROM player
    WHERE name = (\(playerNameCTE.all()))
    """
```

Common table expressions can also be used as subqueries, when you update or delete rows in the database:

```swift
// WITH playerName AS (SELECT 'O''Brien')
// UPDATE player SET name = (SELECT * FROM playerName)
try Player
    .with(playerNameCTE)
    .updateAll(db, Column("name").set(to: playerNameCTE.all()))
    
// WITH playerName AS (SELECT 'O''Brien')
// DELETE FROM player WHERE name = (SELECT * FROM playerName)
try Player
    .with(playerNameCTE)
    .filter(Column("name") == playerNameCTE.all())
    .deleteAll(db)
```


## Fetch Values From Common Table Expressions

In the previous chapter, a common table expression was embedded as a subquery, with the `CommonTableExpression.all()` method.

`all()` builds a regular [query interface request] that you can filter, sort, etc, like all query interface requests. You can also fetch from it, but only as long as it is provided with the definition of the CTE.

This will generally give requests of the form `cte.all().with(cte)`. In SQL, this would give: `WITH cte AS (...) SELECT * FROM cte`.

The generic type of `CommonTableExpression<...>` now turns out useful, so that you can fetch the desired outcome (database [rows](../README.md#row-queries), simple [values](../README.md#value-queries), or custom [records](../README.md#records)).

For example, let's fetch a range of integer:

```swift
func counterRequest(range: ClosedRange<Int>) -> QueryInterfaceRequest<Int> {
    // WITH RECURSIVE counter(x) AS
    //   (VALUES(...) UNION ALL SELECT x+1 FROM counter WHERE x<...)
    // SELECT * FROM counter
    let counter = CommonTableExpression<Int>(
        recursive: true,
        named: "counter",
        columns: ["x"],
        literal: """
            VALUES(\(range.lowerBound)) \
            UNION ALL \
            SELECT x+1 FROM counter WHERE x < \(range.upperBound)
            """)
    return counter.all().with(counter)
}

let values = try dbQueue.read { db in
    try counterRequest(range: 3...7).fetchAll(db)
}
print(values) // prints "[3, 4, 5, 6, 7]"
```

When you have to fetch from a `CommonTableExpression` which does not have the desired generic type, you can still use the `asRequest(of:)` method:

```swift
let cte: CommonTableExpression<Void> = ...
let rows: [Row] = try dbQueue.read { db in
    try cte.all().with(cte)
        .asRequest(of: Row.self)
        .fetchAll(db)
}
```


## Associations to Common Table Expressions

GRDB [associations] define "to-one" and "to-many" relationships between two database tables. Here we will define associations between regular tables and common table expressions.

We recommend familiarity with the "joining methods", described in [Joining And Prefetching Associated Records]:

```swift
// SELECT parent.* FROM parent LEFT JOIN child ON ...
Parent.joining(optional: childAssociation)

// SELECT parent.* FROM parent JOIN child ON ...
Parent.joining(required: childAssociation)

// SELECT parent.*, child.* FROM parent LEFT JOIN child ON ...
Parent.including(optional: childAssociation)

// SELECT parent.*, child.* FROM parent JOIN child ON ...
Parent.including(required: childAssociation)
```

> :point_up: **Note**: common table expressions currently only define "to-one" associations, so the `including(all:)` joining method is unavailable.

CTE associations are generally built with the `association(to:on:)` method, which needs:

- The two sides of the association: a `CommonTableExpression` instance, and another CTE or a type that conforms to the [TableRecord] protocol.
- A function that returns the condition that joins the two sides of the association.

The condition function plays the same role as the **foreign key** that defines regular table [associations] such as **BelongsTo** or **HasMany**. It accepts two [TableAlias], from which you can build a joining expression:

For example:

```swift
// An association from LeftRecord to rightCTE
let rightCTE = ...
let association = LeftRecord.association(
    to: rightCTE, 
    on: { left, right in
        left[Column("x")] = right[Column("y")]
    })
```

Now this association can be used with a joining method:

```swift
// WITH rightCTE AS (...)
// SELECT leftRecord.*, rightCTE.*
// FROM leftRecord
// JOIN rightCTE ON leftRecord.x = rightCTE.y
LeftRecord
    .with(rightCTE)
    .including(required: association)
```


### CTE Association Example: a Chat App

As an example, let's build the classical main screen of a chat application: a list of all latest messages from all conversations.

The database schema of the chat app contains a `chat` and a `message` table. The application defines the following records:

```swift
struct Chat: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    ...
}

struct Message: Codable, FetchableRecord, PersistableRecord {
    var chatID: Int64
    var date: Date
    ...
}
```

To feed the main app screen, we want to fetch a list of `ChatInfo` records:

```swift
struct ChatInfo: Decodable, FetchableRecord {
    /// The chat
    var chat: Chat
    
    /// The latest chat message, if any
    var latestMessage: Message?
}
```

The SQL request that we want to run is below. It uses an SQLite-specific [special processing](https://sqlite.org/lang_select.html) of `MAX()` that helps the selection of latest messages from all chats:

```sql
WITH latestMessage AS
  (SELECT *, MAX(date) FROM message GROUP BY chatID)
SELECT chat.*, latestMessage.*
FROM chat
LEFT JOIN latestMessage ON chat.id = latestMessage.chatID
ORDER BY latestMessage.date DESC
```

We start by defining the CTE request, which loads the latest messages of all chats:

```swift
// SELECT *, MAX(date) FROM message GROUP BY chatID
let latestMessageRequest = Message
    .annotated(with: max(Column("date")))
    .group(Column("chatID"))
```

We can now define the CTE for the latest messages:

```swift
// WITH latestMessage AS
//   (SELECT *, MAX(date) FROM message GROUP BY chatID)
let latestMessageCTE = CommonTableExpression<Void>(
    named: "latestMessage",
    request: latestMessageRequest)
```

The association from a chat to its latest message follows:

```swift

// ... JOIN latestMessage ON chat.id = latestMessage.chatID
let latestMessage = Chat.association(
    to: latestMessageCTE,
    on: { chat, latestMessage in
        chat[Column("id")] == latestMessage[Column("chatID")]
    })
    .order(Column("date").desc)
```

The final request can now be defined:

```swift

// WITH latestMessage AS
//   (SELECT *, MAX(date) FROM message GROUP BY chatID)
// SELECT chat.*, latestMessage.*
// FROM chat
// LEFT JOIN latestMessage ON chat.id = latestMessage.chatID
// ORDER BY latestMessage.date DESC
let request = Chat
    .with(latestMessageCTE)
    .including(optional: latestMessage)
    .asRequest(of: ChatInfo.self)
```

And we can fetch the data that feeds our application screen:

```swift

let chatInfos: [ChatInfos] = try dbQueue.read(request.fetchAll)
```

> :bulb: **Tip**: the joining methods are generally type-safe: they won't allow you to join apples to oranges. This works when associations have a *precise* type. In this context, our go-to `CommonTableExpression<Void>` CTEs can work against type safety. So when you want to define associations between several CTEs, and make sure the compiler will notice wrong uses of those associations, tag your `CommonTableExpression` with a type instead of `Void`.
>
> You can use an existing record type, or an ad-hoc enum. For example:
>
> ```swift
> enum CTE1 { }
> let cte1 = CommonTableExpression<CTE1>(...)
>
> enum CTE2 { }
> let cte2 = CommonTableExpression<CTE2>(...)
>
> let assoc1 = BaseRecord.association(to: cte1, on: ...)
> let assoc2 = cte1.association(to: cte2, on: ...)
> let assoc3 = cte2.association(to: FarRecord.self, on: ...)
>
> // WITH ...
> // SELECT base.* FROM base
> // JOIN cte1 ON ...
> // JOIN cte2 ON ...
> // JOIN far ON ...
> let request = BaseRecord
>     .with(cte1).with(cte2)
>     .joining(required: assoc1
>         .joining(required: assoc2
>             .joining(required: assoc3)))
>
> // Compiler error
> let request = BaseRecord.joining(required: assoc2)
> ```

[query interface request]: ../README.md#requests
[query interface requests]: ../README.md#requests
[SQLRequest]: ../README.md#custom-requests
[SQLiteral]: SQLInterpolation.md
[SQL Interpolation]: SQLInterpolation.md
[associations]: AssociationsBasics.md
[Joining And Prefetching Associated Records]: AssociationsBasics.md#joining-and-prefetching-associated-records
[Define Common Table Expressions]: #define-common-table-expressions
[Embed Common Table Expressions in Requests]: #embed-common-table-expressions-in-requests
[Fetch Values From Common Table Expressions]: #fetch-values-from-common-table-expressions
[Associations to Common Table Expressions]: #associations-to-common-table-expressions
[TableRecord]: ../README.md#tablerecord-protocol
[TableAlias]: AssociationsBasics.md#table-aliases
