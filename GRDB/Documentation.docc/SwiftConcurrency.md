# Swift Concurrency and GRDB

How to best integrate GRDB and Swift Concurrency 

## Overview

GRDB’s primary goal is to leverage SQLite’s concurrency features for the benefit of application developers. Swift 6 makes it possible to achieve this goal while ensuring data-race safety.

For example, the ``DatabasePool`` connection allows applications to fetch and display database values on screen, even while a background task is writing the results of a network request to disk.

Application previews and tests prefer to use an in-memory ``DatabaseQueue`` connection.

Both connection types provide the same database access methods:

```swift
// Read
let playerCount = try await writer.read { db in
    try Player.fetchCount(db)
}

// Write
let newPlayerCount = try await writer.write { db in
    try Player(name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}

// Observe database changes
let observation = ValueObservation.tracking { db in
    try Player.fetchAll(db)
}
for try await players in observation.values(in: writer) {
    print("Fresh players", players)
}
```

`DatabaseQueue` serializes all database accesses, when `DatabasePool` allows parallel reads and writes. The common ``DatabaseWriter`` protocol provides the [SQLite isolation guarantees](https://www.sqlite.org/isolation.html) that abstract away the differences between the two connection types, without sacrificing data integrity. See the <doc:Concurrency> guide for more information.

All safety guarantees of Swift 6 are enforced during database accesses. They are controlled by the language mode and level of concurrency checkings used by your application, as described in [Migrating to Swift 6] on swift.org. 

The following sections describe, with more details, how GRDB interacts with Swift Concurrency.

- <doc:SwiftConcurrency#Non-Sendable-Record-Types>
- <doc:SwiftConcurrency#Shorthand-Closure-Notation>
- <doc:SwiftConcurrency#Non-Sendable-Configuration-of-Record-Types>
- <doc:SwiftConcurrency#Choosing-between-Synchronous-and-Asynchronous-Database-Accesses>

### Non-Sendable Record Types

In the Swift 6 language mode, and in the Swift 5 language mode with strict concurrency checkings, the compiler emits an error or a warning when the application reads, writes, or observes a non-[`Sendable`](https://developer.apple.com/documentation/swift/sendable) type.

By default, Swift classes are not Sendable. They are not thread-safe. With GRDB, record classes will typically trigger compiler diagnostics:

```swift
// A non-Sendable record type
final class Player: Codable, Identifiable {
    var id: Int64
    var name: String
    var score: Int
}

extension Player: FetchableRecord, PersistableRecord { }

// ❌ Type 'Player' does not conform to the 'Sendable' protocol
let player = try await writer.read { db in
    try Player.fetchOne(db, id: 42)
}

// ❌ Capture of 'player' with non-sendable type 'Player' in a `@Sendable` closure
let player: Player
try await writer.read { db in
    try player.insert(db)
}

// ❌ Type 'Player' does not conform to the 'Sendable' protocol
let observation = ValueObservation.tracking { db in
    try Player.fetchAll(db)
}
```

#### The solution

The solution is to have the record type conform to `Sendable`.

Since classes are difficult to make `Sendable`, the easiest way to is to replace classes with structs composed of `Sendable` properties:

```swift
// This struct is Sendable
struct Player: Codable, Identifiable {
    var id: Int64
    var name: String
    var score: Int
}

extension Player: FetchableRecord, PersistableRecord { }
```

You do not need to perform this refactoring right away: you can compile your application in the Swift 5 language mode, with minimal concurrency checkings. Take your time, and only when your application is ready, enable strict concurrency checkings or the Swift 6 language mode.

#### FAQ: My application defines record classes, because…

- **Question: My record types are subclasses of the built-in GRDB `Record` class.**
    
    Consider refactoring them as structs. The ``Record`` class was present in GRDB 1.0, in 2017. It has served its purpose. It is not `Sendable`, and its use is actively discouraged since GRDB 7.

- **Question: I need a hierarchy of record classes because I use inheritance.**
    
    It should be possible to refactor the class hiearchy with Swift protocols. See <doc:RecordTimestamps> for a practical example. Protocols make it possible to define records as structs.

- **Question: I use the `@Observable` macro for my record types, and this macro requires a class.**

    A possible solution is to define two types: an `@Observable` class that drives your SwiftUI views, and a plain record struct for database work. An indirect advantage is that you will be able to make them evolve independently.

- **Question: I use classes instead of structs because I monitored my application and classes have a lower CPU/memory footprint.**
    
    Now that's tricky. Please do not think the `Sendable` requirement is a whim: see the following questions.

#### FAQ: How to make classes Sendable?

- **Question: Can I mark my record classes as `@unchecked Sendable`?**

    Take care that all humans and machines who will read your code will think that the class is thread-safe, so make sure it really is. See the following questions.

- **Question: I can use locks to make my class safely Sendable.**

    You can indeed put a lock on the whole instance, or on each individual property, or on multiple subgroups of properties, as needed by your application. Remember that structs are simpler, because they do not need locks and the compiler does all the hard work for you.

- **Question: Can I make my record classes immutable?**

    Yes. Classes that can not be modified, made of constant `let` properties, are Sendable. Those immutable classes will not make it easy to modify the database, though.

#### FAQ: Why this Sendable requirement?

**GRDB needs new features in the Swift language and the SDKs in order to deal with non-Sendable types.**

[SE-0430: `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md) looks like the language feature we need, but:

- `DispatchQueue.async` does not accept a `sending` closure. GRDB needs this in order to accept non-Sendable records to be sent to the database, as below:

    ```swift
    let nonSendableRecord: Player
    try await writer.write { db in
        try nonSendableRecord.insert(db)
    }
    ```

    Please [file a feedback](http://feedbackassistant.apple.com) for requesting this DispatchQueue improvement. The more the merrier. I personally filed FB15270949.

- Database access methods taint the values they fetch. In the code below, the rules of [SE-0414: Region based Isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md) have the compiler refuse that the fetched player is sent back to the caller:

    ```swift
    let player = try await writer.read { db in
        try Player.fetchOne(db, id: 42)
    }
    ```

    Strictly speaking, the compiler diagnostic is correct: one could copy the non-Sendable `db` argument into the fetched `Player` instance, making it unsuitable for later use. In practice, nobody does that. Copying `db` is a programmer error, and GRDB promptly raises a fatal error whenever a `db` copy would be improperly used. But there is no way to tell the compiler about this practice.

For all those reasons, GRDB has to require values that are asynchronously written and read from the database to be `Sendable`.

### Shorthand Closure Notation

In the Swift 5 language mode, the compiler emits a warning when a database access is written with the shorthand closure notation:

```swift
// Standard closure:
let count = try await writer.read { db in
    try Player.fetchCount(db)
}

// Shorthand notation:
// ⚠️ Converting non-sendable function value to '@Sendable (Database) 
// throws -> Int' may introduce data races.
let count = try await writer.read(Player.fetchCount)
```

**You can remove this warning** by enabling [SE-0418: Inferring `Sendable` for methods and key path literals](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0418-inferring-sendable-for-methods.md), as below:

- **Using Xcode**

    Set `SWIFT_UPCOMING_FEATURE_INFER_SENDABLE_FROM_CAPTURES` to `YES` in the build settings of your target.

- **In a SwiftPM package manifest**

    Enable the `InferSendableFromCaptures` upcoming feature: 
    
    ```swift
    .target(
        name: "MyTarget",
        swiftSettings: [
            .enableUpcomingFeature("InferSendableFromCaptures")
        ]
    )
    ```

This language feature is not enabled by default, because it can potentially [affect source compatibility](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/sourcecompatibility#Inferring-Sendable-for-methods-and-key-path-literals).

### Non-Sendable Configuration of Record Types

In the Swift 6 language mode, and in the Swift 5 language mode with strict concurrency checkings, the compiler emits an error or a warning when a record type specifies which columns it fetches from the database, with the ``TableRecord/databaseSelection-7iphs`` static property:

```swift
extension Player: FetchableRecord, MutablePersistableRecord {
    // ❌ Static property 'databaseSelection' is not concurrency-safe
    // because non-'Sendable' type '[any SQLSelectable]'
    // may have shared mutable state
    static let databaseSelection: [any SQLSelectable] = [
        Column("id"), Column("name"), Column("score")
    ]
}
```

**To fix this error**, replace the stored property with a computed property:

```swift
extension Player: FetchableRecord, MutablePersistableRecord {
    static var databaseSelection: [any SQLSelectable] {
        [Column("id"), Column("name"), Column("score")]
    }
}
```

### Choosing between Synchronous and Asynchronous Database Accesses

GRDB connections provide two versions of `read` and `write`, one that is synchronous, and one that is asynchronous. It might not be clear how to choose one or the other.

```swift
// Synchronous database access
try writer.write { ... }

// Asynchronous database access
await try writer.write { ... }
```

Synchronous accesses are handy. They avoid introducing undesired delays, flashes of missing content in the user interface, or `async` functions. There is no problem performing fast database accesses synchronously, even from the main thread.

**It is a good idea to prefer the asynchronous version (`await`) whenever the application accesses the database from Swift tasks.** This is not a hard requirement, because performing synchronous database accesses from tasks is not incorrect. The only problem is that other tasks may have to wait until datababase accesses are completed. When you `await` for database accesses, this problem does not happen.

In many occasions, the compiler will guide you. In the sample code below, the compiler requires the `await` keyword:

```swift
func fetchPlayers() async throws -> [Player] {
    try await writer.read(Player.fetchAll)
}
```

But there are some scenarios where your vigilance is needed. For example, the compiler does not spot the missing `await` inside closures ([swiftlang/swift#74459](https://github.com/swiftlang/swift/issues/74459)):

```swift
Task {
    // NOT RECOMMENDED
    // The compiler does not spot the missing `await`
    let players = try writer.read(Player.fetchAll)

    // RECOMMENDED
    let players = try await writer.read(Player.fetchAll)
}
```

[demo apps]: https://github.com/groue/GRDB.swift/tree/master/Documentation/DemoApps
[Migrating to Swift 6]: https://www.swift.org/migration/documentation/migrationguide/