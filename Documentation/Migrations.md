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

See the [DatabaseMigrator reference](http://groue.github.io/GRDB.swift/docs/5.23/Structs/DatabaseMigrator.html) for more migrator methods.


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

If SQLite does not directly support all kinds of schema alterations, you can make arbitrary changes to the schema design of any table using a sequence of operations, as in the example below:

```swift
migrator.registerMigration("Add NOT NULL check on player.name") { db in
    try db.create(table: "new_player") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
    }
    try db.execute(sql: "INSERT INTO new_player SELECT * FROM player")
    try db.drop(table: "player")
    try db.rename(table: "new_player", to: "player")
}
```

This technique is described in SQLite documentation: [Making Other Kinds Of Table Schema Changes](https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes).

The detailed sequence of operations is described below, some of them are performed by GRDB, and others by your code:

1. GRDB: If foreign key constraints are enabled, disable them using PRAGMA foreign_keys=OFF.

2. GRDB: Start a transaction.

3. **Your code**: Remember the format of all indexes, triggers, and views associated with table X. This information will be needed in step 8 below. One way to do this is to run a query like the following: `SELECT type, sql FROM sqlite_schema WHERE tbl_name='X'`.

4. **Your code**: Use `CREATE TABLE` to construct a new table "new_X" that is in the desired revised format of table X. Make sure that the name "new_X" does not collide with any existing table name, of course.

5. **Your code**: Transfer content from X into new_X using a statement like: `INSERT INTO new_X SELECT ... FROM X`.

6. **Your code**: Drop the old table X: `DROP TABLE X`.

7. **Your code**: Change the name of new_X to X using: `ALTER TABLE new_X RENAME TO X`.

8. **Your code**: Use `CREATE INDEX`, `CREATE TRIGGER`, and `CREATE VIEW` to reconstruct indexes, triggers, and views associated with table X. Perhaps use the old format of the triggers, indexes, and views saved from step 3 above as a guide, making changes as appropriate for the alteration.

9. **Your code**: If any views refer to table X in a way that is affected by the schema change, then drop those views using `DROP VIEW` and recreate them with whatever changes are necessary to accommodate the schema change using `CREATE VIEW`.

10. GRDB: If foreign key constraints were originally enabled then run [`PRAGMA foreign_key_check`](https://www.sqlite.org/pragma.html#pragma_foreign_key_check) to verify that the schema change did not break any foreign key constraints.

11. GRDB: Commit the transaction started in step 2.

12. GRDB: If foreign keys constraints were originally enabled, reenable them now.

> :point_up: **Note**: Take care to follow the procedure above precisely, in the same order, or you might corrupt triggers, views, and foreign key constraints. Have a second look at [Making Other Kinds Of Table Schema Changes](https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes) if necessary.
>
> :point_up: **Note**: By default, all migrations perform, at step 10, a full check of all foreign keys in your database. When your database is big, those checks may have a noticeable impact on migration performances. See [Foreign Key Checks] for a discussion of your ways to avoid this toll.


## Foreign Key Checks

SQLite makes it [difficult](https://www.sqlite.org/lang_altertable.html) to perform some schema changes, and this creates very undesired churn w.r.t. foreign keys. GRDB makes its best to hide those problems to you, but you might have to deal with them one day, especially if your database becomes *very big*:

You'll need to read this chapter if you are looking for a mitigation to the time spent by migrations performing foreign key checks. You'll know this by instrumenting your migrations, and looking for the time spent in the `checkForeignKeys` method. See [Advanced Database Schema Changes] right above to know what are those foreign key checks.

**Your first mitigation technique is immediate foreign key checks.**

If you register a migration with `.immediate` foreign key checks, the migration will not temporarily disable foreign keys, and won't need to perform a deferred full check of all foreign keys in your database:

```swift
migrator.registerMigration("make it faster please", foreignKeyChecks: .immediate) { db in
    try db.create(table: ...)                    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ...
}
```

Such a migration is much faster, and it still guarantees that no foreign key constraint is broken. But it can not run the kind of migrations covered by [Making Other Kinds Of Table Schema Changes](https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes). In this case, you'll need to use the second mitigation technique:

**Your second mitigation technique is to disable deferred foreign key checks.**

You can ask the migrator to stop performing foreign key checks for all newly registered migrations.

:warning: If you use this technique, your app becomes responsible for preventing foreign key violations from being committed to disk!

```swift
migrator = migrator.disablingDeferredForeignKeyChecks()

// From now on, migrations are unchecked!
migrator.registerMigration("fast but unchecked") { db in ... }
```

In order to prevent foreign key violations from being committed to disk, you can:

- Run migrations with immediate foreign key check, as long as they do not require the technique described by [Making Other Kinds Of Table Schema Changes](https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes):

    ```swift
    migrator = migrator.disablingDeferredForeignKeyChecks()
    migrator.registerMigration("unchecked") { db in ... }
    migrator.registerMigration("checked", foreignKeyChecks: .immediate) { db in ... }
    ```

- Perform foreign key checks on some tables only:

    ```swift
    migrator = migrator.disablingDeferredForeignKeyChecks()
    migrator.registerMigration("partially checked") { db in
        ...
        
        // Throws an error and stops migrations if there exists a
        // foreign key violation in the 'player' table.
        try db.checkForeignKeys(in: "player")
    }
    ```

- Perform a full check of foreign keys, eventually:
    
    ```swift
    try migrator.migrate(dbQueue)
    
    // Throws an error if there exists any foreign key violation.
    try dbQueue.read { db in
        try db.checkForeignKeys()
    }
    ```

In order to check for foreign key violations, the `checkForeignKeys()` and `checkForeignKeys(in:)` methods are recommended over the raw use of the [`PRAGMA foreign_key_check`](https://www.sqlite.org/pragma.html#pragma_foreign_key_check). Those methods throw a nicely detailed DatabaseError that contains a lot of debugging information:

```swift
// SQLite error 19: FOREIGN KEY constraint violation - from player(teamId) to team(id),
// in [id:1 teamId:2 name:"O'Brien" score:1000]
try db.checkForeignKeys()
```

You can also iterate a lazy [cursor](../README.md#cursors) of all individual foreign key violations found in the database:

```swift
let violations = try db.foreignKeyViolations()
while let violation = try violations.next() {
    // The name of the table that contains the `REFERENCES` clause
    violation.originTable
    
    // The rowid of the row that contains the invalid `REFERENCES` clause, or
    // nil if the origin table is a `WITHOUT ROWID` table.
    violation.originRowID
    
    // The name of the table that is referred to.
    violation.destinationTable
    
    // The id of the specific foreign key constraint that failed. This id
    // matches `ForeignKeyInfo.id`. See `Database.foreignKeys(on:)` for more
    // information.
    violation.foreignKeyId
    
    // Plain description:
    // "FOREIGN KEY constraint violation - from player to team, in rowid 1"
    String(describing: violation)
    
    // Rich description:
    // "FOREIGN KEY constraint violation - from player(teamId) to team(id),
    //  in [id:1 teamId:2 name:"O'Brien" score:1000]"
    try violation.failureDescription(db)
    
    // Turn violation into a DatabaseError
    throw violation.databaseError(db)
}
```

## Asynchronous Migrations

`DatabaseMigrator` provides the following ways to migrate a database in an asynchronous way.

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
