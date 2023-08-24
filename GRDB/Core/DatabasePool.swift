import Dispatch
import Foundation
#if os(iOS)
import UIKit
#endif

public final class DatabasePool {
    private let writer: SerializedDatabase
    
    /// The pool of reader connections.
    /// It is constant, until close() sets it to nil.
    private var readerPool: Pool<SerializedDatabase>?
    
    @LockedBox var databaseSnapshotCount = 0
    
    /// If Database Suspension is enabled, this array contains the necessary `NotificationCenter` observers.
    private var suspensionObservers: [NSObjectProtocol] = []
    
    // MARK: - Database Information
    
    public var configuration: Configuration {
        writer.configuration
    }
    
    /// The path to the database.
    public var path: String {
        writer.path
    }
    
    // MARK: - Initializer
    
    /// Opens or creates an SQLite database.
    ///
    /// For example:
    ///
    /// ```swift
    /// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
    /// ```
    ///
    /// The SQLite connections are closed when the database pool
    /// gets deallocated.
    ///
    /// - parameters:
    ///     - path: The path to the database file.
    ///     - configuration: A configuration.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
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
        readerPool = Pool(
            maximumCount: configuration.maximumReaderCount,
            qos: configuration.readQoS,
            makeElement: {
                readerCount += 1 // protected by Pool (TODO: document this protection behavior)
                return try SerializedDatabase(
                    path: path,
                    configuration: readerConfiguration,
                    defaultLabel: "GRDB.DatabasePool",
                    purpose: "reader.\(readerCount)")
            })
        
        // Set up journal mode unless readonly
        if !configuration.readonly {
            switch configuration.journalMode {
            case .default, .wal:
                try writer.sync {
                    try $0.setUpWALMode()
                }
            }
        }
        
        setupSuspension()
        
        // Be a nice iOS citizen, and don't consume too much memory
        // See https://github.com/groue/GRDB.swift/#memory-management
        #if os(iOS)
        if configuration.automaticMemoryManagement {
            setupMemoryManagement()
        }
        #endif
    }
    
    deinit {
        // Remove block-based Notification observers.
        suspensionObservers.forEach(NotificationCenter.default.removeObserver(_:))
        
        // Undo job done in setupMemoryManagement()
        //
        // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11Error
        // Explicit unregistration is required before macOS 10.11.
        NotificationCenter.default.removeObserver(self)
        
        // Close reader connections before the writer connection.
        // Context: https://github.com/groue/GRDB.swift/issues/739
        readerPool = nil
    }
    
    /// Returns a Configuration suitable for readonly connections on a
    /// WAL database.
    private static func readerConfiguration(_ configuration: Configuration) -> Configuration {
        var configuration = configuration
        
        configuration.readonly = true
        
        // Readers use deferred transactions by default.
        // Other transaction kinds are forbidden by SQLite in read-only connections.
        configuration.defaultTransactionKind = .deferred
        
        // <https://www.sqlite.org/wal.html#sometimes_queries_return_sqlite_busy_in_wal_mode>
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
}

// @unchecked because of databaseSnapshotCount, readerPool and suspensionObservers
extension DatabasePool: @unchecked Sendable { }

extension DatabasePool {
    
    // MARK: - Memory management
    
    /// Frees as much memory as possible, by disposing non-essential memory.
    ///
    /// This method is synchronous, and blocks the current thread until all
    /// database accesses are completed.
    ///
    /// This method closes all read-only connections, unless the
    /// ``Configuration/persistentReadOnlyConnections`` configuration flag
    /// is set.
    ///
    /// - warning: This method can prevent concurrent reads from executing,
    ///   until it returns. Prefer ``releaseMemoryEventually()`` if you intend
    ///   to keep on using the database while releasing memory.
    public func releaseMemory() {
        // Release writer memory
        writer.sync { $0.releaseMemory() }
        
        if configuration.persistentReadOnlyConnections {
            // Keep existing readers
            readerPool?.forEach { reader in
                reader.sync { $0.releaseMemory() }
            }
        } else {
            // Release readers memory by closing all connections.
            //
            // We must use a barrier in order to guarantee that memory has been
            // freed (reader connections closed) when the method exits, as
            // documented.
            //
            // Without the barrier, connections would only close _eventually_ (after
            // their eventual concurrent jobs have completed).
            readerPool?.barrier {
                readerPool?.removeAll()
            }
        }
    }
    
