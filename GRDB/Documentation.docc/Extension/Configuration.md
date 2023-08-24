# ``GRDB/Configuration``

The configuration of a database connection.

## Overview

You create a `Configuration` before opening a database connection:

```swift
var config = Configuration()
config.readonly = true
config.maximumReaderCount = 2  // (DatabasePool only) The default is 5

let dbQueue = try DatabaseQueue( // or DatabasePool
    path: "/path/to/database.sqlite",
    configuration: config)
```

See <doc:DatabaseConnections>.

## Frequent Use Cases

#### Tracing SQL Statements

You can setup a tracing function that prints out all executed SQL requests with ``prepareDatabase(_:)`` and ``Database/trace(options:_:)``:

```swift
var config = Configuration()
config.prepareDatabase { db in
    db.trace { print("SQL> \($0)") }
}

let dbQueue = try DatabaseQueue(
    path: "/path/to/database.sqlite",
    configuration: config)

// Prints "SQL> SELECT COUNT(*) FROM player"
let playerCount = dbQueue.read { db in
    try Player.fetchCount(db)
}
```

#### Public Statement Arguments

Debugging is easier when database errors and tracing functions expose the values sent to the database. Since those values may contain sensitive information, verbose logging is disabled by default. You turn it on with ``publicStatementArguments``:   

```swift
var config = Configuration()
#if DEBUG
// Protect sensitive information by enabling
// verbose debugging in DEBUG builds only.
config.publicStatementArguments = true
#endif

let dbQueue = try DatabaseQueue(
    path: "/path/to/database.sqlite",
    configuration: config)

do {
    try dbQueue.write { db in
        user.name = ...
        user.location = ...
        user.address = ...
        user.phoneNumber = ...
        try user.save(db)
    }
} catch {
    // Prints sensitive information in debug builds only
    print(error)
}
```

> Warning: It is your responsibility to prevent sensitive information from leaking in unexpected locations, so you should not set the `publicStatementArguments` flag in release builds (think about GDPR and other privacy-related rules).

## Topics

### Creating a Configuration

- ``init()``

### Configuring SQLite Connections

- ``acceptsDoubleQuotedStringLiterals``
- ``busyMode``
- ``foreignKeysEnabled``
- ``journalMode``
- ``readonly``
- ``JournalModeConfiguration``

### Configuring GRDB Connections

- ``allowsUnsafeTransactions``
- ``defaultTransactionKind``
- ``label``
- ``maximumReaderCount``
- ``observesSuspensionNotifications``
- ``persistentReadOnlyConnections``
- ``prepareDatabase(_:)``
- ``publicStatementArguments``
- ``transactionClock``
- ``TransactionClock``

### Configuring the Quality of Service

- ``qos``
- ``readQoS``
- ``writeQoS``
- ``targetQueue``
- ``writeTargetQueue``
