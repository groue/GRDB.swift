import Foundation
import Dispatch
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif
#if os(iOS)
import UIKit
#endif

/// A DatabasePool grants concurrent accesses to an SQLite database.
public final class DatabasePool: DatabaseWriter {
    private let writer: SerializedDatabase
    private var readerPool: Pool<SerializedDatabase>!
    // TODO: remove when the deprecated change(passphrase:) method turns unavailable.
    private var readerConfiguration: Configuration
    
    private var functions = Set<DatabaseFunction>()
    private var collations = Set<DatabaseCollation>()
    private var tokenizerRegistrations: [(Database) -> Void] = []
    
    var databaseSnapshotCount = LockedBox(value: 0)
    
    // MARK: - Database Information
    
    /// The path to the database.
    public var path: String {
        return writer.path
    }
    
    public var configuration: Configuration {
        return writer.configuration
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
            schemaCache: DatabaseSchemaCache(),
            defaultLabel: "GRDB.DatabasePool",
            purpose: "writer")
        
        // Readers
        readerConfiguration = configuration
        readerConfiguration.readonly = true
        
        // Readers use deferred transactions by default.
        // Other transaction kinds are forbidden by SQLite in read-only connections.
        readerConfiguration.defaultTransactionKind = .deferred
        
        // Readers can't allow dangling transactions because there's no
        // guarantee that one can get the same reader later in order to close
        // an opened transaction.
        readerConfiguration.allowsUnsafeTransactions = false
        
        // https://www.sqlite.org/wal.html#sometimes_queries_return_sqlite_busy_in_wal_mode
        // > But there are some obscure cases where a query against a WAL-mode
        // > database can return SQLITE_BUSY, so applications should be prepared
        // > for that happenstance.
        // >
        // > - If another database connection has the database mode open in
        // >   exclusive locking mode [...]
        // > - When the last connection to a particular database is closing,
        // >   that connection will acquire an exclusive lock for a short time
        // >   while it cleans up the WAL and shared-memory files [...]
        // > - If the last connection to a database crashed, then the first new
        // >   connection to open the database will start a recovery process. An
        // >   exclusive lock is held during recovery. [...]
        //
        // The whole point of WAL readers is to avoid SQLITE_BUSY, so let's
        // setup a busy handler for pool readers, in order to workaround those
        // "obscure cases" that may happen when the database is shared between
        // multiple processes.
        readerConfiguration.busyMode = .timeout(10)
        
        var readerCount = 0
        readerPool = Pool(maximumCount: configuration.maximumReaderCount, makeElement: { [unowned self] in
            readerCount += 1 // protected by pool (TODO: documented this protection behavior)
            let reader = try SerializedDatabase(
                path: path,
                configuration: self.readerConfiguration,
                schemaCache: DatabaseSchemaCache(),
                defaultLabel: "GRDB.DatabasePool",
                purpose: "reader.\(readerCount)")
            reader.sync { self.setupDatabase($0) }
            return reader
        })
        
        // Activate WAL Mode unless readonly
        if !configuration.readonly {
            try writer.sync { db in
                let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode = WAL")
                guard journalMode == "wal" else {
                    throw DatabaseError(message: "could not activate WAL Mode at path: \(path)")
                }
                
                // https://www.sqlite.org/pragma.html#pragma_synchronous
                // > Many applications choose NORMAL when in WAL mode
                try db.execute(sql: "PRAGMA synchronous = NORMAL")
                
                if !FileManager.default.fileExists(atPath: path + "-wal") {
                    // Create the -wal file if it does not exist yet. This
                    // avoids an SQLITE_CANTOPEN (14) error whenever a user
                    // opens a pool to an existing non-WAL database, and
                    // attempts to read from it.
                    // See https://github.com/groue/GRDB.swift/issues/102
                    try db.inSavepoint {
                        try db.execute(sql: """
                            CREATE TABLE grdb_issue_102 (id INTEGER PRIMARY KEY);
                            DROP TABLE grdb_issue_102;
                            """)
                        return .commit
                    }
                }
            }
        }
        
