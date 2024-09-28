Migrating From GRDB 6 to GRDB 7
===============================

**This guide helps you upgrade your applications from GRDB 6 to GRDB 7.**

- [Preparing the Migration to GRDB 7](#preparing-the-migration-to-grdb-7)
- [New requirements](#new-requirements)
- [The Record Base Class is Discouraged](#the-record-base-class-is-discouraged)
- [Column Coding Strategies](#column-coding-strategies)
- [Cancellable Async Database Accesses](#cancellable-async-database-accesses)
- [Default Transaction Kind](#default-transaction-kind)
- [Access to SQLite C functions](#access-to-sqlite-c-functions)
- [Recommendations Regarding Swift Concurrency](#recommendations-regarding-swift-concurrency)
- [Other Changes](#other-changes)

## Preparing the Migration to GRDB 7

Before upgrading, ensure you are using the [latest GRDB 6 release](https://github.com/groue/GRDB.swift/tags) and address any deprecation warnings. Once this is done, proceed with upgrading to GRDB 7. Due to breaking changes, your application may no longer compile. Follow the fix-it suggestions for simple syntax updates, and review the specific modifications described below.

## New requirements

GRDB requirements have been bumped:

- **Swift Compiler 6+** (was Swift 5.7+). Both Swift 5 and Swift 6 language modes are supported. For more information, see the [Migrating to Swift 6] Apple guide.
- **Xcode 16.0+** (was Xcode 14.0+)
- **iOS 13+** (was iOS 11+)
- **macOS 10.15+** (was macOS 10.13+)
- **tvOS 13+** (was tvOS 11+)
- **watchOS 7.0+** (was watchOS 4+)
- **SQLite 3.20.0+** (was SQLite 3.19.3+)

## The Record Base Class is Discouraged

The usage of the [Record] base class is **discouraged** in GRDB 7. Present in GRDB 1.0, in 2017, it has served its purpose. 

It is not recommended to define any new type that subclass `Record`.

It is recommended to refactor `Record` subclasses into Swift structs, before you enable the strict concurrency checkings or the Swift 6 language mode. See [Migrating to Swift 6] for more information about Swift 6 language modes.

For example:

```swift
// GRDB 6
class Player: Record {
    var id: UUID
    var name: String
    var score: Int
    
    override class var databaseTableName: String { "player" }
    
    init(id: UUID, name: String, score: Int) { ... }
    required init(row: Row) throws { ... }
    override func encode(to container: inout PersistenceContainer) throws { ...}
}

// GRDB 7
struct Player: Codable {
    var id: UUID
    var name: String
    var score: Int
}

extension Player: FetchableRecord, PersistableRecord { }
```

Do not miss [Swift Concurrency and GRDB], for more recommendations regarding non-Sendable record types in GRDB. 

## Column Coding Strategies

In GRDB 6, Codable record types can specify how `Data`, `Date`, and `UUID` properties are stored in the database:

```swift
// GRDB 6
struct Player {
    static let databaseDataDecodingStrategy = ...
    static let databaseDateDecodingStrategy = ...
    static let databaseDataEncodingStrategy = ...
    static let databaseDateEncodingStrategy = ...
    static let databaseUUIDEncodingStrategy = ...
}
```

These properties have been removed in GRDB 7. You must now define methods that accept a column argument:

```swift
// GRDB 7
struct Player {
    static func databaseDataDecodingStrategy(for column: String) -> DatabaseDataDecodingStrategy { ... }
    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy { ...}
    static func databaseDataEncodingStrategy(for column: String) -> DatabaseDataEncodingStrategy { ... }
    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy { ... }
    static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy { ... }
}
```

## Cancellable Async Database Accesses

In GRDB 6, asynchronous database accesses such as `try await read { ... }` or `try await write { ... }` complete even if the wrapper Task is cancelled.

In GRDB 7, asynchronous database accesses respect Task cancellation. If a Task is cancelled, reads and writes throw a `CancellationError`, pending transactions are rolled back, and the database is not modified. The only SQL statement that can execute in a cancelled database access is `ROLLBACK`.

The effect of this change on your application depends on how it uses tasks. For example, take care of database jobs initiated frop the [`task`](https://developer.apple.com/documentation/swiftui/view/task(priority:_:)) SwiftUI modifier.

If you want an asynchronous database access to always complete, regardless of Task cancellation, wrap it in an unstructured Task:

```swift
// Create a new Task in order to ignore
// cancellation of the current task, and
// make sure database changes are always
// committed to disk.
let task = Task {
    try await writer.write { ... }
}
// If needed, wait for the database job to complete:
try await task.value
```

Other asynchronous database accesses, such as methods accepting a completion blocks (`asyncRead`, etc.), Combine publishers, RxSwift observables, do not handle cancellation and will proceed to completion by default.

## Default Transaction Kind

Some applications specify a default transaction kind, which was previously recommended in the [Sharing a Database] guide:

```swift
// GRDB 6
var config = Configuration()
config.defaultTransactionKind = .immediate
```

In GRDB 7, `Configuration` no longer has a `defaultTransactionKind` property, because transactions are automatically managed. Reads use DEFERRED transactions, and writes use IMMEDIATE transactions.

You can still specify a transaction kind explicitly when necessary. See [Transaction Kinds] for details.

## Access to SQLite C functions

In GRDB 6, the underlying C SQLite library is implicitly available:

```swift
// GRDB 6
import GRDB

let sqliteVersion = sqlite3_libversion_number()
```

In GRDB 7, you may need an additional import, depending on how GRDB is integrated:

- If your app uses the GRDB Swift Package Manager (SPM) package:

    ```swift
    import SQLite3

    let sqliteVersion = sqlite3_libversion_number()
    ```
    
    The GRDB 6 SPM package included a product named "CSQLite." In GRDB 7, this product has been renamed "GRDBSQLite." Update your dependencies accordingly. It is unclear at the time of writing whether some projects can remove this dependency.
    
- If your app uses SQLCipher:

    ```swift
    import SQLCipher

    let sqliteVersion = sqlite3_libversion_number()
    ```

- In other cases, no additional import is needed.

## Recommendations Regarding Swift Concurrency

GRDB 7 requires Xcode 16+ and a Swift 6 compiler.

Depending of the language mode and level of concurrency checkings used by your application (see [Migrating to Swift 6]), you may see warnings or errors. We address those issues, and provide general guidance, in [Swift Concurrency and GRDB].


## Other Changes

- `ValueObservation` must be started from the Main Actor by default. Use an explicit `async(onQueue: .main)` scheduling in order to remove this constraint.

- `DatabasePool.concurrentRead` has been removed. Use [`asyncConcurrentRead`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasepool/asyncconcurrentread(_:)) instead.

- The `PersistenceContainer` subscript no longer guarantees that the value returned is the same as what was previously set. It only guarantees that both values are encoded identically in the database.

- The async sequence returned by [`ValueObservation.values`](https://swiftpackageindex.com/groue/grdb.swiftdocumentation/grdb/valueobservation/values(in:scheduling:bufferingpolicy:)) now iterates on the cooperative thread pool by default. Use .mainActor as the scheduler if you need the previous behavior.

[Migrating to Swift 6]: https://www.swift.org/migration/documentation/migrationguide
[Sharing a Database]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasesharing
[Transaction Kinds]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/transactions#Transaction-Kinds
[Swift Concurrency and GRDB]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/swiftconcurrency
[Record]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/record