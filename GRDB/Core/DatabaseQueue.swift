import Foundation

#if os(iOS)
import UIKit
#endif

public final class DatabaseQueue {
    private let writer: SerializedDatabase
    
    // MARK: - Configuration
    
    public var configuration: Configuration {
        writer.configuration
    }
    
    /// The path to the database file.
    ///
    /// The path is `:memory:` for in-memory databases.
    public var path: String {
        writer.path
    }
    
    // MARK: - Initializers
    
    /// Opens or creates an SQLite database.
    ///
    /// For example:
    ///
    /// ```swift
    /// let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
    /// ```
    ///
    /// The SQLite connection is closed when the database queue
    /// gets deallocated.
    ///
    /// - parameters:
    ///     - path: The path to the database file.
    ///     - configuration: A configuration.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public init(path: String, configuration: Configuration = Configuration()) throws {
        // DatabaseQueue can't perform parallel reads
        var configuration = configuration
        configuration.maximumReaderCount = 1
        
        writer = try SerializedDatabase(
            path: path,
            configuration: configuration,
            defaultLabel: "GRDB.DatabaseQueue")
        
        setupSuspension()
        
        // Be a nice iOS citizen, and don't consume too much memory
        // See https://github.com/groue/GRDB.swift/#memory-management
        #if os(iOS)
        if configuration.automaticMemoryManagement {
            setupMemoryManagement()
        }
        #endif
    }
    
    /// Opens an in-memory SQLite database.
    ///
    /// To create an independent in-memory database, don't pass any name. The
    /// database memory is released when the database queue is deallocated:
    ///
    /// ```swift
    /// // An independent in-memory database
    /// let dbQueue = try DatabaseQueue()
    /// ```
    ///
    /// When you need to open several connections to the same in-memory
    /// database, give it a name:
    ///
    /// ```swift
    /// // A shared in-memory database
    /// let dbQueue = try DatabaseQueue(named: "myDatabase")
    /// ```
    ///
    /// In this case, the database is automatically deleted and memory is
    /// reclaimed when the last connection to the database of the given
    /// name closes.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/inmemorydb.html>
    ///
    /// - parameter name: When nil, an independent in-memory database opens.
    ///   Otherwise, the shared in-memory database of the given name opens.
    /// - parameter configuration: A configuration.
    public init(named name: String? = nil, configuration: Configuration = Configuration()) throws {
        let path: String
        if let name {
            path = "file:\(name)?mode=memory&cache=shared"
        } else {
            path = ":memory:"
        }
        
        writer = try SerializedDatabase(
            path: path,
            configuration: configuration,
            defaultLabel: "GRDB.DatabaseQueue")
    }
    
    deinit {
        // Undo job done in setupMemoryManagement()
        //
        // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11Error
        // Explicit unregistration is required before macOS 10.11.
        NotificationCenter.default.removeObserver(self)
    }
}

extension DatabaseQueue {
    
    // MARK: - Memory management
    
    /// Free as much memory as possible.
    ///
    /// This method blocks the current thread until all database accesses are completed.
    public func releaseMemory() {
        writer.sync { $0.releaseMemory() }
    }
    
    #if os(iOS)
    /// Listens to UIApplicationDidEnterBackgroundNotification and
    /// UIApplicationDidReceiveMemoryWarningNotification in order to release
    /// as much memory as possible.
    private func setupMemoryManagement() {
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
            // Release memory asynchronously
            writer.async { db in
                db.releaseMemory()
                application.endBackgroundTask(task)
            }
        }
    }
    
    @objc
    private func applicationDidReceiveMemoryWarning(_ notification: NSNotification) {
        writer.async { db in
            db.releaseMemory()
        }
    }
    #endif
}

extension DatabaseQueue: DatabaseReader {
    public func close() throws {
        try writer.sync { try $0.close() }
    }
    
    // MARK: - Interrupting Database Operations
    
    public func interrupt() {
        writer.interrupt()
    }
    
    // MARK: - Database Suspension
    
    func suspend() {
        writer.suspend()
    }
    
    func resume() {
        writer.resume()
    }
    
