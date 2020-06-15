import GRDB

/// AppDatabase lets the application access the database.
///
/// It applies the pratices recommended at
/// https://github.com/groue/GRDB.swift/blob/master/Documentation/GoodPracticesForDesigningRecordTypes.md
final class AppDatabase {
    private let dbQueue: DatabaseQueue
    
    /// Creates an AppDatabase and updates its schema if necessary.
    init(_ dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try migrator.migrate(dbQueue)
    }
    
    /// The DatabaseMigrator that defines the database schema.
    ///
    /// See https://github.com/groue/GRDB.swift/blob/master/Documentation/Migrations.md
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createPlayer") { db in
            // Create a table
            // See https://github.com/groue/GRDB.swift#create-tables
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                
                // Sort player names in a localized case insensitive fashion by default
                // See https://github.com/groue/GRDB.swift/blob/master/README.md#unicode
                t.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
                
                t.column("score", .integer).notNull()
            }
        }
        
        migrator.registerMigration("fixtures") { db in
            // Populate the players table with random data
            for _ in 0..<8 {
                var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                try player.insert(db)
            }
        }
        
//        // Migrations for future application versions will be inserted here:
//        migrator.registerMigration(...) { db in
//            ...
//        }
        
        return migrator
    }
}

// MARK: - Database Access
//
// This extension defines methods that fulfill application needs, both in terms
// of writes and reads.

extension AppDatabase {
    
    // MARK: Writes
    
    /// Save (insert or update) a player.
    func savePlayer(_ player: inout Player) throws {
        try dbQueue.write { db in
            try player.save(db)
        }
    }
    
    /// Delete one player
    func deletePlayer(_ player: Player) throws {
        try dbQueue.write { db in
            _ = try player.delete(db)
        }
    }
    
    /// Delete all players
    func deleteAllPlayers() throws {
        try dbQueue.write { db in
            _ = try Player.deleteAll(db)
        }
    }
    
    /// Refresh all players (by performing some random changes, for demo purpose).
    func refreshPlayers() throws {
        try dbQueue.write { db in
            if try Player.fetchCount(db) == 0 {
                // Insert new random players
                for _ in 0..<8 {
                    var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                    try player.insert(db)
                }
            } else {
                // Insert a player
                if Bool.random() {
                    var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
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
    
    // MARK: Reads
    
    /// Tracks changes in the number of players
    func observePlayerCount(
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Int) -> Void)
        -> DatabaseCancellable
    {
        ValueObservation
            .tracking(Player.fetchCount)
            .start(
                in: dbQueue,
                onError: onError,
                onChange: onChange)
    }
    
    /// Tracks changes in players ordered by name
    func observePlayersOrderedByName(
        onError: @escaping (Error) -> Void,
        onChange: @escaping ([Player]) -> Void)
        -> DatabaseCancellable
    {
        ValueObservation
            .tracking(Player.all().orderedByName().fetchAll)
            .start(
                in: dbQueue,
                onError: onError,
                onChange: onChange)
    }
    
    /// Tracks changes in players ordered by score
    func observePlayersOrderedByScore(
        onError: @escaping (Error) -> Void,
        onChange: @escaping ([Player]) -> Void)
        -> DatabaseCancellable
    {
        ValueObservation
            .tracking(Player.all().orderedByScore().fetchAll)
            .start(
                in: dbQueue,
                onError: onError,
                onChange: onChange)
    }
}

