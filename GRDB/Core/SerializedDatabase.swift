import Foundation

/// A class that serializes accesses to a database.
final class SerializedDatabase {
    /// The database connection
    private let db: Database
    
    /// The database configuration
    var configuration: Configuration {
        return db.configuration
    }
    
    /// The path to the database file
    var path: String
    
    /// The dispatch queue
    private let queue: DispatchQueue
    
    init(path: String, configuration: Configuration = Configuration(), schemaCache: DatabaseSchemaCache) throws {
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
        config.threadingMode = .multiThread
        
        db = try Database(path: path, configuration: config, schemaCache: schemaCache)
        queue = SchedulingWatchdog.makeSerializedQueue(allowingDatabase: db)
        self.path = path
        try queue.sync {
            try db.setup()
        }
    }
    
    deinit {
        // Database may be deallocated in its own queue: allow reentrancy
        reentrantSync { db in
            db.close()
        }
    }
    
    /// Synchronously executes a block the serialized dispatch queue, and
    /// returns its result.
    ///
    /// This method is *not* reentrant.
    func sync<T>(_ block: (Database) throws -> T) rethrows -> T {
        // Three different cases:
        //
        // 1. A database is invoked from some queue like the main queue:
        //
        //      dbQueue.inDatabase { db in       // <-- we're here
        //      }
        //
        // 2. A database is invoked in a reentrant way:
        //
        //      dbQueue.inDatabase { db in
        //          dbQueue.inDatabase { db in   // <-- we're here
        //          }
        //      }
        //
        // 3. A database in invoked from another database:
        //
        //      dbQueue1.inDatabase { db1 in
        //          dbQueue2.inDatabase { db2 in // <-- we're here
        //          }
        //      }
        
        guard let watchdog = SchedulingWatchdog.current else {
            // Case 1
            return try queue.sync {
                try block(db)
            }
        }
        
        // Case 2 is forbidden.
        GRDBPrecondition(!watchdog.allows(db), "Database methods are not reentrant.")
        
        // Case 3
        return try queue.sync {
            try SchedulingWatchdog.current!.allowing(databases: watchdog.allowedDatabases) {
                try block(db)
            }
        }
    }
    
    /// Synchronously executes a block the serialized dispatch queue, and
    /// returns its result.
    ///
    /// This method is reentrant.
    func reentrantSync<T>(_ block: (Database) throws -> T) rethrows -> T {
        // Three different cases:
        //
        // 1. A database is invoked from some queue like the main queue:
        //
        //      dbQueue.inDatabase { db in       // <-- we're here
        //      }
        //
        // 2. A database is invoked in a reentrant way:
        //
        //      dbQueue.inDatabase { db in
        //          dbQueue.inDatabase { db in   // <-- we're here
        //          }
        //      }
        //
        // 3. A database in invoked from another database:
        //
        //      dbQueue1.inDatabase { db1 in
        //          dbQueue2.inDatabase { db2 in // <-- we're here
        //          }
        //      }
        
        guard let watchdog = SchedulingWatchdog.current else {
            // Case 1
            return try queue.sync {
                try block(db)
            }
        }
        
        // Case 2
        if watchdog.allows(db) {
            return try block(db)
        }
        
        // Case 3
        return try queue.sync {
            try SchedulingWatchdog.current!.allowing(databases: watchdog.allowedDatabases) {
                try block(db)
            }
        }
    }
    
    /// Asynchronously executes a block in the serialized dispatch queue.
    func async(_ block: @escaping (Database) -> Void) {
        queue.async {
            block(self.db)
        }
    }
    
    /// Returns true if any only if the current dispatch queue is valid.
    var onValidQueue: Bool {
        return SchedulingWatchdog.allows(db)
    }
    
    /// Executes the block in the current queue.
    ///
    /// - precondition: the current dispatch queue is valid.
    func execute<T>(_ block: (Database) throws -> T) rethrows -> T {
        preconditionValidQueue()
        return try block(db)
    }
    
    /// Fatal error if current dispatch queue is not valid.
    func preconditionValidQueue(_ message: @autoclosure() -> String = "Database was not used on the correct thread.", file: StaticString = #file, line: UInt = #line) {
        SchedulingWatchdog.preconditionValidQueue(db, message, file: file, line: line)
    }
}
