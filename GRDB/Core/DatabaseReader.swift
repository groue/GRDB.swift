#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

/// The protocol for all types that can fetch values from a database.
///
/// It is adopted by DatabaseQueue and DatabasePool.
///
/// The protocol comes with isolation guarantees that describe the behavior of
/// adopting types in a multithreaded application.
///
/// Types that adopt the protocol can provide in practice stronger guarantees.
/// For example, DatabaseQueue provides a stronger isolation level
/// than DatabasePool.
///
/// **Warning**: Isolation guarantees stand as long as there is no external
/// connection to the database. Should you have to cope with external
/// connections, protect yourself with transactions, and be ready to setup a
/// [busy handler](https://www.sqlite.org/c3ref/busy_handler.html).
public protocol DatabaseReader: AnyObject {
    
    /// The database configuration
    var configuration: Configuration { get }
    
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
    
    /// Synchronously executes a read-only block that takes a database
    /// connection, and returns its result.
    ///
    /// Guarantee 1: the block argument is isolated. Eventual concurrent
    /// database updates are not visible inside the block:
    ///
    ///     try reader.read { db in
    ///         // Those two values are guaranteed to be equal, even if the
    ///         // `player` table is modified between the two requests:
    ///         let count1 = try Player.fetchCount(db)
    ///         let count2 = try Player.fetchCount(db)
    ///     }
    ///
    ///     try reader.read { db in
    ///         // Now this value may be different:
    ///         let count = try Player.fetchCount(db)
    ///     }
    ///
    /// Guarantee 2: Starting iOS 8.2, OSX 10.10, and with custom SQLite builds
    /// and SQLCipher, attempts to write in the database throw a DatabaseError
    /// whose resultCode is `SQLITE_READONLY`.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block, or any DatabaseError that would
    ///   happen while establishing the read access to the database.
    func read<T>(_ block: (Database) throws -> T) throws -> T
    
