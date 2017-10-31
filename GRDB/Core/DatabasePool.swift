import Foundation
#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif
#if os(iOS)
    import UIKit
#endif

/// A DatabasePool grants concurrent accesses to an SQLite database.
public final class DatabasePool {
    private let writer: SerializedDatabase
    private var readerConfig: Configuration
    private var readerPool: Pool<SerializedDatabase>!
    
    private var functions = Set<DatabaseFunction>()
    private var collations = Set<DatabaseCollation>()
    
    #if os(iOS)
    private weak var application: UIApplication?
    #endif
    
    // MARK: - Database Information
    
    /// The path to the database.
    public var path: String {
        return writer.path
    }
    
    // MARK: - Initializer
    
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
        readerConfig.defaultTransactionKind = .deferred // Make it the default for readers. Other transaction kinds are forbidden by SQLite in read-only connections.
        readerPool = Pool(maximumCount: configuration.maximumReaderCount, makeElement: { [unowned self] in
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
        })
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

extension DatabasePool {

    // MARK: - WAL Checkpoints

    /// Runs a WAL checkpoint
    ///
    /// See https://www.sqlite.org/wal.html and
    /// https://www.sqlite.org/c3ref/wal_checkpoint_v2.html) for
    /// more information.
    ///
    /// - parameter kind: The checkpoint mode (default passive)
    public func checkpoint(_ kind: Database.CheckpointMode = .passive) throws {
        try write { db in
            // TODO: read https://www.sqlite.org/c3ref/wal_checkpoint_v2.html and
            // check whether we need a busy handler on writer and/or readers
            // when kind is not .Passive.
            let code = sqlite3_wal_checkpoint_v2(db.sqliteConnection, nil, kind.rawValue, nil, nil)
            guard code == SQLITE_OK else {
                throw DatabaseError(resultCode: code, message: db.lastErrorMessage, sql: nil)
            }
        }
    }
}

extension DatabasePool {

    // MARK: - Memory management

