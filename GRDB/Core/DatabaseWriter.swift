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
public protocol DatabaseWriter : DatabaseReader {
    
    // MARK: - Writing in Database
    
    /// Synchronously executes a block that takes a database connection, and
    /// returns its result.
    ///
    /// Eventual concurrent database updates are postponed until the block
    /// has executed.
    ///
    /// This method is *not* reentrant.
    func write<T>(_ block: (Database) throws -> T) rethrows -> T
    
    /// Synchronously executes a block that takes a database connection, and
    /// returns its result.
    ///
    /// Eventual concurrent database updates are postponed until the block
    /// has executed.
    ///
    /// This method is reentrant. It should be avoided because it fosters
    /// dangerous concurrency practices.
    func unsafeReentrantWrite<T>(_ block: (Database) throws -> T) rethrows -> T

    // MARK: - Reading from Database
    
    /// Synchronously or asynchronously executes a read-only block that takes a
    /// database connection.
    ///
    /// This method must be called from a writing dispatch queue.
    ///
    /// The *block* argument is guaranteed to see the database in the state it
    /// has at the moment this method is called (see below). Eventual concurrent
    /// database updates are *not visible* inside the block.
    ///
    /// What is the "current state" of the database?
    ///
    /// - When this method is called outside of any transaction, the current
    ///   state is the last committed state.
    ///
    ///         try writer.write { db in
    ///             try db.execute("DELETE FROM players")
    ///             try writer.readFromCurrentState { db in
    ///                 // Guaranteed to be zero
    ///                 try Int.fetchOne(db, "SELECT COUNT(*) FROM players")!
    ///             }
    ///             try db.execute("INSERT INTO players ...")
    ///         }
    ///
    /// - When this method is called inside an uncommitted transation, the
    ///   current state depends on the caller:
    ///
    ///     DatabasePool.readFromCurrentState runs *block* asynchronously in a
    ///     concurrent reader dispatch queue, and release the writing dispatch
    ///     queue early, before the block has finished. In the example below,
    ///     the insertion runs concurrently with the select, and the select sees
    ///     the database in its last committed state.
    ///
    ///         try dbPool.write { db in
    ///             try db.execute("DELETE FROM players")
    ///             db.inTransaction {
    ///                 try db.execute("INSERT INTO players ...")
    ///                 try dbPool.readFromCurrentState { db in
    ///                     // Zero
    ///                     try Int.fetchOne(db, "SELECT COUNT(*) FROM players")!
    ///                 }
    ///                 return .commit
    ///             }
    ///         }
    ///
    ///     DatabaseQueue.readFromCurrentState simply runs *block* synchronously,
    ///     and returns when the block has completed. In the example below, the
    ///     select sees the uncommitted state of the database, and the insertion
    ///     is run after the select.
    ///
    ///         try dbQueue.write { db in
    ///             try db.execute("DELETE FROM players")
    ///             db.inTransaction {
    ///                 try db.execute("INSERT INTO players ...")
    ///                 try dbQueue.readFromCurrentState { db in
    ///                     // One
    ///                     try Int.fetchOne(db, "SELECT COUNT(*) FROM players")!
    ///                 }
    ///                 return .commit
    ///             }
    ///         }
    ///
    /// This method is *not* reentrant.
    func readFromCurrentState(_ block: @escaping (Database) -> Void) throws
}

extension DatabaseWriter {
    
    // MARK: - Transaction Observers
    
    /// Add a transaction observer, so that it gets notified of
    /// database changes.
    ///
    /// - parameter transactionObserver: A transaction observer.
    /// - parameter extent: The duration of the observation. The default is
    ///   the observer lifetime (observation lasts until observer
    ///   is deallocated).
    public func add(transactionObserver: TransactionObserver, extent: Database.TransactionObservationExtent = .observerLifetime) {
        write { $0.add(transactionObserver: transactionObserver, extent: extent) }
    }
    
    /// Remove a transaction observer.
    public func remove(transactionObserver: TransactionObserver) {
        write { $0.remove(transactionObserver: transactionObserver) }
    }
}

/// A type-erased DatabaseWriter
///
/// Instances of AnyDatabaseWriter forward their methods to an arbitrary
/// underlying database writer.
public final class AnyDatabaseWriter : DatabaseWriter {
    private let base: DatabaseWriter
    
    /// Creates a database writer that wraps a base database writer.
    public init(_ base: DatabaseWriter) {
        self.base = base
    }
    
    // MARK: - Reading from Database

    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.read(block)
    }

    public func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.unsafeRead(block)
    }

    public func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.unsafeReentrantRead(block)
    }

    public func readFromCurrentState(_ block: @escaping (Database) -> Void) throws {
        try base.readFromCurrentState(block)
    }

    // MARK: - Writing in Database

    public func write<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try base.write(block)
    }

    public func unsafeReentrantWrite<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try base.unsafeReentrantWrite(block)
    }
    
    // MARK: - Functions
    
    public func add(function: DatabaseFunction) {
        base.add(function: function)
    }
    
    public func remove(function: DatabaseFunction) {
        base.remove(function: function)
    }
    
    // MARK: - Collations
    
    public func add(collation: DatabaseCollation) {
        base.add(collation: collation)
    }
    
    public func remove(collation: DatabaseCollation) {
        base.remove(collation: collation)
    }
}
