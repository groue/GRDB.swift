import Foundation
import GRDB

/// AppDatabase lets the application access the database.
///
/// It applies the pratices recommended at
/// <https://github.com/groue/GRDB.swift/blob/master/Documentation/GoodPracticesForDesigningRecordTypes.md>
struct AppDatabase {
    /// Creates an `AppDatabase`, and make sure the database schema is ready.
    init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }
    
    /// Provides access to the database.
    ///
    /// Application can use a `DatabasePool`, while SwiftUI previews and tests
    /// can use a fast in-memory `DatabaseQueue`.
    ///
    /// See <https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections>
    private let dbWriter: any DatabaseWriter
    
    /// The DatabaseMigrator that defines the database schema.
    ///
    /// See <https://github.com/groue/GRDB.swift/blob/master/Documentation/Migrations.md>
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        #if DEBUG
        // Speed up development by nuking the database when migrations change
        // See https://github.com/groue/GRDB.swift/blob/master/Documentation/Migrations.md#the-erasedatabaseonschemachange-option
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        
        migrator.registerMigration("createPlayer") { db in
            // Create a table
            // See https://github.com/groue/GRDB.swift#create-tables
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
}

// MARK: - Database Access: Writes

extension AppDatabase {
    /// A validation error that prevents some players from being saved into
    /// the database.
    enum ValidationError: LocalizedError {
        case missingName
        
        var errorDescription: String? {
            switch self {
            case .missingName:
                return "Please provide a name"
            }
        }
    }
    
    /// Saves (inserts or updates) a player. When the method returns, the
    /// player is present in the database, and its id is not nil.
    func savePlayer(_ player: inout Player) async throws {
        if player.name.isEmpty {
            throw ValidationError.missingName
        }
        player = try await dbWriter.write { [player] db in
            try player.saved(db)
        }
    }
    
    /// Delete the specified players
    func deletePlayers(ids: [Int64]) async throws {
        try await dbWriter.write { db in
            _ = try Player.deleteAll(db, ids: ids)
        }
    }
    
    /// Delete all players
    func deleteAllPlayers() async throws {
        try await dbWriter.write { db in
            _ = try Player.deleteAll(db)
        }
    }
    
    /// Refresh all players (by performing some random changes, for demo purpose).
    func refreshPlayers() async throws {
        try await dbWriter.write { db in
            if try Player.all().isEmpty(db) {
                // When database is empty, insert new random players
                try createRandomPlayers(db)
            } else {
                // Insert a player
                if Bool.random() {
                    _ = try Player.makeRandom().inserted(db) // insert but ignore inserted id
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
    
    /// Create random players if the database is empty.
    func createRandomPlayersIfEmpty() throws {
        try dbWriter.write { db in
            if try Player.all().isEmpty(db) {
                try createRandomPlayers(db)
            }
        }
    }

    static let uiTestPlayers = [
        Player(id: nil, name: "Arthur", score: 5),
        Player(id: nil, name: "Barbara", score: 6),
        Player(id: nil, name: "Craig", score: 8),
        Player(id: nil, name: "David", score: 4),
        Player(id: nil, name: "Elena", score: 1),
        Player(id: nil, name: "Frederik", score: 2),
        Player(id: nil, name: "Gilbert", score: 7),
        Player(id: nil, name: "Henriette", score: 3)]

    func createPlayersForUITests() throws {
        try dbWriter.write { db in
            try AppDatabase.uiTestPlayers.forEach { player in
                _ = try player.inserted(db) // insert but ignore inserted id
            }
        }
    }
    
    /// Support for `createRandomPlayersIfEmpty()` and `refreshPlayers()`.
    private func createRandomPlayers(_ db: Database) throws {
        for _ in 0..<8 {
            _ = try Player.makeRandom().inserted(db) // insert but ignore inserted id
        }
    }
}

// MARK: - Database Access: Reads

// This demo app does not provide any specific reading method, and instead
// gives an unrestricted read-only access to the rest of the application.
// In your app, you are free to choose another path, and define focused
// reading methods.
extension AppDatabase {
    /// Provides a read-only access to the database
    var databaseReader: DatabaseReader {
        dbWriter
    }
}
