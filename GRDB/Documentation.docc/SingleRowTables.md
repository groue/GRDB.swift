# Single-Row Tables

The setup for database tables that should contain a single row.

## Overview

Database tables that contain a single row can store configuration values, user preferences, and generally some global application state.

They are a suitable alternative to `UserDefaults` in some applications, especially when configuration refers to values found in other database tables, and database integrity is a concern.

A possible way to store such configuration is a table of key-value pairs: two columns, and one row for each configuration value. This technique works, but it has a few drawbacks: one has to deal with the various types of configuration values (strings, integers, dates, etc), and it is not possible to define foreign keys. This is why we won't explore key-value tables.

In this guide, we'll implement a single-row table, with recommendations on the database schema, migrations, and the design of a Swift API for accessing the configuration values. The schema will define one column for each configuration value, because we aim at being able to deal with foreign keys and references to other tables. You may prefer storing configuration values in a single JSON column. In this case, take inspiration from this guide, as well as <doc:JSON>.

We will also aim at providing a default value for a given configuration, even when it is not stored on disk yet. This is a feature similar to [`UserDefaults.register(defaults:)`](https://developer.apple.com/documentation/foundation/userdefaults/1417065-register).

## The Single-Row Table

As always with SQLite, everything starts at the level of the database schema. When we put the database engine on our side, we have to write less code, and this helps shipping less bugs.

We want to instruct SQLite that our table must never contain more than one row. We will never have to wonder what to do if we were unlucky enough to find two rows with conflicting values in this table.

SQLite is not able to guarantee that the table is never empty, so we have to deal with two cases: either the table is empty, or it contains one row.

Those two cases can create a nagging question for the application. By default, inserts fail when the row already exists, and updates fail when the table is empty. In order to avoid those errors, we will have the app deal with updates in the <doc:SingleRowTables#The-Single-Row-Record> section below. Right now, we instruct SQLite to just replace the eventual existing row in case of conflicting inserts.

```swift
migrator.registerMigration("appConfiguration") { db in
    // CREATE TABLE appConfiguration (
    //   id INTEGER PRIMARY KEY ON CONFLICT REPLACE CHECK (id = 1),
    //   storedFlag BOOLEAN,
    //   ...)
    try db.create(table: "appConfiguration") { t in
        // Single row guarantee: have inserts replace the existing row,
        // and make sure the id column is always 1.
        t.primaryKey("id", .integer, onConflict: .replace)
            .check { $0 == 1 }
        
        // The configuration columns
        t.column("storedFlag", .boolean)
        // ... other columns
    }
}
```

Note how the database table is defined in a migration. That's because most apps evolve, and need to add other configuration columns eventually. See <doc:Migrations> for more information.

We have defined a `storedFlag` column that can be NULL. That may be surprising, because optional booleans are usually a bad idea! But we can deal with this NULL at runtime, and nullable columns have a few advantages:

- NULL means that the application user had not made a choice yet. When `storedFlag` is NULL, the app can use a default value, such as `true`.
- As application evolves, application will need to add new configuration columns. It is not always possible to provide a sensible default value for these new columns, at the moment the table is modified. On the other side, it is generally possible to deal with those NULL values at runtime.

Despite those arguments, some apps absolutely require a value. In this case, don't weaken the application logic and make sure the database can't store a NULL value:

```swift
// DO NOT hesitate requiring NOT NULL columns when the app requires it.
migrator.registerMigration("appConfiguration") { db in
    try db.create(table: "appConfiguration") { t in
        t.primaryKey("id", .integer, onConflict: .replace).check { $0 == 1 }
        
        t.column("flag", .boolean).notNull() // required
    }
}
```


## The Single-Row Record

Now that the database schema has been defined, we can define the record type that will help the application access the single row:

```swift
struct AppConfiguration: Codable {
    // Support for the single row guarantee
    private var id = 1
    
    // The stored properties
    private var storedFlag: Bool?
    // ... other properties
}
```

The `storedFlag` property is private, because we want to expose a nice `flag` property that has a default value when `storedFlag` is nil:

```swift
// Support for default values
extension AppConfiguration {
    var flag: Bool {
        get { storedFlag ?? true /* the default value */ }
        set { storedFlag = newValue }
    }

    mutating func resetFlag() {
        storedFlag = nil
    }
}
```

This ceremony is not needed when the column can not be null:

```swift
// The simplified setup for non-nullable columns
struct AppConfiguration: Codable {
    // Support for the single row guarantee
    private var id = 1
    
    // The stored properties
    var flag: Bool
    // ... other properties
}
```

In case the database table would be empty, we need a default configuration:

```swift
extension AppConfiguration {
    /// The default configuration
    static let `default` = AppConfiguration(flag: nil)
}
```

We make our record able to access the database:

```swift
extension AppConfiguration: FetchableRecord, PersistableRecord {
```

We have seen in the <doc:SingleRowTables#The-Single-Row-Table> section that by default, updates throw an error if the database table is empty. To avoid this error, we instruct GRDB to insert the missing default configuration before attempting to update (see ``MutablePersistableRecord/willSave(_:)-6jitc`` for more information):

```swift
    // Customize the default PersistableRecord behavior
    func willUpdate(_ db: Database, columns: Set<String>) throws {
        // Insert the default configuration if it does not exist yet.
        if try !exists(db) {
            try AppConfiguration.default.insert(db)
        }
    }
```

The standard GRDB method ``FetchableRecord/fetchOne(_:)`` returns an optional which is nil when the database table is empty. As a convenience, let's define a method that returns a non-optional (replacing the missing row with `default`):

```swift
    /// Returns the persisted configuration, or the default one if the
    /// database table is empty.
    static func find(_ db: Database) throws -> AppConfiguration {
        try fetchOne(db) ?? .default
    }
}
```

And that's it! Now we can use our singleton record:

```swift
// READ
let config = try dbQueue.read { db in
    try AppConfiguration.find(db)
}
if config.flag {
    // ...
}

// WRITE
try dbQueue.write { db in
    // Update the config in the database
    var config = try AppConfiguration.find(db)
    try config.updateChanges(db) {
        $0.flag = true
    }
    
    // Other possible ways to save the config:
    var config = try AppConfiguration.find(db)
    config.flag = true
    try config.save(db)   // all the same
    try config.update(db) // all the same
    try config.insert(db) // all the same
    try config.upsert(db) // all the same
}
```

See ``MutablePersistableRecord`` for more information about persistence methods.


## Wrap-Up

We all love to copy and paste, don't we? Just customize the template code below:

```swift
// Table creation
try db.create(table: "appConfiguration") { t in
    // Single row guarantee: have inserts replace the existing row,
    // and make sure the id column is always 1.
    t.primaryKey("id", .integer, onConflict: .replace)
        .check { $0 == 1 }
    
    // The configuration columns
    t.column("storedFlag", .boolean)
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
    
    // The stored properties
    private var storedFlag: Bool?
    // ... other properties
}

// Support for default values
extension AppConfiguration {
    var flag: Bool {
        get { storedFlag ?? true /* the default value */ }
        set { storedFlag = newValue }
    }

    mutating func resetFlag() {
        storedFlag = nil
    }
}

extension AppConfiguration {
    /// The default configuration
    static let `default` = AppConfiguration(storedFlag: nil)
}

// Database Access
extension AppConfiguration: FetchableRecord, PersistableRecord {
    // Customize the default PersistableRecord behavior
    func willUpdate(_ db: Database, columns: Set<String>) throws {
        // Insert the default configuration if it does not exist yet.
        if try !exists(db) {
            try AppConfiguration.default.insert(db)
        }
    }
    
    /// Returns the persisted configuration, or the default one if the
    /// database table is empty.
    static func find(_ db: Database) throws -> AppConfiguration {
        try fetchOne(db) ?? .default
    }
}
```
