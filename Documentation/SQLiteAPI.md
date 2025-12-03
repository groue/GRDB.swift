SQLite API
==========

**In this section of the documentation, we will talk SQL.** Jump to the [Query Interface](QueryInterface.md) if SQL is not your cup of tea.

- [Executing Updates](#executing-updates)
- [Fetch Queries](#fetch-queries)
    - [Fetching Methods](#fetching-methods)
    - [Cursors](#cursors)
    - [Row Queries](#row-queries)
    - [Value Queries](#value-queries)
- [Values](#values)
    - [Data](#data-and-memory-savings)
    - [Date and DateComponents](#date-and-datecomponents)
    - [NSNumber, NSDecimalNumber, and Decimal](#nsnumber-nsdecimalnumber-and-decimal)
    - [Swift enums](#swift-enums)
    - [`DatabaseValueConvertible`]: the protocol for custom value types
- [Transactions and Savepoints]
- [SQL Interpolation]

Advanced topics:

- [Prepared Statements]
- [Custom SQL Functions and Aggregates](CustomSQLFunctions.md)
- [Database Schema Introspection](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseschemaintrospection)
- [Row Adapters](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/rowadapter)
- [Raw SQLite Pointers](#raw-sqlite-pointers)


## Executing Updates

Once granted with a [database connection](DatabaseConnections.md), the [`execute(sql:arguments:)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/database/execute(sql:arguments:)) method executes the SQL statements that do not return any database row, such as `CREATE TABLE`, `INSERT`, `DELETE`, `ALTER`, etc.

For example:

```swift
try dbQueue.write { db in
    try db.execute(sql: """
        CREATE TABLE player (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            score INT)
        """)

    try db.execute(
        sql: "INSERT INTO player (name, score) VALUES (?, ?)",
        arguments: ["Barbara", 1000])

    try db.execute(
        sql: "UPDATE player SET score = :score WHERE id = :id",
        arguments: ["score": 1000, "id": 1])
    }
}
```

The `?` and colon-prefixed keys like `:score` in the SQL query are the **statements arguments**. You pass arguments with arrays or dictionaries, as in the example above. See [Values](#values) for more information on supported arguments types (Bool, Int, String, Date, Swift enums, etc.), and [`StatementArguments`] for a detailed documentation of SQLite arguments.

You can also embed query arguments right into your SQL queries, with [`execute(literal:)`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/database/execute(literal:)), as in the example below. See [SQL Interpolation] for more details.

```swift
try dbQueue.write { db in
    let name = "O'Brien"
    let score = 550
    try db.execute(literal: """
        INSERT INTO player (name, score) VALUES (\(name), \(score))
        """)
}
```

**Never ever embed values directly in your raw SQL strings**. See [Avoiding SQL Injection](BackupAndUtilities.md#avoiding-sql-injection) for more information:

```swift
// WRONG: don't embed values in raw SQL strings
let id = 123
let name = textField.text
try db.execute(
    sql: "UPDATE player SET name = '\(name)' WHERE id = \(id)")

// CORRECT: use arguments dictionary
try db.execute(
    sql: "UPDATE player SET name = :name WHERE id = :id",
    arguments: ["name": name, "id": id])

// CORRECT: use arguments array
try db.execute(
    sql: "UPDATE player SET name = ? WHERE id = ?",
    arguments: [name, id])

// CORRECT: use SQL Interpolation
try db.execute(
    literal: "UPDATE player SET name = \(name) WHERE id = \(id)")
```

**Join multiple statements with a semicolon**:

```swift
try db.execute(sql: """
    INSERT INTO player (name, score) VALUES (?, ?);
    INSERT INTO player (name, score) VALUES (?, ?);
    """, arguments: ["Arthur", 750, "Barbara", 1000])

try db.execute(literal: """
    INSERT INTO player (name, score) VALUES (\("Arthur"), \(750));
    INSERT INTO player (name, score) VALUES (\("Barbara"), \(1000));
    """)
```

When you want to make sure that a single statement is executed, use a prepared [`Statement`].

**After an INSERT statement**, you can get the row ID of the inserted row with [`lastInsertedRowID`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/database/lastinsertedrowid):

```swift
try db.execute(
    sql: "INSERT INTO player (name, score) VALUES (?, ?)",
    arguments: ["Arthur", 1000])
let playerId = db.lastInsertedRowID
```

Don't miss [Records](Records.md), that provide classic **persistence methods**:

```swift
var player = Player(name: "Arthur", score: 1000)
try player.insert(db)
let playerId = player.id
```


## Fetch Queries

[Database connections](DatabaseConnections.md) let you fetch database rows, plain values, and custom models aka "records".

**Rows** are the raw results of SQL queries:

```swift
try dbQueue.read { db in
    if let row = try Row.fetchOne(db, sql: "SELECT * FROM wine WHERE id = ?", arguments: [1]) {
        let name: String = row["name"]
        let color: Color = row["color"]
        print(name, color)
    }
}
```


**Values** are the Bool, Int, String, Date, Swift enums, etc. stored in row columns:

```swift
try dbQueue.read { db in
    let urls = try URL.fetchCursor(db, sql: "SELECT url FROM wine")
    while let url = try urls.next() {
        print(url)
    }
}
```


**Records** are your application objects that can initialize themselves from rows:

```swift
let wines = try dbQueue.read { db in
    try Wine.fetchAll(db, sql: "SELECT * FROM wine")
}
```

- [Fetching Methods](#fetching-methods)
- [Cursors](#cursors)
- [Row Queries](#row-queries)
- [Value Queries](#value-queries)
- [Records](Records.md)


### Fetching Methods

**Throughout GRDB**, you can always fetch *cursors*, *arrays*, *sets*, or *single values* of any fetchable type (database [row](#row-queries), simple [value](#value-queries), or custom [record](Records.md)):

```swift
try Row.fetchCursor(...) // A Cursor of Row
try Row.fetchAll(...)    // [Row]
try Row.fetchSet(...)    // Set<Row>
try Row.fetchOne(...)    // Row?
```

- `fetchCursor` returns a **[cursor](#cursors)** over fetched values:

    ```swift
    let rows = try Row.fetchCursor(db, sql: "SELECT ...") // A Cursor of Row
    ```

- `fetchAll` returns an **array**:

    ```swift
    let players = try Player.fetchAll(db, sql: "SELECT ...") // [Player]
    ```

- `fetchSet` returns a **set**:

    ```swift
    let names = try String.fetchSet(db, sql: "SELECT ...") // Set<String>
    ```

- `fetchOne` returns a **single optional value**, and consumes a single database row (if any).

    ```swift
    let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) ...") // Int?
    ```

**All those fetching methods require an SQL string that contains a single SQL statement.** When you want to fetch from multiple statements joined with a semicolon, iterate the multiple [prepared statements] found in the SQL string.

### Cursors

**Whenever you consume several rows from the database, you can fetch an Array, a Set, or a Cursor**.

The `fetchAll()` and `fetchSet()` methods return regular Swift array and sets, that you iterate like all other arrays and sets:

```swift
try dbQueue.read { db in
    // [Player]
    let players = try Player.fetchAll(db, sql: "SELECT ...")
    for player in players {
        // use player
    }
}
```

Unlike arrays and sets, cursors returned by `fetchCursor()` load their results step after step:

```swift
try dbQueue.read { db in
    // Cursor of Player
    let players = try Player.fetchCursor(db, sql: "SELECT ...")
    while let player = try players.next() {
        // use player
    }
}
```

- **Cursors can not be used on any thread**: you must consume a cursor on the dispatch queue it was created in. Particularly, don't extract a cursor out of a database access method:

    ```swift
    // Wrong
    let cursor = try dbQueue.read { db in
        try Player.fetchCursor(db, ...)
    }
    while let player = try cursor.next() { ... }
    ```

    Conversely, arrays and sets may be consumed on any thread:

    ```swift
    // OK
    let array = try dbQueue.read { db in
        try Player.fetchAll(db, ...)
    }
    for player in array { ... }
    ```

- **Cursors can be iterated only one time.** Arrays and sets can be iterated many times.

- **Cursors iterate database results in a lazy fashion**, and don't consume much memory. Arrays and sets contain copies of database values, and may take a lot of memory when there are many fetched results.

- **Cursors are granted with direct access to SQLite,** unlike arrays and sets that have to take the time to copy database values. If you look after extra performance, you may prefer cursors.

- **Cursors can feed Swift collections.**

    You will most of the time use `fetchAll` or `fetchSet` when you want an array or a set. For more specific needs, you may prefer one of the initializers below. All of them accept an extra optional `minimumCapacity` argument which helps optimizing your app when you have an idea of the number of elements in a cursor (the built-in `fetchAll` and `fetchSet` do not perform such an optimization).

    **Arrays** and all types conforming to `RangeReplaceableCollection`:

    ```swift
    // [String]
    let cursor = try String.fetchCursor(db, ...)
    let array = try Array(cursor)
    ```

    **Sets**:

    ```swift
    // Set<Int>
    let cursor = try Int.fetchCursor(db, ...)
    let set = try Set(cursor)
    ```

    **Dictionaries**:

    ```swift
    // [Int64: [Player]]
    let cursor = try Player.fetchCursor(db)
    let dictionary = try Dictionary(grouping: cursor, by: { $0.teamID })

    // [Int64: Player]
    let cursor = try Player.fetchCursor(db).map { ($0.id, $0) }
    let dictionary = try Dictionary(uniqueKeysWithValues: cursor)
    ```

- **Cursors adopt the [Cursor](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/cursor) protocol, which looks a lot like standard [lazy sequences](https://developer.apple.com/reference/swift/lazysequenceprotocol) of Swift.** As such, cursors come with many convenience methods: `compactMap`, `contains`, `dropFirst`, `dropLast`, `drop(while:)`, `enumerated`, `filter`, `first`, `flatMap`, `forEach`, `joined`, `joined(separator:)`, `max`, `max(by:)`, `min`, `min(by:)`, `map`, `prefix`, `prefix(while:)`, `reduce`, `reduce(into:)`, `suffix`:

    ```swift
    // Prints all Github links
    try URL
        .fetchCursor(db, sql: "SELECT url FROM link")
        .filter { url in url.host == "github.com" }
        .forEach { url in print(url) }

    // An efficient cursor of coordinates:
    let locations = try Row.
        .fetchCursor(db, sql: "SELECT latitude, longitude FROM place")
        .map { row in
            CLLocationCoordinate2D(latitude: row[0], longitude: row[1])
        }
    ```

- **Cursors are not Swift sequences.** That's because Swift sequences can't handle iteration errors, when reading SQLite results may fail at any time.

- **Cursors require a little care**:

    - Don't modify the results during a cursor iteration:

        ```swift
        // Undefined behavior
        while let player = try players.next() {
            try db.execute(sql: "DELETE ...")
        }
        ```

    - Don't turn a cursor of `Row` into an array or a set. You would not get the distinct rows you expect. To get a array of rows, use `Row.fetchAll(...)`. To get a set of rows, use `Row.fetchSet(...)`. Generally speaking, make sure you copy a row whenever you extract it from a cursor for later use: `row.copy()`.

If you don't see, or don't care about the difference, use arrays. If you care about memory and performance, use cursors when appropriate.


### Row Queries

- [Fetching Rows](#fetching-rows)
- [Column Values](#column-values)
- [DatabaseValue](#databasevalue)
- [Rows as Dictionaries](#rows-as-dictionaries)


#### Fetching Rows

Fetch **cursors** of rows, **arrays**, **sets**, or **single** rows (see [fetching methods](#fetching-methods)):

```swift
try dbQueue.read { db in
    try Row.fetchCursor(db, sql: "SELECT ...", arguments: ...) // A Cursor of Row
    try Row.fetchAll(db, sql: "SELECT ...", arguments: ...)    // [Row]
    try Row.fetchSet(db, sql: "SELECT ...", arguments: ...)    // Set<Row>
    try Row.fetchOne(db, sql: "SELECT ...", arguments: ...)    // Row?

    let rows = try Row.fetchCursor(db, sql: "SELECT * FROM wine")
    while let row = try rows.next() {
        let name: String = row["name"]
        let color: Color = row["color"]
        print(name, color)
    }
}

let rows = try dbQueue.read { db in
    try Row.fetchAll(db, sql: "SELECT * FROM player")
}
```

Arguments are optional arrays or dictionaries that fill the positional `?` and colon-prefixed keys like `:name` in the query:

```swift
let rows = try Row.fetchAll(db,
    sql: "SELECT * FROM player WHERE name = ?",
    arguments: ["Arthur"])

let rows = try Row.fetchAll(db,
    sql: "SELECT * FROM player WHERE name = :name",
    arguments: ["name": "Arthur"])
```

See [Values](#values) for more information on supported arguments types (Bool, Int, String, Date, Swift enums, etc.), and [`StatementArguments`] for a detailed documentation of SQLite arguments.

Unlike row arrays that contain copies of the database rows, row cursors are close to the SQLite metal, and require a little care:

> **Note**: **Don't turn a cursor of `Row` into an array or a set**. You would not get the distinct rows you expect. To get a array of rows, use `Row.fetchAll(...)`. To get a set of rows, use `Row.fetchSet(...)`. Generally speaking, make sure you copy a row whenever you extract it from a cursor for later use: `row.copy()`.


#### Column Values

**Read column values** by index or column name:

```swift
let name: String = row[0]      // 0 is the leftmost column
let name: String = row["name"] // Leftmost matching column - lookup is case-insensitive
let name: String = row[Column("name")] // Using query interface's Column
```

Make sure to ask for an optional when the value may be NULL:

```swift
let name: String? = row["name"]
```

The `row[]` subscript returns the type you ask for. See [Values](#values) for more information on supported value types:

```swift
let bookCount: Int     = row["bookCount"]
let bookCount64: Int64 = row["bookCount"]
let hasBooks: Bool     = row["bookCount"] // false when 0

let string: String     = row["date"]      // "2015-09-11 18:14:15.123"
let date: Date         = row["date"]      // Date
self.date = row["date"] // Depends on the type of the property.
```

You can also use the `as` type casting operator:

```swift
row[...] as Int
row[...] as Int?
```

Throwing accessors exist as well. Their use is not encouraged, because a database decoding error is a programming error. If an application stores invalid data in the database file, that is a bug that needs to be fixed:

```swift
let name = try row.decode(String.self, atIndex: 0)
let bookCount = try row.decode(Int.self, forColumn: "bookCount")
```

> **Warning**: avoid the `as!` and `as?` operators:
>
> ```swift
> if let int = row[...] as? Int { ... } // BAD - doesn't work
> if let int = row[...] as Int? { ... } // GOOD
> ```

> **Warning**: avoid nil-coalescing row values, and prefer the `coalesce` method instead:
>
> ```swift
> let name: String? = row["nickname"] ?? row["name"]     // BAD - doesn't work
> let name: String? = row.coalesce(["nickname", "name"]) // GOOD
> ```

Generally speaking, you can extract the type you need, provided it can be converted from the underlying SQLite value:

- **Successful conversions include:**

    - All numeric SQLite values to all numeric Swift types, and Bool (zero is the only false boolean).
    - Text SQLite values to Swift String.
    - Blob SQLite values to Foundation Data.

    See [Values](#values) for more information on supported types (Bool, Int, String, Date, Swift enums, etc.)

- **NULL returns nil.**

    ```swift
    let row = try Row.fetchOne(db, sql: "SELECT NULL")!
    row[0] as Int? // nil
    row[0] as Int  // fatal error: could not convert NULL to Int.
    ```

    There is one exception, though: the [DatabaseValue](#databasevalue) type:

    ```swift
    row[0] as DatabaseValue // DatabaseValue.null
    ```

- **Missing columns return nil.**

    ```swift
    let row = try Row.fetchOne(db, sql: "SELECT 'foo' AS foo")!
    row["missing"] as String? // nil
    row["missing"] as String  // fatal error: no such column: missing
    ```

    You can explicitly check for a column presence with the `hasColumn` method.

- **Invalid conversions throw a fatal error.**

    ```swift
    let row = try Row.fetchOne(db, sql: "SELECT 'Mom's birthday'")!
    row[0] as String // "Mom's birthday"
    row[0] as Date?  // fatal error: could not convert "Mom's birthday" to Date.
    row[0] as Date   // fatal error: could not convert "Mom's birthday" to Date.

    let row = try Row.fetchOne(db, sql: "SELECT 256")!
    row[0] as Int    // 256
    row[0] as UInt8? // fatal error: could not convert 256 to UInt8.
    row[0] as UInt8  // fatal error: could not convert 256 to UInt8.
    ```

    Those conversion fatal errors can be avoided with the [DatabaseValue](#databasevalue) type:

    ```swift
    let row = try Row.fetchOne(db, sql: "SELECT 'Mom's birthday'")!
    let dbValue: DatabaseValue = row[0]
    if dbValue.isNull {
        // Handle NULL
    } else if let date = Date.fromDatabaseValue(dbValue) {
        // Handle valid date
    } else {
        // Handle invalid date
    }
    ```

    This extra verbosity is the consequence of having to deal with an untrusted database: you may consider fixing the content of your database instead. See [Error Handling](BackupAndUtilities.md#error-handling) for more information.

- **SQLite has a weak type system, and provides [convenience conversions](https://www.sqlite.org/c3ref/column_blob.html) that can turn String to Int, Double to Blob, etc.**

    GRDB will sometimes let those conversions go through:

    ```swift
    let rows = try Row.fetchCursor(db, sql: "SELECT '20 small cigars'")
    while let row = try rows.next() {
        row[0] as Int   // 20
    }
    ```

    Don't freak out: those conversions did not prevent SQLite from becoming the immensely successful database engine you want to use. And GRDB adds safety checks described just above. You can also prevent those convenience conversions altogether by using the [DatabaseValue](#databasevalue) type.


#### DatabaseValue

**`DatabaseValue` is an intermediate type between SQLite and your values, which gives information about the raw value stored in the database.**

You get `DatabaseValue` just like other value types:

```swift
let dbValue: DatabaseValue = row[0]
let dbValue: DatabaseValue? = row["name"] // nil if and only if column does not exist

// Check for NULL:
dbValue.isNull // Bool

// The stored value:
dbValue.storage.value // Int64, Double, String, Data, or nil

// All the five storage classes supported by SQLite:
switch dbValue.storage {
case .null:                 print("NULL")
case .int64(let int64):     print("Int64: \(int64)")
case .double(let double):   print("Double: \(double)")
case .string(let string):   print("String: \(string)")
case .blob(let data):       print("Data: \(data)")
}
```

You can extract regular [values](#values) (Bool, Int, String, Date, Swift enums, etc.) from `DatabaseValue` with the [fromDatabaseValue()](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasevalueconvertible/fromdatabasevalue(_:)-21zzv) method:

```swift
let dbValue: DatabaseValue = row["bookCount"]
let bookCount   = Int.fromDatabaseValue(dbValue)   // Int?
let bookCount64 = Int64.fromDatabaseValue(dbValue) // Int64?
let hasBooks    = Bool.fromDatabaseValue(dbValue)  // Bool?, false when 0

let dbValue: DatabaseValue = row["date"]
let string = String.fromDatabaseValue(dbValue)     // "2015-09-11 18:14:15.123"
let date   = Date.fromDatabaseValue(dbValue)       // Date?
```

`fromDatabaseValue` returns nil for invalid conversions:

```swift
let row = try Row.fetchOne(db, sql: "SELECT 'Mom's birthday'")!
let dbValue: DatabaseValue = row[0]
let string = String.fromDatabaseValue(dbValue) // "Mom's birthday"
let int    = Int.fromDatabaseValue(dbValue)    // nil
let date   = Date.fromDatabaseValue(dbValue)   // nil
```


#### Rows as Dictionaries

Row adopts the standard [RandomAccessCollection](https://developer.apple.com/documentation/swift/randomaccesscollection) protocol, and can be seen as a dictionary of [DatabaseValue](#databasevalue):

```swift
// All the (columnName, dbValue) tuples, from left to right:
for (columnName, dbValue) in row {
    ...
}
```

**You can build rows from dictionaries** (standard Swift dictionaries and NSDictionary). See [Values](#values) for more information on supported types:

```swift
let row: Row = ["name": "foo", "date": nil]
let row = Row(["name": "foo", "date": nil])
let row = Row(/* [AnyHashable: Any] */) // nil if invalid dictionary
```

Yet rows are not real dictionaries: they may contain duplicate columns:

```swift
let row = try Row.fetchOne(db, sql: "SELECT 1 AS foo, 2 AS foo")!
row.columnNames    // ["foo", "foo"]
row.databaseValues // [1, 2]
row["foo"]         // 1 (leftmost matching column)
for (columnName, dbValue) in row { ... } // ("foo", 1), ("foo", 2)
```

**When you build a dictionary from a row**, you have to disambiguate identical columns, and choose how to present database values. For example:

- A `[String: DatabaseValue]` dictionary that keeps leftmost value in case of duplicated column name:

    ```swift
    let dict = Dictionary(row, uniquingKeysWith: { (left, _) in left })
    ```

- A `[String: AnyObject]` dictionary which keeps rightmost value in case of duplicated column name. This dictionary is identical to FMResultSet's resultDictionary from FMDB. It contains NSNull values for null columns, and can be shared with Objective-C:

    ```swift
    let dict = Dictionary(
        row.map { (column, dbValue) in
            (column, dbValue.storage.value as AnyObject)
        },
        uniquingKeysWith: { (_, right) in right })
    ```

- A `[String: Any]` dictionary that can feed, for example, JSONSerialization:

    ```swift
    let dict = Dictionary(
        row.map { (column, dbValue) in
            (column, dbValue.storage.value)
        },
        uniquingKeysWith: { (left, _) in left })
    ```

See the documentation of [`Dictionary.init(_:uniquingKeysWith:)`](https://developer.apple.com/documentation/swift/dictionary/2892961-init) for more information.


### Value Queries

**Instead of rows, you can directly fetch values.** There are many supported [value types](#values) (Bool, Int, String, Date, Swift enums, etc.).

Like rows, fetch values as **cursors**, **arrays**, **sets**, or **single** values (see [fetching methods](#fetching-methods)). Values are extracted from the leftmost column of the SQL queries:

```swift
try dbQueue.read { db in
    try Int.fetchCursor(db, sql: "SELECT ...", arguments: ...) // A Cursor of Int
    try Int.fetchAll(db, sql: "SELECT ...", arguments: ...)    // [Int]
    try Int.fetchSet(db, sql: "SELECT ...", arguments: ...)    // Set<Int>
    try Int.fetchOne(db, sql: "SELECT ...", arguments: ...)    // Int?

    let maxScore = try Int.fetchOne(db, sql: "SELECT MAX(score) FROM player") // Int?
    let names = try String.fetchAll(db, sql: "SELECT name FROM player")       // [String]
}
```

`Int.fetchOne` returns nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value:

```swift
// No row:
try Int.fetchOne(db, sql: "SELECT 42 WHERE FALSE") // nil

// One row with a NULL value:
try Int.fetchOne(db, sql: "SELECT NULL")           // nil

// One row with a non-NULL value:
try Int.fetchOne(db, sql: "SELECT 42")             // 42
```

For requests which may contain NULL, fetch optionals:

```swift
try dbQueue.read { db in
    try Optional<Int>.fetchCursor(db, sql: "SELECT ...", arguments: ...) // A Cursor of Int?
    try Optional<Int>.fetchAll(db, sql: "SELECT ...", arguments: ...)    // [Int?]
    try Optional<Int>.fetchSet(db, sql: "SELECT ...", arguments: ...)    // Set<Int?>
}
```

> :bulb: **Tip**: One advanced use case, when you fetch one value, is to distinguish the cases of a statement that yields no row, or one row with a NULL value. To do so, use `Optional<Int>.fetchOne`, which returns a double optional `Int??`:
>
> ```swift
> // No row:
> try Optional<Int>.fetchOne(db, sql: "SELECT 42 WHERE FALSE") // .none
> // One row with a NULL value:
> try Optional<Int>.fetchOne(db, sql: "SELECT NULL")           // .some(.none)
> // One row with a non-NULL value:
> try Optional<Int>.fetchOne(db, sql: "SELECT 42")             // .some(.some(42))
> ```

There are many supported value types (Bool, Int, String, Date, Swift enums, etc.). See [Values](#values) for more information.


## Values

GRDB ships with built-in support for the following value types:

- **Swift Standard Library**: Bool, Double, Float, all signed and unsigned integer types, String, [Swift enums](#swift-enums).

- **Foundation**: [Data](#data-and-memory-savings), [Date](#date-and-datecomponents), [DateComponents](#date-and-datecomponents), [Decimal](#nsnumber-nsdecimalnumber-and-decimal), NSNull, [NSNumber](#nsnumber-nsdecimalnumber-and-decimal), NSString, URL, [UUID](#uuid).

- **CoreGraphics**: CGFloat.

- **[DatabaseValue](#databasevalue)**, the type which gives information about the raw value stored in the database.

- **Full-Text Patterns**: [FTS3Pattern](FullTextSearch.md#fts3pattern) and [FTS5Pattern](FullTextSearch.md#fts5pattern).

- Generally speaking, all types that adopt the [`DatabaseValueConvertible`] protocol.

Values can be used as [statement arguments](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/statementarguments):

```swift
let url: URL = ...
let verified: Bool = ...
try db.execute(
    sql: "INSERT INTO link (url, verified) VALUES (?, ?)",
    arguments: [url, verified])
```

Values can be [extracted from rows](#column-values):

```swift
let rows = try Row.fetchCursor(db, sql: "SELECT * FROM link")
while let row = try rows.next() {
    let url: URL = row["url"]
    let verified: Bool = row["verified"]
}
```

Values can be [directly fetched](#value-queries):

```swift
let urls = try URL.fetchAll(db, sql: "SELECT url FROM link")  // [URL]
```

Use values in [Records](Records.md):

```swift
struct Link: FetchableRecord {
    var url: URL
    var isVerified: Bool

    init(row: Row) {
        url = row["url"]
        isVerified = row["verified"]
    }
}
```

Use values in the [query interface](QueryInterface.md):

```swift
let url: URL = ...
let link = try Link.filter { $0.url == url }.fetchOne(db)
```


### Data (and Memory Savings)

**Data** suits the BLOB SQLite columns. It can be stored and fetched from the database just like other [values](#values):

```swift
let rows = try Row.fetchCursor(db, sql: "SELECT data, ...")
while let row = try rows.next() {
    let data: Data = row["data"]
}
```

At each step of the request iteration, the `row[]` subscript creates *two copies* of the database bytes: one fetched by SQLite, and another, stored in the Swift Data value.

**You have the opportunity to save memory** by not copying the data fetched by SQLite:

```swift
while let row = try rows.next() {
    try row.withUnsafeData(name: "data") { (data: Data?) in
        ...
    }
}
```

The non-copied data does not live longer than the iteration step: make sure that you do not use it past this point.


### Date and DateComponents

[**Date**](#date) and [**DateComponents**](#datecomponents) can be stored and fetched from the database.

Here is how GRDB supports the various [date formats](https://www.sqlite.org/lang_datefunc.html) supported by SQLite:

| SQLite format                | Date               | DateComponents |
|:---------------------------- |:------------------:|:--------------:|
| YYYY-MM-DD                   |       Read         | Read / Write   |
| YYYY-MM-DD HH:MM             |       Read         | Read / Write   |
| YYYY-MM-DD HH:MM:SS          |       Read         | Read / Write   |
| YYYY-MM-DD HH:MM:SS.SSS      | Read / Write       | Read / Write   |
| YYYY-MM-DD**T**HH:MM         |       Read         |      Read      |
| YYYY-MM-DD**T**HH:MM:SS      |       Read         |      Read      |
| YYYY-MM-DD**T**HH:MM:SS.SSS  |       Read         |      Read      |
| HH:MM                        |                    | Read / Write   |
| HH:MM:SS                     |                    | Read / Write   |
| HH:MM:SS.SSS                 |                    | Read / Write   |
| Timestamps since unix epoch  |       Read         |                |
| `now`                        |                    |                |


#### Date

**Date** can be stored and fetched from the database just like other [values](#values):

```swift
try db.execute(
    sql: "INSERT INTO player (creationDate, ...) VALUES (?, ...)",
    arguments: [Date(), ...])

let row = try Row.fetchOne(db, ...)!
let creationDate: Date = row["creationDate"]
```

Dates are stored using the format "YYYY-MM-DD HH:MM:SS.SSS" in the UTC time zone. It is precise to the millisecond.

> **Note**: this format was chosen because it is the only format that is:
>
> - Comparable (`ORDER BY date` works)
> - Comparable with the SQLite keyword CURRENT_TIMESTAMP (`WHERE date > CURRENT_TIMESTAMP` works)
> - Able to feed [SQLite date & time functions](https://www.sqlite.org/lang_datefunc.html)
> - Precise enough

See [Codable Records](Records.md#codable-records) for more date customization options, and [`DatabaseValueConvertible`] if you want to define a Date-wrapping type with customized database representation.


#### DateComponents

DateComponents is indirectly supported, through the **DatabaseDateComponents** helper type.

DatabaseDateComponents reads date components from all [date formats supported by SQLite](https://www.sqlite.org/lang_datefunc.html), and stores them in the format of your choice, from HH:MM to YYYY-MM-DD HH:MM:SS.SSS.

```swift
let components = DateComponents()
components.year = 1973
components.month = 9
components.day = 18

// Store "1973-09-18"
let dbComponents = DatabaseDateComponents(components, format: .YMD)
try db.execute(
    sql: "INSERT INTO player (birthDate, ...) VALUES (?, ...)",
    arguments: [dbComponents, ...])

// Read "1973-09-18"
let row = try Row.fetchOne(db, sql: "SELECT birthDate ...")!
let dbComponents: DatabaseDateComponents = row["birthDate"]
dbComponents.format         // .YMD (the actual format found in the database)
dbComponents.dateComponents // DateComponents
```


### NSNumber, NSDecimalNumber, and Decimal

**NSNumber** and **Decimal** can be stored and fetched from the database just like other [values](#values).

Here is how GRDB supports the various data types supported by SQLite:

|                 |    Integer   |     Double   |    String    |
|:--------------- |:------------:|:------------:|:------------:|
| NSNumber        | Read / Write | Read / Write |     Read     |
| NSDecimalNumber | Read / Write | Read / Write |     Read     |
| Decimal         |     Read     |     Read     | Read / Write |

- All three types can decode database integers and doubles:

    ```swift
    let number = try NSNumber.fetchOne(db, sql: "SELECT 10")            // NSNumber
    let number = try NSDecimalNumber.fetchOne(db, sql: "SELECT 1.23")   // NSDecimalNumber
    let number = try Decimal.fetchOne(db, sql: "SELECT -100")           // Decimal
    ```

- All three types decode database strings as decimal numbers:

    ```swift
    let number = try NSNumber.fetchOne(db, sql: "SELECT '10'")          // NSDecimalNumber (sic)
    let number = try NSDecimalNumber.fetchOne(db, sql: "SELECT '1.23'") // NSDecimalNumber
    let number = try Decimal.fetchOne(db, sql: "SELECT '-100'")         // Decimal
    ```

- `NSNumber` and `NSDecimalNumber` send 64-bit signed integers and doubles in the database:

    ```swift
    // INSERT INTO transfer VALUES (10)
    try db.execute(sql: "INSERT INTO transfer VALUES (?)", arguments: [NSNumber(value: 10)])

    // INSERT INTO transfer VALUES (10.0)
    try db.execute(sql: "INSERT INTO transfer VALUES (?)", arguments: [NSNumber(value: 10.0)])

    // INSERT INTO transfer VALUES (10)
    try db.execute(sql: "INSERT INTO transfer VALUES (?)", arguments: [NSDecimalNumber(string: "10.0")])

    // INSERT INTO transfer VALUES (10.5)
    try db.execute(sql: "INSERT INTO transfer VALUES (?)", arguments: [NSDecimalNumber(string: "10.5")])
    ```

- `Decimal` sends decimal strings in the database:

    ```swift
    // INSERT INTO transfer VALUES ('10')
    try db.execute(sql: "INSERT INTO transfer VALUES (?)", arguments: [Decimal(10)])

    // INSERT INTO transfer VALUES ('10.5')
    try db.execute(sql: "INSERT INTO transfer VALUES (?)", arguments: [Decimal(string: "10.5")!])
    ```


### UUID

**UUID** can be stored and fetched from the database just like other [values](#values).

GRDB stores uuids as 16-bytes data blobs, and decodes them from both 16-bytes data blobs and strings such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F".


### Swift Enums

**Swift enums** and generally all types that adopt the [RawRepresentable](https://developer.apple.com/library/tvos/documentation/Swift/Reference/Swift_RawRepresentable_Protocol/index.html) protocol can be stored and fetched from the database just like their raw [values](#values):

```swift
enum Color : Int {
    case red, white, rose
}

enum Grape : String {
    case chardonnay, merlot, riesling
}

// Declare empty DatabaseValueConvertible adoption
extension Color : DatabaseValueConvertible { }
extension Grape : DatabaseValueConvertible { }

// Store
try db.execute(
    sql: "INSERT INTO wine (grape, color) VALUES (?, ?)",
    arguments: [Grape.merlot, Color.red])

// Read
let rows = try Row.fetchCursor(db, sql: "SELECT * FROM wine")
while let row = try rows.next() {
    let grape: Grape = row["grape"]
    let color: Color = row["color"]
}
```

**When a database value does not match any enum case**, you get a fatal error. This fatal error can be avoided with the [DatabaseValue](#databasevalue) type:

```swift
let row = try Row.fetchOne(db, sql: "SELECT 'syrah'")!

row[0] as String  // "syrah"
row[0] as Grape?  // fatal error: could not convert "syrah" to Grape.
row[0] as Grape   // fatal error: could not convert "syrah" to Grape.

let dbValue: DatabaseValue = row[0]
if dbValue.isNull {
    // Handle NULL
} else if let grape = Grape.fromDatabaseValue(dbValue) {
    // Handle valid grape
} else {
    // Handle unknown grape
}
```


## Raw SQLite Pointers

**If not all SQLite APIs are exposed in GRDB, you can still use the [SQLite C Interface](https://www.sqlite.org/c3ref/intro.html) and call [SQLite C functions](https://www.sqlite.org/c3ref/funclist.html).**

To access the C SQLite functions from SQLCipher or the system SQLite, you need to perform an extra import:

```swift
import SQLite3   // System SQLite
import SQLCipher // SQLCipher

let sqliteVersion = String(cString: sqlite3_libversion())
```

Raw pointers to database connections and statements are available through the `Database.sqliteConnection` and `Statement.sqliteStatement` properties:

```swift
try dbQueue.read { db in
    // The raw pointer to a database connection:
    let sqliteConnection = db.sqliteConnection

    // The raw pointer to a statement:
    let statement = try db.makeStatement(sql: "SELECT ...")
    let sqliteStatement = statement.sqliteStatement
}
```

> **Note**
>
> - Those pointers are owned by GRDB: don't close connections or finalize statements created by GRDB.
> - GRDB opens SQLite connections in the "[multi-thread mode](https://www.sqlite.org/threadsafe.html)", which (oddly) means that **they are not thread-safe**. Make sure you touch raw databases and statements inside their dedicated dispatch queues.
> - Use the raw SQLite C Interface at your own risk. GRDB won't prevent you from shooting yourself in the foot.


[Transactions and Savepoints]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/transactions
[SQL Interpolation]: SQLInterpolation.md
[Prepared Statements]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/statement
[prepared statements]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/statement
[`Statement`]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/statement
[`DatabaseValueConvertible`]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasevalueconvertible
[`StatementArguments`]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/statementarguments
