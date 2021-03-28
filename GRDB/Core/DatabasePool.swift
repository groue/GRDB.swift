import Foundation
import Dispatch
#if os(iOS)
import UIKit
#endif

/// A DatabasePool grants concurrent accesses to an SQLite database.
public final class DatabasePool: DatabaseWriter {
    private let writer: SerializedDatabase
    private var readerPool: Pool<SerializedDatabase>!
    
    @LockedBox var databaseSnapshotCount = 0
    
    // MARK: - Database Information
    
    /// The database configuration
    public var configuration: Configuration {
        writer.configuration
    }
    
    /// The path to the database.
    public var path: String {
        writer.path
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
            defaultLabel: "GRDB.DatabasePool",
            purpose: "writer")
        
        // Readers
        var readerConfiguration = DatabasePool.readerConfiguration(configuration)
        
        // Readers can't allow dangling transactions because there's no
        // guarantee that one can get the same reader later in order to close
        // an opened transaction.
        readerConfiguration.allowsUnsafeTransactions = false
        
        var readerCount = 0
        readerPool = Pool(maximumCount: configuration.maximumReaderCount, makeElement: {
            readerCount += 1 // protected by Pool (TODO: document this protection behavior)
            return try SerializedDatabase(
                path: path,
                configuration: readerConfiguration,
                defaultLabel: "GRDB.DatabasePool",
                purpose: "reader.\(readerCount)")
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
        setupMemoryManagement()
        #endif
    }
    
    deinit {
        // Undo job done in setupMemoryManagement()
        //
        // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11Error
        // Explicit unregistration is required before OS X 10.11.
        NotificationCenter.default.removeObserver(self)
        
        // Close reader connections before the writer connection.
        // Context: https://github.com/groue/GRDB.swift/issues/739
        readerPool = nil
    }
    
    /// Returns a Configuration suitable for readonly connections on a
    /// WAL database.
    static func readerConfiguration(_ configuration: Configuration) -> Configuration {
        var configuration = configuration
        
        configuration.readonly = true
        
        // Readers use deferred transactions by default.
        // Other transaction kinds are forbidden by SQLite in read-only connections.
        configuration.defaultTransactionKind = .deferred
        
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
        if configuration.readonlyBusyMode == nil {
            configuration.readonlyBusyMode = .timeout(10)
        }
        
        return configuration
    }
    
    /// Blocks the current thread until all database connections have
    /// executed the *body* block.
    fileprivate func forEachConnection(_ body: (Database) -> Void) {
        writer.sync(body)
        readerPool.forEach { $0.sync(body) }
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
    /// Listens to UIApplicationDidEnterBackgroundNotification and
    /// UIApplicationDidReceiveMemoryWarningNotification in order to release
    /// as much memory as possible.
    private func setupMemoryManagement() {
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
                    try db.clearSchemaCacheIfNeeded()
                    result = try block(db)
                    return .commit
                }
                return result!
            }
        }
    }
    
    /// Asynchronously executes a read-only block in a protected dispatch queue.
    ///
    ///     let players = try dbQueue.asyncRead { dbResult in
    ///         do {
    ///             let db = try dbResult.get()
    ///             let count = try Player.fetchCount(db)
    ///         } catch {
    ///             // Handle error
    ///         }
    ///     }
    ///
    /// Attempts to write in the database from this method throw a DatabaseError
    /// of resultCode `SQLITE_READONLY`.
    ///
    /// - parameter block: A block that accesses the database.
    public func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        // First async jump in order to grab a reader connection.
        // Honor configuration dispatching (qos/targetQueue).
        let label = configuration.identifier(
            defaultLabel: "GRDB.DatabasePool",
            purpose: "asyncRead")
        configuration
            .makeDispatchQueue(label: label)
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
                            try db.clearSchemaCacheIfNeeded()
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
    
    /// :nodoc:
    public func _weakAsyncRead(_ block: @escaping (Result<Database, Error>?) -> Void) {
        // First async jump in order to grab a reader connection.
        // Honor configuration dispatching (qos/targetQueue).
        let label = configuration.identifier(
            defaultLabel: "GRDB.DatabasePool",
            purpose: "asyncRead")
        configuration
            .makeDispatchQueue(label: label)
            .async { [weak self] in
                guard let self = self else {
                    block(nil)
                    return
                }
                
                do {
                    let (reader, releaseReader) = try self.readerPool.get()
                    
                    // Second async jump because sync could deadlock if
                    // configuration has a serial targetQueue.
                    reader.weakAsync { db in
                        guard let db = db else {
                            block(nil)
                            return
                        }
                        
                        defer {
                            try? db.commit() // Ignore commit error
                            releaseReader()
                        }
                        do {
                            // The block isolation comes from the DEFERRED transaction.
                            try db.beginTransaction(.deferred)
                            try db.clearSchemaCacheIfNeeded()
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
                try db.clearSchemaCacheIfNeeded()
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
                    try db.clearSchemaCacheIfNeeded()
                    return try block(db)
                }
            }
        }
    }
    
    public func concurrentRead<T>(_ block: @escaping (Database) throws -> T) -> DatabaseFuture<T> {
        // The semaphore that blocks until futureResult is defined:
        let futureSemaphore = DispatchSemaphore(value: 0)
        var futureResult: Result<T, Error>? = nil
        
        asyncConcurrentRead { dbResult in
            // Fetch and release the future
            futureResult = dbResult.flatMap { db in Result { try block(db) } }
            futureSemaphore.signal()
        }
        
        return DatabaseFuture {
            // Block the future until results are fetched
            _ = futureSemaphore.wait(timeout: .distantFuture)
            return try futureResult!.get()
        }
    }
    
    /// Performs the same job as asyncConcurrentRead.
    ///
    /// :nodoc:
    public func spawnConcurrentRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        asyncConcurrentRead(block)
    }
    
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
    ///         writer.asyncConcurrentRead { dbResult in
    ///             do {
    ///                 let db = try dbResult.get()
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
                    // https://www.sqlite.org/isolation.html
                    //
                    // > In WAL mode, SQLite exhibits "snapshot isolation". When
                    // > a read transaction starts, that reader continues to see
                    // > an unchanging "snapshot" of the database file as it
                    // > existed at the moment in time when the read transaction
                    // > started. Any write transactions that commit while the
                    // > read transaction is active are still invisible to the
                    // > read transaction, because the reader is seeing a
                    // > snapshot of database file from a prior moment in time.
                    //
                    // That's exactly what we need. But what does "when read
                    // transaction starts" mean?
                    //
                    // http://www.sqlite.org/lang_transaction.html
                    //
                    // > Deferred [transaction] means that no locks are acquired
                    // > on the database until the database is first accessed.
                    // > [...] Locks are not acquired until the first read or
                    // > write operation. [...] Because the acquisition of locks
                    // > is deferred until they are needed, it is possible that
                    // > another thread or process could create a separate
                    // > transaction and write to the database after the BEGIN
                    // > on the current thread has executed.
                    //
                    // Now that's precise enough: SQLite defers snapshot
                    // isolation until the first SELECT:
                    //
                    //     Reader                       Writer
                    //     BEGIN DEFERRED TRANSACTION
                    //                                  UPDATE ... (1)
                    //     Here the change (1) is visible from the reader
                    //     SELECT ...
                    //                                  UPDATE ... (2)
                    //     Here the change (2) is not visible from the reader
                    //
                    // We thus have to perform a select that establishes the
                    // snapshot isolation before we release the writer queue:
                    //
                    //     Reader                       Writer
                    //     BEGIN DEFERRED TRANSACTION
                    //     SELECT anything
                    //                                  UPDATE ... (1)
                    //     Here the change (1) is not visible from the reader
                    //
                    // Since any select goes, use `PRAGMA schema_version`.
                    try db.beginTransaction(.deferred)
                    try db.clearSchemaCacheIfNeeded()
                } catch {
                    isolationSemaphore.signal()
                    block(.failure(error))
                    return
                }
                
                // Now that we have an isolated snapshot of the last commit, we
                // can release the writer queue.
                isolationSemaphore.signal()
                
                block(.success(db))
            }
        } catch {
            isolationSemaphore.signal()
            block(.failure(error))
        }
        
        // Block the writer queue until snapshot isolation success or error
        _ = isolationSemaphore.wait(timeout: .distantFuture)
    }
    
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
        try writer.sync(updates)
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
        try readerPool.barrier {
            try writer.sync(updates)
        }
    }
    
    /// Asynchronously executes database updates in a protected dispatch queue,
    /// outside of any transaction, and returns the result.
    ///
    /// Updates are guaranteed an exclusive access to the database. They wait
    /// until all pending writes and reads are completed. They postpone all
    /// other writes and reads until they are completed.
    ///
    /// - important: Reads executed by concurrent *database snapshots* are not
    ///   considered: they can run concurrently with the barrier updates.
    /// - parameter updates: The updates to the database.
    public func asyncBarrierWriteWithoutTransaction(_ updates: @escaping (Database) -> Void) {
        readerPool.asyncBarrier {
            self.writer.sync(updates)
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
        try writer.reentrantSync(updates)
    }
    
    /// Asynchronously executes database updates in a protected dispatch queue,
    /// outside of any transaction.
    ///
    /// Eventual concurrent reads may see partial updates unless you wrap them
    /// in a transaction.
    public func asyncWriteWithoutTransaction(_ updates: @escaping (Database) -> Void) {
        writer.async(updates)
    }
    
    /// :nodoc:
    public func _weakAsyncWriteWithoutTransaction(_ updates: @escaping (Database?) -> Void) {
        writer.weakAsync(updates)
    }
    
    // MARK: - Database Observation
    
    /// :nodoc:
    public func _add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> DatabaseCancellable
    {
        if configuration.readonly {
            return _addReadOnly(
                observation: observation,
                scheduling: scheduler,
                onChange: onChange)
        }
        
        if observation.requiresWriteAccess {
            let observer = _addWriteOnly(
                observation: observation,
                scheduling: scheduler,
                onChange: onChange)
            return AnyDatabaseCancellable(cancel: observer.cancel)
        }
        
        let observer = _addConcurrent(
            observation: observation,
            scheduling: scheduler,
            onChange: onChange)
        return AnyDatabaseCancellable(cancel: observer.cancel)
    }
    
    /// A concurrent observation fetches the initial value without waiting for
    /// the writer.
    private func _addConcurrent<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> ValueObserver<Reducer> // For testability
    {
        assert(!configuration.readonly, "Use _addReadOnly(observation:) instead")
        assert(!observation.requiresWriteAccess, "Use _addWriteOnly(observation:) instead")
        
        let reduceQueueLabel = configuration.identifier(
            defaultLabel: "GRDB",
            purpose: "ValueObservation")
        let observer = ValueObserver(
            observation: observation,
            writer: self,
            scheduler: scheduler,
            reduceQueue: configuration.makeDispatchQueue(label: reduceQueueLabel),
            onChange: onChange)
        
        // Starting a concurrent observation means that we'll fetch the initial
        // value right away, without waiting for an access to the writer queue,
        // and the opportunity to install a transaction observer.
        //
        // This is how DatabasePool can start an observation and promptly notify
        // an initial value, even when there is a long-running write transaction
        // in the background.
        //
        // We thus have to deal with the fact that between this initial fetch,
        // and the beginning of transaction tracking, any number of untracked
        // writes may occur.
        //
        // We must notify changes that happen during this untracked window. But
        // how do we spot them, since we're not tracking database changes yet?
        //
        // A safe solution is to always perform a second fetch. We may fetch the
        // same initial value, if no change did happen. But we don't miss
        // possible changes.
        //
        // We can avoid this second fetch when SQLite is compiled with the
        // SQLITE_ENABLE_SNAPSHOT option:
        //
        // 1. Perform the initial fetch in a DatabaseSnapshot. Its long running
        // transaction acquires a lock that will prevent checkpointing until we
        // get a writer access, so that we can reliably compare database
        // versions with `sqlite3_snapshot`:
        // https://www.sqlite.org/c3ref/snapshot.html.
        //
        // 2. Get a writer access, and compare the versions of the initial
        // snapshot, and the current state of the database: if versions are
        // identical, we can avoid the second fetch. If they are not, we perform
        // the second fetch, even if the actual changes are unrelated to the
        // tracked database region (we have no way to know).
        //
        // 3. Install the transaction observer.
        
        #if SQLITE_ENABLE_SNAPSHOT
        if scheduler.immediateInitialValue() {
            do {
                let initialSnapshot = try makeSnapshot()
                let initialValue = try initialSnapshot.read(observer.fetchInitialValue)
                onChange(initialValue)
                add(observer: observer, from: initialSnapshot)
            } catch {
                observer.complete()
                observation.events.didFail?(error)
            }
        } else {
            let label = configuration.identifier(
                defaultLabel: "GRDB.DatabasePool",
                purpose: "ValueObservation")
            configuration
                .makeDispatchQueue(label: label)
                .async { [weak self] in
                    guard let self = self else { return }
                    if observer.isCompleted { return }
                    
                    do {
                        let initialSnapshot = try self.makeSnapshot()
                        let initialValue = try initialSnapshot.read(observer.fetchInitialValue)
                        observer.notifyChange(initialValue)
                        self.add(observer: observer, from: initialSnapshot)
                    } catch {
                        observer.notifyErrorAndComplete(error)
                    }
                }
        }
        #else
        if scheduler.immediateInitialValue() {
            do {
                let initialValue = try read(observer.fetchInitialValue)
                onChange(initialValue)
                addObserver(observer: observer)
            } catch {
                observer.complete()
                observation.events.didFail?(error)
            }
        } else {
            _weakAsyncRead { [weak self] dbResult in
                guard let self = self, let dbResult = dbResult else { return }
                if observer.isCompleted { return }
                
                do {
                    let initialValue = try observer.fetchInitialValue(dbResult.get())
                    observer.notifyChange(initialValue)
                    self.addObserver(observer: observer)
                } catch {
                    observer.notifyErrorAndComplete(error)
                }
            }
        }
        #endif
        
        return observer
    }
    
    #if SQLITE_ENABLE_SNAPSHOT
    // Support for _addConcurrent(observation:)
    private func add<Reducer: ValueReducer>(
        observer: ValueObserver<Reducer>,
        from initialSnapshot: DatabaseSnapshot)
    {
        _weakAsyncWriteWithoutTransaction { db in
            guard let db = db else { return }
            if observer.isCompleted { return }
            
            do {
                // Transaction is needed for version snapshotting
                try db.inTransaction(.deferred) {
                    // Keep DatabaseSnaphot alive until we have compared
                    // database versions. It prevents database checkpointing,
                    // and keeps versions (`sqlite3_snapshot`) valid
                    // and comparable.
                    let fetchNeeded: Bool = try withExtendedLifetime(initialSnapshot) {
                        guard let initialVersion = initialSnapshot.version else {
                            return true
                        }
                        return try db.wasChanged(since: initialVersion)
                    }
                    
                    if fetchNeeded {
                        observer.events.databaseDidChange?()
                        if let value = try observer.fetchValue(db) {
                            observer.notifyChange(value)
                        }
                    }
                    return .commit
                }
                
                // Now we can start observation
                db.add(transactionObserver: observer, extent: .observerLifetime)
            } catch {
                observer.notifyErrorAndComplete(error)
            }
        }
    }
    #else
    // Support for _addConcurrent(observation:)
    private func addObserver<Reducer: ValueReducer>(observer: ValueObserver<Reducer>) {
        _weakAsyncWriteWithoutTransaction { db in
            guard let db = db else { return }
            if observer.isCompleted { return }
            
            do {
                observer.events.databaseDidChange?()
                if let value = try observer.fetchValue(db) {
                    observer.notifyChange(value)
                }
                
                // Now we can start observation
                db.add(transactionObserver: observer, extent: .observerLifetime)
            } catch {
                observer.notifyErrorAndComplete(error)
            }
        }
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
        
        return try DatabaseSnapshot(
            path: path,
            configuration: writer.configuration,
            defaultLabel: "GRDB.DatabasePool",
            purpose: "snapshot.\($databaseSnapshotCount.increment())")
    }
}
