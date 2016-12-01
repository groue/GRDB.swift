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
    /// The *block* argument is completely isolated. Eventual concurrent
    /// database updates are postponed until the block has executed.
    func write<T>(_ block: (Database) throws -> T) throws -> T
    
    
    /// Synchronously executes a block in a protected dispatch queue, wrapped
    /// inside a transaction.
    ///
    /// If the block throws an error, the transaction is rollbacked and the
    /// error is rethrown.
    ///
    ///     try writer.writeInTransaction { db in
    ///         db.execute(...)
    ///         return .commit
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameters:
    ///     - kind: The transaction type.
    ///       See https://www.sqlite.org/lang_transaction.html for more information.
    ///     - block: A block that executes SQL statements and return either
    ///       .commit or .rollback.
    /// - throws: The error thrown by the block.
    func writeInTransaction(_ kind: Database.TransactionKind?, _ block: (Database) throws -> Database.TransactionCompletion) throws
    
    /// Synchronously executes a block that takes a database connection, and
    /// returns its result.
    ///
    /// The *block* argument is completely isolated: eventual concurrent
    /// database updates are postponed until the block has executed.
    ///
    /// However, this method poses a threat to concurrent reads if it modifies
    /// the database. Readers may seen the database in a constant, but
    /// inconsistent state:
    ///
    ///     writer.unsafeWrite { db in
    ///         // Preserve a zero balance
    ///         try db.execute(db, "INSERT INTO credits ...", arguments: [amount])
    ///         try db.execute(db, "INSERT INTO debits ...", arguments: [amount])
    ///     }
    ///
    ///     writer.read { db in
    ///         // Here the balance may not be zero
    ///     }
    ///
    func unsafeWrite<T>(_ block: (Database) throws -> T) rethrows -> T
    
    
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
    func readFromCurrentState(_ block: @escaping (Database) -> Void) throws
}

extension DatabaseWriter {
    
    /// Default implementation for DatabaseWriter.write(). Synchronously
    /// executes an update block in a protected dispatch queue,
    /// wrapped inside a deferred transaction, and returns its result.
    ///
    ///     try dbPool.write { db in
    ///         try db.execute(...)
    ///     }
    ///
    /// This method is *not* reentrant.
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    public func write<T>(_ block: (Database) throws -> T) throws -> T {
        var result: T! = nil
        try writeInTransaction(.deferred) { db in
            result = try block(db)
            return .commit
        }
        return result!
    }
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
        unsafeWrite { db in
            db.add(transactionObserver: transactionObserver)
        }
    }
    
    /// Remove a transaction observer.
    public func remove(transactionObserver: TransactionObserver) {
        unsafeWrite { db in
            db.remove(transactionObserver: transactionObserver)
        }
    }
}
