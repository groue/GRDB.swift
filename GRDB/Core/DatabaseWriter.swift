#if canImport(Combine)
import Combine
#endif
import Dispatch

/// A type that writes into an SQLite database.
///
/// Do not declare new conformances to `DatabaseWriter`. Only the built-in
/// conforming types are valid.
///
/// A database writer creates one single SQLite connection dedicated to database
/// updates. All updates are executed in a serial **writer dispatch queue**.
///
/// Read accesses are defined by ``DatabaseReader``, the protocol all database
/// writers conform to.
///
/// See <doc:Concurrency> for more information about the behavior of conforming
/// types in a multithreaded application.
///
/// ## Topics
///
/// ### Writing into the Database
///
/// - ``write(_:)-76inz``
/// - ``write(_:)-88g7e``
/// - ``writePublisher(receiveOn:updates:)``
/// - ``writePublisher(receiveOn:updates:thenRead:)``
/// - ``writeWithoutTransaction(_:)-4qh1w``
/// - ``writeWithoutTransaction(_:)-tckw``
/// - ``asyncWrite(_:completion:)``
/// - ``asyncWriteWithoutTransaction(_:)``
///
/// ### Exclusive Access to the Database
///
/// - ``barrierWriteWithoutTransaction(_:)-280j1``
/// - ``barrierWriteWithoutTransaction(_:)-7u4xw``
/// - ``asyncBarrierWriteWithoutTransaction(_:)``
///
/// ### Reading from the Latest Committed Database State
///
/// - ``concurrentRead(_:)``
/// - ``spawnConcurrentRead(_:)``
/// - ``DatabaseFuture``
///
/// ### Unsafe Methods
///
/// - ``unsafeReentrantWrite(_:)``
///
/// ### Observing Database Transactions
///
/// - ``add(transactionObserver:extent:)``
/// - ``remove(transactionObserver:)``
///
/// ### Other Database Operations
///
/// - ``erase()-w5n7``
/// - ``erase()-7jv3d``
/// - ``vacuum()-310uw``
/// - ``vacuum()-9inj0``
/// - ``vacuum(into:)-5lo41``
/// - ``vacuum(into:)-9c5mb``
///
/// ### Supporting Types
///
/// - ``AnyDatabaseWriter``
public protocol DatabaseWriter: DatabaseReader {
    
    // MARK: - Writing in Database
    
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// For example:
    ///
    /// ```swift
    /// let newPlayerCount = try writer.writeWithoutTransaction { db in
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
    ///   can see partial updates performed by the `updates` closure. See
    ///   <doc:Concurrency#Rule-2:-Mind-your-transactions> for more information.
    ///
    /// - parameter updates: A closure which accesses the database.
    /// - throws: The error thrown by `updates`.
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    func writeWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T
    
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// This method waits until all currently executing database accesses
    /// performed by the database writer finish executing (reads and writes).
    /// At that point, database operations are executed. Once they finish, the
    /// database writer can proceed with other database accesses.
    ///
    /// For example:
    ///
    /// ```swift
    /// let newPlayerCount = try writer.barrierWriteWithoutTransaction { db in
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
    ///   can see partial updates performed by the `updates` closure. See
    ///   <doc:Concurrency#Rule-2:-Mind-your-transactions> for more information.
    ///
    /// - parameter updates: A closure which accesses the database.
    /// - throws: The error thrown by `updates`.
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    func barrierWriteWithoutTransaction<T>(_ updates: (Database) throws -> T) throws -> T
    
    /// Schedules database operations for execution, and returns immediately.
    ///
    /// Database operations are not executed until all currently executing
    /// database accesses performed by the database writer finish executing
    /// (reads and writes). At that point, database operations are executed.
    /// Once they finish, the database writer can proceed with other
    /// database accesses.
    ///
    /// For example:
    ///
    /// ```swift
    /// writer.asyncBarrierWriteWithoutTransaction { dbResult in
    ///     do {
    ///         let db = try dbResult.get()
    ///         try Player(name: "Arthur").insert(db)
    ///         let newPlayerCount = try Player.fetchCount(db)
    ///     } catch {
    ///         // Handle error
    ///     }
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
    /// - warning: Database operations are not wrapped in a transaction. They
    ///   can see changes performed by concurrent writes or writes performed by
    ///   other processes: two identical requests performed by the `updates`
    ///   closure may not return the same value. Concurrent database accesses
    ///   can see partial updates performed by the `updates` closure. See
    ///   <doc:Concurrency#Rule-2:-Mind-your-transactions> for more information.
    ///
    /// - parameter updates: A closure which accesses the database. Its argument
    ///   is a `Result` that provides the database connection, or the failure
    ///   that would prevent establishing the barrier access to the database.
    func asyncBarrierWriteWithoutTransaction(_ updates: @escaping (Result<Database, Error>) -> Void)
    
