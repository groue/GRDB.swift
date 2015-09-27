/// EXPERIMENTAL
public protocol DatabaseTransactionDelegate: class {
    // Notify a database change (insert, update or delete):
    func databaseDidChangeWithEvent(event: DatabaseEvent)
    
    // An opportunity to rollback previous changes:
    func databaseShouldCommit() -> Bool
    
    // Previous change will be committed:
    func databaseWillCommit()
    
    // Previous change will be rollbacked:
    func databaseWillRollback()
}

public extension DatabaseTransactionDelegate {
    func databaseDidChangeWithEvent(event: DatabaseEvent) { }
    func databaseShouldCommit() -> Bool { return true }
    func databaseWillCommit() { }
    func databaseWillRollback() { }
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
