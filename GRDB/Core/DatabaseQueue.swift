import Foundation

#if os(iOS)
import UIKit
#endif

/// A DatabaseQueue serializes access to an SQLite database.
public final class DatabaseQueue: DatabaseWriter {
    private let writer: SerializedDatabase
    
    // MARK: - Configuration
    
    /// The database configuration
    public var configuration: Configuration {
        writer.configuration
    }
    
    /// The path to the database file; it is ":memory:" for in-memory databases.
    public var path: String {
        writer.path
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
            defaultLabel: "GRDB.DatabaseQueue")
        
        setupSuspension()
        
        // Be a nice iOS citizen, and don't consume too much memory
        // See https://github.com/groue/GRDB.swift/#memory-management
        #if os(iOS)
        setupMemoryManagement()
        #endif
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
            defaultLabel: "GRDB.DatabaseQueue")
    }
    
    deinit {
        // Undo job done in setupMemoryManagement()
        //
        // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11Error
        // Explicit unregistration is required before OS X 10.11.
        NotificationCenter.default.removeObserver(self)
    }
    
    public func close() throws {
        try writer.sync { try $0.close() }
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
        
        // Use raw notification names because of
        // FB9801372 (UIApplication.didReceiveMemoryWarningNotification should not be declared @MainActor)
        // TODO: Reuse UIApplication.didReceiveMemoryWarningNotification when possible.
        // TODO: Reuse UIApplication.didEnterBackgroundNotification when possible.
        center.addObserver(
            self,
            selector: #selector(DatabaseQueue.applicationDidReceiveMemoryWarning(_:)),
            name: NSNotification.Name(rawValue: "UIApplicationDidReceiveMemoryWarningNotification"),
            object: nil)
        center.addObserver(
            self,
            selector: #selector(DatabaseQueue.applicationDidEnterBackground(_:)),
            name: NSNotification.Name(rawValue: "UIApplicationDidEnterBackgroundNotification"),
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

extension DatabaseQueue {
    
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
            do {
                // The transaction guarantees snapshot isolation against eventual
                // external connection.
                try db.beginTransaction(.deferred)
                try db.beginReadOnly()
            } catch {
                value(.failure(error))
                return
            }
            
            value(.success(db))
            
            // Ignore error because we can not notify it.
            try? db.endReadOnly()
            try? db.commit()
        }
    }
    
    /// :nodoc:
    public func _weakAsyncRead(_ value: @escaping (Result<Database, Error>?) -> Void) {
        writer.weakAsync { db in
            guard let db = db else {
                value(nil)
                return
            }
            
            do {
                // The transaction guarantees snapshot isolation against eventual
                // external connection.
                try db.beginTransaction(.deferred)
                try db.beginReadOnly()
            } catch {
                value(.failure(error))
                return
            }
            
            value(.success(db))
            
            // Ignore error because we can not notify it.
            try? db.endReadOnly()
            try? db.commit()
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
    
    /// Performs the same job as asyncConcurrentRead.
    ///
    /// :nodoc:
    public func spawnConcurrentRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        // Check that we're on the writer queue...
        writer.execute { db in
            // ... and that no transaction is opened.
            GRDBPrecondition(!db.isInsideTransaction, "must not be called from inside a transaction.")
            
            do {
                try db.beginTransaction(.deferred)
                try db.beginReadOnly()
            } catch {
                value(.failure(error))
                return
            }
            
            value(.success(db))
            
            // Ignore error because we can not notify it.
            try? db.endReadOnly()
            try? db.commit()
        }
    }
    
    // MARK: - Writing in Database
    
    /// Synchronously executes database updates in a protected dispatch queue,
    /// wrapped inside a transaction, and returns the result.
    ///
    /// If the updates throws an error, the transaction is rollbacked and the
    /// error is rethrown. If the updates return .rollback, the transaction is
    /// also rollbacked, but no error is thrown.
    ///
    /// Eventual concurrent database accesses are postponed until the
    /// transaction has completed.
    ///
    /// This method is *not* reentrant.
    ///
    ///     try dbQueue.writeInTransaction { db in
    ///         db.execute(...)
    ///         return .commit
    ///     }
    ///
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is configuration.defaultTransactionKind, which itself
    ///       defaults to .deferred. See <https://www.sqlite.org/lang_transaction.html>
    ///       for more information.
    ///     - updates: The updates to the database.
    /// - throws: The error thrown by the updates, or by the
    ///   wrapping transaction.
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
    public func barrierWriteWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try writer.sync(updates)
    }
    
    public func asyncBarrierWriteWithoutTransaction(_ updates: @escaping (Database) -> Void) {
        writer.async(updates)
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
    /// This method is *not* reentrant.
    ///
    /// - parameter updates: The updates to the database.
    /// - throws: The error thrown by the updates.
    public func inDatabase<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try writer.sync(updates)
    }
    
    public func unsafeReentrantWrite<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try writer.reentrantSync(updates)
    }
    
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
        
        let observer = _addWriteOnly(
            observation: observation,
            scheduling: scheduler,
            onChange: onChange)
        return AnyDatabaseCancellable(cancel: observer.cancel)
    }
}
