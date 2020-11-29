Migrating From GRDB 4 to GRDB 5
===============================

**This guide aims at helping you upgrading your applications from GRDB 4 to GRDB 5.**

- [Preparing the Migration to GRDB 5](#preparing-the-migration-to-grdb-5)
- [New requirements](#new-requirements)
- [Database Configuration](#database-configuration)
- [ValueObservation](#valueobservation)
- [Combine Integration](#combine-integration)
- [Other Changes](#other-changes)


## Preparing the Migration to GRDB 5

If you haven't made it yet, upgrade to the [latest GRDB 4 release](https://github.com/groue/GRDB.swift/tags) first, and fix any deprecation warning prior to the GRDB 5 upgrade.

GRDB 5 ships with fix-its that will suggest simple syntactic changes, and won't require you to think much.

Your attention will be needed, though, in the area of database observation.


## New requirements

GRDB requirements have been bumped:

- **Swift 5.2+** (was Swift 4.2+)
- **Xcode 11.4+** (was Xcode 10.0+)
- **iOS 10.0+** (was iOS 9.0+)
- **macOS 10.10+** (was macOS 10.9+)
- tvOS 9.0+ (unchanged)
- watchOS 2.0+ (unchanged)


## Database Configuration

The way to configure a database relies much more on the `Configuration.prepareDatabase(_:)` method:

```swift
// BEFORE: GRDB 4
var config = Configuration()
config.trace = { ... }              // Tracing SQL statements
config.prepareDatabase = { db in    // prepareDatabase was a property
    ...                             // Custom setup
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
dbQueue.add(function: ...)          // Custom SQL function
dbQueue.add(collation: ...)         // Custom collation
dbQueue.add(tokenizer: ...)         // Custom FTS5 tokenizer

// NEW: GRDB 5
var config = Configuration()
config.prepareDatabase { db in      // prepareDatabase is now a method
    db.trace { ... }
    db.add(function: ...)
    db.add(collation: ...)
    db.add(tokenizer: ...)
    ...
}
let dbQueue = try DatabaseQueue(dbPath, configuration: config)
```


## ValueObservation

[ValueObservation] is the database observation tool that tracks changes in database values. It has quite changed in GRDB 5.

Those changes have the vanilla GRDB, its [Combine publishers], and [RxGRDB] offer a common API, and a common behavior. This greatly helps choosing or switching your preferred database observation technique. In previous versions of GRDB, the three companion libraries used to have subtle differences that were just opportunities for bugs.

In the end, this migration step might require some work. But it's for the benefit of all!

- [Creating ValueObservation](#creating-valueobservation)
- [Starting ValueObservation](#starting-valueobservation)
- [Runtime Behavior of ValueObservation](#runtime-behavior-of-valueobservation)
- [Removed ValueObservation Methods](#removed-valueobservation-methods)

### Creating ValueObservation

In GRDB 5, you *always* create a ValueObservation by providing a function that fetches the observed value:

```swift
// GRDB 5
let observation = ValueObservation.tracking { db in
    /* fetch and return the observed value */
}

// For example, an observation of [Player], which tracks all players:
let observation = ValueObservation.tracking { db in
    try Player.fetchAll(db)
}

// The same observation, using shorthand notation:
let observation = ValueObservation.tracking(Player.fetchAll)
```

Several methods that build observations were removed:

```swift
// BEFORE: GRDB 4
let observation = request.observationForCount()
let observation = request.observationForFirst()
let observation = request.observationForAll()
let observation = ValueObservation.tracking(value: someFetchFunction)
let observation = ValueObservation.tracking(..., fetch: { db in ... })

// NEW: GRDB 5
let observation = ValueObservation.tracking(request.fetchCount)
let observation = ValueObservation.tracking(request.fetchOne)
let observation = ValueObservation.tracking(request.fetchAll)
let observation = ValueObservation.tracking(someFetchFunction)
let observation = ValueObservation.tracking { db in ... }
```

Finally, ValueObservation used to let application define custom "reducers" based on a protocol name ValueReducer, which was removed in GRDB 5. See the [#731](https://github.com/groue/GRDB.swift/pull/731) conversation for a solution towards a replacement.

<details>
    <summary>RxGRDB impact</summary>

```swift
// BEFORE: GRDB 4
request.rx.observeCount(in: dbQueue)
request.rx.observeFirst(in: dbQueue)
request.rx.observeAll(in: dbQueue)

// NEW: GRDB 5
ValueObservation.tracking(request.fetchCount).rx.observe(in: dbQueue)
ValueObservation.tracking(request.fetchOne).rx.observe(in: dbQueue)
ValueObservation.tracking(request.fetchAll).rx.observe(in: dbQueue)
```

</details>


### Starting ValueObservation

The `start` method which starts observing the database has changed as well.

```swift
// Start observing the database
let cancellable = observation.start(
    in: dbQueue,
    onError: { error in ... },
    onChange: { value in print("fresh value: \(value)") })
```

1. The result of the `start` method is now a DatabaseCancellable which allows you to explicitly stop an observation:
    
    ```swift
    // BEFORE: GRDB 4
    let observer: TransactionObserver?
    observer = observation.start(...)
    observer = nil       // Stop the observation
    
    // NEW: GRDB 5
    let cancellable: DatabaseCancellable
    cancellable = observation.start(...)
    cancellable.cancel() // Stop the observation
    ```
    
    The returned DatabaseCancellable cancels itself when it gets deinitialized.

2. The `onError` handler of the `start` method is now mandatory:
    
    ```swift
    // BEFORE: GRDB 4
    do {
        try observation.start(in: dbQueue) { value in
            print("fresh value: \(value)")
        }
    } catch { ... }

    // NEW: GRDB 5
    observation.start(
        in: dbQueue,
        onError: { error in ... },
        onChange: { value in print("fresh value: \(value)") })
    ```


### Runtime Behavior of ValueObservation

**The behavior of ValueObservation has changed**.

The changes can quite impact your application. We'll describe them below, as well as the strategies to restore the previous behavior when needed.

1. ValueObservation used to notify its initial value *immediately* when the observation starts. Now, it notifies fresh values on the main thread, *asynchronously*, by default.
    
    This means that the parts of your application that rely on this immediate value to, say, set up their user interface, have to be modified. Otherwise, they may suffer from a brief flash of missing data, during the short amount of time between the beginning of the observation, and the asynchronous delivery of the initial value.
    
    To be granted with an immediate, synchronous, delivery of the initial value, insert a `scheduling: .immediate` argument in the `start` method:
    
    ```swift
    let observation = ValueObservation.tracking(Player.fetchAll)
    let cancellable = observation.start(
        in: dbQueue,
        // Opt in for immediate notification of the initial value
        scheduling: .immediate,
        onError: { error in ... },
        onChange: { [weak self] (players: [Player]) in
            guard let self = self else { return }
            self.updateView(players)
        })
    // <- Here the view has already been updated.
    ```
    
    Note that the `.immediate` scheduling requires that the observation starts from the main thread. A fatal error is raised otherwise.
    
    <details>
        <summary>Combine impact</summary>
    
    ```swift
    let observation = ValueObservation.tracking(Player.fetchAll)
    let cancellable = observation
        .publisher(
            in: dbQueue, 
            // Opt in for immediate notification of the initial value
            scheduling: .immediate)
        .sink(...)
    ```
    
    </details>
    
    <details>
        <summary>RxGRDB impact</summary>
    
    ```swift
    let observation = ValueObservation.tracking(Player.fetchAll)
    let disposable = observation
        .rx.observe(
            in: dbQueue, 
            // Opt in for immediate notification of the initial value
            scheduling: .immediate)
        .subscribe(...)
    ```
    
    </details>

2. ValueObservation used to notify one fresh value for each and every database transaction that had an impact on the tracked value. Now, it may coalesce notifications. If your application relies on exactly one notification per transaction, use [DatabaseRegionObservation] instead.

3. Some value observations used to automatically remove duplicate values. This is no longer automatic. If your application relies on distinct consecutive values, use the [removeDuplicates] operator.

4. ValueObservation used to prevent a database connection (DatabaseQueue or DatabasePool) from closing. Now an observation just stops emitting any fresh value when the database connection closes.

5. ValueObservation used to be able to restart notifying fresh values after it has notified an error. Now an error marks the end of the observation.

6. ValueObservation used to have a `scheduling` property, which has been removed.
    
    You can remove the explicit request to dispatch fresh values asynchronously on the main dispatch queue, because it is now the default behavior:
    
    ```swift
    // BEFORE: GRDB 4
    var observation = ValueObservation.tracking(...)
    observation.scheduling = .async(onQueue: .main, startImmediately: true)
    observation.start(in: dbQueue, onError: ..., onChange: ...)

    // NEW: GRDB 5
    let observation = ValueObservation.tracking(...)
    observation.start(in: dbQueue, onError: ..., onChange: ...)
    ```
    
    For other dispatch queues, use the `scheduling` parameter of the `start` method:
    
    ```swift
    let queue: DispatchQueue = ...
    
    // BEFORE: GRDB 4
    var observation = ValueObservation.tracking(...)
    observation.scheduling = .async(onQueue: queue, startImmediately: true)
    observation.start(in: dbQueue, onError: ..., onChange: ...)
    
    // NEW: GRDB 5
    let observation = ValueObservation.tracking(...)
    observation.start(in: dbQueue, scheduling: .async(onQueue: queue), onError: ..., onChange: ...)
    ```
    
    The GRDB 4 `startImmediately` parameter is no longer supported: ValueObservation now always emits an initial value, without waiting for eventual changes. It is up to your application to ignore this initial value if it wants to.


### Removed ValueObservation Methods

1. ValueObservation used to have a `compactMap` method. This method has been removed without any replacement.
    
    If your application uses Combine publishers or RxGRDB, then use the `compactMap` method from Combine or RxSwift instead.

2. ValueObservation used to have a `combine` method. This method has been removed without any replacement.
    
    In your application, replace combined observations with a single observation:
    
    ```swift
    struct HallOfFame {
        var totalPlayerCount: Int
        var bestPlayers: [Player]
    }
    
    // BEFORE: GRDB 4
    let totalPlayerCountObservation = ValueObservation.tracking(Player.fetchCount)
    
    let bestPlayersObservation = ValueObservation.tracking(Player
            .limit(10)
            .order(Column("score").desc)
            .fetchAll)
    
    let observation = ValueObservation
        .combine(totalPlayerCountObservation, bestPlayersObservation)
        .map(HallOfFame.init)
    
    // NEW: GRDB 5
    let observation = ValueObservation.tracking { db -> HallOfFame in
        let totalPlayerCount = try Player.fetchCount(db)
        
        let bestPlayers = try Player
            .order(Column("score").desc)
            .limit(10)
            .fetchAll(db)
        
        return HallOfFame(
            totalPlayerCount: totalPlayerCount,
            bestPlayers: bestPlayers)
    }
    ```
    
    As is previous versions of GRDB, do not use the `combineLatest` operators of Combine or RxSwift in order to combine several ValueObservation. You would lose all guarantees of [data consistency](https://en.wikipedia.org/wiki/Consistency_(database_systems)).


## Combine Integration

GRDB 4 had a companion library named GRDBCombine. Combine support is now embedded right into GRDB 5, and you have to remove any dependency on GRDBCombine.

GRDBCombine used to define a `fetchOnSubscription()` method of the ValueObservation subscriber. It has been removed. Replace it with `scheduling: .immediate` for the same effect (an initial value is notified immediately, synchronously, when the publisher is subscribed):
    
```swift
// BEFORE: GRDB 4 + GRDBCombine
let observation = ValueObservation.tracking { db in ... }
let publisher = observation
    .publisher(in: dbQueue)
    .fetchOnSubscription()

// NEW: GRDB 5
let observation = ValueObservation.tracking { db in ... }
let publisher = observation
    .publisher(in: dbQueue, scheduling: .immediate)
```


## Other Changes

1. The `Configuration.trace` property has been removed. You know use the `Database.trace(options:_:)` method instead:

    ```swift
    // BEFORE: GRDB 4
    var config = Configuration()
    config.trace = { print($0) }
    let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
     
    // NEW: GRDB 5
    var config = Configuration()
    config.prepareDatabase { db in
        db.trace { print($0) }
    }
    let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
    ```

2. [Batch updates] used to rely of the `<-` operator. This operator has been removed. Use the `set(to:)` method instead:
    
    ```swift
    // BEFORE: GRDB 4
    try Player.updateAll(db, Column("score") <- 0)
     
    // NEW: GRDB 5
    try Player.updateAll(db, Column("score").set(to: 0))
    ```
    
    > :question: This change avoids conflicts with other libraries that define the same operator.

3. [SQL Interpolation] does no longer wrap subqueries in parenthesis:
    
    ```swift
    // BEFORE: GRDB 4
    let maximumScore: SQLRequest<Int> = "SELECT MAX(score) FROM player"
    let bestPlayers: SQLRequest<Player> = "SELECT * FROM player WHERE score = \(maximumScore)"
     
    // NEW: GRDB 5
    let maximumScore: SQLRequest<Int> = "SELECT MAX(score) FROM player"
    let bestPlayers: SQLRequest<Player> = "SELECT * FROM player WHERE score = (\(maximumScore))"
    //                                            extra parenthesis required: ^               ^
    ```
    
    > :question: This change makes it possible to concatenate subqueries with the UNION operator.

4. In order to extract raw SQL string from an [SQLLiteral], you now need a database connection:

    ```swift
    let query: SQLLiteral = "UPDATE player SET name = \(name) WHERE id = \(id)"
    
    // BEFORE: GRDB 4
    print(query.sql)       // prints "UPDATE player SET name = ? WHERE id = ?"
    print(query.arguments) // prints ["O'Brien", 42]
     
    // NEW: GRDB 5
    let (sql, arguments) = try dbQueue.read(query.build)
    print(sql)             // prints "UPDATE player SET name = ? WHERE id = ?"
    print(arguments)       // prints ["O'Brien", 42]
    ```

5. In order to extract raw SQL string from a request ([SQLRequest] or [QueryInterfaceRequest]), you now need to call the `makePreparedRequest()` method:

    ```swift
    // BEFORE: GRDB 4
    try dbQueue.read { db in
        let request = Player.filter(Column("name") == "O'Brien")
        let sqlRequest = try SQLRequest(db, request: request)
        print(sqlRequest.sql)       // "SELECT * FROM player WHERE name = ?"
        print(sqlRequest.arguments) // ["O'Brien"]
    }
     
    // NEW: GRDB 5
    try dbQueue.read { db in
        let request = Player.filter(Column("name") == "O'Brien")
        let statement = try request.makePreparedRequest(db, forSingleResult: false).statement
        print(statement.sql)        // "SELECT * FROM player WHERE name = ?"
        print(statement.arguments)  // ["O'Brien"]
    }
    ```

6. The `TableRecord.selectionSQL()` method is no longer avaible. When you need to embed the columns selected by a record type in an SQL request, you now have to use [SQL Interpolation]:

    ```swift
    // BEFORE: GRDB 4
    let sql = "SELECT \(Player.selectionSQL()) FROM player"
    let players = try Player.fetchAll(db, sql: sql)
     
    // NEW: GRDB 5
    let request: SQLRequest<Player> = "SELECT \(columnsOf: Player.self) FROM player"
    let players = try request.fetchAll(db)
    ```

7. [Custom SQL functions] are now [callable values](https://github.com/apple/swift-evolution/blob/master/proposals/0253-callable.md):
    
    ```swift
    // BEFORE: GRDB 4
    Player.select(myFunction.call(Column("name")))
     
    // NEW: GRDB 5
    Player.select(myFunction(Column("name")))
    ```

8. Defining custom `FetchRequest` types is no longer supported.
    
    Refactor your app around [SQLRequest] and [QueryInterfaceRequest], which are supposed to fully address your needs.
    
9. The module name for [custom SQLite builds](CustomSQLiteBuilds.md) is now the plain `GRDB`:
    
    ```swift
    // BEFORE: GRDB 4
    import GRDBCustomSQLite
     
    // NEW: GRDB 5
    import GRDB
    ```

10. Importing the `GRDB` module grants access to the [SQLite C interface](https://www.sqlite.org/c3ref/intro.html). You don't need any longer to import the underlying SQLite library:
    
    ```swift
    // BEFORE: GRDB 4
    import CSQLite   // When GRDB is included with the Swift Package Manager
    import SQLCipher // When GRDB is linked to SQLCipher
    import SQLite3   // When GRDB is linked to System SQLite
    let sqliteVersion = String(cString: sqlite3_libversion())

    // NEW: GRDB 5
    import GRDB
    let sqliteVersion = String(cString: sqlite3_libversion())
    ```

11. `FetchedRecordsController` was removed from GRDB 5. The [Database Observation] chapter describes the other ways to observe the database.

12. Defining custom `RowAdapter` types is no longer supported. A new [RenameColumnAdapter](../README.md#renamecolumnadapter) adapter makes it possible to process column names.

13. Many types and methods that support the query builder used to be publicly exposed and flagged as experimental. They are now private, or renamed with an underscore prefix, which means they are not for public use.

14. Explicit boolean tests `expression == true` and `expression == false` generate different SQL:
    
    ```swift
    // GRDB 4: SELECT * FROM player WHERE isActive
    // GRDB 5: SELECT * FROM player WHERE isActive = 1
    Player.filter(Column("isActive") == true)

    // GRDB 4: SELECT * FROM player WHERE NOT isActive
    // GRDB 5: SELECT * FROM player WHERE isActive = 0
    Player.filter(Column("isActive") == false)

    // GRDB 4 & 5: SELECT * FROM player WHERE isActive
    Player.filter(Column("isActive"))

    // GRDB 4 & 5: SELECT * FROM player WHERE NOT isActive
    Player.filter(!Column("isActive"))
    ```
    
    This change is innocuous for database boolean values that are `0`, `1`, or `NULL`. However, it is a breaking change for all other database values.


[ValueObservation]: ../README.md#valueobservation
[DatabaseRegionObservation]: ../README.md#databaseregionobservation
[RxGRDB]: http://github.com/RxSwiftCommunity/RxGRDB
[removeDuplicates]: ../README.md#valueobservationremoveduplicates
[Custom SQL functions]: ../README.md#custom-sql-functions
[Batch updates]: ../README.md#update-requests
[SQL Interpolation]: SQLInterpolation.md
[SQLLiteral]: SQLInterpolation.md#sqlliteral
[SQLRequest]: ../README.md#custom-requests
[QueryInterfaceRequest]: ../README.md#requests
[Combine publishers]: Combine.md
[Database Observation]: ../README.md#database-changes-observation
