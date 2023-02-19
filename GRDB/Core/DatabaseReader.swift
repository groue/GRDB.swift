#if canImport(Combine)
import Combine
#endif
import Dispatch

/// A type that reads from an SQLite database.
///
/// Do not declare new conformances to `DatabaseReader`. Only the built-in
/// conforming types are valid.
///
/// The protocol comes with isolation guarantees that describe the behavior of
/// conforming types in a multithreaded application. See <doc:Concurrency> for
/// more information.
///
/// ## Topics
///
/// ### Database Information
///
/// - ``configuration``
///
/// ### Reading from the Database
///
/// - ``read(_:)-3806d``
/// - ``read(_:)-4w6gy``
/// - ``readPublisher(receiveOn:value:)``
/// - ``asyncRead(_:)``
///
/// ### Unsafe Methods
///
/// - ``unsafeRead(_:)-5i7tf``
/// - ``unsafeRead(_:)-11mk0``
/// - ``unsafeReentrantRead(_:)``
/// - ``asyncUnsafeRead(_:)``
///
/// ### Other Database Operations
///
/// - ``backup(to:pagesPerStep:progress:)``
/// - ``close()``
/// - ``interrupt()``
///
/// ### Supporting Types
///
/// - ``AnyDatabaseReader``
public protocol DatabaseReader: AnyObject, Sendable {
    
    /// The database configuration.
    var configuration: Configuration { get }
    
    /// Closes the database connection.
    ///
    /// - note: You do not have to call this method, and you should not call
    ///   it unless the correct execution of your program depends on precise
    ///   database closing. Database connections are automatically closed when
    ///   they are deinitialized, and this is sufficient for most applications.
    ///
    /// If this method does not throw, then the database is properly closed, and
    /// every future database access will throw a ``DatabaseError`` of
    /// code `SQLITE_MISUSE`.
    ///
    /// Otherwise, there exists concurrent database accesses or living prepared
    /// statements that prevent the database from closing, and this method
    /// throws a ``DatabaseError`` of code `SQLITE_BUSY`.
    /// See <https://www.sqlite.org/c3ref/close.html> for more information.
    ///
    /// After an error has been thrown, the database may still be opened, and
    /// you can keep on accessing it. It may also remain in a "zombie" state,
    /// in which case it will throw `SQLITE_MISUSE` for all future
    /// database accesses.
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    func close() throws
    
    // MARK: - Interrupting Database Operations
    
    /// Causes any pending database operation to abort and return at its
    /// earliest opportunity.
    ///
    /// This method can be called from any thread.
    ///
    /// A call to `interrupt()` that occurs when there are no running SQL
    /// statements is a no-op and has no effect on SQL statements that are
    /// started after `interrupt()` returns.
    ///
    /// A database operation that is interrupted will throw a ``DatabaseError``
    /// with code `SQLITE_INTERRUPT`. If the interrupted SQL operation is an
    /// `INSERT`, `UPDATE`, or `DELETE` that is inside an explicit transaction,
    /// then the entire transaction will be rolled back automatically. If the
    /// rolled back transaction was started by a transaction-wrapping method
    /// such as ``DatabaseWriter/write(_:)-76inz`` or
    /// ``Database/inTransaction(_:_:)``, then all database accesses will throw
    /// a ``DatabaseError`` with code `SQLITE_ABORT` until the wrapping
    /// method returns.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     // interrupted:
    ///     try Player(...).insert(db)     // throws SQLITE_INTERRUPT
    ///     // not executed:
    ///     try Player(...).insert(db)
    /// }                                  // throws SQLITE_INTERRUPT
    ///
    /// try dbQueue.write { db in
    ///     do {
    ///         // interrupted:
    ///         try Player(...).insert(db) // throws SQLITE_INTERRUPT
    ///     } catch { }
    ///     try Player(...).insert(db)     // throws SQLITE_ABORT
    /// }                                  // throws SQLITE_ABORT
    ///
    /// try dbQueue.write { db in
    ///     do {
    ///         // interrupted:
    ///         try Player(...).insert(db) // throws SQLITE_INTERRUPT
    ///     } catch { }
    /// }                                  // throws SQLITE_ABORT
    /// ```
    ///
    /// Beware: when an application opens a transaction without a
    /// transaction-wrapping method, no `SQLITE_ABORT` error warns of
    /// aborted transactions:
    ///
    /// ```swift
    /// try dbQueue.inDatabase { db in // or dbPool.writeWithoutTransaction
    ///     try db.beginTransaction()
    ///     do {
    ///         // interrupted:
    ///         try Player(...).insert(db) // throws SQLITE_INTERRUPT
    ///     } catch { }
    ///     try Player(...).insert(db)     // success
    ///     try db.commit()                // throws SQLITE_ERROR "cannot commit - no transaction is active"
    /// }
    /// ```
    ///
    /// Both `SQLITE_ABORT` and `SQLITE_INTERRUPT` errors can be checked with the
    /// ``DatabaseError/isInterruptionError`` property.
    func interrupt()
    
