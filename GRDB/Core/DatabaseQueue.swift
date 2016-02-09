import Foundation

/// A Database Queue serializes access to an SQLite database.
public final class DatabaseQueue {
    
    // MARK: - Configuration
    
    /// The database configuration
    public var configuration: Configuration {
        return database.configuration
    }
    
    
    // MARK: - Initializers
    
    /// Opens the SQLite database at path *path*.
    ///
    ///     let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
    ///
    /// Database connections get closed when the database queue gets deallocated.
    ///
    /// - parameters:
    ///     - path: The path to the database file.
    ///     - configuration: A configuration.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public convenience init(path: String, var configuration: Configuration = Configuration()) throws {
        // IMPLEMENTATION NOTE
        //
        // According to https://www.sqlite.org/threadsafe.html:
        //
        // > Multi-thread. In this mode, SQLite can be safely used by multiple
        // > threads provided that no single database connection is used
        // > simultaneously in two or more threads.
        // >
        // > Serialized. In serialized mode, SQLite can be safely used by
        // > multiple threads with no restriction.
        // >
        // > The default mode is serialized.
        //
        // Since our database connection is only used via our serial dispatch
        // queue, there is no purpose using the default serialized mode.
        configuration.threadingMode = .MultiThread
        try self.init(database: Database(path: path, configuration: configuration))
    }
    
    /// Opens an in-memory SQLite database.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///
    /// Database memory is released when the database queue gets deallocated.
    ///
    /// - parameter configuration: A configuration.
    public convenience init(var configuration: Configuration = Configuration()) {
        configuration.threadingMode = .MultiThread  // See IMPLEMENTATION NOTE in init(_:configuration:)
        self.init(database: Database(configuration: configuration))
    }
    
    
    // MARK: - Database access
    
    /// Synchronously executes a block in the database queue.
    ///
    ///     dbQueue.inDatabase { db in
    ///         db.fetch(...)
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    public func inDatabase(block: (db: Database) throws -> Void) rethrows {
        try inQueue {
            try block(db: self.database)
        }
    }
    
    /// Synchronously executes a block in the database queue, and returns
    /// its result.
    ///
    ///     let rows = dbQueue.inDatabase { db in
    ///         db.fetch(...)
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    public func inDatabase<T>(block: (db: Database) throws -> T) rethrows -> T {
        return try inQueue {
            try block(db: self.database)
        }
    }
    
    /// Synchronously executes a block in the database queue, wrapped inside a
    /// transaction.
    ///
    /// If the block throws an error, the transaction is rollbacked and the
    /// error is rethrown.
    ///
    ///     try dbQueue.inTransaction { db in
    ///         db.execute(...)
    ///         return .Commit
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is configuration.defaultTransactionKind, which itself
    ///       defaults to .Immediate. See https://www.sqlite.org/lang_transaction.html
    ///       for more information.
    ///     - block: A block that executes SQL statements and return either
    ///       .Commit or .Rollback.
    /// - throws: The error thrown by the block.
    public func inTransaction(kind: TransactionKind? = nil, block: (db: Database) throws -> TransactionCompletion) throws {
        try inQueue {
            try self.database.inTransaction(kind) {
                try block(db: self.database)
            }
        }
    }
    
    
    // MARK: - Not public
    
    /// The Database
    private var database: Database
    
    /// The dispatch queue
    private let queue: dispatch_queue_t
    
    /// The key for the dispatch queue specific that holds the DatabaseQueue
    /// identity. See databaseQueueID.
    static let databaseQueueIDKey = unsafeBitCast(DatabaseQueue.self, UnsafePointer<Void>.self)     // some unique pointer
    
    /// The value for the dispatch queue specific that holds the DatabaseQueue
    /// identity.
    ///
    /// It helps:
    /// - warning the user when he wraps calls to inDatabase() or
    ///   inTransaction(), which would create a deadlock
    /// - warning the user the he uses a statement outside of the database
    ///   queue.
    private lazy var databaseQueueID: DatabaseQueueID = {
        unsafeBitCast(self, DatabaseQueueID.self)   // pointer to self
    }()
    
    init(database: Database) {
        // IMPLEMENTATION NOTE
        //
        // https://www.sqlite.org/isolation.html
        //
        // > Within a single database connection X, a SELECT statement always
        // > sees all changes to the database that are completed prior to the
        // > start of the SELECT statement, whether committed or uncommitted.
        // > And the SELECT statement obviously does not see any changes that
        // > occur after the SELECT statement completes. But what about changes
        // > that occur while the SELECT statement is running? What if a SELECT
        // > statement is started and the sqlite3_step() interface steps through
        // > roughly half of its output, then some UPDATE statements are run by
        // > the application that modify the table that the SELECT statement is
        // > reading, then more calls to sqlite3_step() are made to finish out
        // > the SELECT statement? Will the later steps of the SELECT statement
        // > see the changes made by the UPDATE or not? The answer is that this
        // > behavior is undefined.
        //
        // This is why we use a serial queue: to avoid UPDATE to fuck up SELECT.
        self.database = database
        queue = dispatch_queue_create("com.github.groue.GRDB", nil)
        dispatch_queue_set_specific(queue, DatabaseQueue.databaseQueueIDKey, databaseQueueID, nil)
        database.databaseQueueID = databaseQueueID
    }
    
    private func inQueue<T>(block: () throws -> T) rethrows -> T {
        // IMPLEMENTATION NOTE
        //
        // DatabaseQueue.inDatabase() and DatabaseQueue.inTransaction() are not
        // reentrant.
        //
        // Avoiding dispatch_sync and calling block() right away if the specific
        // is currently self.databaseQueueID looks like a promising solution:
        //
        //     dbQueue.inDatabase { db in
        //         dbQueue.inDatabase { db in
        //             // Look, ma! I'm reentrant!
        //         }
        //     }
        //
        // However it does not survive this code, which deadlocks:
        //
        //     let queue = dispatch_queue_create("...", nil)
        //     dbQueue.inDatabase { db in
        //         dispatch_sync(queue) {
        //             dbQueue.inDatabase { db in
        //                 // Never run
        //             }
        //         }
        //     }
        //
        // I try not to ship half-baked solutions, so until a complete solution
        // is found to this problem, I prefer totally disabling reentrancy.
        precondition(databaseQueueID != dispatch_get_specific(DatabaseQueue.databaseQueueIDKey), "DatabaseQueue.inDatabase(_:) or DatabaseQueue.inTransaction(_:) was called reentrantly, which would lead to a deadlock.")
        return try dispatchSync(queue, block: block)
    }
}

typealias DatabaseQueueID = UnsafeMutablePointer<Void>
