// Import C SQLite functions
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import Foundation

// The protocol for Row underlying implementation
protocol RowImpl {
    var count: Int { get }
    var isFetched: Bool { get }
    
    func scopes(prefetchedRows: Row.PrefetchedRowsView) -> Row.ScopesView
    func columnName(atUncheckedIndex index: Int) -> String
    func hasNull(atUncheckedIndex index: Int) -> Bool
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value
    
    func withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T
    
    /// Returns the index of the leftmost column that matches *name* (case-insensitive)
    func index(forColumn name: String) -> Int?
    
    // row.impl is guaranteed to be self.
    func unscopedRow(_ row: Row) -> Row
    func unadaptedRow(_ row: Row) -> Row
    func copiedRow(_ row: Row) -> Row
}

extension RowImpl {
    func copiedRow(_ row: Row) -> Row {
        // unless customized, assume unsafe and unadapted row
        Row(impl: ArrayRowImpl(columns: Array(row)))
    }
    
    func unscopedRow(_ row: Row) -> Row {
        // unless customized, assume unadapted row (see AdaptedRowImpl for customization)
        row
    }
    
    func unadaptedRow(_ row: Row) -> Row {
        // unless customized, assume unadapted row (see AdaptedRowImpl for customization)
        row
    }
    
    func scopes(prefetchedRows: Row.PrefetchedRowsView) -> Row.ScopesView {
        // unless customized, assume unuscoped row (see AdaptedRowImpl for customization)
        Row.ScopesView()
    }
    
    func hasNull(atUncheckedIndex index: Int) -> Bool {
        // unless customized, use slow check (see StatementRowImpl and AdaptedRowImpl for customization)
        databaseValue(atUncheckedIndex: index).isNull
    }
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value
    {
        // unless customized, use slow decoding (see StatementRowImpl and AdaptedRowImpl for customization)
        try Value.decode(
            fromDatabaseValue: databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: Row(impl: self), key: .columnIndex(index)))
    }
    
    func withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T {
        // unless customized, copy data (see StatementRowImpl and AdaptedRowImpl for customization)
        let data = try Optional<Data>.decode(
            fromDatabaseValue: databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: Row(impl: self), key: .columnIndex(index)))
        return try body(data)
    }
}

// TODO: merge with StatementCopyRowImpl eventually?
/// See Row.init(dictionary:)
struct ArrayRowImpl: RowImpl {
    let columns: [(String, DatabaseValue)]
    
    init<Columns>(columns: Columns)
    where Columns: Collection, Columns.Element == (String, DatabaseValue)
    {
        self.columns = Array(columns)
    }
    
    var count: Int { columns.count }
    
    var isFetched: Bool { false }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        columns[index].1
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        columns[index].0
    }
    
    func index(forColumn name: String) -> Int? {
        let lowercaseName = name.lowercased()
        return columns.firstIndex { (column, _) in column.lowercased() == lowercaseName }
    }
    
    func copiedRow(_ row: Row) -> Row {
        row
    }
}

extension ArrayRowImpl: Sendable { }

// TODO: merge with ArrayRowImpl eventually?
/// See Row.init(copiedFromStatementRef:sqliteStatement:)
struct StatementCopyRowImpl: RowImpl {
    let dbValues: ContiguousArray<DatabaseValue>
    let columnNames: [String]
    
    init(sqliteStatement: SQLiteStatement, columnNames: [String]) {
        let sqliteStatement = sqliteStatement
        self.dbValues = ContiguousArray(
            (0..<sqlite3_column_count(sqliteStatement))
                .map { DatabaseValue(sqliteStatement: sqliteStatement, index: $0) }
                as [DatabaseValue])
        self.columnNames = columnNames
    }
    
    var count: Int { columnNames.count }
    
    var isFetched: Bool { true }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        dbValues[index]
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        columnNames[index]
    }
    
    func index(forColumn name: String) -> Int? {
        let lowercaseName = name.lowercased()
        return columnNames.firstIndex { $0.lowercased() == lowercaseName }
    }
    
    func copiedRow(_ row: Row) -> Row {
        row
    }
}

/// See Row.init(statement:)
struct StatementRowImpl: RowImpl {
    let statement: Statement
    let sqliteStatement: SQLiteStatement
    let lowercaseColumnIndexes: [String: Int]
    
    init(sqliteStatement: SQLiteStatement, statement: Statement) {
        self.statement = statement
        self.sqliteStatement = sqliteStatement
        // Optimize row[columnName]
        let lowercaseColumnNames = (0..<sqlite3_column_count(sqliteStatement))
            .map { String(cString: sqlite3_column_name(sqliteStatement, CInt($0))).lowercased() }
        self.lowercaseColumnIndexes = Dictionary(
            lowercaseColumnNames
                .enumerated()
                .map { ($0.element, $0.offset) },
            uniquingKeysWith: { (left, _) in left }) // keep leftmost indexes
    }
    
    var count: Int {
        Int(sqlite3_column_count(sqliteStatement))
    }
    
    var isFetched: Bool { true }
    
    func hasNull(atUncheckedIndex index: Int) -> Bool {
        // Avoid extracting values, because this modifies the SQLite statement.
        sqlite3_column_type(sqliteStatement, CInt(index)) == SQLITE_NULL
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        DatabaseValue(sqliteStatement: sqliteStatement, index: CInt(index))
    }
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value
    {
        try Value.fastDecode(
            fromStatement: sqliteStatement,
            atUncheckedIndex: CInt(index),
            context: RowDecodingContext(statement: statement, index: index))
    }
    
    func withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T {
        guard sqlite3_column_type(sqliteStatement, CInt(index)) != SQLITE_NULL else {
            return try body(nil)
        }
        guard let bytes = sqlite3_column_blob(sqliteStatement, CInt(index)) else {
            return try body(Data())
        }
        
        let count = Int(sqlite3_column_bytes(sqliteStatement, CInt(index)))
        let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes), count: count, deallocator: .none)
        return try body(data)
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        statement.columnNames[index]
    }
    
    func index(forColumn name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercased()]
    }
    
    func copiedRow(_ row: Row) -> Row {
        Row(copiedFromSQLiteStatement: sqliteStatement, statement: statement)
    }
}

// This one is not optimized at all, since it is only used in fatal conversion errors, so far
struct SQLiteStatementRowImpl: RowImpl {
    let sqliteStatement: SQLiteStatement
    var count: Int { Int(sqlite3_column_count(sqliteStatement)) }
    var isFetched: Bool { true }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        String(cString: sqlite3_column_name(sqliteStatement, CInt(index)))
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        DatabaseValue(sqliteStatement: sqliteStatement, index: CInt(index))
    }
    
    func index(forColumn name: String) -> Int? {
        let name = name.lowercased()
        for index in 0..<count where columnName(atUncheckedIndex: index).lowercased() == name {
            return index
        }
        return nil
    }
}

/// See Row.init()
struct EmptyRowImpl: RowImpl {
    var count: Int { 0 }
    
    var isFetched: Bool { false }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        // Programmer error
        fatalError("row index out of range")
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        // Programmer error
        fatalError("row index out of range")
    }
    
    func index(forColumn name: String) -> Int? { nil }
    
    func copiedRow(_ row: Row) -> Row { row }
}
