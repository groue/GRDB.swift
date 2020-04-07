Migrating From GRDB 4 to GRDB 5
===============================

**GRDB 5 comes with less features than GRDB 4!** This is just the sign that your favorite Swift SQLite library is more fitted than ever for your GUI applications, and that is will be easier to maintain in the future.

This guide aims at helping you upgrading your applications.

- [Preparing the Migration to GRDB 5](#preparing-the-migration-to-grdb-5)
- [New requirements](#new-requirements)
- [ValueObservation](#valueobservation)
- [Other Changes](#other-changes)


## Preparing the Migration to GRDB 5

GRDB 5 ships with fix-its that will help your migration from 4.12.1.

If you haven't made it yet, upgrade to GRDB 4.12.1 first, and fix all deprecation warnings, prior to the GRDB 5 upgrade.


## New requirements

GRDB requirements have been bumped:

- **Swift 5.2+** (was Swift 4.2+)
- **Xcode 11.4+** (was Xcode 10.0+)
- iOS 9.0+ (unchanged)
- macOS 10.10+ (was macOS 10.9+)
- tvOS 9.0+ (unchanged)
- watchOS 2.0+ (unchanged)


## ValueObservation

[ValueObservation] is the database observation tool that tracks changes in database values. It has quite changed in GRDB 5.

**The API surface of ValueObservation was reduced**, leaving only two core methods:

```swift
// Define an observation
let observation = ValueObservation.tracking { db in
    /* fetch observed value */
}

// Start the observation
let cancellable = observation.start(
    in: dbQueue,
    onError: { error in ... },
    onChange: { value in print("fresh value: \(value)") })
```

If the tracked value is computed from several database requests that are not always the same, make sure you use the `trackingVaryingRegion` method, as below. See [Observing a Varying Database Region] for more information.

```swift
// An observation which does not always execute the same requests:
let observation = ValueObservation.trackingVaryingRegion { db -> Int in
    switch try Preference.fetchOne(db)!.selection {
        case .food: return try Food.fetchCount(db)
        case .beverage: return try Beverage.fetchCount(db)
    }
}
```

The `onError` handler of the `start` method is now mandatory:

```diff
-do {
-    try observation.start(in: dbQueue) { value in
-        print("fresh value: \(value)")
-    }
-} catch { ... }
+observation.start(
+    in: dbQueue,
+    onError: { error in ... },
+    onChange: { value in print("fresh value: \(value)") })
```

The result of the `start` method is now a DatabaseCancellable which allows you to explicitly stop an observation:

```diff
-let observer: TransactionObserver
-observer = observation.start(...)
+let cancellable: DatabaseCancellable
+cancellable = observation.start(...)
```

Some convenience ways to build observations were removed:

```diff
-let observation = request.observationForCount()
-let observation = request.observationForFirst()
-let observation = request.observationForAll()
-let observation = ValueObservation.tracking(request, fetch: { db in ... })
+let observation = ValueObservation.tracking(request.fetchCount)
+let observation = ValueObservation.tracking(request.fetchOne)
+let observation = ValueObservation.tracking(request.fetchAll)
+let observation = ValueObservation.tracking { db in ... }
```

<details>
    <summary>RxGRDB impact</summary>

```diff
-request.rx.observeCount(in: dbQueue)
-request.rx.observeFirst(in: dbQueue)
-request.rx.observeAll(in: dbQueue)
+ValueObservation.tracking(request.fetchCount).rx.observe(in: dbQueue)
+ValueObservation.tracking(request.fetchOne).rx.observe(in: dbQueue)
+ValueObservation.tracking(request.fetchAll).rx.observe(in: dbQueue)
```

</details>

**The behavior of ValueObservation has changed**.

Those changes have been applied identically to [GRDBCombine] and [RxGRDB], so that you are granted with an identical behavior, regardless of the technique you use to observe the database (vanilla GRDB, Combine, or RxSwift).

1. ValueObservation used to notify its initial value *immediately* when the observation starts. Now, it notifies fresh values on the main thread, *asynchronously*, by default.
    
    This means that parts of your application that rely on this immediate value to, say, setup their user interface, have to be modified. Insert a `scheduling: .immediate` argument in the `start` method:
    
    ```diff
     let observation = ValueObservation.tracking(Player.fetchAll)
     let cancellable = observation.start(
         in: dbQueue,
    +    // Opt in for immediate notification of the initial value
    +    scheduling: .immediate,
         onError: { error in ... },
         onChange: { [weak self] (players: [Player]) in
             guard let self = self else { return }
             self.updateView(players)
         })
     // <- Here the view has already been updated.
    ```
    
    <details>
        <summary>GRDBCombine impact</summary>
    
    ```diff
     let observation = ValueObservation.tracking(Player.fetchAll)
     let cancellable = observation
         .publisher(in: dbQueue)
    +    // Opt in for immediate notification of the initial value
    +    .scheduling(.immediate)
         .sink(...)
    ```
    
    </details>
    
    <details>
        <summary>RxGRDB impact</summary>
    
    ```diff
     let observation = ValueObservation.tracking(Player.fetchAll)
     let disposable = observation
         .rx.observe(in: dbQueue)
    +    // Opt in for immediate notification of the initial value
    +    .scheduling(.immediate)
         .subscribe(...)
    ```
    
    </details>

2. ValueObservation used to notify one fresh value for each and every database transaction that had an impact on the tracked value. Now, it may coalesce notifications. It your application relies on exactly one notification per transaction, use [DatabaseRegionObservation] instead.

3. Some value observations used to automatically remove duplicate values. This is no longer automatic. If your application relies on distinct consecutive values, use the [removeDuplicates] operator.

4. ValueObservation used to have a `compactMap` method. This method has been removed without any replacement.

5. ValueObservation used to let application define custom "reducers" using the ValueReducer protocol. These apis are no longer available. See the [#731](https://github.com/groue/GRDB.swift/pull/731) conversation for a solution towards a replacement.


## Other Changes

1. The `QueryInterfaceRequest` has been renamed to `Request`.

2. If you happen to implement custom fetch requests with the `FetchRequest` protocol, you now have to define the `makePreparedRequest(_:forSingleResult:)` method:
    
    ```diff
     struct MyRequest: FetchRequest {
    -    func prepare(_ db: Database, forSingleResult singleResult: Bool) throws -> (SelectStatement, RowAdapter?) {
    -        let statement: SelectStatement = ...
    -        let adapter: RowAdapter? = ...
    -        return (statement, adapter)
    -    }
    +    func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest
    +        let statement: SelectStatement = ...
    +        let adapter: RowAdapter? = ...
    +        return PreparedRequest(statement: statement, adapter: adapter)
    +    }
     }
    ```

3. [Custom SQL functions] are now [callable values](https://github.com/apple/swift-evolution/blob/master/proposals/0253-callable.md):
    
    ```diff
    -Player.select(myFunction.call(Column("name")))
    +Player.select(myFunction(Column("name")))
    ```


[ValueObservation]: ../README.md#valueobservation
[DatabaseRegionObservation]: ../README.md#databaseregionobservation
[RxGRDB]: http://github.com/RxSwiftCommunity/RxGRDB
[GRDBCombine]: http://github.com/groue/GRDBCombine
[Observing a Varying Database Region]: ../README.md#observing-a-varying-database-region
[removeDuplicates]: ../README.md#valueobservationremoveduplicates
[Custom SQL functions]: ../README.md#custom-sql-functions
