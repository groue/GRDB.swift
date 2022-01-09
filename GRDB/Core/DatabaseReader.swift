#if canImport(Combine)
import Combine
#endif
import Dispatch

/// `DatabaseReader` is the protocol for all types that can fetch values from
/// an SQLite database.
///
/// It is adopted by `DatabaseQueue`, `DatabasePool`, and `DatabaseSnapshot`.
///
/// The protocol comes with isolation guarantees that describe the behavior of
/// adopting types in a multithreaded application.
///
/// Types that adopt the protocol can provide in practice stronger guarantees.
/// For example, `DatabaseQueue` provides a stronger isolation level
/// than `DatabasePool`.
///
/// **Warning**: Isolation guarantees stand as long as there is no external
/// connection to the database. Should you have to cope with external
/// connections, protect yourself with transactions, and be ready to setup a
/// [busy handler](https://www.sqlite.org/c3ref/busy_handler.html).
public protocol DatabaseReader: AnyObject, GRDBSendable {
    
    /// The database configuration
    var configuration: Configuration { get }
    
    /// Closes the database connection with the `sqlite3_close()` function.
    ///
    /// **Note**: You DO NOT HAVE to call this method, and you SHOULD NOT call
    /// it unless the correct execution of your program depends on precise
    /// database closing. Database connections are automatically closed when
    /// they are deinitialized, and this is sufficient for most applications.
    ///
    /// If this method does not throw, then the database is properly closed, and
    /// every future database access will throw a `DatabaseError` of
    /// code `SQLITE_MISUSE`.
    ///
    /// Otherwise, there exists concurrent database accesses or living prepared
    /// statements that prevent the database from closing, and this method
    /// throws a `DatabaseError` of code `SQLITE_BUSY`.
    /// See <https://www.sqlite.org/c3ref/close.html> for more information.
    ///
    /// After an error has been thrown, the database may still be opened, and
    /// you can keep on accessing it. It may also remain in a "zombie" state,
    /// in which case it will throw `SQLITE_MISUSE` for all future
    /// database accesses.
    func close() throws
    
    // MARK: - Interrupting Database Operations
    
    /// This method causes any pending database operation to abort and return at
    /// its earliest opportunity.
    ///
    /// It can be called from any thread.
    ///
    /// A call to `interrupt()` that occurs when there are no running SQL
    /// statements is a no-op and has no effect on SQL statements that are
    /// started after `interrupt()` returns.
    ///
    /// A database operation that is interrupted will throw a DatabaseError with
    /// code SQLITE_INTERRUPT. If the interrupted SQL operation is an INSERT,
    /// UPDATE, or DELETE that is inside an explicit transaction, then the
    /// entire transaction will be rolled back automatically. If the rolled back
    /// transaction was started by a transaction-wrapping method such as
    /// `DatabaseWriter.write` or `Database.inTransaction`, then all database
    /// accesses will throw a DatabaseError with code SQLITE_ABORT until the
    /// wrapping method returns.
    ///
    /// For example:
    ///
    ///     try dbQueue.write { db in
    ///         // interrupted:
    ///         try Player(...).insert(db)     // throws SQLITE_INTERRUPT
    ///         // not executed:
    ///         try Player(...).insert(db)
    ///     }                                  // throws SQLITE_INTERRUPT
    ///
    ///     try dbQueue.write { db in
    ///         do {
    ///             // interrupted:
    ///             try Player(...).insert(db) // throws SQLITE_INTERRUPT
    ///         } catch { }
    ///         try Player(...).insert(db)     // throws SQLITE_ABORT
    ///     }                                  // throws SQLITE_ABORT
    ///
    ///     try dbQueue.write { db in
    ///         do {
    ///             // interrupted:
    ///             try Player(...).insert(db) // throws SQLITE_INTERRUPT
    ///         } catch { }
    ///     }                                  // throws SQLITE_ABORT
    ///
    /// When an application creates transaction without a transaction-wrapping
    /// method, no SQLITE_ABORT error warns of aborted transactions:
    ///
    ///     try dbQueue.inDatabase { db in // or dbPool.writeWithoutTransaction
    ///         try db.beginTransaction()
    ///         do {
    ///             // interrupted:
    ///             try Player(...).insert(db) // throws SQLITE_INTERRUPT
    ///         } catch { }
    ///         try Player(...).insert(db)     // success
    ///         try db.commit()                // throws SQLITE_ERROR "cannot commit - no transaction is active"
    ///     }
    ///
    /// Both SQLITE_ABORT and SQLITE_INTERRUPT errors can be checked with the
    /// `DatabaseError.isInterruptionError` property.
    func interrupt()
    
