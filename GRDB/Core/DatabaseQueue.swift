import Foundation

#if os(iOS)
import UIKit
#endif

/// A DatabaseQueue serializes access to an SQLite database.
public final class DatabaseQueue {
    
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
        store = try DatabaseStore(path: path, attributes: configuration.fileAttributes)
        serializedDatabase = try SerializedDatabase(
            path: path,
            configuration: configuration,
            schemaCache: SimpleDatabaseSchemaCache())
    }
    
    /// Opens an in-memory SQLite database.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///
    /// Database memory is released when the database queue gets deallocated.
    ///
    /// - parameter configuration: A configuration.
    public init(configuration: Configuration = Configuration()) {
        store = nil
        serializedDatabase = try! SerializedDatabase(
            path: ":memory:",
            configuration: configuration,
            schemaCache: SimpleDatabaseSchemaCache())
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
    
    
    // MARK: - Configuration
    
    /// The database configuration
    public var configuration: Configuration {
        return serializedDatabase.configuration
    }
    
    /// The path to the database file; nil for in-memory databases.
    public var path: String! {
        return store?.path
    }
    
    
    // MARK: - Database access
    
    /// Synchronously executes a block in a protected dispatch queue, and
    /// returns its result.
    ///
    ///     let persons = dbQueue.inDatabase { db in
    ///         Person.fetchAll(...)
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    public func inDatabase<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try serializedDatabase.sync(block)
    }
    
    /// Synchronously executes a block in a protected dispatch queue, wrapped
    /// inside a transaction.
    ///
    /// If the block throws an error, the transaction is rollbacked and the
    /// error is rethrown.
    ///
    ///     try dbQueue.inTransaction { db in
    ///         db.execute(...)
    ///         return .commit
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is configuration.defaultTransactionKind, which itself
    ///       defaults to .immediate. See https://www.sqlite.org/lang_transaction.html
    ///       for more information.
    ///     - block: A block that executes SQL statements and return either
    ///       .commit or .rollback.
    /// - throws: The error thrown by the block.
    public func inTransaction(_ kind: Database.TransactionKind? = nil, _ block: (Database) throws -> Database.TransactionCompletion) throws {
        try serializedDatabase.sync { db in
            try db.inTransaction(kind) {
                try block(db)
            }
        }
    }
    
    
    // MARK: - Memory management
    
    /// Free as much memory as possible.
    ///
    /// This method blocks the current thread until all database accesses are completed.
    ///
    /// See also setupMemoryManagement(application:)
    public func releaseMemory() {
        serializedDatabase.sync { db in
            db.releaseMemory()
        }
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
        center.addObserver(self, selector: #selector(DatabaseQueue.applicationDidReceiveMemoryWarning(_:)), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
        center.addObserver(self, selector: #selector(DatabaseQueue.applicationDidEnterBackground(_:)), name: .UIApplicationDidEnterBackground, object: nil)
    }
    
    private var application: UIApplication?
    
    @objc private func applicationDidEnterBackground(_ notification: NSNotification) {
        guard let application = application else {
            return
        }
        
        var task: UIBackgroundTaskIdentifier! = nil
        task = application.beginBackgroundTask(expirationHandler: nil)
        
        if task == UIBackgroundTaskInvalid {
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
    
    
    // MARK: - Not public
    
    private let store: DatabaseStore?

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
    fileprivate var serializedDatabase: SerializedDatabase
}


// =========================================================================
// MARK: - Encryption

#if SQLITE_HAS_CODEC
    extension DatabaseQueue {
        
        /// Changes the passphrase of an encrypted database
        public func change(passphrase: String) throws {
            try serializedDatabase.sync { db in
                try db.change(passphrase: passphrase)
            }
        }
    }
#endif


// =========================================================================
// MARK: - DatabaseReader

extension DatabaseQueue : DatabaseReader {
    
    // MARK: - DatabaseReader Protocol Adoption
    
    /// Alias for inDatabase
    ///
    /// This method is part of the DatabaseReader protocol adoption.
    public func read<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try serializedDatabase.sync(block)
    }
    
    /// Alias for inDatabase
    ///
    /// This method is part of the DatabaseReader protocol adoption.
    public func nonIsolatedRead<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try serializedDatabase.sync(block)
    }
    
    
    // MARK: - Functions
    
    /// Add or redefine an SQL function.
    ///
    ///     let fn = DatabaseFunction("succ", argumentCount: 1) { databaseValues in
    ///         let dbv = databaseValues.first!
    ///         guard let int = dbv.value() as Int? else {
    ///             return nil
    ///         }
    ///         return int + 1
    ///     }
    ///     dbQueue.add(function: fn)
    ///     dbQueue.inDatabase { db in
    ///         Int.fetchOne(db, "SELECT succ(1)") // 2
    ///     }
    public func add(function: DatabaseFunction) {
        serializedDatabase.sync { db in
            db.add(function: function)
        }
    }
    
    /// Remove an SQL function.
    public func remove(function: DatabaseFunction) {
        serializedDatabase.sync { db in
            db.remove(function: function)
        }
    }
    
    
    // MARK: - Collations
    
    /// Add or redefine a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     dbQueue.add(collation: collation)
    ///     try dbQueue.inDatabase { db in
    ///         try db.execute("CREATE TABLE files (name TEXT COLLATE LOCALIZED_STANDARD")
    ///     }
    public func add(collation: DatabaseCollation) {
        serializedDatabase.sync { db in
            db.add(collation: collation)
        }
    }
    
    /// Remove a collation.
    public func remove(collation: DatabaseCollation) {
        serializedDatabase.sync { db in
            db.remove(collation: collation)
        }
    }
}


// =========================================================================
// MARK: - DatabaseWriter

extension DatabaseQueue : DatabaseWriter {
    
    // MARK: - DatabaseWriter Protocol Adoption
    
    /// Alias for inDatabase
    ///
    /// This method is part of the DatabaseWriter protocol adoption.
    public func write<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try serializedDatabase.sync(block)
    }

    /// Executes *block*.
    ///
    /// This method is part of the DatabaseWriter protocol adoption, and must
    /// be called from the protected database dispatch queue.
    public func readFromWrite(_ block: @escaping (Database) -> Void) {
        serializedDatabase.execute(block)
    }
}