    /// Free as much memory as possible.
    ///
    /// This method blocks the current thread until all database accesses are completed.
    ///
    /// See also setupMemoryManagement(application:)
    public func releaseMemory() {
        // TODO: test that this method blocks the current thread until all database accesses are completed.
        write { $0.releaseMemory() }
        readerPool.forEach { reader in
            reader.sync { $0.releaseMemory() }
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
}

#if SQLITE_HAS_CODEC
    extension DatabasePool {

        // MARK: - Encryption
        
        /// Changes the passphrase of an encrypted database
        public func change(passphrase: String) throws {
            try readerPool.clear(andThen: {
                try write { try $0.change(passphrase: passphrase) }
                readerConfig.passphrase = passphrase
            })
        }
    }
#endif

extension DatabasePool : DatabaseReader {
    
    // MARK: - Reading from Database

    /// Synchronously executes a read-only block in a protected dispatch queue,
    /// and returns its result. The block is wrapped in a deferred transaction.
    ///
    ///     let players = try dbPool.read { db in
    ///         try Player.fetchAll(...)
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
        GRDBPrecondition(currentReader == nil, "Database methods are not reentrant.")
        return try readerPool.get { reader in
            try reader.sync { db in
                var result: T? = nil
                // The block isolation comes from the DEFERRED transaction.
                // See DatabasePoolTests.testReadMethodIsolationOfBlock().
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
        GRDBPrecondition(currentReader == nil, "Database methods are not reentrant.")
        return try readerPool.get { reader in
            try reader.sync(block)
        }
    }
    
    /// Synchronously executes a read-only block in a protected dispatch queue,
    /// and returns its result.
    ///
    /// The block argument is not isolated: eventual concurrent database updates
    /// are visible inside the block:
    ///
    ///     try dbPool.unsafeReentrantRead { db in
    ///         // Those two values may be different because some other thread
    ///         // may have inserted or deleted a wine between the two requests:
    ///         let count1 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///         let count2 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///     }
    ///
    /// Cursor iteration is safe, though:
    ///
    ///     try dbPool.unsafeReentrantRead { db in
    ///         // No concurrent update can mess with this iteration:
    ///         let rows = try Row.fetchCursor(db, "SELECT ...")
    ///         while let row = try rows.next() { ... }
    ///     }
    ///
    /// This method is reentrant. It should be avoided because it fosters
    /// dangerous concurrency practices.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block, or any DatabaseError that would
    ///   happen while establishing the read access to the database.
    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        if let reader = currentReader {
            return try reader.reentrantSync(block)
        } else {
            return try readerPool.get { reader in
                try reader.sync(block)
            }
        }
    }
    
    /// Returns a reader that can be used from the current dispatch queue,
    /// if any.
    private var currentReader: SerializedDatabase? {
        var readers: [SerializedDatabase] = []
        readerPool.forEach { reader in
            // We can't check for reader.onValidQueue here because
            // Pool.forEach() runs its closure argument in some arbitrary
            // dispatch queue. We thus extract the reader so that we can query
            // it below.
            readers.append(reader)
        }
        
        // Now the readers array contains some readers. The pool readers may
        // already be different, because some other thread may have started
        // a new read, for example.
        //
        // This doesn't matter: the reader we are looking for is already on
        // its own dispatch queue. If it exists, is still in use, thus still
        // in the pool, and thus still relevant for our check:
        return readers.first { $0.onValidQueue }
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
    ///     dbPool.add(function: fn)
    ///     try dbPool.read { db in
    ///         try Int.fetchOne(db, "SELECT succ(1)") // 2
    ///     }
    public func add(function: DatabaseFunction) {
        functions.update(with: function)
        write { $0.add(function: function) }
        readerPool.forEach { reader in
            reader.sync { $0.add(function: function) }
        }
    }
    
    /// Remove an SQL function.
    public func remove(function: DatabaseFunction) {
        functions.remove(function)
        write { $0.remove(function: function) }
        readerPool.forEach { reader in
            reader.sync { $0.remove(function: function) }
        }
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
        write { $0.add(collation: collation) }
        readerPool.forEach { reader in
            reader.sync { $0.add(collation: collation) }
        }
    }
    
    /// Remove a collation.
    public func remove(collation: DatabaseCollation) {
        collations.remove(collation)
        write { $0.remove(collation: collation) }
        readerPool.forEach { reader in
            reader.sync { $0.remove(collation: collation) }
        }
    }
}

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
        try write { db in
            try db.inTransaction(kind) {
                try block(db)
            }
        }
    }
    
    /// Synchronously executes an update block in a protected dispatch queue,
    /// and returns its result.
    ///
    /// Eventual concurrent database updates are postponed until the block
    /// has executed.
    ///
    ///     try dbPool.unsafeReentrantWrite { db in
    ///         try db.execute(...)
    ///     }
    ///
    /// This method is reentrant. It should be avoided because it fosters
    /// dangerous concurrency practices.
    public func unsafeReentrantWrite<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try writer.reentrantSync(block)
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
    ///         try db.execute("DELETE FROM players")
    ///         try dbPool.readFromCurrentState { db in
    ///             // Guaranteed to be zero
    ///             try Int.fetchOne(db, "SELECT COUNT(*) FROM players")!
    ///         }
    ///         try db.execute("INSERT INTO players ...")
    ///     }
    ///
    /// This method blocks the current thread until the isolation guarantee has
    /// been established, and before the block argument has run.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block, or any DatabaseError that would
    ///   happen while establishing the read access to the database.
    public func readFromCurrentState(_ block: @escaping (Database) -> Void) throws {
        // https://www.sqlite.org/isolation.html
        //
        // > In WAL mode, SQLite exhibits "snapshot isolation". When a read
        // > transaction starts, that reader continues to see an unchanging
        // > "snapshot" of the database file as it existed at the moment in time
        // > when the read transaction started. Any write transactions that
        // > commit while the read transaction is active are still invisible to
        // > the read transaction, because the reader is seeing a snapshot of
        // > database file from a prior moment in time.
        //
        // That's exactly what we need. But what does "when read transaction
        // starts" mean?
        //
        // http://www.sqlite.org/lang_transaction.html
        //
        // > Deferred [transaction] means that no locks are acquired on the
        // > database until the database is first accessed. [...] Locks are not
        // > acquired until the first read or write operation. [...] Because the
        // > acquisition of locks is deferred until they are needed, it is
        // > possible that another thread or process could create a separate
        // > transaction and write to the database after the BEGIN on the
        // > current thread has executed.
        //
        // Now that's precise enough: SQLite defers "snapshot isolation" until
        // the first SELECT:
        //
        //     Reader                       Writer
        //     BEGIN DEFERRED TRANSACTION
        //                                  UPDATE ... (1)
        //     Here the change (1) is visible
        //     SELECT ...
        //                                  UPDATE ... (2)
        //     Here the change (2) is not visible
        //
        // The readFromCurrentState method says that no change should be visible
        // at all. We thus have to perform a select that establishes the
        // snapshot isolation before we release the writer queue:
        //
        //     Reader                       Writer
        //     BEGIN DEFERRED TRANSACTION
        //     SELECT anything
        //                                  UPDATE ...
        //     Here the change is not visible by GRDB user
        
        // This method must be called from the writing dispatch queue:
        writer.preconditionValidQueue()
        
        // The semaphore that blocks the writing dispatch queue until snapshot
        // isolation has been established:
        let semaphore = DispatchSemaphore(value: 0)
        
        var readError: Error? = nil
        try readerPool.get { reader in
            reader.async { db in
                do {
                    try db.beginTransaction(.deferred)
                    assert(db.isInsideTransaction)
                    try db.makeSelectStatement("SELECT rootpage FROM sqlite_master").cursor().next()
                } catch {
                    readError = error
                    semaphore.signal() // Release the writer queue and rethrow error
                    return
                }
                semaphore.signal() // We can release the writer queue now that we are isolated for good
                block(db)
                _ = try? db.commit() // Ignore commit error
            }
        }
        _ = semaphore.wait(timeout: .distantFuture)
        if let readError = readError {
            // TODO: write a test for this
            throw readError
        }
    }
}