    /// Schedules database operations for execution, and returns immediately.
    ///
    /// For example:
    ///
    /// ```swift
    /// writer.asyncWriteWithoutTransaction { db in
    ///     do {
    ///         try Player(name: "Arthur").insert(db)
    ///         let newPlayerCount = try Player.fetchCount(db)
    ///     } catch {
    ///         // Handle error
    ///     }
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
    /// - warning: Database operations are not wrapped in a transaction. They
    ///   can see changes performed by concurrent writes or writes performed by
    ///   other processes: two identical requests performed by the `updates`
    ///   closure may not return the same value. Concurrent database accesses
    ///   can see partial updates performed by the `updates` closure. See
    ///   <doc:Concurrency#Rule-2:-Mind-your-transactions> for more information.
    ///
    /// - parameter updates: A closure which accesses the database.
    func asyncWriteWithoutTransaction(_ updates: @escaping (Database) -> Void)
    
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// This method can be called from other database access methods. Reentrant
    /// database accesses are discouraged because they muddle transaction
    /// boundaries. See <doc:Concurrency#Rule-2:-Mind-your-transactions> for
    /// more information. 
    ///
    /// For example:
    ///
    /// ```swift
    /// let newPlayerCount = try writer.unsafeReentrantWrite { db in
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
    /// - warning: Database operations are not wrapped in a transaction. They
    ///   can see changes performed by concurrent writes or writes performed by
    ///   other processes: two identical requests performed by the `updates`
    ///   closure may not return the same value. Concurrent database accesses
    ///   can see partial updates performed by the `updates` closure.
    ///
    /// - parameter updates: A closure which accesses the database.
    /// - throws: The error thrown by `updates`.
    func unsafeReentrantWrite<T>(_ updates: (Database) throws -> T) rethrows -> T
    
    // MARK: - Reading from Database
    
    /// Schedules read-only database operations for execution, and returns a
    /// future value.
    ///
    /// This method must be called from the writer dispatch queue, outside of
    /// any transaction. You'll get a fatal error otherwise.
    ///
    /// Database operations performed by the `value` closure are isolated in a
    /// transaction: they do not see changes performed by eventual concurrent
    /// writes (even writes performed by other processes).
    ///
    /// They see the database in the state left by the last updates performed
    /// by the database writer.
    ///
    /// To access the fetched results, you call the ``DatabaseFuture/wait()``
    /// method of the returned future, on any dispatch queue.
    ///
    /// In the example below, the number of players is fetched concurrently with
    /// the player insertion. Yet the future is guaranteed to return zero:
    ///
    /// ```swift
    /// try writer.writeWithoutTransaction { db in
    ///     // Delete all players
    ///     try Player.deleteAll()
    ///
    ///     // Count players concurrently
    ///     let future = writer.concurrentRead { db in
    ///         return try Player.fetchCount()
    ///     }
    ///
    ///     // Insert a player
    ///     try Player(...).insert(db)
    ///
    ///     // Guaranteed to be zero
    ///     let count = try future.wait()
    /// }
    /// ```
    ///
    /// - note: Usage of this method is discouraged, because waiting on the
    ///   returned ``DatabaseFuture`` blocks a thread. You may prefer
    ///   ``spawnConcurrentRead(_:)`` instead.
    /// - parameter value: A closure which accesses the database.
    func concurrentRead<T>(_ value: @escaping (Database) throws -> T) -> DatabaseFuture<T>
    
