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
    func write<T>(_ block: (Database) throws -> T) rethrows -> T
    
    
    // MARK: - Reading from Database
    
    /// Synchronously or asynchronously executes a read-only block that takes a
    /// database connection.
    ///
    /// This method must be called from a writing dispatch queue.
    ///
    /// The *block* argument is guaranteed to see the database in the state it
    /// has at the moment this method is called. Eventual concurrent
    /// database updates are *not visible* inside the block.
    ///
    ///     try writer.write { db in
    ///         try db.execute("DELETE FROM persons")
    ///         writer.readFromWrite { db in
    ///             // Guaranteed to be zero
    ///             Int.fetchOne(db, "SELECT COUNT(*) FROM persons")!
    ///         }
    ///         try db.execute("INSERT INTO persons ...")
    ///     }
    ///
    /// DatabasePool.readFromWrite runs *block* asynchronously in a concurrent
    /// reader dispatch queue, and release the writing dispatch queue early,
    /// before the block has finished. In the example above, the insertion runs
    /// concurrently with the select (and yet the select is guaranteed not to
    /// see the insertion).
    ///
    /// DatabaseQueue.readFromWrite simply runs *block* synchronously, and
    /// returns when the block has completed. In the example above, the
    /// insertion is run after the select.
    func readFromWrite(_ block: @escaping (Database) -> Void)
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
        write { db in
            db.add(transactionObserver: transactionObserver)
        }
    }
    
    /// Remove a transaction observer.
    public func remove(transactionObserver: TransactionObserver) {
        write { db in
            db.remove(transactionObserver: transactionObserver)
        }
    }
}

extension DatabaseWriter {
    // Addresses https://github.com/groue/GRDB.swift/issues/117 and
    // https://bugs.swift.org/browse/SR-2623
    //
    // This method allows avoiding calling the regular rethrowing `write(_:)`
    // method from a property of type DatabaseWriter, and crashing the Swift 3
    // compiler of Xcode 8 GM Version 8.0 (8A218a)
    func writeForIssue117(_ block: (Database) -> Void) -> Void {
        write(block)
    }
}
