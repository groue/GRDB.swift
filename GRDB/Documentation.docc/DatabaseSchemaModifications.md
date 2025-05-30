# Modifying the Database Schema

How to modify the database schema

## Overview

For modifying the database schema, prefer Swift methods over raw SQL queries. They allow the compiler to check if a schema change is available on the target operating system. Only use a raw SQL query when no Swift method exist (when creating triggers, for example).

When a schema change is not directly supported by SQLite, or not available on the target operating system, database tables have to be recreated. See <doc:Migrations> for the detailed procedure.

## Create Tables

The ``Database/create(table:options:body:)`` method covers nearly all SQLite table creation features. For virtual tables, see [Full-Text Search](https://github.com/groue/GRDB.swift/blob/master/Documentation/FullTextSearch.md), or use raw SQL.

```swift
// CREATE TABLE place (
//   id INTEGER PRIMARY KEY AUTOINCREMENT,
//   title TEXT,
//   favorite BOOLEAN NOT NULL DEFAULT 0,
//   latitude DOUBLE NOT NULL,
//   longitude DOUBLE NOT NULL
// )
try db.create(table: "place") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("title", .text)
    t.column("favorite", .boolean).notNull().defaults(to: false)
    t.column("longitude", .double).notNull()
    t.column("latitude", .double).notNull()
}
```

**Configure table creation**

```swift
// CREATE TABLE player ( ... )
try db.create(table: "player") { t in ... }
    
// CREATE TEMPORARY TABLE player IF NOT EXISTS (
try db.create(table: "player", options: [.temporary, .ifNotExists]) { t in ... }
```

Reference: ``TableOptions``

**Add regular columns** with their name and eventual type (`text`, `integer`, `double`, `real`, `numeric`, `boolean`, `blob`, `date`, `datetime`, `any`, and `json`) - see [SQLite data types](https://www.sqlite.org/datatype3.html) and <doc:JSON>:

```swift
// CREATE TABLE player (
//   score,
//   name TEXT,
//   creationDate DATETIME,
//   address TEXT,
try db.create(table: "player") { t in
    t.column("score")
    t.column("name", .text)
    t.column("creationDate", .datetime)
    t.column("address", .json)
```

Reference: ``TableDefinition/column(_:_:)``

Define **not null** columns, and set **default values**:

```swift
    // email TEXT NOT NULL,
    t.column("email", .text).notNull()
    
    // name TEXT NOT NULL DEFAULT 'Anonymous',
    t.column("name", .text).notNull().defaults(to: "Anonymous")
```

Reference: ``ColumnDefinition``

**Define primary, unique, or foreign keys**. When defining a foreign key, the referenced column is the primary key of the referenced table (unless you specify otherwise):

```swift
    // id INTEGER PRIMARY KEY AUTOINCREMENT,
    t.autoIncrementedPrimaryKey("id")

    // uuid TEXT PRIMARY KEY NOT NULL,
    t.primaryKey("uuid", .text)

    // teamName TEXT NOT NULL,
    // position INTEGER NOT NULL,
    // PRIMARY KEY (teamName, position),
    t.primaryKey {
        t.column("teamName", .text)
        t.column("position", .integer)
    }

    // email TEXT UNIQUE,
    t.column("email", .text).unique()

    // teamId TEXT REFERENCES team(id) ON DELETE CASCADE,
    // countryCode TEXT REFERENCES country(code) NOT NULL,
    t.belongsTo("team", onDelete: .cascade)
    t.belongsTo("country").notNull()
```

Reference: ``TableDefinition``, ``ColumnDefinition/unique(onConflict:)``

**Create an index** on a column

```swift
    t.column("score", .integer).indexed()
```

Reference: ``ColumnDefinition``

For extra index options, see <doc:DatabaseSchemaModifications#Create-Indexes> below.

**Perform integrity checks** on individual columns, and SQLite will only let conforming rows in. In the example below, the `$0` closure variable is a column which lets you build any SQL expression.

```swift
    // name TEXT CHECK (LENGTH(name) > 0)
    // score INTEGER CHECK (score > 0)
    t.column("name", .text).check { length($0) > 0 }
    t.column("score", .integer).check(sql: "score > 0")
```

Reference: ``ColumnDefinition``

Columns can also be defined with a raw sql String, or an [SQL literal](https://github.com/groue/GRDB.swift/blob/master/Documentation/SQLInterpolation.md#sql-literal) in which you can safely embed raw values without any risk of syntax errors or SQL injection:

```swift
    t.column(sql: "name TEXT")
    
    let defaultName: String = ...
    t.column(literal: "name TEXT DEFAULT \(defaultName)")
```

Reference: ``TableDefinition``

Other **table constraints** can involve several columns:

```swift
    // PRIMARY KEY (a, b),
    t.primaryKey(["a", "b"])
    
    // UNIQUE (a, b) ON CONFLICT REPLACE,
    t.uniqueKey(["a", "b"], onConflict: .replace)
    
    // FOREIGN KEY (a, b) REFERENCES parents(c, d),
    t.foreignKey(["a", "b"], references: "parents")
    
    // CHECK (a + b < 10),
    t.check(Column("a") + Column("b") < 10)
    
    // CHECK (a + b < 10)
    t.check(sql: "a + b < 10")
    
    // Raw SQL constraints
    t.constraint(sql: "CHECK (a + b < 10)")
    t.constraint(literal: "CHECK (a + b < \(10))")
```

Reference: ``TableDefinition``

**Generated columns**:

```swift
    t.column("totalScore", .integer).generatedAs(sql: "score + bonus")
    t.column("totalScore", .integer).generatedAs(Column("score") + Column("bonus"))
}
```

Reference: ``ColumnDefinition``

## Modify Tables

SQLite lets you modify existing tables:

```swift
// ALTER TABLE referer RENAME TO referrer
try db.rename(table: "referer", to: "referrer")

// ALTER TABLE player ADD COLUMN hasBonus BOOLEAN
// ALTER TABLE player RENAME COLUMN url TO homeURL
// ALTER TABLE player DROP COLUMN score
try db.alter(table: "player") { t in
    t.add(column: "hasBonus", .boolean)
    t.rename(column: "url", to: "homeURL")
    t.drop(column: "score")
}
```

Reference: ``TableAlteration``

> Note: SQLite restricts the possible table alterations, and may require you to recreate dependent triggers or views. See <doc:Migrations#Defining-the-Database-Schema-from-a-Migration> for more information.

## Drop Tables

Drop tables with the ``Database/drop(table:)`` method:

```swift
try db.drop(table: "obsolete")
```

## Create Indexes

Create an index on a column:

```swift
try db.create(table: "player") { t in
    t.column("email", .text).unique()
    t.column("score", .integer).indexed()
}
```

Create indexes on an existing table:

```swift
// CREATE INDEX index_player_on_email ON player(email)
try db.create(indexOn: "player", columns: ["email"])

// CREATE UNIQUE INDEX index_player_on_email ON player(email)
try db.create(indexOn: "player", columns: ["email"], options: .unique)
```

Create indexes with a specific collation:

```swift
// CREATE INDEX index_player_on_email ON player(email COLLATE NOCASE)
try db.create(
    index: "index_player_on_email",
    on: "player",
    expressions: [Column("email").collating(.nocase)])
```

Create indexes on expressions:

```swift
// CREATE INDEX index_player_on_total_score ON player(score+bonus)
try db.create(
    index: "index_player_on_total_score",
    on: "player",
    expressions: [Column("score") + Column("bonus")])

// CREATE INDEX index_player_on_country ON player(address ->> 'country')
try db.create(
    index: "index_player_on_country",
    on: "player",
    expressions: [
        JSONColumn("address")["country"],
    ])
```

Unique constraints and unique indexes are somewhat different: don't miss the tip in <doc:DatabaseSchemaRecommendations/Unique-keys-should-be-supported-by-unique-indexes> below.

## Topics

### Database Tables

- ``Database/alter(table:body:)``
- ``Database/create(table:options:body:)``
- ``Database/create(virtualTable:options:using:)``
- ``Database/create(virtualTable:options:using:_:)``
- ``Database/drop(table:)``
- ``Database/dropFTS4SynchronizationTriggers(forTable:)``
- ``Database/dropFTS5SynchronizationTriggers(forTable:)``
- ``Database/rename(table:to:)``
- ``Database/ColumnType``
- ``Database/ConflictResolution``
- ``Database/ForeignKeyAction``
- ``TableAlteration``
- ``TableDefinition``
- ``TableOptions``
- ``VirtualTableModule``
- ``VirtualTableOptions``

### Database Views

- ``Database/create(view:options:columns:as:)``
- ``Database/create(view:options:columns:asLiteral:)``
- ``Database/drop(view:)``
- ``ViewOptions``

### Database Indexes

- ``Database/create(indexOn:columns:options:condition:)``
- ``Database/create(index:on:columns:options:condition:)``
- ``Database/create(index:on:expressions:options:condition:)``
- ``Database/drop(indexOn:columns:)``
- ``Database/drop(index:)``
- ``IndexOptions``

### Sunsetted Methods

Those are legacy interfaces that are preserved for backwards compatibility. Their use is not recommended.

- ``Database/create(index:on:columns:unique:ifNotExists:condition:)``
- ``Database/create(table:temporary:ifNotExists:withoutRowID:body:)``
- ``Database/create(virtualTable:ifNotExists:using:)``
- ``Database/create(virtualTable:ifNotExists:using:_:)``
