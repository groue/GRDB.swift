import Dispatch

/// The protocol for all types that can update a database.
///
/// It is adopted by DatabaseQueue and DatabasePool.
///
/// The protocol comes with isolation guarantees that describe the behavior of
/// adopting types in a multithreaded application.
///
/// Types that adopt the protocol can in practice provide stronger guarantees.
/// For example, DatabaseQueue provides a stronger isolation level
/// than DatabasePool.
///
/// **Warning**: Isolation guarantees stand as long as there is no external
/// connection to the database. Should you have to cope with external
/// connections, protect yourself with transactions, and be ready to setup a
/// [busy handler](https://www.sqlite.org/c3ref/busy_handler.html).
public protocol DatabaseWriter: DatabaseReader {
    
    // MARK: - Writing in Database
    
    /// Synchronously executes database updates in a protected dispatch queue,
    /// wrapped inside a transaction, and returns the result.
    ///
    /// If the updates throw an error, the transaction is rollbacked and the
    /// error is rethrown.
    ///
    /// Eventual concurrent database updates are postponed until the transaction
    /// has completed.
    ///
    /// Eventual concurrent reads are guaranteed to not see any partial updates
    /// of the database until the transaction has completed.
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter updates: The updates to the database.
    /// - throws: The error thrown by the updates, or by the
    ///   wrapping transaction.
    func write<T>(_ updates: (Database) throws -> T) throws -> T
    
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
    func writeWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T
    
    /// Synchronously executes database updates in a protected dispatch queue,
    /// outside of any transaction, and returns the result.
    ///
    /// Updates are guaranteed an exclusive access to the database. They wait
    /// until all pending writes and reads are completed. They postpone all
    /// other writes and reads until they are completed.
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter updates: The updates to the database.
    /// - throws: The error thrown by the updates.
    func barrierWriteWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T
    
    /// Asynchronously executes database updates in a protected dispatch queue,
    /// wrapped inside a transaction.
    ///
    /// If the updates throw an error, the transaction is rollbacked.
    ///
    /// The *completion* closure is always called with the result of the
    /// database updates. Its arguments are a database connection and the
    /// result of the transaction. This result is a failure if the transaction
    /// could not be committed.
    ///
    /// Eventual concurrent database updates are postponed until the transaction
    /// and the *completion* closure have completed.
    ///
    /// Eventual concurrent reads are guaranteed to not see any partial updates
    /// of the database until the transaction has completed.
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter updates: The updates to the database.
    /// - parameter completion: A closure that is called with the eventual
    ///   transaction error.
    /// - throws: The error thrown by the updates, or by the wrapping transaction.
    func asyncWrite<T>(
        _ updates: @escaping (Database) throws -> T,
        completion: @escaping (Database, Result<T, Error>) -> Void)
    
    /// Asynchronously executes database updates in a protected dispatch queue,
    /// outside of any transaction.
    ///
    /// Eventual concurrent reads may see partial updates unless you wrap them
    /// in a transaction.
    func asyncWriteWithoutTransaction(_ updates: @escaping (Database) -> Void)
    
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
    func unsafeReentrantWrite<T>(_ updates: (Database) throws -> T) rethrows -> T
    
    // MARK: - Reading from Database
    
    /// Concurrently executes a read-only block in a protected dispatch queue.
    ///
    /// This method must be called from a writing dispatch queue, outside of any
    /// transaction. You'll get a fatal error otherwise.
    ///
    /// The *block* argument is guaranteed to see the database in the last
    /// committed state at the moment this method is called. Eventual concurrent
    /// database updates are *not visible* inside the block.
    ///
    /// To access the fetched results, you call the wait() method of the
    /// returned future, on any dispatch queue.
    ///
    /// In the example below, the number of players is fetched concurrently with
    /// the player insertion. Yet the future is guaranteed to return zero:
    ///
    ///     try writer.writeWithoutTransaction { db in
    ///         // Delete all players
    ///         try Player.deleteAll()
    ///
    ///         // Count players concurrently
    ///         let future = writer.concurrentRead { db in
    ///             return try Player.fetchCount()
    ///         }
    ///
    ///         // Insert a player
    ///         try Player(...).insert(db)
    ///
    ///         // Guaranteed to be zero
    ///         let count = try future.wait()
    ///     }
    func concurrentRead<T>(_ block: @escaping (Database) throws -> T) -> DatabaseFuture<T>
    