    /// Eventually frees as much memory as possible, by disposing
    /// non-essential memory.
    ///
    /// This method eventually closes all read-only connections, unless the
    /// ``Configuration/persistentReadOnlyConnections`` configuration flag
    /// is set.
    ///
    /// Unlike ``releaseMemory()``, this method does not prevent concurrent
    /// database accesses when it is executing. But it does not notify when
    /// non-essential memory has been freed.
    public func releaseMemoryEventually() {
        if configuration.persistentReadOnlyConnections {
            // Keep existing readers
            readerPool?.forEach { reader in
                reader.async { $0.releaseMemory() }
            }
        } else {
            // Release readers memory by eventually closing all reader connections
            // (they will close after their current jobs have completed).
            readerPool?.removeAll()
        }
        
        // Release writer memory eventually.
        writer.async { $0.releaseMemory() }
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
            // Release memory synchronously
            releaseMemory()
        } else {
            // Release memory eventually.
            //
            // We don't know when reader connections will be closed (because
            // they may be currently in use), so we don't quite know when
            // reader memory will be freed (which would be the ideal timing for
            // ending our background task).
            //
            // So let's just end the background task after the writer connection
            // has freed its memory. That's better than nothing.
            releaseMemoryEventually()
            writer.async { _ in
                application.endBackgroundTask(task)
            }
        }
    }
    
    @objc
    private func applicationDidReceiveMemoryWarning(_ notification: NSNotification) {
        releaseMemoryEventually()
    }
    #endif
}

extension DatabasePool: DatabaseReader {
    
    public func close() throws {
        try readerPool?.barrier {
            // Close writer connection first. If we can't close it,
            // don't close readers.
            //
            // This allows us to exit this method as fully closed (read and
            // writes fail), or not closed at all (reads and writes succeed).
            //
            // Unfortunately, this introduces a regression for
            // https://github.com/groue/GRDB.swift/issues/739.
            // TODO: fix this regression.
            try writer.sync { try $0.close() }
            
            // OK writer is closed. Now close readers and
            // eventually prevent any future read access
            defer { readerPool = nil }
            
            try readerPool?.forEach { reader in
                try reader.sync { try $0.close() }
            }
        }
    }
    
    // MARK: - Interrupting Database Operations
    