        setupSuspension()
        
        // Be a nice iOS citizen, and don't consume too much memory
        // See https://github.com/groue/GRDB.swift/#memory-management
        #if os(iOS)
        setupAutomaticMemoryManagement()
        #endif
    }
    
    deinit {
        // Undo job done in setupAutomaticMemoryManagement()
        //
        // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11Error
        // Explicit unregistration is required before iOS 9 and OS X 10.11.
        NotificationCenter.default.removeObserver(self)
    }
    
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
            try db.checkpoint(kind)
        }
    }
}

extension DatabasePool {
    
    // MARK: - Memory management
    
    /// Free as much memory as possible.
    ///
    /// This method blocks the current thread until all database accesses
    /// are completed.
    public func releaseMemory() {
        // Release writer memory
        writer.sync { $0.releaseMemory() }
        // Release readers memory by closing all connections
        readerPool.barrier {
            readerPool.removeAll()
        }
    }
    
    
    #if os(iOS)
    // swiftlint:disable:next line_length
    @available(*, deprecated, message: "Memory management is now enabled by default. This deprecated method does nothing.")
    public func setupMemoryManagement(in application: UIApplication) {
        // No op.
    }
    
    /// Listens to UIApplicationDidEnterBackgroundNotification and
    /// UIApplicationDidReceiveMemoryWarningNotification in order to release
    /// as much memory as possible.
    ///
    /// - param application: The UIApplication that will start a background
    ///   task to let the database pool release its memory when the application
    ///   enters background.
    private func setupAutomaticMemoryManagement() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(DatabasePool.applicationDidReceiveMemoryWarning(_:)),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
        center.addObserver(
            self,
            selector: #selector(DatabasePool.applicationDidEnterBackground(_:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
    }
    
