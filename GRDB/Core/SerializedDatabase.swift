/// A class that serializes accesses to a database.
final class SerializedDatabase {
    /// The database
    private let database: Database
    
    /// The database configuration
    var configuration: Configuration {
        return database.configuration
    }
    
    /// The dispatch queue
    private let queue: dispatch_queue_t
    
    convenience init(path: String, configuration: Configuration = Configuration(), schemaCache: DatabaseSchemaCacheType) throws {
        // According to https://www.sqlite.org/threadsafe.html
        //
        // > SQLite support three different threading modes:
        // >
        // > 1. Multi-thread. In this mode, SQLite can be safely used by
        // >    multiple threads provided that no single database connection is
        // >    used simultaneously in two or more threads.
        // >
        // > 2. Serialized. In serialized mode, SQLite can be safely used by
        // >    multiple threads with no restriction.
        // >
        // > [...]
        // >
        // > The default mode is serialized.
        //
        // Since our database connection is only used via our serial dispatch
        // queue, there is no purpose using the default serialized mode.
        var config = configuration
        config.threadingMode = .MultiThread
        
        let database = try Database(path: path, configuration: config, schemaCache: schemaCache)
        self.init(database: database)
    }
    
    private init(database: Database) {
        self.database = database
        self.queue = dispatch_queue_create("com.github.groue.GRDB", nil)
        
        // Activate database.preconditionValidQueue()
        let databaseQueueID = unsafeBitCast(database, UnsafeMutablePointer<Void>.self)
        dispatch_queue_set_specific(queue, Database.databaseQueueIDKey, databaseQueueID, nil)
        database.databaseQueueID = databaseQueueID
    }
    
    func inDatabase<T>(block: (db: Database) throws -> T) rethrows -> T {
        // This method is NOT reentrant.
        //
        // Avoiding dispatch_sync and calling block() right away if the specific
        // is currently self.databaseQueueID looks like a promising solution:
        //
        //     serializedDatabase.inDatabase { db in
        //         serializedDatabase.inDatabase { db in
        //             // Look, ma! I'm reentrant!
        //         }
        //     }
        //
        // However it does not survive this code, which deadlocks:
        //
        //     let queue = dispatch_queue_create("...", nil)
        //     serializedDatabase.inDatabase { db in
        //         dispatch_sync(queue) {
        //             serializedDatabase.inDatabase { db in
        //                 // Never run
        //             }
        //         }
        //     }
        //
        // I try not to ship half-baked solutions, so until a complete solution
        // is found to this problem, I prefer discouraging reentrancy.
        precondition(database.databaseQueueID != dispatch_get_specific(Database.databaseQueueIDKey), "Database methods are not reentrant.")
        return try dispatchSync(queue) {
            try block(db: self.database)
        }
    }
}
