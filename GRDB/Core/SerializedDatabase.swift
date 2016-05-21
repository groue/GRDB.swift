import Foundation

/// A class that serializes accesses to a database.
final class SerializedDatabase {
    /// The database connection
    private let db: Database
    
    /// The database configuration
    var configuration: Configuration {
        return db.configuration
    }
    
    /// The dispatch queue
    private let queue: dispatch_queue_t
    
    init(path: String, configuration: Configuration = Configuration(), schemaCache: DatabaseSchemaCacheType) throws {
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
        
        db = try Database(path: path, configuration: config, schemaCache: schemaCache)
        queue = DatabaseScheduler.makeSerializedQueueAllowing(database: db)
        try dispatchSync(queue) {
            try self.db.setup()
        }
    }
    
    deinit {
        performSync { db in
            db.close()
        }
    }
    
    /// Synchronously executes a block the serialized dispatch queue, and returns
    /// its result.
    ///
    /// This method is *not* reentrant.
    func performSync<T>(block: (db: Database) throws -> T) rethrows -> T {
        return try DatabaseScheduler.dispatchSync(queue, database: db, block: block)
    }
    
    /// Asynchronously executes a block in the serialized dispatch queue.
    func performAsync(block: (db: Database) -> Void) {
        dispatch_async(queue) {
            block(db: self.db)
        }
    }
    
    /// Executes the block in the current queue.
    ///
    /// - precondition: the current dispatch queue is valid.
    func perform<T>(block: (db: Database) throws -> T) rethrows -> T {
        preconditionValidQueue()
        return try block(db: db)
    }
    
    /// Fatal error if current dispatch queue is not valid.
    func preconditionValidQueue(@autoclosure message: () -> String = "Database was not used on the correct thread.", file: StaticString = #file, line: UInt = #line) {
        DatabaseScheduler.preconditionValidQueue(db, message, file: file, line: line)
    }
}
