import Foundation

#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif

#if os(iOS)
    import UIKit
#endif

/// A DatabasePool grants concurrent accesses to an SQLite database.
public final class DatabasePool {
    
    // MARK: - Initializers
    
    /// Opens the SQLite database at path *path*.
    ///
    ///     let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
    ///
    /// Database connections get closed when the database pool gets deallocated.
    ///
    /// - parameters:
    ///     - path: The path to the database file.
    ///     - configuration: A configuration.
    ///     - maximumReaderCount: The maximum number of readers. Default is 5.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public init(path: String, configuration: Configuration = Configuration()) throws {
        GRDBPrecondition(configuration.maximumReaderCount > 0, "configuration.maximumReaderCount must be at least 1")
        
        // Database Store
        store = try DatabaseStore(path: path, attributes: configuration.fileAttributes)
        
        // Writer and readers share the same database schema cache
        let sharedSchemaCache = SharedDatabaseSchemaCache()
        
        // Writer
        writer = try SerializedDatabase(
            path: path,
            configuration: configuration,
            schemaCache: sharedSchemaCache)
        
        // Activate WAL Mode unless readonly
        if !configuration.readonly {
            try writer.sync { db in
                let journalMode = try String.fetchOne(db, "PRAGMA journal_mode = WAL")
                guard journalMode == "wal" else {
                    throw DatabaseError(message: "could not activate WAL Mode at path: \(path)")
                }
                
                // https://www.sqlite.org/pragma.html#pragma_synchronous
                // > Many applications choose NORMAL when in WAL mode
                try db.execute("PRAGMA synchronous = NORMAL")
                
                if !FileManager.default.fileExists(atPath: path + "-wal") {
                    // Create the -wal file if it does not exist yet. This
                    // avoids an SQLITE_CANTOPEN (14) error whenever a user
                    // opens a pool to an existing non-WAL database, and
                    // attempts to read from it.
                    // See https://github.com/groue/GRDB.swift/issues/102
                    try db.execute("CREATE TABLE grdb_issue_102 (id INTEGER PRIMARY KEY); DROP TABLE grdb_issue_102;")
                }
            }
        }
        
        // Readers
        readerConfig = configuration
        readerConfig.readonly = true
        readerConfig.defaultTransactionKind = .deferred // Make it the default. Other transaction kinds are forbidden by SQLite in read-only connections.
        
        readerPool = Pool<SerializedDatabase>(maximumCount: configuration.maximumReaderCount)
        readerPool.makeElement = { [unowned self] in
            let reader = try SerializedDatabase(
                path: path,
                configuration: self.readerConfig,
                schemaCache: sharedSchemaCache)
            
            reader.sync { db in
                for function in self.functions {
                    db.add(function: function)
                }
                for collation in self.collations {
                    db.add(collation: collation)
                }
            }
            
            return reader
        }
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
    
    /// The path to the database.
    public var path: String {
        return store.path
    }
    
    
    // MARK: - WAL Management
    
