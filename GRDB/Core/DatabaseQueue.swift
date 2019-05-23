import Foundation

#if os(iOS)
import UIKit
#endif

/// A DatabaseQueue serializes access to an SQLite database.
public final class DatabaseQueue: DatabaseWriter {
    private var writer: SerializedDatabase
    #if os(iOS)
    private weak var application: UIApplication?
    #endif
    
    // MARK: - Configuration
    
    /// The database configuration
    public var configuration: Configuration {
        return writer.configuration
    }
    
    /// The path to the database file; it is ":memory:" for in-memory databases.
    public var path: String {
        return writer.path
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
    public init(path: String, configuration: Configuration = Configuration()) throws {
        writer = try SerializedDatabase(
            path: path,
            configuration: configuration,
            schemaCache: SimpleDatabaseSchemaCache(),
            defaultLabel: "GRDB.DatabaseQueue")
    }
    
    /// Opens an in-memory SQLite database.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///
    /// Database memory is released when the database queue gets deallocated.
    ///
    /// - parameter configuration: A configuration.
    public init(configuration: Configuration = Configuration()) {
        // Assume SQLite always succeeds creating an in-memory database
        writer = try! SerializedDatabase(
            path: ":memory:",
            configuration: configuration,
            schemaCache: SimpleDatabaseSchemaCache(),
            defaultLabel: "GRDB.DatabaseQueue")
    }
    
    #if os(iOS)
    deinit {
        // Undo job done in setupMemoryManagement()
        //
        // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11Error
        // Explicit unregistration is required before iOS 9 and OS X 10.11.
        NotificationCenter.default.removeObserver(self)
    }
    #endif
}

extension DatabaseQueue {

    // MARK: - Memory management

    /// Free as much memory as possible.
    ///
    /// This method blocks the current thread until all database accesses are completed.
    ///
    /// See also setupMemoryManagement(application:)
    public func releaseMemory() {
        writer.sync { $0.releaseMemory() }
    }
    
    #if os(iOS)
    /// Listens to UIApplicationDidEnterBackgroundNotification and
    /// UIApplicationDidReceiveMemoryWarningNotification in order to release
    /// as much memory as possible.
    ///
    /// - param application: The UIApplication that will start a background
    ///   task to let the database queue release its memory when the application
    ///   enters background.
    public func setupMemoryManagement(in application: UIApplication) {
        self.application = application
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(DatabaseQueue.applicationDidReceiveMemoryWarning(_:)),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
        center.addObserver(
            self,
            selector: #selector(DatabaseQueue.applicationDidEnterBackground(_:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
    }
    
    @objc private func applicationDidEnterBackground(_ notification: NSNotification) {
        guard let application = application else {
            return
        }
        
        let task: UIBackgroundTaskIdentifier = application.beginBackgroundTask(expirationHandler: nil)
        if task == .invalid {
            // Perform releaseMemory() synchronously.
            releaseMemory()
        } else {
            // Perform releaseMemory() asynchronously.
            DispatchQueue.global().async {
                self.releaseMemory()
                application.endBackgroundTask(task)
            }
        }
    }
    
    @objc private func applicationDidReceiveMemoryWarning(_ notification: NSNotification) {
        DispatchQueue.global().async {
            self.releaseMemory()
        }
    }
    #endif
}

#if SQLITE_HAS_CODEC
    extension DatabaseQueue {

        // MARK: - Encryption

        /// Changes the passphrase of an encrypted database
        public func change(passphrase: String) throws {
            try writer.sync { try $0.change(passphrase: passphrase) }
        }
    }
#endif

extension DatabaseQueue {
    
    // MARK: - Reading from Database
    
    /// Synchronously executes a read-only block in a protected dispatch queue,
    /// and returns its result.
    ///
    ///     let players = try dbQueue.read { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// Starting SQLite 3.8.0 (iOS 8.2+, OSX 10.10+, custom SQLite builds and
    /// SQLCipher), attempts to write in the database from this meethod throw a
    /// DatabaseError of resultCode `SQLITE_READONLY`.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    public func read<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try writer.sync { db in
            try db.readOnly { try block(db) }
        }
    }
    
