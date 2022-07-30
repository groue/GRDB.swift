Migrating From GRDB 5 to GRDB 6
===============================

**This guide aims at helping you upgrading your applications from GRDB 5 to GRDB 6.**

- [Preparing the Migration to GRDB 6](#preparing-the-migration-to-grdb-6)
- [New requirements](#new-requirements)
- [Primary Associated Types](#primary-associated-types)
- [Record Changes](#record-changes)
- [Other Changes](#other-changes)


## Preparing the Migration to GRDB 6

If you haven't made it yet, upgrade to the [latest GRDB 5 release](https://github.com/groue/GRDB.swift/tags) first, and fix any deprecation warning prior to the GRDB 6 upgrade.

You can then upgrade to GRDB 6. Due to the breaking changes, it is possible that your application code no longer compiles. Follow the fix-its that suggest simple syntactic changes. Other modifications that you need to apply are described below.

## New requirements

GRDB requirements have been bumped:

- **Swift 5.7+** (was Swift 5.3+)
- **Xcode 14.0+** (was Xcode 12.0+)
- iOS 11.0+ (unchanged)
- **macOS 10.13+** (was macOS 10.10+)
- **tvOS 11.0+** (was tvOS 11.0+)
- **watchOS 4.0+** (was watchOS 2.0+)
- **SQLite 3.19.3+** (was SQLite 3.8.5+)

## Primary Associated Types

Request protocols now come with a primary associated type, enabled by [SE-0346](https://github.com/apple/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md). This is a great opportunity to simplify your extensions:

```diff
-extension DerivableRequest where RowDecoder == Book {
+extension DerivableRequest<Book> {
     /// Order books by title, in a localized case-insensitive fashion
     func orderByTitle() -> Self {
         order(Column("title").collating(.localizedCaseInsensitiveCompare))
     }
 }
```

Your extensions to `QueryInterfaceRequest` can be streamlined as well, thanks to [SE-0361](https://github.com/apple/swift-evolution/blob/main/proposals/0361-bound-generic-extensions.md):

```diff
-extension QueryInterfaceRequest where RowDecoder == Player {
+extension QueryInterfaceRequest<Player> {
     func selectID() -> QueryInterfaceRequest<Int64> {
         selectPrimaryKey()
     }
 }
```

The `Cursor` protocol has also gained a primary associated type (the type of its elements).

## Record Changes

The record protocols have been refactored. We tried to keep the amount of modifications to your existing code as small as possible, but some changes could not be avoided.

- **The `FetchableRecord.init(row:)` initializer can now throw errors.**
    
    ```diff
    -let player = Player(row: row)
    +let player = try Player(row: row)
    ```

    Decodable records that derive their `FetchableRecord` implementation from the standard `Decodable` protocol now throw errors when they find unexpected database values (they used to crash in GRDB 5).
    
    If you subclass the `Record` type, you have to update your override of `init(row:)`:
    
    ```diff
     class Player: Record {
    -    required init(row: Row) {
    +    required init(row: Row) throws {
             self.id = row["id"]
             self.name = row["name"]
    -        super.init(row: row)
    +        try super.init(row: row)
         }
     }
    ```
    
    In record types that do not derive their `FetchableRecord.init(row:)` implementation from the standard `Decodable` protocol, you are responsible for throwing decoding errors, as in the sample code below:
    
    <details>
        <summary>Handling untrusted input</summary>
    
    For example:
    
    ```swift
    struct LogEntry: FetchableRecord {
        var date: Date
        
        init(row: Row) throws {
            let dbValue: DatabaseValue = row["date"]
            if dbValue.isNull {
                // Handle NULL
                throw ...
            } else if let date = Date.fromDatabaseValue(dbValue) {
                self.date = date
            } else {
                // Handle invalid date
                throw ...
            }
        }
    }
    ```
    
    </details>


## Other Changes

- The initializer of in-memory databases can now throw errors:

    ```diff
    -let dbQueue = DatabaseQueue()
    +let dbQueue = try DatabaseQueue()
    ```

- The `selectID()` method is removed. You can provide your own implementation, based on the new `selectPrimaryKey(as:)` method:

    ```swift
    extension QueryInterfaceRequest<Player> {
        func selectID() -> QueryInterfaceRequest<Int64> {
            selectPrimaryKey()
        }
    }
    ```

- `Cursor.isEmpty` is now a throwing property, instead of a method:
    
    ```diff
    -if try cursor.isEmpty() { ... }
    +if try cursor.isEmpty { ... }
    ```

- The `Record.copy()` method was removed, without replacement.

- The `DerivableRequest.limit(_:offset_:)` method was removed, without replacement.
    
    You can still limit `QueryInterfaceRequest`, but associations can no longer be limited:
    
    ```swift
    // Still OK: a limited request of authors
    let request = Author.limit(10)

    // Still OK: a limited request of books
    let request = author.request(for: Author.books).limit(10)
    
    // No longer possible: including a limited association
    let request = Author.including(all: Author.books.limit(10))
    ```
