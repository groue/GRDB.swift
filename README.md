<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/groue/GRDB.swift/master/GRDB~dark.png">
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/groue/GRDB.swift/master/GRDB.png">
    <img alt="GRDB: A toolkit for SQLite databases, with a focus on application development." src="https://raw.githubusercontent.com/groue/GRDB.swift/master/GRDB.png">
</picture>

<p align="center">
    <strong>A toolkit for SQLite databases, with a focus on application development</strong><br>
    Proudly serving the community since 2015
</p>

<p align="center">
    <a href="https://developer.apple.com/swift/"><img alt="Swift 5.7" src="https://img.shields.io/badge/swift-5.7-orange.svg?style=flat"></a>
    <a href="https://github.com/groue/GRDB.swift/blob/master/LICENSE"><img alt="License" src="https://img.shields.io/github/license/groue/GRDB.swift.svg?maxAge=2592000"></a>
    <a href="https://github.com/groue/GRDB.swift/actions/workflows/CI.yml"><img alt="CI Status" src="https://github.com/groue/GRDB.swift/actions/workflows/CI.yml/badge.svg?branch=master"></a>
</p>

**Latest release**: August 7, 2024 • [version 6.29.1](https://github.com/groue/GRDB.swift/tree/v6.29.1) • [CHANGELOG](CHANGELOG.md) • [Migrating From GRDB 5 to GRDB 6](Documentation/GRDB6MigrationGuide.md)

**Requirements**: iOS 11.0+ / macOS 10.13+ / tvOS 11.0+ / watchOS 4.0+ &bull; SQLite 3.19.3+ &bull; Swift 5.7+ / Xcode 14+

**Contact**:

- Release announcements and usage tips: follow [@groue](http://twitter.com/groue) on Twitter, [@groue@hachyderm.io](https://hachyderm.io/@groue) on Mastodon.
- Report bugs in a [Github issue](https://github.com/groue/GRDB.swift/issues/new). Make sure you check the [existing issues](https://github.com/groue/GRDB.swift/issues?q=is%3Aopen) first.
- A question? Looking for advice? Do you wonder how to contribute? Fancy a chat? Go to the [GitHub discussions](https://github.com/groue/GRDB.swift/discussions), or the [GRDB forums](https://forums.swift.org/c/related-projects/grdb).


## What is GRDB?

Use this library to save your application’s permanent data into SQLite databases. It comes with built-in tools that address common needs:

- **SQL Generation**
    
    Enhance your application models with persistence and fetching methods, so that you don't have to deal with SQL and raw database rows when you don't want to.

- **Database Observation**
    
    Get notifications when database values are modified. 

- **Robust Concurrency**
    
    Multi-threaded applications can efficiently use their databases, including WAL databases that support concurrent reads and writes. 

- **Migrations**
    
    Evolve the schema of your database as you ship new versions of your application.
    
- **Leverage your SQLite skills**

    Not all developers need advanced SQLite features. But when you do, GRDB is as sharp as you want it to be. Come with your SQL and SQLite skills, or learn new ones as you go!

---

<p align="center">
    <a href="#usage">Usage</a> &bull;
    <a href="#documentation">Documentation</a> &bull;
    <a href="#installation">Installation</a> &bull;
    <a href="#faq">FAQ</a>
</p>

---

## Usage

<details open>
  <summary>Start using the database in four steps</summary>

```swift
import GRDB

// 1. Open a database connection
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

// 2. Define the database schema
try dbQueue.write { db in
    try db.create(table: "player") { t in
        t.primaryKey("id", .text)
        t.column("name", .text).notNull()
        t.column("score", .integer).notNull()
    }
}

// 3. Define a record type
struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var score: Int
}

// 4. Write and read in the database
try dbQueue.write { db in
    try Player(id: "1", name: "Arthur", score: 100).insert(db)
    try Player(id: "2", name: "Barbara", score: 1000).insert(db)
}

let players: [Player] = try dbQueue.read { db in
    try Player.fetchAll(db)
}
```

</details>

<details>
    <summary>Access to raw SQL</summary>

```swift
try dbQueue.write { db in
    try db.execute(sql: """
        CREATE TABLE place (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          favorite BOOLEAN NOT NULL DEFAULT 0,
          latitude DOUBLE NOT NULL,
          longitude DOUBLE NOT NULL)
        """)
    
    try db.execute(sql: """
        INSERT INTO place (title, favorite, latitude, longitude)
        VALUES (?, ?, ?, ?)
        """, arguments: ["Paris", true, 48.85341, 2.3488])
    
    let parisId = db.lastInsertedRowID
    
    // Avoid SQL injection with SQL interpolation
    try db.execute(literal: """
        INSERT INTO place (title, favorite, latitude, longitude)
        VALUES (\("King's Cross"), \(true), \(51.52151), \(-0.12763))
        """)
}
```

See [Executing Updates](#executing-updates)

</details>

<details>
    <summary>Access to raw database rows and values</summary>

```swift
try dbQueue.read { db in
    // Fetch database rows
    let rows = try Row.fetchCursor(db, sql: "SELECT * FROM place")
    while let row = try rows.next() {
        let title: String = row["title"]
        let isFavorite: Bool = row["favorite"]
        let coordinate = CLLocationCoordinate2D(
            latitude: row["latitude"],
            longitude: row["longitude"])
    }
    
    // Fetch values
    let placeCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM place")! // Int
    let placeTitles = try String.fetchAll(db, sql: "SELECT title FROM place") // [String]
}

let placeCount = try dbQueue.read { db in
    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM place")!
}
```

See [Fetch Queries](#fetch-queries)

</details>

<details>
    <summary>Database model types aka "records"</summary>

```swift
struct Place {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    var coordinate: CLLocationCoordinate2D
}

// snip: turn Place into a "record" by adopting the protocols that
// provide fetching and persistence methods.

try dbQueue.write { db in
    // Create database table
    try db.create(table: "place") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("title", .text).notNull()
        t.column("favorite", .boolean).notNull().defaults(to: false)
        t.column("longitude", .double).notNull()
        t.column("latitude", .double).notNull()
    }
    
    var berlin = Place(
        id: nil,
        title: "Berlin",
        isFavorite: false,
        coordinate: CLLocationCoordinate2D(latitude: 52.52437, longitude: 13.41053))
    
    try berlin.insert(db)
    berlin.id // some value
    
    berlin.isFavorite = true
    try berlin.update(db)
}
```

See [Records](#records)

</details>

<details>
    <summary>Query the database with the Swift query interface</summary>

```swift
try dbQueue.read { db in
    // Place
    let paris = try Place.find(db, id: 1)
    
    // Place?
    let berlin = try Place.filter(Column("title") == "Berlin").fetchOne(db)
    
    // [Place]
    let favoritePlaces = try Place
        .filter(Column("favorite") == true)
        .order(Column("title"))
        .fetchAll(db)
    
    // Int
    let favoriteCount = try Place.filter(Column("favorite")).fetchCount(db)
    
    // SQL is always welcome
    let places = try Place.fetchAll(db, sql: "SELECT * FROM place")
}
```

See the [Query Interface](#the-query-interface)

</details>

<details>
    <summary>Database changes notifications</summary>

```swift
// Define the observed value
let observation = ValueObservation.tracking { db in
    try Place.fetchAll(db)
}

// Start observation
let cancellable = observation.start(
    in: dbQueue,
    onError: { error in ... },
    onChange: { (places: [Place]) in print("Fresh places: \(places)") })
```

Ready-made support for Combine and RxSwift:

```swift
// Combine
let cancellable = observation.publisher(in: dbQueue).sink(
    receiveCompletion: { completion in ... },
    receiveValue: { (places: [Place]) in print("Fresh places: \(places)") })

// RxSwift
let disposable = observation.rx.observe(in: dbQueue).subscribe(
    onNext: { (places: [Place]) in print("Fresh places: \(places)") },
    onError: { error in ... })
```

See [Database Observation], [Combine Support], [RxGRDB].

</details>

Documentation
=============

**GRDB runs on top of SQLite**: you should get familiar with the [SQLite FAQ](http://www.sqlite.org/faq.html). For general and detailed information, jump to the [SQLite Documentation](http://www.sqlite.org/docs.html).


#### Demo Applications & Frequently Asked Questions

- [Demo Applications]: Three flavors: vanilla UIKit, Combine + SwiftUI, and Async/Await + SwiftUI.
- [FAQ]

#### Reference

- 📖 [GRDB Reference](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/)

#### Getting Started

- [Installation](#installation)
- [Database Connections]: Connect to SQLite databases

#### SQLite and SQL

- [SQLite API](#sqlite-api): The low-level SQLite API &bull; [executing updates](#executing-updates) &bull; [fetch queries](#fetch-queries) &bull; [SQL Interpolation]

#### Records and the Query Interface

- [Records](#records): Fetching and persistence methods for your custom structs and class hierarchies
- [Query Interface](#the-query-interface): A swift way to generate SQL &bull; [create tables](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseschema) &bull; [requests](#requests) • [associations between record types](Documentation/AssociationsBasics.md)

#### Application Tools

- [Migrations]: Transform your database as your application evolves.
- [Full-Text Search]: Perform efficient and customizable full-text searches.
- [Database Observation]: Observe database changes and transactions.
- [Encryption](#encryption): Encrypt your database with SQLCipher.
- [Backup](#backup): Dump the content of a database to another.
- [Interrupt a Database](#interrupt-a-database): Abort any pending database operation.
- [Sharing a Database]: How to share an SQLite database between multiple processes - recommendations for App Group containers, App Extensions, App Sandbox, and file coordination.

#### Good to Know

- [Concurrency]: How to access databases in a multi-threaded application.
- [Combine](Documentation/Combine.md): Access and observe the database with Combine publishers.
- [Avoiding SQL Injection](#avoiding-sql-injection)
- [Error Handling](#error-handling)
- [Unicode](#unicode)
- [Memory Management](#memory-management)
- [Data Protection](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections)
- :bulb: [Migrating From GRDB 5 to GRDB 6](Documentation/GRDB6MigrationGuide.md)
- :bulb: [Why Adopt GRDB?](Documentation/WhyAdoptGRDB.md)
- :bulb: [Recommended Practices for Designing Record Types](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/recordrecommendedpractices)

#### Companion Libraries

- [GRDBQuery](https://github.com/groue/GRDBQuery): Access and observe the database from your SwiftUI views.
- [GRDBSnapshotTesting](https://github.com/groue/GRDBSnapshotTesting): Test your database. 

**[FAQ]**

**[Sample Code](#sample-code)**


Installation
============

**The installation procedures below have GRDB use the version of SQLite that ships with the target operating system.**

See [Encryption](#encryption) for the installation procedure of GRDB with SQLCipher.

See [Custom SQLite builds](Documentation/CustomSQLiteBuilds.md) for the installation procedure of GRDB with a customized build of SQLite.


## Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) automates the distribution of Swift code. To use GRDB with SPM, add a dependency to `https://github.com/groue/GRDB.swift.git`

GRDB offers two libraries, `GRDB` and `GRDB-dynamic`. Pick only one. When in doubt, prefer `GRDB`. The `GRDB-dynamic` library can reveal useful if you are going to link it with multiple targets within your app and only wish to link to a shared, dynamic framework once. See [How to link a Swift Package as dynamic](https://forums.swift.org/t/how-to-link-a-swift-package-as-dynamic/32062) for more information.

> **Note**: Linux is not currently supported.
>
> **Warning**: Due to an Xcode bug, you will get "No such module 'CSQLite'" errors when you want to embed the GRDB package in other targets than the main application (watch extensions, for example). UI and Unit testing targets are OK, though. See [#642](https://github.com/groue/GRDB.swift/issues/642#issuecomment-575994093) for more information.


## CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Xcode projects. To use GRDB with CocoaPods (version 1.2 or higher), specify in your `Podfile`:

```ruby
pod 'GRDB.swift'
```

GRDB can be installed as a framework, or a static library.

**Important Note for CocoaPods installation**

Due to an [issue](https://github.com/CocoaPods/CocoaPods/issues/11839) in CocoaPods, it is currently not possible to deploy new versions of GRDB to CocoaPods. The last version available on CocoaPods is 6.24.1. To install later versions of GRDB using CocoaPods, use one of the following workarounds:

- Depend on the `GRDB6` branch. This is more or less equivalent to what `pod 'GRDB.swift', '~> 6.0'` would normally do, if CocoaPods would accept new GRDB versions to be published:

    ```ruby
    # Can't use semantic versioning due to https://github.com/CocoaPods/CocoaPods/issues/11839
    pod 'GRDB.swift', git: 'https://github.com/groue/GRDB.swift.git', branch: 'GRDB6'
    ```

- Depend on a specific version explicitly (Replace the tag with the version you want to use):

    ```ruby
    # Can't use semantic versioning due to https://github.com/CocoaPods/CocoaPods/issues/11839
    # Replace the tag with the tag that you want to use.
    pod 'GRDB.swift', git: 'https://github.com/groue/GRDB.swift.git', tag: 'v6.29.0' 
    ```

## Carthage

[Carthage](https://github.com/Carthage/Carthage) is **unsupported**. For some context about this decision, see [#433](https://github.com/groue/GRDB.swift/issues/433).


## Manually

1. [Download](https://github.com/groue/GRDB.swift/releases) a copy of GRDB, or clone its repository and make sure you checkout the latest tagged version.

2. Embed the `GRDB.xcodeproj` project in your own project.

3. Add the `GRDB` target in the **Target Dependencies** section of the **Build Phases** tab of your application target (extension target for WatchOS).

4. Add the `GRDB.framework` to the **Embedded Binaries** section of the **General**  tab of your application target (extension target for WatchOS).

> :bulb: **Tip**: see the [Demo Applications] for examples of such integration.


Database Connections
====================

GRDB provides two classes for accessing SQLite databases: [`DatabaseQueue`] and [`DatabasePool`]:

```swift
import GRDB

// Pick one:
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
```

The differences are:

- Database pools allow concurrent database accesses (this can improve the performance of multithreaded applications).
- Database pools open your SQLite database in the [WAL mode](https://www.sqlite.org/wal.html) (unless read-only).
- Database queues support [in-memory databases](https://www.sqlite.org/inmemorydb.html).

**If you are not sure, choose [`DatabaseQueue`].** You will always be able to switch to [`DatabasePool`] later.

For more information and tips when opening connections, see [Database Connections](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections).


SQLite API
==========

**In this section of the documentation, we will talk SQL.** Jump to the [query interface](#the-query-interface) if SQL is not your cup of tea.

- [Executing Updates](#executing-updates)
- [Fetch Queries](#fetch-queries)
    - [Fetching Methods](#fetching-methods)
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
- [Custom SQL Functions and Aggregates](#custom-sql-functions-and-aggregates)
- [Database Schema Introspection](#database-schema-introspection)
- [Row Adapters](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/rowadapter)
- [Raw SQLite Pointers](#raw-sqlite-pointers)


## Executing Updates

Once granted with a [database connection], the [`execute(sql:arguments:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/database/execute(sql:arguments:)) method executes the SQL statements that do not return any database row, such as `CREATE TABLE`, `INSERT`, `DELETE`, `ALTER`, etc.

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

You can also embed query arguments right into your SQL queries, with [`execute(literal:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/database/execute(literal:)), as in the example below. See [SQL Interpolation] for more details.

```swift
try dbQueue.write { db in
    let name = "O'Brien"
    let score = 550
    try db.execute(literal: """
        INSERT INTO player (name, score) VALUES (\(name), \(score))
        """)
}
```

**Never ever embed values directly in your raw SQL strings**. See [Avoiding SQL Injection](#avoiding-sql-injection) for more information:

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

**After an INSERT statement**, you can get the row ID of the inserted row with [`lastInsertedRowID`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/database/lastinsertedrowid):

```swift
try db.execute(
    sql: "INSERT INTO player (name, score) VALUES (?, ?)",
    arguments: ["Arthur", 1000])
let playerId = db.lastInsertedRowID
```

Don't miss [Records](#records), that provide classic **persistence methods**:

```swift
var player = Player(name: "Arthur", score: 1000)
try player.insert(db)
let playerId = player.id
```


## Fetch Queries

[Database connections] let you fetch database rows, plain values, and custom models aka "records".

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

- [Fetching Methods](#fetching-methods) and [Cursors](#cursors)
- [Row Queries](#row-queries)
- [Value Queries](#value-queries)
- [Records](#records)


### Fetching Methods

**Throughout GRDB**, you can always fetch *cursors*, *arrays*, *sets*, or *single values* of any fetchable type (database [row](#row-queries), simple [value](#value-queries), or custom [record](#records)):

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

📖 [`Cursor`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/cursor)

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

- **Cursors adopt the [Cursor](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/cursor) protocol, which looks a lot like standard [lazy sequences](https://developer.apple.com/reference/swift/lazysequenceprotocol) of Swift.** As such, cursors come with many convenience methods: `compactMap`, `contains`, `dropFirst`, `dropLast`, `drop(while:)`, `enumerated`, `filter`, `first`, `flatMap`, `forEach`, `joined`, `joined(separator:)`, `max`, `max(by:)`, `min`, `min(by:)`, `map`, `prefix`, `prefix(while:)`, `reduce`, `reduce(into:)`, `suffix`:
    
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
- 📖 [`Row`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/row)


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

> **Warning**: avoid the `as!` and `as?` operators:
> 
> ```swift
> if let int = row[...] as? Int { ... } // BAD - doesn't work
> if let int = row[...] as Int? { ... } // GOOD
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
    let row = try Row.fetchOne(db, sql: "SELECT 'Mom’s birthday'")!
    row[0] as String // "Mom’s birthday"
    row[0] as Date?  // fatal error: could not convert "Mom’s birthday" to Date.
    row[0] as Date   // fatal error: could not convert "Mom’s birthday" to Date.
    
    let row = try Row.fetchOne(db, sql: "SELECT 256")!
    row[0] as Int    // 256
    row[0] as UInt8? // fatal error: could not convert 256 to UInt8.
    row[0] as UInt8  // fatal error: could not convert 256 to UInt8.
    ```
    
    Those conversion fatal errors can be avoided with the [DatabaseValue](#databasevalue) type:
    
    ```swift
    let row = try Row.fetchOne(db, sql: "SELECT 'Mom’s birthday'")!
    let dbValue: DatabaseValue = row[0]
    if dbValue.isNull {
        // Handle NULL
    } else if let date = Date.fromDatabaseValue(dbValue) {
        // Handle valid date
    } else {
        // Handle invalid date
    }
    ```
    
    This extra verbosity is the consequence of having to deal with an untrusted database: you may consider fixing the content of your database instead. See [Fatal Errors](#fatal-errors) for more information.
    
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

📖 [`DatabaseValue`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasevalue)

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

You can extract regular [values](#values) (Bool, Int, String, Date, Swift enums, etc.) from `DatabaseValue` with the [fromDatabaseValue()](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasevalueconvertible/fromdatabasevalue(_:)-21zzv) method:

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
let row = try Row.fetchOne(db, sql: "SELECT 'Mom’s birthday'")!
let dbValue: DatabaseValue = row[0]
let string = String.fromDatabaseValue(dbValue) // "Mom’s birthday"
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

📖 [`DatabaseValueConvertible`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasevalueconvertible)

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

- **Full-Text Patterns**: [FTS3Pattern](Documentation/FullTextSearch.md#fts3pattern) and [FTS5Pattern](Documentation/FullTextSearch.md#fts5pattern).

- Generally speaking, all types that adopt the [`DatabaseValueConvertible`] protocol.

Values can be used as [statement arguments](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/statementarguments):

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

Use values in [Records](#records):

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

Use values in the [query interface](#the-query-interface):

```swift
let url: URL = ...
let link = try Link.filter(Column("url") == url).fetchOne(db)
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
| YYYY-MM-DD                   |       Read ¹       | Read / Write   |
| YYYY-MM-DD HH:MM             |       Read ¹ ²     | Read ² / Write |
| YYYY-MM-DD HH:MM:SS          |       Read ¹ ²     | Read ² / Write |
| YYYY-MM-DD HH:MM:SS.SSS      | Read ¹ ² / Write ¹ | Read ² / Write |
| YYYY-MM-DD**T**HH:MM         |       Read ¹ ²     |      Read ²    |
| YYYY-MM-DD**T**HH:MM:SS      |       Read ¹ ²     |      Read ²    |
| YYYY-MM-DD**T**HH:MM:SS.SSS  |       Read ¹ ²     |      Read ²    |
| HH:MM                        |                    | Read ² / Write |
| HH:MM:SS                     |                    | Read ² / Write |
| HH:MM:SS.SSS                 |                    | Read ² / Write |
| Timestamps since unix epoch  |       Read ³       |                |
| `now`                        |                    |                |

¹ Missing components are assumed to be zero. Dates are stored and read in the UTC time zone, unless the format is followed by a timezone indicator ⁽²⁾.

² This format may be optionally followed by a timezone indicator of the form `[+-]HH:MM` or just `Z`.

³ GRDB 2+ interprets numerical values as timestamps that fuel `Date(timeIntervalSince1970:)`. Previous GRDB versions used to interpret numbers as [julian days](https://en.wikipedia.org/wiki/Julian_day). Julian days are still supported, with the `Date(julianDay:)` initializer.

> **Warning**: the range of valid years in the SQLite date formats is 0000-9999. You will need to pick another date format when your application needs to process years outside of this range. See the following chapters.


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
>
> **Warning**: the range of valid years in the SQLite date format is 0000-9999. You will experience problems with years outside of this range, such as decoding errors, or invalid date computations with [SQLite date & time functions](https://www.sqlite.org/lang_datefunc.html).

Some applications may prefer another date format:

- Some may prefer ISO-8601, with a `T` separator.
- Some may prefer ISO-8601, with a time zone.
- Some may need to store years beyond the 0000-9999 range.
- Some may need sub-millisecond precision.
- Some may need exact `Date` roundtrip.
- Etc.

**You should think twice before choosing a different date format:**

- ISO-8601 is about *exchange and communication*, when SQLite is about *storage and data manipulation*. Sharing the same representation in your database and in JSON files only provides a superficial convenience, and should be the least of your priorities. Don't store dates as ISO-8601 without understanding what you lose. For example, ISO-8601 time zones forbid database-level date comparison. 
- Sub-millisecond precision and exact `Date` roundtrip are not as obvious needs as it seems at first sight. Dates generally don't precisely roundtrip as soon as they leave your application anyway, because the other systems your app communicates with use their own date representation (the Android version of your app, the server your application is talking to, etc.) On top of that, `Date` comparison is at least as hard and nasty as [floating point comparison](https://www.google.com/search?q=floating+point+comparison+is+hard).

The customization of date format is explicit. For example:

```swift
let date = Date()
let timeInterval = date.timeIntervalSinceReferenceDate
try db.execute(
    sql: "INSERT INTO player (creationDate, ...) VALUES (?, ...)",
    arguments: [timeInterval, ...])

if let row = try Row.fetchOne(db, ...) {
    let timeInterval: TimeInterval = row["creationDate"]
    let creationDate = Date(timeIntervalSinceReferenceDate: timeInterval)
}
```

See also [Codable Records] for more date customization options, and [`DatabaseValueConvertible`] if you want to define a Date-wrapping type with customized database representation.


#### DateComponents

DateComponents is indirectly supported, through the **DatabaseDateComponents** helper type.

DatabaseDateComponents reads date components from all [date formats supported by SQLite](https://www.sqlite.org/lang_datefunc.html), and stores them in the format of your choice, from HH:MM to YYYY-MM-DD HH:MM:SS.SSS.

> **Warning**: the range of valid years is 0000-9999. You will experience problems with years outside of this range, such as decoding errors, or invalid date computations with [SQLite date & time functions](https://www.sqlite.org/lang_datefunc.html). See [Date](#date) for more information.

DatabaseDateComponents can be stored and fetched from the database just like other [values](#values):

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
    
    > **Warning**: since SQLite does not support decimal numbers, sending a non-integer `NSDecimalNumber` can result in a loss of precision during the conversion to double.
    >
    > Instead of sending non-integer `NSDecimalNumber` to the database, you may prefer:
    >
    > - Send `Decimal` instead (those store decimal strings in the database).
    > - Send integers instead (for example, store amounts of cents instead of amounts of Euros).

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


## Custom SQL Functions and Aggregates

**SQLite lets you define SQL functions and aggregates.**

A custom SQL function or aggregate extends SQLite:

```sql
SELECT reverse(name) FROM player;   -- custom function
SELECT maxLength(name) FROM player; -- custom aggregate
```

- [Custom SQL Functions](#custom-sql-functions)
- [Custom Aggregates](#custom-aggregates)


### Custom SQL Functions

📖 [`DatabaseFunction`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasefunction)

A *function* argument takes an array of [DatabaseValue](#databasevalue), and returns any valid [value](#values) (Bool, Int, String, Date, Swift enums, etc.) The number of database values is guaranteed to be *argumentCount*.

SQLite has the opportunity to perform additional optimizations when functions are "pure", which means that their result only depends on their arguments. So make sure to set the *pure* argument to true when possible.

```swift
let reverse = DatabaseFunction("reverse", argumentCount: 1, pure: true) { (values: [DatabaseValue]) in
    // Extract string value, if any...
    guard let string = String.fromDatabaseValue(values[0]) else {
        return nil
    }
    // ... and return reversed string:
    return String(string.reversed())
}
```

You make a function available to a database connection through its configuration:

```swift
var config = Configuration()
config.prepareDatabase { db in
    db.add(function: reverse)
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

try dbQueue.read { db in
    // "oof"
    try String.fetchOne(db, sql: "SELECT reverse('foo')")!
}
```


**Functions can take a variable number of arguments:**

When you don't provide any explicit *argumentCount*, the function can take any number of arguments:

```swift
let averageOf = DatabaseFunction("averageOf", pure: true) { (values: [DatabaseValue]) in
    let doubles = values.compactMap { Double.fromDatabaseValue($0) }
    return doubles.reduce(0, +) / Double(doubles.count)
}
db.add(function: averageOf)

// 2.0
try Double.fetchOne(db, sql: "SELECT averageOf(1, 2, 3)")!
```


**Functions can throw:**

```swift
let sqrt = DatabaseFunction("sqrt", argumentCount: 1, pure: true) { (values: [DatabaseValue]) in
    guard let double = Double.fromDatabaseValue(values[0]) else {
        return nil
    }
    guard double >= 0 else {
        throw DatabaseError(message: "invalid negative number")
    }
    return sqrt(double)
}
db.add(function: sqrt)

// SQLite error 1 with statement `SELECT sqrt(-1)`: invalid negative number
try Double.fetchOne(db, sql: "SELECT sqrt(-1)")!
```


**Use custom functions in the [query interface](#the-query-interface):**

```swift
// SELECT reverseString("name") FROM player
Player.select(reverseString(nameColumn))
```


**GRDB ships with built-in SQL functions that perform unicode-aware string transformations.** See [Unicode](#unicode).


### Custom Aggregates

📖 [`DatabaseFunction`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasefunction), [`DatabaseAggregate`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseaggregate)

Before registering a custom aggregate, you need to define a type that adopts the `DatabaseAggregate` protocol:

```swift
protocol DatabaseAggregate {
    // Initializes an aggregate
    init()
    
    // Called at each step of the aggregation
    mutating func step(_ dbValues: [DatabaseValue]) throws
    
    // Returns the final result
    func finalize() throws -> DatabaseValueConvertible?
}
```

For example:

```swift
struct MaxLength : DatabaseAggregate {
    var maxLength: Int = 0
    
    mutating func step(_ dbValues: [DatabaseValue]) {
        // At each step, extract string value, if any...
        guard let string = String.fromDatabaseValue(dbValues[0]) else {
            return
        }
        // ... and update the result
        let length = string.count
        if length > maxLength {
            maxLength = length
        }
    }
    
    func finalize() -> DatabaseValueConvertible? {
        maxLength
    }
}

let maxLength = DatabaseFunction(
    "maxLength",
    argumentCount: 1,
    pure: true,
    aggregate: MaxLength.self)
```

Like [custom SQL Functions](#custom-sql-functions), you make an aggregate function available to a database connection through its configuration:

```swift
var config = Configuration()
config.prepareDatabase { db in
    db.add(function: maxLength)
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

try dbQueue.read { db in
    // Some Int
    try Int.fetchOne(db, sql: "SELECT maxLength(name) FROM player")!
}
```

The `step` method of the aggregate takes an array of [DatabaseValue](#databasevalue). This array contains as many values as the *argumentCount* parameter (or any number of values, when *argumentCount* is omitted).

The `finalize` method of the aggregate returns the final aggregated [value](#values) (Bool, Int, String, Date, Swift enums, etc.).

SQLite has the opportunity to perform additional optimizations when aggregates are "pure", which means that their result only depends on their inputs. So make sure to set the *pure* argument to true when possible.


**Use custom aggregates in the [query interface](#the-query-interface):**

```swift
// SELECT maxLength("name") FROM player
let request = Player.select(maxLength.apply(nameColumn))
try Int.fetchOne(db, request) // Int?
```


## Database Schema Introspection

GRDB comes with a set of schema introspection methods:

```swift
try dbQueue.read { db in
    // Bool, true if the table exists
    try db.tableExists("player")
    
    // [ColumnInfo], the columns in the table
    try db.columns(in: "player")
    
    // PrimaryKeyInfo
    try db.primaryKey("player")
    
    // [ForeignKeyInfo], the foreign keys defined on the table
    try db.foreignKeys(on: "player")
    
    // [IndexInfo], the indexes defined on the table
    try db.indexes(on: "player")
    
    // Bool, true if column(s) is a unique key (primary key or unique index)
    try db.table("player", hasUniqueKey: ["email"])
}

// Bool, true if argument is the name of an internal SQLite table
Database.isSQLiteInternalTable(...)

// Bool, true if argument is the name of an internal GRDB table
Database.isGRDBInternalTable(...)
```

For more information, see [`tableExists(_:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/database/tableexists(_:)) and related methods.


## Raw SQLite Pointers

**If not all SQLite APIs are exposed in GRDB, you can still use the [SQLite C Interface](https://www.sqlite.org/c3ref/intro.html) and call [SQLite C functions](https://www.sqlite.org/c3ref/funclist.html).**

Those functions are embedded right into the GRDB module, regardless of the underlying SQLite implementation (system SQLite, [SQLCipher](#encryption), or [custom SQLite build]):

```swift
import GRDB

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


Records
=======

**On top of the [SQLite API](#sqlite-api), GRDB provides protocols and a class** that help manipulating database rows as regular objects named "records":

```swift
try dbQueue.write { db in
    if var place = try Place.fetchOne(db, id: 1) {
        place.isFavorite = true
        try place.update(db)
    }
}
```

Of course, you need to open a [database connection], and [create database tables](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseschema) first.

To define your custom records, you subclass the ready-made `Record` class, or you extend your structs and classes with protocols that come with focused sets of features: fetching methods, persistence methods, record comparison...

Extending structs with record protocols is more "swifty". Subclassing the Record class is more "classic". You can choose either way. See some [examples of record definitions](#examples-of-record-definitions), and the [list of record methods](#list-of-record-methods) for an overview.

> **Note**: if you are familiar with Core Data's NSManagedObject or Realm's Object, you may experience a cultural shock: GRDB records are not uniqued, do not auto-update, and do not lazy-load. This is both a purpose, and a consequence of protocol-oriented programming. You should read [How to build an iOS application with SQLite and GRDB.swift](https://medium.com/@gwendal.roue/how-to-build-an-ios-application-with-sqlite-and-grdb-swift-d023a06c29b3) for a general introduction.
>
> :bulb: **Tip**: after you have read this chapter, check the [Recommended Practices for Designing Record Types](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/recordrecommendedpractices) Guide.
>
> :bulb: **Tip**: see the [Demo Applications] for sample apps that uses records.

**Overview**

- [Inserting Records](#inserting-records)
- [Fetching Records](#fetching-records)
- [Updating Records](#updating-records)
- [Deleting Records](#deleting-records)
- [Counting Records](#counting-records)

**Protocols and the Record Class**

- [Record Protocols Overview](#record-protocols-overview)
- [FetchableRecord Protocol](#fetchablerecord-protocol)
- [TableRecord Protocol](#tablerecord-protocol)
- [PersistableRecord Protocol](#persistablerecord-protocol)
    - [Persistence Methods]
    - [Persistence Methods and the `RETURNING` clause]
    - [Persistence Callbacks]
- [Identifiable Records]
- [Codable Records]
- [Record Class](#record-class)
- [Record Comparison]
- [Record Customization Options]
- [Record Timestamps and Transaction Date]

**Records in a Glance**

- [Examples of Record Definitions](#examples-of-record-definitions)
- [List of Record Methods](#list-of-record-methods)


### Inserting Records

To insert a record in the database, call the `insert` method:

```swift
let player = Player(name: "Arthur", email: "arthur@example.com")
try player.insert(db)
```

:point_right: `insert` is available for subclasses of the [Record](#record-class) class, and types that adopt the [PersistableRecord] protocol.


### Fetching Records

To fetch records from the database, call a [fetching method](#fetching-methods):

```swift
let arthur = try Player.fetchOne(db,            // Player?
    sql: "SELECT * FROM players WHERE name = ?",
    arguments: ["Arthur"])

let bestPlayers = try Player                    // [Player]
    .order(Column("score").desc)
    .limit(10)
    .fetchAll(db)
    
let spain = try Country.fetchOne(db, id: "ES")  // Country?
let italy = try Country.find(db, id: "IT")      // Country
```

:point_right: Fetching from raw SQL is available for subclasses of the [Record](#record-class) class, and types that adopt the [FetchableRecord] protocol.

:point_right: Fetching without SQL, using the [query interface](#the-query-interface), is available for subclasses of the [Record](#record-class) class, and types that adopt both [FetchableRecord] and [TableRecord] protocol.


### Updating Records

To update a record in the database, call the `update` method:

```swift
var player: Player = ...
player.score = 1000
try player.update(db)
```

It is possible to [avoid useless updates](#record-comparison):

```swift
// does not hit the database if score has not changed
try player.updateChanges(db) {
    $0.score = 1000
}
```

See the [query interface](#the-query-interface) for batch updates:

```swift
try Player
    .filter(Column("team") == "red")
    .updateAll(db, Column("score") += 1)
```

:point_right: update methods are available for subclasses of the [Record](#record-class) class, and types that adopt the [PersistableRecord] protocol. Batch updates are available on the [TableRecord] protocol.


### Deleting Records

To delete a record in the database, call the `delete` method:

```swift
let player: Player = ...
try player.delete(db)
```

You can also delete by primary key, unique key, or perform batch deletes (see [Delete Requests](#delete-requests)):

```swift
try Player.deleteOne(db, id: 1)
try Player.deleteOne(db, key: ["email": "arthur@example.com"])
try Country.deleteAll(db, ids: ["FR", "US"])
try Player
    .filter(Column("email") == nil)
    .deleteAll(db)
```

:point_right: delete methods are available for subclasses of the [Record](#record-class) class, and types that adopt the [PersistableRecord] protocol. Batch deletes are available on the [TableRecord] protocol.


### Counting Records

To count records, call the `fetchCount` method:

```swift
let playerCount: Int = try Player.fetchCount(db)

let playerWithEmailCount: Int = try Player
    .filter(Column("email") == nil)
    .fetchCount(db)
```

:point_right: `fetchCount` is available for subclasses of the [Record](#record-class) class, and types that adopt the [TableRecord] protocol.


Details follow:

- [Record Protocols Overview](#record-protocols-overview)
- [FetchableRecord Protocol](#fetchablerecord-protocol)
- [TableRecord Protocol](#tablerecord-protocol)
- [PersistableRecord Protocol](#persistablerecord-protocol)
- [Identifiable Records]
- [Codable Records]
- [Record Class](#record-class)
- [Record Comparison]
- [Record Customization Options]
- [Examples of Record Definitions](#examples-of-record-definitions)
- [List of Record Methods](#list-of-record-methods)


## Record Protocols Overview

**GRDB ships with three record protocols**. Your own types will adopt one or several of them, according to the abilities you want to extend your types with.

- [FetchableRecord] is able to **decode database rows**.
    
    ```swift
    struct Place: FetchableRecord { ... }
    let places = try dbQueue.read { db in
        try Place.fetchAll(db, sql: "SELECT * FROM place")
    }
    ```
    
    > :bulb: **Tip**: `FetchableRecord` can derive its implementation from the standard `Decodable` protocol. See [Codable Records] for more information.
    
    `FetchableRecord` can decode database rows, but it is not able to build SQL requests for you. For that, you also need `TableRecord`:
    
- [TableRecord] is able to **generate SQL queries**:
    
    ```swift
    struct Place: TableRecord { ... }
    let placeCount = try dbQueue.read { db in
        // Generates and runs `SELECT COUNT(*) FROM place`
        try Place.fetchCount(db)
    }
    ```
    
    When a type adopts both `TableRecord` and `FetchableRecord`, it can load from those requests:
    
    ```swift
    struct Place: TableRecord, FetchableRecord { ... }
    try dbQueue.read { db in
        let places = try Place.order(Column("title")).fetchAll(db)
        let paris = try Place.fetchOne(id: 1)
    }
    ```

- [PersistableRecord] is able to **write**: it can create, update, and delete rows in the database:
    
    ```swift
    struct Place : PersistableRecord { ... }
    try dbQueue.write { db in
        try Place.delete(db, id: 1)
        try Place(...).insert(db)
    }
    ```
    
    A persistable record can also [compare](#record-comparison) itself against other records, and avoid useless database updates.
    
    > :bulb: **Tip**: `PersistableRecord` can derive its implementation from the standard `Encodable` protocol. See [Codable Records] for more information.


## FetchableRecord Protocol

📖 [`FetchableRecord`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/fetchablerecord)

**The FetchableRecord protocol grants fetching methods to any type** that can be built from a database row:

```swift
protocol FetchableRecord {
    /// Row initializer
    init(row: Row) throws
}
```

**To use FetchableRecord**, subclass the [Record](#record-class) class, or adopt it explicitly. For example:

```swift
struct Place {
    var id: Int64?
    var title: String
    var coordinate: CLLocationCoordinate2D
}

extension Place : FetchableRecord {
    init(row: Row) {
        id = row["id"]
        title = row["title"]
        coordinate = CLLocationCoordinate2D(
            latitude: row["latitude"],
            longitude: row["longitude"])
    }
}
```

Rows also accept column enums:

```swift
extension Place : FetchableRecord {
    enum Columns: String, ColumnExpression {
        case id, title, latitude, longitude
    }
    
    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        coordinate = CLLocationCoordinate2D(
            latitude: row[Columns.latitude],
            longitude: row[Columns.longitude])
    }
}
```

See [column values](#column-values) for more information about the `row[]` subscript.

When your record type adopts the standard Decodable protocol, you don't have to provide the implementation for `init(row:)`. See [Codable Records] for more information:

```swift
// That's all
struct Player: Decodable, FetchableRecord {
    var id: Int64
    var name: String
    var score: Int
}
```

FetchableRecord allows adopting types to be fetched from SQL queries:

```swift
try Place.fetchCursor(db, sql: "SELECT ...", arguments:...) // A Cursor of Place
try Place.fetchAll(db, sql: "SELECT ...", arguments:...)    // [Place]
try Place.fetchSet(db, sql: "SELECT ...", arguments:...)    // Set<Place>
try Place.fetchOne(db, sql: "SELECT ...", arguments:...)    // Place?
```

See [fetching methods](#fetching-methods) for information about the `fetchCursor`, `fetchAll`, `fetchSet` and `fetchOne` methods. See [`StatementArguments`] for more information about the query arguments.

> **Note**: for performance reasons, the same row argument to `init(row:)` is reused during the iteration of a fetch query. If you want to keep the row for later use, make sure to store a copy: `self.row = row.copy()`.

> **Note**: The `FetchableRecord.init(row:)` initializer fits the needs of most applications. But some application are more demanding than others. When FetchableRecord does not exactly provide the support you need, have a look at the [Beyond FetchableRecord] chapter.


## TableRecord Protocol

📖 [`TableRecord`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerecord)

**The TableRecord protocol** generates SQL for you. To use TableRecord, subclass the [Record](#record-class) class, or adopt it explicitly:

```swift
protocol TableRecord {
    static var databaseTableName: String { get }
    static var databaseSelection: [any SQLSelectable] { get }
}
```

The `databaseSelection` type property is optional, and documented in the [Columns Selected by a Request] chapter.

The `databaseTableName` type property is the name of a database table. By default, it is derived from the type name:

```swift
struct Place: TableRecord { }
print(Place.databaseTableName) // prints "place"
```

For example:

- Place: `place`
- Country: `country`
- PostalAddress: `postalAddress`
- HTTPRequest: `httpRequest`
- TOEFL: `toefl`

You can still provide a custom table name:

```swift
struct Place: TableRecord {
    static let databaseTableName = "location"
}
print(Place.databaseTableName) // prints "location"
```

Subclasses of the [Record](#record-class) class must always override their superclass's `databaseTableName` property:

```swift
class Place: Record {
    override class var databaseTableName: String { "place" }
}
print(Place.databaseTableName) // prints "place"
```

When a type adopts both TableRecord and [FetchableRecord](#fetchablerecord-protocol), it can be fetched using the [query interface](#the-query-interface):

```swift
// SELECT * FROM place WHERE name = 'Paris'
let paris = try Place.filter(nameColumn == "Paris").fetchOne(db)
```

TableRecord can also fetch deal with primary and unique keys: see [Fetching by Key](#fetching-by-key) and [Testing for Record Existence](#testing-for-record-existence).


## PersistableRecord Protocol

📖 [`EncodableRecord`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/encodablerecord), [`MutablePersistableRecord`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/mutablepersistablerecord), [`PersistableRecord`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/persistablerecord)

**GRDB record types can create, update, and delete rows in the database.**

Those abilities are granted by three protocols:

```swift
// Defines how a record encodes itself into the database
protocol EncodableRecord {
    /// Defines the values persisted in the database
    func encode(to container: inout PersistenceContainer) throws
}

// Adds persistence methods
protocol MutablePersistableRecord: TableRecord, EncodableRecord {
    /// Optional method that lets your adopting type store its rowID upon
    /// successful insertion. Don't call it directly: it is called for you.
    mutating func didInsert(_ inserted: InsertionSuccess)
}

// Adds immutability
protocol PersistableRecord: MutablePersistableRecord {
    /// Non-mutating version of the optional didInsert(_:)
    func didInsert(_ inserted: InsertionSuccess)
}
```

Yes, three protocols instead of one. Here is how you pick one or the other:

- **If your type is a class**, choose `PersistableRecord`. On top of that, implement `didInsert(_:)` if the database table has an auto-incremented primary key.

- **If your type is a struct, and the database table has an auto-incremented primary key**, choose `MutablePersistableRecord`, and implement `didInsert(_:)`.

- **Otherwise**, choose `PersistableRecord`, and ignore `didInsert(_:)`.

The `encode(to:)` method defines which [values](#values) (Bool, Int, String, Date, Swift enums, etc.) are assigned to database columns.

The optional `didInsert` method lets the adopting type store its rowID after successful insertion, and is only useful for tables that have an auto-incremented primary key. It is called from a protected dispatch queue, and serialized with all database updates.

**To use the persistable protocols**, subclass the [Record](#record-class) class, or adopt one of them explicitly. For example:

```swift
extension Place : MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["title"] = title
        container["latitude"] = coordinate.latitude
        container["longitude"] = coordinate.longitude
    }
    
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

var paris = Place(
    id: nil,
    title: "Paris",
    coordinate: CLLocationCoordinate2D(latitude: 48.8534100, longitude: 2.3488000))

try paris.insert(db)
paris.id   // some value
```

Persistence containers also accept column enums:

```swift
extension Place : MutablePersistableRecord {
    enum Columns: String, ColumnExpression {
        case id, title, latitude, longitude
    }
    
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.latitude] = coordinate.latitude
        container[Columns.longitude] = coordinate.longitude
    }
}
```

When your record type adopts the standard Encodable protocol, you don't have to provide the implementation for `encode(to:)`. See [Codable Records] for more information:

```swift
// That's all
struct Player: Encodable, MutablePersistableRecord {
    var id: Int64?
    var name: String
    var score: Int
    
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```


### Persistence Methods

[Record](#record-class) subclasses and types that adopt [PersistableRecord] are given methods that insert, update, and delete:

```swift
// INSERT
try place.insert(db)
let insertedPlace = try place.inserted(db) // non-mutating

// UPDATE
try place.update(db)
try place.update(db, columns: ["title"])

// Maybe UPDATE
try place.updateChanges(db, from: otherPlace)
try place.updateChanges(db) { $0.isFavorite = true }
try place.updateChanges(db) // Record class only

// INSERT or UPDATE
try place.save(db)
let savedPlace = place.saved(db) // non-mutating

// UPSERT
try place.upsert(db)
let insertedPlace = place.upsertAndFetch(db)

// DELETE
try place.delete(db)

// EXISTENCE CHECK
let exists = try place.exists(db)
```

See [Upsert](#upsert) below for more information about upserts.

**The [TableRecord] protocol comes with batch operations**:

```swift
// UPDATE
try Place.updateAll(db, ...)

// DELETE
try Place.deleteAll(db)
try Place.deleteAll(db, ids:...)
try Place.deleteAll(db, keys:...)
try Place.deleteOne(db, id:...)
try Place.deleteOne(db, key:...)
```

For more information about batch updates, see [Update Requests](#update-requests).

- All persistence methods can throw a [DatabaseError](#error-handling).

- `update` and `updateChanges` throw [RecordError] if the database does not contain any row for the primary key of the record.

- `save` makes sure your values are stored in the database. It performs an UPDATE if the record has a non-null primary key, and then, if no row was modified, an INSERT. It directly performs an INSERT if the record has no primary key, or a null primary key.

- `delete` and `deleteOne` returns whether a database row was deleted or not. `deleteAll` returns the number of deleted rows. `updateAll` returns the number of updated rows. `updateChanges` returns whether a database row was updated or not.

**All primary keys are supported**, including composite primary keys that span several columns, and the [hidden `rowid` column](https://www.sqlite.org/rowidtable.html).

**To customize persistence methods**, you provide [Persistence Callbacks], described below. Do not attempt at overriding the ready-made persistence methods.

### Upsert

[UPSERT](https://www.sqlite.org/lang_UPSERT.html) is an SQLite feature that causes an INSERT to behave as an UPDATE or a no-op if the INSERT would violate a uniqueness constraint (primary key or unique index).

> **Note**: Upsert apis are available from SQLite 3.35.0+: iOS 15.0+, macOS 12.0+, tvOS 15.0+, watchOS 8.0+, or with a [custom SQLite build] or [SQLCipher](#encryption).
>
> **Note**: With regard to [persistence callbacks](#available-callbacks), an upsert behaves exactly like an insert. In particular: the `aroundInsert(_:)` and `didInsert(_:)` callbacks reports the rowid of the inserted or updated row; `willUpdate`, `aroundUdate`, `didUdate` are not called.

[PersistableRecord] provides three upsert methods:

- `upsert(_:)`
    
    Inserts or updates a record.
    
    The upsert behavior is triggered by a violation of any uniqueness constraint on the table (primary key or unique index). In case of conflict, all columns but the primary key are overwritten with the inserted values:
    
    ```swift
    struct Player: Encodable, PersistableRecord {
        var id: Int64
        var name: String
        var score: Int
    }
    
    // INSERT INTO player (id, name, score)
    // VALUES (1, 'Arthur', 1000)
    // ON CONFLICT DO UPDATE SET
    //   name = excluded.name,
    //   score = excluded.score
    let player = Player(id: 1, name: "Arthur", score: 1000)
    try player.upsert(db)
    ```

- `upsertAndFetch(_:onConflict:doUpdate:)` (requires [FetchableRecord] conformance)

    Inserts or updates a record, and returns the upserted record.
    
    The `onConflict` and `doUpdate` arguments let you further control the upsert behavior. Make sure you check the [SQLite UPSERT documentation](https://www.sqlite.org/lang_UPSERT.html) for detailed information.
    
    - `onConflict`: the "conflict target" is the array of columns in the uniqueness constraint (primary key or unique index) that triggers the upsert.
        
        If empty (the default), all uniqueness constraint are considered.
    
    - `doUpdate`: a closure that returns columns assignments to perform in case of conflict. Other columns are overwritten with the inserted values.
        
        By default, all inserted columns but the primary key and the conflict target are overwritten.
    
    In the example below, we upsert the new vocabulary word "jovial". It is inserted if that word is not already in the dictionary. Otherwise, `count` is incremented, `isTainted` is not overwritten, and `kind` is overwritten:
    
    ```swift
    // CREATE TABLE vocabulary(
    //   word TEXT NOT NULL PRIMARY KEY,
    //   kind TEXT NOT NULL,
    //   isTainted BOOLEAN DEFAULT 0,
    //   count INT DEFAULT 1))
    struct Vocabulary: Encodable, PersistableRecord {
        var word: String
        var kind: String
        var isTainted: Bool
    }
    
    // INSERT INTO vocabulary(word, kind, isTainted)
    // VALUES('jovial', 'adjective', 0)
    // ON CONFLICT(word) DO UPDATE SET \
    //   count = count + 1,   -- on conflict, count is incremented
    //   kind = excluded.kind -- on conflict, kind is overwritten
    // RETURNING *
    let vocabulary = Vocabulary(word: "jovial", kind: "adjective", isTainted: false)
    let upserted = try vocabulary.upsertAndFetch(
        db, onConflict: ["word"],
        doUpdate: { _ in
            [Column("count") += 1,            // on conflict, count is incremented
             Column("isTainted").noOverwrite] // on conflict, isTainted is NOT overwritten
        })
    ```
    
    The `doUpdate` closure accepts an `excluded` TableAlias argument that refers to the inserted values that trigger the conflict. You can use it to specify an explicit overwrite, or to perform a computation. In the next example, the upsert keeps the maximum date in case of conflict:
    
    ```swift
    // INSERT INTO message(id, text, date)
    // VALUES(...)
    // ON CONFLICT DO UPDATE SET \
    //   text = excluded.text,
    //   date = MAX(date, excluded.date)
    // RETURNING *
    let upserted = try message.upsertAndFetch(doUpdate: { excluded in
        // keep the maximum date in case of conflict
        [Column("date").set(to: max(Column("date"), excluded["date"]))]
    })
    ```

- `upsertAndFetch(_:as:onConflict:doUpdate:)` (does not require [FetchableRecord] conformance)

    This method is identical to `upsertAndFetch(_:onConflict:doUpdate:)` described above, but you can provide a distinct [FetchableRecord] record type as a result, in order to specify the returned columns.

### Persistence Methods and the `RETURNING` clause

SQLite is able to return values from a inserted, updated, or deleted row, with the [`RETURNING` clause](https://www.sqlite.org/lang_returning.html).

> **Note**: Support for the `RETURNING` clause is available from SQLite 3.35.0+: iOS 15.0+, macOS 12.0+, tvOS 15.0+, watchOS 8.0+, or with a [custom SQLite build] or [SQLCipher](#encryption).

The `RETURNING` clause helps dealing with database features such as auto-incremented ids, default values, and [generated columns](https://sqlite.org/gencol.html). You can, for example, insert a few columns and fetch the default or generated ones in one step.

GRDB uses the `RETURNING` clause in all persistence methods that contain `AndFetch` in their name.

For example, given a database table with an auto-incremented primary key and a default score:

```swift
try dbQueue.write { db in
    try db.execute(sql: """
        CREATE TABLE player(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          score INTEGER NOT NULL DEFAULT 1000)
        """)
}
```

You can define a record type with full database information, and another partial record type that deals with a subset of columns:

```swift
// A player with full database information
struct Player: Codable, PersistableRecord, FetchableRecord {
    var id: Int64
    var name: String
    var score: Int
}

// A partial player
struct PartialPlayer: Encodable, PersistableRecord {
    static let databaseTableName = "player"
    var name: String
}
```

And now you can get a full player by inserting a partial one:

```swift
try dbQueue.write { db in
    let partialPlayer = PartialPlayer(name: "Alice")
    
    // INSERT INTO player (name) VALUES ('Alice') RETURNING *
    if let player = try partialPlayer.insertAndFetch(db, as: Player.self) {
        print(player.id)    // The inserted id
        print(player.name)  // The inserted name
        print(player.score) // The default score
    }
}
```

For extra precision, you can select only the columns you need, and fetch the desired value from the provided prepared [`Statement`]:

```swift
try dbQueue.write { db in
    let partialPlayer = PartialPlayer(name: "Alice")
    
    // INSERT INTO player (name) VALUES ('Alice') RETURNING score
    let score = try partialPlayer.insertAndFetch(db, selection: [Column("score")]) { statement in
        try Int.fetchOne(statement)
    }
    print(score) // Prints 1000, the default score
}
```

There are other similar persistence methods, such as `upsertAndFetch`, `saveAndFetch`, `updateAndFetch`, `updateChangesAndFetch`, etc. They all behave like `upsert`, `save`, `update`, `updateChanges`, except that they return saved values. For example:

```swift
// Save and return the saved player
let savedPlayer = try player.saveAndFetch(db)
```

See [Persistence Methods], [Upsert](#upsert), and [`updateChanges` methods](#the-updatechanges-methods) for more information.

**Batch operations** can return updated or deleted values:

> **Warning**: Make sure you check the [documentation of the `RETURNING` clause](https://www.sqlite.org/lang_returning.html#limitations_and_caveats), which describes important limitations and caveats for batch operations.

```swift
let request = Player.filter(...)...

// Fetch all deleted players
// DELETE FROM player RETURNING *
let deletedPlayers = try request.deleteAndFetchAll(db) // [Player]

// Fetch a selection of columns from the deleted rows
// DELETE FROM player RETURNING name
let statement = try request.deleteAndFetchStatement(db, selection: [Column("name")])
let deletedNames = try String.fetchSet(statement)

// Fetch all updated players
// UPDATE player SET score = score + 10 RETURNING *
let updatedPlayers = try request.updateAndFetchAll(db, [Column("score") += 10]) // [Player]

// Fetch a selection of columns from the updated rows
// UPDATE player SET score = score + 10 RETURNING score
let statement = try request.updateAndFetchStatement(
    db, [Column("score") += 10],
    select: [Column("score")])
let updatedScores = try Int.fetchAll(statement)
```


### Persistence Callbacks

Your custom type may want to perform extra work when the persistence methods are invoked.

To this end, your record type can implement **persistence callbacks**. Callbacks are methods that get called at certain moments of a record's life cycle. With callbacks it is possible to write code that will run whenever an record is inserted, updated, or deleted.

In order to use a callback method, you need to provide its implementation. For example, a frequently used callback is `didInsert`, in the case of auto-incremented database ids:

```swift
struct Player: MutablePersistableRecord {
    var id: Int64?
    
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

try dbQueue.write { db in
    var player = Player(id: nil, ...)
    try player.insert(db)
    print(player.id) // didInsert was called: prints some non-nil id
}
```

When you subclass the [Record](#record-class) class, override the callback, and make sure you call `super` at some point of your implementation:

```swift
class Player: Record {
    var id: Int64?
    
    // Update auto-incremented id upon successful insertion
    func didInsert(_ inserted: InsertionSuccess) {
        super.didInsert(inserted)
        id = inserted.rowID
    }
}
```

Callbacks can also help implementing record validation:

```swift
struct Link: PersistableRecord {
    var url: URL
    
    func willSave(_ db: Database) throws {
        if url.host == nil {
            throw ValidationError("url must be absolute.")
        }
    }
}

try link.insert(db) // Calls the willSave callback
try link.update(db) // Calls the willSave callback
try link.save(db)   // Calls the willSave callback
try link.upsert(db) // Calls the willSave callback
```

#### Available Callbacks

Here is a list with all the available [persistence callbacks], listed in the same order in which they will get called during the respective operations:

- Inserting a record (all `record.insert` and `record.upsert` methods)
    - `willSave`
    - `aroundSave`
    - `willInsert`
    - `aroundInsert`
    - `didInsert`
    - `didSave`
    
- Updating a record (all `record.update` methods)
    - `willSave`
    - `aroundSave`
    - `willUpdate`
    - `aroundUpdate`
    - `didUpdate`
    - `didSave`
    
- Deleting a record (only the `record.delete(_:)` method)
    - `willDelete`
    - `aroundDelete`
    - `didDelete`

For detailed information about each callback, check the [reference](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/mutablepersistablerecord/).

In the `MutablePersistableRecord` protocol, `willInsert` and `didInsert` are mutating methods. In `PersistableRecord`, they are not mutating.

> **Note**: The `record.save(_:)` method performs an UPDATE if the record has a non-null primary key, and then, if no row was modified, an INSERT. It directly performs an INSERT if the record has no primary key, or a null primary key. It triggers update and/or insert callbacks accordingly.
>
> **Warning**: Callbacks are only invoked from persistence methods called on record instances. Callbacks are not invoked when you call a type method, perform a batch operations, or execute raw SQL.
>
> **Warning**: When a `did***` callback is invoked, do not assume that the change is actually persisted on disk, because the database may still be inside an uncommitted transaction. When you need to handle transaction completions, use the [afterNextTransaction(onCommit:onRollback:)](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/database/afternexttransaction(oncommit:onrollback:)). For example:
>
> ```swift
> struct PictureFile: PersistableRecord {
>     var path: String
>     
>     func willDelete(_ db: Database) {
>         db.afterNextTransaction { _ in
>             try? deleteFileOnDisk()
>         }
>     }
> }
> ```


## Identifiable Records

**When a record type maps a table with a single-column primary key, it is recommended to have it adopt the standard [Identifiable] protocol.**

```swift
struct Player: Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64 // fulfills the Identifiable requirement
    var name: String
    var score: Int
}
```

When `id` has a [database-compatible type](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasevalueconvertible) (Int64, Int, String, UUID, ...), the `Identifiable` conformance unlocks type-safe record and request methods:

```swift
let player = try Player.find(db, id: 1)               // Player
let player = try Player.fetchOne(db, id: 1)           // Player?
let players = try Player.fetchAll(db, ids: [1, 2, 3]) // [Player]
let players = try Player.fetchSet(db, ids: [1, 2, 3]) // Set<Player>

let request = Player.filter(id: 1)
let request = Player.filter(ids: [1, 2, 3])

try Player.deleteOne(db, id: 1)
try Player.deleteAll(db, ids: [1, 2, 3])
```

> **Note**: `Identifiable` is not available on all application targets, and not all tables have a single-column primary key. GRDB provides other methods that deal with primary and unique keys, but they won't check the type of their arguments:
> 
> ```swift
> // Available on non-Identifiable types
> try Player.fetchOne(db, key: 1)
> try Player.fetchOne(db, key: ["email": "arthur@example.com"])
> try Country.fetchAll(db, keys: ["FR", "US"])
> try Citizenship.fetchOne(db, key: ["citizenId": 1, "countryCode": "FR"])
> 
> let request = Player.filter(key: 1)
> let request = Player.filter(keys: [1, 2, 3])
> 
> try Player.deleteOne(db, key: 1)
> try Player.deleteAll(db, keys: [1, 2, 3])
> ```

> **Note**: It is not recommended to use `Identifiable` on record types that use an auto-incremented primary key:
>
> ```swift
> // AVOID declaring Identifiable conformance when key is auto-incremented
> struct Player {
>     var id: Int64? // Not an id suitable for Identifiable
>     var name: String
>     var score: Int
> }
> 
> extension Player: FetchableRecord, MutablePersistableRecord {
>     // Update auto-incremented id upon successful insertion
>     mutating func didInsert(_ inserted: InsertionSuccess) {
>         id = inserted.rowID
>     }
> }
> ```
>
> For a detailed rationale, please see [issue #1435](https://github.com/groue/GRDB.swift/issues/1435#issuecomment-1740857712).

Some database tables have a single-column primary key which is not called "id":

```swift
try db.create(table: "country") { t in
    t.primaryKey("isoCode", .text)
    t.column("name", .text).notNull()
    t.column("population", .integer).notNull()
}
```

In this case, `Identifiable` conformance can be achieved, for example, by returning the primary key column from the `id` property:

```swift
struct Country: Identifiable, FetchableRecord, PersistableRecord {
    var isoCode: String
    var name: String
    var population: Int
    
    // Fulfill the Identifiable requirement
    var id: String { isoCode }
}

let france = try dbQueue.read { db in
    try Country.fetchOne(db, id: "FR")
}
```


## Codable Records

Record types that adopt an archival protocol ([Codable, Encodable or Decodable](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types)) get free database support just by declaring conformance to the desired [record protocols](#record-protocols-overview):

```swift
// Declare a record...
struct Player: Codable, FetchableRecord, PersistableRecord {
    var name: String
    var score: Int
}

// ...and there you go:
try dbQueue.write { db in
    try Player(name: "Arthur", score: 100).insert(db)
    let players = try Player.fetchAll(db)
}
```

Codable records encode and decode their properties according to their own implementation of the Encodable and Decodable protocols. Yet databases have specific requirements:

- Properties are always coded according to their preferred database representation, when they have one (all [values](#values) that adopt the [`DatabaseValueConvertible`] protocol).
- You can customize the encoding and decoding of dates and uuids.
- Complex properties (arrays, dictionaries, nested structs, etc.) are stored as JSON.

For more information about Codable records, see:

- [JSON Columns]
- [Column Names Coding Strategies]
- [Data, Date, and UUID Coding Strategies]
- [The userInfo Dictionary]
- [Tip: Derive Columns from Coding Keys](#tip-derive-columns-from-coding-keys)

> :bulb: **Tip**: see the [Demo Applications] for sample code that uses Codable records.


### JSON Columns

When a [Codable record](#codable-records) contains a property that is not a simple [value](#values) (Bool, Int, String, Date, Swift enums, etc.), that value is encoded and decoded as a **JSON string**. For example:

```swift
enum AchievementColor: String, Codable {
    case bronze, silver, gold
}

struct Achievement: Codable {
    var name: String
    var color: AchievementColor
}

struct Player: Codable, FetchableRecord, PersistableRecord {
    var name: String
    var score: Int
    var achievements: [Achievement] // stored in a JSON column
}

try dbQueue.write { db in
    // INSERT INTO player (name, score, achievements)
    // VALUES (
    //   'Arthur',
    //   100,
    //   '[{"color":"gold","name":"Use Codable Records"}]')
    let achievement = Achievement(name: "Use Codable Records", color: .gold)
    let player = Player(name: "Arthur", score: 100, achievements: [achievement])
    try player.insert(db)
}
```

GRDB uses the standard [JSONDecoder](https://developer.apple.com/documentation/foundation/jsondecoder) and [JSONEncoder](https://developer.apple.com/documentation/foundation/jsonencoder) from Foundation. By default, Data values are handled with the `.base64` strategy, Date with the `.millisecondsSince1970` strategy, and non conforming floats with the `.throw` strategy.

You can customize the JSON format by implementing those methods:

```swift
protocol FetchableRecord {
    static func databaseJSONDecoder(for column: String) -> JSONDecoder
}

protocol EncodableRecord {
    static func databaseJSONEncoder(for column: String) -> JSONEncoder
}
```

> :bulb: **Tip**: Make sure you set the JSONEncoder `sortedKeys` option. This option makes sure that the JSON output is stable. This stability is required for [Record Comparison] to work as expected, and database observation tools such as [ValueObservation] to accurately recognize changed records.


### Column Names Coding Strategies

By default, [Codable Records] store their values into database columns that match their coding keys: the `teamID` property is stored into the `teamID` column.

This behavior can be overridden, so that you can, for example, store the `teamID` property into the `team_id` column:

```swift
protocol FetchableRecord {
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { get }
}

protocol EncodableRecord {
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { get }
}
```

See [DatabaseColumnDecodingStrategy](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasecolumndecodingstrategy) and [DatabaseColumnEncodingStrategy](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasecolumnencodingstrategy/) to learn about all available strategies.


### Data, Date, and UUID Coding Strategies

By default, [Codable Records] encode and decode their Data properties as blobs, and Date and UUID properties as described in the general [Date and DateComponents](#date-and-datecomponents) and [UUID](#uuid) chapters.

To sum up: dates encode themselves in the "YYYY-MM-DD HH:MM:SS.SSS" format, in the UTC time zone, and decode a variety of date formats and timestamps. UUIDs encode themselves as 16-bytes data blobs, and decode both 16-bytes data blobs and strings such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F".

Those behaviors can be overridden:

```swift
protocol FetchableRecord {
    static var databaseDataDecodingStrategy: DatabaseDataDecodingStrategy { get }
    static var databaseDateDecodingStrategy: DatabaseDateDecodingStrategy { get }
}

protocol EncodableRecord {
    static var databaseDataEncodingStrategy: DatabaseDataEncodingStrategy { get }
    static var databaseDateEncodingStrategy: DatabaseDateEncodingStrategy { get }
    static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { get }
}
```

See [DatabaseDataDecodingStrategy](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasedatadecodingstrategy/), [DatabaseDateDecodingStrategy](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasedatedecodingstrategy/), [DatabaseDataEncodingStrategy](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasedataencodingstrategy/), [DatabaseDateEncodingStrategy](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasedateencodingstrategy/), and [DatabaseUUIDEncodingStrategy](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseuuidencodingstrategy/) to learn about all available strategies.

There is no customization of uuid decoding, because UUID can already decode all its encoded variants (16-bytes blobs and uuid strings, both uppercase and lowercase).

Customized coding strategies apply:

- When encoding and decoding database rows to and from records (fetching and persistence methods).
- In requests by single-column primary key: `fetchOne(_:id:)`, `filter(id:)`, `deleteAll(_:keys:)`, etc.

*They do not apply* in other requests based on data, date, or uuid values.

So make sure that those are properly encoded in your requests. For example:

```swift
struct Player: Codable, FetchableRecord, PersistableRecord, Identifiable {
    // UUIDs are stored as strings
    static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString
    var id: UUID
    ...
}

try dbQueue.write { db in
    let uuid = UUID()
    let player = Player(id: uuid, ...)
    
    // OK: inserts a player in the database, with a string uuid
    try player.insert(db)
    
    // OK: performs a string-based query, finds the inserted player
    _ = try Player.filter(id: uuid).fetchOne(db)

    // NOT OK: performs a blob-based query, fails to find the inserted player
    _ = try Player.filter(Column("id") == uuid).fetchOne(db)
    
    // OK: performs a string-based query, finds the inserted player
    _ = try Player.filter(Column("id") == uuid.uuidString).fetchOne(db)
}
```


### The userInfo Dictionary

Your [Codable Records] can be stored in the database, but they may also have other purposes. In this case, you may need to customize their implementations of `Decodable.init(from:)` and `Encodable.encode(to:)`, depending on the context.

The standard way to provide such context is the `userInfo` dictionary. Implement those properties:

```swift
protocol FetchableRecord {
    static var databaseDecodingUserInfo: [CodingUserInfoKey: Any] { get }
}

protocol EncodableRecord {
    static var databaseEncodingUserInfo: [CodingUserInfoKey: Any] { get }
}
```

For example, here is a Player type that customizes its decoding:

```swift
// A key that holds a decoder's name
let decoderName = CodingUserInfoKey(rawValue: "decoderName")!

struct Player: FetchableRecord, Decodable {
    init(from decoder: Decoder) throws {
        // Print the decoder name
        let decoderName = decoder.userInfo[decoderName] as? String
        print("Decoded from \(decoderName ?? "unknown decoder")")
        ...
    }
}
```

You can have a specific decoding from JSON...

```swift
// prints "Decoded from JSON"
let decoder = JSONDecoder()
decoder.userInfo = [decoderName: "JSON"]
let player = try decoder.decode(Player.self, from: jsonData)
```

... and another one from database rows:

```swift
extension Player: FetchableRecord {
    static let databaseDecodingUserInfo: [CodingUserInfoKey: Any] = [decoderName: "database row"]
}

// prints "Decoded from database row"
let player = try Player.fetchOne(db, ...)
```

> **Note**: make sure the `databaseDecodingUserInfo` and `databaseEncodingUserInfo` properties are explicitly declared as `[CodingUserInfoKey: Any]`. If they are not, the Swift compiler may silently miss the protocol requirement, resulting in sticky empty userInfo.


### Tip: Derive Columns from Coding Keys

Codable types are granted with a [CodingKeys](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types) enum. You can use them to safely define database columns:

```swift
struct Player: Codable {
    var id: Int64
    var name: String
    var score: Int
}

extension Player: FetchableRecord, PersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
}
```

See the [query interface](#the-query-interface) and [Recommended Practices for Designing Record Types](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/recordrecommendedpractices) for further information.


## Record Class

**Record** is a class that is designed to be subclassed. It inherits its features from the [FetchableRecord, TableRecord, and PersistableRecord](#record-protocols-overview) protocols. On top of that, Record instances can compare against previous versions of themselves in order to [avoid useless updates](#record-comparison).

Record subclasses define their custom database relationship by overriding database methods. For example:

```swift
class Place: Record {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    var coordinate: CLLocationCoordinate2D
    
    init(id: Int64?, title: String, isFavorite: Bool, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.title = title
        self.isFavorite = isFavorite
        self.coordinate = coordinate
        super.init()
    }
    
    /// The table name
    override class var databaseTableName: String { "place" }
    
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, title, favorite, latitude, longitude
    }
    
    /// Creates a record from a database row
    required init(row: Row) throws {
        id = row[Columns.id]
        title = row[Columns.title]
        isFavorite = row[Columns.favorite]
        coordinate = CLLocationCoordinate2D(
            latitude: row[Columns.latitude],
            longitude: row[Columns.longitude])
        try super.init(row: row)
    }
    
    /// The values persisted in the database
    override func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.favorite] = isFavorite
        container[Columns.latitude] = coordinate.latitude
        container[Columns.longitude] = coordinate.longitude
    }
    
    /// Update record ID after a successful insertion
    override func didInsert(_ inserted: InsertionSuccess) {
        super.didInsert(inserted)
        id = inserted.rowID
    }
}
```


## Record Comparison

**Records that adopt the [EncodableRecord] protocol can compare against other records, or against previous versions of themselves.**

This helps avoiding costly UPDATE statements when a record has not been edited.

- [The `updateChanges` Methods](#the-updatechanges-methods)
- [The `databaseEquals` Method](#the-databaseequals-method)
- [The `databaseChanges` and `hasDatabaseChanges` Methods](#the-databasechanges-and-hasdatabasechanges-methods)


### The `updateChanges` Methods

The `updateChanges` methods perform a database update of the changed columns only (and does nothing if record has no change).

- `updateChanges(_:from:)`

    This method lets you compare two records:

    ```swift
    if let oldPlayer = try Player.fetchOne(db, id: 42) {
        var newPlayer = oldPlayer
        newPlayer.score = 100
        if try newPlayer.updateChanges(db, from: oldPlayer) {
            print("player was modified, and updated in the database")
        } else {
            print("player was not modified, and database was not hit")
        }
    }
    ```

- `updateChanges(_:modify:)`
    
    This method lets you update a record in place:
    
    ```swift
    if var player = try Player.fetchOne(db, id: 42) {
        let modified = try player.updateChanges(db) {
            $0.score = 100
        }
        if modified {
            print("player was modified, and updated in the database")
        } else {
            print("player was not modified, and database was not hit")
        }
    }
    ```

- `updateChanges(_:)` (Record class only)
    
    Instances of the [Record](#record-class) class are able to compare against themselves, and know if they have changes that have not been saved since the last fetch or saving:

    ```swift
    // Record class only
    if let player = try Player.fetchOne(db, id: 42) {
        player.score = 100
        if try player.updateChanges(db) {
            print("player was modified, and updated in the database")
        } else {
            print("player was not modified, and database was not hit")
        }
    }
    ```


### The `databaseEquals` Method

This method returns whether two records have the same database representation:

```swift
let oldPlayer: Player = ...
var newPlayer: Player = ...
if newPlayer.databaseEquals(oldPlayer) == false {
    try newPlayer.save(db)
}
```

> **Note**: The comparison is performed on the database representation of records. As long as your record type adopts the EncodableRecord protocol, you don't need to care about Equatable.


### The `databaseChanges` and `hasDatabaseChanges` Methods

`databaseChanges(from:)` returns a dictionary of differences between two records:

```swift
let oldPlayer = Player(id: 1, name: "Arthur", score: 100)
let newPlayer = Player(id: 1, name: "Arthur", score: 1000)
for (column, oldValue) in try newPlayer.databaseChanges(from: oldPlayer) {
    print("\(column) was \(oldValue)")
}
// prints "score was 100"
```

The [Record](#record-class) class is able to compare against itself:

```swift
// Record class only
let player = Player(id: 1, name: "Arthur", score: 100)
try player.insert(db)
player.score = 1000
for (column, oldValue) in try player.databaseChanges {
    print("\(column) was \(oldValue)")
}
// prints "score was 100"
```

[Record](#record-class) instances also have a `hasDatabaseChanges` property:

```swift
// Record class only
player.score = 1000
if player.hasDatabaseChanges {
    try player.save(db)
}
```

`Record.hasDatabaseChanges` is false after a Record instance has been fetched or saved into the database. Subsequent modifications may set it, or not: `hasDatabaseChanges` is based on value comparison. **Setting a property to the same value does not set the changed flag**:

```swift
let player = Player(name: "Barbara", score: 750)
player.hasDatabaseChanges  // true

try player.insert(db)
player.hasDatabaseChanges  // false

player.name = "Barbara"
player.hasDatabaseChanges  // false

player.score = 1000
player.hasDatabaseChanges  // true
try player.databaseChanges // ["score": 750]
```

For an efficient algorithm which synchronizes the content of a database table with a JSON payload, check [groue/SortedDifference](https://github.com/groue/SortedDifference).


## Record Customization Options

GRDB records come with many default behaviors, that are designed to fit most situations. Many of those defaults can be customized for your specific needs:

- [Persistence Callbacks]: define what happens when you call a persistence method such as `player.insert(db)`
- [Conflict Resolution]: Run `INSERT OR REPLACE` queries, and generally define what happens when a persistence method violates a unique index.
- [Columns Selected by a Request]: define which columns are selected by requests such as `Player.fetchAll(db)`.
- [Beyond FetchableRecord]: the FetchableRecord protocol is not the end of the story.

[Codable Records] have a few extra options:

- [JSON Columns]: control the format of JSON columns.
- [Column Names Coding Strategies]: control how coding keys are turned into column names
- [Date and UUID Coding Strategies]: control the format of Date and UUID properties in your Codable records.
- [The userInfo Dictionary]: adapt your Codable implementation for the database.


### Conflict Resolution

**Insertions and updates can create conflicts**: for example, a query may attempt to insert a duplicate row that violates a unique index.

Those conflicts normally end with an error. Yet SQLite let you alter the default behavior, and handle conflicts with specific policies. For example, the `INSERT OR REPLACE` statement handles conflicts with the "replace" policy which replaces the conflicting row instead of throwing an error.

The [five different policies](https://www.sqlite.org/lang_conflict.html) are: abort (the default), replace, rollback, fail, and ignore.

**SQLite let you specify conflict policies at two different places:**

- In the definition of the database table:
    
    ```swift
    // CREATE TABLE player (
    //     id INTEGER PRIMARY KEY AUTOINCREMENT,
    //     email TEXT UNIQUE ON CONFLICT REPLACE
    // )
    try db.create(table: "player") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("email", .text).unique(onConflict: .replace) // <--
    }
    
    // Despite the unique index on email, both inserts succeed.
    // The second insert replaces the first row:
    try db.execute(sql: "INSERT INTO player (email) VALUES (?)", arguments: ["arthur@example.com"])
    try db.execute(sql: "INSERT INTO player (email) VALUES (?)", arguments: ["arthur@example.com"])
    ```
    
- In each modification query:
    
    ```swift
    // CREATE TABLE player (
    //     id INTEGER PRIMARY KEY AUTOINCREMENT,
    //     email TEXT UNIQUE
    // )
    try db.create(table: "player") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("email", .text).unique()
    }
    
    // Again, despite the unique index on email, both inserts succeed.
    try db.execute(sql: "INSERT OR REPLACE INTO player (email) VALUES (?)", arguments: ["arthur@example.com"])
    try db.execute(sql: "INSERT OR REPLACE INTO player (email) VALUES (?)", arguments: ["arthur@example.com"])
    ```

When you want to handle conflicts at the query level, specify a custom `persistenceConflictPolicy` in your type that adopts the PersistableRecord protocol. It will alter the INSERT and UPDATE queries run by the `insert`, `update` and `save` [persistence methods]:

```swift
protocol MutablePersistableRecord {
    /// The policy that handles SQLite conflicts when records are
    /// inserted or updated.
    ///
    /// This property is optional: its default value uses the ABORT
    /// policy for both insertions and updates, so that GRDB generate
    /// regular INSERT and UPDATE queries.
    static var persistenceConflictPolicy: PersistenceConflictPolicy { get }
}

struct Player : MutablePersistableRecord {
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace)
}

// INSERT OR REPLACE INTO player (...) VALUES (...)
try player.insert(db)
```

> **Note**: If you specify the `ignore` policy for inserts, the [`didInsert`  callback](#persistence-callbacks) will be called with some random id in case of failed insert. You can detect failed insertions with `insertAndFetch`:
>     
> ```swift
> // How to detect failed `INSERT OR IGNORE`:
> // INSERT OR IGNORE INTO player ... RETURNING *
> if let insertedPlayer = try player.insertAndFetch(db) {
>     // Succesful insertion
> } else {
>     // Ignored failure
> }
> ```
>
> **Note**: The `replace` policy may have to delete rows so that inserts and updates can succeed. Those deletions are not reported to [transaction observers](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/transactionobserver) (this might change in a future release of SQLite).

### Beyond FetchableRecord

**Some GRDB users eventually discover that the [FetchableRecord] protocol does not fit all situations.** Use cases that are not well handled by FetchableRecord include:

- Your application needs polymorphic row decoding: it decodes some type or another, depending on the values contained in a database row.

- Your application needs to decode rows with a context: each decoded value should be initialized with some extra value that does not come from the database.

Since those use cases are not well handled by FetchableRecord, don't try to implement them on top of this protocol: you'll just fight the framework.


## Examples of Record Definitions

We will show below how to declare a record type for the following database table:

```swift
try dbQueue.write { db in
    try db.create(table: "place") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("title", .text).notNull()
        t.column("isFavorite", .boolean).notNull().defaults(to: false)
        t.column("longitude", .double).notNull()
        t.column("latitude", .double).notNull()
    }
}
```

Each one of the three examples below is correct. You will pick one or the other depending on your personal preferences and the requirements of your application:

<details>
  <summary>Define a Codable struct, and adopt the record protocols you need</summary>

This is the shortest way to define a record type.

See the [Record Protocols Overview](#record-protocols-overview), and [Codable Records] for more information.

```swift
struct Place: Codable {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    private var latitude: CLLocationDegrees
    private var longitude: CLLocationDegrees
    
    var coordinate: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
}

// SQL generation
extension Place: TableRecord {
    /// The table columns
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let isFavorite = Column(CodingKeys.isFavorite)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
    }
}

// Fetching methods
extension Place: FetchableRecord { }

// Persistence methods
extension Place: MutablePersistableRecord {
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

</details>

<details>
  <summary>Define a plain struct, and adopt the record protocols you need</summary>

See the [Record Protocols Overview](#record-protocols-overview) for more information.
    
```swift
struct Place {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    var coordinate: CLLocationCoordinate2D
}

// SQL generation
extension Place: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, title, isFavorite, latitude, longitude
    }
}

// Fetching methods
extension Place: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        isFavorite = row[Columns.isFavorite]
        coordinate = CLLocationCoordinate2D(
            latitude: row[Columns.latitude],
            longitude: row[Columns.longitude])
    }
}

// Persistence methods
extension Place: MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.isFavorite] = isFavorite
        container[Columns.latitude] = coordinate.latitude
        container[Columns.longitude] = coordinate.longitude
    }
    
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

</details>

<details>
  <summary>Define a plain struct optimized for fetching performance</summary>

This struct derives its persistence methods from the standard Encodable protocol (see [Codable Records]), but performs optimized row decoding by accessing database columns with numeric indexes.

See the [Record Protocols Overview](#record-protocols-overview) for more information.
    
```swift
struct Place: Encodable {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    private var latitude: CLLocationDegrees
    private var longitude: CLLocationDegrees
    
    var coordinate: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
}

// SQL generation
extension Place: TableRecord {
    /// The table columns
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let isFavorite = Column(CodingKeys.isFavorite)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
    }
    
    /// Arrange the selected columns and lock their order
    static let databaseSelection: [any SQLSelectable] = [
        Columns.id,
        Columns.title,
        Columns.favorite,
        Columns.latitude,
        Columns.longitude]
}

// Fetching methods
extension Place: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        // For high performance, use numeric indexes that match the
        // order of Place.databaseSelection
        id = row[0]
        title = row[1]
        isFavorite = row[2]
        coordinate = CLLocationCoordinate2D(
            latitude: row[3],
            longitude: row[4])
    }
}

// Persistence methods
extension Place: MutablePersistableRecord {
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

</details>

<details>
  <summary>Subclass the <code>Record</code> class</summary>

See the [Record class](#record-class) for more information.
    
```swift
class Place: Record {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    var coordinate: CLLocationCoordinate2D
    
    init(id: Int64?, title: String, isFavorite: Bool, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.title = title
        self.isFavorite = isFavorite
        self.coordinate = coordinate
        super.init()
    }
    
    /// The table name
    override class var databaseTableName: String { "place" }
    
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, title, isFavorite, latitude, longitude
    }
    
    /// Creates a record from a database row
    required init(row: Row) throws {
        id = row[Columns.id]
        title = row[Columns.title]
        isFavorite = row[Columns.isFavorite]
        coordinate = CLLocationCoordinate2D(
            latitude: row[Columns.latitude],
            longitude: row[Columns.longitude])
        try super.init(row: row)
    }
    
    /// The values persisted in the database
    override func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.isFavorite] = isFavorite
        container[Columns.latitude] = coordinate.latitude
        container[Columns.longitude] = coordinate.longitude
    }
    
    // Update auto-incremented id upon successful insertion
    override func didInsert(_ inserted: InsertionSuccess) {
        super.didInsert(inserted)
        id = inserted.rowID
    }
}
```

</details>


## List of Record Methods

This is the list of record methods, along with their required protocols. The [Record](#record-class) class adopts all these protocols, and adds a few extra methods.

| Method | Protocols | Notes |
| ------ | --------- | :---: |
| **Core Methods** | | |
| `init(row:)` | [FetchableRecord] | |
| `Type.databaseTableName` | [TableRecord] | |
| `Type.databaseSelection` | [TableRecord] | [*](#columns-selected-by-a-request) |
| `Type.persistenceConflictPolicy` | [PersistableRecord] | [*](#conflict-resolution) |
| `record.encode(to:)` | [EncodableRecord] | |
| **Insert and Update Records** | | |
| `record.insert(db)` | [PersistableRecord] | |
| `record.insertAndFetch(db)` | [PersistableRecord] & [FetchableRecord] | |
| `record.insertAndFetch(_:as:)` | [PersistableRecord] | |
| `record.insertAndFetch(_:selection:fetch:)` | [PersistableRecord] | |
| `record.inserted(db)` | [PersistableRecord] | |
| `record.save(db)` | [PersistableRecord] | |
| `record.saveAndFetch(db)` | [PersistableRecord] & [FetchableRecord] | |
| `record.saveAndFetch(_:as:)` | [PersistableRecord] | |
| `record.saveAndFetch(_:selection:fetch:)` | [PersistableRecord] | |
| `record.saved(db)` | [PersistableRecord] | |
| `record.update(db)` | [PersistableRecord] | |
| `record.updateAndFetch(db)` | [PersistableRecord] & [FetchableRecord] | |
| `record.updateAndFetch(_:as:)` | [PersistableRecord] | |
| `record.updateAndFetch(_:selection:fetch:)` | [PersistableRecord] | |
| `record.update(db, columns:...)` | [PersistableRecord] | |
| `record.updateAndFetch(_:columns:selection:fetch:)` | [PersistableRecord] | |
| `record.updateChanges(db, from:...)` | [PersistableRecord] | [*](#record-comparison) |
| `record.updateChanges(db) { ... }` | [PersistableRecord] | [*](#record-comparison) |
| `record.updateChangesAndFetch(_:columns:as:modify:)` | [PersistableRecord] | |
| `record.updateChangesAndFetch(_:columns:selection:fetch:modify:)` | [PersistableRecord] | |
| `record.updateChanges(db)` | [Record](#record-class) | [*](#record-comparison) |
| `record.upsert(db)` | [PersistableRecord] | |
| `record.upsertAndFetch(db)` | [PersistableRecord] & [FetchableRecord] | |
| `record.upsertAndFetch(_:as:)` | [PersistableRecord] | |
| `Type.updateAll(db, ...)` | [TableRecord] | |
| `Type.filter(...).updateAll(db, ...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| **Delete Records** | | |
| `record.delete(db)` | [PersistableRecord] | |
| `Type.deleteOne(db, key:...)` | [TableRecord] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.deleteOne(db, id:...)` | [TableRecord] & [Identifiable] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.deleteAll(db)` | [TableRecord] | |
| `Type.deleteAll(db, keys:...)` | [TableRecord] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.deleteAll(db, ids:...)` | [TableRecord] & [Identifiable] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.filter(...).deleteAll(db)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| **Persistence Callbacks** | | |
| `record.willInsert(_:)` | [PersistableRecord] | |
| `record.aroundInsert(_:insert:)` | [PersistableRecord] | |
| `record.didInsert(_:)` | [PersistableRecord] | |
| `record.willUpdate(_:columns:)` | [PersistableRecord] | |
| `record.aroundUpdate(_:columns:update:)` | [PersistableRecord] | |
| `record.didUpdate(_:)` | [PersistableRecord] | |
| `record.willSave(_:)` | [PersistableRecord] | |
| `record.aroundSave(_:save:)` | [PersistableRecord] | |
| `record.didSave(_:)` | [PersistableRecord] | |
| `record.willDelete(_:)` | [PersistableRecord] | |
| `record.aroundDelete(_:delete:)` | [PersistableRecord] | |
| `record.didDelete(deleted:)` | [PersistableRecord] | |
| **Check Record Existence** | | |
| `record.exists(db)` | [PersistableRecord] | |
| `Type.exists(db, key: ...)` | [TableRecord] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.exists(db, id: ...)` | [TableRecord] & [Identifiable] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.filter(...).isEmpty(db)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| **Convert Record to Dictionary** | | |
| `record.databaseDictionary` | [EncodableRecord] | |
| **Count Records** | | |
| `Type.fetchCount(db)` | [TableRecord] | |
| `Type.filter(...).fetchCount(db)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| **Fetch Record [Cursors](#cursors)** | | |
| `Type.fetchCursor(db)` | [FetchableRecord] & [TableRecord] | |
| `Type.fetchCursor(db, keys:...)` | [FetchableRecord] & [TableRecord] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchCursor(db, ids:...)` | [FetchableRecord] & [TableRecord] & [Identifiable] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchCursor(db, sql: sql)` | [FetchableRecord] | <a href="#list-of-record-methods-3">³</a> |
| `Type.fetchCursor(statement)` | [FetchableRecord] | <a href="#list-of-record-methods-4">⁴</a> |
| `Type.filter(...).fetchCursor(db)` | [FetchableRecord] & [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| **Fetch Record Arrays** | | |
| `Type.fetchAll(db)` | [FetchableRecord] & [TableRecord] | |
| `Type.fetchAll(db, keys:...)` | [FetchableRecord] & [TableRecord] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchAll(db, ids:...)` | [FetchableRecord] & [TableRecord] & [Identifiable] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchAll(db, sql: sql)` | [FetchableRecord] | <a href="#list-of-record-methods-3">³</a> |
| `Type.fetchAll(statement)` | [FetchableRecord] | <a href="#list-of-record-methods-4">⁴</a> |
| `Type.filter(...).fetchAll(db)` | [FetchableRecord] & [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| **Fetch Record Sets** | | |
| `Type.fetchSet(db)` | [FetchableRecord] & [TableRecord] | |
| `Type.fetchSet(db, keys:...)` | [FetchableRecord] & [TableRecord] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchSet(db, ids:...)` | [FetchableRecord] & [TableRecord] & [Identifiable] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchSet(db, sql: sql)` | [FetchableRecord] | <a href="#list-of-record-methods-3">³</a> |
| `Type.fetchSet(statement)` | [FetchableRecord] | <a href="#list-of-record-methods-4">⁴</a> |
| `Type.filter(...).fetchSet(db)` | [FetchableRecord] & [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| **Fetch Individual Records** | | |
| `Type.fetchOne(db)` | [FetchableRecord] & [TableRecord] | |
| `Type.fetchOne(db, key:...)` | [FetchableRecord] & [TableRecord] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchOne(db, id:...)` | [FetchableRecord] & [TableRecord] & [Identifiable] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchOne(db, sql: sql)` | [FetchableRecord] | <a href="#list-of-record-methods-3">³</a> |
| `Type.fetchOne(statement)` | [FetchableRecord] | <a href="#list-of-record-methods-4">⁴</a> |
| `Type.filter(...).fetchOne(db)` | [FetchableRecord] & [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.find(db, key:...)` | [FetchableRecord] & [TableRecord] | <a href="#list-of-record-methods-1">¹</a> |
| `Type.find(db, id:...)` | [FetchableRecord] & [TableRecord] & [Identifiable] | <a href="#list-of-record-methods-1">¹</a> |
| **[Codable Records]** | | |
| `Type.databaseDecodingUserInfo` | [FetchableRecord] | [*](#the-userinfo-dictionary) |
| `Type.databaseJSONDecoder(for:)` | [FetchableRecord] | [*](#json-columns) |
| `Type.databaseDateDecodingStrategy` | [FetchableRecord] | [*](#data-date-and-uuid-coding-strategies) |
| `Type.databaseEncodingUserInfo` | [EncodableRecord] | [*](#the-userinfo-dictionary) |
| `Type.databaseJSONEncoder(for:)` | [EncodableRecord] | [*](#json-columns) |
| `Type.databaseDateEncodingStrategy` | [EncodableRecord] | [*](#data-date-and-uuid-coding-strategies) |
| `Type.databaseUUIDEncodingStrategy` | [EncodableRecord] | [*](#data-date-and-uuid-coding-strategies) |
| **Define [Associations]** | | |
| `Type.belongsTo(...)` | [TableRecord] | [*](Documentation/AssociationsBasics.md) |
| `Type.hasMany(...)` | [TableRecord] | [*](Documentation/AssociationsBasics.md) |
| `Type.hasOne(...)` | [TableRecord] | [*](Documentation/AssociationsBasics.md) |
| `Type.hasManyThrough(...)` | [TableRecord] | [*](Documentation/AssociationsBasics.md) |
| `Type.hasOneThrough(...)` | [TableRecord] | [*](Documentation/AssociationsBasics.md) |
| **Building Query Interface [Requests](#requests)** | | |
| `record.request(for:...)` | [TableRecord] & [EncodableRecord] | [*](Documentation/AssociationsBasics.md) |
| `Type.all()` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.none()` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.select(...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.select(..., as:...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.selectPrimaryKey(as:...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.annotated(with:...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.filter(...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.filter(id:)` | [TableRecord] & Identifiable | [*](#identifiable-records) |
| `Type.filter(ids:)` | [TableRecord] & Identifiable | [*](#identifiable-records) |
| `Type.matching(...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.including(all:)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.including(optional:)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.including(required:)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.joining(optional:)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.joining(required:)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.group(...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.groupByPrimaryKey()` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.having(...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.order(...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.orderByPrimaryKey()` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.limit(...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| `Type.with(...)` | [TableRecord] | <a href="#list-of-record-methods-2">²</a> |
| **[Record Comparison]** | | |
| `record.databaseEquals(...)` | [EncodableRecord] | |
| `record.databaseChanges(from:...)` | [EncodableRecord] | |
| `record.updateChanges(db, from:...)` | [PersistableRecord] | |
| `record.updateChanges(db) { ... }` | [PersistableRecord] | |
| `record.hasDatabaseChanges` | [Record](#record-class) | |
| `record.databaseChanges` | [Record](#record-class) | |
| `record.updateChanges(db)` | [Record](#record-class) | |

<a name="list-of-record-methods-1">¹</a> All unique keys are supported: primary keys (single-column, composite, [`rowid`](https://www.sqlite.org/rowidtable.html)) and unique indexes:

```swift
try Player.fetchOne(db, id: 1)                                // Player?
try Player.fetchOne(db, key: ["email": "arthur@example.com"]) // Player?
try Country.fetchAll(db, keys: ["FR", "US"])                  // [Country]
```

<a name="list-of-record-methods-2">²</a> See [Fetch Requests](#requests):

```swift
let request = Player.filter(emailColumn != nil).order(nameColumn)
let players = try request.fetchAll(db)  // [Player]
let count = try request.fetchCount(db)  // Int
```

<a name="list-of-record-methods-3">³</a> See [SQL queries](#fetch-queries):

```swift
let player = try Player.fetchOne(db, sql: "SELECT * FROM player WHERE id = ?", arguments: [1]) // Player?
```

<a name="list-of-record-methods-4">⁴</a> See [`Statement`]:

```swift
let statement = try db.makeStatement(sql: "SELECT * FROM player WHERE id = ?")
let player = try Player.fetchOne(statement, arguments: [1])  // Player?
```


The Query Interface
===================

**The query interface lets you write pure Swift instead of SQL:**

```swift
try dbQueue.write { db in
    // Update database schema
    try db.create(table: "wine") { t in ... }
    
    // Fetch records
    let wines = try Wine
        .filter(originColumn == "Burgundy")
        .order(priceColumn)
        .fetchAll(db)
    
    // Count
    let count = try Wine
        .filter(colorColumn == Color.red)
        .fetchCount(db)
    
    // Update
    try Wine
        .filter(originColumn == "Burgundy")
        .updateAll(db, priceColumn *= 0.75)
    
    // Delete
    try Wine
        .filter(corkedColumn == true)
        .deleteAll(db)
}
```

You need to open a [database connection] before you can query the database.

Please bear in mind that the query interface can not generate all possible SQL queries. You may also *prefer* writing SQL, and this is just OK. From little snippets to full queries, your SQL skills are welcome:

```swift
try dbQueue.write { db in
    // Update database schema (with SQL)
    try db.execute(sql: "CREATE TABLE wine (...)")
    
    // Fetch records (with SQL)
    let wines = try Wine.fetchAll(db,
        sql: "SELECT * FROM wine WHERE origin = ? ORDER BY price",
        arguments: ["Burgundy"])
    
    // Count (with an SQL snippet)
    let count = try Wine
        .filter(sql: "color = ?", arguments: [Color.red])
        .fetchCount(db)
    
    // Update (with SQL)
    try db.execute(sql: "UPDATE wine SET price = price * 0.75 WHERE origin = 'Burgundy'")
    
    // Delete (with SQL)
    try db.execute(sql: "DELETE FROM wine WHERE corked")
}
```

So don't miss the [SQL API](#sqlite-api).

> **Note**: the generated SQL may change between GRDB releases, without notice: don't have your application rely on any specific SQL output.

- [The Database Schema](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseschema)
- [Requests](#requests)
- [Expressions](#expressions)
    - [SQL Operators](#sql-operators)
    - [SQL Functions](#sql-functions)
- [Embedding SQL in Query Interface Requests]
- [Fetching from Requests]
- [Fetching by Key](#fetching-by-key)
- [Testing for Record Existence](#testing-for-record-existence)
- [Fetching Aggregated Values](#fetching-aggregated-values)
- [Delete Requests](#delete-requests)
- [Update Requests](#update-requests)
- [Custom Requests](#custom-requests)
- :blue_book: [Associations and Joins](Documentation/AssociationsBasics.md)
- :blue_book: [Common Table Expressions]
- :blue_book: [Query Interface Organization]

## Requests

📖 [`QueryInterfaceRequest`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/queryinterfacerequest), [`Table`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/table)

**The query interface requests** let you fetch values from the database:

```swift
let request = Player.filter(emailColumn != nil).order(nameColumn)
let players = try request.fetchAll(db)  // [Player]
let count = try request.fetchCount(db)  // Int
```

Query interface requests usually start from **a type** that adopts the `TableRecord` protocol, such as a `Record` subclass (see [Records](#records)):

```swift
class Player: Record { ... }

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

> **Note**: all examples in the documentation below use a record type, but you can always substitute a `Table` instead.

Next, declare the table **columns** that you want to use for filtering, or sorting:

```swift
let idColumn = Column("id")
let nameColumn = Column("name")
```

You can also declare column enums, if you prefer:

```swift
// Columns.id and Columns.name can be used just as
// idColumn and nameColumn declared above.
enum Columns: String, ColumnExpression {
    case id
    case name
}
```

You can now build requests with the following methods: `all`, `none`, `select`, `distinct`, `filter`, `matching`, `group`, `having`, `order`, `reversed`, `limit`, `joining`, `including`, `with`. All those methods return another request, which you can further refine by applying another method: `Player.select(...).filter(...).order(...)`.

- [`all()`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerecord/all()), [`none()`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerecord/none()): the requests for all rows, or no row.

    ```swift
    // SELECT * FROM player
    Player.all()
    ```
    
    By default, all columns are selected. See [Columns Selected by a Request].

- [`select(...)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/selectionrequest/select(_:)-30yzl) and [`select(..., as:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/queryinterfacerequest/select(_:as:)-282xc) define the selected columns. See [Columns Selected by a Request].
    
    ```swift
    // SELECT name FROM player
    Player.select(nameColumn, as: String.self)
    ```

- [`annotated(with: expression...)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/selectionrequest/annotated(with:)-6ehs4) extends the selection.

    ```swift
    // SELECT *, (score + bonus) AS total FROM player
    Player.annotated(with: (scoreColumn + bonusColumn).forKey("total"))
    ```

- [`annotated(with: aggregate)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/derivablerequest/annotated(with:)-74xfs) extends the selection with [association aggregates](Documentation/AssociationsBasics.md#association-aggregates).
    
    ```swift
    // SELECT team.*, COUNT(DISTINCT player.id) AS playerCount
    // FROM team
    // LEFT JOIN player ON player.teamId = team.id
    // GROUP BY team.id
    Team.annotated(with: Team.players.count)
    ```

- [`annotated(withRequired: association)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/joinablerequest/annotated(withrequired:)) and [`annotated(withOptional: association)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/joinablerequest/annotated(withoptional:)) extends the selection with [Associations].
    
    ```swift
    // SELECT player.*, team.color
    // FROM player
    // JOIN team ON team.id = player.teamId
    Player.annotated(withRequired: Player.team.select(colorColumn))
    ```

- [`distinct()`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/derivablerequest/distinct()) performs uniquing.
    
    ```swift
    // SELECT DISTINCT name FROM player
    Player.select(nameColumn, as: String.self).distinct()
    ```

- [`filter(expression)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/filteredrequest/filter(_:)) applies conditions.
    
    ```swift
    // SELECT * FROM player WHERE id IN (1, 2, 3)
    Player.filter([1,2,3].contains(idColumn))
    
    // SELECT * FROM player WHERE (name IS NOT NULL) AND (height > 1.75)
    Player.filter(nameColumn != nil && heightColumn > 1.75)
    ```

- [`filter(id:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerequest/filter(id:)) and [`filter(ids:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerequest/filter(ids:)) are type-safe methods available on [Identifiable Records]:
    
    ```swift
    // SELECT * FROM player WHERE id = 1
    Player.filter(id: 1)
    
    // SELECT * FROM country WHERE isoCode IN ('FR', 'US')
    Country.filter(ids: ["FR", "US"])
    ```
    
- [`filter(key:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerequest/filter(key:)-1p9sq) and [`filter(keys:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerequest/filter(keys:)-6ggt1) apply conditions on primary and unique keys:
    
    ```swift
    // SELECT * FROM player WHERE id = 1
    Player.filter(key: 1)
    
    // SELECT * FROM country WHERE isoCode IN ('FR', 'US')
    Country.filter(keys: ["FR", "US"])
    
    // SELECT * FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    Citizenship.filter(key: ["citizenId": 1, "countryCode": "FR"])
    
    // SELECT * FROM player WHERE email = 'arthur@example.com'
    Player.filter(key: ["email": "arthur@example.com"])
    ```

- `matching(pattern)` ([FTS3](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerequest/matching(_:)-3s3zr), [FTS5](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerequest/matching(_:)-7c1e8)) performs [full-text search](Documentation/FullTextSearch.md).
    
    ```swift
    // SELECT * FROM document WHERE document MATCH 'sqlite database'
    let pattern = FTS3Pattern(matchingAllTokensIn: "SQLite database")
    Document.matching(pattern)
    ```
    
    When the pattern is nil, no row will match.

- [`group(expression, ...)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/aggregatingrequest/group(_:)-edak) groups rows.
    
    ```swift
    // SELECT name, MAX(score) FROM player GROUP BY name
    Player
        .select(nameColumn, max(scoreColumn))
        .group(nameColumn)
    ```

- [`having(expression)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/aggregatingrequest/having(_:)) applies conditions on grouped rows.
    
    ```swift
    // SELECT team, MAX(score) FROM player GROUP BY team HAVING MIN(score) >= 1000
    Player
        .select(teamColumn, max(scoreColumn))
        .group(teamColumn)
        .having(min(scoreColumn) >= 1000)
    ```

- [`having(aggregate)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/derivablerequest/having(_:)) applies conditions on grouped rows, according to an [association aggregate](Documentation/AssociationsBasics.md#association-aggregates).
    
    ```swift
    // SELECT team.*
    // FROM team
    // LEFT JOIN player ON player.teamId = team.id
    // GROUP BY team.id
    // HAVING COUNT(DISTINCT player.id) >= 5
    Team.having(Team.players.count >= 5)
    ```

- [`order(ordering, ...)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/orderedrequest/order(_:)-63rzl) sorts.
    
    ```swift
    // SELECT * FROM player ORDER BY name
    Player.order(nameColumn)
    
    // SELECT * FROM player ORDER BY score DESC, name
    Player.order(scoreColumn.desc, nameColumn)
    ```
    
    SQLite considers NULL values to be smaller than any other values for sorting purposes. Hence, NULLs naturally appear at the beginning of an ascending ordering and at the end of a descending ordering. With a [custom SQLite build], this can be changed using `.ascNullsLast` and `.descNullsFirst`:
    
    ```swift
    // SELECT * FROM player ORDER BY score ASC NULLS LAST
    Player.order(nameColumn.ascNullsLast)
    ```
    
    Each `order` call clears any previous ordering:
    
    ```swift
    // SELECT * FROM player ORDER BY name
    Player.order(scoreColumn).order(nameColumn)
    ```

- [`reversed()`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/orderedrequest/reversed()) reverses the eventual orderings.
    
    ```swift
    // SELECT * FROM player ORDER BY score ASC, name DESC
    Player.order(scoreColumn.desc, nameColumn).reversed()
    ```
    
    If no ordering was already specified, this method has no effect:
    
    ```swift
    // SELECT * FROM player
    Player.all().reversed()
    ```

- [`limit(limit, offset: offset)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/queryinterfacerequest/limit(_:offset:)) limits and pages results.
    
    ```swift
    // SELECT * FROM player LIMIT 5
    Player.limit(5)
    
    // SELECT * FROM player LIMIT 5 OFFSET 10
    Player.limit(5, offset: 10)
    ```

- [`joining(required:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/joinablerequest/joining(required:)), [`joining(optional:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/joinablerequest/joining(optional:)), [`including(required:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/joinablerequest/including(required:)), [`including(optional:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/joinablerequest/including(optional:)), and [`including(all:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/joinablerequest/including(all:)) fetch and join records through [Associations].
    
    ```swift
    // SELECT player.*, team.*
    // FROM player
    // JOIN team ON team.id = player.teamId
    Player.including(required: Player.team)
    ```

- [`with(cte)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/derivablerequest/with(_:)) embeds a [common table expression]:
    
    ```swift
    // WITH ... SELECT * FROM player
    let cte = CommonTableExpression(...)
    Player.with(cte)
    ```

- Other requests that involve the primary key:
    
    - [`selectPrimaryKey(as:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/queryinterfacerequest/selectprimarykey(as:)) selects the primary key.
    
        ```swift
        // SELECT id FROM player
        Player.selectPrimaryKey(as: Int64.self)    // QueryInterfaceRequest<Int64>
        
        // SELECT code FROM country
        Country.selectPrimaryKey(as: String.self)  // QueryInterfaceRequest<String>
        
        // SELECT citizenId, countryCode FROM citizenship
        Citizenship.selectPrimaryKey(as: Row.self) // QueryInterfaceRequest<Row>
        ```
        
    - [`orderByPrimaryKey()`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerequest/orderbyprimarykey()) sorts by primary key.
        
        ```swift
        // SELECT * FROM player ORDER BY id
        Player.orderByPrimaryKey()
        
        // SELECT * FROM country ORDER BY code
        Country.orderByPrimaryKey()
        
        // SELECT * FROM citizenship ORDER BY citizenId, countryCode
        Citizenship.orderByPrimaryKey()
        ```
    
    - [`groupByPrimaryKey()`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/tablerequest/groupbyprimarykey()) groups rows by primary key.


You can refine requests by chaining those methods:

```swift
// SELECT * FROM player WHERE (email IS NOT NULL) ORDER BY name
Player.order(nameColumn).filter(emailColumn != nil)
```

The `select`, `order`, `group`, and `limit` methods ignore and replace previously applied selection, orderings, grouping, and limits. On the opposite, `filter`, `matching`, and `having` methods extend the query:

```swift
Player                          // SELECT * FROM player
    .filter(nameColumn != nil)  // WHERE (name IS NOT NULL)
    .filter(emailColumn != nil) //        AND (email IS NOT NULL)
    .order(nameColumn)          // - ignored -
    .reversed()                 // - ignored -
    .order(scoreColumn)         // ORDER BY score
    .limit(20, offset: 40)      // - ignored -
    .limit(10)                  // LIMIT 10
```


Raw SQL snippets are also accepted, with eventual [arguments](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/statementarguments):

```swift
// SELECT DATE(creationDate), COUNT(*) FROM player WHERE name = 'Arthur' GROUP BY date(creationDate)
Player
    .select(sql: "DATE(creationDate), COUNT(*)")
    .filter(sql: "name = ?", arguments: ["Arthur"])
    .group(sql: "DATE(creationDate)")
```


### Columns Selected by a Request

By default, query interface requests select all columns:

```swift
// SELECT * FROM player
struct Player: TableRecord { ... }
let request = Player.all()

// SELECT * FROM player
let table = Table("player")
let request = table.all()
```

**The selection can be changed for each individual requests, or in the case of record-based requests, for all requests built from this record type.**

The `select(...)` and `select(..., as:)` methods change the selection of a single request (see [Fetching from Requests] for detailed information):

```swift
let request = Player.select(max(Column("score")))
let maxScore = try Int.fetchOne(db, request) // Int?

let request = Player.select(max(Column("score")), as: Int.self)
let maxScore = try request.fetchOne(db)      // Int?
```

The default selection for a record type is controlled by the `databaseSelection` property:

```swift
struct RestrictedPlayer : TableRecord {
    static let databaseTableName = "player"
    static let databaseSelection: [any SQLSelectable] = [Column("id"), Column("name")]
}

struct ExtendedPlayer : TableRecord {
    static let databaseTableName = "player"
    static let databaseSelection: [any SQLSelectable] = [AllColumns(), Column.rowID]
}

// SELECT id, name FROM player
let request = RestrictedPlayer.all()

// SELECT *, rowid FROM player
let request = ExtendedPlayer.all()
```

> **Note**: make sure the `databaseSelection` property is explicitly declared as `[any SQLSelectable]`. If it is not, the Swift compiler may silently miss the protocol requirement, resulting in sticky `SELECT *` requests. To verify your setup, see the [How do I print a request as SQL?](#how-do-i-print-a-request-as-sql) FAQ.


## Expressions

Feed [requests](#requests) with SQL expressions built from your Swift code:


### SQL Operators

📖 [`SQLSpecificExpressible`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/sqlspecificexpressible)

GRDB comes with a Swift version of many SQLite [built-in operators](https://sqlite.org/lang_expr.html#operators), listed below. But not all: see [Embedding SQL in Query Interface Requests] for a way to add support for missing SQL operators.

- `=`, `<>`, `<`, `<=`, `>`, `>=`, `IS`, `IS NOT`
    
    Comparison operators are based on the Swift operators `==`, `!=`, `===`, `!==`, `<`, `<=`, `>`, `>=`:
    
    ```swift
    // SELECT * FROM player WHERE (name = 'Arthur')
    Player.filter(nameColumn == "Arthur")
    
    // SELECT * FROM player WHERE (name IS NULL)
    Player.filter(nameColumn == nil)
    
    // SELECT * FROM player WHERE (score IS 1000)
    Player.filter(scoreColumn === 1000)
    
    // SELECT * FROM rectangle WHERE width < height
    Rectangle.filter(widthColumn < heightColumn)
    ```
    
    Subqueries are supported:
    
    ```swift
    // SELECT * FROM player WHERE score = (SELECT max(score) FROM player)
    let maximumScore = Player.select(max(scoreColumn))
    Player.filter(scoreColumn == maximumScore)
    
    // SELECT * FROM player WHERE score = (SELECT max(score) FROM player)
    let maximumScore = SQLRequest("SELECT max(score) FROM player")
    Player.filter(scoreColumn == maximumScore)
    ```
    
    > **Note**: SQLite string comparison, by default, is case-sensitive and not Unicode-aware. See [string comparison](#string-comparison) if you need more control.

- `*`, `/`, `+`, `-`
    
    SQLite arithmetic operators are derived from their Swift equivalent:
    
    ```swift
    // SELECT ((temperature * 1.8) + 32) AS fahrenheit FROM planet
    Planet.select((temperatureColumn * 1.8 + 32).forKey("fahrenheit"))
    ```
    
    > **Note**: an expression like `nameColumn + "rrr"` will be interpreted by SQLite as a numerical addition (with funny results), not as a string concatenation. See the `concat` operator below.
    
    When you want to join a sequence of expressions with the `+` or `*` operator, use `joined(operator:)`:
    
    ```swift
    // SELECT score + bonus + 1000 FROM player
    let values = [
        scoreColumn,
        bonusColumn,
        1000.databaseValue]
    Player.select(values.joined(operator: .add))
    ```
    
    Note in the example above how you concatenate raw values: `1000.databaseValue`. A plain `1000` would not compile.
    
    When the sequence is empty, `joined(operator: .add)` returns 0, and `joined(operator: .multiply)` returns 1.

- `&`, `|`, `~`, `<<`, `>>`
    
    Bitwise operations (bitwise and, or, not, left shift, right shift) are derived from their Swift equivalent:
    
    ```swift
    // SELECT mask & 2 AS isRocky FROM planet
    Planet.select((Column("mask") & 2).forKey("isRocky"))
    ```

- `||`
    
    Concatenate several strings:
    
    ```swift
    // SELECT firstName || ' ' || lastName FROM player
    Player.select([firstNameColumn, " ".databaseValue, lastNameColumn].joined(operator: .concat))
    ```
    
    Note in the example above how you concatenate raw strings: `" ".databaseValue`. A plain `" "` would not compile.
    
    When the sequence is empty, `joined(operator: .concat)` returns the empty string.

- `AND`, `OR`, `NOT`
    
    The SQL logical operators are derived from the Swift `&&`, `||` and `!`:
    
    ```swift
    // SELECT * FROM player WHERE ((NOT verified) OR (score < 1000))
    Player.filter(!verifiedColumn || scoreColumn < 1000)
    ```
    
    When you want to join a sequence of expressions with the `AND` or `OR` operator, use `joined(operator:)`:
    
    ```swift
    // SELECT * FROM player WHERE (verified AND (score >= 1000) AND (name IS NOT NULL))
    let conditions = [
        verifiedColumn,
        scoreColumn >= 1000,
        nameColumn != nil]
    Player.filter(conditions.joined(operator: .and))
    ```
    
    When the sequence is empty, `joined(operator: .and)` returns true, and `joined(operator: .or)` returns false:
    
    ```swift
    // SELECT * FROM player WHERE 1
    Player.filter([].joined(operator: .and))
    
    // SELECT * FROM player WHERE 0
    Player.filter([].joined(operator: .or))
    ```

- `BETWEEN`, `IN`, `NOT IN`
    
    To check inclusion in a Swift sequence (array, set, range…), call the `contains` method:
    
    ```swift
    // SELECT * FROM player WHERE id IN (1, 2, 3)
    Player.filter([1, 2, 3].contains(idColumn))
    
    // SELECT * FROM player WHERE id NOT IN (1, 2, 3)
    Player.filter(![1, 2, 3].contains(idColumn))
    
    // SELECT * FROM player WHERE score BETWEEN 0 AND 1000
    Player.filter((0...1000).contains(scoreColumn))
    
    // SELECT * FROM player WHERE (score >= 0) AND (score < 1000)
    Player.filter((0..<1000).contains(scoreColumn))
    
    // SELECT * FROM player WHERE initial BETWEEN 'A' AND 'N'
    Player.filter(("A"..."N").contains(initialColumn))
    
    // SELECT * FROM player WHERE (initial >= 'A') AND (initial < 'N')
    Player.filter(("A"..<"N").contains(initialColumn))
    ```
    
    To check inclusion inside a subquery, call the `contains` method as well:
    
    ```swift
    // SELECT * FROM player WHERE id IN (SELECT playerId FROM playerSelection)
    let selectedPlayerIds = PlayerSelection.select(playerIdColumn)
    Player.filter(selectedPlayerIds.contains(idColumn))
    
    // SELECT * FROM player WHERE id IN (SELECT playerId FROM playerSelection)
    let selectedPlayerIds = SQLRequest("SELECT playerId FROM playerSelection")
    Player.filter(selectedPlayerIds.contains(idColumn))
    ```
    
    To check inclusion inside a [common table expression], call the `contains` method as well:
    
    ```swift
    // WITH selectedName AS (...)
    // SELECT * FROM player WHERE name IN selectedName
    let cte = CommonTableExpression(named: "selectedName", ...)
    Player
        .with(cte)
        .filter(cte.contains(nameColumn))
    ```
    
    > **Note**: SQLite string comparison, by default, is case-sensitive and not Unicode-aware. See [string comparison](#string-comparison) if you need more control.

- `EXISTS`, `NOT EXISTS`
    
    To check if a subquery would return rows, call the `exists` method:
    
    ```swift
    // Teams that have at least one other player
    //
    //  SELECT * FROM team
    //  WHERE EXISTS (SELECT * FROM player WHERE teamID = team.id)
    let teamAlias = TableAlias()
    let player = Player.filter(Column("teamID") == teamAlias[Column("id")])
    let teams = Team.aliased(teamAlias).filter(player.exists())
    
    // Teams that have no player
    //
    //  SELECT * FROM team
    //  WHERE NOT EXISTS (SELECT * FROM player WHERE teamID = team.id)
    let teams = Team.aliased(teamAlias).filter(!player.exists())
    ```
    
    In the above example, you use a `TableAlias` in order to let a subquery refer to a column from another table.
    
    In the next example, which involves the same table twice, the table alias requires an explicit disambiguation with `TableAlias(name:)`:
    
    ```swift    
    // Players who coach at least one other player
    //
    //  SELECT coach.* FROM player coach
    //  WHERE EXISTS (SELECT * FROM player WHERE coachId = coach.id)
    let coachAlias = TableAlias(name: "coach")
    let coachedPlayer = Player.filter(Column("coachId") == coachAlias[Column("id")])
    let coaches = Player.aliased(coachAlias).filter(coachedPlayer.exists())
    ```
    
    Finally, subqueries can also be expressed as SQL, with [SQL Interpolation]:
    
    ```swift
    // SELECT coach.* FROM player coach
    // WHERE EXISTS (SELECT * FROM player WHERE coachId = coach.id)
    let coachedPlayer = SQLRequest("SELECT * FROM player WHERE coachId = \(coachAlias[Column("id")])")
    let coaches = Player.aliased(coachAlias).filter(coachedPlayer.exists())
    ```
    
- `LIKE`
    
    The SQLite LIKE operator is available as the `like` method:
    
    ```swift
    // SELECT * FROM player WHERE (email LIKE '%@example.com')
    Player.filter(emailColumn.like("%@example.com"))
    
    // SELECT * FROM book WHERE (title LIKE '%10\%%' ESCAPE '\')
    Player.filter(emailColumn.like("%10\\%%", escape: "\\"))
    ```
    
    > **Note**: the SQLite LIKE operator is case-insensitive but not Unicode-aware. For example, the expression `'a' LIKE 'A'` is true but `'æ' LIKE 'Æ'` is false.

- `MATCH`
    
    The full-text MATCH operator is available through [FTS3Pattern](Documentation/FullTextSearch.md#fts3pattern) (for FTS3 and FTS4 tables) and [FTS5Pattern](Documentation/FullTextSearch.md#fts5pattern) (for FTS5):
    
    FTS3 and FTS4:
    
    ```swift
    let pattern = FTS3Pattern(matchingAllTokensIn: "SQLite database")
    
    // SELECT * FROM document WHERE document MATCH 'sqlite database'
    Document.matching(pattern)
    
    // SELECT * FROM document WHERE content MATCH 'sqlite database'
    Document.filter(contentColumn.match(pattern))
    ```
    
    FTS5:
    
    ```swift
    let pattern = FTS5Pattern(matchingAllTokensIn: "SQLite database")
    
    // SELECT * FROM document WHERE document MATCH 'sqlite database'
    Document.matching(pattern)
    ```
- `AS`
    
    To give an alias to an expression, use the `forKey` method:
    
    ```swift
    // SELECT (score + bonus) AS total
    // FROM player
    Player.select((Column("score") + Column("bonus")).forKey("total"))
    ```
    
    If you need to refer to this aliased column in another place of the request, use a detached column:
    
    ```swift
    // SELECT (score + bonus) AS total
    // FROM player 
    // ORDER BY total
    Player
        .select((Column("score") + Column("bonus")).forKey("total"))
        .order(Column("total").detached)
    ```
    
    Unlike `Column("total")`, the detached column `Column("total").detached` is never associated to the "player" table, so it is always rendered as `total` in the generated SQL, even when the request involves other tables via an [association](Documentation/AssociationsBasics.md) or a [common table expression].


### SQL Functions

📖 [`SQLSpecificExpressible`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/sqlspecificexpressible)

GRDB comes with a Swift version of many SQLite [built-in functions](https://sqlite.org/lang_corefunc.html), listed below. But not all: see [Embedding SQL in Query Interface Requests] for a way to add support for missing SQL functions.

- `ABS`, `AVG`, `COUNT`, `DATETIME`, `JULIANDAY`, `LENGTH`, `MAX`, `MIN`, `SUM`, `TOTAL`:
    
    Those are based on the `abs`, `average`, `count`, `dateTime`, `julianDay`, `length`, `max`, `min`, `sum` and `total` Swift functions:
    
    ```swift
    // SELECT MIN(score), MAX(score) FROM player
    Player.select(min(scoreColumn), max(scoreColumn))
    
    // SELECT COUNT(name) FROM player
    Player.select(count(nameColumn))
    
    // SELECT COUNT(DISTINCT name) FROM player
    Player.select(count(distinct: nameColumn))
    
    // SELECT JULIANDAY(date, 'start of year') FROM game
    Game.select(julianDay(dateColumn, .startOfYear))
    ```
    
    For more information about the functions `dateTime` and `julianDay`, see [Date And Time Functions](https://www.sqlite.org/lang_datefunc.html).

- `CAST`

    Use the `cast` Swift function:
    
    ```swift
    // SELECT (CAST(wins AS REAL) / games) AS successRate FROM player
    Player.select((cast(winsColumn, as: .real) / gamesColumn).forKey("successRate"))
    ```
    
    See [CAST expressions](https://www.sqlite.org/lang_expr.html#castexpr) for more information about SQLite conversions.

- `IFNULL`
    
    Use the Swift `??` operator:
    
    ```swift
    // SELECT IFNULL(name, 'Anonymous') FROM player
    Player.select(nameColumn ?? "Anonymous")
    
    // SELECT IFNULL(name, email) FROM player
    Player.select(nameColumn ?? emailColumn)
    ```

- `LOWER`, `UPPER`
    
    The query interface does not give access to those SQLite functions. Nothing against them, but they are not unicode aware.
    
    Instead, GRDB extends SQLite with SQL functions that call the Swift built-in string functions `capitalized`, `lowercased`, `uppercased`, `localizedCapitalized`, `localizedLowercased` and `localizedUppercased`:
    
    ```swift
    Player.select(nameColumn.uppercased())
    ```
    
    > **Note**: When *comparing* strings, you'd rather use a [collation](#string-comparison):
    >
    > ```swift
    > let name: String = ...
    >
    > // Not recommended
    > nameColumn.uppercased() == name.uppercased()
    >
    > // Better
    > nameColumn.collating(.caseInsensitiveCompare) == name
    > ```

- Custom SQL functions and aggregates
    
    You can apply your own [custom SQL functions and aggregates](#custom-functions-):
    
    ```swift
    let f = DatabaseFunction("f", ...)
    
    // SELECT f(name) FROM player
    Player.select(f.apply(nameColumn))
    ```

## Embedding SQL in Query Interface Requests

You will sometimes want to extend your query interface requests with SQL snippets. This can happen because GRDB does not provide a Swift interface for some SQL function or operator, or because you want to use an SQLite construct that GRDB does not support.

Support for extensibility is large, but not unlimited. All the SQL queries built by the query interface request have the shape below. _If you need something else, you'll have to use [raw SQL requests](#sqlite-api)._

```sql
WITH ...     -- 1
SELECT ...   -- 2
FROM ...     -- 3
JOIN ...     -- 4
WHERE ...    -- 5
GROUP BY ... -- 6
HAVING ...   -- 7
ORDER BY ... -- 8
LIMIT ...    -- 9
```

1. `WITH ...`: see [Common Table Expressions].

2. `SELECT ...`

    The selection can be provided as raw SQL:
    
    ```swift
    // SELECT IFNULL(name, 'O''Brien'), score FROM player
    let request = Player.select(sql: "IFNULL(name, 'O''Brien'), score")
    
    // SELECT IFNULL(name, 'O''Brien'), score FROM player
    let defaultName = "O'Brien"
    let request = Player.select(sql: "IFNULL(name, ?), score", arguments: [suffix])
    ```

    The selection can be provided with [SQL Interpolation]:
    
    ```swift
    // SELECT IFNULL(name, 'O''Brien'), score FROM player
    let defaultName = "O'Brien"
    let request = Player.select(literal: "IFNULL(name, \(defaultName)), score")
    ```
    
    The selection can be provided with a mix of Swift and [SQL Interpolation]:
    
    ```swift
    // SELECT IFNULL(name, 'O''Brien') AS displayName, score FROM player
    let defaultName = "O'Brien"
    let displayName: SQL = "IFNULL(\(Column("name")), \(defaultName)) AS displayName"
    let request = Player.select(displayName, Column("score"))
    ```
    
    When the custom SQL snippet should behave as a full-fledged expression, with support for the `+` Swift operator, the `forKey` aliasing method, and all other [SQL Operators](#sql-operators), build an _expression literal_ with the `SQL.sqlExpression` method:
    
    ```swift
    // SELECT IFNULL(name, 'O''Brien') AS displayName, score FROM player
    let defaultName = "O'Brien"
    let displayName = SQL("IFNULL(\(Column("name")), \(defaultName))").sqlExpression
    let request = Player.select(displayName.forKey("displayName"), Column("score"))
    ```
    
    Such expression literals allow you to build a reusable support library of SQL functions or operators that are missing from the query interface. For example, you can define a Swift `date` function:
    
    ```swift
    func date(_ value: some SQLSpecificExpressible) -> SQLExpression {
        SQL("DATE(\(value))").sqlExpression
    }
    
    // SELECT * FROM "player" WHERE DATE("createdAt") = '2020-01-23'
    let request = Player.filter(date(Column("createdAt")) == "2020-01-23")
    ```
    
    See the [Query Interface Organization] for more information about `SQLSpecificExpressible` and `SQLExpression`.
    
3. `FROM ...`: only one table is supported here. You can not customize this SQL part.

4. `JOIN ...`: joins are fully controlled by [Associations]. You can not customize this SQL part.

5. `WHERE ...`
    
    The WHERE clause can be provided as raw SQL:
    
    ```swift
    // SELECT * FROM player WHERE score >= 1000
    let request = Player.filter(sql: "score >= 1000")
    
    // SELECT * FROM player WHERE score >= 1000
    let minScore = 1000
    let request = Player.filter(sql: "score >= ?", arguments: [minScore])
    ```

    The WHERE clause can be provided with [SQL Interpolation]:
    
    ```swift
    // SELECT * FROM player WHERE score >= 1000
    let minScore = 1000
    let request = Player.filter(literal: "score >= \(minScore)")
    ```
    
    The WHERE clause can be provided with a mix of Swift and [SQL Interpolation]:
    
    ```swift
    // SELECT * FROM player WHERE (score >= 1000) AND (team = 'red')
    let minScore = 1000
    let scoreCondition: SQL = "\(Column("score")) >= \(minScore)"
    let request = Player.filter(scoreCondition && Column("team") == "red")
    ```
    
    See `SELECT ...` above for more SQL Interpolation examples.
    
6. `GROUP BY ...`

    The GROUP BY clause can be provided as raw SQL, SQL Interpolation, or a mix of Swift and SQL Interpolation, just as the selection and the WHERE clause (see above).
    
7. `HAVING ...`

    The HAVING clause can be provided as raw SQL, SQL Interpolation, or a mix of Swift and SQL Interpolation, just as the selection and the WHERE clause (see above).
    
8. `ORDER BY ...`

    The ORDER BY clause can be provided as raw SQL, SQL Interpolation, or a mix of Swift and SQL Interpolation, just as the selection and the WHERE clause (see above).
    
    In order to support the `desc` and `asc` query interface operators, and the `reversed()` query interface method, you must provide your orderings as _expression literals_ with the `SQL.sqlExpression` method:
    
    ```swift
    // SELECT * FROM "player" 
    // ORDER BY (score + bonus) ASC, name DESC
    let total = SQL("(score + bonus)").sqlExpression
    let request = Player
        .order(total.desc, Column("name"))
        .reversed()
    ```
    
9. `LIMIT ...`: use the `limit(_:offset:)` method. You can not customize this SQL part.


## Fetching from Requests

Once you have a request, you can fetch the records at the origin of the request:

```swift
// Some request based on `Player`
let request = Player.filter(...)... // QueryInterfaceRequest<Player>

// Fetch players:
try request.fetchCursor(db) // A Cursor of Player
try request.fetchAll(db)    // [Player]
try request.fetchSet(db)    // Set<Player>
try request.fetchOne(db)    // Player?
```

For example:

```swift
let allPlayers = try Player.fetchAll(db)                            // [Player]
let arthur = try Player.filter(nameColumn == "Arthur").fetchOne(db) // Player?
```

See [fetching methods](#fetching-methods) for information about the `fetchCursor`, `fetchAll`, `fetchSet` and `fetchOne` methods.

**You sometimes want to fetch other values**.

The simplest way is to use the request as an argument to a fetching method of the desired type:

```swift
// Fetch an Int
let request = Player.select(max(scoreColumn))
let maxScore = try Int.fetchOne(db, request) // Int?

// Fetch a Row
let request = Player.select(min(scoreColumn), max(scoreColumn))
let row = try Row.fetchOne(db, request)!     // Row
let minScore = row[0] as Int?
let maxScore = row[1] as Int?
```

You can also change the request so that it knows the type it has to fetch:

- With `asRequest(of:)`, useful when you use [Associations]:
    
    ```swift
    struct BookInfo: FetchableRecord, Decodable {
        var book: Book
        var author: Author
    }
    
    // A request of BookInfo
    let request = Book
        .including(required: Book.author)
        .asRequest(of: BookInfo.self)
    
    let bookInfos = try dbQueue.read { db in
        try request.fetchAll(db) // [BookInfo]
    }
    ```
    
- With `select(..., as:)`, which is handy when you change the selection:
    
    ```swift
    // A request of Int
    let request = Player.select(max(scoreColumn), as: Int.self)
    
    let maxScore = try dbQueue.read { db in
        try request.fetchOne(db) // Int?
    }
    ```


## Fetching by Key

**Fetching records according to their primary key** is a common task.

[Identifiable Records] can use the type-safe methods `find(_:id:)`, `fetchOne(_:id:)`, `fetchAll(_:ids:)` and `fetchSet(_:ids:)`:

```swift
try Player.find(db, id: 1)                   // Player
try Player.fetchOne(db, id: 1)               // Player?
try Country.fetchAll(db, ids: ["FR", "US"])  // [Countries]
```

All record types can use `find(_:key:)`, `fetchOne(_:key:)`, `fetchAll(_:keys:)` and `fetchSet(_:keys:)` that apply conditions on primary and unique keys:

```swift
try Player.find(db, key: 1)                  // Player
try Player.fetchOne(db, key: 1)              // Player?
try Country.fetchAll(db, keys: ["FR", "US"]) // [Country]
try Player.fetchOne(db, key: ["email": "arthur@example.com"])            // Player?
try Citizenship.fetchOne(db, key: ["citizenId": 1, "countryCode": "FR"]) // Citizenship?
```

When the table has no explicit primary key, GRDB uses the [hidden `rowid` column](https://www.sqlite.org/rowidtable.html):

```swift
// SELECT * FROM document WHERE rowid = 1
try Document.fetchOne(db, key: 1)            // Document?
```

**When you want to build a request and plan to fetch from it later**, use a `filter` method:

```swift
let request = Player.filter(id: 1)
let request = Country.filter(ids: ["FR", "US"])
let request = Player.filter(key: ["email": "arthur@example.com"])
let request = Citizenship.filter(key: ["citizenId": 1, "countryCode": "FR"])
```


## Testing for Record Existence

**You can check if a request has matching rows in the database.**

```swift
// Some request based on `Player`
let request = Player.filter(...)...

// Check for player existence:
let noSuchPlayer = try request.isEmpty(db) // Bool
```

You should check for emptiness instead of counting:

```swift
// Correct
let noSuchPlayer = try request.fetchCount(db) == 0
// Even better
let noSuchPlayer = try request.isEmpty(db)
```

**You can also check if a given primary or unique key exists in the database.**

[Identifiable Records] can use the type-safe method `exists(_:id:)`:

```swift
try Player.exists(db, id: 1)
try Country.exists(db, id: "FR")
```

All record types can use `exists(_:key:)` that can check primary and unique keys:

```swift
try Player.exists(db, key: 1)
try Country.exists(db, key: "FR")
try Player.exists(db, key: ["email": "arthur@example.com"])
try Citizenship.exists(db, key: ["citizenId": 1, "countryCode": "FR"])
```

You should check for key existence instead of fetching a record and checking for nil:

```swift
// Correct
let playerExists = try Player.fetchOne(db, id: 1) != nil
// Even better
let playerExists = try Player.exists(db, id: 1)
```


## Fetching Aggregated Values

**Requests can count.** The `fetchCount()` method returns the number of rows that would be returned by a fetch request:

```swift
// SELECT COUNT(*) FROM player
let count = try Player.fetchCount(db) // Int

// SELECT COUNT(*) FROM player WHERE email IS NOT NULL
let count = try Player.filter(emailColumn != nil).fetchCount(db)

// SELECT COUNT(DISTINCT name) FROM player
let count = try Player.select(nameColumn).distinct().fetchCount(db)

// SELECT COUNT(*) FROM (SELECT DISTINCT name, score FROM player)
let count = try Player.select(nameColumn, scoreColumn).distinct().fetchCount(db)
```


**Other aggregated values** can also be selected and fetched (see [SQL Functions](#sql-functions)):

```swift
let request = Player.select(max(scoreColumn))
let maxScore = try Int.fetchOne(db, request) // Int?

let request = Player.select(min(scoreColumn), max(scoreColumn))
let row = try Row.fetchOne(db, request)!     // Row
let minScore = row[0] as Int?
let maxScore = row[1] as Int?
```


## Delete Requests

**Requests can delete records**, with the `deleteAll()` method:

```swift
// DELETE FROM player
try Player.deleteAll(db)

// DELETE FROM player WHERE team = 'red'
try Player
    .filter(teamColumn == "red")
    .deleteAll(db)

// DELETE FROM player ORDER BY score LIMIT 10
try Player
    .order(scoreColumn)
    .limit(10)
    .deleteAll(db)
```

> **Note** Deletion methods are available on types that adopt the [TableRecord] protocol, and `Table`:
>
> ```swift
> struct Player: TableRecord { ... }
> try Player.deleteAll(db)          // Fine
> try Table("player").deleteAll(db) // Just as fine
> ```

**Deleting records according to their primary key** is a common task.

[Identifiable Records] can use the type-safe methods `deleteOne(_:id:)` and `deleteAll(_:ids:)`:

```swift
try Player.deleteOne(db, id: 1)
try Country.deleteAll(db, ids: ["FR", "US"])
```

All record types can use `deleteOne(_:key:)` and `deleteAll(_:keys:)` that apply conditions on primary and unique keys:

```swift
try Player.deleteOne(db, key: 1)
try Country.deleteAll(db, keys: ["FR", "US"])
try Player.deleteOne(db, key: ["email": "arthur@example.com"])
try Citizenship.deleteOne(db, key: ["citizenId": 1, "countryCode": "FR"])
```

When the table has no explicit primary key, GRDB uses the [hidden `rowid` column](https://www.sqlite.org/rowidtable.html):

```swift
// DELETE FROM document WHERE rowid = 1
try Document.deleteOne(db, id: 1)             // Document?
```


## Update Requests

**Requests can batch update records**. The `updateAll()` method accepts *column assignments* defined with the `set(to:)` method:

```swift
// UPDATE player SET score = 0, isHealthy = 1, bonus = NULL
try Player.updateAll(db, 
    Column("score").set(to: 0), 
    Column("isHealthy").set(to: true), 
    Column("bonus").set(to: nil))

// UPDATE player SET score = 0 WHERE team = 'red'
try Player
    .filter(Column("team") == "red")
    .updateAll(db, Column("score").set(to: 0))

// UPDATE player SET top = 1 ORDER BY score DESC LIMIT 10
try Player
    .order(Column("score").desc)
    .limit(10)
    .updateAll(db, Column("top").set(to: true))

// UPDATE country SET population = 67848156 WHERE id = 'FR'
try Country
    .filter(id: "FR")
    .updateAll(db, Column("population").set(to: 67_848_156))
```

Column assignments accept any expression:

```swift
// UPDATE player SET score = score + (bonus * 2)
try Player.updateAll(db, Column("score").set(to: Column("score") + Column("bonus") * 2))
```

As a convenience, you can also use the `+=`, `-=`, `*=`, or `/=` operators:

```swift
// UPDATE player SET score = score + (bonus * 2)
try Player.updateAll(db, Column("score") += Column("bonus") * 2)
```

Default [Conflict Resolution] rules apply, and you may also provide a specific one:

```swift
// UPDATE OR IGNORE player SET ...
try Player.updateAll(db, onConflict: .ignore, /* assignments... */)
```

> **Note** The `updateAll` method is available on types that adopt the [TableRecord] protocol, and `Table`:
>
> ```swift
> struct Player: TableRecord { ... }
> try Player.updateAll(db, ...)          // Fine
> try Table("player").updateAll(db, ...) // Just as fine
> ```


## Custom Requests

Until now, we have seen [requests](#requests) created from any type that adopts the [TableRecord] protocol:

```swift
let request = Player.all()  // QueryInterfaceRequest<Player>
```

Those requests of type `QueryInterfaceRequest` can fetch and count:

```swift
try request.fetchCursor(db) // A Cursor of Player
try request.fetchAll(db)    // [Player]
try request.fetchSet(db)    // Set<Player>
try request.fetchOne(db)    // Player?
try request.fetchCount(db)  // Int
```

**When the query interface can not generate the SQL you need**, you can still fallback to [raw SQL](#fetch-queries):

```swift
// Custom SQL is always welcome
try Player.fetchAll(db, sql: "SELECT ...")   // [Player]
```

But you may prefer to bring some elegance back in, and build custom requests:

```swift
// No custom SQL in sight
try Player.customRequest().fetchAll(db) // [Player]
```

**To build custom requests**, you can use one of the built-in requests or derive requests from other requests.

- [SQLRequest] is a fetch request built from raw SQL. For example:
    
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
    
    SQLRequest supports [SQL Interpolation]:
    
    ```swift
    extension Player {
        static func filter(color: Color) -> SQLRequest<Player> {
            "SELECT * FROM player WHERE color = \(color)"
        }
    }
    ```
    
- The [`asRequest(of:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/queryinterfacerequest/asrequest(of:)) method changes the type fetched by the request. It is useful, for example, when you use [Associations]:

    ```swift
    struct BookInfo: FetchableRecord, Decodable {
        var book: Book
        var author: Author
    }
    
    let request = Book
        .including(required: Book.author)
        .asRequest(of: BookInfo.self)
    
    // [BookInfo]
    try request.fetchAll(db)
    ```

- The [`adapted(_:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/fetchrequest/adapted(_:)) method eases the consumption of complex rows with row adapters. See [`RowAdapter`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/rowadapter) and [`splittingRowAdapters(columnCounts:)`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/splittingrowadapters(columncounts:)) for a sample code that uses `adapted(_:)`.


Encryption
==========

**GRDB can encrypt your database with [SQLCipher](http://sqlcipher.net) v3.4+.**

Use [CocoaPods](http://cocoapods.org/), and specify in your `Podfile`:

```ruby
# GRDB with SQLCipher 4
pod 'GRDB.swift/SQLCipher'
pod 'SQLCipher', '~> 4.0'

# GRDB with SQLCipher 3
pod 'GRDB.swift/SQLCipher'
pod 'SQLCipher', '~> 3.4'
```

Make sure you remove any existing `pod 'GRDB.swift'` from your Podfile. `GRDB.swift/SQLCipher` must be the only active GRDB pod in your whole project, or you will face linker or runtime errors, due to the conflicts between SQLCipher and the system SQLite.

- [Creating or Opening an Encrypted Database](#creating-or-opening-an-encrypted-database)
- [Changing the Passphrase of an Encrypted Database](#changing-the-passphrase-of-an-encrypted-database)
- [Exporting a Database to an Encrypted Database](#exporting-a-database-to-an-encrypted-database)
- [Security Considerations](#security-considerations)


### Creating or Opening an Encrypted Database

**You create and open an encrypted database** by providing a passphrase to your [database connection]:

```swift
var config = Configuration()
config.prepareDatabase { db in
    try db.usePassphrase("secret")
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

It is also in `prepareDatabase` that you perform other [SQLCipher configuration steps](https://www.zetetic.net/sqlcipher/sqlcipher-api/) that must happen early in the lifetime of a SQLCipher connection. For example:

```swift
var config = Configuration()
config.prepareDatabase { db in
    try db.usePassphrase("secret")
    try db.execute(sql: "PRAGMA cipher_page_size = ...")
    try db.execute(sql: "PRAGMA kdf_iter = ...")
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

When you want to open an existing SQLCipher 3 database with SQLCipher 4, you may want to run the `cipher_compatibility` pragma:

```swift
// Open an SQLCipher 3 database with SQLCipher 4
var config = Configuration()
config.prepareDatabase { db in
    try db.usePassphrase("secret")
    try db.execute(sql: "PRAGMA cipher_compatibility = 3")
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

See [SQLCipher 4.0.0 Release](https://www.zetetic.net/blog/2018/11/30/sqlcipher-400-release/) and [Upgrading to SQLCipher 4](https://discuss.zetetic.net/t/upgrading-to-sqlcipher-4/3283) for more information.


### Changing the Passphrase of an Encrypted Database

**You can change the passphrase** of an already encrypted database.

When you use a [database queue](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasequeue), open the database with the old passphrase, and then apply the new passphrase:

```swift
try dbQueue.write { db in
    try db.changePassphrase("newSecret")
}
```

When you use a [database pool](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasepool), make sure that no concurrent read can happen by changing the passphrase within the `barrierWriteWithoutTransaction` block. You must also ensure all future reads open a new database connection by calling the `invalidateReadOnlyConnections` method:

```swift
try dbPool.barrierWriteWithoutTransaction { db in
    try db.changePassphrase("newSecret")
    dbPool.invalidateReadOnlyConnections()
}
```

> **Note**: When an application wants to keep on using a database queue or pool after the passphrase has changed, it is responsible for providing the correct passphrase to the `usePassphrase` method called in the database preparation function. Consider:
>
> ```swift
> // WRONG: this won't work across a passphrase change
> let passphrase = try getPassphrase()
> var config = Configuration()
> config.prepareDatabase { db in
>     try db.usePassphrase(passphrase)
> }
>
> // CORRECT: get the latest passphrase when it is needed
> var config = Configuration()
> config.prepareDatabase { db in
>     let passphrase = try getPassphrase()
>     try db.usePassphrase(passphrase)
> }
> ```

> **Note**: The `DatabasePool.barrierWriteWithoutTransaction` method does not prevent [database snapshots](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasesnapshot) from accessing the database during the passphrase change, or after the new passphrase has been applied to the database. Those database accesses may throw errors. Applications should provide their own mechanism for invalidating open snapshots before the passphrase is changed.

> **Note**: Instead of changing the passphrase "in place" as described here, you can also export the database in a new encrypted database that uses the new passphrase. See [Exporting a Database to an Encrypted Database](#exporting-a-database-to-an-encrypted-database).


### Exporting a Database to an Encrypted Database

Providing a passphrase won't encrypt a clear-text database that already exists, though. SQLCipher can't do that, and you will get an error instead: `SQLite error 26: file is encrypted or is not a database`.

Instead, create a new encrypted database, at a distinct location, and export the content of the existing database. This can both encrypt a clear-text database, or change the passphrase of an encrypted database.

The technique to do that is [documented](https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/868/1) by SQLCipher.

With GRDB, it gives:

```swift
// The existing database
let existingDBQueue = try DatabaseQueue(path: "/path/to/existing.db")

// The new encrypted database, at some distinct location:
var config = Configuration()
config.prepareDatabase { db in
    try db.usePassphrase("secret")
}
let newDBQueue = try DatabaseQueue(path: "/path/to/new.db", configuration: config)

try existingDBQueue.inDatabase { db in
    try db.execute(
        sql: """
            ATTACH DATABASE ? AS encrypted KEY ?;
            SELECT sqlcipher_export('encrypted');
            DETACH DATABASE encrypted;
            """,
        arguments: [newDBQueue.path, "secret"])
}

// Now the export is completed, and the existing database can be deleted.
```


### Security Considerations

#### Managing the lifetime of the passphrase string

It is recommended to avoid keeping the passphrase in memory longer than necessary. To do this, make sure you load the passphrase from the `prepareDatabase` method:

```swift
// NOT RECOMMENDED: this keeps the passphrase in memory longer than necessary
let passphrase = try getPassphrase()
var config = Configuration()
config.prepareDatabase { db in
    try db.usePassphrase(passphrase)
}

// RECOMMENDED: only load the passphrase when it is needed
var config = Configuration()
config.prepareDatabase { db in
    let passphrase = try getPassphrase()
    try db.usePassphrase(passphrase)
}
```

This technique helps manages the lifetime of the passphrase, although keep in mind that the content of a String may remain intact in memory long after the object has been released.

For even better control over the lifetime of the passphrase in memory, use a Data object which natively provides the `resetBytes` function.

```swift
// RECOMMENDED: only load the passphrase when it is needed and reset its content immediately after use
var config = Configuration()
config.prepareDatabase { db in
    var passphraseData = try getPassphraseData() // Data
    defer {
        passphraseData.resetBytes(in: 0..<passphraseData.count)
    }
    try db.usePassphrase(passphraseData)
}
```

Some demanding users will want to go further, and manage the lifetime of the raw passphrase bytes. See below.


#### Managing the lifetime of the passphrase bytes

GRDB offers convenience methods for providing the database passphrases as Swift strings: `usePassphrase(_:)` and `changePassphrase(_:)`. Those methods don't keep the passphrase String in memory longer than necessary. But they are as secure as the standard String type: the lifetime of actual passphrase bytes in memory is not under control.

When you want to precisely manage the passphrase bytes, talk directly to SQLCipher, using its raw C functions.

For example:

```swift
var config = Configuration()
config.prepareDatabase { db in
    ... // Carefully load passphrase bytes
    let code = sqlite3_key(db.sqliteConnection, /* passphrase bytes */)
    ... // Carefully dispose passphrase bytes
    guard code == SQLITE_OK else {
        throw DatabaseError(
            resultCode: ResultCode(rawValue: code), 
            message: db.lastErrorMessage)
    }
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

#### Passphrase availability vs. Database availability

When the passphrase is securely stored in the system keychain, your application can protect it using the [`kSecAttrAccessible`](https://developer.apple.com/documentation/security/ksecattraccessible) attribute.

Such protection prevents GRDB from creating SQLite connections when the passphrase is not available:

```swift
var config = Configuration()
config.prepareDatabase { db in
    let passphrase = try loadPassphraseFromSystemKeychain()
    try db.usePassphrase(passphrase)
}

// Success if and only if the passphrase is available
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

For the same reason, [database pools], which open SQLite connections on demand, may fail at any time as soon as the passphrase becomes unavailable:

```swift
// Success if and only if the passphrase is available
let dbPool = try DatabasePool(path: dbPath, configuration: config)

// May fail if passphrase has turned unavailable
try dbPool.read { ... }

// May trigger value observation failure if passphrase has turned unavailable
try dbPool.write { ... }
```

Because DatabasePool maintains a pool of long-lived SQLite connections, some database accesses will use an existing connection, and succeed. And some other database accesses will fail, as soon as the pool wants to open a new connection. It is impossible to predict which accesses will succeed or fail.

For the same reason, a database queue, which also maintains a long-lived SQLite connection, will remain available even after the passphrase has turned unavailable.

Applications are thus responsible for protecting database accesses when the passphrase is unavailable. To this end, they can use [Data Protection](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/encrypting_your_app_s_files). They can also destroy their instances of database queue or pool when the passphrase becomes unavailable.


## Backup

**You can backup (copy) a database into another.**

Backups can for example help you copying an in-memory database to and from a database file when you implement NSDocument subclasses.

```swift
let source: DatabaseQueue = ...      // or DatabasePool
let destination: DatabaseQueue = ... // or DatabasePool
try source.backup(to: destination)
```

The `backup` method blocks the current thread until the destination database contains the same contents as the source database.

When the source is a [database pool](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasepool), concurrent writes can happen during the backup. Those writes may, or may not, be reflected in the backup, but they won't trigger any error.

`Database` has an analogous `backup` method.

```swift
let source: DatabaseQueue = ...      // or DatabasePool
let destination: DatabaseQueue = ... // or DatabasePool
try source.write { sourceDb in
    try destination.barrierWriteWithoutTransaction { destDb in
        try sourceDb.backup(to: destDb)
    }
}
```

This method allows for the choice of source and destination `Database` handles with which to backup the database.

### Backup Progress Reporting

The `backup` methods take optional `pagesPerStep` and `progress` parameters. Together these parameters can be used to track a database backup in progress and abort an incomplete backup.

When `pagesPerStep` is provided, the database backup is performed in _steps_. At each step, no more than `pagesPerStep` database pages are copied from the source to the destination. The backup proceeds one step at a time until all pages have been copied.

When a `progress` callback is provided, `progress` is called after every backup step, including the last. Even if a non-default `pagesPerStep` is specified or the backup is otherwise completed in a single step, the `progress` callback will be called.

```swift
try source.backup(
    to: destination,
    pagesPerStep: ...)
    { backupProgress in
       print("Database backup progress:", backupProgress)
    }
```

### Aborting an Incomplete Backup

If a call to `progress` throws when `backupProgress.isComplete == false`, the backup will be aborted and the error rethrown. However, if a call to `progress` throws when `backupProgress.isComplete == true`, the backup is unaffected and the error is silently ignored.

> **Warning**: Passing non-default values of `pagesPerStep` or `progress` to the backup methods is an advanced API intended to provide additional capabilities to expert users. GRDB's backup API provides a faithful, low-level wrapper to the underlying SQLite online backup API. GRDB's documentation is not a comprehensive substitute for the official SQLite [documentation of their backup API](https://www.sqlite.org/c3ref/backup_finish.html).

## Interrupt a Database

**The `interrupt()` method** causes any pending database operation to abort and return at its earliest opportunity.

It can be called from any thread.

```swift
dbQueue.interrupt()
dbPool.interrupt()
```

A call to `interrupt()` that occurs when there are no running SQL statements is a no-op and has no effect on SQL statements that are started after `interrupt()` returns.

A database operation that is interrupted will throw a DatabaseError with code `SQLITE_INTERRUPT`. If the interrupted SQL operation is an INSERT, UPDATE, or DELETE that is inside an explicit transaction, then the entire transaction will be rolled back automatically. If the rolled back transaction was started by a transaction-wrapping method such as `DatabaseWriter.write` or `Database.inTransaction`, then all database accesses will throw a DatabaseError with code `SQLITE_ABORT` until the wrapping method returns.

For example:

```swift
try dbQueue.write { db in
    try Player(...).insert(db)     // throws SQLITE_INTERRUPT
    try Player(...).insert(db)     // not executed
}                                  // throws SQLITE_INTERRUPT

try dbQueue.write { db in
    do {
        try Player(...).insert(db) // throws SQLITE_INTERRUPT
    } catch { }
}                                  // throws SQLITE_ABORT

try dbQueue.write { db in
    do {
        try Player(...).insert(db) // throws SQLITE_INTERRUPT
    } catch { }
    try Player(...).insert(db)     // throws SQLITE_ABORT
}                                  // throws SQLITE_ABORT
```

You can catch both `SQLITE_INTERRUPT` and `SQLITE_ABORT` errors:

```swift
do {
    try dbPool.write { db in ... }
} catch DatabaseError.SQLITE_INTERRUPT, DatabaseError.SQLITE_ABORT {
    // Oops, the database was interrupted.
}
```

For more information, see [Interrupt A Long-Running Query](https://www.sqlite.org/c3ref/interrupt.html).


## Avoiding SQL Injection

SQL injection is a technique that lets an attacker nuke your database.

> ![XKCD: Exploits of a Mom](https://imgs.xkcd.com/comics/exploits_of_a_mom.png)
>
> https://xkcd.com/327/

Here is an example of code that is vulnerable to SQL injection:

```swift
// BAD BAD BAD
let id = 1
let name = textField.text
try dbQueue.write { db in
    try db.execute(sql: "UPDATE students SET name = '\(name)' WHERE id = \(id)")
}
```

If the user enters a funny string like `Robert'; DROP TABLE students; --`, SQLite will see the following SQL, and drop your database table instead of updating a name as intended:

```sql
UPDATE students SET name = 'Robert';
DROP TABLE students;
--' WHERE id = 1
```

To avoid those problems, **never embed raw values in your SQL queries**. The only correct technique is to provide [arguments](#executing-updates) to your raw SQL queries:

```swift
let name = textField.text
try dbQueue.write { db in
    // Good
    try db.execute(
        sql: "UPDATE students SET name = ? WHERE id = ?",
        arguments: [name, id])
    
    // Just as good
    try db.execute(
        sql: "UPDATE students SET name = :name WHERE id = :id",
        arguments: ["name": name, "id": id])
}
```

When you use [records](#records) and the [query interface](#the-query-interface), GRDB always prevents SQL injection for you:

```swift
let id = 1
let name = textField.text
try dbQueue.write { db in
    if var student = try Student.fetchOne(db, id: id) {
        student.name = name
        try student.update(db)
    }
}
```


## Error Handling

GRDB can throw [DatabaseError](#databaseerror), [RecordError], or crash your program with a [fatal error](#fatal-errors).

Considering that a local database is not some JSON loaded from a remote server, GRDB focuses on **trusted databases**. Dealing with [untrusted databases](#how-to-deal-with-untrusted-inputs) requires extra care.

- [DatabaseError](#databaseerror)
- [RecordError]
- [Fatal Errors](#fatal-errors)
- [How to Deal with Untrusted Inputs](#how-to-deal-with-untrusted-inputs)
- [Error Log](#error-log)


### DatabaseError

📖 [`DatabaseError`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseerror)

**DatabaseError** are thrown on SQLite errors:

```swift
do {
    try Pet(masterId: 1, name: "Bobby").insert(db)
} catch let error as DatabaseError {
    // The SQLite error code: 19 (SQLITE_CONSTRAINT)
    error.resultCode
    
    // The extended error code: 787 (SQLITE_CONSTRAINT_FOREIGNKEY)
    error.extendedResultCode
    
    // The eventual SQLite message: FOREIGN KEY constraint failed
    error.message
    
    // The eventual erroneous SQL query
    // "INSERT INTO pet (masterId, name) VALUES (?, ?)"
    error.sql
    
    // The eventual SQL arguments
    // [1, "Bobby"]
    error.arguments
    
    // Full error description
    // > SQLite error 19: FOREIGN KEY constraint failed -
    // > while executing `INSERT INTO pet (masterId, name) VALUES (?, ?)`
    error.description
}
```

If you want to see statement arguments in the error description, [make statement arguments public](https://swiftpackageindex.com/groue/grdb.swift/configuration/publicstatementarguments).

**SQLite uses [results codes](https://www.sqlite.org/rescode.html) to distinguish between various errors**.

You can catch a DatabaseError and match on result codes:

```swift
do {
    try ...
} catch let error as DatabaseError {
    switch error {
    case DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY:
        // foreign key constraint error
    case DatabaseError.SQLITE_CONSTRAINT:
        // any other constraint error
    default:
        // any other database error
    }
}
```

You can also directly match errors on result codes:

```swift
do {
    try ...
} catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY {
    // foreign key constraint error
} catch DatabaseError.SQLITE_CONSTRAINT {
    // any other constraint error
} catch {
    // any other database error
}
```

Each DatabaseError has two codes: an `extendedResultCode` (see [extended result code](https://www.sqlite.org/rescode.html#extended_result_code_list)), and a less precise `resultCode` (see [primary result code](https://www.sqlite.org/rescode.html#primary_result_code_list)). Extended result codes are refinements of primary result codes, as `SQLITE_CONSTRAINT_FOREIGNKEY` is to `SQLITE_CONSTRAINT`, for example.

> **Warning**: SQLite has progressively introduced extended result codes across its versions. The [SQLite release notes](http://www.sqlite.org/changes.html) are unfortunately not quite clear about that: write your handling of extended result codes with care.


### RecordError

📖 [`RecordError`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/recorderror)

**RecordError** is thrown by the [PersistableRecord] protocol when the `update` method could not find any row to update:

```swift
do {
    try player.update(db)
} catch let RecordError.recordNotFound(databaseTableName: table, key: key) {
    print("Key \(key) was not found in table \(table).")
}
```

**RecordError** is also thrown by the [FetchableRecord] protocol when the `find` method does not find any record:

```swift
do {
    let player = try Player.find(db, id: 42)
} catch let RecordError.recordNotFound(databaseTableName: table, key: key) {
    print("Key \(key) was not found in table \(table).")
}
```


### Fatal Errors

**Fatal errors notify that the program, or the database, has to be changed.**

They uncover programmer errors, false assumptions, and prevent misuses. Here are a few examples:

- **The code asks for a non-optional value, when the database contains NULL:**
    
    ```swift
    // fatal error: could not convert NULL to String.
    let name: String = row["name"]
    ```
    
    Solution: fix the contents of the database, use [NOT NULL constraints](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/columndefinition/notnull(onconflict:)), or load an optional:
    
    ```swift
    let name: String? = row["name"]
    ```

- **Conversion from database value to Swift type fails:**
    
    ```swift
    // fatal error: could not convert "Mom’s birthday" to Date.
    let date: Date = row["date"]
    
    // fatal error: could not convert "" to URL.
    let url: URL = row["url"]
    ```
    
    Solution: fix the contents of the database, or use [DatabaseValue](#databasevalue) to handle all possible cases:
    
    ```swift
    let dbValue: DatabaseValue = row["date"]
    if dbValue.isNull {
        // Handle NULL
    } else if let date = Date.fromDatabaseValue(dbValue) {
        // Handle valid date
    } else {
        // Handle invalid date
    }
    ```

- **The database can't guarantee that the code does what it says:**

    ```swift
    // fatal error: table player has no unique index on column email
    try Player.deleteOne(db, key: ["email": "arthur@example.com"])
    ```
    
    Solution: add a unique index to the player.email column, or use the `deleteAll` method to make it clear that you may delete more than one row:
    
    ```swift
    try Player.filter(Column("email") == "arthur@example.com").deleteAll(db)
    ```

- **Database connections are not reentrant:**
    
    ```swift
    // fatal error: Database methods are not reentrant.
    dbQueue.write { db in
        dbQueue.write { db in
            ...
        }
    }
    ```
    
    Solution: avoid reentrancy, and instead pass a database connection along.


### How to Deal with Untrusted Inputs

Let's consider the code below:

```swift
let sql = "SELECT ..."

// Some untrusted arguments for the query
let arguments: [String: Any] = ...
let rows = try Row.fetchCursor(db, sql: sql, arguments: StatementArguments(arguments))

while let row = try rows.next() {
    // Some untrusted database value:
    let date: Date? = row[0]
}
```

It has two opportunities to throw fatal errors:

- **Untrusted arguments**: The dictionary may contain values that do not conform to the [DatabaseValueConvertible protocol](#values), or may miss keys required by the statement.
- **Untrusted database content**: The row may contain a non-null value that can't be turned into a date.

In such a situation, you can still avoid fatal errors by exposing and handling each failure point, one level down in the GRDB API:

```swift
// Untrusted arguments
if let arguments = StatementArguments(arguments) {
    let statement = try db.makeStatement(sql: sql)
    try statement.setArguments(arguments)
    
    var cursor = try Row.fetchCursor(statement)
    while let row = try iterator.next() {
        // Untrusted database content
        let dbValue: DatabaseValue = row[0]
        if dbValue.isNull {
            // Handle NULL
        if let date = Date.fromDatabaseValue(dbValue) {
            // Handle valid date
        } else {
            // Handle invalid date
        }
    }
}
```

See [`Statement`] and [DatabaseValue](#databasevalue) for more information.


### Error Log

**SQLite can be configured to invoke a callback function containing an error code and a terse error message whenever anomalies occur.**

This global error callback must be configured early in the lifetime of your application:

```swift
Database.logError = { (resultCode, message) in
    NSLog("%@", "SQLite error \(resultCode): \(message)")
}
```

> **Warning**: Database.logError must be set before any database connection is opened. This includes the connections that your application opens with GRDB, but also connections opened by other tools, such as third-party libraries. Setting it after a connection has been opened is an SQLite misuse, and has no effect.

See [The Error And Warning Log](https://sqlite.org/errlog.html) for more information.


## Unicode

SQLite lets you store unicode strings in the database.

However, SQLite does not provide any unicode-aware string transformations or comparisons.


### Unicode functions

The `UPPER` and `LOWER` built-in SQLite functions are not unicode-aware:

```swift
// "JéRôME"
try String.fetchOne(db, sql: "SELECT UPPER('Jérôme')")
```

GRDB extends SQLite with [SQL functions](#custom-sql-functions-and-aggregates) that call the Swift built-in string functions `capitalized`, `lowercased`, `uppercased`, `localizedCapitalized`, `localizedLowercased` and `localizedUppercased`:

```swift
// "JÉRÔME"
let uppercased = DatabaseFunction.uppercase
try String.fetchOne(db, sql: "SELECT \(uppercased.name)('Jérôme')")
```

Those unicode-aware string functions are also readily available in the [query interface](#sql-functions):

```swift
Player.select(nameColumn.uppercased)
```


### String Comparison

SQLite compares strings in many occasions: when you sort rows according to a string column, or when you use a comparison operator such as `=` and `<=`.

The comparison result comes from a *collating function*, or *collation*. SQLite comes with three built-in collations that do not support Unicode: [binary, nocase, and rtrim](https://www.sqlite.org/datatype3.html#collation).

GRDB comes with five extra collations that leverage unicode-aware comparisons based on the standard Swift String comparison functions and operators:

- `unicodeCompare` (uses the built-in `<=` and `==` Swift operators)
- `caseInsensitiveCompare`
- `localizedCaseInsensitiveCompare`
- `localizedCompare`
- `localizedStandardCompare`

A collation can be applied to a table column. All comparisons involving this column will then automatically trigger the comparison function:
    
```swift
try db.create(table: "player") { t in
    // Guarantees case-insensitive email unicity
    t.column("email", .text).unique().collate(.nocase)
    
    // Sort names in a localized case insensitive way
    t.column("name", .text).collate(.localizedCaseInsensitiveCompare)
}

// Players are sorted in a localized case insensitive way:
let players = try Player.order(nameColumn).fetchAll(db)
```

> **Warning**: SQLite *requires* host applications to provide the definition of any collation other than binary, nocase and rtrim. When a database file has to be shared or migrated to another SQLite library of platform (such as the Android version of your application), make sure you provide a compatible collation.

If you can't or don't want to define the comparison behavior of a column (see warning above), you can still use an explicit collation in SQL requests and in the [query interface](#the-query-interface):

```swift
let collation = DatabaseCollation.localizedCaseInsensitiveCompare
let players = try Player.fetchAll(db,
    sql: "SELECT * FROM player ORDER BY name COLLATE \(collation.name))")
let players = try Player.order(nameColumn.collating(collation)).fetchAll(db)
```


**You can also define your own collations**:

```swift
let collation = DatabaseCollation("customCollation") { (lhs, rhs) -> NSComparisonResult in
    // return the comparison of lhs and rhs strings.
}

// Make the collation available to a database connection
var config = Configuration()
config.prepareDatabase { db in
    db.add(collation: collation)
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```



## Memory Management

Both SQLite and GRDB use non-essential memory that help them perform better.

You can reclaim this memory with the `releaseMemory` method:

```swift
// Release as much memory as possible.
dbQueue.releaseMemory()
dbPool.releaseMemory()
```

This method blocks the current thread until all current database accesses are completed, and the memory collected.

> **Warning**: If `DatabasePool.releaseMemory()` is called while a long read is performed concurrently, then no other read access will be possible until this long read has completed, and the memory has been released. If this does not suit your application needs, look for the asynchronous options below:

You can release memory in an asynchronous way as well:

```swift
// On a DatabaseQueue
dbQueue.asyncWriteWithoutTransaction { db in
    db.releaseMemory()
}

// On a DatabasePool
dbPool.releaseMemoryEventually()
```

`DatabasePool.releaseMemoryEventually()` does not block the current thread, and does not prevent concurrent database accesses. In exchange for this convenience, you don't know when memory has been freed.


### Memory Management on iOS

**The iOS operating system likes applications that do not consume much memory.**

[Database queues] and [pools](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasepool) automatically free non-essential memory when the application receives a memory warning, and when the application enters background.

You can opt out of this automatic memory management:

```swift
var config = Configuration()
config.automaticMemoryManagement = false
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config) // or DatabasePool
```

FAQ
===

**[FAQ: Opening Connections](#faq-opening-connections)**

- [How do I create a database in my application?](#how-do-i-create-a-database-in-my-application)
- [How do I open a database stored as a resource of my application?](#how-do-i-open-a-database-stored-as-a-resource-of-my-application)
- [How do I close a database connection?](#how-do-i-close-a-database-connection)

**[FAQ: SQL](#faq-sql)**

- [How do I print a request as SQL?](#how-do-i-print-a-request-as-sql)

**[FAQ: General](#faq-general)**

- [How do I monitor the duration of database statements execution?](#how-do-i-monitor-the-duration-of-database-statements-execution)
- [What Are Experimental Features?](#what-are-experimental-features)
- [Does GRDB support library evolution and ABI stability?](#does-grdb-support-library-evolution-and-abi-stability)

**[FAQ: Associations](#faq-associations)**

- [How do I filter records and only keep those that are associated to another record?](#how-do-i-filter-records-and-only-keep-those-that-are-associated-to-another-record)
- [How do I filter records and only keep those that are NOT associated to another record?](#how-do-i-filter-records-and-only-keep-those-that-are-not-associated-to-another-record)
- [How do I select only one column of an associated record?](#how-do-i-select-only-one-column-of-an-associated-record)

**[FAQ: ValueObservation](#faq-valueobservation)**

- [Why is ValueObservation not publishing value changes?](#why-is-valueobservation-not-publishing-value-changes)

**[FAQ: Errors](#faq-errors)**

- [Generic parameter 'T' could not be inferred](#generic-parameter-t-could-not-be-inferred)
- [Mutation of captured var in concurrently-executing code](#mutation-of-captured-var-in-concurrently-executing-code)
- [SQLite error 1 "no such column"](#sqlite-error-1-no-such-column)
- [SQLite error 10 "disk I/O error", SQLite error 23 "not authorized"](#sqlite-error-10-disk-io-error-sqlite-error-23-not-authorized)
- [SQLite error 21 "wrong number of statement arguments" with LIKE queries](#sqlite-error-21-wrong-number-of-statement-arguments-with-like-queries)


## FAQ: Opening Connections

- :arrow_up: [FAQ]
- [How do I create a database in my application?](#how-do-i-create-a-database-in-my-application)
- [How do I open a database stored as a resource of my application?](#how-do-i-open-a-database-stored-as-a-resource-of-my-application)
- [How do I close a database connection?](#how-do-i-close-a-database-connection)

### How do I create a database in my application?

First choose a proper location for the database file. Document-based applications will let the user pick a location. Apps that use the database as a global storage will prefer the Application Support directory.

The sample code below creates or opens a database file inside its dedicated directory (a [recommended practice](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections)). On the first run, a new empty database file is created. On subsequent runs, the database file already exists, so it just opens a connection:

```swift
// HOW TO create an empty database, or open an existing database file

// Create the "Application Support/MyDatabase" directory
let fileManager = FileManager.default
let appSupportURL = try fileManager.url(
    for: .applicationSupportDirectory, in: .userDomainMask,
    appropriateFor: nil, create: true) 
let directoryURL = appSupportURL.appendingPathComponent("MyDatabase", isDirectory: true)
try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

// Open or create the database
let databaseURL = directoryURL.appendingPathComponent("db.sqlite")
let dbQueue = try DatabaseQueue(path: databaseURL.path)
```

### How do I open a database stored as a resource of my application?

Open a read-only connection to your resource:

```swift
// HOW TO open a read-only connection to a database resource

// Get the path to the database resource.
if let dbPath = Bundle.main.path(forResource: "db", ofType: "sqlite") {
    // If the resource exists, open a read-only connection.
    // Writes are disallowed because resources can not be modified. 
    var config = Configuration()
    config.readonly = true
    let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
} else {
    // The database resource can not be found.
    // Fix your setup, or report the problem to the user. 
}
```

### How do I close a database connection?

Database connections are automatically closed when `DatabaseQueue` or `DatabasePool` instances are deinitialized.

If the correct execution of your program depends on precise database closing, perform an explicit call to [`close()`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasereader/close()). This method may fail and create zombie connections, so please check its detailed documentation.

## FAQ: SQL

- :arrow_up: [FAQ]
- [How do I print a request as SQL?](#how-do-i-print-a-request-as-sql)

### How do I print a request as SQL?

When you want to debug a request that does not deliver the expected results, you may want to print the SQL that is actually executed.

You can compile the request into a prepared [`Statement`]:

```swift
try dbQueue.read { db in
    let request = Player.filter(Column("email") == "arthur@example.com")
    let statement = try request.makePreparedRequest(db).statement
    print(statement) // SELECT * FROM player WHERE email = ?
    print(statement.arguments) // ["arthur@example.com"]
}
```

Another option is to setup a tracing function that prints out the executed SQL requests. For example, provide a tracing function when you connect to the database:

```swift
// Prints all SQL statements
var config = Configuration()
config.prepareDatabase { db in
    db.trace { print($0) }
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

try dbQueue.read { db in
    // Prints "SELECT * FROM player WHERE email = ?"
    let players = try Player.filter(Column("email") == "arthur@example.com").fetchAll(db)
}
```

If you want to see statement arguments such as `'arthur@example.com'` in the logged statements, [make statement arguments public](https://swiftpackageindex.com/groue/grdb.swift/configuration/publicstatementarguments).

> **Note**: the generated SQL may change between GRDB releases, without notice: don't have your application rely on any specific SQL output.


## FAQ: General

- :arrow_up: [FAQ]
- [How do I monitor the duration of database statements execution?](#how-do-i-monitor-the-duration-of-database-statements-execution)
- [What Are Experimental Features?](#what-are-experimental-features)
- [Does GRDB support library evolution and ABI stability?](#does-grdb-support-library-evolution-and-abi-stability)

### How do I monitor the duration of database statements execution?

Use the `trace(options:_:)` method, with the `.profile` option:

```swift
var config = Configuration()
config.prepareDatabase { db in
    db.trace(options: .profile) { event in
        // Prints all SQL statements with their duration
        print(event)
        
        // Access to detailed profiling information
        if case let .profile(statement, duration) = event, duration > 0.5 {
            print("Slow query: \(statement.sql)")
        }
    }
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

try dbQueue.read { db in
    let players = try Player.filter(Column("email") == "arthur@example.com").fetchAll(db)
    // Prints "0.003s SELECT * FROM player WHERE email = ?"
}
```

If you want to see statement arguments such as `'arthur@example.com'` in the logged statements, [make statement arguments public](https://swiftpackageindex.com/groue/grdb.swift/configuration/publicstatementarguments).

### What Are Experimental Features?

Since GRDB 1.0, all backwards compatibility guarantees of [semantic versioning](http://semver.org) apply: no breaking change will happen until the next major version of the library.

There is an exception, though: *experimental features*, marked with the "**:fire: EXPERIMENTAL**" badge. Those are advanced features that are too young, or lack user feedback. They are not stabilized yet.

Those experimental features are not protected by semantic versioning, and may break between two minor releases of the library. To help them becoming stable, [your feedback](https://github.com/groue/GRDB.swift/issues) is greatly appreciated.

### Does GRDB support library evolution and ABI stability?

No, GRDB does not support library evolution and ABI stability. The only promise is API stability according to [semantic versioning](http://semver.org), with an exception for [experimental features](#what-are-experimental-features).

Yet, GRDB can be built with the "Build Libraries for Distribution" Xcode option (`BUILD_LIBRARY_FOR_DISTRIBUTION`), so that you can build binary frameworks at your convenience.

## FAQ: Associations

- :arrow_up: [FAQ]
- [How do I filter records and only keep those that are associated to another record?](#how-do-i-filter-records-and-only-keep-those-that-are-associated-to-another-record)
- [How do I filter records and only keep those that are NOT associated to another record?](#how-do-i-filter-records-and-only-keep-those-that-are-not-associated-to-another-record)
- [How do I select only one column of an associated record?](#how-do-i-select-only-one-column-of-an-associated-record)

### How do I filter records and only keep those that are associated to another record?

Let's say you have two record types, `Book` and `Author`, and you want to only fetch books that have an author, and discard anonymous books.

We start by defining the association between books and authors:

```swift
struct Book: TableRecord {
    ...
    static let author = belongsTo(Author.self)
}

struct Author: TableRecord {
    ...
}
```

And then we can write our request and only fetch books that have an author, discarding anonymous ones:

```swift
let books: [Book] = try dbQueue.read { db in
    // SELECT book.* FROM book 
    // JOIN author ON author.id = book.authorID
    let request = Book.joining(required: Book.author)
    return try request.fetchAll(db)
}
```

Note how this request does not use the `filter` method. Indeed, we don't have any condition to express on any column. Instead, we just need to "require that a book can be joined to its author".

See [How do I filter records and only keep those that are NOT associated to another record?](#how-do-i-filter-records-and-only-keep-those-that-are-not-associated-to-another-record) below for the opposite question.


### How do I filter records and only keep those that are NOT associated to another record?

Let's say you have two record types, `Book` and `Author`, and you want to only fetch anonymous books that do not have any author.

We start by defining the association between books and authors:

```swift
struct Book: TableRecord {
    ...
    static let author = belongsTo(Author.self)
}

struct Author: TableRecord {
    ...
}
```

And then we can write our request and only fetch anonymous books that don't have any author:

```swift
let books: [Book] = try dbQueue.read { db in
    // SELECT book.* FROM book
    // LEFT JOIN author ON author.id = book.authorID
    // WHERE author.id IS NULL
    let authorAlias = TableAlias()
    let request = Book
        .joining(optional: Book.author.aliased(authorAlias))
        .filter(!authorAlias.exists)
    return try request.fetchAll(db)
}
```

This request uses a TableAlias in order to be able to filter on the eventual associated author. We make sure that the `Author.primaryKey` is nil, which is another way to say it does not exist: the book has no author.

See [How do I filter records and only keep those that are associated to another record?](#how-do-i-filter-records-and-only-keep-those-that-are-associated-to-another-record) above for the opposite question.


### How do I select only one column of an associated record?

Let's say you have two record types, `Book` and `Author`, and you want to fetch all books with their author name, but not the full associated author records.

We start by defining the association between books and authors:

```swift
struct Book: Decodable, TableRecord {
    ...
    static let author = belongsTo(Author.self)
}

struct Author: Decodable, TableRecord {
    ...
    enum Columns {
        static let name = Column(CodingKeys.name)
    }
}
```

And then we can write our request and the ad-hoc record that decodes it:

```swift
struct BookInfo: Decodable, FetchableRecord {
    var book: Book
    var authorName: String? // nil when the book is anonymous
    
    static func all() -> QueryInterfaceRequest<BookInfo> {
        // SELECT book.*, author.name AS authorName
        // FROM book
        // LEFT JOIN author ON author.id = book.authorID
        let authorName = Author.Columns.name.forKey(CodingKeys.authorName)
        return Book
            .annotated(withOptional: Book.author.select(authorName))
            .asRequest(of: BookInfo.self)
    }
}

let bookInfos: [BookInfo] = try dbQueue.read { db in
    BookInfo.all().fetchAll(db)
}
```

By defining the request as a static method of BookInfo, you have access to the private `CodingKeys.authorName`, and a compiler-checked SQL column name.

By using the `annotated(withOptional:)` method, you append the author name to the top-level selection that can be decoded by the ad-hoc record.

By using `asRequest(of:)`, you enhance the type-safety of your request.


## FAQ: ValueObservation

- :arrow_up: [FAQ]
- [Why is ValueObservation not publishing value changes?](#why-is-valueobservation-not-publishing-value-changes)

### Why is ValueObservation not publishing value changes?

Sometimes it looks that a [ValueObservation] does not notify the changes you expect.

There may be four possible reasons for this:

1. The expected changes were not committed into the database.
2. The expected changes were committed into the database, but were quickly overwritten.
3. The observation was stopped.
4. The observation does not track the expected database region.

To answer the first two questions, look at SQL statements executed by the database. This is done when you open the database connection:

```swift
// Prints all SQL statements
var config = Configuration()
config.prepareDatabase { db in
    db.trace { print("SQL: \($0)") }
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

If, after that, you are convinced that the expected changes were committed into the database, and not overwritten soon after, trace observation events:

```swift
let observation = ValueObservation
    .tracking { db in ... }
    .print() // <- trace observation events
let cancellable = observation.start(...)
```

Look at the observation logs which start with `cancel` or `failure`: maybe the observation was cancelled by your app, or did fail with an error.

Look at the observation logs which start with `value`: make sure, again, that the expected value was not actually notified, then overwritten.

Finally, look at the observation logs which start with `tracked region`. Does the printed database region cover the expected changes?

For example:

- `empty`: The empty region, which tracks nothing and never triggers the observation.
- `player(*)`: The full `player` table
- `player(id,name)`: The `id` and `name` columns of the `player` table
- `player(id,name)[1]`: The `id` and `name` columns of the row with id 1 in the `player` table
- `player(*),team(*)`: Both the full `player` and `team` tables

If you happen to use the `ValueObservation.trackingConstantRegion(_:)` method and see a mismatch between the tracked region and your expectation, then change the definition of your observation by using `tracking(_:)`. You should witness that the logs which start with `tracked region` now evolve in order to include the expected changes, and that you get the expected notifications.

If after all those steps (thanks you!), your observation is still failing you, please [open an issue](https://github.com/groue/GRDB.swift/issues/new) and provide a [minimal reproducible example](https://stackoverflow.com/help/minimal-reproducible-example)!


## FAQ: Errors

- :arrow_up: [FAQ]
- [Generic parameter 'T' could not be inferred](#generic-parameter-t-could-not-be-inferred)
- [Mutation of captured var in concurrently-executing code](#mutation-of-captured-var-in-concurrently-executing-code)
- [SQLite error 1 "no such column"](#sqlite-error-1-no-such-column)
- [SQLite error 10 "disk I/O error", SQLite error 23 "not authorized"](#sqlite-error-10-disk-io-error-sqlite-error-23-not-authorized)
- [SQLite error 21 "wrong number of statement arguments" with LIKE queries](#sqlite-error-21-wrong-number-of-statement-arguments-with-like-queries)

### Generic parameter 'T' could not be inferred
    
You may get this error when using the `read` and `write` methods of database queues and pools:

```swift
// Generic parameter 'T' could not be inferred
let string = try dbQueue.read { db in
    let result = try String.fetchOne(db, ...)
    return result
}
```

This is a limitation of the Swift compiler.

The general workaround is to explicitly declare the type of the closure result:

```swift
// General Workaround
let string = try dbQueue.read { db -> String? in
    let result = try String.fetchOne(db, ...)
    return result
}
```

You can also, when possible, write a single-line closure:

```swift
// Single-line closure workaround:
let string = try dbQueue.read { db in
    try String.fetchOne(db, ...)
}
```


### Mutation of captured var in concurrently-executing code

The `insert` and `save` [persistence methods](#persistablerecord-protocol) can trigger a compiler error in async contexts:

```swift
var player = Player(id: nil, name: "Arthur")
try await dbWriter.write { db in
    // Error: Mutation of captured var 'player' in concurrently-executing code
    try player.insert(db)
}
print(player.id) // A non-nil id
```

When this happens, prefer the `inserted` and `saved` methods instead:

```swift
// OK
var player = Player(id: nil, name: "Arthur")
player = try await dbWriter.write { [player] db in
    return try player.inserted(db)
}
print(player.id) // A non-nil id
```


### SQLite error 1 "no such column"

This error message is self-explanatory: do check for misspelled or non-existing column names.

However, sometimes this error only happens when an app runs on a recent operating system (iOS 14+, Big Sur+, etc.) The error does not happen with previous ones.

When this is the case, there are two possible explanations:

1. Maybe a column name is *really* misspelled or missing from the database schema.
    
    To find it, check the SQL statement that comes with the [DatabaseError](#databaseerror).

2. Maybe the application is using the character `"` instead of the single quote `'` as the delimiter for string literals in raw SQL queries. Recent versions of SQLite have learned to tell about this deviation from the SQL standard, and this is why you are seeing this error. 
    
    For example: this is not standard SQL: `UPDATE player SET name = "Arthur"`.
    
    The standard version is: `UPDATE player SET name = 'Arthur'`.
    
    It just happens that old versions of SQLite used to accept the former, non-standard version. Newer versions are able to reject it with an error.
    
    The fix is to change the SQL statements run by the application: replace `"` with `'` in your string literals.
    
    It may also be time to learn about statement arguments and [SQL injection](#avoiding-sql-injection):
    
    ```swift
    let name: String = ...
    
    // NOT STANDARD (double quote)
    try db.execute(sql: """
        UPDATE player SET name = "\(name)"
        """)
    
    // STANDARD, BUT STILL NOT RECOMMENDED (single quote)
    try db.execute(sql: "UPDATE player SET name = '\(name)'")
    
    // STANDARD, AND RECOMMENDED (statement arguments)
    try db.execute(sql: "UPDATE player SET name = ?", arguments: [name])
    ```
    
For more information, see [Double-quoted String Literals Are Accepted](https://sqlite.org/quirks.html#double_quoted_string_literals_are_accepted), and [Configuration.acceptsDoubleQuotedStringLiterals](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/configuration/acceptsdoublequotedstringliterals).
    


### SQLite error 10 "disk I/O error", SQLite error 23 "not authorized"

Those errors may be the sign that SQLite can't access the database due to [data protection](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/encrypting_your_app_s_files).

When your application should be able to run in the background on a locked device, it has to catch this error, and, for example, wait for [UIApplicationDelegate.applicationProtectedDataDidBecomeAvailable(_:)](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1623044-applicationprotecteddatadidbecom) or [UIApplicationProtectedDataDidBecomeAvailable](https://developer.apple.com/reference/uikit/uiapplicationprotecteddatadidbecomeavailable) notification and retry the failed database operation.

```swift
do {
    try ...
} catch DatabaseError.SQLITE_IOERR, DatabaseError.SQLITE_AUTH {
    // Handle possible data protection error
}
```

This error can also be prevented altogether by using a more relaxed [file protection](https://developer.apple.com/reference/foundation/filemanager/1653059-file_protection_values).


### SQLite error 21 "wrong number of statement arguments" with LIKE queries

You may get the error "wrong number of statement arguments" when executing a LIKE query similar to:

```swift
let name = textField.text
let players = try dbQueue.read { db in
    try Player.fetchAll(db, sql: "SELECT * FROM player WHERE name LIKE '%?%'", arguments: [name])
}
```

The problem lies in the `'%?%'` pattern.

SQLite only interprets `?` as a parameter when it is a placeholder for a whole value (int, double, string, blob, null). In this incorrect query, `?` is just a character in the `'%?%'` string: it is not a query parameter, and is not processed in any way. See [https://www.sqlite.org/lang_expr.html#varparam](https://www.sqlite.org/lang_expr.html#varparam) for more information about SQLite parameters.

To fix the error, you can feed the request with the pattern itself, instead of the name:

```swift
let name = textField.text
let players: [Player] = try dbQueue.read { db in
    let pattern = "%\(name)%"
    return try Player.fetchAll(db, sql: "SELECT * FROM player WHERE name LIKE ?", arguments: [pattern])
}
```


Sample Code
===========

- The [Documentation](#documentation) is full of GRDB snippets.
- [Demo Applications]
- Open `GRDB.xcworkspace`: it contains GRDB-enabled playgrounds to play with.
- [groue/SortedDifference](https://github.com/groue/SortedDifference): How to synchronize a database table with a JSON payload


---

**Thanks**

- [Pierlis](http://pierlis.com), where we write great software.
- [@alextrob](https://github.com/alextrob), [@alexwlchan](https://github.com/alexwlchan), [@bellebethcooper](https://github.com/bellebethcooper), [@bfad](https://github.com/bfad), [@cfilipov](https://github.com/cfilipov), [@charlesmchen-signal](https://github.com/charlesmchen-signal), [@Chiliec](https://github.com/Chiliec), [@chrisballinger](https://github.com/chrisballinger), [@darrenclark](https://github.com/darrenclark), [@davidkraus](https://github.com/davidkraus), [@eburns-vmware](https://github.com/eburns-vmware), [@felixscheinost](https://github.com/felixscheinost), [@fpillet](https://github.com/fpillet), [@gcox](https://github.com/gcox), [@GetToSet](https://github.com/GetToSet), [@gjeck](https://github.com/gjeck), [@guidedways](https://github.com/guidedways), [@gusrota](https://github.com/gusrota), [@haikusw](https://github.com/haikusw), [@hartbit](https://github.com/hartbit), [@holsety](https://github.com/holsety), [@jroselightricks](https://github.com/jroselightricks), [@kdubb](https://github.com/kdubb), [@kluufger](https://github.com/kluufger), [@KyleLeneau](https://github.com/KyleLeneau), [@layoutSubviews](https://github.com/layoutSubviews), [@mallman](https://github.com/mallman), [@MartinP7r](https://github.com/MartinP7r), [@Marus](https://github.com/Marus), [@mattgallagher](https://github.com/mattgallagher), [@MaxDesiatov](https://github.com/MaxDesiatov), [@michaelkirk-signal](https://github.com/michaelkirk-signal), [@mtancock](https://github.com/mtancock), [@pakko972](https://github.com/pakko972), [@peter-ss](https://github.com/peter-ss), [@pierlo](https://github.com/pierlo), [@pocketpixels](https://github.com/pocketpixels), [@pp5x](https://github.com/pp5x), [@professordeng](https://github.com/professordeng), [@robcas3](https://github.com/robcas3), [@runhum](https://github.com/runhum), [@sberrevoets](https://github.com/sberrevoets), [@schveiguy](https://github.com/schveiguy), [@SD10](https://github.com/SD10), [@sobri909](https://github.com/sobri909), [@sroddy](https://github.com/sroddy), [@steipete](https://github.com/steipete), [@swiftlyfalling](https://github.com/swiftlyfalling), [@Timac](https://github.com/Timac), [@tternes](https://github.com/tternes), [@valexa](https://github.com/valexa), [@wuyuehyang](https://github.com/wuyuehyang), [@ZevEisenberg](https://github.com/ZevEisenberg), and [@zmeyc](https://github.com/zmeyc) for their contributions, help, and feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [@kali](https://github.com/kali) because SQL.
- [ccgus/fmdb](https://github.com/ccgus/fmdb) for its excellency.

---

[URIs don't change: people change them.](https://www.w3.org/Provider/Style/URI)

#### Adding support for missing SQL functions or operators

This chapter was renamed to [Embedding SQL in Query Interface Requests].

#### Advanced DatabasePool

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/concurrency).

#### After Commit Hook

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/database/afternexttransaction(oncommit:onrollback:)).

#### Asynchronous APIs

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/concurrency).

#### Changes Tracking

This chapter has been renamed [Record Comparison].

#### Concurrency

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/concurrency).

#### Custom Value Types

Custom Value Types conform to the [`DatabaseValueConvertible`] protocol.

#### Customized Decoding of Database Rows

This chapter has been renamed [Beyond FetchableRecord].

#### Customizing the Persistence Methods

This chapter was replaced with [Persistence Callbacks].

#### Database Changes Observation

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseobservation).

#### Database Configuration

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/configuration).

#### Database Queues

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasequeue).

#### Database Pools

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasepool).

#### Database Snapshots

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/concurrency).

#### DatabaseWriter and DatabaseReader Protocols

This chapter was removed. See the references of [DatabaseReader](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasereader) and [DatabaseWriter](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasewriter).

#### Date and UUID Coding Strategies

This chapter has been renamed [Data, Date, and UUID Coding Strategies].

#### Dealing with External Connections

This chapter has been superseded by the [Sharing a Database] guide.

#### Differences between Database Queues and Pools

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/concurrency).

#### Enabling FTS5 Support

FTS5 is enabled by default since GRDB 6.7.0.

#### FetchedRecordsController

FetchedRecordsController has been removed in GRDB 5.

The [Database Observation] chapter describes the other ways to observe the database.

#### Full-Text Search

This chapter has [moved](Documentation/FullTextSearch.md).

#### Guarantees and Rules

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/concurrency).

#### Joined Queries Support

This chapter was replaced with the documentation of [splittingRowAdapters(columnCounts:)](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/splittingrowadapters(columncounts:)).

#### Migrations

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations).

#### NSNumber and NSDecimalNumber

This chapter has [moved](#nsnumber-nsdecimalnumber-and-decimal).

#### Persistable Protocol

This protocol has been renamed [PersistableRecord] in GRDB 3.0.

#### PersistenceError

This error was renamed to [RecordError].

#### Prepared Statements

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/statement).

#### Row Adapters

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/rowadapter).

#### RowConvertible Protocol

This protocol has been renamed [FetchableRecord] in GRDB 3.0.

#### TableMapping Protocol

This protocol has been renamed [TableRecord] in GRDB 3.0.

#### Transactions and Savepoints

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/transactions).

#### Transaction Hook

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/database/afternexttransaction(oncommit:onrollback:)).

#### TransactionObserver Protocol

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/transactionobserver).

#### Unsafe Concurrency APIs

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/concurrency).

#### ValueObservation

This chapter has [moved](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/valueobservation).

#### ValueObservation and DatabaseRegionObservation

This chapter has been superseded by [ValueObservation] and [DatabaseRegionObservation].

[Associations]: Documentation/AssociationsBasics.md
[Beyond FetchableRecord]: #beyond-fetchablerecord
[Identifiable Records]: #identifiable-records
[Codable Records]: #codable-records
[Columns Selected by a Request]: #columns-selected-by-a-request
[common table expression]: Documentation/CommonTableExpressions.md
[Common Table Expressions]: Documentation/CommonTableExpressions.md
[Conflict Resolution]: #conflict-resolution
[Column Names Coding Strategies]: #column-names-coding-strategies
[Data, Date, and UUID Coding Strategies]: #data-date-and-uuid-coding-strategies
[Fetching from Requests]: #fetching-from-requests
[Embedding SQL in Query Interface Requests]: #embedding-sql-in-query-interface-requests
[Full-Text Search]: Documentation/FullTextSearch.md
[Migrations]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations
[The userInfo Dictionary]: #the-userinfo-dictionary
[JSON Columns]: #json-columns
[FetchableRecord]: #fetchablerecord-protocol
[EncodableRecord]: #persistablerecord-protocol
[PersistableRecord]: #persistablerecord-protocol
[Record Comparison]: #record-comparison
[Record Customization Options]: #record-customization-options
[Persistence Callbacks]: #persistence-callbacks
[persistence callbacks]: #persistence-callbacks
[Record Timestamps and Transaction Date]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/recordtimestamps
[TableRecord]: #tablerecord-protocol
[ValueObservation]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/valueobservation
[DatabaseRegionObservation]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseregionobservation
[RxGRDB]: https://github.com/RxSwiftCommunity/RxGRDB
[DatabaseRegion]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseregion
[SQL Interpolation]: Documentation/SQLInterpolation.md
[custom SQLite build]: Documentation/CustomSQLiteBuilds.md
[Combine]: https://developer.apple.com/documentation/combine
[Combine Support]: Documentation/Combine.md
[Concurrency]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/concurrency
[Demo Applications]: Documentation/DemoApps
[Sharing a Database]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasesharing
[FAQ]: #faq
[Database Observation]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseobservation
[SQLRequest]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/sqlrequest
[SQL literal]: Documentation/SQLInterpolation.md#sql-literal
[Identifiable]: https://developer.apple.com/documentation/swift/identifiable
[Query Interface Organization]: Documentation/QueryInterfaceOrganization.md
[Database Configuration]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/configuration
[Persistence Methods]: #persistence-methods
[persistence methods]: #persistence-methods
[Persistence Methods and the `RETURNING` clause]: #persistence-methods-and-the-returning-clause
[RecordError]: #recorderror
[Transactions and Savepoints]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/transactions
[`DatabaseQueue`]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasequeue
[Database queues]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasequeue
[`DatabasePool`]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasepool
[database pools]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasepool
[`DatabaseValueConvertible`]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasevalueconvertible
[`StatementArguments`]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/statementarguments
[Prepared Statements]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/statement
[prepared statements]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/statement
[`Statement`]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/statement
[Database Connections]: #database-connections
[Database connections]: #database-connections
[database connection]: #database-connections