    // Exposed for RxGRDB and GRBCombine. Naming is not stabilized.
    /// Schedules read-only database operations for execution.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// This method must be called from the writer dispatch queue, outside of
    /// any transaction. You'll get a fatal error otherwise.
    ///
    /// Database operations performed by the `value` closure are isolated in a
    /// transaction: they do not see changes performed by eventual concurrent
    /// writes (even writes performed by other processes).
    ///
    /// They see the database in the state left by the last updates performed
    /// by the database writer.
    ///
    /// In the example below, the number of players is fetched concurrently with
    /// the player insertion. Yet it is guaranteed to return zero:
    ///
    /// ```swift
    /// try writer.writeWithoutTransaction { db in
    ///     // Delete all players
    ///     try Player.deleteAll()
    ///
    ///     // Count players concurrently
    ///     writer.spawnConcurrentRead { db in
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
    /// - important: The database operations are executed immediately,
    ///   or asynchronously, depending on the actual class
    ///   of `DatabaseWriter`.
    ///
    /// - parameter value: A closure which accesses the database. Its argument
    ///   is a `Result` that provides the database connection, or the failure
    ///   that would prevent establishing the read access to the database.
    func spawnConcurrentRead(_ value: @escaping (Result<Database, Error>) -> Void)
}

extension DatabaseWriter {
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// For example:
    ///
    /// ```swift
    /// let newPlayerCount = try writer.write { db in
    ///     try Player(name: "Arthur").insert(db)
    ///     return try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// Database operations are wrapped in a transaction. If they throw an
    /// error, the transaction is rollbacked and the error is rethrown.
    ///
    /// Concurrent database accesses can not see partial database updates (even
    /// when performed by other processes).
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
    /// - parameter updates: A closure which accesses the database.
    /// - throws: The error thrown by `updates`, or any ``DatabaseError`` that
    ///   would happen while establishing the database access or committing
    ///   the transaction.
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
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
    
    /// Schedules database operations for execution, and returns immediately.
    ///
    /// For example:
    ///
    /// ```swift
    /// writer.asyncWrite { db -> Int in
    ///     try Player(name: "Arthur").insert(db)
    ///     return try Player.fetchCount(db)
    /// } completion: { db, result in
    ///     switch result {
    ///     case let .success(newPlayerCount):
    ///         // Handle success
    ///     case let .failure(error):
    ///         // Handle error
    /// }
    /// ```
    ///
    /// Database operations run by the `updates` closure are wrapped in
    /// a transaction. If they throw an error, the transaction is rollbacked.
    ///
    /// The `completion` closure has two arguments: a database connection, and
    /// the result of the transaction. This result is a failure if the
    /// transaction could not be committed or if `updates` has thrown an error.
    ///
    /// Concurrent database accesses can not see partial database updates
    /// performed by `updates` (even when performed by other processes).
    ///
    /// Database operations run in the writer dispatch queue, serialized
    /// with all database updates performed by this `DatabaseWriter`.
    ///
    /// The ``Database`` argument to `updates` and `completion` is valid only
    /// during the execution of those closures. Do not store or return the
    /// database connection for later use.
    ///
    /// - parameter updates: A closure which accesses the database.
    /// - parameter completion: A closure called with the transaction result.
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
    
    /// Adds a transaction observer, so that it gets notified of
    /// database changes and transactions.
    ///
    /// This method has no effect on read-only database connections.
    ///
    /// - parameter transactionObserver: A transaction observer.
    /// - parameter extent: The duration of the observation. The default is
    ///   the observer lifetime (observation lasts until observer
    ///   is deallocated).
    public func add(
        transactionObserver: some TransactionObserver,
        extent: Database.TransactionObservationExtent = .observerLifetime)
    {
        writeWithoutTransaction { $0.add(transactionObserver: transactionObserver, extent: extent) }
    }
    
    /// Removes a transaction observer.
    public func remove(transactionObserver: some TransactionObserver) {
        writeWithoutTransaction { $0.remove(transactionObserver: transactionObserver) }
    }
    
    // MARK: - Erasing the content of the database
    
    /// Erase the database: delete all content, drop all tables, etc.
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func erase() throws {
        try barrierWriteWithoutTransaction { try $0.erase() }
    }
    
    // MARK: - Claiming Disk Space
    
    /// Rebuilds the database file, repacking it into a minimal amount of
    /// disk space.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_vacuum.html>
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func vacuum() throws {
        try writeWithoutTransaction { try $0.execute(sql: "VACUUM") }
    }
    