    /// Runs a WAL checkpoint
    ///
    /// See https://www.sqlite.org/wal.html and
    /// https://www.sqlite.org/c3ref/wal_checkpoint_v2.html) for
    /// more information.
    ///
    /// - parameter kind: The checkpoint mode (default passive)
    public func checkpoint(_ kind: Database.CheckpointMode = .passive) throws {
        try writer.sync { db in
            // TODO: read https://www.sqlite.org/c3ref/wal_checkpoint_v2.html and
            // check whether we need a busy handler on writer and/or readers
            // when kind is not .Passive.
            let code = sqlite3_wal_checkpoint_v2(db.sqliteConnection, nil, kind.rawValue, nil, nil)
            guard code == SQLITE_OK else {
                throw DatabaseError(code: code, message: db.lastErrorMessage, sql: nil)
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
        // TODO: test that this method blocks the current thread until all database accesses are completed.
        writer.sync { db in
            db.releaseMemory()
        }
        
        readerPool.forEach { reader in
            reader.sync { db in
                db.releaseMemory()
            }
        }
        
        readerPool.clear()
    }
    
    
    #if os(iOS)
    /// Listens to UIApplicationDidEnterBackgroundNotification and
    /// UIApplicationDidReceiveMemoryWarningNotification in order to release
    /// as much memory as possible.
    ///
    /// - param application: The UIApplication that will start a background
    ///   task to let the database pool release its memory when the application
    ///   enters background.
    public func setupMemoryManagement(in application: UIApplication) {
        self.application = application
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(DatabasePool.applicationDidReceiveMemoryWarning(_:)), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
        center.addObserver(self, selector: #selector(DatabasePool.applicationDidEnterBackground(_:)), name: .UIApplicationDidEnterBackground, object: nil)
    }
    
    private var application: UIApplication!
    
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
    
    let store: DatabaseStore    // Not private for tests that require syncing with the store
    fileprivate let writer: SerializedDatabase
    fileprivate var readerConfig: Configuration
    fileprivate let readerPool: Pool<SerializedDatabase>
    
    fileprivate var functions = Set<DatabaseFunction>()
    fileprivate var collations = Set<DatabaseCollation>()
}


// =========================================================================
// MARK: - Encryption

#if SQLITE_HAS_CODEC
    extension DatabasePool {
        
        /// Changes the passphrase of an encrypted database
        public func change(passphrase: String) throws {
            try readerPool.clear(andThen: {
                try writer.sync { db in
                    try db.change(passphrase: passphrase)
                }
                readerConfig.passphrase = passphrase
            })
        }
    }
#endif


// =========================================================================
// MARK: - DatabaseReader

extension DatabasePool : DatabaseReader {
    
    // MARK: - Read From Database
    
    /// Synchronously executes a read-only block in a protected dispatch queue,
    /// and returns its result. The block is wrapped in a deferred transaction.
    ///
    ///     let persons = try dbPool.read { db in
    ///         try Person.fetchAll(...)
    ///     }
    ///
    /// The block is completely isolated. Eventual concurrent database updates
    /// are *not visible* inside the block:
    ///
    ///     try dbPool.read { db in
    ///         // Those two values are guaranteed to be equal, even if the
    ///         // `wines` table is modified between the two requests:
    ///         let count1 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///         let count2 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///     }
    ///
    ///     try dbPool.read { db in
    ///         // Now this value may be different:
    ///         let count = try Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block, or any DatabaseError that would
    ///   happen while establishing the read access to the database.
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        // The block isolation comes from the DEFERRED transaction.
        // See DatabasePoolTests.testReadMethodIsolationOfBlock().
        return try readerPool.get { reader in
            try reader.sync { db in
                var result: T? = nil
                try db.inTransaction(.deferred) {
                    result = try block(db)
                    return .commit
                }
                return result!
            }
        }
    }
    
    /// Synchronously executes a read-only block in a protected dispatch queue,
    /// and returns its result.
    ///
    /// The block argument is not isolated: eventual concurrent database updates
    /// are visible inside the block:
    ///
    ///     try dbPool.unsafeRead { db in
    ///         // Those two values may be different because some other thread
    ///         // may have inserted or deleted a wine between the two requests:
    ///         let count1 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///         let count2 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///     }
    ///
    /// Cursor iteration is safe, though:
    ///
    ///     try dbPool.unsafeRead { db in
    ///         // No concurrent update can mess with this iteration:
    ///         let rows = try Row.fetchCursor(db, "SELECT ...")
    ///         while let row = try rows.next() { ... }
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block, or any DatabaseError that would
    ///   happen while establishing the read access to the database.
    public func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T {
        return try readerPool.get { reader in
            try reader.sync { db in
                try block(db)
            }
        }
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
    ///     dbPool.add(function: fn)
    ///     try dbPool.read { db in
    ///         try Int.fetchOne(db, "SELECT succ(1)") // 2
    ///     }
    public func add(function: DatabaseFunction) {
        functions.update(with: function)
        writer.sync { db in db.add(function: function) }
        readerPool.forEach { $0.sync { db in db.add(function: function) } }
    }
    
    /// Remove an SQL function.
    public func remove(function: DatabaseFunction) {
        functions.remove(function)
        writer.sync { db in db.remove(function: function) }
        readerPool.forEach { $0.sync { db in db.remove(function: function) } }
    }
    
    
    // MARK: - Collations
    
    /// Add or redefine a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     dbPool.add(collation: collation)
    ///     try dbPool.write { db in
    ///         try db.execute("CREATE TABLE files (name TEXT COLLATE LOCALIZED_STANDARD")
    ///     }
    public func add(collation: DatabaseCollation) {
        collations.update(with: collation)
        writer.sync { db in db.add(collation: collation) }
        readerPool.forEach { $0.sync { db in db.add(collation: collation) } }
    }
    
    /// Remove a collation.
    public func remove(collation: DatabaseCollation) {
        collations.remove(collation)
        writer.sync { db in db.remove(collation: collation) }
        readerPool.forEach { $0.sync { db in db.remove(collation: collation) } }
    }
}


// =========================================================================
// MARK: - DatabaseWriter

extension DatabasePool : DatabaseWriter {
    
    // MARK: - Writing in Database
    
    /// Synchronously executes an update block in a protected dispatch queue,
    /// and returns its result.
    ///
    /// Eventual concurrent database updates are postponed until the block
    /// has executed.
    ///
    ///     try dbPool.write { db in
    ///         try db.execute(...)
    ///     }
    ///
    /// To maintain database integrity, and preserve eventual concurrent reads
    /// from seeing an inconsistent database state, prefer the
    /// writeInTransaction method.
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameters block: A block that executes SQL statements and return
    ///   either .commit or .rollback.
    /// - throws: The error thrown by the block.
    public func write<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try writer.sync(block)
    }
    
    /// Synchronously executes a block in a protected dispatch queue, wrapped
    /// inside a transaction.
    ///
    /// Eventual concurrent database updates are postponed until the block
    /// has executed.
    ///
    /// If the block throws an error, the transaction is rollbacked and the
    /// error is rethrown. If the block returns .rollback, the transaction is
    /// also rollbacked, but no error is thrown.
    ///
    ///     try dbPool.writeInTransaction { db in
    ///         db.execute(...)
    ///         return .commit
    ///     }
    ///
    /// Eventual concurrent readers do not see partial changes:
    ///
    ///     dbPool.writeInTransaction { db in
    ///         // Eventually preserve a zero balance
    ///         try db.execute(db, "INSERT INTO credits ...", arguments: [amount])
    ///         try db.execute(db, "INSERT INTO debits ...", arguments: [amount])
    ///     }
    ///
    ///     dbPool.read { db in
    ///         // Here the balance is guaranteed to be zero
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
    /// - throws: The error thrown by the block, or any error establishing the
    ///   transaction.
    public func writeInTransaction(_ kind: Database.TransactionKind? = nil, _ block: (Database) throws -> Database.TransactionCompletion) throws {
        try writer.sync { db in
            try db.inTransaction(kind) {
                try block(db)
            }
        }
    }
    
    
    // MARK: - Reading from Database
    
    /// Asynchronously executes a read-only block in a protected dispatch queue,
    /// wrapped in a deferred transaction.
    ///
    /// This method must be called from the writing dispatch queue.
    ///
    /// The *block* argument is guaranteed to see the database in the last
    /// committed state at the moment this method is called. Eventual concurrent
    /// database updates are *not visible* inside the block.
    ///
    ///     try dbPool.write { db in
    ///         try db.execute("DELETE FROM persons")
    ///         try dbPool.readFromCurrentState { db in
    ///             // Guaranteed to be zero
    ///             try Int.fetchOne(db, "SELECT COUNT(*) FROM persons")!
    ///         }
    ///         try db.execute("INSERT INTO persons ...")
    ///     }
    ///
    /// This method blocks the current thread until the isolation guarantee has
    /// been established, and before the block argument has run.
    public func readFromCurrentState(_ block: @escaping (Database) -> Void) throws {
        writer.preconditionValidQueue()
        
        let semaphore = DispatchSemaphore(value: 0)
        try readerPool.get { reader in
            reader.async { db in
                // https://www.sqlite.org/isolation.html
                //
                // > In WAL mode, SQLite exhibits "snapshot isolation". When a
                // > read transaction starts, that reader continues to see an
                // > unchanging "snapshot" of the database file as it existed at
                // > the moment in time when the read transaction started.
                // > Any write transactions that commit while the read
                // > transaction is active are still invisible to the read
                // > transaction, because the reader is seeing a snapshot of
                // > database file from a prior moment in time.
                //
                // This documentation is NOT accurate. SQLite actually defers
                // isolation until the first SELECT:
                //
                //     Reader                       Writer
                //     BEGIN DEFERRED TRANSACTION
                //                                  UPDATE ... (1)
                //     Here the change (1) is visible
                //     SELECT ...
                //                                  UPDATE ... (2)
                //     Here the change (2) is not visible
                //
                // This is not the guarantee expected by this method: no change
                // at all should be visible.
                //
                // Workaround: perform an initial read before releasing the
                // writer queue:
                //
                //     Reader                       Writer
                //     BEGIN DEFERRED TRANSACTION
                //     SELECT anything -- the work around
                //                                  UPDATE ...
                //     Here the change is not visible by GRDB user
                try! db.inTransaction(.deferred) {  // Assume deferred transactions are always possible in a read-only WAL database
                    try db.makeSelectStatement("SELECT rootpage FROM sqlite_master").fetchCursor().next() // doesn't work with cached statement
                    semaphore.signal() // We can release the writer queue now that we are isolated for good.
                    block(db)
                    return .commit
                }
            }
        }
        _ = semaphore.wait(timeout: .distantFuture)
    }
}
