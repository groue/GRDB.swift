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
    
    init(
        path: String,
        configuration: Configuration = Configuration(),
        schemaCache: DatabaseSchemaCache,
        defaultLabel: String,
        purpose: String? = nil)
        throws
    {
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
        
        self.path = path
        self.db = try Database(path: path, configuration: config, schemaCache: schemaCache)
        self.queue = configuration.makeDispatchQueue(defaultLabel: defaultLabel, purpose: purpose)
        SchedulingWatchdog.allowDatabase(db, onQueue: queue)
        try queue.sync {
            do {
                try db.setup()
            } catch {
                db.close()
                throw error
            }
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
        //      serializedDatabase.sync { db in       // <-- we're here
        //      }
        //
        // 2. A database is invoked in a reentrant way:
        //
        //      serializedDatabase.sync { db in
        //          serializedDatabase.sync { db in   // <-- we're here
        //          }
        //      }
        //
        // 3. A database in invoked from another database:
        //
        //      serializedDatabase1.sync { db1 in
        //          serializedDatabase2.sync { db2 in // <-- we're here
        //          }
        //      }
        
        guard let watchdog = SchedulingWatchdog.current else {
            // Case 1
            return try queue.sync {
                defer { preconditionNoUnsafeTransactionLeft(db) }
                return try block(db)
            }
        }
        
        // Case 2 is forbidden.
        GRDBPrecondition(!watchdog.allows(db), "Database methods are not reentrant.")
        
        // Case 3
        return try queue.sync {
            try SchedulingWatchdog.current!.inheritingAllowedDatabases(from: watchdog) {
                defer { preconditionNoUnsafeTransactionLeft(db) }
                return try block(db)
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
        //      serializedDatabase.reentrantSync { db in       // <-- we're here
        //      }
        //
        // 2. A database is invoked in a reentrant way:
        //
        //      serializedDatabase.reentrantSync { db in
        //          serializedDatabase.reentrantSync { db in   // <-- we're here
        //          }
        //      }
        //
        // 3. A database in invoked from another database:
        //
        //      serializedDatabase1.reentrantSync { db1 in
        //          serializedDatabase2.reentrantSync { db2 in // <-- we're here
        //          }
        //      }
        
        guard let watchdog = SchedulingWatchdog.current else {
            // Case 1
            return try queue.sync {
                // Since we are reentrant, a transaction may already be opened.
                // In this case, don't check for unsafe transaction at the end.
                if db.isInsideTransaction {
                    return try block(db)
                } else {
                    defer { preconditionNoUnsafeTransactionLeft(db) }
                    return try block(db)
                }
            }
        }
        
        // Case 2
        if watchdog.allows(db) {
            // Since we are reentrant, a transaction may already be opened.
            // In this case, don't check for unsafe transaction at the end.
            if db.isInsideTransaction {
                return try block(db)
            } else {
                defer { preconditionNoUnsafeTransactionLeft(db) }
                return try block(db)
            }
        }
        
        // Case 3
        return try queue.sync {
            try SchedulingWatchdog.current!.inheritingAllowedDatabases(from: watchdog) {
                // Since we are reentrant, a transaction may already be opened.
                // In this case, don't check for unsafe transaction at the end.
                if db.isInsideTransaction {
                    return try block(db)
                } else {
                    defer { preconditionNoUnsafeTransactionLeft(db) }
                    return try block(db)
                }
            }
        }
    }
    
    /// Asynchronously executes a block in the serialized dispatch queue.
    func async(_ block: @escaping (Database) -> Void) {
        queue.async {
            block(self.db)
            self.preconditionNoUnsafeTransactionLeft(self.db)
        }
    }
    
    /// Returns true if any only if the current dispatch queue is valid.
    var onValidQueue: Bool {
        return SchedulingWatchdog.current?.allows(db) ?? false
    }
    
    /// Executes the block in the current queue.
    ///
    /// - precondition: the current dispatch queue is valid.
    func execute<T>(_ block: (Database) throws -> T) rethrows -> T {
        preconditionValidQueue()
        return try block(db)
    }
    
    func interrupt() {
        // Intentionally not scheduled in our serial queue
        db.interrupt()
    }
    
    func suspend() {
        // Intentionally not scheduled in our serial queue
        db.suspend()
    }
    
    func resume() {
        // Intentionally not scheduled in our serial queue
        db.resume()
    }
    
    /// Fatal error if current dispatch queue is not valid.
    func preconditionValidQueue(
        _ message: @autoclosure() -> String = "Database was not used on the correct thread.",
        file: StaticString = #file,
        line: UInt = #line)
    {
        SchedulingWatchdog.preconditionValidQueue(db, message(), file: file, line: line)
    }
    
    /// Fatal error if a transaction has been left opened.
    private func preconditionNoUnsafeTransactionLeft(
        _ db: Database,
        _ message: @autoclosure() -> String = "A transaction has been left opened at the end of a database access",
        file: StaticString = #file,
        line: UInt = #line)
    {
        GRDBPrecondition(
            configuration.allowsUnsafeTransactions || !db.isInsideTransaction,
            message(),
            file: file,
            line: line)
    }
}
