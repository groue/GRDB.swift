/**
The transaction delegate of a database is notified of all changes and
transactions committed or rollbacked on a database.
*/
public protocol DatabaseTransactionDelegate: class {
    
    /**
    Notifies a database change (insert, update, or delete).
    
    The change is pending until the end of the current transaction, notified to
    databaseShouldCommit(_), databaseDidCommit(_) and databaseDidRollback(_).
    
    This method is called on the database queue.
    
    **WARNING**: this method must not change the database.
    
    - parameter db: A Database.
    - parameter event: A database event.
    */
    func database(db: Database, didChangeWithEvent event: DatabaseEvent)
    
    /**
    When a transaction is about to be committed, the transaction delegate has an
    opportunity to rollback pending changes.
    
    This method is called on the database queue.
    
    **WARNING**: this method must not change the database.
    
    - parameter db: A Database.
    - returns: Whether the transaction should be committed.
    */
    func databaseShouldCommit(db: Database) -> Bool
    
    /**
    Database changes have been committed.
    
    This method is called on the database queue. It can change the database.
    
    - parameter db: A Database.
    */
    func databaseDidCommit(db: Database)
    
    
    /**
    Database changes have been rollbacked.
    
    This method is called on the database queue. It can change the database.
    
    - parameter db: A Database.
    */
    func databaseDidRollback(db: Database)
}

public extension DatabaseTransactionDelegate {
    func database(db: Database, didChangeWithEvent event: DatabaseEvent) { }
    func databaseShouldCommit(db: Database) -> Bool { return true }
    func databaseDidCommit(db: Database) { }
    func databaseDidRollback(db: Database) { }
}

public struct DatabaseEvent {
    public enum Kind: Int32 {
        case Insert = 18    // SQLITE_INSERT
        case Delete = 9     // SQLITE_DELETE
        case Update = 23    // SQLITE_UPDATE
    }
    
    public let kind: Kind
    public let databaseName: String
    public let tableName: String
    public let rowID: Int64
}