    @objc
    private func applicationDidEnterBackground(_ notification: NSNotification) {
        guard let application = notification.object as? UIApplication else {
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
    
    @objc
    private func applicationDidReceiveMemoryWarning(_ notification: NSNotification) {
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
    @available(*, deprecated, message: "Use Database.changePassphrase(_:) instead")
    public func change(passphrase: String) throws {
        try readerPool.barrier {
            try writer.sync { try $0.changePassphrase(passphrase) }
            readerPool.removeAll()
            readerConfiguration._passphrase = passphrase
        }
    }
}
#endif

extension DatabasePool: DatabaseReader {
    
    // MARK: - Interrupting Database Operations
    
    public func interrupt() {
        writer.interrupt()
        readerPool.forEach { $0.interrupt() }
    }
    
    // MARK: - Database Suspension
    
    func suspend() {
        if configuration.readonly {
            // read-only WAL connections can't acquire locks and do not need to
            // be suspended.
            return
        }
        writer.suspend()
    }
    
    func resume() {
        if configuration.readonly {
            // read-only WAL connections can't acquire locks and do not need to
            // be suspended.
            return
        }
        writer.resume()
    }
    
    private func setupSuspension() {
        if configuration.observesSuspensionNotifications {
            let center = NotificationCenter.default
            center.addObserver(
                self,
                selector: #selector(DatabasePool.suspend(_:)),
                name: Database.suspendNotification,
                object: nil)
            center.addObserver(
                self,
                selector: #selector(DatabasePool.resume(_:)),
                name: Database.resumeNotification,
                object: nil)
        }
    }
    
    @objc
    private func suspend(_ notification: Notification) {
        suspend()
    }
    
    @objc
    private func resume(_ notification: Notification) {
        resume()
    }
    
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
    ///         let count1 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
    ///         let count2 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
    ///     }
    ///
    ///     try dbPool.read { db in
    ///         // Now this value may be different:
    ///         let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
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
                    db.clearSchemaCache()
                    result = try block(db)
                    return .commit
                }
                return result!
            }
        }
    }
    
    #if compiler(>=5.0)
    /// Asynchronously executes a read-only block in a protected dispatch queue.
    ///
    ///     let players = try dbQueue.asyncRead { result in
    ///         do {
    ///             let db = try result.get()
    ///             let count = try Player.fetchCount(db)
    ///         } catch {
    ///             // Handle error
    ///         }
    ///     }
    ///
    /// Starting SQLite 3.8.0 (iOS 8.2+, OSX 10.10+, custom SQLite builds and
    /// SQLCipher), attempts to write in the database from this method throw a
    /// DatabaseError of resultCode `SQLITE_READONLY`.
    ///
    /// - parameter block: A block that accesses the database.
    public func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        // First async jump in order to grab a reader connection.
        // Honor configuration dispatching (qos/targetQueue).
        configuration
            .makeDispatchQueue(defaultLabel: "GRDB.DatabasePool", purpose: "asyncRead")
            .async {
                do {
                    let (reader, releaseReader) = try self.readerPool.get()
                    
                    // Second async jump because sync could deadlock if
                    // configuration has a serial targetQueue.
                    reader.async { db in
                        defer {
                            try? db.commit() // Ignore commit error
                            releaseReader()
                        }
                        do {
                            // The block isolation comes from the DEFERRED transaction.
                            try db.beginTransaction(.deferred)
                            
                            // Reset the schema cache before running user code in snapshot isolation
                            db.clearSchemaCache()
                            block(.success(db))
                        } catch {
                            block(.failure(error))
                        }
                    }
                } catch {
                    block(.failure(error))
                }
        }
    }
    #endif
    
    /// Synchronously executes a read-only block in a protected dispatch queue,
    /// and returns its result.
    ///
    /// The block argument is not isolated: eventual concurrent database updates
    /// are visible inside the block:
    ///
    ///     try dbPool.unsafeRead { db in
    ///         // Those two values may be different because some other thread
    ///         // may have inserted or deleted a wine between the two requests:
    ///         let count1 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
    ///         let count2 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
    ///     }
    ///
    /// Cursor iteration is safe, though:
    ///
    ///     try dbPool.unsafeRead { db in
    ///         // No concurrent update can mess with this iteration:
    ///         let rows = try Row.fetchCursor(db, sql: "SELECT ...")
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
                // Reset the schema cache
                db.clearSchemaCache()
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
    ///         let count1 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
    ///         let count2 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
    ///     }
    ///
    /// Cursor iteration is safe, though:
    ///
    ///     try dbPool.unsafeReentrantRead { db in
    ///         // No concurrent update can mess with this iteration:
    ///         let rows = try Row.fetchCursor(db, sql: "SELECT ...")
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
                    // Reset the schema cache
                    db.clearSchemaCache()
                    return try block(db)
                }
            }
        }
    }
    
    public func concurrentRead<T>(_ block: @escaping (Database) throws -> T) -> DatabaseFuture<T> {
        // The semaphore that blocks until futureResult is defined:
        let futureSemaphore = DispatchSemaphore(value: 0)
        var futureResult: DatabaseResult<T>? = nil
        
        #if compiler(>=5.0)
        asyncConcurrentRead { db in
            // Fetch and release the future
            futureResult = DatabaseResult { try block(db.get()) }
            futureSemaphore.signal()
        }
        #else
        // Check that we're on the writer queue...
        writer.execute { db in
            // ... and that no transaction is opened.
            GRDBPrecondition(!db.isInsideTransaction, """
                must not be called from inside a transaction. \
                If this error is raised from a DatabasePool.write block, use \
                DatabasePool.writeWithoutTransaction instead (and use \
                transactions when needed).
                """)
        }
        
        // The semaphore that blocks the writing dispatch queue until snapshot
        // isolation has been established:
        let isolationSemaphore = DispatchSemaphore(value: 0)
        
        do {
            let (reader, releaseReader) = try readerPool.get()
            reader.async { db in
                defer {
                    try? db.commit() // Ignore commit error
                    releaseReader()
                }
                do {
                    try db.beginSnapshotTransaction()
                } catch {
                    futureResult = .failure(error)
                    isolationSemaphore.signal()
                    futureSemaphore.signal()
                    return
                }
                
                // Release the writer queue
                isolationSemaphore.signal()
                
                // Fetch and release the future
                futureResult = DatabaseResult {
                    // Reset the schema cache before running user code in snapshot isolation
                    db.clearSchemaCache()
                    return try block(db)
                }
                futureSemaphore.signal()
            }
        } catch {
            futureResult = .failure(error)
            isolationSemaphore.signal()
            futureSemaphore.signal()
        }
        
        // Block the writer queue until snapshot isolation success or error
        _ = isolationSemaphore.wait(timeout: .distantFuture)
        #endif
        
        return DatabaseFuture {
            // Block the future until results are fetched
            _ = futureSemaphore.wait(timeout: .distantFuture)
            return try futureResult!.get()
        }
    }
    
    #if compiler(>=5.0)
    /// Performs the same job as asyncConcurrentRead.
    ///
    /// :nodoc:
    public func spawnConcurrentRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        asyncConcurrentRead(block)
    }
    #endif
    
    #if compiler(>=5.0)
    /// Asynchronously executes a read-only block in a protected dispatch queue.
    ///
    /// This method must be called from a writing dispatch queue, outside of any
    /// transaction. You'll get a fatal error otherwise.
    ///
    /// The *block* argument is guaranteed to see the database in the last
    /// committed state at the moment this method is called. Eventual concurrent
    /// database updates are *not visible* inside the block.
    ///
    /// This method returns as soon as the isolation guarantees described above
    /// are established.
    ///
    /// In the example below, the number of players is fetched concurrently with
    /// the player insertion. Yet the future is guaranteed to return zero:
    ///
    ///     try writer.asyncWriteWithoutTransaction { db in
    ///         // Delete all players
    ///         try Player.deleteAll()
    ///
    ///         // Count players concurrently
    ///         writer.asyncConcurrentRead { result in
    ///             do {
    ///                 let db = try result.get()
    ///                 // Guaranteed to be zero
    ///                 let count = try Player.fetchCount(db)
    ///             } catch {
    ///                 // Handle error
    ///             }
    ///         }
    ///
    ///         // Insert a player
    ///         try Player(...).insert(db)
    ///     }
    ///
    /// - parameter block: A block that accesses the database.
    public func asyncConcurrentRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        // Check that we're on the writer queue...
        writer.execute { db in
            // ... and that no transaction is opened.
            GRDBPrecondition(!db.isInsideTransaction, """
                must not be called from inside a transaction. \
                If this error is raised from a DatabasePool.write block, use \
                DatabasePool.writeWithoutTransaction instead (and use \
                transactions when needed).
                """)
        }
        
        // The semaphore that blocks the writing dispatch queue until snapshot
        // isolation has been established:
        let isolationSemaphore = DispatchSemaphore(value: 0)
        
        do {
            let (reader, releaseReader) = try readerPool.get()
            reader.async { db in
                defer {
                    try? db.commit() // Ignore commit error
                    releaseReader()
                }
                do {
                    try db.beginSnapshotTransaction()
                } catch {
                    isolationSemaphore.signal()
                    block(.failure(error))
                    return
                }
                
                // Release the writer queue
                isolationSemaphore.signal()
                
                // Reset the schema cache before running user code in snapshot isolation
                db.clearSchemaCache()

                block(.success(db))
            }
        } catch {
            isolationSemaphore.signal()
            block(.failure(error))
        }
        
        // Block the writer queue until snapshot isolation success or error
        _ = isolationSemaphore.wait(timeout: .distantFuture)
    }
    #endif
    
    /// Invalidates open read-only SQLite connections.
    ///
    /// After this method is called, read-only database access methods will use
    /// new SQLite connections.
    ///
    /// Eventual concurrent read-only accesses are not invalidated: they will
    /// proceed until completion.
    public func invalidateReadOnlyConnections() {
        readerPool.removeAll()
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
    
    /// Synchronously executes database updates in a protected dispatch queue,
    /// outside of any transaction, and returns the result.
    ///
    /// Eventual concurrent database updates are postponed until the updates
    /// are completed.
    ///
    /// Eventual concurrent reads may see partial updates unless you wrap them
    /// in a transaction.
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter updates: The updates to the database.
    /// - throws: The error thrown by the updates.
    public func writeWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T {
        return try writer.sync(updates)
    }
    
    /// Synchronously executes database updates in a protected dispatch queue,
    /// outside of any transaction, and returns the result.
    ///
    /// Updates are guaranteed an exclusive access to the database. They wait
    /// until all pending writes and reads are completed. They postpone all
    /// other writes and reads until they are completed.
    ///
    /// This method is *not* reentrant.
    ///
    /// - important: Reads executed by concurrent *database snapshots* are not
    ///   considered: they can run concurrently with the barrier updates.
    /// - parameter updates: The updates to the database.
    /// - throws: The error thrown by the updates.
    public func barrierWriteWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T {
        return try readerPool.barrier {
            try writer.sync(updates)
        }
    }
    
    /// Synchronously executes database updates in a protected dispatch queue,
    /// wrapped inside a transaction, and returns the result.
    ///
    /// If the updates throws an error, the transaction is rollbacked and the
    /// error is rethrown. If the updates return .rollback, the transaction is
    /// also rollbacked, but no error is thrown.
    ///
    /// Eventual concurrent database updates are postponed until the transaction
    /// has completed.
    ///
    /// Eventual concurrent reads are guaranteed to not see any partial updates
    /// of the database until the transaction has completed.
    ///
    /// This method is *not* reentrant.
    ///
    ///     try dbPool.writeInTransaction { db in
    ///         db.execute(...)
    ///         return .commit
    ///     }
    ///
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is configuration.defaultTransactionKind, which itself
    ///       defaults to .deferred. See https://www.sqlite.org/lang_transaction.html
    ///       for more information.
    ///     - updates: The updates to the database.
    /// - throws: The error thrown by the updates, or by the
    ///   wrapping transaction.
    public func writeInTransaction(
        _ kind: Database.TransactionKind? = nil,
        _ updates: (Database) throws -> Database.TransactionCompletion)
        throws
    {
        try writer.sync { db in
            try db.inTransaction(kind) {
                try updates(db)
            }
        }
    }
    
    /// Synchronously executes database updates in a protected dispatch queue,
    /// outside of any transaction, and returns the result.
    ///
    /// Eventual concurrent database updates are postponed until the updates
    /// are completed.
    ///
    /// Eventual concurrent reads may see partial updates unless you wrap them
    /// in a transaction.
    ///
    /// This method is reentrant. It should be avoided because it fosters
    /// dangerous concurrency practices.
    public func unsafeReentrantWrite<T>(_ updates: (Database) throws -> T) rethrows -> T {
        return try writer.reentrantSync(updates)
    }
    
    /// Asynchronously executes database updates in a protected dispatch queue,
    /// outside of any transaction.
    ///
    /// Eventual concurrent reads may see partial updates unless you wrap them
    /// in a transaction.
    public func asyncWriteWithoutTransaction(_ updates: @escaping (Database) -> Void) {
        writer.async(updates)
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
    ///         try Int.fetchOne(db, sql: "SELECT succ(1)") // 2
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
    ///         try db.execute(sql: "CREATE TABLE file (name TEXT COLLATE LOCALIZED_STANDARD")
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
                GRDBPrecondition(
                    !db.isInsideTransaction,
                    "makeSnapshot() must not be called from inside a transaction.")
            }
        }
        
        let snapshot = try DatabaseSnapshot(
            path: path,
            configuration: writer.configuration,
            defaultLabel: "GRDB.DatabasePool",
            purpose: "snapshot.\(databaseSnapshotCount.increment())")
        snapshot.read { setupDatabase($0) }
        return snapshot
    }
}