    // MARK: - Read From Database
    
    /// Synchronously executes a read-only function that accepts a database
    /// connection, and returns its result.
    ///
    /// For example:
    ///
    ///     let count = try reader.read { db in
    ///         try Player.fetchCount(db)
    ///     }
    ///
    /// The `value` function runs in an isolated fashion: eventual concurrent
    /// database updates are not visible from the function:
    ///
    ///     try reader.read { db in
    ///         // Those two values are guaranteed to be equal, even if the
    ///         // `player` table is modified, between the two requests, by
    ///         // some other database connection or some other thread.
    ///         let count1 = try Player.fetchCount(db)
    ///         let count2 = try Player.fetchCount(db)
    ///     }
    ///
    ///     try reader.read { db in
    ///         // Now this value may be different:
    ///         let count = try Player.fetchCount(db)
    ///     }
    ///
    /// Attempts to write in the database throw a DatabaseError with
    /// resultCode `SQLITE_READONLY`.
    ///
    /// It is a programmer error to call this method from another database
    /// access method:
    ///
    ///     try reader.read { db in
    ///         // Raises a fatal error
    ///         try reader.read { ... )
    ///     }
    ///
    /// - parameter value: A function that accesses the database.
    /// - throws: The error thrown by `value`, or any `DatabaseError` that would
    ///   happen while establishing the read access to the database.
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    func read<T>(_ value: (Database) throws -> T) throws -> T
    
