Database Connections
====================

GRDB provides two classes for accessing SQLite databases: [`DatabaseQueue`] and [`DatabasePool`]:

```swift
import GRDB

// Pick one:
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
```

The differences are:

- Database pools allow concurrent database accesses (this can improve the performance of multithreaded applications).
- Database pools open your SQLite database in the [WAL mode](https://www.sqlite.org/wal.html) (unless read-only).
- Database queues support [in-memory databases](https://www.sqlite.org/inmemorydb.html).

**If you are not sure, choose [`DatabaseQueue`].** You will always be able to switch to [`DatabasePool`] later.

For more information and tips when opening connections, see [Database Connections](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseconnections).

[`DatabaseQueue`]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasequeue
[`DatabasePool`]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasepool
