Tutorial: Building a Database Access Layer
==========================================

<img align="right" src="https://github.com/groue/GRDB.swift/raw/master/Documentation/DemoApps/GRDBDemoiOS/Screenshot.png" width="50%">

**This tutorial describes the building of the database access layer of the [demo applications], step by step, applying good SQLite and GRDB practices along the way.**

The target audience is already fluent with the creation of an Xcode project, storyboards, view controllers, or SwiftUI. These topics are mentionned, but not covered.

Basic database knowledge is assumed, such as what tables and columns are. The tutorial covers high-level GRDB features: record types, query interface, database observation. Raw SQL is also provided, so that you can choose your favorite way to use SQLite.

When you want an explanation about some particular recommendation or piece of code, expand the design notes marked with an ℹ️.

As you can see in the [screenshot], the demo application displays the list of players stored in the database. The application user can sort players by name or by score. She can add, edit, and delete players. The list of players can be "refreshed". For demo purpose, refreshing players performs random modifications to the players.

Let's start!

- [The Database Service]
- [The Shared Application Database]
- [The Database Schema]
- [Inserting Players in the Database, and the Player Struct]
- [Deleting Players]
- [Fetching and Modifying Players]
- [Sorting Players]
- [Observing Players]
- [The Initial Application State]
- [Testing the Database]

## The Database Service

In this chapter, we introduce the `AppDatabase` service. It is the class that grants access to the player database, in a controlled fashion.

We'll make it possible to fetch the list of players, insert new players, as well as other application needs. But not all database operations will be possible. For example, setting up the database schema is the strict privilege of `AppDatabase`, not of the rest of the application.

The `AppDatabase` service accesses the SQLite database through a GRDB [database connection]. We'd like the application to use a `DatabasePool`, because this connection leverages the advantages of the SQLite [WAL mode]. On the other side, we'd prefer application tests to run as fast as possible, with an in-memory database provided by a `DatabaseQueue`. SwiftUI previews will also run with in-memory databases.

Pools and queues share a common protocol, `DatabaseWriter`, and this is what our `AppDatabase` service needs:

```swift
// File: AppDatabase.swift
import GRDB

final class AppDatabase {
    /// Creates an `AppDatabase`.
    init(_ dbWriter: DatabaseWriter) throws {
        self.dbWriter = dbWriter
    }
    
    /// Provides access to the database.
    private let dbWriter: DatabaseWriter
}
```

<details>
    <summary>ℹ️ Design Notes</summary>

> The `dbWriter` property is private: this allows `AppDatabase` to restrict the operations that can be performed on the database.
> 
> The initializer is not private: we can freely create `AppDatabase` instances, for the application, and for tests.
> 
> The initializer is declared with the `throws` qualifier, because it will be extended, below in this guide, in order to prepare the database for application use.

</details>

> ✅ At this stage, we have an `AppDatabase` class which encapsulates access to the database. It supports both WAL databases, and in-memory databases, so that it can feed both the application, and tests.

## The Shared Application Database

Our app uses a single database file, so we want a "shared" database.

Inspired by `UIApplication.shared`, `UserDefaults.standard`, or `FileManager.default`, we will define `AppDatabase.shared`.

<details>
    <summary>ℹ️ Design Notes</summary>

> Some applications will prefer to manage the shared `AppDatabase` instance differently, for example with some dependency injection technique. In this case, you will not define `AppDatabase.shared`.
> 
> Just make sure that there exists a single instance of `DatabaseQueue` or `DatabasePool` for any given database file. This is because multiple instances would compete for database access, and sometimes throw errors. [Sharing a database] is hard. Get inspiration from `AppDatabase.makeShared()`, below, in order to create the single instance of your database service.

</details>

The shared `AppDatabase` instance opens the database on the file system, in a file named "db.sqlite" stored in a "database" folder, and creates an empty database if the file does not already exist:

```swift
// File: Persistence.swift
import GRDB

extension AppDatabase {
    /// The database for the application
    static let shared = makeShared()
    
    private static func makeShared() -> AppDatabase {
        do {
            // Create a folder for storing the SQLite database
            let fileManager = FileManager()
            let folderURL = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("database", isDirectory: true)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            // Connect to a database on disk
            let dbURL = folderURL.appendingPathComponent("db.sqlite")
            let dbPool = try DatabasePool(path: dbURL.path)
            
            // Create the AppDatabase
            let appDatabase = try AppDatabase(dbPool)
            return appDatabase
        } catch {
            fatalError("Unresolved error \(error)")
        }
    }
}
```

<details>
    <summary>ℹ️ Design Notes</summary>

> The database is stored in its own directory, so that you can easily:
> 
> - Set up [data protection].
> - Remove the database as well as its companion [temporary files](https://sqlite.org/tempfiles.html) from disk in a single stroke.
> 
> The shared `AppDatabase` uses a `DatabasePool` in order to profit from the SQLite [WAL mode].
> 
> Any error which prevents the application from opening the database has the application crash. You will have to adapt this sample code if you intend to build an app that is able to run without a working database. For example, you could modify `AppDatabase` so that it owns a `Result<DatabaseWriter, Error>` instead of a plain `DatabaseWriter` - but your mileage may vary.

</details>

The [Combine + SwiftUI Demo Application] defines more instances of `AppDatabase`, such as en empty players database suitable for some SwiftUI previews:

```swift
// File: Persistence.swift

extension AppDatabase {
    /// Creates an empty database for SwiftUI previews
    static func empty() -> AppDatabase {
        // Connect to an in-memory database
        let dbQueue = DatabaseQueue()
        return try! AppDatabase(dbQueue)
    }
}
```

> ✅ At this stage, we have an `AppDatabase.shared` object which vends an empty database. We'll add methods and properties to `AppDatabase`, as we discover the needs of our application.

## The Database Schema

Now that we have an empty database, let's define its schema: the database table(s) that will store our application data. A good database schema will have SQLite manage the database integrity for you, and make sure it is impossible to store invalid data in the database: this is an important step!

<details>
    <summary>ℹ️ Design Notes</summary>

> Some database libraries derive the database schema and relational constraints right from application code. For example, the fact that the name of a player can't be nil would be expressed in Swift, and the database library would prevent nil names from entering the database. With such libraries, you may not be free to define the database schema as you would want it to be, and you do not have much guarantee about the quality of your data.
> 
> With GRDB, it is just the other way around: you freely define the database schema so that it fulfills your application needs, and you access the database data with Swift code that matches this schema. You can't build a safer haven for your precious users' data than a robust SQLite schema. Bring your database skills with you!

</details>

Our database has one table, `player`, where each row contains the attributes of a player: a unique identifier (aka *primary key*), a name, and a score. The identifier makes it possible to instruct the database to perform operations on a specific player. We'll make sure all players have a name and a score (we'll prevent *NULL* values from entering those columns).

In order to define the schema and create the `player` table, it is recommended to use [migrations]. All applications around us evolve as time passes, and ship several versions: it is likely our app will do the same. The database schema evolves as well, as we add features and fix bugs in our app. That's exactly what migrations are for: they represent the building steps of our database schema, as our app goes through its versions.

The migrations are defined in the `AppDatabase.migrator` property, in which we register the *initial migration*:

```swift
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("initial") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("score", .integer).notNull()
            }
        }
        
        // Migrations for future application versions will be inserted here:
        // migrator.registerMigration(...) { db in
        //     ...
        // }
        
        return migrator
    }
```

<details>
    <summary>ℹ️ Design Notes</summary>

> The database table for players is named `player`, because GRDB recommends that table names are English, singular, and camel-cased (`player`, `country`, `postalAddress`, etc.) Such names will help you using [Associations] when you need them. Database table names that follow another naming convention are totally OK, but you will have to perform extra configuration.
> 
> The primary key for players is an auto-incremented column named `id`. It also could have been a UUID column named `uuid`. GRDB generally accepts all primary keys, even if they are not named `id`, even if they span several columns, without any extra setup. Yet `id` is a frequent convention.
> 
> The `id` column is [autoincremented](https://sqlite.org/autoinc.html), in order to avoid id reuse. Reused ids can trip up [database observation] tools: a deletion followed by an insertion with the same id may be interpreted as an update, with unintended consequences.

</details>

<details>
    <summary>Raw SQL version</summary>

Some readers like to write SQL. Please be welcome:

```swift
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("initial") { db in
            try db.execute(sql: """
                CREATE TABLE player (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    score INTEGER NOT NULL
                )
                """)
        }
        
        return migrator
    }
```

</details>

The migrations are now defined, but they are not applied yet. Let's modify the `AppDatabase` initializer, and *migrate* the database. It means that unapplied migrations are run. In the end, we are sure that the database schema is exactly what we want it to be:

```swift
    /// Creates an `AppDatabase` from a database connection,
    /// and make sure the database schema is ready.
    init(_ dbWriter: DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }
```

> ✅ At this stage, we have an `AppDatabase.shared` object which vends a database that contains a `player` table.

## Inserting Players in the Database, and the Player Struct

The `player` table can't remain empty, or the application will never display anything!

The application will insert players through the `AppDatabase` service. We could define an `AppDatabase.insertPlayer(name:score:)` method. But this does not scale well with the number of player columns: who wants to call a method with a dozen arguments?

Instead, let's define a `Player` struct that groups all player attributes:

```swift
// File: Player.swift

/// A Player (take one)
struct Player {
    var name: String
    var score: Int
}
```

This is enough to define the `AppDatabase.insertPlayer(_:)` method. But let's go further: the app will, eventually, deal with player identifiers. So let's add a `Player.id` property right away:

```swift
/// A Player
struct Player {
    var id: Int64?
    var name: String
    var score: Int
}
```

The type of the `id` property is `Int64?` because it matches the `id` column in the `player` table (SQLite integer primary keys are 64-bit integers, even on 32-bit platforms). When the id is nil, the player is not yet saved in the database. When the id is not nil, it is the identifier of a player in the database.

The `name` and `score` properties are regular `String` and `Int`. They are not optional (`String?` or `Int?`), because we added "not null" constraints on those database columns when we defined the `player` table.

> ✅ Now we have a `Player` type that fits the columns of the `player` database table, and is able to deal with all application needs. This is what GRDB calls a [record type]. At this stage, `Player` has no database power yet, but hold on.

The `Player` type allows `AppDatabase` to insert a player. We can do it with raw SQL:

<details>
    <summary>Raw SQL version</summary>

```swift
// File: AppDatabase.swift

extension AppDatabase {
    /// Inserts a player. When the method returns, the
    /// player id is set to the newly inserted id. 
    func insertPlayer(_ player: inout Player) throws {
        try dbWriter.write { db in
            try insert(db, player: &player)
        }
    }
    
    /// Inserts a player. When the method returns, the
    /// player id is set to the newly inserted id. 
    private func insert(_ db: Database, player: inout Player) throws {
        try db.execute(literal: """
            INSERT INTO player (name, score) 
            VALUES (\(player.name), \(player.score))
            """)
        player.id = db.lastInsertedRowID
    }
}
```

The `insertPlayer(_:)` method calls a private helper method `insert(_:player:)`. This helper method will be reused later in the tutorial.

Note that the helper method calls the `execute(literal:)` method, which avoids [SQL injection], thanks to [SQL Interpolation].

</details>

SQL is just fine, but we can also make `Player` a [persistable record]. With persistable records, you do not have to write the SQL queries that perform common persistence operations.

The `Player` struct adopts the `MutablePersistableRecord` protocol, because the `player` database table has an autoincremented id:

- "Persistable": players can be inserted, updated and deleted.
- "Mutable": a player is modified (mutated) upon insertion, because its `id` property is set from the autoincremented SQLite id.

Conformance to `MutablePersistableRecord` is almost free for types that adopt the standard [Encodable] protocol:

```swift
// File: Player.swift

// Give Player database powers
extension Player: Encodable, MutablePersistableRecord {
    /// Updates a player id after it has been inserted in the database.
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
```

In this tutorial, the name of the database table matches the name of the type, and columns matches properties, so we do not have to configure anything.

<details>
    <summary>Avoiding Encodable</summary>

The `Encodable` protocol is handy, but you may prefer not to use it. In this case, you have to fulfill the persistable record requirements:

```swift
// File: Player.swift

// Give Player database powers
extension Player: MutablePersistableRecord {
    /// Defines the values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["score"] = score
    }
    
    /// Updates a player id after it has been inserted in the database.
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
```

</details>

That's it. And thanks to persistable records, we now support both inserts and updates:

```swift
// File: AppDatabase.swift

extension AppDatabase {
    /// Saves (inserts or updates) a player. When the method returns, the
    /// player id is not nil.
    func savePlayer(_ player: inout Player) throws {
        try dbWriter.write { db in
            try player.save(db)
        }
    }
}
```

Now, we can save players from the app:

```swift
// Inserts a player
var player = Player(id: nil, name: "Arthur", score: 0)
try AppDatabase.shared.savePlayer(player)
print("Player id is \(player.id)") // Prints "Player id is 1"

// Updates a player
player.score = 1000
try AppDatabase.shared.savePlayer(player)
```

> 👆 **Note**: make sure you define the `Encodable` extension to `Player` in the same file where the `Player` struct is defined: this is how you will profit from the synthesized conformance to this protocol.
>
> ✅ At this stage, we can insert and update players in the database.

## Deleting Players

The application can delete players:

- The "Trash" icon at the bottom left of the [screen] deletes all players.
- The "Edit" button at the top left of the screen lets the user delete individual players.
- The player list supports the swipe to delete gesture.

The `AppDatabase` service supports these use cases with two new methods:

```swift
// File: AppDatabase.swift

extension AppDatabase {
    /// Delete the specified players
    func deletePlayers(ids: [Int64]) throws {
        try dbWriter.write { db in
            _ = try Player.deleteAll(db, keys: ids)
        }
    }
    
    /// Delete all players
    func deleteAllPlayers() throws {
        try dbWriter.write { db in
            _ = try Player.deleteAll(db)
        }
    }
}
```

Both `deleteAll(_:)` and `deleteAll(_:keys:)` methods are available for all persistable records.

<details>
    <summary>Raw SQL version</summary>

If you do not want to make `Player` a persistable record, you can fallback to raw SQL:

```swift
// File: AppDatabase.swift

extension AppDatabase {
    /// Delete the specified players
    func deletePlayers(ids: [Int64]) throws {
        try dbWriter.write { db in
            try db.execute(literal: """
                DELETE FROM player WHERE id IN \(ids)
                """)
        }
    }
    
    /// Delete all players
    func deleteAllPlayers() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM player")
        }
    }
}
```

The `deletePlayers(ids:)` method above uses [SQL Interpolation] so that you can embed an array of ids right inside your SQL query (`WHERE id IN \(ids)`). The "really raw" SQL version below is a little more involved:

```swift
    func deletePlayers(ids: [Int64]) throws {
        try dbWriter.write { db in
            if ids.isEmpty {
                // Avoid SQL syntax error
                return
            }
            // DELETE FROM player WHERE id IN (?, ?, ...)
            //                                 ~~~~~~~~~
            //   as many question marks as there are ids
            let placeholders = databaseQuestionMarks(count: ids.count)
            let query = "DELETE FROM player WHERE id IN (\(placeholders))"
            try db.execute(sql: query, arguments: StatementArguments(ids))
        }
    }
```

All the techniques we have seen avoid [SQL injection].

> ✅ At this stage, we can delete all or individual players from the database.

</details>

## Fetching and Modifying Players

The user of the application can edit a player, by tapping on its row: this presents a form where both name & score can be edited. This use case is already fulfilled by the `AppDatabase.savePlayer(_:)` service method, described in the [Inserting Players in the Database, and the Player Struct] chapter.

There is another way to modify players: the refresh button at the bottom center of the [screen]. This one simulates a "real" refresh from, say, a server, and applies random transformations to the player database. We implement this modification of the players database with the `AppDatabase.refreshPlayers()` method:

```swift
// File: AppDatabase.swift

extension AppDatabase {
    /// Refresh all players (by performing some random changes, for demo purpose).
    func refreshPlayers() throws {
        try dbWriter.write { db in
            if try Player.fetchCount(db) == 0 {
                // When database is empty, insert new random players
                try createRandomPlayers(db)
            } else {
                // Insert a player
                if Bool.random() {
                    var player = Player.newRandom()
                    try player.insert(db)
                }
                
                // Delete a random player
                if Bool.random() {
                    try Player.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                
                // Update some players
                for var player in try Player.fetchAll(db) where Bool.random() {
                    try player.updateChanges(db) {
                        $0.score = Player.randomScore()
                    }
                }
            }
        }
    }
    
    private func createRandomPlayers(_ db: Database) throws {
        for _ in 0..<8 {
            var player = Player.newRandom()
            try player.insert(db)
        }
    }
}
```

The `AppDatabase.refreshPlayers()` method calls a private helper method `createRandomPlayers(_:)`. This helper method will be reused later in the tutorial.

<details>
    <summary>ℹ️ Design Notes</summary>

> The role of the `AppDatabase` service is to provide a set of [ACID] transformations, that fully control the state of the database. Either a player is saved, either it is not. Players are refreshed, or they are not. If our application would synchronize its local database with some remote server, we would want players to be fully synchronized, or not at all. Intermediate states such as partially saved, deleted, refreshed, or synchronized players must be avoided, in order to make the application robust. After all, errors happen, and even hard crashes. Thanks to the ACID guarantees provided by SQLite, errors and crashes are unable to threaten important database invariants.
>
> **The added value of the `AppDatabase` service is to provide one method per database transformation needed by the app.** All those methods perform **a single GRDB write**, in order to profit from all ACID guarantees of SQLite transactions. Refreshing players is one of those transformations. Saving a player is another, which supports the user interface for editing of creating players.
>
> :bulb: **Tip**: when two distinct service methods want to reuse a piece of code, we extract it in a helper method such as `createRandomPlayers(_:)` above. Unlike service methods, helper methods access the database through their `Database` argument, not through the `dbWriter` property.

</details>

Refreshing players needs some support from the `Player` record type, so that we can build random players:

```swift
// File: Player.swift

extension Player {
    private static let names = ["Arthur", "Anita", ...]
    
    /// Creates a new player with random name and random score
    static func newRandom() -> Player {
        Player(id: nil, name: randomName(), score: randomScore())
    }
    
    /// Returns a random name
    static func randomName() -> String {
        names.randomElement()!
    }
    
    /// Returns a random score
    static func randomScore() -> Int {
        10 * Int.random(in: 0...100)
    }
}
```

Refreshing players also needs to fetch the players that are randomly updated (`try Player.fetchAll(db)`).

Fetching players is free when `Player` adopts the [Decodable] protocol: we just need to add the [FetchableRecord] conformance:

```swift
// File: Player.swift

extension Player: Decodable, FetchableRecord { }
```

<details>
    <summary>Avoiding Decodable</summary>

The `Decodable` protocol is handy, but you may prefer not to use it. In this case, you have to fulfill the fetchable record requirements:

```swift
// File: Player.swift

extension Player: FetchableRecord {
    /// Creates a player from a database row
    init(row: Row) {
        id = row["id"]
        name = row["name"]
        score = row["score"]
    }
}
```

</details>

<details>
    <summary>Raw SQL version</summary>

Let's write `AppDatabase.refreshPlayers()` without any support from SQL generation provided by record protocols:

```swift
// File: AppDatabase.swift

extension AppDatabase {
    /// Refresh all players (by performing some random changes, for demo purpose).
    func refreshPlayers() throws {
        try dbWriter.write { db in
            if try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player") == 0 {
                // When database is empty, insert new random players
                try createRandomPlayers(db)
            } else {
                // Insert a player
                if Bool.random() {
                    var player = Player.newRandom()
                    try insert(db, player: &player)
                }
                
                // Delete a random player
                if Bool.random() {
                    try db.execute(sql: """
                        DELETE FROM player
                        ORDER BY RANDOM()
                        LIMIT 1
                        """)
                }
                
                // Update some players
                let ids = try Int64.fetchAll(db, sql: "SELECT id FROM player")
                for id in ids where Bool.random() {
                    try db.execute(literal: """
                        UPDATE player
                        SET score = \(Player.randomScore())
                        WHERE id = \(id)
                        """)
                }
            }
        }
    }
    
    private func createRandomPlayers(_ db: Database) throws {
        for _ in 0..<8 {
            var player = Player.newRandom()
            try insert(db, player: &player)
        }
    }
}
```

The `insert(_:player:)` method was defined, with raw SQL, in [Inserting Players in the Database, and the Player Struct].

</details>

> ✅ At this stage, we can fetch players from the database, and modify players in a controlled and robust way.

## Sorting Players

The application [screen] displays a list of players. The user can choose the order of players by tapping the button at the top right of the screen. The app supports two orderings: by descending score, and by ascending name.

In this chapter, we will not describe how the applications keeps its screen synchronized with the content of the database. This will be the topic of [Observing Players].

Here we will extend the `Player` record type so that it provides the **database requests** needed by the application.

<details>
    <summary>ℹ️ Design Notes</summary>

> With GRDB, record types are responsible of their table: they know how data is stored in the database. This is why `Player` is better suited to know what sorting players by name, or by score, means.
>
> On the other side, `Player` does not perform database fetches on its own. Actual database fetches are performed by the application, depending on the user actions, by invoking methods on `AppDatabase.shared`.
>
> `Player` *defines* database requests, and `AppDatabase` *executes* those requests.

</details>

We made `Player` a full-fledged record type in the previous chapters. Record types can profit from the [query interface], a Swift way to build database requests.

In order to build requests that sort by score or by name, we need to define columns. When the `Player` type is [Codable], we can profit from its `CodingKeys` so that the compiler makes sure we do not make any typo:

```swift
// File: Player.swift
extension Player {
    // Player columns are defined from CodingKeys
    fileprivate enum Columns {
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
}
```

<details>
    <summary>ℹ️ Design Notes</summary>

> `Player.Columns` is declared `fileprivate`. The goal is to prevent other application files from messing with the intimate relationship between the `Player` record type and the `player` database table.
>
> Some apps eventually need to relax the visibility of those columns. Until they really have to, though, `fileprivate` is the recommended default for columns.

</details>

<details>
    <summary>Avoiding Codable</summary>

The `Codable` protocol is handy, but you may prefer not to use it. In this case, define columns as a String enum:

```swift
// File: Player.swift
extension Player {
    // Player columns
    fileprivate enum Columns: String, ColumnExpression {
        case name
        case score
    }
}
```

</details>

Following advice from the [Good Practices for Designing Record Types], we can now define player requests in an extension of the `DerivableRequest` protocol:

```swift
// File: Player.swift

/// Define some player requests used by the application.
extension DerivableRequest where RowDecoder == Player {
    /// A request of players ordered by name.
    ///
    /// For example:
    ///
    ///     let players: [Player] = try dbWriter.read { db in
    ///         try Player.all().orderedByName().fetchAll(db)
    ///     }
    func orderedByName() -> Self {
        // Sort by name in a localized case insensitive fashion
        order(Player.Columns.name.collating(.localizedCaseInsensitiveCompare))
    }
    
    /// A request of players ordered by score.
    ///
    /// For example:
    ///
    ///     let players: [Player] = try dbWriter.read { db in
    ///         try Player.all().orderedByScore().fetchAll(db)
    ///     }
    ///     let bestPlayer: Player? = try dbWriter.read { db in
    ///         try Player.all().orderedByScore().fetchOne(db)
    ///     }
    func orderedByScore() -> Self {
        // Sort by descending score, and then by name, in a
        // localized case insensitive fashion
        order(
            Player.Columns.score.desc,
            Player.Columns.name.collating(.localizedCaseInsensitiveCompare))
    }
}
```

Names are sorted according to the `localizedCaseInsensitiveCompare` collation. See [String Comparison](../README.md#string-comparison) for more information.

Writing an "extension of the `DerivableRequest` protocol" may sound intimidating. Well, don't be shy, and look at the sample code above: it contains inline documentation which describes the usage of those requests. Is it more clear now? `DerivableRequest` makes it possible to extend the query interface with custom requests, and also to hide some database implementation details inside a dedicated record type.

If you know the [Active Record](https://guides.rubyonrails.org/active_record_querying.html) Ruby library, you may be reminded of [scopes](https://guides.rubyonrails.org/active_record_querying.html#scopes):

```ruby
# player.rb
class Player < ApplicationRecord
  scope :ordered_by_name, -> { order(name: :asc) }
end
```

<details>
    <summary>Raw SQL version</summary>

You can build SQL requests with `SQLRequest`, which profits from [SQL Interpolation]. If you have the `Player` type conform to [FetchableRecord], those requests will be able to fetch. Otherwise, we'll have to fetch raw database rows and we will have more work to do. But those requests can still be defined:

```swift
// File: Player.swift

/// Define some player requests used by the application.
extension Player {
    /// A request of players ordered by name.
    ///
    /// For example:
    ///
    ///     let players: [Player] = try dbWriter.read { db in
    ///         try Player.orderedByName().fetchAll(db)
    ///     }
    static func orderedByName() -> SQLRequest<Player> {
        // Sort by name in a localized case insensitive fashion
        """
        SELECT * FROM player
        ORDER BY name COLLATING \(.localizedCaseInsensitiveCompare)
        """
    }
    
    /// A request of players ordered by score.
    ///
    /// For example:
    ///
    ///     let players: [Player] = try dbWriter.read { db in
    ///         try Player.orderedByScore().fetchAll(db)
    ///     }
    static func orderedByScore() -> SQLRequest<Player> {
        // Sort by descending score, and then by name, in a
        // localized case insensitive fashion
        """
        SELECT * FROM player
        ORDER BY score DESC,
                 name COLLATING \(.localizedCaseInsensitiveCompare)
        """
    }
}
```

Compared to query interface requests, raw SQL requests lose two benefits:

- SQL requests are not composable together. You can not reuse them. For example:

    ```swift
    // A request from a future version of our app.
    // Request composition is only possible for query interface requests.
    let request = Player.all()
        .filter(team: .red)
        .including(all: Player.awards)
        .orderedByName()
    ```

- SQL requests do not auto-optimize when you are only interested in the first row:
    
    ```swift
    // No automatic appending of `LIMIT 1`, as query interface requests do.
    let bestPlayer: Player? = try dbWriter.read { db in
        try Player.orderedByScore().fetchOne(db)
    }
    ```
    
</details>

> ✅ At this stage, we have defined the database requests that can feed the list of players in the application.

## Observing Players

## The Initial Application State

Let's perform a little polishing step, so that the first time the application is launched, it is already populated with a few players. We write a demo application, and a demo is nicer when the user can play right away.

To this end, we create a new `AppDatabase.createRandomPlayersIfEmpty()` method. It reuses the `createRandomPlayers(_:)` helper method defined in the [Fetching and Modifying Players] chapter:

```swift
// File: AppDatabase.swift

extension AppDatabase {
    /// Create random players if the database is empty.
    func createRandomPlayersIfEmpty() throws {
        try dbWriter.write { db in
            if try Player.fetchCount(db) == 0 {
                try createRandomPlayers(db)
            }
        }
    }
}
```

And we modify `AppDatabase.makeShared()` so that the application never boots with an empty database:

```swift
// File: Persistence.swift
import GRDB

extension AppDatabase {
    /// The database for the application
    static let shared = makeShared()
    
    private static func makeShared() -> AppDatabase {
        do {
            // Create a folder for storing the SQLite database
            let fileManager = FileManager()
            let folderURL = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("database", isDirectory: true)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            // Connect to a database on disk
            let dbURL = folderURL.appendingPathComponent("db.sqlite")
            let dbPool = try DatabasePool(path: dbURL.path)
            
            // Create the AppDatabase
            let appDatabase = try AppDatabase(dbPool)
            
            // Populate the database if it is empty, for better demo purpose.
            try appDatabase.createRandomPlayersIfEmpty()
            
            return appDatabase
        } catch {
            fatalError("Unresolved error \(error)")
        }
    }
}
```

<details>
    <summary>ℹ️ Design Notes</summary>

> We do not call `createRandomPlayersIfEmpty()` from the `AppDatabase` initializer, or from its migrator, because we also need to create empty databases (for tests, or some SwiftUI previews). The correct place is indeed `makeShared()`, the method that creates the database for the application itself.

</details>

> ✅ At this stage, we have a polished Database Access Layer that makes sure the demo app looks good.

## Testing the Database

[The Database Service]: #the-database-service
[The Shared Application Database]: #the-shared-application-database
[The Database Schema]: #the-database-schema
[Inserting Players in the Database, and the Player Struct]: #inserting-players-in-the-database-and-the-player-struct
[Deleting Players]: #deleting-players
[Fetching and Modifying Players]: #fetching-and-modifying-players
[Sorting Players]: #sorting-players
[Observing Players]: #observing-players
[The Initial Application State]: #the-initial-application-state
[Testing the Database]: #testing-the-database

[demo applications]: DemoApps
[UIKit demo application]: DemoApps/GRDBDemoiOS/README.md
[Combine + SwiftUI Demo Application]: DemoApps/GRDBCombineDemo/README.md
[database connection]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
[DatabaseQueue]: ../README.md#database-queues
[DatabasePool]: ../README.md#database-pools
[migrations]: Migrations.md
[Codable]: https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types
[Encodable]: https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types
[Decodable]: https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types
[record type]: ../README.md#records
[persistable record]: ../README.md#persistablerecord-protocol
[FetchableRecord]: ../README.md#fetchablerecord-protocol
[WAL mode]: https://sqlite.org/wal.html
[data protection]: ../README.md#data-protection
[Associations]: AssociationsBasics.md
[Sharing a database]: SharingADatabase.md
[database observation]: ../README.md#database-changes-observation
[SQL Interpolation]: SQLInterpolation.md
[SQL injection]: ../README.md#avoiding-sql-injection
[screenshot]: https://github.com/groue/GRDB.swift/raw/master/Documentation/DemoApps/GRDBDemoiOS/Screenshot.png
[screen]: https://github.com/groue/GRDB.swift/raw/master/Documentation/DemoApps/GRDBDemoiOS/Screenshot.png
[ACID]: https://en.wikipedia.org/wiki/ACID
[query interface]: ../README.md#the-query-interface
[Good Practices for Designing Record Types]: GoodPracticesForDesigningRecordTypes.md
