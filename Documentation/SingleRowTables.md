Single-Row Tables
=================

Let's talk about database tables that should contain a single row.

Such tables can store configuration values, user preferences, and generally some global application state. They are a suitable alternative to `UserDefaults` in some applications, especially when configuration refers to values found in other database tables, and database integrity is a concern.

An alternative way to store such configuration is a table of key-value pairs: two columns, and one row for each configuration value. This technique works, but it has a few drawbacks: you will have to deal with the various types of configuration values (strings, integers, dates, etc), and you won't be able to define foreign keys. This is why we won't explore key-value tables.

This guide helps you implementing a single-row table with GRDB, with recommendations on the database schema, migrations, and the design of a matching [record] type.

- [The Single-Row Table]
- [The Single-Row Record]
- [Wrap-Up]


## The Single-Row Table

As always with GRDB, everything starts at the level of the database schema. Putting the robust SQLite on our side is always a good idea, because we have to write less code, and this helps shipping less bugs.

We want to instruct SQLite that our table must never contain more than one row. We will never have to wonder what to do if we were unlucky enough to find two rows with conflicting values in this table.

SQLite is not able to guarantee that the table is never empty, so we have to deal with two cases: either the table is empty, or it contains one row.

Those two cases can create a nagging question for the application. By default, inserts fail when the row already exists, and updates fail when the table is empty. In order to avoid those errors, we will have the app perform an insert in case of a failed update (in the [The Single-Row Record] chapter). And we instruct SQLite to just replace the eventual existing row in case of conflicting inserts:

```swift
// CREATE TABLE appConfiguration (
//   id INTEGER PRIMARY KEY ON CONFLICT REPLACE CHECK (id = 1),
//   flag BOOLEAN NOT NULL,
//   ...)
try db.create(table: "appConfiguration") { t in
    // Single row guarantee
    t.column("id", .integer)
        // Have inserts replace the existing row
        .primaryKey(onConflict: .replace)
        // Make sure the id column is always 1
        .check { $0 == 1 }
    
    // The configuration colums
    t.column("flag", .boolean).notNull()
    // ... other columns
}
```

When you use [migrations], you may wonder if it is a good idea or not to perform an initial insert just after the table is created. Well, this is not recommended:

```swift
// NOT RECOMMENDED
migrator.registerMigration("appConfiguration") { db in
    try db.create(table: "appConfiguration") { t in
        // Single row guarantee
        t.column("id", .integer).primaryKey(onConflict: .replace).check { $0 == 1 }
        
        // Define sensible defaults for each column
        t.column("flag", .boolean).notNull()
            .defaults(to: false)
        // ... other columns
    }
    
    // Populate the table
    try db.execute(sql: "INSERT INTO appConfiguration DEFAULT VALUES")
}
```

It is not a good idea to populate the table in a migration, for two reasons:

1. This is not a hard guarantee that the table will never be empty. As a consequence, this won't prevent your Swift code from dealing with the possibility of a missing row. On top of that, the Swift code that deals with the missing row may not use the same default values as the SQLite schema (a [DRY] violation), with unclear consequences.

2. Migrations that are shipped in the wild should *never* change, because you want to control the state of the databases installed on your users' devices, regardless of the application version they install first, regardless of how many application versions are skipped when they download an upgrade, etc. By inserting an initial row in a migration, you make it difficult for your application to adjust the sensible default values in the future, while keeping a clear idea of the various installation and upgrade scenarios.

The recommended migration creates the table, nothing more:

```swift
// RECOMMENDED
migrator.registerMigration("appConfiguration") { db in
    try db.create(table: "appConfiguration") { t in
        // Single row guarantee
        t.column("id", .integer).primaryKey(onConflict: .replace).check { $0 == 1 }
        
        // The configuration colums
        t.column("flag", .boolean).notNull()
        // ... other columns
    }
}
```


## The Single-Row Record

Now that the database schema has been defined, we can define the [record] type that will help the application access the single row:

```swift
struct AppConfiguration: Codable {
    // Support for the single row guarantee
    private var id = 1
    
    // The configuration properties
    var flag: Bool
    // ... other properties
}
```

In case the database table would be empty, we need a default configuration:

```swift
extension AppConfiguration {
    /// The default configuration
    static let `default` = AppConfiguration(flag: false, ...)
}
```

We make our record able to access the database:

```swift
extension AppConfiguration: FetchableRecord, PersistableRecord {
```

We have seen in the [The Single-Row Table] chapter that by default, updates throw an error if the database table is empty. To avoid this error, we instruct GRDB to perform an insert in case of a failed update (see [Persistence Methods] for more information):

```swift
    // Customize the default PersistableRecord behavior
    func update(_ db: Database, columns: Set<String>) throws {
        do {
            try performUpdate(db, columns: columns)
        } catch PersistenceError.recordNotFound {
            // No row was updated: perform an insert
            try performInsert(db)
        }
    }
```

The standard GRDB method `fetchOne` returns an optional which is nil when the database table is empty. As a convenience, let's define a method that returns a non-optional (replacing the missing row with `default`):

```swift
    /// Returns the persisted configuration, or the default one if the
    /// database table is empty.
    static func fetch(_ db: Database) throws -> AppConfiguration {
        try fetchOne(db) ?? .default
    }
}
```

And that's it! Now we can use our singleton record:

```swift
// READ
let config = try dbQueue.read { db in
    try AppConfiguration.fetch(db)
}
if config.flag {
    // ...
}

// WRITE
try dbQueue.write { db in
    var config = try AppConfiguration.fetch(db)
    
    // Update some config values
    try config.updateChanges(db) {
        $0.flag = true
    }
    
    // Other possible ways to write config:
    try config.update(db)
    try config.save(db)
    try config.insert(db)
}
```

The three `update`, `save` and `insert` methods can be used interchangeably: all three make sure the configuration is stored in the database.

The `updateChanges` method only updates the values changed by its closure argument (and performs an insert if the database table is empty).

See [Persistence Methods] for more information.


## Wrap-Up

We all love to copy and paste, don't we? Just customize the template code below:

```swift
// Table creation
try db.create(table: "appConfiguration") { t in
    // Single row guarantee
    t.column("id", .integer).primaryKey(onConflict: .replace).check { $0 == 1 }
    
    // The configuration columns
    t.column("flag", .boolean).notNull()
    // ... other columns
}
```

```swift
//
// AppConfiguration.swift
//

import GRDB

struct AppConfiguration: Codable {
    // Support for the single row guarantee
    private var id = 1
    
    // The configuration properties
    var flag: Bool
    // ... other properties
}

extension AppConfiguration {
    /// The default configuration
    static let `default` = AppConfiguration(flag: false, ...)
}

// Database Access
extension AppConfiguration: FetchableRecord, PersistableRecord {
    // Customize the default PersistableRecord behavior
    func update(_ db: Database, columns: Set<String>) throws {
        do {
            try performUpdate(db, columns: columns)
        } catch PersistenceError.recordNotFound {
            // No row was updated: perform an insert
            try performInsert(db)
        }
    }
    
    /// Returns the persisted configuration, or the default one if the
    /// database table is empty.
    static func fetch(_ db: Database) throws -> AppConfiguration {
        try fetchOne(db) ?? .default
    }
}
```


[migrations]: Migrations.md
[record]: ../README.md#records
[The Single-Row Table]: #the-single-row-table
[The Single-Row Record]: #the-single-row-record
[Wrap-Up]: #wrap-up
[DRY]: https://en.wikipedia.org/wiki/Don%27t_repeat_yourself
[Persistence Methods]: ../README.md#persistence-methods
