/**
TODO
*/
public protocol MetalType {
    
    /**
    Returns an instance initialized from a raw SQLite statement pointer.
    
    - parameter sqliteStatement: A pointer to a SQLite statement.
    - parameter index: The column index.
    */
    init(sqliteStatement: SQLiteStatement, index: Int32)
    
}