    // VACUUM INTO was introduced in SQLite 3.27.0:
    // https://www.sqlite.org/releaselog/3_27_0.html
    //
    // Old versions of SQLCipher won't have it, but I don't know how to perform
    // availability checks that depend on the version of the SQLCipher CocoaPod
    // chosen by the application. So let's just have the method fail at runtime.
    //
    // This method is declared on DatabaseWriter instead of DatabaseReader,
    // so that it is not available on DatabaseSnaphot. VACUUM INTO is not
    // available inside the transaction that is kept open by DatabaseSnaphot.
#if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Creates a new database file at the specified path with a minimum
    /// amount of disk space.
    ///
    /// Databases encrypted with SQLCipher are copied with the same password
    /// and configuration as the original database.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_vacuum.html#vacuuminto>
    ///
    /// - Parameter filePath: file path for new database
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func vacuum(into filePath: String) throws {
        try writeWithoutTransaction {
            try $0.execute(sql: "VACUUM INTO ?", arguments: [filePath])
        }
    }
#else
    /// Creates a new database file at the specified path with a minimum
    /// amount of disk space.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_vacuum.html#vacuuminto>
    ///
    /// - Parameter filePath: file path for new database
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    @available(iOS 14, macOS 10.16, tvOS 14, watchOS 7, *)
    public func vacuum(into filePath: String) throws {
        try writeWithoutTransaction {
            try $0.execute(sql: "VACUUM INTO ?", arguments: [filePath])
        }
    }
#endif
    
    // MARK: - Database Observation
    
    /// Starts an observation that fetches fresh database values synchronously,
    /// from the writer database connection, right after the database
    /// was modified.
    func _addWriteOnly<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        scheduling scheduler: some ValueObservationScheduler,
        onChange: @escaping (Reducer.Value) -> Void)
    -> AnyDatabaseCancellable
    {
        assert(!configuration.readonly, "Use _addReadOnly(observation:) instead")
        let observer = ValueWriteOnlyObserver(
            writer: self,
            scheduler: scheduler,
            readOnly: !observation.requiresWriteAccess,
            trackingMode: observation.trackingMode,
            reducer: observation.makeReducer(),
            events: observation.events,
            onChange: onChange)
        return observer.start()
    }
}

extension DatabaseWriter {
    // MARK: - Asynchronous Database Access
    
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// For example:
    ///
    /// ```swift
    /// let newPlayerCount = try await writer.write { db in
    ///     try Player(name: "Arthur").insert(db)
    ///     return try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// Database operations are wrapped in a transaction. If they throw an
    /// error, the transaction is rollbacked and the error is rethrown.
    ///
    /// Concurrent database accesses can not see partial database updates (even
    /// when performed by other processes).
    ///
    /// Database operations run in the writer dispatch queue, serialized
    /// with all database updates performed by this `DatabaseWriter`.
    ///
    /// The ``Database`` argument to `updates` is valid only during the
    /// execution of the closure. Do not store or return the database connection
    /// for later use.
    ///
    /// - parameter updates: A closure which accesses the database.
    /// - throws: The error thrown by `updates`, or any ``DatabaseError`` that
    ///   would happen while establishing the database access or committing
    ///   the transaction.
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func write<T>(_ updates: @Sendable @escaping (Database) throws -> T) async throws -> T {
        try await withUnsafeThrowingContinuation { continuation in
            asyncWrite(updates, completion: { _, result in
                continuation.resume(with: result)
            })
        }
    }
    
