import GRDB

/// Returns an empty in-memory database for the application.
func emptyDatabaseQueue() -> DatabaseQueue {
    let dbQueue = DatabaseQueue()
    try! migrator().migrate(dbQueue)
    return dbQueue
}

/// Returns an in-memory database that contains one player.
///
/// - parameter playerId: The ID of the inserted player.
func populatedDatabaseQueue(playerId: Int64? = nil) -> DatabaseQueue {
    let dbQueue = emptyDatabaseQueue()
    try! dbQueue.write { db in
        // insert a random player (and ignore generated id)
        _ = try Player.makeRandom(id: playerId).inserted(db)
    }
    return dbQueue
}

/// The migrator that defines the schema of the database.
private func migrator() -> DatabaseMigrator {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("createPlayer") { db in
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("score", .integer).notNull()
            t.column("photoID", .integer).notNull()
        }
    }
    return migrator
}
