# The Database Schema

Learn how to define the database schema.

## Overview

You can directly define the database schema when you open a database, as below:

```swift
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

try dbQueue.write { db in
    try db.create(table: "player", options: .ifNotExists) { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
        t.column("score", .integer).notNull()
    }
}
```

But you should prefer wrapping all your schema changes in <doc:Migrations>, when you plan to upgrade the database schema in future versions of your app.

## Schema Alterations

SQLite directly supports a [set of schema alterations](https://www.sqlite.org/lang.html).

Many of them are available as Swift methods such as ``Database/create(table:options:body:)``, listed below.

When the schema alteration you need is not available as a Swift method, use a raw SQL query (for creating views or triggers, for example).

When you need to modify a table in a way that is not directly supported by SQLite, or not available on your target operating system, you will need to recreate the database table. See <doc:Migrations> for the detailed procedure.

> Tip: Prefer Swift methods over raw SQL queries. This helps the compiler check if features are available on the SQLite version that ships on the target operating system. For example:
>
> - Dropping a table column requires SQLite 3.35+ (iOS 15.0, macOS 12.0).
> - [Strict tables](https://www.sqlite.org/stricttables.html) require SQLite 3.37+ (iOS 15.4, macOS 12.4).

## Topics

### Database Tables

- ``Database/alter(table:body:)``
- ``Database/create(table:options:body:)``
- ``Database/create(virtualTable:ifNotExists:using:)``
- ``Database/create(virtualTable:ifNotExists:using:_:)``
- ``Database/drop(table:)``
- ``Database/dropFTS4SynchronizationTriggers(forTable:)``
- ``Database/rename(table:to:)``
- ``Database/ColumnType``
- ``Database/ConflictResolution``
- ``Database/ForeignKeyAction``
- ``TableAlteration``
- ``TableDefinition``
- ``TableOptions``
- ``VirtualTableModule``

### Database Indexes

- ``Database/create(index:on:columns:options:condition:)``
- ``Database/drop(index:)``
- ``IndexOptions``

### Querying the Database Schema

- ``Database/columns(in:)``
- ``Database/foreignKeys(on:)``
- ``Database/indexes(on:)``
- ``Database/isGRDBInternalTable(_:)``
- ``Database/isSQLiteInternalTable(_:)``
- ``Database/primaryKey(_:)``
- ``Database/schemaVersion()``
- ``Database/table(_:hasUniqueKey:)``
- ``Database/tableExists(_:)``
- ``Database/triggerExists(_:)``
- ``Database/viewExists(_:)``
- ``ColumnInfo``
- ``ForeignKeyInfo``
- ``IndexInfo``
- ``PrimaryKeyInfo``

### Integrity Checks

- ``Database/checkForeignKeys()``
- ``Database/checkForeignKeys(in:)``
- ``Database/foreignKeyViolations()``
- ``Database/foreignKeyViolations(in:)``
- ``ForeignKeyViolation``
