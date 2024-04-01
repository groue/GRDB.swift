#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import Foundation

#warning("TODO: document")
final class StatementRow {
    private let statement: Statement
    private let sqliteStatement: SQLiteStatement
    private let lowercaseColumnIndexes: [String: Int]
    
    init(statement: Statement) {
        let sqliteStatement = statement.sqliteStatement
        
        self.statement = statement
        self.sqliteStatement = sqliteStatement
        
        // Optimize index(forColumn:)
        let lowercaseColumnNames = (0..<sqlite3_column_count(sqliteStatement))
            .map { String(cString: sqlite3_column_name(sqliteStatement, CInt($0))).lowercased() }
        self.lowercaseColumnIndexes = Dictionary(
            lowercaseColumnNames
                .enumerated()
                .map { ($0.element, $0.offset) },
            uniquingKeysWith: { (left, _) in left }) // keep leftmost indexes
    }
}

extension StatementRow: RowProtocol {
    typealias Index = RowIndex
    typealias Element = (String, DatabaseValue)
    
    var prefetchedRows: Row.PrefetchedRowsView {
        Row.PrefetchedRowsView()
    }
    
    #warning("TODO: wrong return type")
    func copy() -> Row {
        Row(copiedFromSQLiteStatement: sqliteStatement, statement: statement)
    }
    
    func _decode<Strategy: _RowDecodingStrategy>(
        with strategy: Strategy,
        atUncheckedIndex index: Int
    ) throws -> Strategy._RowDecodingOutput
    {
        let statementIndex = CInt(index)
        
        if sqlite3_column_type(sqliteStatement, statementIndex) == SQLITE_NULL {
            throw RowDecodingError.valueMismatch(
                Strategy._RowDecodingOutput.self,
                sqliteStatement: sqliteStatement,
                index: statementIndex,
                context: _makeRowDecodingContext(forKey: .columnIndex(index)))
        }
        
        return try strategy._decode(
            sqliteStatement: sqliteStatement,
            atUncheckedIndex: CInt(index),
            context: _makeRowDecodingContext(forKey: .columnIndex(index)))
    }

    func _decode<Value: DatabaseValueConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int
    ) throws -> Value
    {
        try Value._decode(
            databaseValue: _databaseValue(atUncheckedIndex: index),
            context: _makeRowDecodingContext(forKey: .columnIndex(index)))
    }

    func _fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int
    ) throws -> Value
    {
        try Value._fastDecode(
            sqliteStatement: sqliteStatement,
            atUncheckedIndex: CInt(index),
            context: _RowDecodingContext(statement: statement, index: index))
    }
    
    var _isFetched: Bool {
        true
    }
    
    func _scopes(prefetchedRows: Row.PrefetchedRowsView) -> Row.ScopesView {
        Row.ScopesView()
    }
    
    func _columnName(atUncheckedIndex index: Int) -> String {
        statement.columnNames[index]
    }
    
    func _hasNull(atUncheckedIndex index: Int) -> Bool {
        // Avoid extracting values, because this modifies the SQLite statement.
        sqlite3_column_type(sqliteStatement, CInt(index)) == SQLITE_NULL
    }
    
    func _databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        DatabaseValue(sqliteStatement: sqliteStatement, index: CInt(index))
    }
    
    func _withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T {
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
    
    #warning("TODO: wrong return type")
    var _unscopedRow: Row {
        copy()
    }
    
    #warning("TODO: wrong return type")
    var _unadaptedRow: Row {
        copy()
    }
    
    #warning("TODO: wrong return type")
    var _copiedRow: Row {
        copy()
    }
    
    func _makeRowDecodingContext(forKey key: _RowKey?) -> _RowDecodingContext {
        _RowDecodingContext(
            row: copy(),
            key: key,
            sql: statement.sql,
            statementArguments: statement.arguments)
    }
    
    func index(forColumn name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercased()]
    }
}
