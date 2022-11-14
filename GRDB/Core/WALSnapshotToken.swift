// swiftlint:disable:next line_length
#if (compiler(<5.7.1) && (os(macOS) || targetEnvironment(macCatalyst))) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT)
#else

#if canImport(Combine)
import Combine
import Dispatch
#endif

/// A token that indicates which WAL snapshot is being accessed.
///
/// ## Overview
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// All database accesses performed from a `WALSnapshotToken` see the database
/// content as it existed at the moment the token was created.
///
/// ## Usage
///
/// You create a `WALSnapshotToken` from a ``DatabasePool``,
/// with ``DatabasePool/currentSnapshotToken()``:
///
/// ```swift
/// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
/// let token = try dbPool.currentSnapshotToken()
/// let playerCount = try dbPool.read(from: token) { db in
///     try Player.fetchCount(db)
/// }
/// ```
///
/// When you want to control the database state seen by a token, create the
/// token from within a write access, outside of any transaction.
///
/// For example, compare the two tokens below. The first one is guaranteed to
/// see an empty table of players, because is is created after all players have
/// been deleted, and from the serialized writer dispatch queue which prevents
/// any concurrent write. The second is created without this concurrency
/// protection, which means that some other threads may already have created
/// some players:
///
/// ```swift
/// let token1 = try dbPool.writeWithoutTransaction { db -> WALSnapshotToken in
///     try db.inTransaction {
///         try Player.deleteAll()
///         return .commit
///     }
///
///     return dbPool.currentSnapshotToken()
/// }
///
/// // <- Other threads may have created some players here
/// let token2 = try dbPool.currentSnapshotToken()
///
/// // Guaranteed to be zero
/// let count1 = try dbPool.read(from: token1, Player.fetchCount)
///
/// // Could be anything
/// let count2 = try dbPool.read(from: token2, Player.fetchCount)
/// ```
///
/// Related SQLite documentation:
///
/// - <https://www.sqlite.org/c3ref/snapshot_get.html>
/// - <https://www.sqlite.org/c3ref/snapshot_open.html>
public struct WALSnapshotToken {
    let walSnapshot: WALSnapshot
    
    /// The connection that holds a transaction and prevents checkpointing in
    /// order to keep `walSnapshot` valid.
    let snapshot: DatabaseSnapshot
    
    let schemaVersion: Int32
    
    // Protected by a lock because a token can be used in multiple
    // database connections.
    @LockedBox var schemaCache: Database.SchemaCache
}

extension DatabasePool {
    /// Returns a token associated with the WAL snapshot of the current state of
    /// the database.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// The returned token makes it possible to see the database content as it
    /// existed at the moment the token was created.
    ///
    /// It is a programmer error to get a WAL snapshot token from the writer
    /// dispatch queue when a transaction is opened:
    ///
    /// ```swift
    /// try dbPool.write { db in
    ///     try Player.deleteAll()
    ///
    ///     // fatal error: currentSnapshotToken() must not be called from inside a transaction
    ///     let token = try dbPool.currentSnapshotToken()
    /// }
    /// ```
    ///
    /// To avoid this fatal error, create the token *before* or *after*
    /// the transaction:
    ///
    /// ```swift
    /// let token = try dbPool.currentSnapshotToken() // OK
    ///
    /// try dbPool.writeWithoutTransaction { db in
    ///     let token = try dbPool.currentSnapshotToken() // OK
    ///
    ///     try db.inTransaction {
    ///         try Player.deleteAll()
    ///         return .commit
    ///     }
    ///
    ///     let token = try dbPool.currentSnapshotToken() // OK
    /// }
    ///
    /// let token = try dbPool.currentSnapshotToken() // OK
    /// ```
    public func currentSnapshotToken() throws -> WALSnapshotToken {
        let snapshot = try makeSnapshot()
        return try snapshot.read { db in
            try WALSnapshotToken(
                walSnapshot: WALSnapshot(db),
                snapshot: snapshot,
                schemaVersion: db.schemaVersion(),
                schemaCache: db.schemaCache)
        }
    }
    
