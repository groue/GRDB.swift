#if canImport(Combine)
import Combine
#endif
import Dispatch

/// `DatabaseWriter` is the protocol for all types that can write into an
/// SQLite database.
///
/// It is adopted by `DatabaseQueue` and `DatabasePool`.
///
/// The protocol comes with isolation guarantees that describe the behavior of
/// adopting types in a multithreaded application.
///
/// Types that adopt the protocol can in practice provide stronger guarantees.
/// For example, `DatabaseQueue` provides a stronger isolation level
/// than `DatabasePool`.
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
    /// outside of any transaction, and returns the result.
    ///
    /// Updates are guaranteed an exclusive access to the database. They wait
    /// until all pending writes and reads are completed. They postpone all
    /// other writes and reads until they are completed.
    ///
    /// - parameter updates: The updates to the database.
    func asyncBarrierWriteWithoutTransaction(_ updates: @escaping (Database) -> Void)
    
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
    
    /// Asynchronously executes database updates in a protected dispatch queue,
    /// outside of any transaction, without retaining self.
    ///
    /// :nodoc:
    func _weakAsyncWriteWithoutTransaction(_ updates: @escaping (Database?) -> Void)
    
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
    
    public func remove(transactionObserver: TransactionObserver) {
        _weakAsyncWriteWithoutTransaction {
            $0?.remove(transactionObserver: transactionObserver)
        }
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
    
    // MARK: - Database Observation
    
    /// A write-only observation only uses the serialized writer
    func _addWriteOnly<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> ValueObserver<Reducer> // For testability
    {
        assert(!configuration.readonly, "Use _addReadOnly(observation:) instead")
        
        let reduceQueueLabel = configuration.identifier(
            defaultLabel: "GRDB",
            purpose: "ValueObservation")
        let observer = ValueObserver(
            observation: observation,
            writer: self,
            scheduler: scheduler,
            reduceQueue: configuration.makeDispatchQueue(label: reduceQueueLabel),
            onChange: onChange)
        
        if scheduler.immediateInitialValue() {
            do {
                let initialValue: Reducer.Value = try unsafeReentrantWrite { db in
                    let initialValue = try observer.fetchInitialValue(db)
                    db.add(transactionObserver: observer, extent: .observerLifetime)
                    return initialValue
                }
                onChange(initialValue)
            } catch {
                observer.complete()
                observation.events.didFail?(error)
            }
        } else {
            _weakAsyncWriteWithoutTransaction { db in
                guard let db = db else { return }
                if observer.isCompleted { return }
                do {
                    let initialValue = try observer.fetchInitialValue(db)
                    observer.notifyChange(initialValue)
                    db.add(transactionObserver: observer, extent: .observerLifetime)
                } catch {
                    observer.notifyErrorAndComplete(error)
                }
            }
        }
        
        return observer
    }
}

#if canImport(Combine)
extension DatabaseWriter {
    // MARK: - Publishing Database Updates
    
    /// Returns a Publisher that asynchronously writes into the database.
    ///
    ///     // DatabasePublishers.Write<Int>
    ///     let newPlayerCount = dbQueue.writePublisher { db -> Int in
    ///         try Player(...).insert(db)
    ///         return try Player.fetchCount(db)
    ///     }
    ///
    /// Its value and completion are emitted on the main dispatch queue.
    ///
    /// - parameter updates: A closure which writes in the database.
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func writePublisher<Output>(
        updates: @escaping (Database) throws -> Output)
    -> DatabasePublishers.Write<Output>
    {
        writePublisher(receiveOn: DispatchQueue.main, updates: updates)
    }
    
    /// Returns a Publisher that asynchronously writes into the database.
    ///
    ///     // DatabasePublishers.Write<Int>
    ///     let newPlayerCount = dbQueue.writePublisher(
    ///         receiveOn: DispatchQueue.global(),
    ///         updates: { db -> Int in
    ///             try Player(...).insert(db)
    ///             return try Player.fetchCount(db)
    ///         })
    ///
    /// Its value and completion are emitted on `scheduler`.
    ///
    /// - parameter scheduler: A Combine Scheduler.
    /// - parameter updates: A closure which writes in the database.
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func writePublisher<S, Output>(
        receiveOn scheduler: S,
        updates: @escaping (Database) throws -> Output)
    -> DatabasePublishers.Write<Output>
    where S: Scheduler
    {
        OnDemandFuture({ fulfill in
            self.asyncWrite(updates, completion: { _, result in
                fulfill(result)
            })
        })
        // We don't want users to process emitted values on a
        // database dispatch queue.
        .receiveValues(on: scheduler)
        .eraseToWritePublisher()
    }
    
