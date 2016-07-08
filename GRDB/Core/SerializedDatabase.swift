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
        // Three diffent cases:
        //
        // 1. A database is invoked from some queue like the main queue:
        //
        //      dbQueue.inDatabase { db in
        //      }
        //
        // 2. A database is invoked in a reentrant way:
        //
        //      dbQueue.inDatabase { db in
        //          dbQueue.inDatabase { db in
        //          }
        //      }
        //
        // 3. A database in invoked from another database:
        //
        //      dbQueue1.inDatabase { db1 in
        //          dbQueue2.inDatabase { db2 in
        //          }
        //      }
        
        if let sourceScheduler = DatabaseScheduler.currentScheduler() {
            // Case 2 or 3:
            //
            // 2. A database is invoked in a reentrant way:
            //
            //      dbQueue.inDatabase { db in
            //          dbQueue.inDatabase { db in
            //          }
            //      }
            //
            // 3. A database in invoked from another database:
            //
            //      dbQueue1.inDatabase { db1 in
            //          dbQueue2.inDatabase { db2 in
            //          }
            //      }
            //
            // 2 is forbidden.
            GRDBPrecondition(!sourceScheduler.allows(db), "Database methods are not reentrant.")
            
            // Case 3:
            //
            // 3. A database in invoked from another database:
            //
            //      dbQueue1.inDatabase { db1 in
            //          dbQueue2.inDatabase { db2 in
            //          }
            //      }
            //
            // Let's enter the new queue, and temporarily allow the
            // currently allowed databases inside.
            //
            // The impl function helps us turn dispatch_sync into a rethrowing function
            func impl(queue: dispatch_queue_t, db: Database, block: (db: Database) throws -> T, onError: (ErrorType) throws -> ()) rethrows -> T {
                var result: T? = nil
                var blockError: ErrorType? = nil
                dispatch_sync(queue) {
                    let targetScheduler = DatabaseScheduler.currentScheduler()!
                    assert(targetScheduler.allowedDatabases[0] === db) // sanity check
                    
                    do {
                        let backup = targetScheduler.allowedDatabases
                        targetScheduler.allowedDatabases.appendContentsOf(sourceScheduler.allowedDatabases)
                        defer {
                            targetScheduler.allowedDatabases = backup
                        }
                        result = try block(db: db)
                    } catch {
                        blockError = error
                    }
                }
                if let blockError = blockError {
                    try onError(blockError)
                }
                return result!
            }
            return try impl(queue, db: db, block: block, onError: { throw $0 })
        } else {
            // Case 1:
            //
            // 1. A database is invoked from some queue like the main queue:
            //
            //      dbQueue.inDatabase { db in
            //      }
            //
            // Just dispatch block to queue:
            //
            // The impl function helps us turn dispatch_sync into a rethrowing function
            func impl(queue: dispatch_queue_t, db: Database, block: (db: Database) throws -> T, onError: (ErrorType) throws -> ()) rethrows -> T {
                var result: T? = nil
                var blockError: ErrorType? = nil
                dispatch_sync(queue) {
                    do {
                        result = try block(db: db)
                    } catch {
                        blockError = error
                    }
                }
                if let blockError = blockError {
                    try onError(blockError)
                }
                return result!
            }
            return try impl(queue, db: db, block: block, onError: { throw $0 })
        }
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