    /// Executes read-only database operations from the given WAL snapshot, and
    /// returns their result after they have finished executing.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// For example:
    ///
    /// ```swift
    /// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
    /// let token = try dbPool.currentSnapshotToken()
    /// let count = try reader.read(from: token) { db in
    ///     try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// Database operations see the database content as it existed at the moment
    /// the token was created.
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
    public func read<T>(from token: WALSnapshotToken, _ value: (Database) throws -> T) throws -> T {
        try read { db in
            try db.read(from: token) {
                try value(db)
            }
        }
    }
    
    /// Executes read-only database operations from the given WAL snapshot, and
    /// returns their result after they have finished executing.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// For example:
    ///
    /// ```swift
    /// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
    /// let token = try dbPool.currentSnapshotToken()
    /// let count = try await reader.read(from: token) { db in
    ///     try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// Database operations see the database content as it existed at the moment
    /// the token was created.
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
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func read<T>(
        from token: WALSnapshotToken,
        _ value: @Sendable @escaping (Database) throws -> T)
    async throws -> T
    {
        try await read { db in
            try db.read(from: token) {
                try value(db)
            }
        }
    }
    
    /// Schedules read-only database operations for execution, from the given
    /// WAL snapshot, and returns immediately.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// For example:
    ///
    /// ```swift
    /// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
    /// let token = try dbPool.currentSnapshotToken()
    /// try reader.asyncRead(from: token) { dbResult in
    ///     do {
    ///         let db = try dbResult.get()
    ///         let count = try Player.fetchCount(db)
    ///     } catch {
    ///         // Handle error
    ///     }
    /// }
    /// ```
    ///
    /// Database operations see the database content as it existed at the moment
    /// the token was created.
    ///
    /// The database connection is read-only: attempts to write throw a
    /// ``DatabaseError`` with resultCode `SQLITE_READONLY`.
    ///
    /// - parameter value: A closure which accesses the database. Its argument
    ///   is a `Result` that provides the database connection, or the failure
    ///   that would prevent establishing the read access to the database.
    public func asyncRead(from token: WALSnapshotToken, _ value: @escaping (Result<Database, Error>) -> Void) {
        asyncRead { dbResult in
            do {
                let db = try dbResult.get()
                try db.read(from: token) {
                    value(.success(db))
                }
            } catch {
                value(.failure(error))
            }
        }
    }
    
#if canImport(Combine)
    /// Returns a publisher that publishes one value fetched from the given WAL
    /// snapshot, and completes.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// The database is not accessed until subscription. Value and completion
    /// are published on `scheduler` (the main dispatch queue by default).
    ///
    /// For example:
    ///
    /// ```swift
    /// let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
    /// let token = try dbPool.currentSnapshotToken()
    /// let countPublisher = reader.readPublisher(from: token) { db in
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
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func readPublisher<Output>(
        from token: WALSnapshotToken,
        receiveOn scheduler: some Combine.Scheduler = DispatchQueue.main,
        value: @escaping (Database) throws -> Output)
    -> DatabasePublishers.Read<Output>
    {
        readPublisher(receiveOn: scheduler) { db in
            try db.read(from: token) {
                try value(db)
            }
        }
    }
#endif
}

extension Database {
    fileprivate func open(_ token: WALSnapshotToken) throws {
        let code = sqlite3_snapshot_open(sqliteConnection, "main", token.walSnapshot.sqliteSnapshot)
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code)
        }
        lastSchemaVersion = token.schemaVersion
        schemaCache = token.schemaCache
    }
    
    fileprivate func read<T>(from token: WALSnapshotToken, _ value: () throws -> T) throws -> T {
        try open(token)
        defer {
            token.$schemaCache.update { $0.formUnion(schemaCache) }
        }
        
        return try value()
    }
}
#endif