    /// Returns a Publisher that asynchronously writes into the database.
    ///
    ///     // DatabasePublishers.Write<Int>
    ///     let newPlayerCount = dbQueue.writePublisher(
    ///         updates: { db in try Player(...).insert(db) }
    ///         thenRead: { db, _ in try Player.fetchCount(db) })
    ///
    /// Its value and completion are emitted on the main dispatch queue.
    ///
    /// - parameter updates: A closure which writes in the database.
    /// - parameter value: A closure which reads from the database.
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func writePublisher<T, Output>(
        updates: @escaping (Database) throws -> T,
        thenRead value: @escaping (Database, T) throws -> Output)
    -> DatabasePublishers.Write<Output>
    {
        writePublisher(receiveOn: DispatchQueue.main, updates: updates, thenRead: value)
    }
    
    
    /// Returns a Publisher that asynchronously writes into the database.
    ///
    ///     // DatabasePublishers.Write<Int>
    ///     let newPlayerCount = dbQueue.writePublisher(
    ///         receiveOn: DispatchQueue.global(),
    ///         updates: { db in try Player(...).insert(db) }
    ///         thenRead: { db, _ in try Player.fetchCount(db) })
    ///
    /// Its value and completion are emitted on `scheduler`.
    ///
    /// - parameter scheduler: A Combine Scheduler.
    /// - parameter updates: A closure which writes in the database.
    /// - parameter value: A closure which reads from the database.
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func writePublisher<S, T, Output>(
        receiveOn scheduler: S,
        updates: @escaping (Database) throws -> T,
        thenRead value: @escaping (Database, T) throws -> Output)
    -> DatabasePublishers.Write<Output>
    where S: Scheduler
    {
        OnDemandFuture({ fulfill in
            self.asyncWriteWithoutTransaction { db in
                var updatesValue: T?
                do {
                    try db.inTransaction {
                        updatesValue = try updates(db)
                        return .commit
                    }
                } catch {
                    fulfill(.failure(error))
                    return
                }
                self.spawnConcurrentRead { dbResult in
                    fulfill(dbResult.flatMap { db in Result { try value(db, updatesValue!) } })
                }
            }
        })
        // We don't want users to process emitted values on a
        // database dispatch queue.
        .receiveValues(on: scheduler)
        .eraseToWritePublisher()
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DatabasePublishers {
    /// A publisher that writes into the database. It publishes exactly
    /// one element, or an error.
    ///
    /// See:
    ///
    /// - `DatabaseWriter.writePublisher(updates:)`.
    /// - `DatabaseWriter.writePublisher(updates:thenRead:)`.
    /// - `DatabaseWriter.writePublisher(receiveOn:updates:)`.
    /// - `DatabaseWriter.writePublisher(receiveOn:updates:thenRead:)`.
    public struct Write<Output>: Publisher {
        public typealias Output = Output
        public typealias Failure = Error
        
        fileprivate let upstream: AnyPublisher<Output, Error>
        
        public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
            upstream.receive(subscriber: subscriber)
        }
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Publisher where Failure == Error {
    fileprivate func eraseToWritePublisher() -> DatabasePublishers.Write<Output> {
        .init(upstream: eraseToAnyPublisher())
    }
}
#endif

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
    
    public var configuration: Configuration {
        base.configuration
    }
    
    // MARK: - Interrupting Database Operations
    
    public func interrupt() {
        base.interrupt()
    }
    
    // MARK: - Reading from Database
    
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        try base.read(block)
    }
    
    public func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        base.asyncRead(block)
    }
    
    /// :nodoc:
    public func _weakAsyncRead(_ block: @escaping (Result<Database, Error>?) -> Void) {
        base._weakAsyncRead(block)
    }
    
    public func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T {
        try base.unsafeRead(block)
    }
    
    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        try base.unsafeReentrantRead(block)
    }
    
    public func concurrentRead<T>(_ block: @escaping (Database) throws -> T) -> DatabaseFuture<T> {
        base.concurrentRead(block)
    }
    
    /// :nodoc:
    public func spawnConcurrentRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        base.spawnConcurrentRead(block)
    }
    
    // MARK: - Writing in Database
    
    public func write<T>(_ updates: (Database) throws -> T) throws -> T {
        try base.write(updates)
    }
    
    public func writeWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try base.writeWithoutTransaction(updates)
    }
    
    public func barrierWriteWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try base.barrierWriteWithoutTransaction(updates)
    }
    
    public func asyncBarrierWriteWithoutTransaction(_ updates: @escaping (Database) -> Void) {
        base.asyncBarrierWriteWithoutTransaction(updates)
    }
    
    public func asyncWrite<T>(
        _ updates: @escaping (Database) throws -> T,
        completion: @escaping (Database, Result<T, Error>) -> Void)
    {
        base.asyncWrite(updates, completion: completion)
    }
    
    public func asyncWriteWithoutTransaction(_ updates: @escaping (Database) -> Void) {
        base.asyncWriteWithoutTransaction(updates)
    }
    
    /// :nodoc:
    public func _weakAsyncWriteWithoutTransaction(_ updates: @escaping (Database?) -> Void) {
        base._weakAsyncWriteWithoutTransaction(updates)
    }
    
    public func unsafeReentrantWrite<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try base.unsafeReentrantWrite(updates)
    }
    
    // MARK: - Database Observation
    
    /// :nodoc:
    public func _add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> DatabaseCancellable
    {
        base._add(
            observation: observation,
            scheduling: scheduler,
            onChange: onChange)
    }
}