    public func interrupt() {
        writer.interrupt()
        readerPool?.forEach { $0.interrupt() }
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
            suspensionObservers.append(center.addObserver(
                forName: Database.suspendNotification,
                object: nil,
                queue: nil,
                using: { [weak self] _ in self?.suspend() }
            ))
            suspensionObservers.append(center.addObserver(
                forName: Database.resumeNotification,
                object: nil,
                queue: nil,
                using: { [weak self] _ in self?.resume() }
            ))
        }
    }
    
    // MARK: - Reading from Database
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func read<T>(_ value: (Database) throws -> T) throws -> T {
        GRDBPrecondition(currentReader == nil, "Database methods are not reentrant.")
        guard let readerPool else {
            throw DatabaseError.connectionIsClosed()
        }
        return try readerPool.get { reader in
            try reader.sync { db in
                try db.isolated {
                    try db.clearSchemaCacheIfNeeded()
                    return try value(db)
                }
            }
        }
    }
    
    public func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        guard let readerPool else {
            value(.failure(DatabaseError.connectionIsClosed()))
            return
        }
        
        readerPool.asyncGet { result in
            do {
                let (reader, releaseReader) = try result.get()
                // Second async jump because that's how `Pool.async` has to be used.
                reader.async { db in
                    defer {
                        try? db.commit() // Ignore commit error
                        releaseReader(.reuse)
                    }
                    do {
                        // The block isolation comes from the DEFERRED transaction.
                        try db.beginTransaction(.deferred)
                        try db.clearSchemaCacheIfNeeded()
                        value(.success(db))
                    } catch {
                        value(.failure(error))
                    }
                }
            } catch {
                value(.failure(error))
            }
        }
    }
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func unsafeRead<T>(_ value: (Database) throws -> T) throws -> T {
        GRDBPrecondition(currentReader == nil, "Database methods are not reentrant.")
        guard let readerPool else {
            throw DatabaseError.connectionIsClosed()
        }
        return try readerPool.get { reader in
            try reader.sync { db in
                try db.clearSchemaCacheIfNeeded()
                return try value(db)
            }
        }
    }
    
    public func asyncUnsafeRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        guard let readerPool else {
            value(.failure(DatabaseError.connectionIsClosed()))
            return
        }
        
        readerPool.asyncGet { result in
            do {
                let (reader, releaseReader) = try result.get()
                // Second async jump because that's how `Pool.async` has to be used.
                reader.async { db in
                    defer {
                        releaseReader(.reuse)
                    }
                    do {
                        try db.clearSchemaCacheIfNeeded()
                        value(.success(db))
                    } catch {
                        value(.failure(error))
                    }
                }
            } catch {
                value(.failure(error))
            }
        }
    }
    
    public func unsafeReentrantRead<T>(_ value: (Database) throws -> T) throws -> T {
        if let reader = currentReader {
            return try reader.reentrantSync(value)
        } else if writer.onValidQueue {
            return try writer.execute(value)
        } else {
            guard let readerPool else {
                throw DatabaseError.connectionIsClosed()
            }
            return try readerPool.get { reader in
                try reader.sync { db in
                    try db.clearSchemaCacheIfNeeded()
                    return try value(db)
                }
            }
        }
    }
    
    public func concurrentRead<T>(_ value: @escaping (Database) throws -> T) -> DatabaseFuture<T> {
        // The semaphore that blocks until futureResult is defined:
        let futureSemaphore = DispatchSemaphore(value: 0)
        var futureResult: Result<T, Error>? = nil
        
        asyncConcurrentRead { dbResult in
            // Fetch and release the future
            futureResult = dbResult.flatMap { db in Result { try value(db) } }
            futureSemaphore.signal()
        }
        
        return DatabaseFuture {
            // Block the future until results are fetched
            _ = futureSemaphore.wait(timeout: .distantFuture)
            return try futureResult!.get()
        }
    }
    
    public func spawnConcurrentRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        asyncConcurrentRead(value)
    }
    
    /// Performs an asynchronous read access.
    ///
    /// This method must be called from the writer dispatch queue, outside of
    /// any transaction. You'll get a fatal error otherwise.
    ///
    /// The `value` function is guaranteed to see the database in the last
    /// committed state at the moment this method is called. Eventual
    /// concurrent database updates are not visible from the function.
    ///
    /// This method returns as soon as the isolation guarantee described above
    /// has been established.
    ///
    /// In the example below, the number of players is fetched concurrently with
    /// the player insertion. Yet it is guaranteed to be zero:
    ///
    /// ```swift
    /// try writer.asyncWriteWithoutTransaction { db in
    ///     // Delete all players
    ///     try Player.deleteAll()
    ///
    ///     // Count players concurrently
    ///     writer.asyncConcurrentRead { dbResult in
    ///         do {
    ///             let db = try dbResult.get()
    ///             // Guaranteed to be zero
    ///             let count = try Player.fetchCount(db)
    ///         } catch {
    ///             // Handle error
    ///         }
    ///     }
    ///
    ///     // Insert a player
    ///     try Player(...).insert(db)
    /// }
    /// ```
    ///
    /// - parameter value: A function that accesses the database.
    public func asyncConcurrentRead(_ value: @escaping (Result<Database, Error>) -> Void) {
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
            guard let readerPool else {
                throw DatabaseError.connectionIsClosed()
            }
            let (reader, releaseReader) = try readerPool.get()
            reader.async { db in
                defer {
                    try? db.commit() // Ignore commit error
                    releaseReader(.reuse)
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
                    value(.failure(error))
                    return
                }
                
                // Now that we have an isolated snapshot of the last commit, we
                // can release the writer queue.
                isolationSemaphore.signal()
                
                value(.success(db))
            }
        } catch {
            isolationSemaphore.signal()
            value(.failure(error))
        }
        
        // Block the writer queue until snapshot isolation success or error
        _ = isolationSemaphore.wait(timeout: .distantFuture)
    }
    
    /// Invalidates open read-only SQLite connections.
    ///
    /// After this method is called, read-only database access methods will use
    /// new SQLite connections.
    ///
    /// Eventual concurrent read-only accesses are not interrupted, and
    /// proceed until completion.
    ///
    /// - This method closes all read-only connections, even if the
    /// ``Configuration/persistentReadOnlyConnections`` configuration flag
    /// is set.
    public func invalidateReadOnlyConnections() {
        readerPool?.removeAll()
    }
    
    /// Returns a reader that can be used from the current dispatch queue,
    /// if any.
    private var currentReader: SerializedDatabase? {
        guard let readerPool else {
            return nil
        }
        
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
    
    // MARK: - WAL Snapshot Transactions
    
    // swiftlint:disable:next line_length
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
    /// Returns a long-lived WAL snapshot transaction on a reader connection.
    func walSnapshotTransaction() throws -> WALSnapshotTransaction {
        guard let readerPool else {
            throw DatabaseError.connectionIsClosed()
        }
        
        let (reader, releaseReader) = try readerPool.get()
        return try WALSnapshotTransaction(onReader: reader, release: { isInsideTransaction in
            // Discard the connection if the transaction could not be
            // properly ended. If we'd reuse it, the next read would
            // fail because we'd fail starting a read transaction.
            releaseReader(isInsideTransaction ? .discard : .reuse)
        })
    }
    
    /// Returns a long-lived WAL snapshot transaction on a reader connection.
    ///
    /// - important: The `completion` argument is executed in a serial
    ///   dispatch queue, so make sure you use the transaction asynchronously.
    func asyncWALSnapshotTransaction(_ completion: @escaping (Result<WALSnapshotTransaction, Error>) -> Void) {
        guard let readerPool else {
            completion(.failure(DatabaseError.connectionIsClosed()))
            return
        }
        
        readerPool.asyncGet { result in
            completion(result.flatMap { reader, releaseReader in
                Result {
                    try WALSnapshotTransaction(onReader: reader, release: { isInsideTransaction in
                        // Discard the connection if the transaction could not be
                        // properly ended. If we'd reuse it, the next read would
                        // fail because we'd fail starting a read transaction.
                        releaseReader(isInsideTransaction ? .discard : .reuse)
                    })
                }
            })
        }
    }
#endif
    
    // MARK: - Database Observation
    
    public func _add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: some ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> AnyDatabaseCancellable
    {
        if configuration.readonly {
            // The easy case: the database does not change
            return _addReadOnly(
                observation: observation,
                scheduling: scheduler,
                onChange: onChange)
            
        } else if observation.requiresWriteAccess {
            // Observe from the writer database connection.
            return _addWriteOnly(
                observation: observation,
                scheduling: scheduler,
                onChange: onChange)
            
        } else {
            // DatabasePool can perform concurrent observation
            return _addConcurrent(
                observation: observation,
                scheduling: scheduler,
                onChange: onChange)
        }
    }
    
    /// A concurrent observation fetches the initial value without waiting for
    /// the writer.
    private func _addConcurrent<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: some ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> AnyDatabaseCancellable
    {
        assert(!configuration.readonly, "Use _addReadOnly(observation:) instead")
        assert(!observation.requiresWriteAccess, "Use _addWriteOnly(observation:) instead")
        let observer = ValueConcurrentObserver(
            dbPool: self,
            scheduler: scheduler,
            trackingMode: observation.trackingMode,
            reducer: observation.makeReducer(),
            events: observation.events,
            onChange: onChange)
        return observer.start()
    }
}