    /// Executes database operations, and returns their result after they have
    /// finished executing.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// For example:
    ///
    /// ```swift
    /// let newPlayerCount = try await writer.writeWithoutTransaction { db in
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
    /// - warning: Database operations are not wrapped in a transaction. They
    ///   can see changes performed by concurrent writes or writes performed by
    ///   other processes: two identical requests performed by the `updates`
    ///   closure may not return the same value. Concurrent database accesses
    ///   can see partial updates performed by the `updates` closure.
    ///
    /// - parameter updates: A closure which accesses the database.
    /// - throws: The error thrown by `updates`.
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func writeWithoutTransaction<T>(_ updates: @Sendable @escaping (Database) throws -> T) async throws -> T {
        try await withUnsafeThrowingContinuation { continuation in
            asyncWriteWithoutTransaction { db in
                do {
                    try continuation.resume(returning: updates(db))
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
    /// Database operations are not executed until all currently executing
    /// database accesses performed by the database writer finish executing
    /// (both reads and writes). At that point, database operations are
    /// executed. Once they finish, the database writer can proceed with other
    /// database accesses.
    ///
    /// For example:
    ///
    /// ```swift
    /// let newPlayerCount = try await writer.barrierWriteWithoutTransaction { db in
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
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func barrierWriteWithoutTransaction<T>(
        _ updates: @Sendable @escaping (Database) throws -> T)
    async throws -> T
    {
        try await withUnsafeThrowingContinuation { continuation in
            asyncBarrierWriteWithoutTransaction { dbResult in
                continuation.resume(with: dbResult.flatMap { db in Result { try updates(db) } })
            }
        }
    }
    
    /// Erase the database: delete all content, drop all tables, etc.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func erase() async throws {
        try await writeWithoutTransaction { try $0.erase() }
    }
    
    /// Rebuilds the database file, repacking it into a minimal amount of
    /// disk space.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_vacuum.html>
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func vacuum() async throws {
        try await writeWithoutTransaction { try $0.execute(sql: "VACUUM") }
    }
    
#if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Creates a new database file at the specified path with a minimum
    /// amount of disk space.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// Databases encrypted with SQLCipher are copied with the same password
    /// and configuration as the original database.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_vacuum.html#vacuuminto>
    ///
    /// - Parameter filePath: file path for new database
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func vacuum(into filePath: String) async throws {
        try await writeWithoutTransaction {
            try $0.execute(sql: "VACUUM INTO ?", arguments: [filePath])
        }
    }
#else
    /// Creates a new database file at the specified path with a minimum
    /// amount of disk space.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_vacuum.html#vacuuminto>
    ///
    /// - Parameter filePath: file path for new database
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func vacuum(into filePath: String) async throws {
        try await writeWithoutTransaction {
            try $0.execute(sql: "VACUUM INTO ?", arguments: [filePath])
        }
    }
#endif
}

#if canImport(Combine)
extension DatabaseWriter {
    // MARK: - Publishing Database Updates
    
    /// Returns a publisher that publishes one value and completes.
    ///
    /// The database is not accessed until subscription. Value and completion
    /// are published on `scheduler` (the main dispatch queue by default).
    ///
    /// For example:
    ///
    /// ```swift
    /// // DatabasePublishers.Write<Int>
    /// let newPlayerCountPublisher = writer.writePublisher { db in
    ///     try Player(name: "Arthur").insert(db)
    ///     return try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// Database operations are wrapped in a transaction. If they throw an
    /// error, the transaction is rollbacked and the error completes
    /// the publisher.
    ///
    /// Concurrent database accesses can not see partial database updates (even
    /// when performed by other processes).
    ///
    /// Database operations are asynchronously dispatched in the writer dispatch
    /// queue, serialized with all database updates performed by
    /// this `DatabaseWriter`.
    ///
    /// The ``Database`` argument to `updates` is valid only during the
    /// execution of the closure. Do not store or return the database connection
    /// for later use.
    ///
    /// - parameter scheduler: A Combine Scheduler.
    /// - parameter updates: A closure which accesses the database.
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func writePublisher<Output>(
        receiveOn scheduler: some Combine.Scheduler = DispatchQueue.main,
        updates: @escaping (Database) throws -> Output)
    -> DatabasePublishers.Write<Output>
    {
        OnDemandFuture { fulfill in
            self.asyncWrite(updates, completion: { _, result in
                fulfill(result)
            })
        }
        // We don't want users to process emitted values on a
        // database dispatch queue.
        .receiveValues(on: scheduler)
        .eraseToWritePublisher()
    }
    
    /// Returns a publisher that publishes one value and completes.
    ///
    /// The database is not accessed until subscription. Value and completion
    /// are published on `scheduler` (the main dispatch queue by default).
    ///
    /// For example:
    ///
    /// ```swift
    /// // DatabasePublishers.Write<Int>
    /// let newPlayerCountPublisher = writer.writePublisher { db in
    ///     try Player(name: "Arthur").insert(db)
    /// } thenRead: { db, _ in
    ///     try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// The returned publisher publishes exactly the same value as
    /// ``writePublisher(receiveOn:updates:)``:
    ///
    /// ```swift
    /// // DatabasePublishers.Write<Int>
    /// let newPlayerCountPublisher = writer.writePublisher { db in
    ///     try Player(name: "Arthur").insert(db)
    ///     return try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// The difference is that the last fetches are performed in the `thenRead`
    /// closure. This closure accepts two arguments: a read-only database
    /// connection, and the result of the `updates` function. This allows you to
    /// pass information from a function to the other (it is ignored in the
    /// sample code above).
    ///
    /// When you use a ``DatabasePool``, this method applies a scheduling
    /// optimization: the `thenRead` closure sees the database in the state left
    /// by the `updates` closure, but it does not block any concurrent writes.
    /// This can reduce database write contention.
    ///
    /// When you use a ``DatabaseQueue``, the results are guaranteed to be
    /// identical, but no scheduling optimization is applied.
    ///
    /// The ``Database`` argument to `updates` and `value` is valid only during
    /// the execution of those closures. Do not store or return the database
    /// connection for later use.
    ///
    /// - parameter scheduler: A Combine Scheduler.
    /// - parameter updates: A closure which writes in the database.
    /// - parameter value: A closure which reads from the database.
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func writePublisher<S, T, Output>(
        receiveOn scheduler: S = DispatchQueue.main,
        updates: @escaping (Database) throws -> T,
        thenRead value: @escaping (Database, T) throws -> Output)
    -> DatabasePublishers.Write<Output>
    where S: Scheduler
    {
        OnDemandFuture { fulfill in
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
        }
        // We don't want users to process emitted values on a
        // database dispatch queue.
        .receiveValues(on: scheduler)
        .eraseToWritePublisher()
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension DatabasePublishers {
    /// A publisher that writes into the database.
    ///
    /// `Write` publishes exactly one element, or an error.
    ///
    /// You build such a publisher from ``DatabaseWriter``.
    public struct Write<Output>: Publisher {
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
    fileprivate func eraseToWritePublisher() -> DatabasePublishers.Write<Output> {
        .init(upstream: self.eraseToAnyPublisher())
    }
}
#endif

/// A future database value.
///
/// You get instances of `DatabaseFuture` from the `DatabaseWriter`
/// ``DatabaseWriter/concurrentRead(_:)`` method. For example:
///
/// ```swift
/// let futureCount: Future<Int> = try writer.writeWithoutTransaction { db in
///     try Player(...).insert()
///
///     // Count players concurrently
///     return writer.concurrentRead { db in
///         return try Player.fetchCount()
///     }
/// }
///
/// let count: Int = try futureCount.wait()
/// ```
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

/// A type-erased database writer.
///
/// An instance of `AnyDatabaseWriter` forwards its operations to an underlying
/// base database writer.
public final class AnyDatabaseWriter {
    private let base: any DatabaseWriter
    
    /// Creates a new database reader that wraps and forwards operations
    /// to `base`.
    public init(_ base: some DatabaseWriter) {
        self.base = base
    }
}

extension AnyDatabaseWriter: DatabaseReader {
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

extension AnyDatabaseWriter: DatabaseWriter {
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func writeWithoutTransaction<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try base.writeWithoutTransaction(updates)
    }
    
    @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
    public func barrierWriteWithoutTransaction<T>(_ updates: (Database) throws -> T) throws -> T {
        try base.barrierWriteWithoutTransaction(updates)
    }
    
    public func asyncBarrierWriteWithoutTransaction(_ updates: @escaping (Result<Database, Error>) -> Void) {
        base.asyncBarrierWriteWithoutTransaction(updates)
    }
    
    public func asyncWriteWithoutTransaction(_ updates: @escaping (Database) -> Void) {
        base.asyncWriteWithoutTransaction(updates)
    }
    
    public func unsafeReentrantWrite<T>(_ updates: (Database) throws -> T) rethrows -> T {
        try base.unsafeReentrantWrite(updates)
    }
    
    public func concurrentRead<T>(_ value: @escaping (Database) throws -> T) -> DatabaseFuture<T> {
        base.concurrentRead(value)
    }
    
    public func spawnConcurrentRead(_ value: @escaping (Result<Database, Error>) -> Void) {
        base.spawnConcurrentRead(value)
    }
}