    // MARK: - Read From Database
    
    /// Executes read-only database operations, and returns their result after
    /// they have finished executing.
    ///
    /// For example:
    ///
    /// ```swift
    /// let count = try reader.read { db in
    ///     try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// Database operations are isolated in a transaction: they do not see
    /// changes performed by eventual concurrent writes (even writes performed
    /// by other processes).
    ///
    /// The database connection is read-only: attempts to write throw a
    /// ``DatabaseError`` with resultCode `SQLITE_READONLY`.
    ///
    /// The ``Database`` argument to `value` is valid only during the execution
    /// of the closure. Do not store or return the database connection for
    /// later use.
    ///
    /// It is a programmer error to call this method from another database
    /// access method. Doing so raises a "Database methods are not reentrant"
    /// fatal error at runtime.
    ///
    /// - parameter value: A closure which accesses the database.
    /// - throws: The error thrown by `value`, or any ``DatabaseError`` that
    ///   would happen while establishing the database access.
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    func read<T>(_ value: (Database) throws -> T) throws -> T
    
    /// Schedules read-only database operations for execution, and
    /// returns immediately.
    ///
    /// For example:
    ///
    /// ```swift
    /// try reader.asyncRead { dbResult in
    ///     do {
    ///         let db = try dbResult.get()
    ///         let count = try Player.fetchCount(db)
    ///     } catch {
    ///         // Handle error
    ///     }
    /// }
    /// ```
    ///
    /// Database operations are isolated in a transaction: they do not see
    /// changes performed by eventual concurrent writes (even writes performed
    /// by other processes).
    ///
    /// The database connection is read-only: attempts to write throw a
    /// ``DatabaseError`` with resultCode `SQLITE_READONLY`.
    ///
    /// - parameter value: A closure which accesses the database. Its argument
    ///   is a `Result` that provides the database connection, or the failure
    ///   that would prevent establishing the read access to the database.
    func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void)
    
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// This method is "unsafe" because the database reader does nothing more
    /// than providing a database connection. When you use this method, you
    /// become responsible for the thread-safety of your application, and
    /// responsible for database accesses performed by other processes. See
    /// <doc:Concurrency#Safe-and-Unsafe-Database-Accesses> for
    /// more information.
    ///
    /// For example:
    ///
    /// ```swift
    /// let count = try reader.unsafeRead { db in
    ///     try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// The ``Database`` argument to `value` is valid only during the execution
    /// of the closure. Do not store or return the database connection for
    /// later use.
    ///
    /// It is a programmer error to call this method from another database
    /// access method. Doing so raises a "Database methods are not reentrant"
    /// fatal error at runtime.
    ///
    /// - warning: Database operations may not be wrapped in a transaction. They
    ///   may see changes performed by concurrent writes or writes performed by
    ///   other processes: two identical requests performed by the `value`
    ///   closure may not return the same value.
    /// - warning: Attempts to write in the database may succeed.
    ///
    /// - parameter value: A closure which accesses the database.
    /// - throws: The error thrown by `value`, or any ``DatabaseError`` that
    ///   would happen while establishing the database access.
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    func unsafeRead<T>(_ value: (Database) throws -> T) throws -> T
    
    /// Schedules database operations for execution, and returns immediately.
    ///
    /// This method is "unsafe" because the database reader does nothing more
    /// than providing a database connection. When you use this method, you
    /// become responsible for the thread-safety of your application, and
    /// responsible for database accesses performed by other processes. See
    /// <doc:Concurrency#Safe-and-Unsafe-Database-Accesses> for
    /// more information.
    ///
    /// For example:
    ///
    /// ```swift
    /// reader.asyncUnsafeRead { dbResult in
    ///     do {
    ///         let db = try dbResult.get()
    ///         let count = try Player.fetchCount(db)
    ///     } catch {
    ///         // handle error
    ///     }
    /// }
    /// ```
    ///
    /// - warning: Database operations may not be wrapped in a transaction. They
    ///   may see changes performed by concurrent writes or writes performed by
    ///   other processes: two identical requests performed by the `value`
    ///   closure may not return the same value.
    /// - warning: Attempts to write in the database may succeed.
    ///
    /// - parameter value: A closure which accesses the database. Its argument
    ///   is a `Result` that provides the database connection, or the failure
    ///   that would prevent establishing the read access to the database.
    func asyncUnsafeRead(_ value: @escaping (Result<Database, Error>) -> Void)
    
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// This method is "unsafe" because the database reader does nothing more
    /// than providing a database connection. When you use this method, you
    /// become responsible for the thread-safety of your application, and
    /// responsible for database accesses performed by other processes. See
    /// <doc:Concurrency#Safe-and-Unsafe-Database-Accesses> for
    /// more information.
    ///
    /// This method can be called from other database access methods. If called
    /// from the dispatch queue of a current database access (read or write),
    /// the `Database` argument to `value` is the same as the current
    /// database access.
    ///
    /// Reentrant database accesses are discouraged because they muddle
    /// transaction boundaries
    /// (see <doc:Concurrency#Rule-2:-Mind-your-transactions> for
    /// more information).
    ///
    /// For example:
    ///
    /// ```swift
    /// let count = try reader.unsafeReentrantRead { db in
    ///     try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// The ``Database`` argument to `value` is valid only during the execution
    /// of the closure. Do not store or return the database connection for
    /// later use.
    ///
    /// - warning: Database operations may not be wrapped in a transaction. They
    ///   may see changes performed by concurrent writes or writes performed by
    ///   other processes: two identical requests performed by the `value`
    ///   closure may not return the same value.
    /// - warning: Attempts to write in the database may succeed.
    ///
    /// - parameter value: A closure which accesses the database.
    /// - throws: The error thrown by `value`, or any ``DatabaseError`` that
    ///   would happen while establishing the database access.
    func unsafeReentrantRead<T>(_ value: (Database) throws -> T) throws -> T
    
    
    // MARK: - Value Observation
    
    /// Starts a value observation.
    ///
    /// Use the ``ValueObservation/start(in:scheduling:onError:onChange:)``
    /// method instead.
    ///
    /// - parameter observation: a ValueObservation.
    /// - returns: A DatabaseCancellable that can stop the observation.
    func _add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: some ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> AnyDatabaseCancellable
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
    /// ```swift
    /// let source: DatabaseQueue = ...
    /// let destination: DatabaseQueue = ...
    /// try source.backup(to: destination)
    /// ```
    ///
    /// When you're after progress reporting during backup, you'll want to
    /// perform the backup in several steps. Each step copies the number of
    /// _database pages_ you specify. See <https://www.sqlite.org/c3ref/backup_finish.html>
    /// for more information:
    ///
    /// ```swift
    /// // Backup with progress reporting
    /// try source.backup(to: destination, pagesPerStep: ...) { progress in
    ///     print("Database backup progress:", progress)
    /// }
    /// ```
    ///
    /// The `progress` callback will be called at least once—when
    /// `backupProgress.isCompleted == true`. If the callback throws
    /// when `backupProgress.isCompleted == false`, the backup is aborted
    /// and the error is rethrown. If the callback throws when
    /// `backupProgress.isCompleted == true`, backup completion is
    /// unaffected and the error is silently ignored.
    ///
    /// See also ``Database/backup(to:pagesPerStep:progress:)``
    ///
    /// - parameters:
    ///     - writer: The destination database.
    ///     - pagesPerStep: The number of database pages copied on each backup
    ///       step. By default, all pages are copied in one single step.
    ///     - progress: An optional function that is notified of the backup
    ///       progress.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or the
    ///   error thrown by `progress`.
    public func backup(
        to writer: some DatabaseWriter,
        pagesPerStep: CInt = -1,
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
        pagesPerStep: CInt = -1,
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

extension DatabaseReader {
    // MARK: - Asynchronous Database Access
    
    /// Executes read-only database operations, and returns their result after
    /// they have finished executing.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// For example:
    ///
    /// ```swift
    /// let count = try await reader.read { db in
    ///     try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// Database operations are isolated in a transaction: they do not see
    /// changes performed by eventual concurrent writes (even writes performed
    /// by other processes).
    ///
    /// The database connection is read-only: attempts to write throw a
    /// ``DatabaseError`` with resultCode `SQLITE_READONLY`.
    ///
    /// The ``Database`` argument to `value` is valid only during the execution
    /// of the closure. Do not store or return the database connection for
    /// later use.
    ///
    /// - parameter value: A closure which accesses the database.
    /// - throws: The error thrown by `value`, or any ``DatabaseError`` that
    ///   would happen while establishing the database access.
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
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
    
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// This method is "unsafe" because the database reader does nothing more
    /// than providing a database connection. When you use this method, you
    /// become responsible for the thread-safety of your application, and
    /// responsible for database accesses performed by other processes. See
    /// <doc:Concurrency#Safe-and-Unsafe-Database-Accesses> for
    /// more information.
    ///
    /// For example:
    ///
    /// ```swift
    /// let count = try await reader.unsafeRead { db in
    ///     try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// The ``Database`` argument to `value` is valid only during the execution
    /// of the closure. Do not store or return the database connection for
    /// later use.
    ///
    /// - warning: Database operations may not be wrapped in a transaction. They
    ///   may see changes performed by concurrent writes or writes performed by
    ///   other processes: two identical requests performed by the `value`
    ///   closure may not return the same value.
    /// - warning: Attempts to write in the database may succeed.
    ///
    /// - parameter value: A closure which accesses the database.
    /// - throws: The error thrown by `value`, or any ``DatabaseError`` that
    ///   would happen while establishing the database access.
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
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

#if canImport(Combine)
extension DatabaseReader {
    // MARK: - Publishing Database Values
    
    /// Returns a publisher that publishes one value and completes.
    ///
    /// The database is not accessed until subscription. Value and completion
    /// are published on `scheduler` (the main dispatch queue by default).
    ///
    /// For example:
    ///
    /// ```swift
    /// // DatabasePublishers.Read<Int>
    /// let countPublisher = reader.readPublisher { db in
    ///     try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// Database operations are isolated in a transaction: they do not see
    /// changes performed by eventual concurrent writes (even writes performed
    /// by other processes).
    ///
    /// The database connection is read-only: attempts to write throw a
    /// ``DatabaseError`` with resultCode `SQLITE_READONLY`.
    ///
    /// The ``Database`` argument to `value` is valid only during the execution
    /// of the closure. Do not store or return the database connection for
    /// later use.
    ///
    /// - parameter scheduler: A Combine Scheduler.
    /// - parameter value: A closure which accesses the database.
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func readPublisher<Output>(
        receiveOn scheduler: some Combine.Scheduler = DispatchQueue.main,
        value: @escaping (Database) throws -> Output)
    -> DatabasePublishers.Read<Output>
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

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension DatabasePublishers {
    /// A publisher that reads from the database.
    ///
    /// `Read` publishes exactly one element, or an error.
    ///
    /// You build such a publisher from ``DatabaseReader``.
    public struct Read<Output>: Publisher {
        public typealias Output = Output
        public typealias Failure = Error
        
        fileprivate let upstream: AnyPublisher<Output, Error>
        
        public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
            upstream.receive(subscriber: subscriber)
        }
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
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
        scheduling scheduler: some ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> AnyDatabaseCancellable
    {
        if scheduler.immediateInitialValue() {
            do {
                // Perform a reentrant read, in case the observation would be
                // started from a database access.
                let value = try unsafeReentrantRead { db in
                    try db.isolated(readOnly: true) {
                        try observation.fetchInitialValue(db)
                    }
                }
                onChange(value)
            } catch {
                observation.events.didFail?(error)
            }
            return AnyDatabaseCancellable(cancel: { /* nothing to cancel */ })
        } else {
            var isCancelled = false
            asyncRead { dbResult in
                guard !isCancelled else { return }
                
                let result = dbResult.flatMap { db in
                    Result { try observation.fetchInitialValue(db) }
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

/// A type-erased database reader.
///
/// An instance of `AnyDatabaseReader` forwards its operations to an underlying
/// base database reader.
public final class AnyDatabaseReader {
    private let base: any DatabaseReader
    
    /// Creates a new database reader that wraps and forwards operations
    /// to `base`.
    public init(_ base: some DatabaseReader) {
        self.base = base
    }
}

extension AnyDatabaseReader: DatabaseReader {
    public var configuration: Configuration {
        base.configuration
    }
    
    public func close() throws {
        try base.close()
    }
    
    public func interrupt() {
        base.interrupt()
    }
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func read<T>(_ value: (Database) throws -> T) throws -> T {
        try base.read(value)
    }
    
    public func asyncRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        base.asyncRead(value)
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
    
    public func _add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: some ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> AnyDatabaseCancellable
    {
        base._add(
            observation: observation,
            scheduling: scheduler,
            onChange: onChange)
    }
}

/// A type that sees an unchanging database content.
///
/// Do not declare new conformances to `DatabaseSnapshotReader`. Only the
/// built-in conforming types are valid.
///
/// The protocol comes with the same features and guarantees as
/// ``DatabaseReader``. On top of them, a `DatabaseSnapshotReader` always sees
/// the same state of the database.
///
/// ## Topics
///
/// ### Reading from the Database
///
/// - ``reentrantRead(_:)``
public protocol DatabaseSnapshotReader: DatabaseReader { }

extension DatabaseSnapshotReader {
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// This method can be called from other database access methods. If called
    /// from the dispatch queue of a current database access, the `Database`
    /// argument to `value` is the same as the current database access.
    ///
    /// For example:
    ///
    /// ```swift
    /// let count = try snapshot.reentrantRead { db in
    ///     try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// The ``Database`` argument to `value` is valid only during the execution
    /// of the closure. Do not store or return the database connection for
    /// later use.
    ///
    /// - parameter value: A closure which accesses the database.
    /// - throws: The error thrown by `value`, or any ``DatabaseError`` that
    ///   would happen while establishing the database access.
    public func reentrantRead<T>(_ value: (Database) throws -> T) throws -> T {
        // Reentrant reads are safe in a snapshot
        try unsafeReentrantRead(value)
    }
    
    // There is no such thing as an unsafe access to a snapshot.
    public func unsafeRead<T>(_ value: (Database) throws -> T) throws -> T {
        try read(value)
    }
    
    // There is no such thing as an unsafe access to a snapshot.
    public func asyncUnsafeRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        asyncRead(value)
    }
}