extension DatabasePool: DatabaseWriter {
    // MARK: - Writing in Database
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func writeWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try writer.sync(updates)
    }
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func barrierWriteWithoutTransaction<T>(_ updates: (Database) throws -> T) throws -> T {
        guard let readerPool else {
            throw DatabaseError.connectionIsClosed()
        }
        return try readerPool.barrier {
            try writer.sync(updates)
        }
    }
    
    public func asyncBarrierWriteWithoutTransaction(_ updates: @escaping (Result<Database, Error>) -> Void) {
        guard let readerPool else {
            updates(.failure(DatabaseError.connectionIsClosed()))
            return
        }
        readerPool.asyncBarrier {
            self.writer.sync { updates(.success($0)) }
        }
    }
    
    /// Wraps database operations inside a database transaction.
    ///
    /// The `updates` function runs in the writer dispatch queue, serialized
    /// with all database updates.
    ///
    /// If `updates` throws an error, the transaction is rollbacked and the
    /// error is rethrown. If it returns
    /// ``Database/TransactionCompletion/rollback``, the transaction is also
    /// rollbacked, but no error is thrown.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbPool.writeInTransaction { db in
    ///     try Player(name: "Arthur").insert(db)
    ///     try Player(name: "Barbara").insert(db)
    ///     return .commit
    /// }
    /// ```
    ///
    /// - precondition: This method is not reentrant.
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is the ``Configuration/defaultTransactionKind`` of the
    ///       the ``configuration``.
    ///     - updates: A function that updates the database.
    /// - throws: The error thrown by `updates`, or by the wrapping transaction.
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
    
    public func unsafeReentrantWrite<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try writer.reentrantSync(updates)
    }
    
    public func asyncWriteWithoutTransaction(_ updates: @escaping (Database) -> Void) {
        writer.async(updates)
    }
}

