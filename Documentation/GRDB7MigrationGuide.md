Migrating From GRDB 6 to GRDB 7
===============================

**This guide helps you upgrade your applications from GRDB 6 to GRDB 7.**

- [Preparing the Migration to GRDB 7](#preparing-the-migration-to-grdb-7)
- [New requirements](#new-requirements)
- [Column Coding Strategies](#column-coding-strategies)
- [Cancellable Async Database Accesses](#cancellable-async-database-accesses)
- [Default Transaction Kind](#default-transaction-kind)
- [Access to SQLite C functions](#access-to-sqlite-c-functions)
- [Other Changes](#other-changes)
- [Recommendations Regarding Swift Concurrency]

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

## Column Coding Strategies

In GRDB 6, Codable record types can specify how `Data`, `Date`, and `UUID` properties are stored in the database:

```swift
// GRDB 6
struct Player {
    static let databaseDataDecodingStrategy = DatabaseDataDecodingStrategy.deferredToData
    static let databaseDateDecodingStrategy = DatabaseDateDecodingStrategy.timeIntervalSince1970
    static let databaseDataEncodingStrategy = DatabaseDataEncodingStrategy.text
    static let databaseDateEncodingStrategy = DatabaseDateEncodingStrategy.timeIntervalSince1970
    static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString
}
```

These properties have been removed in GRDB 7. You must now define methods that accept a column argument:

```swift
// GRDB 7
struct Player {
    static func databaseDataDecodingStrategy(for column: String) -> DatabaseDataDecodingStrategy {
        .deferredToData
    }
    
    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .timeIntervalSince1970
    }
    
    static func databaseDataEncodingStrategy(for column: String) -> DatabaseDataEncodingStrategy {
        .text
    }
    
    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .timeIntervalSince1970
    }
    
    static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy {
        .uppercaseString
    }
}
```

## Cancellable Async Database Accesses

In GRDB 6, asynchronous database operations initiated with `await` would complete even if the underlying Task was cancelled.

In GRDB 7, all asynchronous database operations respect Task cancellation. If a Task is cancelled, reads and writes will throw a `CancellationError`, and transactions will be rolled back. The only SQL statement that can execute in a cancelled task is `ROLLBACK`.

The effect of this change on your application depends on how you use asynchronous tasks. For example, in SwiftUI, database jobs initiated by the `task` modifier will be cancelled if the associated view is no longer rendered:

```swift
import SwiftUI

struct MyButton: View {
    @State var actionTrigger = 0
    
    var body: some View {
        Button("Toggle favorite") {
            actionTrigger += 1
        }
        .task(id: actionTrigger) {
            if actionTrigger > 0 {
                // Will be cancelled if the button is no longer rendered.
                await performDatabaseJob()
            }
        }
    }
}
```

Other asynchronous database access methods, such as those using completion blocks (`asyncXXX`), Combine publishers, or RxSwift observables, do not handle cancellation and will proceed to completion by default.

## Default Transaction Kind

Some applications specify a default transaction kind, which was previously recommended in the [Sharing a Database] guide:

```swift
// GRDB 6
var config = Configuration()
config.defaultTransactionKind = .immediate
```

In GRDB 7, transaction are automatically managed: reads use DEFERRED transactions, and writes use IMMEDIATE transactions.

You can still specify a transaction kind explicitly when necessary. See [Transaction Kinds] for details.

## Access to SQLite C functions

In GRDB 6, the underlying C SQLite library was automatically available:

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

## Other Changes

- `ValueObservation` must be started from the Main Actor by default. Use an explicit `async(onQueue: .main)` scheduling in order to remove this constraint.

- `DatabasePool.concurrentRead` has been removed. Use [`asyncConcurrentRead`](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasepool/asyncconcurrentread(_:)) instead.

- The `PersistenceContainer` subscript no longer guarantees that the value returned is the same as what was previously set. It only guarantees that both values are encoded identically in the database.

- The async sequence returned by [`ValueObservation.values`](https://swiftpackageindex.com/groue/grdb.swiftdocumentation/grdb/valueobservation/values(in:scheduling:bufferingpolicy:)) now iterates on the cooperative thread pool by default. Use .mainActor as the scheduler if you need the previous behavior.

[Migrating to Swift 6]: https://www.swift.org/migration/documentation/migrationguide
[Sharing a Database]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databasesharing
[Transaction Kinds]: https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/transactions#Transaction-Kinds
[Recommendations Regarding Swift Concurrency]
