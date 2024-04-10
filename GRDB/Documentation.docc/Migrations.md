# Migrations

Migrations allow you to evolve your database schema over time.

## Overview

You can think of migrations as being 'versions' of the database. A database schema starts off in an empty state, and each migration adds or removes tables, columns, or entries.

GRDB can update the database schema along this timeline, bringing it from whatever point it is in the history to the latest version. When a user upgrades your application, only non-applied migrations are run.

You setup migrations in a ``DatabaseMigrator`` instance. For example:

```swift
var migrator = DatabaseMigrator()

// 1st migration
migrator.registerMigration("Create authors") { db in
    try db.create(table: "author") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("creationDate", .datetime)
        t.column("name", .text)
    }
}

// 2nd migration
migrator.registerMigration("Add books and author.birthYear") { db in
    try db.create(table: "book") { t in
        t.autoIncrementedPrimaryKey("id")
        t.belongsTo("author").notNull()
        t.column("title", .text).notNull()
    }

    try db.alter(table: "author") { t in
        t.add(column: "birthYear", .integer)
    }
}
```

To migrate a database, open a connection (see <doc:DatabaseConnections>), and call the ``DatabaseMigrator/migrate(_:)`` method:

```swift
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

// Migrate the database up to the latest version
try migrator.migrate(dbQueue)
```

You can also migrate a database up to a specific version (useful for testing):

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
    // Read-only apps or extensions may want to check if the database
    // lacks expected migrations:
    if try migrator.hasCompletedMigrations(db) == false {
        // database too old
    }
    
    // Some apps may want to check if the database
    // contains unknown (future) migrations:
    if try migrator.hasBeenSuperseded(db) {
        // database too new
    }
}
```

**Each migration runs in a separate transaction.** Should one throw an error, its transaction is rollbacked, subsequent migrations do not run, and the error is eventually thrown by ``DatabaseMigrator/migrate(_:)``.

**Migrations run with deferred foreign key checks.** This means that eventual foreign key violations are only checked at the end of the migration (and they make the migration fail). See <doc:Migrations#Foreign-Key-Checks> below for more information.

**The memory of applied migrations is stored in the database itself** (in a reserved table).

## Defining the Database Schema from a Migration

See <doc:DatabaseSchema> for the methods that define the database schema. For example:

```swift
migrator.registerMigration("Create authors") { db in
    try db.create(table: "author") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("creationDate", .datetime)
        t.column("name", .text)
    }
}
```

When you need to modify a table in a way that is not directly supported by SQLite, or not available on your target operating system, you will need to recreate the database table.

For example:

```swift
migrator.registerMigration("Add NOT NULL check on author.name") { db in
    try db.create(table: "new_author") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("creationDate", .datetime)
        t.column("name", .text).notNull()
    }
    try db.execute(sql: "INSERT INTO new_author SELECT * FROM author")
    try db.drop(table: "author")
    try db.rename(table: "new_author", to: "author")
}
```

The detailed sequence of operations for recreating a database table from a migration is:

1. When relevant, remember the format of all indexes, triggers, and views associated with table X. This information will be needed in steps 6 and 7 below. One way to do this is to run a query like the following: `SELECT type, sql FROM sqlite_schema WHERE tbl_name='X'`.

2. Use `CREATE TABLE` to construct a new table "new_X" that is in the desired revised format of table X. Make sure that the name "new_X" does not collide with any existing table name, of course.

3. Transfer content from X into new_X using a statement like: `INSERT INTO new_X SELECT ... FROM X`.

4. Drop the old table X: `DROP TABLE X`.

5. Change the name of new_X to X using: `ALTER TABLE new_X RENAME TO X`.

6. When relevant, use `CREATE INDEX`, `CREATE TRIGGER`, and `CREATE VIEW` to reconstruct indexes, triggers, and views associated with table X. Perhaps use the old format of the triggers, indexes, and views saved from step 3 above as a guide, making changes as appropriate for the alteration.

7. If any views refer to table X in a way that is affected by the schema change, then drop those views using `DROP VIEW` and recreate them with whatever changes are necessary to accommodate the schema change using `CREATE VIEW`.

> Important: When recreating a table, be sure to follow the above procedure exactly, in the given order, or you might corrupt triggers, views, and foreign key constraints.
>
> When you want to recreate a table _outside of a migration_, check the full procedure detailed in the [Making Other Kinds Of Table Schema Changes](https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes) section of the SQLite documentation.

## Good Practices for Defining Migrations

**A good migration is a migration that is never modified once it has shipped.**

It is much easier to control the schema of all databases deployed on users' devices when migrations define a stable timeline of schema versions. For this reason, it is recommended that migrations define the database schema with **strings**:

```swift
migrator.registerMigration("Create authors") { db in
    // RECOMMENDED
    try db.create(table: "author") { t in
        t.autoIncrementedPrimaryKey("id")
        ...
    }

    // NOT RECOMMENDED
    try db.create(table: Author.databaseTableName) { t in
        t.autoIncrementedPrimaryKey(Author.Columns.id.name)
        ...
    }
}
```

In other words, migrations should talk to the database, only to the database, and use the database language. This makes sure the Swift code of any given migrations will never have to change in the future.

Migrations and the rest of the application code do not live at the same "moment". Migrations describe the past states of the database, while the rest of the application code targets the latest one only. This difference is the reason why **migrations should not depend on application types.**

## The eraseDatabaseOnSchemaChange Option

A `DatabaseMigrator` can automatically wipe out the full database content, and recreate the whole database from scratch, if it detects that migrations have changed their definition.

Setting ``DatabaseMigrator/eraseDatabaseOnSchemaChange`` is useful during application development, as you are still designing migrations, and the schema changes often:

- A migration is removed, or renamed.
- A schema change is detected: any difference in the `sqlite_master` table, which contains the SQL used to create database tables, indexes, triggers, and views.

> Warning: This option can destroy your precious users' data!

It is recommended that this option does not ship in the released application: hide it behind `#if DEBUG` as below.