extension DatabasePool {
    
    // MARK: - Snapshots
    
    /// Creates a database snapshot that serializes accesses to an unchanging
    /// database content, as it exists at the moment the snapshot is created.
    ///
    /// It is a programmer error to create a snapshot from the writer dispatch
    /// queue when a transaction is opened:
    ///
    /// ```swift
    /// try dbPool.write { db in
    ///     try Player.deleteAll()
    ///
    ///     // fatal error: makeSnapshot() must not be called from inside a transaction
    ///     let snapshot = try dbPool.makeSnapshot()
    /// }
    /// ```
    ///
    /// To avoid this fatal error, create the snapshot *before* or *after*
    /// the transaction:
    ///
    /// ```swift
    /// let snapshot = try dbPool.makeSnapshot() // OK
    ///
    /// try dbPool.writeWithoutTransaction { db in
    ///     let snapshot = try dbPool.makeSnapshot() // OK
    ///
    ///     try db.inTransaction {
    ///         try Player.deleteAll()
    ///         return .commit
    ///     }
    ///
    ///     // OK
    ///     let snapshot = try dbPool.makeSnapshot() // OK
    /// }
    ///
    /// let snapshot = try dbPool.makeSnapshot() // OK
    /// ```
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
            configuration: DatabasePool.readerConfiguration(writer.configuration),
            defaultLabel: "GRDB.DatabasePool",
            purpose: "snapshot.\($databaseSnapshotCount.increment())")
    }
    
    // swiftlint:disable:next line_length
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
    /// Creates a database snapshot that allows concurrent accesses to an
    /// unchanging database content, as it exists at the moment the snapshot
    /// is created.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// A ``DatabaseError`` of code `SQLITE_ERROR` is thrown if the SQLite
    /// database is not in the [WAL mode](https://www.sqlite.org/wal.html),
    /// or if this method is called from a write transaction, or if the
    /// wal file is missing or truncated (size zero).
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/snapshot_get.html>
    public func makeSnapshotPool() throws -> DatabaseSnapshotPool {
        try unsafeReentrantRead { db in
            try DatabaseSnapshotPool(db)
        }
    }
#endif
}
