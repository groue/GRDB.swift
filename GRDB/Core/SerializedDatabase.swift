import Foundation

/// A class that serializes accesses to an SQLite connection.
final class SerializedDatabase {
    /// The database connection
    private let db: Database
    
    /// The database configuration
    var configuration: Configuration { db.configuration }
    
    /// The path to the database file
    let path: String
    
    /// The dispatch queue
    private let queue: DispatchQueue
    
    /// If true, overrides `configuration.allowsUnsafeTransactions`.
    private var allowsUnsafeTransactions = false
    
    init(
        path: String,
        configuration: Configuration = Configuration(),
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
        let identifier = configuration.identifier(defaultLabel: defaultLabel, purpose: purpose)
        self.db = try Database(
            path: path,
            description: identifier,
            configuration: config)
        if config.readonly {
            self.queue = configuration.makeReaderDispatchQueue(label: identifier)
        } else {
            self.queue = configuration.makeWriterDispatchQueue(label: identifier)
        }
        SchedulingWatchdog.allowDatabase(db, onQueue: queue)
        try queue.sync {
            do {
                try db.setUp()
            } catch {
                // Recent versions of the Swift compiler will call the
                // deinitializer. Older ones won't.
                // See https://bugs.swift.org/browse/SR-13746 for details.
                //
                // So let's close the database now. The deinitializer
                // will only close the database if needed.
                db.close_v2()
                throw error
            }
        }
    }
    
    deinit {
        // Database may be deallocated in its own queue: allow reentrancy
        reentrantSync { db in
            db.close_v2()
        }
    }
    
    /// Executes database operations, returns their result after they have
    /// finished executing, and allows or forbids long-lived transactions.
    ///
    /// This method is not reentrant.
    ///
    /// - parameter allowingLongLivedTransaction: When true, the
    ///   ``Configuration/allowsUnsafeTransactions`` configuration flag is
    ///   ignored until this method is called again with false.
    func sync<T>(allowingLongLivedTransaction: Bool, _ body: (Database) throws -> T) rethrows -> T {
        try sync { db in
            self.allowsUnsafeTransactions = allowingLongLivedTransaction
            return try body(db)
        }
    }
    
    /// Executes database operations, and returns their result after they
    /// have finished executing.
    ///
    /// This method is not reentrant.
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
    
    /// Executes database operations, returns their result after they have
    /// finished executing, and allows or forbids long-lived transactions.
    ///
    /// This method is reentrant.
    ///
    /// - parameter allowingLongLivedTransaction: When true, the
    ///   ``Configuration/allowsUnsafeTransactions`` configuration flag is
    ///   ignored until this method is called again with false.
    func reentrantSync<T>(allowingLongLivedTransaction: Bool, _ body: (Database) throws -> T) rethrows -> T {
        try reentrantSync { db in
            self.allowsUnsafeTransactions = allowingLongLivedTransaction
            return try body(db)
        }
    }
    
    /// Executes database operations, and returns their result after they
    /// have finished executing.
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
    
    /// Schedules database operations for execution, and returns immediately.
    func async(_ block: @escaping (Database) -> Void) {
        queue.async {
            block(self.db)
            self.preconditionNoUnsafeTransactionLeft(self.db)
        }
    }
    
    /// Returns true if any only if the current dispatch queue is valid.
    var onValidQueue: Bool {
        SchedulingWatchdog.current?.allows(db) ?? false
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
            allowsUnsafeTransactions || configuration.allowsUnsafeTransactions || !db.isInsideTransaction,
            message(),
            file: file,
            line: line)
    }
}

// @unchecked because the wrapped `Database` itself is not Sendable.
// It happens the job of SerializedDatabase is precisely to provide thread-safe
// access to `Database`.
extension SerializedDatabase: @unchecked Sendable { }
