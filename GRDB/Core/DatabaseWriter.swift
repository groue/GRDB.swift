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
    /// Eventual concurrent reads are guaranteed not to see any changes
    /// performed in the block until they are all saved in the database.
    ///
    /// The block may, or may not, be wrapped inside a transaction.
    ///
    /// This method is *not* reentrant.
    func write<T>(_ block: (Database) throws -> T) throws -> T
    
    /// Synchronously executes a block that takes a database connection, and
    /// returns its result.
    ///
    /// Eventual concurrent database updates are postponed until the block
    /// has executed.
    ///
    /// Eventual concurrent reads may see changes performed in the block before
    /// the block completes.
    ///
    /// The block is guaranteed to be executed outside of a transaction.
    ///
    /// This method is *not* reentrant.
    func writeWithoutTransaction<T>(_ block: (Database) throws -> T) rethrows -> T
    
    /// Synchronously executes a block that takes a database connection, and
    /// returns its result.
    ///
    /// Eventual concurrent database updates are postponed until the block
    /// has executed.
    ///
    /// Eventual concurrent reads may see changes performed in the block before
    /// the block completes.
    ///
    /// This method is reentrant. It should be avoided because it fosters
    /// dangerous concurrency practices.
    func unsafeReentrantWrite<T>(_ block: (Database) throws -> T) rethrows -> T

    // MARK: - Reading from Database
    
    /// Synchronously or asynchronously executes a read-only block that takes a
    /// database connection.
    ///
    /// This method must be called from a writing dispatch queue, outside of any
    /// transaction. You'll get a fatal error otherwise.
    ///
    /// The *block* argument is guaranteed to see the database in the last
    /// committed state at the moment this method is called. Eventual concurrent
    /// database updates are *not visible* inside the block.
    ///
    /// For example:
    ///
    ///     try writer.write { db in
    ///         try db.execute("DELETE FROM player")
    ///         try writer.readFromCurrentState { db in
    ///             // Guaranteed to be zero
    ///             try Int.fetchOne(db, "SELECT COUNT(*) FROM player")!
    ///         }
    ///         try db.execute("INSERT INTO player ...")
    ///     }
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
        writeWithoutTransaction { $0.add(transactionObserver: transactionObserver, extent: extent) }
    }
    
    /// Remove a transaction observer.
    public func remove(transactionObserver: TransactionObserver) {
        writeWithoutTransaction { $0.remove(transactionObserver: transactionObserver) }
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

    /// :nodoc:
    public func readFromCurrentState(_ block: @escaping (Database) -> Void) throws {
        try base.readFromCurrentState(block)
    }

    // MARK: - Writing in Database

    /// :nodoc:
    public func write<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.write(block)
    }
    
    /// :nodoc:
    public func writeWithoutTransaction<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try base.writeWithoutTransaction(block)
    }

    /// :nodoc:
    public func unsafeReentrantWrite<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try base.unsafeReentrantWrite(block)
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