```swift
var migrator = DatabaseMigrator()
#if DEBUG
// Speed up development by nuking the database when migrations change
migrator.eraseDatabaseOnSchemaChange = true
#endif
```

## Foreign Key Checks

By default, each migration temporarily disables foreign keys, and performs a full check of all foreign keys in the database before it is committed on disk.

When the database becomes very big, those checks may have a noticeable impact on migration performances. You'll know this by profiling migrations, and looking for the time spent in the `checkForeignKeys` method.

You can make those migrations faster, but this requires a little care.

**Your first mitigation technique is immediate foreign key checks.**

When you register a migration with `.immediate` foreign key checks, the migration does not temporarily disable foreign keys, and does not need to perform a deferred full check of all foreign keys in the database:

```swift
migrator.registerMigration("Fast migration", foreignKeyChecks: .immediate) { db in ... }
```

Such a migration is faster, and it still guarantees database integrity. But it must only execute schema alterations directly supported by SQLite. Migrations that recreate tables as described in <doc:Migrations#Defining-the-Database-Schema-from-a-Migration> **must not** run with immediate foreign keys checks. You'll need to use the second mitigation technique:

**Your second mitigation technique is to disable deferred foreign key checks.**

You can ask the migrator to stop performing foreign key checks for all newly registered migrations:

```swift
migrator = migrator.disablingDeferredForeignKeyChecks()
```

Migrations become unchecked by default, and run faster. But your app becomes responsible for preventing foreign key violations from being committed to disk:

```swift
migrator = migrator.disablingDeferredForeignKeyChecks()
migrator.registerMigration("Fast but unchecked migration") { db in ... }
```

To prevent a migration from committing foreign key violations on disk, you can:

- Register the migration with immediate foreign key checks, as long as it does not recreate tables as described in <doc:Migrations#Defining-the-Database-Schema-from-a-Migration>:

    ```swift
    migrator = migrator.disablingDeferredForeignKeyChecks()
    migrator.registerMigration("Fast and checked migration", foreignKeyChecks: .immediate) { db in ... }
    ```

- Perform foreign key checks on some tables only, before the migration is committed on disk:

    ```swift
    migrator = migrator.disablingDeferredForeignKeyChecks()
    migrator.registerMigration("Partially checked") { db in
        ...
        
        // Throws an error and stops migrations if there exists a
        // foreign key violation in the 'book' table.
        try db.checkForeignKeys(in: "book")
    }
    ```

As in the above example, check for foreign key violations with the ``Database/checkForeignKeys()`` and ``Database/checkForeignKeys(in:in:)`` methods. They throw a nicely detailed ``DatabaseError`` that contains a lot of debugging information:

```swift
// SQLite error 19: FOREIGN KEY constraint violation - from book(authorId) to author(id),
// in [id:1 authorId:2 name:"Moby-Dick"]
try db.checkForeignKeys(in: "book")
```

Alternatively, you can deal with each individual violation by iterating a cursor of ``ForeignKeyViolation``.

## Topics

### DatabaseMigrator

- ``DatabaseMigrator``