    /// Synchronously executes a block in a protected dispatch queue, and
    /// returns its result.
    ///
    ///     let players = try dbQueue.unsafeRead { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    ///
    /// :nodoc:
    public func unsafeRead<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try writer.sync(block)
    }
    
    /// Synchronously executes a block in a protected dispatch queue, and
    /// returns its result.
    ///
    ///     let players = try dbQueue.unsafeReentrantRead { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///
    /// This method is reentrant. It is unsafe because it fosters dangerous
    /// concurrency practices.
    ///
    /// :nodoc:
    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try writer.reentrantSync(block)
    }
    
    public func concurrentRead<T>(_ block: @escaping (Database) throws -> T) -> DatabaseFuture<T> {
        // DatabaseQueue can't perform parallel reads.
        // Perform a blocking read instead.
        return DatabaseFuture(Result {
            // Check that we're on the writer queue...
            try writer.execute { db in
                // ... and that no transaction is opened.
                GRDBPrecondition(!db.isInsideTransaction, "concurrentRead must not be called from inside a transaction.")
                return try db.readOnly {
                    try block(db)
                }
            }
        })
    }
    
    // MARK: - Writing in Database
    
    /// Synchronously executes a block in a protected dispatch queue, wrapped
    /// inside a transaction.
    ///
    /// If the block throws an error, the transaction is rollbacked and the
    /// error is rethrown.
    ///
    ///     try dbQueue.write { db in
    ///         try Player(...).insert(db)
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that executes SQL statements.
    /// - throws: An eventual database error, or the error thrown by the block.
    public func write<T>(_ block: (Database) throws -> T) throws -> T {
        return try writer.sync { db in
            var result: T? = nil
            try db.inTransaction {
                result = try block(db)
                return .commit
            }
            return result!
        }
    }
    
    /// Synchronously executes a block in a protected dispatch queue, wrapped
    /// inside a transaction.
    ///
    /// If the block throws an error, the transaction is rollbacked and the
    /// error is rethrown. If the block returns .rollback, the transaction is
    /// also rollbacked, but no error is thrown.
    ///
    ///     try dbQueue.inTransaction { db in
    ///         try Player(...).insert(db)
    ///         return .commit
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is configuration.defaultTransactionKind, which itself
    ///       defaults to .deferred. See https://www.sqlite.org/lang_transaction.html
    ///       for more information.
    ///     - block: A block that executes SQL statements and return either
    ///       .commit or .rollback.
    /// - throws: The error thrown by the block.
    public func inTransaction(_ kind: Database.TransactionKind? = nil, _ block: (Database) throws -> Database.TransactionCompletion) throws {
        try writer.sync { db in
            try db.inTransaction(kind) {
                try block(db)
            }
        }
    }
    
    /// Synchronously executes a block in a protected dispatch queue, and
    /// returns its result.
    ///
    ///     let players = try dbQueue.writeWithoutTransaction { db in
    ///         try Player(...).insert(db)
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    ///
    /// :nodoc:
    public func writeWithoutTransaction<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try writer.sync(block)
    }

    /// Synchronously executes a block in a protected dispatch queue, and
    /// returns its result.
    ///
    ///     // INSERT INTO player ...
    ///     let players = try dbQueue.inDatabase { db in
    ///         try Player(...).insert(db)
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    public func inDatabase<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try writer.sync(block)
    }
    
    /// Synchronously executes a block in a protected dispatch queue, and
    /// returns its result.
    ///
    ///     // INSERT INTO player ...
    ///     try dbQueue.unsafeReentrantWrite { db in
    ///         try Player(...).insert(db)
    ///     }
    ///
    /// This method is reentrant. It is unsafe because it fosters dangerous
    /// concurrency practices.
    public func unsafeReentrantWrite<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try writer.reentrantSync(block)
    }
    
    // MARK: - Functions
    
    /// Add or redefine an SQL function.
    ///
    ///     let fn = DatabaseFunction("succ", argumentCount: 1) { dbValues in
    ///         guard let int = Int.fromDatabaseValue(dbValues[0]) else {
    ///             return nil
    ///         }
    ///         return int + 1
    ///     }
    ///     dbQueue.add(function: fn)
    ///     try dbQueue.read { db in
    ///         try Int.fetchOne(db, sql: "SELECT succ(1)") // 2
    ///     }
    public func add(function: DatabaseFunction) {
        writer.sync { $0.add(function: function) }
    }
    
    /// Remove an SQL function.
    public func remove(function: DatabaseFunction) {
        writer.sync { $0.remove(function: function) }
    }
    
    // MARK: - Collations
    
    /// Add or redefine a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     dbQueue.add(collation: collation)
    ///     try dbQueue.write { db in
    ///         try db.execute(sql: "CREATE TABLE file (name TEXT COLLATE LOCALIZED_STANDARD")
    ///     }
    public func add(collation: DatabaseCollation) {
        writer.sync { $0.add(collation: collation) }
    }
    
    /// Remove a collation.
    public func remove(collation: DatabaseCollation) {
        writer.sync { $0.remove(collation: collation) }
    }
}