    // Exposed for RxGRDB and GRBCombine. Naming is not stabilized.
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Concurrently executes a read-only block in a protected dispatch queue.
    ///
    /// This method must be called from a writing dispatch queue, outside of any
    /// transaction. You'll get a fatal error otherwise.
    ///
    /// The *block* argument is guaranteed to see the database in the last
    /// committed state at the moment this method is called. Eventual concurrent
    /// database updates are *not visible* inside the block.
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
    /// :nodoc:
    func spawnConcurrentRead(_ block: @escaping (Result<Database, Error>) -> Void)
}

extension DatabaseWriter {
    
    /// Synchronously executes database updates in a protected dispatch queue,
    /// wrapped inside a transaction, and returns the result.
    ///
    /// If the updates throw an error, the transaction is rollbacked and the
    /// error is rethrown.
    ///
    /// Eventual concurrent database updates are postponed until the transaction
    /// has completed.
    ///
    /// Eventual concurrent reads are guaranteed to not see any partial updates
    /// of the database until the transaction has completed.
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter updates: The updates to the database.
    /// - throws: The error thrown by the updates, or by the
    ///   wrapping transaction.
    public func write<T>(_ updates: (Database) throws -> T) throws -> T {
        try writeWithoutTransaction { db in
            var result: T?
            try db.inTransaction {
                result = try updates(db)
                return .commit
            }
            return result!
        }
    }
    
    /// Asynchronously executes database updates in a protected dispatch queue,
    /// wrapped inside a transaction.
    ///
    /// If the updates throw an error, the transaction is rollbacked.
    ///
    /// The *completion* closure is always called with the result of the
    /// database updates. Its arguments are a database connection and the
    /// result of the transaction. This result is a failure if the transaction
    /// could not be committed. The completion closure is executed in a
    /// protected dispatch queue, outside of any transaction.
    ///
    /// Eventual concurrent database updates are postponed until the transaction
    /// and the *completion* closure have completed.
    ///
    /// Eventual concurrent reads are guaranteed to not see any partial updates
    /// of the database until the transaction has completed.
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter updates: The updates to the database.
    /// - parameter completion: A closure that is called with the eventual
    ///   transaction error.
    /// - throws: The error thrown by the updates, or by the wrapping transaction.
    public func asyncWrite<T>(
        _ updates: @escaping (Database) throws -> T,
        completion: @escaping (Database, Result<T, Error>) -> Void)
    {
        asyncWriteWithoutTransaction { db in
            do {
                var result: T?
                try db.inTransaction {
                    result = try updates(db)
                    return .commit
                }
                completion(db, .success(result!))
            } catch {
                completion(db, .failure(error))
            }
        }
    }
    
    // MARK: - Transaction Observers
    
    /// Add a transaction observer, so that it gets notified of
    /// database changes.
    ///
    /// To remove the observer, use `DatabaseReader.remove(transactionObserver:)`.
    ///
    /// - parameter transactionObserver: A transaction observer.
    /// - parameter extent: The duration of the observation. The default is
    ///   the observer lifetime (observation lasts until observer
    ///   is deallocated).
    public func add(
        transactionObserver: TransactionObserver,
        extent: Database.TransactionObservationExtent = .observerLifetime)
    {
        writeWithoutTransaction { $0.add(transactionObserver: transactionObserver, extent: extent) }
    }
    
    /// Default implementation for the DatabaseReader requirement.
    /// :nodoc:
    public func remove(transactionObserver: TransactionObserver) {
        unsafeReentrantWrite { $0.remove(transactionObserver: transactionObserver) }
    }
    
    // MARK: - Erasing the content of the database
    
