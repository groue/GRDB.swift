# ``GRDB/Statement``

A prepared statement.

## Overview

Prepared statements let you execute an SQL query several times, with different arguments if needed.

Reusing prepared statements is a performance optimization technique because SQLite parses and analyses the SQL query only once, when the prepared statement is created.

## Building Prepared Statements

Build a prepared statement with the ``Database/makeStatement(sql:)`` method:

```swift
try dbQueue.write { db in
    let insertStatement = try db.makeStatement(sql: """
        INSERT INTO player (name, score) VALUES (:name, :score)
        """)
    
    let selectStatement = try db.makeStatement(sql: """
        SELECT * FROM player WHERE name = ?
        """)
}
```

The `?` and colon-prefixed keys like `:name` in the SQL query are the statement arguments. Set the values for those arguments with arrays or dictionaries of database values, or ``StatementArguments`` instances:

```swift
insertStatement.arguments = ["name": "Arthur", "score": 1000]
selectStatement.arguments = ["Arthur"]
```

Alternatively, the ``Database/makeStatement(literal:)`` method creates prepared statements with support for [SQL Interpolation]:

```swift
let insertStatement = try db.makeStatement(literal: "INSERT ...")
let selectStatement = try db.makeStatement(literal: "SELECT ...")
//                                         ~~~~~~~
```

The `makeStatement` methods throw an error of code `SQLITE_MISUSE` (21) if the SQL query contains multiple statements joined with a semicolon. See <doc:GRDB/Statement#Parsing-Multiple-Prepared-Statements-from-a-Single-SQL-String> below.

## Executing Prepared Statements and Fetching Values

Prepared statements can be executed:

```swift
try insertStatement.execute()
```

To fetch rows and values from a prepared statement, use a fetching method of ``Row``, ``DatabaseValueConvertible``, or ``FetchableRecord``:

```swift
let players = try Player.fetchCursor(selectStatement) // A Cursor of Player
let players = try Player.fetchAll(selectStatement)    // [Player]
let players = try Player.fetchSet(selectStatement)    // Set<Player>
let player =  try Player.fetchOne(selectStatement)     // Player?
//                ~~~~~~ or Row, Int, String, Date, etc.
```

Arguments can be set at the moment of the statement execution:

```swift
try insertStatement.execute(arguments: ["name": "Arthur", "score": 1000])
let player = try Player.fetchOne(selectStatement, arguments: ["Arthur"])
```

> Note: A prepared statement that has failed with an error can not be recovered. Create a new instance, or use a cached statement as described below.

> Tip: When you look after the best performance, take care about a difference between setting the arguments before execution, and setting the arguments at the moment of execution:
>
> ```swift
> // First option
> try statement.setArguments(...)
> try statement.execute()
>
> // Second option
> try statement.execute(arguments: ...)
> ```
>
> Both perform exactly the same action, and most applications should not care about the difference. Yet:
>
> - ``setArguments(_:)`` performs a copy of string and blob arguments. It uses the low-level [`SQLITE_TRANSIENT`](https://www.sqlite.org/c3ref/c_static.html) option, and fits well the reuse of a given statement with the same arguments.
> - ``execute(arguments:)`` avoids a temporary allocation for string and blob arguments if the number of arguments is small. Instead of `SQLITE_TRANSIENT`, it uses the low-level [`SQLITE_STATIC`](https://www.sqlite.org/c3ref/c_static.html) option. This fits well the reuse of a given statement with various arguments.
>
> Don't make a blind choice, and monitor your app performance if it really matters!

## Caching Prepared Statements

When the same query will be used several times in the lifetime of an application, one may feel a natural desire to cache prepared statements.

Don't cache statements yourself.

> Note: This is because an application lacks the necessary tools. Statements are tied to specific SQLite connections and dispatch queues which are not managed by the application, especially with a ``DatabasePool`` connection. A change in the database schema [may, or may not](https://www.sqlite.org/compile.html#max_schema_retry) invalidate a statement.

Instead, use the ``Database/cachedStatement(sql:)`` method. GRDB does all the hard caching and memory management:

```swift
let statement = try db.cachedStatement(sql: "INSERT ...")
```

The variant ``Database/cachedStatement(literal:)`` supports [SQL Interpolation]:

```swift
let statement = try db.cachedStatement(literal: "INSERT ...")
```

Should a cached prepared statement throw an error, don't reuse it. Instead, reload one from the cache.

## Parsing Multiple Prepared Statements from a Single SQL String

To build multiple statements joined with a semicolon, use ``Database/allStatements(sql:arguments:)``:

```swift
let statements = try db.allStatements(sql: """
    INSERT INTO player (name, score) VALUES (?, ?);
    INSERT INTO player (name, score) VALUES (?, ?);
    """, arguments: ["Arthur", 100, "O'Brien", 1000])
while let statement = try statements.next() {
    try statement.execute()
}
```

The variant ``Database/allStatements(literal:)`` supports [SQL Interpolation]:

```swift
let statements = try db.allStatements(literal: """
    INSERT INTO player (name, score) VALUES (\("Arthur"), \(100));
    INSERT INTO player (name, score) VALUES (\("O'Brien"), \(1000));
    """)
// An alternative way to iterate all statements
try statements.forEach { statement in
    try statement.execute()
}
```

> Tip: When you intend to run all statements in an SQL string but don't care about individual ones, don't bother iterating individual statement instances! Skip this documentation section and just use ``Database/execute(sql:arguments:)``:
>
> ```swift
> try db.execute(sql: """
>     CREATE TABLE player ...; 
>     INSERT INTO player ...;
>     """)
> ```

The results of multiple `SELECT` statements can be joined into a single ``Cursor``. This is the GRDB version of the [`sqlite3_exec()`](https://www.sqlite.org/c3ref/exec.html) function:

```swift
let statements = try db.allStatements(sql: """
    SELECT ...; 
    SELECT ...; 
    """)
let players = try statements.flatMap { statement in
    try Player.fetchCursor(statement)
}
for let player = try players.next() { 
    print(player.name)
}
```

The ``SQLStatementCursor`` returned from `allStatements` can be turned into a regular Swift array, but in this case make sure all individual statements can compile even if the previous ones were not executed:

```swift
// OK: Array of statements
let statements = try Array(db.allStatements(sql: """
    INSERT ...; 
    UPDATE ...; 
    """))

// FAILURE: Can't build an array of statements since the INSERT won't
// compile until CREATE TABLE is executed.
let statements = try Array(db.allStatements(sql: """
    CREATE TABLE player ...; 
    INSERT INTO player ...;
    """))
```

## Topics

### Executing a Prepared Statement

- ``execute(arguments:)``

### Arguments

- ``arguments``
- ``setArguments(_:)``
- ``setUncheckedArguments(_:)``
- ``validateArguments(_:)``
- ``StatementArguments``

### Statement Informations

- ``columnCount``
- ``columnNames``
- ``databaseRegion``
- ``index(ofColumn:)``
- ``isReadonly``
- ``sql``
- ``sqliteStatement``
- ``SQLiteStatement``


[SQL Interpolation]: https://github.com/groue/GRDB.swift/blob/master/Documentation/SQLInterpolation.md
