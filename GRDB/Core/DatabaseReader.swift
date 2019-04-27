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
public protocol DatabaseReader : class {
    
    // MARK: - Read From Database
    
    /// Synchronously executes a read-only block that takes a database
    /// connection, and returns its result.
    ///
    /// Guarantee 1: the block argument is isolated. Eventual concurrent
    /// database updates are not visible inside the block:
    ///
    ///     try reader.read { db in
    ///         // Those two values are guaranteed to be equal, even if the
    ///         // `wine` table is modified between the two requests:
    ///         let count1 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
    ///         let count2 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
    ///     }
    ///
    ///     try reader.read { db in
    ///         // Now this value may be different:
    ///         let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
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
    ///         // may have inserted or deleted a wine between the two requests:
    ///         let count1 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
    ///         let count2 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
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
    ///         // may have inserted or deleted a wine between the two requests:
    ///         let count1 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
    ///         let count2 = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wine")!
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
        onError: ((Error) -> Void)?,
        onChange: @escaping (Reducer.Value) -> Void)
        throws -> TransactionObserver
    
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
        try backup(to: writer, afterBackupInit: nil, afterBackupStep: nil)
    }
    
    func backup(to writer: DatabaseWriter, afterBackupInit: (() -> ())?, afterBackupStep: (() -> ())?) throws {
        try read { dbFrom in
            try writer.writeWithoutTransaction { dbDest in
                try Database.backup(from: dbFrom, to: dbDest, afterBackupInit: afterBackupInit, afterBackupStep: afterBackupStep)
            }
        }
    }
}

/// A type-erased DatabaseReader
///
/// Instances of AnyDatabaseReader forward their methods to an arbitrary
/// underlying database reader.
public final class AnyDatabaseReader : DatabaseReader {
    private let base: DatabaseReader
    
    /// Creates a database reader that wraps a base database reader.
    public init(_ base: DatabaseReader) {
        self.base = base
    }
    
    // MARK: - Reading from Database
    
    /// :nodoc:
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.read(block)
    }
    
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
        onError: ((Error) -> Void)?,
        onChange: @escaping (Reducer.Value) -> Void)
        throws -> TransactionObserver
    {
        return try base.add(observation: observation, onError: onError, onChange: onChange)
    }
    
    /// :nodoc:
    public func remove(transactionObserver: TransactionObserver) {
        base.remove(transactionObserver: transactionObserver)
    }
}
