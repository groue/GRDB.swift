/**
When a type adopts both DatabaseValueConvertible and MetalType, it is granted
with faster access to the SQLite database values.
*/
public protocol MetalType {
    
    /**
    Returns an instance initialized from a raw SQLite statement pointer.
    
    As an example, here is the how Int64 adopts MetalType:
    
        extension Int64: MetalType {
            public init(sqliteStatement: SQLiteStatement, index: Int32) {
                self = sqlite3_column_int64(sqliteStatement, index)
            }
        }
    
    Implement this method in an optimistic mind: don't check for NULL, don't
    check for type mismatch.
    
    See https://www.sqlite.org/c3ref/column_blob.html for more information.
    
    - parameter sqliteStatement: A pointer to a SQLite statement.
    - parameter index: The column index.
    */
    init(sqliteStatement: SQLiteStatement, index: Int32)
}