    /// Erases the content of the database.
    ///
    /// - precondition: database is not accessed concurrently during the
    ///   execution of this method.
    public func erase() throws {
        try writeWithoutTransaction { try $0.erase() }
    }
    
    // MARK: - Claiming Disk Space
    
    /// Rebuilds the database file, repacking it into a minimal amount of
    /// disk space.
    ///
    /// See https://www.sqlite.org/lang_vacuum.html for more information.
    public func vacuum() throws {
        try writeWithoutTransaction { try $0.execute(sql: "VACUUM") }
    }
    
    // MARK: - Value Observation
    
    /// Default implementation for the DatabaseReader requirement.
    /// :nodoc:
    public func add<Reducer: _ValueReducer>(
        observation: ValueObservation<Reducer>,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
        -> TransactionObserver
    {
        // True if initial value must be sent to the onChange callback
        // before this method returns.
        let initialSync: Bool
        
        // The queue for other values. Nil for any queue.
        let notificationQueue: DispatchQueue?
        
        switch observation.scheduling {
        case .mainQueue:
            if DispatchQueue.isMain {
                // Use case: observation starts on the main queue and wants
                // a synchronous initial fetch. This helps avoiding flashes of
                // missing content.
                initialSync = true
                notificationQueue = DispatchQueue.main
            } else {
                // TODO: make this a fatal error when .mainQueue is no longer
                // the default scheduling.
                // Use case: observation does not start on the main queue, but
                // has the default scheduling .mainQueue
                initialSync = false
                notificationQueue = DispatchQueue.main
            }
            
        case let .async(onQueue: queue):
            // Use case: observation must not block the target queue
            initialSync = false
            notificationQueue = queue
            
        case .unsafe:
            // Use case: third-party integration (RxSwift, Combine, ...) that
            // need a synchronous initial fetch.
            //
            // This is really super extra unsafe.
            //
            // If the observation is started on one dispatch queue, then
            // the onChange and onError callbacks must be asynchronously
            // dispatched on the *same* queue.
            //
            // A failure to follow this rule may mess with the ordering of
            // initial values.
            initialSync = true
            notificationQueue = nil
        }
        
        // ---
        
        let observer = ValueObserver<Reducer>(
            requiresWriteAccess: observation.requiresWriteAccess,
            observesSelectedRegion: observation.observesSelectedRegion,
            writer: self,
            reducer: observation.makeReducer(),
            notificationQueue: notificationQueue,
            reduceQueue: configuration.makeDispatchQueue(defaultLabel: "GRDB", purpose: "ValueObservation.reducer"),
            onError: onError,
            onChange: onChange)
        
        if initialSync {
            do {
                // TODO: make initialValue non-optional when compactMap is removed.
                let initialValue: Reducer.Value? = try unsafeReentrantWrite { db in
                    observer.baseRegion = try observation.baseRegion(db).ignoringViews(db)
                    let initialValue = try observer.fetchInitialValue(db)
                    db.add(transactionObserver: observer, extent: .observerLifetime)
                    return initialValue
                }
                if let initialValue = initialValue {
                    onChange(initialValue)
                }
            } catch {
                onError(error)
            }
        } else if let queue = notificationQueue {
            asyncWriteWithoutTransaction { db in
                do {
                    observer.baseRegion = try observation.baseRegion(db).ignoringViews(db)
                    if let value = try observer.fetchInitialValue(db) {
                        queue.async {
                            onChange(value)
                        }
                    }
                    db.add(transactionObserver: observer, extent: .observerLifetime)
                } catch {
                    queue.async {
                        onError(error)
                    }
                }
            }
        } else {
            asyncWriteWithoutTransaction { db in
                do {
                    observer.baseRegion = try observation.baseRegion(db).ignoringViews(db)
                    if let value = try observer.fetchInitialValue(db) {
                        onChange(value)
                    }
                    db.add(transactionObserver: observer, extent: .observerLifetime)
                } catch {
                    onError(error)
                }
            }
        }
        
        // TODO
        //
        // We promise that observation stops when the returned observer is
        // deallocated. But the real observer may have not started observing
        // the database, because some observations start asynchronously.
        // Well... This forces us to return a "token" that cancels any
        // observation started asynchronously.
        //
        // We'll eventually return a proper Cancellable. In GRDB 5?
        return ValueObserverToken(writer: self, observer: observer)
    }
}

/// A future database value, returned by the DatabaseWriter.concurrentRead(_:)
/// method.
///
///     let futureCount: Future<Int> = try writer.writeWithoutTransaction { db in
///         try Player(...).insert()
///
///         // Count players concurrently
///         return writer.concurrentRead { db in
///             return try Player.fetchCount()
///         }
///     }
///
///     let count: Int = try futureCount.wait()
public class DatabaseFuture<Value> {
    private var consumed = false
    private let _wait: () throws -> Value
    
