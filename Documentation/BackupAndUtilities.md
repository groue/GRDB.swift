Backup and Utilities
====================

This document covers various utility topics:

- [Backup](#backup)
- [Interrupt a Database](#interrupt-a-database)
- [Avoiding SQL Injection](#avoiding-sql-injection)
- [Error Handling](#error-handling)
- [Unicode](#unicode)
- [Memory Management](#memory-management)


## Backup

**You can backup (copy) a database into another.**

Backups can for example help you copying an in-memory database to and from a database file when you implement NSDocument subclasses.

```swift
let source: DatabaseQueue = ...      // or DatabasePool
let destination: DatabaseQueue = ... // or DatabasePool
try source.backup(to: destination)
```

The `backup` method blocks the current thread until the destination database contains the same contents as the source database.

When the source is a [database pool](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasepool), concurrent writes can happen during the backup. Those writes may, or may not, be reflected in the backup, but they won't trigger any error.

`Database` has an analogous `backup` method.

```swift
let source: DatabaseQueue = ...      // or DatabasePool
let destination: DatabaseQueue = ... // or DatabasePool
try source.write { sourceDb in
    try destination.barrierWriteWithoutTransaction { destDb in
        try sourceDb.backup(to: destDb)
    }
}
```

This method allows for the choice of source and destination `Database` handles with which to backup the database.

### Backup Progress Reporting

The `backup` methods take optional `pagesPerStep` and `progress` parameters. Together these parameters can be used to track a database backup in progress and abort an incomplete backup.

When `pagesPerStep` is provided, the database backup is performed in *steps*. At each step, no more than `pagesPerStep` database pages are copied from the source to the destination. The backup proceeds one step at a time until all pages have been copied.

When a `progress` callback is provided, `progress` is called after every backup step, including the last. Even if a non-default `pagesPerStep` is specified or the backup is otherwise completed in a single step, the `progress` callback will be called.

```swift
try source.backup(
    to: destination,
    pagesPerStep: ...)
    { backupProgress in
       print("Database backup progress:", backupProgress)
    }
```

### Aborting an Incomplete Backup

If a call to `progress` throws when `backupProgress.isComplete == false`, the backup will be aborted and the error rethrown. However, if a call to `progress` throws when `backupProgress.isComplete == true`, the backup is unaffected and the error is silently ignored.

> **Warning**: Passing non-default values of `pagesPerStep` or `progress` to the backup methods is an advanced API intended to provide additional capabilities to expert users. GRDB's backup API provides a faithful, low-level wrapper to the underlying SQLite online backup API. GRDB's documentation is not a comprehensive substitute for the official SQLite [documentation of their backup API](https://www.sqlite.org/c3ref/backup_finish.html).


## Interrupt a Database

**The `interrupt()` method** causes any pending database operation to abort and return at its earliest opportunity.

It can be called from any thread.

```swift
dbQueue.interrupt()
dbPool.interrupt()
```

A call to `interrupt()` that occurs when there are no running SQL statements is a no-op and has no effect on SQL statements that are started after `interrupt()` returns.

A database operation that is interrupted will throw a DatabaseError with code `SQLITE_INTERRUPT`. If the interrupted SQL operation is an INSERT, UPDATE, or DELETE that is inside an explicit transaction, then the entire transaction will be rolled back automatically.

For example:

```swift
try dbQueue.write { db in
    try Player(...).insert(db)     // throws SQLITE_INTERRUPT
    try Player(...).insert(db)     // not executed
}                                  // throws SQLITE_INTERRUPT

try dbQueue.write { db in
    do {
        try Player(...).insert(db) // throws SQLITE_INTERRUPT
    } catch { }
}                                  // throws SQLITE_ABORT

try dbQueue.write { db in
    do {
        try Player(...).insert(db) // throws SQLITE_INTERRUPT
    } catch { }
    try Player(...).insert(db)     // throws SQLITE_ABORT
}                                  // throws SQLITE_ABORT
```

You can catch both `SQLITE_INTERRUPT` and `SQLITE_ABORT` errors:

```swift
do {
    try dbPool.write { db in ... }
} catch DatabaseError.SQLITE_INTERRUPT, DatabaseError.SQLITE_ABORT {
    // Oops, the database was interrupted.
}
```

For more information, see [Interrupt A Long-Running Query](https://www.sqlite.org/c3ref/interrupt.html).


## Avoiding SQL Injection

SQL injection is a technique that lets an attacker nuke your database.

> ![XKCD: Exploits of a Mom](https://imgs.xkcd.com/comics/exploits_of_a_mom.png)
>
> https://xkcd.com/327/

Here is an example of code that is vulnerable to SQL injection:

```swift
// BAD BAD BAD
let id = 1
let name = textField.text
try dbQueue.write { db in
    try db.execute(sql: "UPDATE students SET name = '\(name)' WHERE id = \(id)")
}
```

If the user enters a funny string like `Robert'; DROP TABLE students; --`, SQLite will see the following SQL, and drop your database table instead of updating a name as intended:

```sql
UPDATE students SET name = 'Robert';
DROP TABLE students;
--' WHERE id = 1
```

To avoid those problems, **never embed raw values in your SQL queries**. The only correct technique is to provide arguments to your raw SQL queries:

```swift
let name = textField.text
try dbQueue.write { db in
    // Good
    try db.execute(
        sql: "UPDATE students SET name = ? WHERE id = ?",
        arguments: [name, id])

    // Just as good
    try db.execute(
        sql: "UPDATE students SET name = :name WHERE id = :id",
        arguments: ["name": name, "id": id])
}
```

When you use [records](Records.md) and the [query interface](QueryInterface.md), GRDB always prevents SQL injection for you:

```swift
let id = 1
let name = textField.text
try dbQueue.write { db in
    if var student = try Student.fetchOne(db, id: id) {
        student.name = name
        try student.update(db)
    }
}
```


## Error Handling

GRDB can throw [DatabaseError](#databaseerror), [RecordError](Records.md#recorderror), [RowDecodingError](Records.md#rowdecodingerror), or crash your program with a [fatal error](#fatal-errors).

Considering that a local database is not some JSON loaded from a remote server, GRDB focuses on **trusted databases**. Dealing with [untrusted databases](#how-to-deal-with-untrusted-inputs) requires extra care.

- [DatabaseError](#databaseerror)
- [Fatal Errors](#fatal-errors)
- [How to Deal with Untrusted Inputs](#how-to-deal-with-untrusted-inputs)
- [Error Log](#error-log)


### DatabaseError

**DatabaseError** are thrown on SQLite errors:

```swift
do {
    try Pet(masterId: 1, name: "Bobby").insert(db)
} catch let error as DatabaseError {
    // The SQLite error code: 19 (SQLITE_CONSTRAINT)
    error.resultCode

    // The extended error code: 787 (SQLITE_CONSTRAINT_FOREIGNKEY)
    error.extendedResultCode

    // The eventual SQLite message: FOREIGN KEY constraint failed
    error.message

    // The eventual erroneous SQL query
    // "INSERT INTO pet (masterId, name) VALUES (?, ?)"
    error.sql

    // The eventual SQL arguments
    // [1, "Bobby"]
    error.arguments

    // Full error description
    // > SQLite error 19: FOREIGN KEY constraint failed -
    // > while executing `INSERT INTO pet (masterId, name) VALUES (?, ?)`
    error.description
}
```

**SQLite uses [results codes](https://www.sqlite.org/rescode.html) to distinguish between various errors**.

You can catch a DatabaseError and match on result codes:

```swift
do {
    try ...
} catch let error as DatabaseError {
    switch error {
    case DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY:
        // foreign key constraint error
    case DatabaseError.SQLITE_CONSTRAINT:
        // any other constraint error
    default:
        // any other database error
    }
}
```

You can also directly match errors on result codes:

```swift
do {
    try ...
} catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY {
    // foreign key constraint error
} catch DatabaseError.SQLITE_CONSTRAINT {
    // any other constraint error
} catch {
    // any other database error
}
```


### Fatal Errors

**Fatal errors notify that the program, or the database, has to be changed.**

They uncover programmer errors, false assumptions, and prevent misuses. Here are a few examples:

- **The code asks for a non-optional value, when the database contains NULL:**

    ```swift
    // fatal error: could not convert NULL to String.
    let name: String = row["name"]
    ```

    Solution: fix the contents of the database, use [NOT NULL constraints](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/columndefinition/notnull(onconflict:)), or load an optional:

    ```swift
    let name: String? = row["name"]
    ```

- **Conversion from database value to Swift type fails:**

    ```swift
    // fatal error: could not convert "Mom's birthday" to Date.
    let date: Date = row["date"]

    // fatal error: could not convert "" to URL.
    let url: URL = row["url"]
    ```

    Solution: fix the contents of the database, or use [DatabaseValue](SQLiteAPI.md#databasevalue) to handle all possible cases.

- **The database can't guarantee that the code does what it says:**

    ```swift
    // fatal error: table player has no unique index on column email
    try Player.deleteOne(db, key: ["email": "arthur@example.com"])
    ```

    Solution: add a unique index to the player.email column.

- **Database connections are not reentrant:**

    ```swift
    // fatal error: Database methods are not reentrant.
    dbQueue.write { db in
        dbQueue.write { db in
            ...
        }
    }
    ```

    Solution: avoid reentrancy, and instead pass a database connection along.


### How to Deal with Untrusted Inputs

Let's consider the code below:

```swift
let sql = "SELECT ..."

// Some untrusted arguments for the query
let arguments: [String: Any] = ...
let rows = try Row.fetchCursor(db, sql: sql, arguments: StatementArguments(arguments))

while let row = try rows.next() {
    // Some untrusted database value:
    let date: Date? = row[0]
}
```

It has two opportunities to throw fatal errors:

- **Untrusted arguments**: The dictionary may contain values that do not conform to the DatabaseValueConvertible protocol, or may miss keys required by the statement.
- **Untrusted database content**: The row may contain a non-null value that can't be turned into a date.

In such a situation, you can still avoid fatal errors by exposing and handling each failure point, one level down in the GRDB API:

```swift
// Untrusted arguments
if let arguments = StatementArguments(arguments) {
    let statement = try db.makeStatement(sql: sql)
    try statement.setArguments(arguments)

    var cursor = try Row.fetchCursor(statement)
    while let row = try iterator.next() {
        // Untrusted database content
        let dbValue: DatabaseValue = row[0]
        if dbValue.isNull {
            // Handle NULL
        if let date = Date.fromDatabaseValue(dbValue) {
            // Handle valid date
        } else {
            // Handle invalid date
        }
    }
}
```


### Error Log

**SQLite can be configured to invoke a callback function containing an error code and a terse error message whenever anomalies occur.**

This global error callback must be configured early in the lifetime of your application:

```swift
Database.logError = { (resultCode, message) in
    NSLog("%@", "SQLite error \(resultCode): \(message)")
}
```

> **Warning**: Database.logError must be set before any database connection is opened. This includes the connections that your application opens with GRDB, but also connections opened by other tools, such as third-party libraries. Setting it after a connection has been opened is an SQLite misuse, and has no effect.

See [The Error And Warning Log](https://sqlite.org/errlog.html) for more information.


## Unicode

SQLite lets you store unicode strings in the database.

However, SQLite does not provide any unicode-aware string transformations or comparisons.


### Unicode functions

The `UPPER` and `LOWER` built-in SQLite functions are not unicode-aware:

```swift
// "JéRôME"
try String.fetchOne(db, sql: "SELECT UPPER('Jérôme')")
```

GRDB extends SQLite with [SQL functions](CustomSQLFunctions.md) that call the Swift built-in string functions `capitalized`, `lowercased`, `uppercased`, `localizedCapitalized`, `localizedLowercased` and `localizedUppercased`:

```swift
// "JÉRÔME"
let uppercased = DatabaseFunction.uppercase
try String.fetchOne(db, sql: "SELECT \(uppercased.name)('Jérôme')")
```

Those unicode-aware string functions are also readily available in the [query interface](QueryInterface.md#sql-functions):

```swift
Player.select { $0.name.uppercased }
```


### String Comparison

SQLite compares strings in many occasions: when you sort rows according to a string column, or when you use a comparison operator such as `=` and `<=`.

The comparison result comes from a *collating function*, or *collation*. SQLite comes with three built-in collations that do not support Unicode: [binary, nocase, and rtrim](https://www.sqlite.org/datatype3.html#collation).

GRDB comes with five extra collations that leverage unicode-aware comparisons based on the standard Swift String comparison functions and operators:

- `unicodeCompare` (uses the built-in `<=` and `==` Swift operators)
- `caseInsensitiveCompare`
- `localizedCaseInsensitiveCompare`
- `localizedCompare`
- `localizedStandardCompare`

A collation can be applied to a table column. All comparisons involving this column will then automatically trigger the comparison function:

```swift
try db.create(table: "player") { t in
    // Guarantees case-insensitive email unicity
    t.column("email", .text).unique().collate(.nocase)

    // Sort names in a localized case insensitive way
    t.column("name", .text).collate(.localizedCaseInsensitiveCompare)
}

// Players are sorted in a localized case insensitive way:
let players = try Player.order(\.name).fetchAll(db)
```

> **Warning**: SQLite *requires* host applications to provide the definition of any collation other than binary, nocase and rtrim. When a database file has to be shared or migrated to another SQLite library of platform (such as the Android version of your application), make sure you provide a compatible collation.

If you can't or don't want to define the comparison behavior of a column, you can still use an explicit collation in SQL requests and in the [query interface](QueryInterface.md):

```swift
let collation = DatabaseCollation.localizedCaseInsensitiveCompare
let players = try Player.fetchAll(db,
    sql: "SELECT * FROM player ORDER BY name COLLATE \(collation.name))")
let players = try Player.order { $0.name.collating(collation) }.fetchAll(db)
```

**You can also define your own collations**:

```swift
let collation = DatabaseCollation("customCollation") { (lhs, rhs) -> NSComparisonResult in
    // return the comparison of lhs and rhs strings.
}

// Make the collation available to a database connection
var config = Configuration()
config.prepareDatabase { db in
    db.add(collation: collation)
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```


## Memory Management

Both SQLite and GRDB use non-essential memory that help them perform better.

You can reclaim this memory with the `releaseMemory` method:

```swift
// Release as much memory as possible.
dbQueue.releaseMemory()
dbPool.releaseMemory()
```

This method blocks the current thread until all current database accesses are completed, and the memory collected.

You can also release memory in an asynchronous way:

```swift
// On a DatabaseQueue
dbQueue.asyncWriteWithoutTransaction { db in
    db.releaseMemory()
}

// On a DatabasePool
dbPool.releaseMemoryEventually()
```

`DatabasePool.releaseMemoryEventually()` does not block the current thread, and does not prevent concurrent database accesses. In exchange for this convenience, you don't know when memory has been freed.


### Memory Management on iOS

**The iOS operating system likes applications that do not consume much memory.**

[Database queues](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasequeue) and [pools](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasepool) automatically free non-essential memory when the application receives a memory warning, and when the application enters background.

You can opt out of this automatic memory management:

```swift
var config = Configuration()
config.automaticMemoryManagement = false
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config) // or DatabasePool
```
