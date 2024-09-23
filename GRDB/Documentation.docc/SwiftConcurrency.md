# Swift Concurrency

How to best integrate GRDB and Swift Concurrency 

## Overview

GRDB’s primary goal is to leverage SQLite’s concurrency features, for the benefit of application developers. Swift 6 concurrency makes it possible to achieve this goal while ensuring data-race safety.

For example, the ``DatabasePool`` connection allows applications to read and display database values on screen, even while a background task is writing the results of a network request to disk.

Application previews and tests prefer to use an in-memory ``DatabaseQueue`` connection, which does not support parallel accesses, but avoids writing to disk. To switch between connections configurations seamlessly, the ``DatabaseWriter`` protocol ensures common guarantees, described in <doc:Concurrency>. For examples of such an integration, see the [demo apps].

Each connection type provides database accesses through closures, as shown with the `db` argument below:

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

Those database access closures are scheduled optimally, in the best interest of application.

Depending of the language mode and level of concurrency checkings used by your application (see [Migrating to Swift 6]), you may see warnings or errors. We will address these issues and provide general guidance in the following sections.

### Shorthand Closure Notation

#### The problem

In the Swift 5 language mode, the compiler emits a warning when a database access is written with the shorthand closure notation:

```swift
// ⚠️ Converting non-sendable function value to '@Sendable (Database) 
// throws -> Int' may introduce data races.
let count = try await writer.read(Player.fetchCount)

// No warning
let count = try await writer.read { db in
    try Player.fetchCount(db)
}
```

#### The solution

You can remove this warning by enabling [SE-0418 Inferring `Sendable` for methods and key path literals](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0418-inferring-sendable-for-methods.md), as below:

- **Using Xcode**

    Set `SWIFT_UPCOMING_FEATURE_INFER_SENDABLE_FROM_CAPTURES` to `YES` in the build settings of your target.

- **In a SwiftPM package manifest**

    Enable the "GlobalActorIsolatedTypesUsability" upcoming feature: 
    
    ```swift
    .target(
        name: "MyTarget",
        swiftSettings: [
            .enableUpcomingFeature("GlobalActorIsolatedTypesUsability")
        ]
    )
    ```

### Non-Sendable Record Classes

#### The problem

In the Swift 6 language mode, and in the Swift 5 language mode with strict concurrency checkings, the compiler emits an error or a warning when the application reads, writes, or observes a non-Sendable record class:

```swift
final class Player: Codable, Identifiable {
    var id: Int64
    var name: String
    var score: Int
    
    init(id: Int64, name: String, score: Int) {
        self.id = id
        self.name = name
        self.score = score
    }
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

The solution is to stop using classes, which are difficult to make `Sendable` correctly.

Instead, define with record structs composed of Sendable properties:

```swift
struct Player: Codable, Identifiable {
    var id: Int64
    var name: String
    var score: Int
}

extension Player: FetchableRecord, PersistableRecord { }
```

You do not have to refactor your code right away: in the Swift 5 language mode, with minimal concurrency checkings, there is no compiler warning. Take your time, and only when your application is ready, enable strict concurrency checkings or the Swift 6 language mode.

> FAQ:
>
> **Question: Can I mark my record classes as `@unchecked Sendable`?**
>
> **Answer**: This is a bad idea, because people who read your code might think that the class is thread-safe, when it is actually not. Instead, use the Swift 5 language mode, with minimal concurrency checkings, until your code is refactored.
>
> **Q: I can use locks to make my class safely Sendable.**
>
> **A**: Yes. You can tame the compiler by putting a lock on the whole instance, or on each individual property, or on multiple subgroups of properties, as needed. A simpler solution is to use a struct, because the compiler does all the hard work for you.
>
> **Q: My record types are subclasses of the built-in GRDB `Record` class.**
>
> **A**: The ``Record`` class was present in GRDB 1.0, in 2017. It has served its purpose. It is not `Sendable`, and its use is actively discouraged in GRDB 7.
>
> **Q: I need a hierarchy of record classes because I use inheritance.**
>
> **A**: It should be possible to refactor the class hiearchy with Swift protocols. See for example <doc:RecordTimestamps> for an example of a protocol that allows record structs to share a common implementation regarding database timestamps.
>
> **Q: I use the `@Observable` macro for my record types, and this macro requires a class.**
>
> **A**: Your solution is to define two types: one, `@Observable`, that drives your SwiftUI views, and another, a plain record struct, for database work.

> Note: Maybe the Swift language will learn to deal with non-Sendable record types eventually, but it will not happen soon. [SE-0430 `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md) looks like the language feature we need, but:
>
> - `DispatchQueue.async` does not accept a `sending` closure. GRDB needs this.
> - Database access methods taint the values they fetch, making it impossible to "send" them back to the caller:
>
>     ```swift
>     let player = try await writer.read { db in
>         try Player.fetchOne(db, id: 42)
>     }
>     ```
>
>     In the above code, the `db` argument has the type ``Database``, which is not Sendable because one can not use an SQLite connection outside of a database access. This non-Sendable value taints the fetched player according to the rules of [SE-0414 Region based Isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md), preventing it from safely crossing isolation domains.

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

### Avoid Synchronous Database Accesses from Tasks

GRDB connections provide two versions of `read` and `write`, one that is asynchronous, and one that is synchronous. **As much as possible,** avoid calling the synchronous version from Swift Tasks. Performing slow synchronous database jobs from the cooperative thread pool can prevent other tasks from making progress.

In many occasions, the compiler will guide you. In the sample code below, it is an error to forget the `await` keyword:

```swift
func fetchPlayers() async throws -> [Player] {
    try await writer.read(Player.fetchAll)
}
```

But there are some scenarios where you need to be vigilant:

- The compiler does not spot missing `await` inside closures ([#74459](https://github.com/swiftlang/swift/issues/74459)):

    ```swift
    Task {
        // NOT RECOMMENDED - but the compiler does not spot the missing `await`
        let players = try writer.read(Player.fetchAll)
    
        // CORRECT
        let players = try await writer.read(Player.fetchAll)
    }
    ```

- Application that define their own database access method (read or write) should declare them as `async` whenever they intend to use them in tasks.

```swift
struct PlayerRepository {
    var writer: any DatabaseWriter
    
    func fetchPlayers() throws -> [Player] {
        try writer.read(Player.fetchAll)
    }
}


- Avoid sync db access methods in async contexts

[demo apps]: https://github.com/groue/GRDB.swift/tree/master/Documentation/DemoApps
[Migrating to Swift 6]: https://www.swift.org/migration/documentation/migrationguide/
[SE-0418]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0418-inferring-sendable-for-methods.md