    /// Asynchronously executes a read-only function that accepts a
    /// database connection.
    ///
    /// The `value` function runs in an isolated fashion: eventual concurrent
    /// database updates are not visible from the function:
    ///
    ///     reader.asyncRead { dbResult in
    ///         do {
    ///             let db = try dbResult.get()
    ///             // Those two values are guaranteed to be equal, even if the
    ///             // `player` table is modified, between the two requests, by
    ///             // some other database connection or some other thread.
    ///             let count1 = try Player.fetchCount(db)
    ///             let count2 = try Player.fetchCount(db)
    ///         } catch {
    ///             // handle error
    ///         }
    ///     }
    ///
    /// Attempts to write in the database throw a DatabaseError with
    /// resultCode `SQLITE_READONLY`.
    ///
    /// - parameter value: A function that accesses the database. Its argument
    ///   is a `Result` that provides the database connection, or the failure
    ///   that would prevent establishing the read access to the database.
    func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void)
    
    /// Same as asyncRead, but without retaining self
    ///
    /// :nodoc:
    func _weakAsyncRead(_ value: @escaping (Result<Database, Error>?) -> Void)
    
    /// Synchronously executes a function that accepts a database
    /// connection, and returns its result.
    ///
    /// For example:
    ///
    ///     let count = try reader.unsafeRead { db in
    ///         try Player.fetchCount(db)
    ///     }
    ///
    /// The guarantees of the `read` method are lifted:
    ///
    /// the `value` function is not isolated: eventual concurrent database
    /// updates are visible from the function:
    ///
    ///     try reader.unsafeRead { db in
    ///         // Those two values can be different, because some other
    ///         // database connection or some other thread may modify the
    ///         // database between the two requests.
    ///         let count1 = try Player.fetchCount(db)
    ///         let count2 = try Player.fetchCount(db)
    ///     }
    ///
    /// The `value` function is not prevented from writing (DatabaseQueue, in
    /// particular, will accept database modifications in `unsafeRead`).
    ///
    /// It is a programmer error to call this method from another database
    /// access method:
    ///
    ///     try reader.read { db in
    ///         // Raises a fatal error
    ///         try reader.unsafeRead { ... )
    ///     }
    ///
    /// - parameter value: A function that accesses the database.
    /// - throws: The error thrown by `value`, or any `DatabaseError` that would
    ///   happen while establishing the read access to the database.
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    func unsafeRead<T>(_ value: (Database) throws -> T) throws -> T
    
    /// Asynchronously executes a function that accepts a database connection.
    ///
    /// The guarantees of the `asyncRead` method are lifted:
    ///
    /// the `value` function is not isolated: eventual concurrent database
    /// updates are visible from the function:
    ///
    ///     reader.asyncUnsafeRead { dbResult in
    ///         do {
    ///             let db = try dbResult.get()
    ///             // Those two values can be different, because some other
    ///             // database connection or some other thread may modify the
    ///             // database between the two requests.
    ///             let count1 = try Player.fetchCount(db)
    ///             let count2 = try Player.fetchCount(db)
    ///         } catch {
    ///             // handle error
    ///         }
    ///     }
    ///
    /// The `value` function is not prevented from writing (DatabaseQueue, in
    /// particular, will accept database modifications in `asyncUnsafeRead`).
    ///
    /// - parameter value: A function that accesses the database. Its argument
    ///   is a `Result` that provides the database connection, or the failure
    ///   that would prevent establishing the read access to the database.
    func asyncUnsafeRead(_ value: @escaping (Result<Database, Error>) -> Void)
    
    /// Synchronously executes a function that accepts a database
    /// connection, and returns its result.
    ///
    /// The guarantees of the safe `read` method are lifted:
    ///
    /// the `value` function is not isolated: eventual concurrent database
    /// updates are visible from the function:
    ///
    ///     try reader.unsafeReentrantRead { db in
    ///         // Those two values can be different, because some other
    ///         // database connection or some other thread may modify the
    ///         // database between the two requests.
    ///         let count1 = try Player.fetchCount(db)
    ///         let count2 = try Player.fetchCount(db)
    ///     }
    ///
    /// The `value` function is not prevented from writing (DatabaseQueue, in
    /// particular, will accept database modifications in `unsafeRead`).
    ///
    /// This method is reentrant. It should be avoided because it fosters
    /// dangerous concurrency practices.
    ///
    /// - parameter value: A function that accesses the database.
    /// - throws: The error thrown by `value`, or any `DatabaseError` that would
    ///   happen while establishing the read access to the database.
    func unsafeReentrantRead<T>(_ value: (Database) throws -> T) throws -> T
    
    
    // MARK: - Value Observation
    
    /// Starts a value observation.
    ///
    /// You should use the `ValueObservation.start(in:onError:onChange:)`
    /// method instead.
    ///
    /// - parameter observation: the stared observation
    /// - returns: a TransactionObserver
    ///
    /// :nodoc:
    func _add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> DatabaseCancellable
}

extension DatabaseReader {
    
    // MARK: - Backup
    
    /// Copies the database contents into another database.
    ///
    /// The `backup` method blocks the current thread until the destination
    /// database contains the same contents as the source database.
    ///
    /// When the source is a DatabasePool, concurrent writes can happen during
    /// the backup. Those writes may, or may not, be reflected in the backup,
    /// but they won't trigger any error.
    ///
    /// Usage:
    ///
    ///     let source: DatabaseQueue = ...
    ///     let destination: DatabaseQueue = ...
    ///     try source.backup(to: destination)
    ///
    /// When you're after progress reporting during backup, you'll want to
    /// perform the backup in several steps. Each step copies the number of
    /// _database pages_ you specify. See <https://www.sqlite.org/c3ref/backup_finish.html>
    /// for more information:
    ///
    ///     // Backup with progress reporting
    ///     try source.backup(
    ///         to: destination,
    ///         pagesPerStep: ...)
    ///         { backupProgress in
    ///            print("Database backup progress:", backupProgress)
    ///         }
    ///
    /// The `progress` callback will be called at least once—when
    /// `backupProgress.isCompleted == true`. If the callback throws
    /// when `backupProgress.isCompleted == false`, the backup is aborted
    /// and the error is rethrown.  If the callback throws when
    /// `backupProgress.isCompleted == true`, backup completion is
    /// unaffected and the error is silently ignored.
    ///
    /// See also `Database.backup()`.
    ///
    /// - parameters:
    ///     - writer: The destination database.
    ///     - pagesPerStep: The number of database pages copied on each backup
    ///       step. By default, all pages are copied in one single step.
    ///     - progress: An optional function that is notified of the backup
    ///       progress.
    /// - throws: The error thrown by `progress` if the backup is abandoned, or
    ///   any `DatabaseError` that would happen while performing the backup.
    public func backup(
        to writer: DatabaseWriter,
        pagesPerStep: Int32 = -1,
        progress: ((DatabaseBackupProgress) throws -> Void)? = nil)
    throws
    {
        try writer.writeWithoutTransaction { destDb in
            try backup(
                to: destDb,
                pagesPerStep: pagesPerStep,
                afterBackupStep: progress)
        }
    }
    