    #if compiler(>=5.0)
    /// Asynchronously executes a read-only block that takes a
    /// database connection.
    ///
    /// Guarantee 1: the block argument is isolated. Eventual concurrent
    /// database updates are not visible inside the block:
    ///
    ///     try reader.asyncRead { result in
    ///         do (
    ///             let db = try result.get()
    ///             // Those two values are guaranteed to be equal, even if the
    ///             // `player` table is modified between the two requests:
    ///             let count1 = try Player.fetchCount(db)
    ///             let count2 = try Player.fetchCount(db)
    ///         } catch {
    ///             // handle error
    ///         }
    ///     }
    ///
    /// Guarantee 2: Starting iOS 8.2, OSX 10.10, and with custom SQLite builds
    /// and SQLCipher, attempts to write in the database throw a DatabaseError
    /// whose resultCode is `SQLITE_READONLY`.
    ///
    /// - parameter block: A block that accesses the database.
    func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void)
    #endif
    
    /// Synchronously executes a read-only block that takes a database
    /// connection, and returns its result.
    ///
    /// The two guarantees of the safe `read` method are lifted:
    ///
    /// The block argument is not isolated: eventual concurrent database updates
    /// are visible inside the block:
    ///
    ///     try reader.unsafeRead { db in
    ///         // Those two values may be different because some other thread
    ///         // may have inserted or deleted a player between the two requests:
    ///         let count1 = try Player.fetchCount(db)
    ///         let count2 = try Player.fetchCount(db)
    ///     }
    ///
    /// Cursor iterations are isolated, though:
    ///
    ///     try reader.unsafeRead { db in
    ///         // No concurrent update can mess with this iteration:
    ///         let rows = try Row.fetchCursor(db, sql: "SELECT ...")
    ///         while let row = try rows.next() { ... }
    ///     }
    ///
    /// The block argument is not prevented from writing (DatabaseQueue, in
    /// particular, will accept database modifications in `unsafeRead`).
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block, or any DatabaseError that would
    ///   happen while establishing the read access to the database.
    func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T
    
    /// Synchronously executes a block that takes a database connection, and
    /// returns its result.
    ///
    /// The two guarantees of the safe `read` method are lifted:
    ///
    /// The block argument is not isolated: eventual concurrent database updates
    /// are visible inside the block:
    ///
    ///     try reader.unsafeReentrantRead { db in
    ///         // Those two values may be different because some other thread
    ///         // may have inserted or deleted a player between the two requests:
    ///         let count1 = try Player.fetchCount(db)
    ///         let count2 = try Player.fetchCount(db)
    ///     }
    ///
    /// Cursor iterations are isolated, though:
    ///
    ///     try reader.unsafeReentrantRead { db in
    ///         // No concurrent update can mess with this iteration:
    ///         let rows = try Row.fetchCursor(db, sql: "SELECT ...")
    ///         while let row = try rows.next() { ... }
    ///     }
    ///
    /// The block argument is not prevented from writing (DatabaseQueue, in
    /// particular, will accept database modifications in `unsafeReentrantRead`).
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block, or any DatabaseError that would
    ///   happen while establishing the read access to the database.
    ///
    /// This method is reentrant. It should be avoided because it fosters
    /// dangerous concurrency practices.
    func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T
    
    
    // MARK: - Functions
    
    /// Add or redefine an SQL function.
    ///
    ///     let fn = DatabaseFunction("succ", argumentCount: 1) { dbValues in
    ///         guard let int = Int.fromDatabaseValue(dbValues[0]) else {
    ///             return nil
    ///         }
    ///         return int + 1
    ///     }
    ///     reader.add(function: fn)
    ///     try reader.read { db in
    ///         try Int.fetchOne(db, sql: "SELECT succ(1)")! // 2
    ///     }
    func add(function: DatabaseFunction)
    
    /// Remove an SQL function.
    func remove(function: DatabaseFunction)
    
    
    // MARK: - Collations
    
    /// Add or redefine a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     reader.add(collation: collation)
    ///     try reader.execute(sql: "SELECT * FROM file ORDER BY name COLLATE localized_standard")
    func add(collation: DatabaseCollation)
    
    /// Remove a collation.
    func remove(collation: DatabaseCollation)
    
    // MARK: - Value Observation
    
    /// Starts a value observation.
    ///
    /// You should use the `ValueObservation.start(in:onError:onChange:)`
    /// method instead.
    ///
    /// - parameter observation: the stared observation
    /// - parameter onError: a closure that is provided by eventual errors that happen
    /// during observation
    /// - parameter onChange: a closure that is provided fresh values
    /// - returns: a TransactionObserver
    func add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
        -> TransactionObserver
    
    /// Remove a transaction observer.
    func remove(transactionObserver: TransactionObserver)
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
    public func backup(to writer: DatabaseWriter) throws {
        try writer.writeWithoutTransaction { dbDest in
            try backup(to: dbDest)
        }
    }
    
    func backup(
        to dbDest: Database,
        afterBackupInit: (() -> Void)? = nil,
        afterBackupStep: (() -> Void)? = nil)
        throws
    {
        try read { dbFrom in
            try dbFrom.backup(
                to: dbDest,
                afterBackupInit: afterBackupInit,
                afterBackupStep: afterBackupStep)
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
    
    /// :nodoc:
    public var configuration: Configuration {
        return base.configuration
    }
    
    // MARK: - Interrupting Database Operations
    
    /// :nodoc:
    public func interrupt() {
        base.interrupt()
    }
    
    // MARK: - Reading from Database
    
    /// :nodoc:
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.read(block)
    }
    
    #if compiler(>=5.0)
    /// :nodoc:
    public func asyncRead(_ block: @escaping (Result<Database, Error>) -> Void) {
        base.asyncRead(block)
    }
    #endif
    
    /// :nodoc:
    public func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.unsafeRead(block)
    }
    
    /// :nodoc:
    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.unsafeReentrantRead(block)
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
    
    // MARK: - Value Observation
    
    /// :nodoc:
    public func add<Reducer: ValueReducer>(
        observation: ValueObservation<Reducer>,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
        -> TransactionObserver
    {
        return base.add(observation: observation, onError: onError, onChange: onChange)
    }
    
    /// :nodoc:
    public func remove(transactionObserver: TransactionObserver) {
        base.remove(transactionObserver: transactionObserver)
    }
}
