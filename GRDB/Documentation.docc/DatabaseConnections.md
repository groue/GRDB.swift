# Database Connections

Open database connections to SQLite databases. 

## Overview

GRDB provides two classes for accessing SQLite databases: ``DatabaseQueue`` and ``DatabasePool``:

```swift
import GRDB

// Pick one:
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
```

The differences are:

- `DatabasePool` allows concurrent database accesses (this can improve the performance of multithreaded applications).
- `DatabasePool` opens your SQLite database in the [WAL mode](https://www.sqlite.org/wal.html).
- `DatabaseQueue` supports <doc:DatabaseQueue#In-Memory-Databases>.

**If you are not sure, choose `DatabaseQueue`.** You will always be able to switch to `DatabasePool` later.

## Topics

### Configuring database connections

- ``Configuration``

### Connections for read and write accesses

- ``DatabaseQueue``
- ``DatabasePool``

### Read-only connections on an unchanging database content

- ``DatabaseSnapshot``
- ``DatabaseSnapshotPool``

### Using database connections

- ``Database``
- ``DatabaseError``