    func backup(
        to destDb: Database,
        pagesPerStep: Int32 = -1,
        afterBackupInit: (() -> Void)? = nil,
        afterBackupStep: ((DatabaseBackupProgress) throws -> Void)? = nil)
    throws
    {
        try read { dbFrom in
            try dbFrom.backupInternal(
                to: destDb,
                pagesPerStep: pagesPerStep,
                afterBackupInit: afterBackupInit,
                afterBackupStep: afterBackupStep)
        }
    }
}

#if compiler(>=5.5.2) && canImport(_Concurrency)
extension DatabaseReader {
    // MARK: - Asynchronous Database Access
    
    // TODO: remove @escaping as soon as it is possible
    /// Asynchronously executes a read-only function that accepts a database
    /// connection, and returns its result.
    ///
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// For example:
    ///
    ///     let count = try await reader.read { db in
    ///         try Player.fetchCount(db)
    ///     }
    ///
    /// The `value` function runs in an isolated fashion: eventual concurrent
    /// database updates are not visible from the function:
    ///
    ///     try await reader.read { db in
    ///         // Those two values are guaranteed to be equal, even if the
    ///         // `player` table is modified, between the two requests, by
    ///         // some other database connection or some other thread.
    ///         let count1 = try Player.fetchCount(db)
    ///         let count2 = try Player.fetchCount(db)
    ///     }
    ///
    ///     try await reader.read { db in
    ///         // Now this value may be different:
    ///         let count = try Player.fetchCount(db)
    ///     }
    ///
    /// Attempts to write in the database throw a DatabaseError with
    /// resultCode `SQLITE_READONLY`.
    ///
    /// - parameter value: A function that accesses the database.
    /// - throws: The error thrown by `value`, or any `DatabaseError` that would
    ///   happen while establishing the read access to the database.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func read<T>(_ value: @Sendable @escaping (Database) throws -> T) async throws -> T {
        try await withUnsafeThrowingContinuation { continuation in
            asyncRead { result in
                do {
                    try continuation.resume(returning: value(result.get()))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // TODO: remove @escaping as soon as it is possible
    /// Asynchronously executes a function that accepts a database connection.
    ///
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// For example:
    ///
    ///     let count = try await reader.unsafeRead { db in
    ///         try Player.fetchCount(db)
    ///     }
    ///
    /// The guarantees of the `read` method are lifted:
    ///
    /// the `value` function is not isolated: eventual concurrent database
    /// updates are visible from the function:
    ///
    ///     try await reader.asyncRead { db in
    ///         // Those two values can be different, because some other
    ///         // database connection or some other thread may modify the
    ///         // database between the two requests.
    ///         let count1 = try Player.fetchCount(db)
    ///         let count2 = try Player.fetchCount(db)
    ///     }
    ///
    /// The `value` function is not prevented from writing (DatabaseQueue, in
    /// particular, will accept database modifications in `asyncUnsafeRead`).
    ///
    /// - parameter value: A function that accesses the database.
    /// - throws: The error thrown by `value`, or any `DatabaseError` that would
    ///   happen while establishing the read access to the database.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func unsafeRead<T>(_ value: @Sendable @escaping (Database) throws -> T) async throws -> T {
        try await withUnsafeThrowingContinuation { continuation in
            asyncUnsafeRead { result in
                do {
                    try continuation.resume(returning: value(result.get()))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
#endif

#if canImport(Combine)
extension DatabaseReader {
    // MARK: - Publishing Database Values
    
    /// Returns a Publisher that asynchronously completes with a fetched value.
    ///
    ///     // DatabasePublishers.Read<[Player]>
    ///     let players = dbQueue.readPublisher { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///
    /// Its value and completion are emitted on the main dispatch queue.
    ///
    /// - parameter value: A closure which accesses the database.
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func readPublisher<Output>(
        value: @escaping (Database) throws -> Output)
    -> DatabasePublishers.Read<Output>
    {
        readPublisher(receiveOn: DispatchQueue.main, value: value)
    }
    
    /// Returns a Publisher that asynchronously completes with a fetched value.
    ///
    ///     // DatabasePublishers.Read<[Player]>
    ///     let players = dbQueue.readPublisher(
    ///         receiveOn: DispatchQueue.global(),
    ///         value: { db in try Player.fetchAll(db) })
    ///
    /// Its value and completion are emitted on `scheduler`.
    ///
    /// - parameter scheduler: A Combine Scheduler.
    /// - parameter value: A closure which accesses the database.
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func readPublisher<S, Output>(
        receiveOn scheduler: S,
        value: @escaping (Database) throws -> Output)
    -> DatabasePublishers.Read<Output>
    where S: Scheduler
    {
        Deferred {
            Future { fulfill in
                self.asyncRead { dbResult in
                    fulfill(dbResult.flatMap { db in Result { try value(db) } })
                }
            }
        }
        .receiveValues(on: scheduler)
        .eraseToReadPublisher()
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DatabasePublishers {
    /// A publisher that reads a value from the database. It publishes exactly
    /// one element, or an error.
    ///
    /// See:
    ///
    /// - `DatabaseReader.readPublisher(receiveOn:value:)`.
    /// - `DatabaseReader.readPublisher(value:)`.
    public struct Read<Output>: Publisher {
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
    fileprivate func eraseToReadPublisher() -> DatabasePublishers.Read<Output> {
        .init(upstream: eraseToAnyPublisher())
    }
}
#endif

extension DatabaseReader {
    // MARK: - Value Observation Support
    
    /// Adding an observation in a read-only database emits only the
    /// initial value.
    func _addReadOnly<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> DatabaseCancellable
    {
        if scheduler.immediateInitialValue() {
            do {
                let value = try unsafeReentrantRead { db in
                    try db.isolated(readOnly: true) {
                        try observation.fetchValue(db)
                    }
                }
                onChange(value)
            } catch {
                observation.events.didFail?(error)
            }
            return AnyDatabaseCancellable(cancel: { })
        } else {
            var isCancelled = false
            _weakAsyncRead { dbResult in
                guard !isCancelled,
                      let dbResult = dbResult
                else { return }
                
                let result = dbResult.flatMap { db in
                    Result { try observation.fetchValue(db) }
                }
                
                scheduler.schedule {
                    guard !isCancelled else { return }
                    do {
                        try onChange(result.get())
                    } catch {
                        observation.events.didFail?(error)
                    }
                }
            }
            return AnyDatabaseCancellable(cancel: { isCancelled = true })
        }
    }
}

/// A type-erased DatabaseReader
///
/// Instances of AnyDatabaseReader forward their methods to an arbitrary
/// underlying database reader.
public final class AnyDatabaseReader: DatabaseReader {
    private let base: DatabaseReader
    
    /// Creates a database reader that wraps a base database reader.
    public init(_ base: DatabaseReader) {
        self.base = base
    }
    
    public var configuration: Configuration {
        base.configuration
    }
    
    public func close() throws {
        try base.close()
    }
    
    // MARK: - Interrupting Database Operations
    
    public func interrupt() {
        base.interrupt()
    }
    
    // MARK: - Reading from Database
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func read<T>(_ value: (Database) throws -> T) throws -> T {
        try base.read(value)
    }
    
    public func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        base.asyncRead(value)
    }
    
    /// :nodoc:
    public func _weakAsyncRead(_ value: @escaping (Result<Database, Error>?) -> Void) {
        base._weakAsyncRead(value)
    }
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func unsafeRead<T>(_ value: (Database) throws -> T) throws -> T {
        try base.unsafeRead(value)
    }
    
    public func asyncUnsafeRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        base.asyncUnsafeRead(value)
    }
    
    public func unsafeReentrantRead<T>(_ value: (Database) throws -> T) throws -> T {
        try base.unsafeReentrantRead(value)
    }
    
    // MARK: - Value Observation
    
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
