# The Database Schema

Define or query the database schema.

## Overview

**GRDB supports all database schemas, and has no requirement.** Any existing SQLite database can be opened, and you are free to structure your new databases as you wish.

You perform modifications to the database schema with methods such as ``Database/create(table:options:body:)``, listed at the end of this page. For example:

```swift
try db.create(table: "player") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("name", .text).notNull()
    t.column("score", .integer).notNull()
}
```

When you plan to evolve the schema as new versions of your application ship, wrap all schema changes in <doc:Migrations>.

Prefer Swift methods over raw SQL queries. They allow the compiler to check if a schema change is available on the target operating system. Only use a raw SQL query when no Swift method exist (when creating triggers, for example).

When a schema change is not directly supported by SQLite, or not available on the target operating system, database tables have to be recreated. See <doc:Migrations> for the detailed procedure.

## Database Schema Recommendations

Even though all schema are supported, some features of the library and of the Swift language are easier to use when the schema follows a few conventions described below.

When those conventions are not applied, or not applicable, you will have to perform extra configurations.

For recommendations specific to JSON columns, see <doc:JSON>.

### Table names should be English, singular, and camelCased

Make them look like singular Swift identifiers: `player`, `team`, `postalAddress`:

```swift
// RECOMMENDED
try db.create(table: "player") { t in
    // table columns and constraints
}

// REQUIRES EXTRA CONFIGURATION
try db.create(table: "players") { t in
    // table columns and constraints
}
```

☝️ **If table names follow a different naming convention**, record types (see <doc:QueryInterface>) will need explicit table names:

```swift
extension Player: TableRecord {
    // Required because table name is not 'player'
    static let databaseTableName = "players"
}

extension PostalAddress: TableRecord {
    // Required because table name is not 'postalAddress'
    static let databaseTableName = "postal_address"
}

extension Award: TableRecord {
    // Required because table name is not 'award'
    static let databaseTableName = "Auszeichnung"
}
```

