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
    ///             try db.execute("DELETE FROM persons")
    ///             try writer.readFromCurrentState { db in
    ///                 // Guaranteed to be zero
    ///                 try Int.fetchOne(db, "SELECT COUNT(*) FROM persons")!
    ///             }
    ///             try db.execute("INSERT INTO persons ...")
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
    ///             try db.execute("DELETE FROM persons")
    ///             db.inTransaction {
    ///                 try db.execute("INSERT INTO persons ...")
    ///                 try dbPool.readFromCurrentState { db in
    ///                     // Zero
    ///                     try Int.fetchOne(db, "SELECT COUNT(*) FROM persons")!
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
    ///             try db.execute("DELETE FROM persons")
    ///             db.inTransaction {
    ///                 try db.execute("INSERT INTO persons ...")
    ///                 try dbQueue.readFromCurrentState { db in
    ///                     // One
    ///                     try Int.fetchOne(db, "SELECT COUNT(*) FROM persons")!
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
    /// The transaction observer is weakly referenced: it is not retained, and
    /// stops getting notifications after it is deallocated.
    ///
    /// - parameter transactionObserver: A transaction observer.
    public func add(transactionObserver: TransactionObserver) {
        write { $0.add(transactionObserver: transactionObserver) }
    }
    
    /// Remove a transaction observer.
    public func remove(transactionObserver: TransactionObserver) {
        write { $0.remove(transactionObserver: transactionObserver) }
    }
}
