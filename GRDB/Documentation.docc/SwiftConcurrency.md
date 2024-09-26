# Swift Concurrency and GRDB

How to best integrate GRDB and Swift Concurrency 

## Overview

GRDB’s primary goal is to leverage SQLite’s concurrency features, for the benefit of application developers. Swift 6 makes it possible to achieve this goal while ensuring data-race safety.

For example, the ``DatabasePool`` connection allows applications to read and display database values on screen, even while a background task is writing the results of a network request to disk.

Application previews and tests prefer to use an in-memory ``DatabaseQueue`` connection, which avoids writing to disk. For examples of such an integration, see the [demo apps].

Both connection types provide identical database accesses through closures, as shown with the `db` argument below:

```swift
// Read
let player = try await writer.read { db in
    try Player.find(db, id: 42)
}

// Write
let newPlayerCount = try await writer.write { db in
    try Player(name: "Arthur").insert(db)
    return try Player.fetchCount(db)
}

// Observe the database
let observation = ValueObservation.tracking { db in
    try Player.fetchAll(db)
}
for try await players in observation.values(in: writer) {
    print("Fresh players", players)
}
```

GRDB optimally schedules those database access closures, in the best interest of the application. With a `DatabaseQueue`, all accesses are serialized. With a `DatabasePool`, reads and writes can occur in parallel, improving throughput. The differences between these two modes are minimized by the common ``DatabaseWriter`` protocol, which provides the runtime guarantees described in the <doc:Concurrency> guide.

Depending of the language mode and level of concurrency checkings used by your application (see [Migrating to Swift 6]), you may see warnings or errors. We will address these issues, and provide general guidance in the following sections.

- <doc:SwiftConcurrency#Non-Sendable-Record-Types>
- <doc:SwiftConcurrency#Shorthand-Closure-Notation>
- <doc:SwiftConcurrency#Non-Sendable-Configuration-of-Record-Types>
- <doc:SwiftConcurrency#Choosing-between-Synchronous-and-Asynchronous-Database-Accesses>

### Non-Sendable Record Types

#### The problem

In the Swift 6 language mode, and in the Swift 5 language mode with strict concurrency checkings, the compiler emits an error or a warning when the application reads, writes, or observes a non-Sendable type such as record *classes*:

```swift
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

The easiest way to do so is to replace classes, which are difficult to make `Sendable`, with structs composed of `Sendable` properties:

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

#### FAQ

> Question: **Can I mark my record classes as `@unchecked Sendable`?**
>
> **Answer**: This is a bad idea, because all humans and machines who will read your code will think that the class is thread-safe, when it is actually not. Instead, use the Swift 5 language mode, with minimal concurrency checkings, until your code is refactored.

> Question: **I can use locks to make my class safely Sendable.**
>
> **Answer**: Indeed you can put a lock on the whole instance, or on each individual property, or on multiple subgroups of properties, as needed. But structs are simpler, because they do not need locks and the compiler does all the hard work for you.

> Question: **My record types are subclasses of the built-in GRDB `Record` class.**
>
> **Answer**: The ``Record`` class was present in GRDB 1.0, in 2017. It has served its purpose. It is not `Sendable`, and its use is actively discouraged since GRDB 7.

> Question: **I need a hierarchy of record classes because I use inheritance.**
>
> **Answer**: It should be possible to refactor the class hiearchy with Swift protocols. See for example <doc:RecordTimestamps> for an example of a protocol that grants database timestamps features.

> Question: **I use the `@Observable` macro for my record types, and this macro requires a class.**
>
> **Answer**: Your solution is to define two types: an `@Observable` one that drives your SwiftUI views, and a plain record struct for database work. An indirect advantage is that you will be able to make them evolve independently.

> Question: **I use classes instead of structs because I monitored my application and classes have a lower CPU/memory footprint.**
>
> **Answer**: Pick your poison: refactor those classes into structs, or make them Sendable, or avoid raising the Swift concurrency checkings. Please do not think the `Sendable` requirement is a whim: see the next question.

> Question: **Can I wait until GRDB learns how to deal with non-Sendable record types?**
>
> **Answer**: This can't happen without new features in the Swift language and the SDKs.
>
> [SE-0430: `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md) looks like the language feature we need, but:
>
> - `DispatchQueue.async` does not accept a `sending` closure. GRDB needs this in order to accept non-Sendable records to be sent to the database, as below:
>
>     ```swift
>     let nonSendableRecord: Player
>     try await writer.write { db in
>         try nonSendableRecord.insert(db)
>     }
>     ```
>
>     Please [file a feedback](http://feedbackassistant.apple.com) for requesting this DispatchQueue improvement. The more the merrier. I personally filed FB15270949.
>
> - Database access methods taint the values they fetch, making it impossible to "send" them back to the caller.
>
>     In the code below, the `db` argument is not Sendable, on purpose. It taints the fetched player, according to the rules of [SE-0414: Region based Isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md), and has the compiler refuse that the player crosses isolation domains, back to the caller:
>
>     ```swift
>     let player = try await writer.read { db in
>         try Player.fetchOne(db, id: 42)
>     }
>     ```
>
>     The compiler diagnostic is correct: one can copy the `db` argument into the fetched `Player` instance. Doing so is a programmer error, though: GRDB promptly raises a fatal error whenever that copied `db` is later used. In practice, nobody does that. But there is no way to tell the compiler about this practice.
>
> For all those reasons, which are entirely beyond our control, GRDB has to require values that are asynchronously written and read from the database to be `Sendable`.

### Shorthand Closure Notation

#### The problem

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

#### The solution

You can remove this warning by enabling [SE-0418: Inferring `Sendable` for methods and key path literals](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0418-inferring-sendable-for-methods.md), as below:

- **Using Xcode**

    Set `SWIFT_UPCOMING_FEATURE_INFER_SENDABLE_FROM_CAPTURES` to `YES` in the build settings of your target.

- **In a SwiftPM package manifest**

    Enable the "InferSendableFromCaptures" upcoming feature: 
    
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

#### The problem

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

#### The solution

Replace the stored property with a computed property:

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

**It is a good idea to prefer the asynchronous version whenever the application accesses the database from Swift tasks.** This is not a hard requirement, because performing synchronous database accesses from tasks is not incorrect. But this may slow down other tasks that run on the cooperative thread pool.

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