[Associations](https://github.com/groue/GRDB.swift/blob/master/Documentation/AssociationsBasics.md) will need explicit keys as well:

```swift
extension Player: TableRecord {
    // Explicit association key because the table name is not 'postalAddress'   
    static let postalAddress = belongsTo(PostalAddress.self, key: "postalAddress")

    // Explicit association key because the table name is not 'award'
    static let awards = hasMany(Award.self, key: "awards")
}
```

As in the above example, make sure to-one associations use singular keys, and to-many associations use plural keys.

### Column names should be camelCased

Again, make them look like Swift identifiers: `fullName`, `score`, `creationDate`:

```swift
// RECOMMENDED
try db.create(table: "player") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("fullName", .text).notNull()
    t.column("score", .integer).notNull()
    t.column("creationDate", .datetime).notNull()
}

// REQUIRES EXTRA CONFIGURATION
try db.create(table: "player") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("full_name", .text).notNull()
    t.column("score", .integer).notNull()
    t.column("creation_date", .datetime).notNull()
}
```

☝️ **If the column names follow a different naming convention**, `Codable` record types will need an explicit `CodingKeys` enum:

```swift
struct Player: Decodable, FetchableRecord {
    var id: Int64
    var fullName: String
    var score: Int
    var creationDate: Date

    // Required CodingKeys customization because 
    // columns are not named like Swift properties
    enum CodingKeys: String, CodingKey {
        case id, fullName = "full_name", score, creationDate = "creation_date"
    }
}
```

### Tables should have explicit primary keys

A primary key uniquely identifies a row in a table. It is defined on one or several columns:

```swift
// RECOMMENDED
try db.create(table: "player") { t in
    // Auto-incremented primary key
    t.autoIncrementedPrimaryKey("id")
    t.column("name", .text).notNull()
}

try db.create(table: "team") { t in
    // Single-column primary key
    t.primaryKey("id", .text)
    t.column("name", .text).notNull()
}

try db.create(table: "membership") { t in
    // Composite primary key
    t.primaryKey {
        t.belongsTo("player")
        t.belongsTo("team")
    }
    t.column("role", .text).notNull()
}
```

Primary keys support record fetching methods such as ``FetchableRecord/fetchOne(_:id:)``, and persistence methods such as ``MutablePersistableRecord/update(_:onConflict:)`` or ``MutablePersistableRecord/delete(_:)``.

See <doc:SingleRowTables> when you need to define a table that contains a single row.

☝️ **If the database table does not define any explicit primary key**, identifying specific rows in this table needs explicit support for the [hidden `rowid` column](https://www.sqlite.org/rowidtable.html) in the matching record types:

```swift
// A table without any explicit primary key
try db.create(table: "player") { t in
    t.column("name", .text).notNull()
    t.column("score", .integer).notNull()
}

// The record type for the 'player' table'
struct Player: Codable {
    // Uniquely identifies a player.
    var rowid: Int64?
    var name: String
    var score: Int
}

extension Player: FetchableRecord, MutablePersistableRecord {
    // Required because the primary key
    // is the hidden rowid column.
    static let databaseSelection: [any SQLSelectable] = [
        AllColumns(),
        Column.rowID]

    // Update id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        rowid = inserted.rowID
    }
}

try dbQueue.read { db in
    // SELECT *, rowid FROM player WHERE rowid = 1
    if let player = try Player.fetchOne(db, id: 1) {
        // DELETE FROM player WHERE rowid = 1
        let deleted = try player.delete(db)
        print(deleted) // true
    }
}
```

### Single-column primary keys should be named 'id'

This helps record types play well with the standard `Identifiable` protocol.

```swift
// RECOMMENDED
try db.create(table: "player") { t in
    t.primaryKey("id", .text)
    t.column("name", .text).notNull()
}

// REQUIRES EXTRA CONFIGURATION
try db.create(table: "player") { t in
    t.primaryKey("uuid", .text)
    t.column("name", .text).notNull()
}
```
☝️ **If the primary key follows a different naming convention**, `Identifiable` record types will need a custom `CodingKeys` enum, or an extra property:

```swift
// Custom coding keys
struct Player: Codable, Identifiable {
    var id: String
    var name: String

    // Required CodingKeys customization because 
    // columns are not named like Swift properties
    enum CodingKeys: String, CodingKey {
        case id = "uuid", name
    }
}

// Extra property
struct Player: Identifiable {
    var uuid: String
    var name: String
    
    // Required because the primary key column is not 'id'
    var id: String { uuid }
}
```

### Unique keys should be supported by unique indexes

Unique indexes makes sure SQLite prevents the insertion of conflicting rows:

```swift
// RECOMMENDED
try db.create(table: "player") { t in
    t.autoIncrementedPrimaryKey("id")
    t.belongsTo("team").notNull()
    t.column("position", .integer).notNull()
    // Players must have distinct names
    t.column("name", .text).unique()
}

// One single player at any given position in a team
try db.create(
    indexOn: "player",
    columns: ["teamId", "position"],
    options: .unique)
```

> Tip: SQLite does not support deferred unique indexes, and this creates undesired churn when you need to temporarily break them. This may happen, for example, when you want to reorder player positions in our above example.
>
> There exist several workarounds; one of them involves dropping and recreating the unique index after the temporary violations have been fixed. If you plan to use this technique, take care that only actual indexes can be dropped. Unique constraints created inside the table body can not:
>
> ```swift
> // Unique constraint on player(name) can not be dropped.
> try db.create(table: "player") { t in
>     t.column("name", .text).unique()
> }
>
> // Unique index on team(name) can be dropped.
> try db.create(table: "team") { t in
>     t.column("name", .text)
> }
> try db.create(indexOn: "team", columns: ["name"], options: .unique)
> ```
>
> If you want to turn an undroppable constraint into a droppable index, you'll need to recreate the database table. See <doc:Migrations> for the detailed procedure.

☝️ **If a table misses unique indexes**, some record methods such as ``FetchableRecord/fetchOne(_:key:)-92b9m`` and ``TableRecord/deleteOne(_:key:)-5pdh5`` will raise a fatal error:

```swift
try dbQueue.write { db in
    // Fatal error: table player has no unique index on columns ...
    let player = try Player.fetchOne(db, key: ["teamId": 42, "position": 1])
    try Player.deleteOne(db, key: ["name": "Arthur"])
    
    // Use instead:
    let player = try Player
        .filter(Column("teamId") == 42 && Column("position") == 1)
        .fetchOne(db)

    try Player
        .filter(Column("name") == "Arthur")
        .deleteAll(db)
}
```

### Relations between tables should be supported by foreign keys

[Foreign Keys](https://www.sqlite.org/foreignkeys.html) have SQLite enforce valid relationships between tables:

```swift
try db.create(table: "team") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("color", .text).notNull()
}

// RECOMMENDED
try db.create(table: "player") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("name", .text).notNull()
    // A player must refer to an existing team
    t.belongsTo("team").notNull()
}

// REQUIRES EXTRA CONFIGURATION
try db.create(table: "player") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("name", .text).notNull()
    // No foreign key
    t.column("teamId", .integer).notNull()
}
```

See ``TableDefinition/belongsTo(_:inTable:onDelete:onUpdate:deferred:indexed:)`` for more information about the creation of foreign keys.

GRDB [Associations](https://github.com/groue/GRDB.swift/blob/master/Documentation/AssociationsBasics.md) are automatically configured from foreign keys declared in the database schema:

```swift
extension Player: TableRecord {
    static let team = belongsTo(Team.self)
}

extension Team: TableRecord {
    static let players = hasMany(Player.self)
}
```

See [Associations and the Database Schema](https://github.com/groue/GRDB.swift/blob/master/Documentation/AssociationsBasics.md#associations-and-the-database-schema) for more precise recommendations.

☝️ **If a foreign key is not declared in the schema**, you will need to explicitly configure related associations:

```swift
extension Player: TableRecord {
    // Required configuration because the database does
    // not declare any foreign key from players to their team.
    static let teamForeignKey = ForeignKey(["teamId"])
    static let team = belongsTo(Team.self,
                                using: teamForeignKey)
}

extension Team: TableRecord {
    // Required configuration because the database does
    // not declare any foreign key from players to their team.
    static let players = hasMany(Player.self,
                                 using: Player.teamForeignKey)
}
```

## Topics

### Database Tables

- ``Database/alter(table:body:)``
- ``Database/create(table:options:body:)``
- ``Database/create(virtualTable:ifNotExists:using:)``
- ``Database/create(virtualTable:ifNotExists:using:_:)``
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

### Querying the Database Schema

- ``Database/columns(in:in:)``
- ``Database/foreignKeys(on:in:)``
- ``Database/indexes(on:in:)``
- ``Database/isGRDBInternalTable(_:)``
- ``Database/isSQLiteInternalTable(_:)``
- ``Database/primaryKey(_:in:)``
- ``Database/schemaVersion()``
- ``Database/table(_:hasUniqueKey:)``
- ``Database/tableExists(_:in:)``
- ``Database/triggerExists(_:in:)``
- ``Database/viewExists(_:in:)``
- ``ColumnInfo``
- ``ForeignKeyInfo``
- ``IndexInfo``
- ``PrimaryKeyInfo``

### Integrity Checks

- ``Database/checkForeignKeys()``
- ``Database/checkForeignKeys(in:in:)``
- ``Database/foreignKeyViolations()``
- ``Database/foreignKeyViolations(in:in:)``
- ``ForeignKeyViolation``

### Sunsetted Methods

Those are legacy interfaces that are preserved for backwards compatibility. Their use is not recommended.

- ``Database/create(index:on:columns:unique:ifNotExists:condition:)``
- ``Database/create(table:temporary:ifNotExists:withoutRowID:body:)``
