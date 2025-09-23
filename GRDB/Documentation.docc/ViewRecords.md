# View Records

Define record types that target database views. 

## Overview

A record type targets a [database view] as soon as its ``TableRecord/databaseTableName-3tcw2`` is the name of a view.

With such a record, some GRDB features will work out of the box, and some will throw errors without extra configuration:

```swift
// OK: Works out of the box
let captains = try Captain.fetchAll(db)
let captainCount = try Captain.fetchCount(db)

// KO: Requires extra configuration
// SQLite error 1: database view captain has no primary key
var bob = try Captain.find(db, id: "bob")
bob.name = "Bobby"
// SQLite error 1: cannot modify captain because it is a view
try bob.update(db)
```

This article explains how to solve those errors:

- How to provide a primary key to a view.
- How to define INSTEAD OF triggers that insert, update, and delete through a database view.

> important: GRDB is impacted by some SQLite limitations regarding INSTEAD OF triggers:
>
> - **Auto-incremented primary keys are not supported.** To be precise, SQLite won't expose the rowid of rows inserted via an INSTEAD OF trigger, so GRDB won't know the id of newly inserted rows. This has various nefarious consequences—see for example the important notice in the ``MutablePersistableRecord/didInsert(_:)`` callback. For more information, check this [SQLite forum thread](https://sqlite.org/forum/forumpost/707e7ed932).
> - **INSTEAD OF triggers and the RETURNING clause do not play well together.** Those are SQLite bugs. All GRDB record methods with `andFetch` in their name may return unexpected or wrong results, depending on the SQLite version. For example, the SQLite version that ships with iOS 18 has bugs, and even more in iOS 17. If you intend to use the `RETURNING` clause, it is recommended that you write tests and run them in various target operation systems.

## Preliminary Setup

To support this documentation, we need a database that contains a view. The sample code below uses <doc:Migrations> and <doc:DatabaseSchemaModifications> methods.

The database schema contains teams and players. Some players are the captain of their team. We enforce in the database schema that a given team can't have multiple captains: 

```swift
var migrator = DatabaseMigrator()
migrator.registerMigration("Teams and players") { db in
    try db.create(table: "team") { t in
        t.primaryKey("id", .text)
        t.column("name", .text).notNull()
    }
    
    try db.create(table: "player") { t in
        t.primaryKey("id", .text)
        t.column("name", .text).notNull()
        t.belongsTo("team", onDelete: .setNull)
        t.column("isCaptain", .boolean).notNull()
    }
    
    // One unique captain per team
    try db.create(
        indexOn: "player", columns: ["teamId"],
        options: .unique,
        condition: Column("isCaptain"))
}
```

We define record types for the `team` and `player` tables, as described in <doc:RecordRecommendedPractices>:

```swift
struct Team: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
}

struct Player: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var teamId: String?
    var isCaptain: Bool
}
```

Let's define a view and a record type for captains. At this point, both the view and the record are read-only:

```swift
migrator.registerMigration("Read-only captains") { db in
    try db.execute(sql: """
        CREATE VIEW captain AS
        SELECT id, name, teamId
        FROM player
        WHERE isCaptain AND teamId IS NOT NULL;
        """)
}

struct Captain: Decodable, Identifiable, FetchableRecord {
    var id: String
    var name: String
    var teamId: String
}
```

✅ From now on, we can use the `Captain` record:

```swift
let dbQueue = try DatabaseQueue()
try migrator.migrate(dbQueue)
try dbQueue.write { db in
    try Team(id: "red", name: "Red").insert(db)
    try Team(id: "blue", name: "Blue").insert(db)
    try Player(id: "alice", name: "Alice", teamId: "red", isCaptain: true).insert(db)
    try Player(id: "bob", name: "Bob", teamId: "blue", isCaptain: true).insert(db)
    try Player(id: "craig", name: "Craig", teamId: "blue", isCaptain: false).insert(db)
    
    let captains = try Captain.fetchAll(db)
    // Prints:
    //  Captain(id: "alice", name: "Alice", teamId: "red")
    //  Captain(id: "bob", name: "Bob", teamId: "blue")
    print(captains)
}
```

## Specifying the primary key of a view

SQLite views do not have any primary key, so GRDB cannot introspect the database schema and automatically find the eventual primary key.

To instruct GRDB about the primary key, define a **schema source**, a type that conforms to ``DatabaseSchemaSource``. In this sample code, the schema only contains the "captain" view, so our schema source does not need to be very complicated. Check the documentation of the protocol for more detailed instructions:

```swift
struct GameSchemaSource: DatabaseSchemaSource {
    /// Returns the names of the columns for the primary key in the
    /// provided database view.
    func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) throws -> [String]? {
        ["id"]
    }
}
```

We configure the database connection with this schema source:

```swift
var config = Configuration()
config.schemaSource = GameSchemaSource()
let dbQueue = try DatabaseQueue(configuration: config)
try migrator.migrate(dbQueue)
```

✅ We can now use the primary key of captains:

```swift
try dbQueue.read { db in
    // [Insert some teams and players...]
    let captains = try Captain.orderByPrimaryKey().fetchAll(db)
    let alice = try Captain.find(db, id: "alice")
}
```

## Associations between views

To define [Associations](https://github.com/groue/GRDB.swift/blob/master/Documentation/AssociationsBasics.md) between record types that target database views, the foreign key must be explicitly provided. We define the foreign key from `captain` to `team` with a column declared as recommended in <doc:RecordRecommendedPractices>: 

```swift
extension Captain {
    // Time to define some columns
    enum Columns {
        static let teamId = Column(CodingKeys.teamId)
    }
    
    // The captain view has a foreign key to teams,
    // from the teamId column to the team primary key.
    // SQLite does not know about it, so we declare it explicitly:
    static let teamForeignKey = ForeignKey([Columns.teamId])
    
    // A captain belongs to a team.
    static let team = belongsTo(Team.self, using: teamForeignKey)
}

extension Team {
    // A team has a captain.
    static let captain = hasOne(Captain.self, using: Captain.teamForeignKey)
}
```

✅ We can now use those associations:

```swift
try dbQueue.read { db in
    // All teams with a captain
    let teamsWithCaptain: [Team] = try Team
        .joining(required: Team.captain)
        .fetchAll(db)
    
    // All (captain, team) pairs
    struct CaptainWithTeam: Decodable, FetchableRecord {
        var captain: Captain
        var team: Team
    }
    let captainsWithTeam: [CaptainWithTeam] = try Captain
        .including(required: Captain.team)
        .asRequest(of: CaptainWithTeam.self)
        .fetchAll(db)
}
```

## Inserting rows into a view

SQLite views are read-only unless we define an [INSTEAD OF trigger] that specifies which statements to run when we insert a row into a view.

INSTEAD OF triggers are very versatile, and applications can define the behavior that best fits their needs. In our sample code, inserting a captain will insert a player with the `isCaptain` flag set, and we'll also remove the `isCaptain` flag of the previous captain, if any:

```swift
migrator.registerMigration("Captain insert") { db in
    try db.execute(sql: """
        -- Insert trigger
        CREATE TRIGGER captain_insert
        INSTEAD OF INSERT ON captain
        BEGIN
            -- Remove previous captain
            UPDATE player SET isCaptain = 0
            WHERE teamId = NEW.teamId AND isCaptain;
            
            -- Insert new captain
            INSERT INTO player(id, name, teamId, isCaptain)
            VALUES (NEW.id, NEW.name, NEW.teamId, 1);
        END;
        """)
}

// Apply the new migration
try migrator.migrate(dbQueue)
```

Let's also give an `insert()` method to the Captain record, with the ``PersistableRecord`` protocol:

```swift
extension Captain: Encodable, PersistableRecord { }
```

- note: Remember that auto-incremented primary keys are not supported, as described at the beginning of this article. Our captain view is backed by the player table which has a string primary key, so we're fine.

✅ We can directly insert captains:

```swift
try dbQueue.write {
    try Team(id: "green", name: "Green").insert(db)
    // Diane is the captain
    try Captain(id: "diane", name: "Diane", teamId: "green").insert(db)
    // Well, no: Eugene is the captain
    try Captain(id: "eugene", name: "Eugene", teamId: "green").insert(db)
    
    // Prints:
    // team          player                  captain
    // green|Green   diane|Diane|green|0     eugene|Eugene|green
    //               eugene|Eugene|green|1
    try db.dumpTables(["team", "player", "captain"])
}
```

## Updating rows in a view

Just like for inserts, an INSTEAD OF trigger can specify how to update rows in a view.

In our sample code, updating a captain will update the player with the same id, and remove the `isCaptain` flag from the previous captain of the team, if any:

```swift
migrator.registerMigration("Captain update") { db in
    try db.execute(sql: """
        -- Update trigger
        CREATE TRIGGER captain_update
        INSTEAD OF UPDATE ON captain
        BEGIN
            -- Remove previous captain
            UPDATE player SET isCaptain = 0
            WHERE teamId = NEW.teamId AND isCaptain AND id <> NEW.id;
            
            -- Update captain
            UPDATE player SET name = NEW.name, teamId = NEW.teamId, isCaptain = 1
            WHERE id = NEW.id;
        END;
        """)
}

// Apply the new migration
try migrator.migrate(dbQueue)
```

✅ Let's update captains:

```swift
try dbQueue.write {
    try Team(id: "red", name: "Red").insert(db)
    try Team(id: "blue", name: "Blue").insert(db)
    try Captain(id: "alice", name: "Alice", teamId: "red").insert(db)
    
    // Bob is the Blue captain.
    var bob = Captain(id: "bob", name: "Bob", teamId: "blue")
    try bob.insert(db)
    
    // Bob is now Bobby, the Red captain.
    // Alice is no longer the Red captain.
    try bob.updateChanges(db) {
        $0.name = "Bobby"
        $0.teamId = "red"
    }
    
    // Prints:
    // team        player              captain
    // blue|Blue   alice|Alice|red|0   bob|Bobby|red
    // red|Red     bob|Bobby|red|1
    try db.dumpTables(["team", "player", "captain"])
}
```

## Deleting rows from a view

The last missing INSTEAD OF trigger deals with deletes:

```swift
migrator.registerMigration("Captain delete") { db in
    try db.execute(sql: """
        -- Delete trigger
        CREATE TRIGGER captain_delete
        INSTEAD OF DELETE ON captain
        BEGIN
            DELETE FROM player WHERE id = OLD.id;
        END;
        """)
}

// Apply the new migration
try migrator.migrate(dbQueue)
```

✅ Let's delete some captains:

```swift
try dbQueue.write {
    // Delete Alice
    try Captain.deleteOne(db, id: "alice")
    
    // Delete Bob
    let bob = try Captain.find(db, id: "bob")
    try bob.delete(db)
    
    // Delete all captains
    try Captain.deleteAll()
}
```

## Going further

To exercise the techniques described here, try to define record types for these other views:

- The `enrolledPlayer` view that only contains players that belong to a team:

    ```swift
    try db.execute(sql: """
        CREATE VIEW enrolledPlayer AS
        SELECT id, name, teamId, isCaptain
        FROM player
        WHERE teamId IS NOT NULL;
        """)
    ```

- The `teamWithCaptainId` view that contains a `captainId` column:

    ```swift
    try db.execute(sql: """
        CREATE VIEW teamWithCaptainId AS
        SELECT team.id, team.name, player.id AS captainId
        FROM team
        JOIN player ON player.teamId = team.id AND player.isCaptain;
        """)
    ```

- A refactored `captain` view whose primary key is the team id—this is valid, since the schema enforces that there's a single captain for each team:

    ```swift
    try db.execute(sql: """
        CREATE VIEW captain AS
        SELECT teamId, name
        FROM player
        WHERE isCaptain AND teamId IS NOT NULL;
        """)
    ```

[database view]: https://www.sqlite.org/lang_createview.html
[INSTEAD OF trigger]: https://sqlite.org/lang_createtrigger.html#instead_of_triggers
