# ``GRDB/ValueObservation``

`ValueObservation` tracks changes in the results of database requests, and notifies fresh values whenever the database changes.

## Overview

`ValueObservation` tracks insertions, updates, and deletions that impact the tracked value, whether performed with raw SQL, or <doc:QueryInterface>. This includes indirect changes triggered by [foreign keys actions](https://www.sqlite.org/foreignkeys.html#fk_actions) or [SQL triggers](https://www.sqlite.org/lang_createtrigger.html).

See <doc:GRDB/ValueObservation#Dealing-with-Undetected-Changes> below for the list of exceptions.

## ValueObservation Usage

1. Make sure that a unique database connection, ``DatabaseQueue`` or ``DatabasePool``, is kept open during the whole duration of the observation.

2. Create a `ValueObservation` with a closure that fetches the observed value:

    ```swift
    let observation = ValueObservation.tracking { db in
        // Fetch and return the observed value
    }

    // For example, an observation of [Player], which tracks all players:
    let observation = ValueObservation.tracking { db in
        try Player.fetchAll(db)
    }

    // The same observation, using shorthand notation:
    let observation = ValueObservation.tracking(Player.fetchAll)
    ```

    There is no limit on the values that can be observed. An observation can perform multiple requests, from multiple database tables, and use raw SQL. See ``tracking(_:)`` for some examples.

3. Start the observation in order to be notified of changes:

    ```swift
    let cancellable = observation.start(in: dbQueue) { error in
        // Handle error
    } onChange: { (players: [Player]) in
        print("Fresh players", players)
    }
    ```

4. Stop the observation by calling the ``DatabaseCancellable/cancel()`` method on the object returned by the `start` method. Cancellation is automatic when the cancellable is deallocated:

    ```swift
    cancellable.cancel()
    ```

`ValueObservation` can also be turned into an async sequence, a Combine publisher, or an RxSwift observable (see the companion library [RxGRDB](https://github.com/RxSwiftCommunity/RxGRDB)):

- Async sequence:

    ```swift
    do {
        for try await players in observation.values(in: dbQueue) {
            print("Fresh players", players)
        }
    } catch {
        // Handle error
    }
    ```

- Combine Publisher:

    ```swift
    let cancellable = observation.publisher(in: dbQueue).sink { completion in
        // Handle completion
    } receiveValue: { (players: [Player]) in
        print("Fresh players", players)
    }
    ```

## ValueObservation Behavior

`ValueObservation` notifies an initial value before the eventual changes.

`ValueObservation` only notifies changes committed to disk.

By default, `ValueObservation` notifies a fresh value whenever any component of its fetched value is modified (any fetched column, row, etc.). This can be configured: see <doc:ValueObservation#Specifying-the-Tracked-Region>.

By default, `ValueObservation` notifies the initial value, as well as eventual changes and errors, on the main dispatch queue, asynchronously. This can be configured: see <doc:ValueObservation#ValueObservation-Scheduling>.

`ValueObservation` may coalesce subsequent changes into a single notification.

`ValueObservation` may notify consecutive identical values. You can filter out the undesired duplicates with the ``removeDuplicates()`` method.

Starting an observation retains the database connection, until it is stopped. As long as the observation is active, the database connection won't be deallocated.

The database observation stops when the cancellable returned by the `start` method is cancelled or deallocated, or if an error occurs.

> Important: Take care that there are use cases that `ValueObservation` is unfit for.
>
> For example, an application may need to process absolutely all changes, and avoid any coalescing. An application may also need to process changes before any further modifications could be performed in the database file. In those cases, the application needs to track *individual transactions*, not values: use ``DatabaseRegionObservation``.
>
> If you need to process changes before they are committed to disk, use ``TransactionObserver``.

## ValueObservation Scheduling

By default, `ValueObservation` notifies the initial value, as well as eventual changes and errors, on the main dispatch queue, asynchronously:

```swift
// The default scheduling
let cancellable = observation.start(in: dbQueue) { error in
    // Called asynchronously on the main dispatch queue
} onChange: { value in
    // Called asynchronously on the main dispatch queue
    print("Fresh value", value)
}
```

You can change this behavior by adding a `scheduling` argument to the `start()` method.

For example, the ``ValueObservationScheduler/immediate`` scheduler notifies all values on the main dispatch queue, and notifies the first one immediately when the observation starts.

It is very useful in graphic applications, because you can configure views right away, without waiting for the initial value to be fetched eventually. You don't have to implement any empty or loading screen, or to prevent some undesired initial animation. Take care that the user interface is not responsive during the fetch of the first value, so only use the `immediate` scheduling for very fast database requests!

The `immediate` scheduling requires that the observation starts from the main dispatch queue (a fatal error is raised otherwise):

```swift
let cancellable = observation.start(in: dbQueue, scheduling: .immediate) { error in
    // Called on the main dispatch queue
} onChange: { value in
    // Called on the main dispatch queue
    print("Fresh value", value)
}
// <- Here "Fresh value" has already been printed.
```

The other built-in scheduler ``ValueObservationScheduler/async(onQueue:)`` asynchronously schedules values and errors on the dispatch queue of your choice.

## ValueObservation Sharing

Sharing a `ValueObservation` spares database resources. When a database change happens, a fresh value is fetched only once, and then notified to all clients of the shared observation.

You build a shared observation with ``shared(in:scheduling:extent:)``:

```swift
// SharedValueObservation<[Player]>
let sharedObservation = ValueObservation
    .tracking { db in try Player.fetchAll(db) }
    .shared(in: dbQueue)
```

`ValueObservation` and `SharedValueObservation` are nearly identical, but the latter has no operator such as `map`. As a replacement, you may for example use Combine apis:

```swift
let cancellable = try sharedObservation
    .publisher() // Turn shared observation into a Combine Publisher
    .map { ... } // The map operator from Combine
    .sink(...)
```


## Specifying the Tracked Region

While the standard ``tracking(_:)`` method lets you track changes to a fetched value and receive any changes to it, sometimes your use case might require more granular control.

Consider a scenario where you'd like to get a specific Player's row, but only when their `score` column changes. You can use ``tracking(region:_:fetch:)`` to do just that:

```swift
let observation = ValueObservation.tracking(
    // Define the tracked database region
    // (the score column of the player with id 1)
    region: Player.select(Column("score")).filter(id: 1),
    // Define what to fetch upon such change to the tracked region
    // (the player with id 1)
    fetch: { db in try Player.fetchOne(db, id: 1) }
)
```

This ``tracking(region:_:fetch:)`` method lets you entirely separate the **observed region(s)** from the **fetched value** itself, for maximum flexibility. See ``DatabaseRegionConvertible`` for more information about the regions that can be tracked.

## Dealing with Undetected Changes

`ValueObservation` will not fetch and notify a fresh value whenever the database is modified in an undetectable way:

- Changes performed by external database connections.
- Changes performed by SQLite statements that are not compiled and executed by GRDB.
- Changes to the database schema, changes to internal system tables such as `sqlite_master`.
- Changes to [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) tables.

To have observations notify a fresh values after such an undetected change was performed, applications can take explicit action. For example, cancel and restart observations. Alternatively, call the ``Database/notifyChanges(in:)`` `Database` method from a write transaction:
    
```swift
try dbQueue.write { db in
    // Notify observations that some changes were performed in the database
    try db.notifyChanges(in: .fullDatabase)

    // Notify observations that some changes were performed in the player table
    try db.notifyChanges(in: Player.all())

    // Equivalent alternative
    try db.notifyChanges(in: Table("player"))
}
```

## ValueObservation Performance

This section further describes runtime aspects of `ValueObservation`, and provides some optimization tips for demanding applications.

**`ValueObservation` is triggered by database transactions that may modify the tracked value.**

Precisely speaking, `ValueObservation` tracks changes in a ``DatabaseRegion``, not changes in values.

For example, if you track the maximum score of players, all transactions that impact the `score` column of the `player` database table (any update, insertion, or deletion) trigger the observation, even if the maximum score itself is not changed.

You can filter out undesired duplicate notifications with the ``removeDuplicates()`` method.

**ValueObservation can create database contention.** In other words, active observations take a toll on the constrained database resources. When triggered by impactful transactions, observations fetch fresh values, and can delay read and write database accesses of other application components.

When needed, you can help GRDB optimize observations and reduce database contention:

> Tip: Stop observations when possible.
>
> For example, if a `UIViewController` needs to display database values, it can start the observation in `viewWillAppear`, and stop it in `viewWillDisappear`.
>
> In a SwiftUI application, you can profit from the [GRDBQuery](https://github.com/groue/GRDBQuery) companion library, and its [`View.queryObservation(_:)`](https://swiftpackageindex.com/groue/grdbquery/documentation/grdbquery/queryobservation) method.

> Tip: Share observations when possible.
>
> Each call to `ValueObservation.start` method triggers independent values refreshes. When several components of your app are interested in the same value, consider sharing the observation with ``shared(in:scheduling:extent:)``.

> Tip: When the observation processes some raw fetched values, use the ``map(_:)`` operator:
>
> ```swift
> // Plain observation
> let observation = ValueObservation.tracking { db -> MyValue in
>     let players = try Player.fetchAll(db)
>     return computeMyValue(players)
> }
>
> // Optimized observation
> let observation = ValueObservation
>     .tracking { db try Player.fetchAll(db) }
>     .map { players in computeMyValue(players) }
> ```
>
> The `map` operator performs its job without blocking database accesses, and without blocking the main thread.

> Tip: When the observation tracks a constant database region, create an optimized observation with the ``trackingConstantRegion(_:)`` method. See the documentation of this method for more information about what constitutes a "constant region", and the nature of the optimization.

**Truncating WAL checkpoints impact ValueObservation.** Such checkpoints are performed with ``Database/checkpoint(_:on:)`` or [`PRAGMA wal_checkpoint`](https://www.sqlite.org/pragma.html#pragma_wal_checkpoint). When an observation is started on a ``DatabasePool``, from a database that has a missing or empty [wal file](https://www.sqlite.org/tempfiles.html#write_ahead_log_wal_files), the observation will always notify two values when it starts, even if the database content is not changed. This is a consequence of the impossibility to create the [wal snapshot](https://www.sqlite.org/c3ref/snapshot_get.html) needed for detecting that no changes were performed during the observation startup. If your application performs truncating checkpoints, you will avoid this behavior if you recreate a non-empty wal file before starting observations. To do so, perform any kind of no-op transaction (such a creating and dropping a dummy table).


## Topics

### Creating a ValueObservation

- ``tracking(_:)``
- ``trackingConstantRegion(_:)``
- ``tracking(region:_:fetch:)``
- ``tracking(regions:fetch:)``

### Creating a Shared Observation

- ``shared(in:scheduling:extent:)``
- ``SharedValueObservationExtent``

### Accessing Observed Values

- ``publisher(in:scheduling:)``
- ``start(in:scheduling:onError:onChange:)``
- ``values(in:scheduling:bufferingPolicy:)``
- ``DatabaseCancellable``
- ``ValueObservationScheduler``

### Mapping Values

- ``map(_:)``

### Filtering Values

- ``removeDuplicates()``
- ``removeDuplicates(by:)``

### Requiring Write Access

- ``requiresWriteAccess``

### Debugging

- ``handleEvents(willStart:willFetch:willTrackRegion:databaseDidChange:didReceiveValue:didFail:didCancel:)``
- ``print(_:to:)``

### Support

- ``ValueReducer``
