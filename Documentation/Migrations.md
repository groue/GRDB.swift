# Migrations

**Migrations** are a convenient way to alter your database schema over time in a consistent and easy way.

- [Migrations Overview]
- [The `eraseDatabaseOnSchemaChange` Option]
- [Advanced Database Schema Changes]
- [Foreign Key Checks]
- [Asynchronous Migrations]


## Migrations Overview

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

**Migrations run with deferred foreign key checks.** This means that eventual foreign key violations are only checked at the end of the migration (and they make the migration fail). See [Foreign Key Checks] below for more information.

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

See the [DatabaseMigrator reference](http://groue.github.io/GRDB.swift/docs/5.12/Structs/DatabaseMigrator.html) for more migrator methods.


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

Please check [Making Other Kinds Of Table Schema Changes](https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes) in the SQLite documentation for further information.


## Foreign Key Checks

You'll need to read this chapter if your migrations spend a lot of time performing foreign key checks, and you are looking for a mitigation.

What are we talking about? SQLite has [limited support](https://www.sqlite.org/lang_altertable.html) for database schema change, and this unfortunately creates unwanted churn regarding foreign keys. In order to accept any kind of schema changes, GRDB migration runs, by default, with deferred foreign key checks. They precisely apply the technique described in [Making Other Kinds Of Table Schema Changes](https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes):

1. Disable foreign keys
2. Start a transaction
3. Apply migration
4. Run [`PRAGMA foreign_key_check`](https://www.sqlite.org/pragma.html#pragma_foreign_key_check) to verify that the schema change did not break any foreign key constraints.
5. Commit
6. Reenable foreign keys

The step 4 can take a long time.

**Mitigation technique 1: immediate foreign key checks**

If you register a migration with `.immediate` foreign key checks, the migration will not disable foreign keys, and avoid the slow `PRAGMA foreign_key_check`:

```swift
migrator.registerMigration("slow", foreignKeyChecks: .immediate) { db in ... }
```

1. Start a transaction
2. Apply migration
3. Commit

Such a migration still guarantees that no foreign key constraint is broken. But it can not run the kind of migrations covered by [Making Other Kinds Of Table Schema Changes](https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes).

**Mitigation technique 2: unsafely disable deferred foreign key checks**

You can ask the migrator to never run `PRAGMA foreign_key_check` for all newly registered migrations:

```swift
migrator = migrator.unsafeWithoutDeferredForeignKeyChecks()
migrator.registerMigration("unchecked") { db in ... }
```

1. Disable foreign keys
2. Start a transaction
3. Apply migration
4. Commit
5. Reenable foreign keys

You keep the ability to run any kind of migration. But the migrator can no longer guarantees that foreign key constraints are honored :warning:

Individual migrations can still immediately check their foreign keys (as long as they do not require the technique described by [Making Other Kinds Of Table Schema Changes](https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes)):

```swift
migrator = migrator.unsafeWithoutDeferredForeignKeyChecks()
migrator.registerMigration("unchecked") { db in ... }
migrator.registerMigration("checked", foreignKeyChecks: .immediate) { db in ... }
```

Since such a migrator does not guarantee that foreign key constraints are honored, you may want to check them at some point, with [`PRAGMA foreign_key_check`](https://www.sqlite.org/pragma.html#pragma_foreign_key_check):

```swift
try migrator.migrate(dbQueue)
let foreignKeyViolationExists = try dbQueue.read { db 
    try Row.fetchCursor(db, sql: "PRAGMA foreign_key_check").isEmpty() == false
}
if foreignKeyViolationExists {
    // Well, too bad
}
```


## Asynchronous Migrations

`DatabaseMigrator` provides two ways to migrate a database in an asynchronous way.

The `asyncMigrate(_:completion:)` method:

```swift
// Completes in a protected dispatch queue that can write in the database
migrator.asyncMigrate(dbQueue, completion: { db, error in
    if let error = error {
        // Some error occurred during migrations
    }
})
```

The `migratePublisher(_:receiveOn:)` [Combine](https://developer.apple.com/documentation/combine) publisher:

```swift
// DatabasePublishers.Migrate
let publisher = migrator.migratePublisher(dbQueue)
```

This publisher completes on the main queue, unless you provide a specific [scheduler](https://developer.apple.com/documentation/combine/scheduler) to the `receiveOn` argument.



[Migrations Overview]: #migrations-overview
[The `eraseDatabaseOnSchemaChange` Option]: #the-erasedatabaseonschemachange-option
[Advanced Database Schema Changes]: #advanced-database-schema-changes
[Foreign Key Checks]: #foreign-key-checks
[Asynchronous Migrations]: #asynchronous-migrations
