import Foundation
import GRDB
import os.log

/// The type that provides access to the application database.
///
/// For example:
///
/// ```swift
/// // Create an empty, in-memory, AppDatabase
/// let config = AppDatabase.makeConfiguration()
/// let dbQueue = try DatabaseQueue(configuration: config)
/// let appDatabase = try AppDatabase(dbQueue)
/// ```
final class AppDatabase: Sendable {
    /// Access to the database.
    ///
    /// See <https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseconnections>
    private let dbWriter: any DatabaseWriter
    
    /// Creates a `AppDatabase`, and makes sure the database schema
    /// is ready.
    ///
    /// - important: Create the `DatabaseWriter` with a configuration
    ///   returned by ``makeConfiguration(_:)``.
    init(_ dbWriter: any GRDB.DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }
    
    /// The DatabaseMigrator that defines the database schema.
    ///
    /// See <https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/migrations>
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
#if DEBUG
        // Speed up development by nuking the database when migrations change
        // See <https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/migrations#The-eraseDatabaseOnSchemaChange-Option>
        migrator.eraseDatabaseOnSchemaChange = true
#endif
        
        migrator.registerMigration("v1") { db in
            // Create a table
            // See <https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseschema>
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

// MARK: - Database Configuration

extension AppDatabase {
    // Uncomment for enabling SQL logging
    // private static let sqlLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SQL")
    
    /// Returns a database configuration suited for `AppDatabase`.
    ///
    /// - parameter config: A base configuration.
    static func makeConfiguration(_ config: Configuration = Configuration()) -> Configuration {
        // var config = config
        //
        // Add custom SQL functions or collations, if needed:
        // config.prepareDatabase { db in
        //     db.add(function: ...)
        // }
        //
        // Uncomment for enabling SQL logging if the `SQL_TRACE` environment variable is set.
        // See <https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/database/trace(options:_:)>
        // if ProcessInfo.processInfo.environment["SQL_TRACE"] != nil {
        //     config.prepareDatabase { db in
        //         let dbName = db.description
        //         db.trace { event in
        //             // Sensitive information (statement arguments) is not
        //             // logged unless config.publicStatementArguments is set
        //             // (see below).
        //             sqlLogger.debug("\(dbName): \(event)")
        //         }
        //     }
        // }
        //
        // #if DEBUG
        // // Protect sensitive information by enabling verbose debugging in
        // // DEBUG builds only.
        // // See <https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/configuration/publicstatementarguments>
        // config.publicStatementArguments = true
        // #endif
        
        return config
    }
}

// MARK: - Database Access: Writes
// The write methods execute invariant-preserving database transactions.
// In this demo repository, they are pretty simple.

extension AppDatabase {
    /// Saves (inserts or updates) a player. When the method returns, the
    /// player is present in the database, and its id is not nil.
    func savePlayer(_ player: inout Player) throws {
        try dbWriter.write { db in
            try player.save(db)
        }
    }
    
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
    
    /// Refresh all players (by performing some random changes, for demo purpose).
    func refreshPlayers() async throws {
        try await dbWriter.write { [self] db in
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
    /// Provides a read-only access to the database.
    var reader: any GRDB.DatabaseReader {
        dbWriter
    }
}
