public protocol MetalType {
    init(sqliteStatement: SQLiteStatement, index: Int32)
}

extension Int64 : MetalType {
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        self = sqlite3_column_int64(sqliteStatement, index)
    }
}
