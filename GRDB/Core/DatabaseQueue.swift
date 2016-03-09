import Foundation

/// A Database Queue serializes access to an SQLite database.
public final class DatabaseQueue {
    
    // MARK: - Configuration
    
    /// The database configuration
    public var configuration: Configuration {
        return serializedDatabase.configuration
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
    public convenience init(path: String, configuration: Configuration = Configuration()) throws {
        try self.init(serializedDatabase: SerializedDatabase(
            path: path,
            configuration: configuration,
            schemaCache: DatabaseSchemaCache()))
    }
    
    /// Opens an in-memory SQLite database.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///
    /// Database memory is released when the database queue gets deallocated.
    ///
    /// - parameter configuration: A configuration.
    public convenience init(configuration: Configuration = Configuration()) {
        try! self.init(path: ":memory:", configuration: configuration)
    }
    
    
    // MARK: - Database access
    
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
        return try serializedDatabase.inDatabase(block)
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
    public func inTransaction(kind: TransactionKind? = nil, _ block: (db: Database) throws -> TransactionCompletion) throws {
        try serializedDatabase.inDatabase { db in
            try db.inTransaction(kind) {
                try block(db: db)
            }
        }
    }
    
    
    // MARK: - Not public
    
    /// The serialized database
    private var serializedDatabase: SerializedDatabase
    
    init(serializedDatabase: SerializedDatabase) {
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
        // This is why we use a serialized database:
        self.serializedDatabase = serializedDatabase
    }
}