    private func setupSuspension() {
        if configuration.observesSuspensionNotifications {
            let center = NotificationCenter.default
            center.addObserver(
                self,
                selector: #selector(DatabaseQueue.suspend(_:)),
                name: Database.suspendNotification,
                object: nil)
            center.addObserver(
                self,
                selector: #selector(DatabaseQueue.resume(_:)),
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
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func read<T>(_ value: (Database) throws -> T) throws -> T {
        try writer.sync { db in
            try db.isolated(readOnly: true) {
                try value(db)
            }
        }
    }
    
    public func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        writer.async { db in
            defer {
                // Ignore error because we can not notify it.
                try? db.commit()
                try? db.endReadOnly()
            }
            
            do {
                // Enter read-only mode before starting a transaction, so that the
                // transaction commit does not trigger database observation.
                // See <https://github.com/groue/GRDB.swift/pull/1213>.
                try db.beginReadOnly()
                try db.beginTransaction(.deferred)
                value(.success(db))
            } catch {
                value(.failure(error))
            }
        }
    }
    
    public func unsafeRead<T>(_ value: (Database) throws -> T) rethrows -> T {
        try writer.sync(value)
    }
    
    public func asyncUnsafeRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        writer.async { value(.success($0)) }
    }
    
    public func unsafeReentrantRead<T>(_ value: (Database) throws -> T) rethrows -> T {
        try writer.reentrantSync(value)
    }
    
    public func concurrentRead<T>(_ value: @escaping (Database) throws -> T) -> DatabaseFuture<T> {
        // DatabaseQueue can't perform parallel reads.
        // Perform a blocking read instead.
        return DatabaseFuture(Result {
            // Check that we're on the writer queue, as documented
            try writer.execute { db in
                try db.isolated(readOnly: true) {
                    try value(db)
                }
            }
        })
    }
    
    public func spawnConcurrentRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        // Check that we're on the writer queue...
        writer.execute { db in
            // ... and that no transaction is opened.
            GRDBPrecondition(!db.isInsideTransaction, "must not be called from inside a transaction.")

            defer {
                // Ignore error because we can not notify it.
                try? db.commit()
                try? db.endReadOnly()
            }
            
            do {
                // Enter read-only mode before starting a transaction, so that the
                // transaction commit does not trigger database observation.
                // See <https://github.com/groue/GRDB.swift/pull/1213>.
                try db.beginReadOnly()
                try db.beginTransaction(.deferred)
                value(.success(db))
            } catch {
                value(.failure(error))
            }
        }
    }
    
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
        } else {
            // Observe from the writer database connection.
            return _addWriteOnly(
                observation: observation,
                scheduling: scheduler,
                onChange: onChange)
        }
    }
}

extension DatabaseQueue: DatabaseWriter {
    // MARK: - Writing in Database
    
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
    /// try dbQueue.inTransaction { db in
    ///     try Player(name: "Arthur").insert(db)
    ///     try Player(name: "Barbara").insert(db)
    ///     return .commit
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is the ``Configuration/defaultTransactionKind`` of the
    ///       the ``configuration``.
    ///     - updates: A function that updates the database.
    /// - throws: The error thrown by `updates`, or by the wrapping transaction.
    public func inTransaction(
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
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func writeWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try writer.sync(updates)
    }
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func barrierWriteWithoutTransaction<T>(_ updates: (Database) throws -> T) throws -> T {
        try writer.sync(updates)
    }
    
    public func asyncBarrierWriteWithoutTransaction(_ updates: @escaping (Result<Database, Error>) -> Void) {
        writer.async { updates(.success($0)) }
    }
    
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// This method is identical to
    /// ``DatabaseWriter/writeWithoutTransaction(_:)-4qh1w``
    ///
    /// For example:
    ///
    /// ```swift
    /// let newPlayerCount = try dbQueue.inDatabase { db in
    ///     try Player(name: "Arthur").insert(db)
    ///     return try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// Database operations run in the writer dispatch queue, serialized
    /// with all database updates performed by this `DatabaseWriter`.
    ///
    /// The ``Database`` argument to `updates` is valid only during the
    /// execution of the closure. Do not store or return the database connection
    /// for later use.
    ///
    /// It is a programmer error to call this method from another database
    /// access method. Doing so raises a "Database methods are not reentrant"
    /// fatal error at runtime.
    ///
    /// - warning: Database operations are not wrapped in a transaction. They
    ///   can see changes performed by concurrent writes or writes performed by
    ///   other processes: two identical requests performed by the `updates`
    ///   closure may not return the same value. Concurrent database accesses
    ///   can see partial updates performed by the `updates` closure.
    ///
    /// - parameter updates: A closure which accesses the database.
    /// - throws: The error thrown by `updates`.
    public func inDatabase<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try writer.sync(updates)
    }
    
    public func unsafeReentrantWrite<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try writer.reentrantSync(updates)
    }
    
    public func asyncWriteWithoutTransaction(_ updates: @escaping (Database) -> Void) {
        writer.async(updates)
    }
}
