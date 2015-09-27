/// EXPERIMENTAL
public protocol DatabaseTransactionDelegate: class {
    // Notify a database change (insert, update or delete):
    func databaseDidChangeWithEvent(event: DatabaseEvent)
    
    // An opportunity to rollback database changes:
    func databaseShouldCommit() -> Bool
    
    // Database changes have been committed:
    func databaseDidCommit()
    
    // Database changes have been rollbacked:
    func databaseDidRollback()
}

public extension DatabaseTransactionDelegate {
    func databaseDidChangeWithEvent(event: DatabaseEvent) { }
    func databaseShouldCommit() -> Bool { return true }
    func databaseDidCommit() { }
    func databaseDidRollback() { }
}

/// EXPERIMENTAL
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
