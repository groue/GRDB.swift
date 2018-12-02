import Foundation
import Dispatch
#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif
#if os(iOS)
    import UIKit
#endif

/// A DatabasePool grants concurrent accesses to an SQLite database.
public final class DatabasePool: DatabaseWriter {
    private let writer: SerializedDatabase
    private var readerConfig: Configuration
    private var readerPool: Pool<SerializedDatabase>!
    
    private var functions = Set<DatabaseFunction>()
    private var collations = Set<DatabaseCollation>()
    private var tokenizerRegistrations: [(Database) -> Void] = []
    
    var snapshotCount = ReadWriteBox(0)
    
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
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public init(path: String, configuration: Configuration = Configuration()) throws {
        GRDBPrecondition(configuration.maximumReaderCount > 0, "configuration.maximumReaderCount must be at least 1")
        
        // Writer
        writer = try SerializedDatabase(
            path: path,
            configuration: configuration,
            schemaCache: SimpleDatabaseSchemaCache(),
            defaultLabel: "GRDB.DatabasePool",
            purpose: "writer")
        
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
        readerConfig.allowsUnsafeTransactions = false   // Because there's no guarantee that one can get the same reader in order to close its opened transaction.
        var readerCount = 0
        readerPool = Pool(maximumCount: configuration.maximumReaderCount, makeElement: { [unowned self] in
            readerCount += 1 // protected by pool's ReadWriteBox (undocumented behavior and protection)
            let reader = try SerializedDatabase(
                path: path,
                configuration: self.readerConfig,
                schemaCache: SimpleDatabaseSchemaCache(),
                defaultLabel: "GRDB.DatabasePool",
                purpose: "reader.\(readerCount)")
            reader.sync { self.setupDatabase($0) }
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
    
    private func setupDatabase(_ db: Database) {
        for function in functions {
            db.add(function: function)
        }
        for collation in collations {
            db.add(collation: collation)
        }
        for registration in tokenizerRegistrations {
            registration(db)
        }
    }
    
    /// Blocks the current thread until all database connections have
    /// executed the *body* block.
    fileprivate func forEachConnection(_ body: (Database) -> Void) {
        writer.sync(body)
        readerPool.forEach { $0.sync(body) }
    }
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
        try writer.sync { db in
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
        forEachConnection { $0.releaseMemory() }
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
        #if swift(>=4.2)
        center.addObserver(self, selector: #selector(DatabasePool.applicationDidReceiveMemoryWarning(_:)), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        center.addObserver(self, selector: #selector(DatabasePool.applicationDidEnterBackground(_:)), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        #else
        center.addObserver(self, selector: #selector(DatabasePool.applicationDidReceiveMemoryWarning(_:)), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
        center.addObserver(self, selector: #selector(DatabasePool.applicationDidEnterBackground(_:)), name: .UIApplicationDidEnterBackground, object: nil)
        #endif
    }
    
    @objc private func applicationDidEnterBackground(_ notification: NSNotification) {
        guard let application = application else {
            return
        }
        
        let task: UIBackgroundTaskIdentifier = application.beginBackgroundTask(expirationHandler: nil)
        #if swift(>=4.2)
        let taskIsInvalid = task == UIBackgroundTaskIdentifier.invalid
        #else
        let taskIsInvalid = task == UIBackgroundTaskInvalid
        #endif
        if taskIsInvalid {
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
                try writer.sync { try $0.change(passphrase: passphrase) }
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
    ///         // `wine` table is modified between the two requests:
    ///         let count1 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wine")!
    ///         let count2 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wine")!
    ///     }
    ///
    ///     try dbPool.read { db in
    ///         // Now this value may be different:
    ///         let count = try Int.fetchOne(db, "SELECT COUNT(*) FROM wine")!
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
                    // Reset the schema cache before running user code in snapshot isolation
                    db.schemaCache = SimpleDatabaseSchemaCache()
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
    ///         let count1 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wine")!
    ///         let count2 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wine")!
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
            try reader.sync { db in
                // No schema cache when snapshot isolation is not established
                db.schemaCache = EmptyDatabaseSchemaCache()
                return try block(db)
            }
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
    ///         let count1 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wine")!
    ///         let count2 = try Int.fetchOne(db, "SELECT COUNT(*) FROM wine")!
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
    /// This method is reentrant. It is unsafe because it fosters dangerous
    /// concurrency practices.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block, or any DatabaseError that would
    ///   happen while establishing the read access to the database.
    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        if let reader = currentReader {
            return try reader.reentrantSync(block)
        } else {
            return try readerPool.get { reader in
                try reader.sync { db in
                    // No schema cache when snapshot isolation is not established
                    db.schemaCache = EmptyDatabaseSchemaCache()
                    return try block(db)
                }
            }
        }
    }
    
    /// This method is deprecated. Use concurrentRead instead.
    ///
    /// Asynchronously executes a read-only block in a protected dispatch queue,
    /// wrapped in a deferred transaction.
    ///
    /// This method must be called from the writing dispatch queue, outside of a
    /// transaction. You'll get a fatal error otherwise.
    ///
    /// The *block* argument is guaranteed to see the database in the last
    /// committed state at the moment this method is called. Eventual concurrent
    /// database updates are *not visible* inside the block.
    ///
    ///     try dbPool.write { db in
    ///         try db.execute("DELETE FROM player")
    ///         try dbPool.readFromCurrentState { db in
    ///             // Guaranteed to be zero
    ///             try Int.fetchOne(db, "SELECT COUNT(*) FROM player")!
    ///         }
    ///         try db.execute("INSERT INTO player ...")
    ///     }
    ///
    /// This method blocks the current thread until the isolation guarantee has
    /// been established, and before the block argument has run.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block, or any DatabaseError that would
    ///   happen while establishing the read access to the database.
    @available(*, deprecated, message: "Use concurrentRead instead")
    public func readFromCurrentState(_ block: @escaping (Database) -> Void) throws {
        // Check that we're on the writer queue...
        writer.execute { db in
            // ... and that no transaction is opened.
            GRDBPrecondition(!db.isInsideTransaction, """
                readFromCurrentState must not be called from inside a transaction. \
                If this error is raised from a DatabasePool.write block, use \
                DatabasePool.writeWithoutTransaction instead (and use \
                transactions when needed).
                """)
        }
        
        // The semaphore that blocks the writing dispatch queue until snapshot
        // isolation has been established:
        let semaphore = DispatchSemaphore(value: 0)
        
        var snapshotIsolationError: Error? = nil
        let (reader, releaseReader) = try readerPool.get()
        reader.async { db in
            defer {
                _ = try? db.commit() // Ignore commit error
                releaseReader()
            }
            do {
                try db.beginSnapshotIsolation()
            } catch {
                snapshotIsolationError = error
                semaphore.signal() // Release the writer queue and rethrow error
                return
            }
            semaphore.signal() // We can release the writer queue now that we are isolated for good
            
            // Reset the schema cache before running user code in snapshot isolation
            db.schemaCache = SimpleDatabaseSchemaCache()
            block(db)
        }
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = snapshotIsolationError {
            // TODO: write a test for this
            throw error
        }
    }
    
    public func concurrentRead<T>(_ block: @escaping (Database) throws -> T) -> Future<T> {
        // Check that we're on the writer queue...
        writer.execute { db in
            // ... and that no transaction is opened.
            GRDBPrecondition(!db.isInsideTransaction, """
                concurrentRead must not be called from inside a transaction. \
                If this error is raised from a DatabasePool.write block, use \
                DatabasePool.writeWithoutTransaction instead (and use \
                transactions when needed).
                """)
        }
        
        // The semaphore that blocks the writing dispatch queue until snapshot
        // isolation has been established:
        let isolationSemaphore = DispatchSemaphore(value: 0)
        
        // The semaphore that blocks until futureResult is defined:
        let futureSemaphore = DispatchSemaphore(value: 0)
        var futureResult: Result<T>? = nil
        
        do {
            let (reader, releaseReader) = try readerPool.get()
            reader.async { db in
                defer {
                    try? db.commit() // Ignore commit error
                    releaseReader()
                }
                do {
                    try db.beginSnapshotIsolation()
                } catch {
                    futureResult = .failure(error)
                    isolationSemaphore.signal()
                    futureSemaphore.signal()
                    return
                }
                
                // Release the writer queue
                isolationSemaphore.signal()
                
                // Reset the schema cache before running user code in snapshot isolation
                db.schemaCache = SimpleDatabaseSchemaCache()
                
                // Fetch and release the future
                futureResult = Result { try block(db) }
                futureSemaphore.signal()
            }
        } catch {
            return Future { throw error }
        }
        
        // Block the writer queue until snapshot isolation success or error
        _ = isolationSemaphore.wait(timeout: .distantFuture)
        
        return Future {
            // Block the future until results are fetched
            _ = futureSemaphore.wait(timeout: .distantFuture)
            return try futureResult!.unwrap()
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
    
    // MARK: - Writing in Database
    
    /// Synchronously executes an update block in a protected dispatch queue,
    /// wrapped inside a transaction, and returns the result of the block.
    ///
    /// Eventual concurrent database updates are postponed until the block
    /// has executed.
    ///
    ///     try dbPool.write { db in
    ///         try db.execute(...)
    ///     }
    ///
    /// Eventual concurrent reads are guaranteed not to see any changes
    /// performed in the block until they are all saved in the database.
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameters block: A block that executes SQL statements.
    /// - throws: The error thrown by the block, or by the wrapping transaction.
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
    
    /// Synchronously executes a block that takes a database connection, and
    /// returns its result.
    ///
    /// Eventual concurrent database updates are postponed until the block
    /// has executed.
    ///
    /// Eventual concurrent reads may see changes performed in the block before
    /// the block completes.
    ///
    /// The block is guaranteed to be executed outside of a transaction.
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameters block: A block that executes SQL statements and return
    ///   either .commit or .rollback.
    /// - throws: The error thrown by the block.
    public func writeWithoutTransaction<T>(_ block: (Database) throws -> T) rethrows -> T {
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
    /// Eventual concurrent reads are guaranteed not to see any changes
    /// performed in the block until they are all saved in the database.
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
    /// - throws: The error thrown by the block, or any error establishing the
    ///   transaction.
    public func writeInTransaction(_ kind: Database.TransactionKind? = nil, _ block: (Database) throws -> Database.TransactionCompletion) throws {
        try writer.sync { db in
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
    /// Eventual concurrent reads may see changes performed in the block before
    /// the block completes.
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
    ///     dbPool.add(function: fn)
    ///     try dbPool.read { db in
    ///         try Int.fetchOne(db, "SELECT succ(1)") // 2
    ///     }
    public func add(function: DatabaseFunction) {
        functions.update(with: function)
        forEachConnection { $0.add(function: function) }
    }
    
    /// Remove an SQL function.
    public func remove(function: DatabaseFunction) {
        functions.remove(function)
        forEachConnection { $0.remove(function: function) }
    }
    
    // MARK: - Collations
    
    /// Add or redefine a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     dbPool.add(collation: collation)
    ///     try dbPool.write { db in
    ///         try db.execute("CREATE TABLE file (name TEXT COLLATE LOCALIZED_STANDARD")
    ///     }
    public func add(collation: DatabaseCollation) {
        collations.update(with: collation)
        forEachConnection { $0.add(collation: collation) }
    }
    
    /// Remove a collation.
    public func remove(collation: DatabaseCollation) {
        collations.remove(collation)
        forEachConnection { $0.remove(collation: collation) }
    }
    
    // MARK: - Custom FTS5 Tokenizers
    
    #if SQLITE_ENABLE_FTS5
    /// Add a custom FTS5 tokenizer.
    ///
    ///     class MyTokenizer : FTS5CustomTokenizer { ... }
    ///     dbPool.add(tokenizer: MyTokenizer.self)
    public func add<Tokenizer: FTS5CustomTokenizer>(tokenizer: Tokenizer.Type) {
        func registerTokenizer(db: Database) {
            db.add(tokenizer: Tokenizer.self)
        }
        tokenizerRegistrations.append(registerTokenizer)
        forEachConnection(registerTokenizer)
    }
    #endif
}

extension DatabasePool {
    
    // MARK: - Snapshots
    
    /// Creates a database snapshot.
    ///
    /// The snapshot sees an unchanging database content, as it existed at the
    /// moment it was created.
    ///
    /// When you want to control the latest committed changes seen by a
    /// snapshot, create it from the pool's writer protected dispatch queue:
    ///
    ///     let snapshot1 = try dbPool.write { db -> DatabaseSnapshot in
    ///         try Player.deleteAll()
    ///         return try dbPool.makeSnapshot()
    ///     }
    ///     // <- Other threads may modify the database here
    ///     let snapshot2 = try dbPool.makeSnapshot()
    ///
    ///     try snapshot1.read { db in
    ///         // Guaranteed to be zero
    ///         try Player.fetchCount(db)
    ///     }
    ///
    ///     try snapshot2.read { db in
    ///         // Could be anything
    ///         try Player.fetchCount(db)
    ///     }
    ///
    /// It is forbidden to create a snapshot from the writer protected dispatch
    /// queue when a transaction is opened, though, because it is likely a
    /// programmer error:
    ///
    ///     try dbPool.write { db in
    ///         try db.inTransaction {
    ///             try Player.deleteAll()
    ///             // fatal error: makeSnapshot() must not be called from inside a transaction
    ///             let snapshot = try dbPool.makeSnapshot()
    ///             return .commit
    ///         }
    ///     }
    ///
    /// To avoid this fatal error, create the snapshot *before* or *after* the
    /// transaction:
    ///
    ///     try dbPool.writeWithoutTransaction { db in
    ///         // OK
    ///         let snapshot = try dbPool.makeSnapshot()
    ///
    ///         try db.inTransaction {
    ///             try Player.deleteAll()
    ///             return .commit
    ///         }
    ///
    ///         // OK
    ///         let snapshot = try dbPool.makeSnapshot()
    ///     }
    ///
    /// You can create as many snapshots as you need, regardless of the maximum
    /// number of reader connections in the pool.
    ///
    /// For more information, read about "snapshot isolation" at https://sqlite.org/isolation.html
    public func makeSnapshot() throws -> DatabaseSnapshot {
        // Sanity check
        if writer.onValidQueue {
            writer.execute { db in
                GRDBPrecondition(!db.isInsideTransaction, "makeSnapshot() must not be called from inside a transaction.")
            }
        }
        
        let snapshot = try DatabaseSnapshot(
            path: path,
            configuration: writer.configuration,
            defaultLabel: "GRDB.DatabasePool",
            purpose: "snapshot.\(snapshotCount.increment())")
        snapshot.read { setupDatabase($0) }
        return snapshot
    }
}
