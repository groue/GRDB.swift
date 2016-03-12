/// The protocol for all types that can update a database.
///
/// It is adopted by DatabaseQueue, DatabasePool, and Database.
///
///     let person = Person(...)
///     try person.insert(dbQueue)
///     try person.insert(dbPool)
///     try dbQueue.inDatabase { db in
///         try person.insert(db)
///     }
public protocol DatabaseWriter : DatabaseReader {
    
    // MARK: - Writing in Database
    
    /// Synchronously executes a block that takes a database connection, and
    /// returns its result.
    ///
    /// The block argument can be fully executed in isolation of eventual
    /// concurrent updates.
    func write<T>(block: (db: Database) throws -> T) rethrows -> T
}

extension DatabaseWriter {
    
    // MARK: - Writing in Database
    
    /// Executes one or several SQL statements, separated by semi-colons.
    ///
    ///     try writer.execute(
    ///         "INSERT INTO persons (name) VALUES (:name)",
    ///         arguments: ["name": "Arthur"])
    ///
    ///     try writer.execute(
    ///         "INSERT INTO persons (name) VALUES (?);" +
    ///         "INSERT INTO persons (name) VALUES (?);" +
    ///         "INSERT INTO persons (name) VALUES (?);",
    ///         arguments; ['Arthur', 'Barbara', 'Craig'])
    ///
    /// This method may throw a DatabaseError.
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    /// - returns: A DatabaseChanges.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(sql: String, arguments: StatementArguments? = nil) throws -> DatabaseChanges {
        return try write { db in
            try db.execute(sql, arguments: arguments)
        }
    }
    
    
    // MARK: - Transaction Observers
    
    /// Add a transaction observer, so that it gets notified of all
    /// database changes.
    ///
    /// The transaction observer is weakly referenced: it is not retained, and
    /// stops getting notifications after it is deallocated.
    public func addTransactionObserver(transactionObserver: TransactionObserverType) {
        write { db in
            db.addTransactionObserver(transactionObserver)
        }
    }
    
    /// Remove a transaction observer.
    public func removeTransactionObserver(transactionObserver: TransactionObserverType) {
        write { db in
            db.removeTransactionObserver(transactionObserver)
        }
    }
}
