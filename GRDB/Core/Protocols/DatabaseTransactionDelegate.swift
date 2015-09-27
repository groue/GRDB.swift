/// EXPERIMENTAL
public protocol DatabaseTransactionDelegate: class {
    func databaseDidChangeWithEvent(event: DatabaseEvent)
    func databaseShouldCommit() -> Bool
    func databaseWillCommit()
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