    init(_ wait: @escaping () throws -> Value) {
        _wait = wait
    }
    
    init(_ result: Result<Value, Error>) {
        _wait = result.get
    }
    
    /// Blocks the current thread until the value is available, and returns it.
    ///
    /// It is a programmer error to call this method several times.
    ///
    /// - throws: Any error that prevented the value from becoming available.
    public func wait() throws -> Value {
        // Not thread-safe and quick and dirty.
        // Goal is that users learn not to call this method twice.
        GRDBPrecondition(consumed == false, "DatabaseFuture.wait() must be called only once")
        consumed = true
        return try _wait()
    }
}

/// A type-erased DatabaseWriter
///
/// Instances of AnyDatabaseWriter forward their methods to an arbitrary
/// underlying database writer.
public final class AnyDatabaseWriter: DatabaseWriter {
    private let base: DatabaseWriter
    
    /// Creates a database writer that wraps a base database writer.
    public init(_ base: DatabaseWriter) {
        self.base = base
    }
    
    /// :nodoc:
    public var configuration: Configuration {
        base.configuration
    }
    
    // MARK: - Interrupting Database Operations
    
    /// :nodoc:
    public func interrupt() {
        base.interrupt()
    }
    
    // MARK: - Reading from Database
    
    /// :nodoc:
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        try base.read(block)
    }
    
    /// :nodoc:
    public func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        base.asyncRead(block)
    }
    
    /// :nodoc:
    public func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T {
        try base.unsafeRead(block)
    }
    
    /// :nodoc:
    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        try base.unsafeReentrantRead(block)
    }
    
    /// :nodoc:
    public func concurrentRead<T>(_ block: @escaping (Database) throws -> T) -> DatabaseFuture<T> {
        base.concurrentRead(block)
    }
    
    /// :nodoc:
    public func spawnConcurrentRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        base.spawnConcurrentRead(block)
    }
    
    // MARK: - Writing in Database
    
    /// :nodoc:
    public func write<T>(_ updates: (Database) throws -> T) throws -> T {
        try base.write(updates)
    }
    
    /// :nodoc:
    public func writeWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try base.writeWithoutTransaction(updates)
    }
    
    /// :nodoc:
    public func barrierWriteWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try base.barrierWriteWithoutTransaction(updates)
    }
    
    /// :nodoc:
    public func asyncWrite<T>(
        _ updates: @escaping (Database) throws -> T,
        completion: @escaping (Database, Result<T, Error>) -> Void)
    {
        base.asyncWrite(updates, completion: completion)
    }
    
    /// :nodoc:
    public func asyncWriteWithoutTransaction(_ updates: @escaping (Database) -> Void) {
        base.asyncWriteWithoutTransaction(updates)
    }
    
    /// :nodoc:
    public func unsafeReentrantWrite<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try base.unsafeReentrantWrite(updates)
    }
    
    // MARK: - Functions
    
    /// :nodoc:
    public func add(function: DatabaseFunction) {
        base.add(function: function)
    }
    
    /// :nodoc:
    public func remove(function: DatabaseFunction) {
        base.remove(function: function)
    }
    
    // MARK: - Collations
    
    /// :nodoc:
    public func add(collation: DatabaseCollation) {
        base.add(collation: collation)
    }
    
    /// :nodoc:
    public func remove(collation: DatabaseCollation) {
        base.remove(collation: collation)
    }
}
