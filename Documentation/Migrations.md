# Migrations

**Migrations** are a convenient way to alter your database schema over time in a consistent and easy way.

Migrations run in order, once and only once. When a user upgrades your application, only non-applied migrations are run.

Inside each migration, you typically [define and update your database tables](../README.md#database-schema) according to your evolving application needs:

```swift
var migrator = DatabaseMigrator()

// 1st migration
migrator.registerMigration("v1") { db in
    try db.create(table: "author") { t in ... }
    try db.create(table: "book") { t in ... }
    try db.create(index: ...)
}

// 2nd migration
migrator.registerMigration("v2") { db in
    try db.alter(table: "author") { t in ... }
}

// Migrations for future versions will be inserted here:
//
// // 3rd migration
// migrator.registerMigration("...") { db in
//     ...
// }
```

**Each migration runs in a separate transaction.** Should one throw an error, its transaction is rollbacked, subsequent migrations do not run, and the error is eventually thrown by `migrator.migrate(dbQueue)`.

**Migrations run with deferred foreign key checks.** This means that eventual foreign key violations are only checked at the end of the migration (and they make the migration fail).

**The memory of applied migrations is stored in the database itself** (in a reserved table).

You migrate the database up to the latest version with the `migrate(_:)` method:

```swift
try migrator.migrate(dbQueue) // or migrator.migrate(dbPool)
```

Migrate a database up to a specific version (useful for testing):

```swift
try migrator.migrate(dbQueue, upTo: "v2")

// Migrations can only run forward:
try migrator.migrate(dbQueue, upTo: "v2")
try migrator.migrate(dbQueue, upTo: "v1")
// ^ fatal error: database is already migrated beyond migration "v1"
```

When several versions of your app are deployed in the wild, you may want to perform extra checks:

```swift
try dbQueue.read { db in
    // Readonly apps may want to check if database lacks expected migrations:
    if try migrator.hasCompletedMigrations(db) == false {
        // database too old
    }
    
    // All apps may want to check if database contains unknown (future) migrations:
    if try migrator.hasBeenSuperseded(db) {
        // database too new
    }
}
```

See the [DatabaseMigrator reference](http://groue.github.io/GRDB.swift/docs/5.3/Structs/DatabaseMigrator.html) for more migrator methods.


## The `eraseDatabaseOnSchemaChange` Option

A DatabaseMigrator can automatically wipe out the full database content, and recreate the whole database from scratch, if it detects that migrations have changed their definition:

```swift
var migrator = DatabaseMigrator()
migrator.eraseDatabaseOnSchemaChange = true
```

> :warning: **Warning**: This option can destroy your precious users' data!

Setting `eraseDatabaseOnSchemaChange` is useful during application development, as you are still designing migrations, and the schema changes often.

It is recommended that this option does not ship in the released application:

```swift
var migrator = DatabaseMigrator()
#if DEBUG
// Speed up development by nuking the database when migrations change
migrator.eraseDatabaseOnSchemaChange = true
#endif
```

The `eraseDatabaseOnSchemaChange` option triggers a recreation of the database if and only if:

- A migration has been removed, or renamed.
- A *schema change* is detected. A schema change is any difference in the `sqlite_master` table, which contains the SQL used to create database tables, indexes, triggers, and views.


## Advanced Database Schema Changes

SQLite does not support many schema changes, and won't let you drop a table column with "ALTER TABLE ... DROP COLUMN ...", for example.

Yet any kind of schema change is still possible, by recreating tables:

```swift
migrator.registerMigration("AddNotNullCheckOnName") { db in
    // Add a NOT NULL constraint on player.name:
    try db.create(table: "new_player") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
    }
    try db.execute(sql: "INSERT INTO new_player SELECT * FROM player")
    try db.drop(table: "player")
    try db.rename(table: "new_player", to: "player")
}
```


