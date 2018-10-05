import Foundation
#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// A database row.
public final class Row : Equatable, Hashable, RandomAccessCollection, ExpressibleByDictionaryLiteral, CustomStringConvertible, CustomDebugStringConvertible {
    // It is not a violation of the Demeter law when another type uses this
    // property, which is exposed for optimizations.
    let impl: RowImpl
    
    /// Unless we are producing a row array, we use a single row when iterating
    /// a statement:
    ///
    ///     let rows = try Row.fetchCursor(db, "SELECT ...")
    ///     let players = try Player.fetchAll(db, "SELECT ...")
    ///
    /// This row keeps an unmanaged reference to the statement, and a handle to
    /// the sqlite statement, so that we avoid many retain/release invocations.
    ///
    /// The statementRef is released in deinit.
    let statementRef: Unmanaged<SelectStatement>?
    let sqliteStatement: SQLiteStatement?
    var statement: SelectStatement? {
        return statementRef?.takeUnretainedValue()
    }
    
    /// The number of columns in the row.
    public let count: Int

    // MARK: - Building rows
    
    /// Creates an empty row.
    public convenience init() {
        self.init(impl: EmptyRowImpl())
    }
    
    /// Creates a row from a dictionary of values.
    public convenience init(_ dictionary: [String: DatabaseValueConvertible?]) {
        self.init(impl: ArrayRowImpl(columns: dictionary.map { ($0, $1?.databaseValue ?? .null) }))
    }
    
    /// Creates a row from [AnyHashable: Any].
    ///
    /// The result is nil unless all dictionary keys are strings, and values
    /// adopt DatabaseValueConvertible.
    public convenience init?(_ dictionary: [AnyHashable: Any]) {
        var initDictionary = [String: DatabaseValueConvertible?]()
        for (key, value) in dictionary {
            guard let columnName = key as? String else {
                return nil
            }
            guard let dbValue = DatabaseValue(value: value) else {
                return nil
            }
            initDictionary[columnName] = dbValue
        }
        self.init(initDictionary)
    }
    
    /// Returns an immutable copy of the row.
    ///
    /// For performance reasons, rows fetched from a cursor are reused during
    /// the iteration of a query: make sure to make a copy of it whenever you
    /// want to keep a specific one: `row.copy()`.
    public func copy() -> Row {
        return impl.copiedRow(self)
    }
    
    // MARK: - Not Public
    
    /// Returns true if and only if the row was fetched from a database.
    var isFetched: Bool {
        return impl.isFetched
    }
    
    deinit {
        statementRef?.release()
    }
    
    /// Creates a row that maps an SQLite statement. Further calls to
    /// sqlite3_step() modify the row.
    ///
    /// The row is implemented on top of StatementRowImpl, which grants *direct*
    /// access to the SQLite statement. Iteration of the statement does modify
    /// the row.
    init(statement: SelectStatement) {
        let statementRef = Unmanaged.passRetained(statement) // released in deinit
        self.statementRef = statementRef
        self.sqliteStatement = statement.sqliteStatement
        self.impl = StatementRowImpl(sqliteStatement: statement.sqliteStatement, statementRef: statementRef)
        self.count = Int(sqlite3_column_count(sqliteStatement))
    }
    
    /// Creates a row that maps an SQLite statement. Further calls to
    /// sqlite3_step() modify the row.
    init(sqliteStatement: SQLiteStatement) {
        self.sqliteStatement = sqliteStatement
        self.statementRef = nil
        self.impl = SQLiteStatementRowImpl(sqliteStatement: sqliteStatement)
        self.count = Int(sqlite3_column_count(sqliteStatement))
    }
    
    /// Creates a row that contain a copy of the current state of the
    /// SQLite statement. Further calls to sqlite3_step() do not modify the row.
    ///
    /// The row is implemented on top of StatementCopyRowImpl, which *copies*
    /// the values from the SQLite statement so that further iteration of the
    /// statement does not modify the row.
    convenience init(copiedFromSQLiteStatement sqliteStatement: SQLiteStatement, statementRef: Unmanaged<SelectStatement>) {
        self.init(impl: StatementCopyRowImpl(sqliteStatement: sqliteStatement, columnNames: statementRef.takeUnretainedValue().columnNames))
    }
    
    init(impl: RowImpl) {
        self.impl = impl
        self.count = impl.count
        self.statementRef = nil
        self.sqliteStatement = nil
    }
}

extension Row {

    // MARK: - Columns
    
    /// The names of columns in the row.
    ///
    /// Columns appear in the same order as they occur as the `.0` member
    /// of column-value pairs in `self`.
    public var columnNames: LazyMapCollection<Row, String> {
        return lazy.map { $0.0 }
    }
    
    /// Returns true if and only if the row has that column.
    ///
    /// This method is case-insensitive.
    public func hasColumn(_ columnName: String) -> Bool {
        return index(ofColumn: columnName) != nil
    }
    
    @inline(__always)
    func index(ofColumn name: String) -> Int? {
        return impl.index(ofColumn: name)
    }
}

extension Row {
    
    // MARK: - Extracting Values
    
    /// Fatal errors if index is out of bounds
    @inline(__always)
    private func checkIndex(_ index: Int, file: StaticString = #file, line: UInt = #line) {
        GRDBPrecondition(index >= 0 && index < count, "row index out of range", file: file, line: line)
    }
    
    /// Returns true if and only if one column contains a non-null value, or if
    /// the row was fetched with a row adapter that defines a scoped row that
    /// contains a non-null value.
    ///
    /// For example:
    ///
    ///     let row = try Row.fetchOne(db, "SELECT 'foo', 1")!
    ///     row.containsNonNullValue // true
    ///
    ///     let row = try Row.fetchOne(db, "SELECT NULL, NULL")!
    ///     row.containsNonNullValue // false
    public var containsNonNullValue: Bool {
        for i in (0..<count) where !impl.hasNull(atUncheckedIndex: i) {
            return true
        }
        
        for (_, scopedRow) in scopes where scopedRow.containsNonNullValue {
            return true
        }
        
        return false
    }
    
    /// Returns true if the row contains null at given index.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// This method is equivalent to `row[index] == nil`, but may be preferred
    /// in performance-critical code because it can avoid decoding database
    /// values.
    public func hasNull(atIndex index: Int) -> Bool {
        checkIndex(index)
        return impl.hasNull(atUncheckedIndex: index)
    }
    
    /// Returns Int64, Double, String, Data or nil, depending on the value
    /// stored at the given index.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    public subscript(_ index: Int) -> DatabaseValueConvertible? {
        checkIndex(index)
        return impl.databaseValue(atUncheckedIndex: index).storage.value
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// If the SQLite value is NULL, the result is nil. Otherwise the SQLite
    /// value is converted to the requested type `Value`. Should this conversion
    /// fail, a fatal error is raised.
    public subscript<Value: DatabaseValueConvertible>(_ index: Int) -> Value? {
        checkIndex(index)
        return Value.decodeIfPresent(from: self, atUncheckedIndex: index)
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// If the SQLite value is NULL, the result is nil. Otherwise the SQLite
    /// value is converted to the requested type `Value`. Should this conversion
    /// fail, a fatal error is raised.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// StatementColumnConvertible. It *may* trigger SQLite built-in conversions
    /// (see https://www.sqlite.org/datatype3.html).
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ index: Int) -> Value? {
        checkIndex(index)
        return Value.fastDecodeIfPresent(from: self, atUncheckedIndex: index)
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    public subscript<Value: DatabaseValueConvertible>(_ index: Int) -> Value {
        checkIndex(index)
        return Value.decode(from: self, atUncheckedIndex: index)
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// StatementColumnConvertible. It *may* trigger SQLite built-in conversions
    /// (see https://www.sqlite.org/datatype3.html).
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ index: Int) -> Value {
        checkIndex(index)
        return Value.fastDecode(from: self, atUncheckedIndex: index)
    }
    
    /// Returns Int64, Double, String, Data or nil, depending on the value
    /// stored at the given column.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// The result is nil if the row does not contain the column.
    public subscript(_ columnName: String) -> DatabaseValueConvertible? {
        // IMPLEMENTATION NOTE
        // This method has a single know use case: checking if the value is nil,
        // as in:
        //
        //     if row["foo"] != nil { ... }
        //
        // Without this method, the code above would not compile.
        guard let index = index(ofColumn: columnName) else {
            return nil
        }
        return impl.databaseValue(atUncheckedIndex: index).storage.value
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. Otherwise the SQLite value is converted to the requested type
    /// `Value`. Should this conversion fail, a fatal error is raised.
    public subscript<Value: DatabaseValueConvertible>(_ columnName: String) -> Value? {
        guard let index = index(ofColumn: columnName) else {
            return nil
        }
        return Value.decodeIfPresent(from: self, atUncheckedIndex: index)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. Otherwise the SQLite value is converted to the requested type
    /// `Value`. Should this conversion fail, a fatal error is raised.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// StatementColumnConvertible. It *may* trigger SQLite built-in conversions
    /// (see https://www.sqlite.org/datatype3.html).
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ columnName: String) -> Value? {
        guard let index = index(ofColumn: columnName) else {
            return nil
        }
        return Value.fastDecodeIfPresent(from: self, atUncheckedIndex: index)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the row does not contain the column, a fatal error is raised.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    public subscript<Value: DatabaseValueConvertible>(_ columnName: String) -> Value {
        guard let index = index(ofColumn: columnName) else {
            // No such column
            fatalConversionError(
                to: Value.self,
                from: nil,
                conversionContext: ValueConversionContext(self).atColumn(columnName))
        }
        return Value.decode(from: self, atUncheckedIndex: index)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the row does not contain the column, a fatal error is raised.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// StatementColumnConvertible. It *may* trigger SQLite built-in conversions
    /// (see https://www.sqlite.org/datatype3.html).
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ columnName: String) -> Value {
        guard let index = index(ofColumn: columnName) else {
            // No such column
            fatalConversionError(
                to: Value.self,
                from: nil,
                conversionContext: ValueConversionContext(self).atColumn(columnName))
        }
        return Value.fastDecode(from: self, atUncheckedIndex: index)
    }
    
    /// Returns Int64, Double, String, NSData or nil, depending on the value
    /// stored at the given column.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// The result is nil if the row does not contain the column.
    public subscript(_ column: ColumnExpression) -> DatabaseValueConvertible? {
        return self[column.name]
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. Otherwise the SQLite value is converted to the requested type
    /// `Value`. Should this conversion fail, a fatal error is raised.
    public subscript<Value: DatabaseValueConvertible>(_ column: ColumnExpression) -> Value? {
        return self[column.name]
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. Otherwise the SQLite value is converted to the requested type
    /// `Value`. Should this conversion fail, a fatal error is raised.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// StatementColumnConvertible. It *may* trigger SQLite built-in conversions
    /// (see https://www.sqlite.org/datatype3.html).
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ column: ColumnExpression) -> Value? {
        return self[column.name]
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the row does not contain the column, a fatal error is raised.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    public subscript<Value: DatabaseValueConvertible>(_ column: ColumnExpression) -> Value {
        return self[column.name]
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the row does not contain the column, a fatal error is raised.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// StatementColumnConvertible. It *may* trigger SQLite built-in conversions
    /// (see https://www.sqlite.org/datatype3.html).
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ column: ColumnExpression) -> Value {
        return self[column.name]
    }
    
    /// Returns the optional Data at given index.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// If the SQLite value is NULL, the result is nil. If the SQLite value can
    /// not be converted to Data, a fatal error is raised.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    public func dataNoCopy(atIndex index: Int) -> Data? {
        checkIndex(index)
        return impl.dataNoCopy(atUncheckedIndex: index)
    }
    
    /// Returns the optional Data at given column.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. If the SQLite value can not be converted to Data, a fatal error
    /// is raised.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    public func dataNoCopy(named columnName: String) -> Data? {
        guard let index = index(ofColumn: columnName) else {
            return nil
        }
        return impl.dataNoCopy(atUncheckedIndex: index)
    }
    
    /// Returns the optional `NSData` at given column.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. If the SQLite value can not be converted to NSData, a fatal error
    /// is raised.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    public func dataNoCopy(_ column: ColumnExpression) -> Data? {
        return dataNoCopy(named: column.name)
    }
}

extension Row {
    
    // MARK: - Extracting DatabaseValue
    
    /// The database values in the row.
    ///
    /// Values appear in the same order as they occur as the `.1` member
    /// of column-value pairs in `self`.
    public var databaseValues: LazyMapCollection<Row, DatabaseValue> {
        return lazy.map { $0.1 }
    }
}

extension Row {
    
    // MARK: - Extracting Records
    
    /// Returns the record encoded in the given scope.
    ///
    /// A fatal error is raised in the row was not fetched with a row adapter
    /// that defines this scope.
    ///
    /// See https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support
    /// for more information.
    public subscript<Record: FetchableRecord>(_ scope: String) -> Record {
        guard let scopedRow = scopesTree[scope] else {
            // Programmer error
            fatalError("no such scope: \(scope)")
        }
        return Record(row: scopedRow)
    }

    /// Returns the record encoded in the given scope, if and only if the scope
    /// has been defined by a row adapter, and the scoped row contains a
    /// non-null value. Otherwise, return nil.
    ///
    /// This subscript is designed to handle left joined records.
    ///
    /// See https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support
    /// for more information.
    public subscript<Record: FetchableRecord>(_ scope: String) -> Record? {
        guard let scopedRow = scopesTree[scope], scopedRow.containsNonNullValue else {
            return nil
        }
        return Record(row: scopedRow)
    }
}

extension Row {
    
    // MARK: - Scopes
    
    /// Returns a view on the scopes defined by row adapters.
    ///
    /// For example:
    ///
    ///     // Define a tree of nested scopes
    ///     let adapter = ScopeAdapter([
    ///         "foo": RangeRowAdapter(0..<1),
    ///         "bar": RangeRowAdapter(1..<2).addingScopes([
    ///             "baz" : RangeRowAdapter(2..<3)])])
    ///
    ///     // Fetch
    ///     let sql = "SELECT 1 AS foo, 2 AS bar, 3 AS baz"
    ///     let row = try Row.fetchOne(db, sql, adapter: adapter)!
    ///
    ///     row.scopes.count  // 2
    ///     row.scopes.names  // ["foo", "bar"]
    ///
    ///     row.scopes["foo"] // [foo:1]
    ///     row.scopes["bar"] // [bar:2]
    ///     row.scopes["baz"] // nil
    public var scopes: ScopesView {
        return impl.scopes
    }
    
    /// Returns a view on the scopes tree defined by row adapters.
    ///
    /// For example:
    ///
    ///     // Define a tree of nested scopes
    ///     let adapter = ScopeAdapter([
    ///         "foo": RangeRowAdapter(0..<1),
    ///         "bar": RangeRowAdapter(1..<2).addingScopes([
    ///             "baz" : RangeRowAdapter(2..<3)])])
    ///
    ///     // Fetch
    ///     let sql = "SELECT 1 AS foo, 2 AS bar, 3 AS baz"
    ///     let row = try Row.fetchOne(db, sql, adapter: adapter)!
    ///
    ///     row.scopesTree.names  // ["foo", "bar", "baz"]
    ///
    ///     row.scopesTree["foo"] // [foo:1]
    ///     row.scopesTree["bar"] // [bar:2]
    ///     row.scopesTree["baz"] // [baz:3]
    public var scopesTree: ScopesTreeView {
        return ScopesTreeView(scopes: scopes)
    }
    
    /// Returns a copy of the row, without any scopes.
    ///
    /// This property can turn out useful when you want to test the content of
    /// adapted rows, such as rows fetched from joined requests.
    ///
    ///     let row = ...
    ///     // Failure because row equality tests for row scopes:
    ///     XCTAssertEqual(row, ["id": 1, "name": "foo"])
    ///     // Success:
    ///     XCTAssertEqual(row.unscoped, ["id": 1, "name": "foo"])
    public var unscoped: Row {
        return impl.unscopedRow(self)
    }
    
    /// Return the raw row fetched from the database.
    ///
    /// This property can turn out useful when you debug the consumption of
    /// adapted rows, such as rows fetched from joined requests.
    public var unadapted: Row {
        return impl.unadaptedRow(self)
    }
}

/// A cursor of database rows. For example:
///
///     try dbQueue.read { db in
///         let rows: RowCursor = try Row.fetchCursor(db, "SELECT * FROM player")
///     }
public final class RowCursor : Cursor {
    public let statement: SelectStatement
    private let sqliteStatement: SQLiteStatement
    private let row: Row // Reused for performance
    private var done = false
    
    init(statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws {
        self.statement = statement
        self.row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        self.sqliteStatement = statement.sqliteStatement
        statement.reset(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? statement.reset()
    }
    
    /// :nodoc:
    public func next() throws -> Row? {
        if done {
            // make sure this instance never yields a value again, even if the
            // statement is reset by another cursor.
            return nil
        }
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE:
            done = true
            return nil
        case SQLITE_ROW:
            return row
        case let code:
            statement.database.selectStatementDidFail(statement)
            throw DatabaseError(resultCode: code, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments)
        }
    }
}

extension Row {
    
    // MARK: - Fetching From SelectStatement
    
    /// Returns a cursor over rows fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT ...")
    ///     let rows = try Row.fetchCursor(statement) // RowCursor
    ///     while let row = try rows.next() { // Row
    ///         let id: Int64 = row[0]
    ///         let name: String = row[1]
    ///     }
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> RowCursor {
        return try RowCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of rows fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT ...")
    ///     let rows = try Row.fetchAll(statement)
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Row] {
        // The cursor reuses a single mutable row. Return immutable copies.
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter).map { $0.copy() })
    }
    
    /// Returns a single row fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT ...")
    ///     let row = try Row.fetchOne(statement)
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Row? {
        let cursor = try fetchCursor(statement, arguments: arguments, adapter: adapter)
        // Keep cursor alive until we can copy the fetched row
        return try withExtendedLifetime(cursor) {
            try cursor.next().map { $0.copy() }
        }
    }
}

extension Row {
    
    // MARK: - Fetching From SQL
    
    /// Returns a cursor over rows fetched from an SQL query.
    ///
    ///     let rows = try Row.fetchCursor(db, "SELECT id, name FROM player") // RowCursor
    ///     while let row = try rows.next() { // Row
    ///         let id: Int64 = row[0]
    ///         let name: String = row[1]
    ///     }
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> RowCursor {
        return try fetchCursor(db, SQLRequest<Void>(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of rows fetched from an SQL query.
    ///
    ///     let rows = try Row.fetchAll(db, "SELECT ...")
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Row] {
        return try fetchAll(db, SQLRequest<Void>(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single row fetched from an SQL query.
    ///
    ///     let row = try Row.fetchOne(db, "SELECT ...")
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Row? {
        return try fetchOne(db, SQLRequest<Void>(sql, arguments: arguments, adapter: adapter))
    }
}

extension Row {
    
    // MARK: - Fetching From FetchRequest
    
    /// Returns a cursor over rows fetched from a fetch request.
    ///
    ///     let request = Player.all()
    ///     let rows = try Row.fetchCursor(db, request) // RowCursor
    ///     while let row = try rows.next() { // Row
    ///         let id: Int64 = row["id"]
    ///         let name: String = row["name"]
    ///     }
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor<R: FetchRequest>(_ db: Database, _ request: R) throws -> RowCursor {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    /// Returns an array of rows fetched from a fetch request.
    ///
    ///     let request = Player.all()
    ///     let rows = try Row.fetchAll(db, request)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An array of rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll<R: FetchRequest>(_ db: Database, _ request: R) throws -> [Row] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single row fetched from a fetch request.
    ///
    ///     let request = Player.filter(key: 1)
    ///     let row = try Row.fetchOne(db, request)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An optional row.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne<R: FetchRequest>(_ db: Database, _ request: R) throws -> Row? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

extension FetchRequest where RowDecoder: Row {
    
    // MARK: Fetching Rows
    
    /// A cursor over fetched rows.
    ///
    ///     let request: ... // Some TypedRequest that fetches Row
    ///     let rows = try request.fetchCursor(db) // RowCursor
    ///     while let row = try rows.next() {  // Row
    ///         let id: Int64 = row[0]
    ///         let name: String = row[1]
    ///     }
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RowCursor {
        return try Row.fetchCursor(db, self)
    }
    
    /// An array of fetched rows.
    ///
    ///     let request: ... // Some TypedRequest that fetches Row
    ///     let rows = try request.fetchAll(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [Row] {
        return try Row.fetchAll(db, self)
    }
    
    /// The first fetched row.
    ///
    ///     let request: ... // Some TypedRequest that fetches Row
    ///     let row = try request.fetchOne(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: A,n optional rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> Row? {
        return try Row.fetchOne(db, self)
    }
}
    
// ExpressibleByDictionaryLiteral
extension Row {
    
    /// Creates a row initialized with elements. Column order is preserved, and
    /// duplicated columns names are allowed.
    ///
    ///     let row: Row = ["foo": 1, "foo": "bar", "baz": nil]
    ///     print(row)
    ///     // Prints [foo:1 foo:"bar" baz:NULL]
    public convenience init(dictionaryLiteral elements: (String, DatabaseValueConvertible?)...) {
        self.init(impl: ArrayRowImpl(columns: elements.map { ($0, $1?.databaseValue ?? .null) }))
    }
}

// RandomAccessCollection
extension Row {
    
    // MARK: - Row as a Collection of (ColumnName, DatabaseValue) Pairs
    
    /// The index of the first (ColumnName, DatabaseValue) pair.
    /// :nodoc:
    public var startIndex: RowIndex {
        return Index(0)
    }
    
    /// The "past-the-end" index, successor of the index of the last
    /// (ColumnName, DatabaseValue) pair.
    /// :nodoc:
    public var endIndex: RowIndex {
        return Index(count)
    }
    
    /// Accesses the (ColumnName, DatabaseValue) pair at given index.
    public subscript(position: RowIndex) -> (String, DatabaseValue) {
        let index = position.index
        checkIndex(index)
        return (
            impl.columnName(atUncheckedIndex: index),
            impl.databaseValue(atUncheckedIndex: index))
    }
}

// Equatable
extension Row {
    
    /// Returns true if and only if both rows have the same columns and values,
    /// in the same order. Columns are compared in a case-sensitive way.
    /// :nodoc:
    public static func == (lhs: Row, rhs: Row) -> Bool {
        if lhs === rhs {
            return true
        }
        
        guard lhs.count == rhs.count else {
            return false
        }
        
        for ((lcol, lval), (rcol, rval)) in zip(lhs, rhs) {
            guard lcol == rcol else {
                return false
            }
            guard lval == rval else {
                return false
            }
        }
        
        let lscopeNames = lhs.scopes.names
        let rscopeNames = rhs.scopes.names
        guard lscopeNames == rscopeNames else {
            return false
        }
        
        for name in lscopeNames {
            let lscope = lhs.scopes[name]
            let rscope = rhs.scopes[name]
            guard lscope == rscope else {
                return false
            }
        }
        
        return true
    }
}

// Hashable
extension Row {
    #if swift(>=4.2)
    /// :nodoc:
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for (column, dbValue) in self {
            hasher.combine(column)
            hasher.combine(dbValue)
        }
    }
    #else
    /// :nodoc:
    public var hashValue: Int {
        return columnNames.reduce(0) { (acc, column) in acc ^ column.hashValue } ^
            databaseValues.reduce(0) { (acc, dbValue) in acc ^ dbValue.hashValue }
    }
    #endif
}

// CustomStringConvertible & CustomDebugStringConvertible
extension Row {
    /// :nodoc:
    public var description: String {
        return "["
            + map { (column, dbValue) in "\(column):\(dbValue)" }.joined(separator: " ")
            + "]"
    }
    
    /// :nodoc:
    public var debugDescription: String {
        return debugDescription(level: 0)
    }
    
    private func debugDescription(level: Int) -> String {
        if level == 0 && self == self.unadapted {
            return description
        }
        let prefix = repeatElement("  ", count: level + 1).joined(separator: "")
        var str = ""
        if level == 0 {
            str = "▿ " + description
            let unadapted = self.unadapted
            if self != unadapted {
                str += "\n" + prefix + "unadapted: " + unadapted.description
            }
        } else {
            str = description
        }
        for (name, scopedRow) in scopes.sorted(by: { $0.name < $1.name }) {
            str += "\n" + prefix + "- " + name + ": " + scopedRow.debugDescription(level: level + 1)
        }
        
        return str
    }
}


// MARK: - RowIndex

/// Indexes to (ColumnName, DatabaseValue) pairs in a database row.
public struct RowIndex : Comparable, Strideable {
    let index: Int
    init(_ index: Int) { self.index = index }
}

// Comparable
extension RowIndex {
    /// :nodoc:
    public static func == (lhs: RowIndex, rhs: RowIndex) -> Bool {
        return lhs.index == rhs.index
    }
    
    /// :nodoc:
    public static func < (lhs: RowIndex, rhs: RowIndex) -> Bool {
        return lhs.index < rhs.index
    }
}

// Strideable: support for Row: RandomAccessCollection
extension RowIndex {
    /// :nodoc:
    public func distance(to other: RowIndex) -> Int {
        return other.index - index
    }
    
    /// :nodoc:
    public func advanced(by n: Int) -> RowIndex {
        return RowIndex(index + n)
    }
}

// MARK: - Row.ScopesView

extension Row {
    /// A view of the scopes defined by row adapters. It is a collection of
    /// tuples made of a scope name and a scoped row, which behaves like a
    /// dictionary.
    ///
    /// For example:
    ///
    ///     // Define a tree of nested scopes
    ///     let adapter = ScopeAdapter([
    ///         "foo": RangeRowAdapter(0..<1),
    ///         "bar": RangeRowAdapter(1..<2).addingScopes([
    ///             "baz" : RangeRowAdapter(2..<3)])])
    ///
    ///     // Fetch
    ///     let sql = "SELECT 1 AS foo, 2 AS bar, 3 AS baz"
    ///     let row = try Row.fetchOne(db, sql, adapter: adapter)!
    ///
    ///     row.scopes.count  // 2
    ///     row.scopes.names  // ["foo", "bar"]
    ///
    ///     row.scopes["foo"] // [foo:1]
    ///     row.scopes["bar"] // [bar:2]
    ///     row.scopes["baz"] // nil
    public struct ScopesView: Collection {
        public typealias Index = Dictionary<String, LayoutedRowAdapter>.Index
        private let row: Row
        private let scopes: [String: LayoutedRowAdapter]
        
        /// The scopes defined on this row.
        public var names: Dictionary<String, LayoutedRowAdapter>.Keys {
            return scopes.keys
        }
        
        init() {
            self.init(row: Row(), scopes: [:])
        }
        
        init(row: Row, scopes: [String: LayoutedRowAdapter]) {
            self.row = row
            self.scopes = scopes
        }
        
        /// :nodoc:
        public var startIndex: Index {
            return scopes.startIndex
        }
        
        /// :nodoc:
        public var endIndex: Index {
            return scopes.endIndex
        }
        
        /// :nodoc:
        public func index(after i: Index) -> Index {
            return scopes.index(after: i)
        }
        
        /// :nodoc:
        public subscript(position: Index) -> (name: String, row: Row) {
            let (name, adapter) = scopes[position]
            return (name: name, row: Row(base: row, adapter: adapter))
        }
        
        /// Returns the row associated with the given scope, or nil if the
        /// scope is not defined.
        public subscript(_ name: String) -> Row? {
            guard let adapter = scopes[name] else {
                return nil
            }
            return Row(base: row, adapter: adapter)
        }
    }
}

// MARK: - Row.ScopesTreeView

extension Row {
    
    /// A view on the scopes tree defined by row adapters.
    ///
    /// For example:
    ///
    ///     // Define a tree of nested scopes
    ///     let adapter = ScopeAdapter([
    ///         "foo": RangeRowAdapter(0..<1),
    ///         "bar": RangeRowAdapter(1..<2).addingScopes([
    ///             "baz" : RangeRowAdapter(2..<3)])])
    ///
    ///     // Fetch
    ///     let sql = "SELECT 1 AS foo, 2 AS bar, 3 AS baz"
    ///     let row = try Row.fetchOne(db, sql, adapter: adapter)!
    ///
    ///     row.scopesTree.names  // ["foo", "bar", "baz"]
    ///
    ///     row.scopesTree["foo"] // [foo:1]
    ///     row.scopesTree["bar"] // [bar:2]
    ///     row.scopesTree["baz"] // [baz:3]
    public struct ScopesTreeView {
        let scopes: ScopesView
        
        /// The scopes defined on this row, recursively.
        public var names: Set<String> {
            var names = Set<String>()
            for (name, row) in scopes {
                names.insert(name)
                names.formUnion(row.scopesTree.names)
            }
            return names
        }

        /// Returns the row associated with the given scope, by performing a
        /// breadth-first search in this row's scopes and the scopes of its
        /// scoped rows, recursively.
        public subscript(_ name: String) -> Row? {
            var fifo = Array(scopes)
            while !fifo.isEmpty {
                let scope = fifo.removeFirst()
                if scope.name == name {
                    return scope.row
                }
                fifo.append(contentsOf: scope.row.scopes)
            }
            return nil
        }
    }
}

// MARK: - RowImpl

// The protocol for Row underlying implementation
protocol RowImpl {
    var count: Int { get }
    var isFetched: Bool { get }
    var scopes: Row.ScopesView { get }
    func columnName(atUncheckedIndex index: Int) -> String
    func hasNull(atUncheckedIndex index:Int) -> Bool
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ type: Value.Type, atUncheckedIndex index: Int) -> Value
    func fastDecodeIfPresent<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ type: Value.Type, atUncheckedIndex index: Int) -> Value?
    func dataNoCopy(atUncheckedIndex index:Int) -> Data?
    
    /// Returns the index of the leftmost column that matches *name* (case-insensitive)
    func index(ofColumn name: String) -> Int?
    
    // row.impl is guaranteed to be self.
    func unscopedRow(_ row: Row) -> Row
    func unadaptedRow(_ row: Row) -> Row
    func copiedRow(_ row: Row) -> Row
}

extension RowImpl {
    func copiedRow(_ row: Row) -> Row {
        // unless customized, assume unsafe and unadapted row
        return Row(impl: ArrayRowImpl(columns: row.map { $0 }))
    }
    
    func unscopedRow(_ row: Row) -> Row {
        // unless customized, assume unadapted row (see AdaptedRowImpl for customization)
        return row
    }
    
    func unadaptedRow(_ row: Row) -> Row {
        // unless customized, assume unadapted row (see AdaptedRowImpl for customization)
        return row
    }
    
    var scopes: Row.ScopesView {
        // unless customized, assume unuscoped row (see AdaptedRowImpl for customization)
        return Row.ScopesView()
    }
    
    func hasNull(atUncheckedIndex index:Int) -> Bool {
        // unless customized, use slow check (see StatementRowImpl and AdaptedRowImpl for customization)
        return databaseValue(atUncheckedIndex: index).isNull
    }
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int) -> Value
    {
        // unless customized, use slow decoding (see StatementRowImpl and AdaptedRowImpl for customization)
        return Value.decode(
            from: databaseValue(atUncheckedIndex: index),
            conversionContext: ValueConversionContext(Row(impl: self)).atColumn(index))
    }
    
    func fastDecodeIfPresent<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int) -> Value?
    {
        // unless customized, use slow decoding (see StatementRowImpl and AdaptedRowImpl for customization)
        return Value.decodeIfPresent(
            from: databaseValue(atUncheckedIndex: index),
            conversionContext: ValueConversionContext(Row(impl: self)).atColumn(index))
    }
    
    func dataNoCopy(atUncheckedIndex index:Int) -> Data? {
        // unless customized, copy data (see StatementRowImpl and AdaptedRowImpl for customization)
        return Data.decodeIfPresent(
            from: databaseValue(atUncheckedIndex: index),
            conversionContext: ValueConversionContext(Row(impl: self)).atColumn(index))
    }
}

// TODO: merge with StatementCopyRowImpl eventually?
/// See Row.init(dictionary:)
private struct ArrayRowImpl : RowImpl {
    let columns: [(String, DatabaseValue)]
    
    init(columns: [(String, DatabaseValue)]) {
        self.columns = columns
    }
    
    var count: Int {
        return columns.count
    }
    
    var isFetched: Bool {
        return false
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        return columns[index].1
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        return columns[index].0
    }
    
    func index(ofColumn name: String) -> Int? {
        let lowercaseName = name.lowercased()
        return columns.index { (column, _) in column.lowercased() == lowercaseName }
    }
    
    func copiedRow(_ row: Row) -> Row {
        return row
    }
}


// TODO: merge with ArrayRowImpl eventually?
/// See Row.init(copiedFromStatementRef:sqliteStatement:)
private struct StatementCopyRowImpl : RowImpl {
    let dbValues: ContiguousArray<DatabaseValue>
    let columnNames: [String]
    
    init(sqliteStatement: SQLiteStatement, columnNames: [String]) {
        let sqliteStatement = sqliteStatement
        self.dbValues = ContiguousArray((0..<sqlite3_column_count(sqliteStatement)).map { DatabaseValue(sqliteStatement: sqliteStatement, index: $0) } as [DatabaseValue])
        self.columnNames = columnNames
    }
    
    var count: Int {
        return columnNames.count
    }
    
    var isFetched: Bool {
        return true
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        return dbValues[index]
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        return columnNames[index]
    }
    
    func index(ofColumn name: String) -> Int? {
        let lowercaseName = name.lowercased()
        return columnNames.index { $0.lowercased() == lowercaseName }
    }
    
    func copiedRow(_ row: Row) -> Row {
        return row
    }
}


/// See Row.init(statement:)
private struct StatementRowImpl : RowImpl {
    let statementRef: Unmanaged<SelectStatement>
    let sqliteStatement: SQLiteStatement
    let lowercaseColumnIndexes: [String: Int]
    
    init(sqliteStatement: SQLiteStatement, statementRef: Unmanaged<SelectStatement>) {
        self.statementRef = statementRef
        self.sqliteStatement = sqliteStatement
        // Optimize row[columnName]
        let lowercaseColumnNames = (0..<sqlite3_column_count(sqliteStatement)).map { String(cString: sqlite3_column_name(sqliteStatement, Int32($0))).lowercased() }
        self.lowercaseColumnIndexes = Dictionary(
            lowercaseColumnNames
                .enumerated()
                .map { ($0.element, $0.offset) },
            uniquingKeysWith: { (left, _) in left }) // keep leftmost indexes
    }
    
    var count: Int {
        return Int(sqlite3_column_count(sqliteStatement))
    }
    
    var isFetched: Bool {
        return true
    }
    
    func hasNull(atUncheckedIndex index:Int) -> Bool {
        // Avoid extracting values, because this modifies the SQLite statement.
        return sqlite3_column_type(sqliteStatement, Int32(index)) == SQLITE_NULL
    }
    
    func dataNoCopy(atUncheckedIndex index:Int) -> Data? {
        guard sqlite3_column_type(sqliteStatement, Int32(index)) != SQLITE_NULL else {
            return nil
        }
        guard let bytes = sqlite3_column_blob(sqliteStatement, Int32(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(sqliteStatement, Int32(index)))
        return Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes), count: count, deallocator: .none)
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        return DatabaseValue(sqliteStatement: sqliteStatement, index: Int32(index))
    }
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int) -> Value
    {
        return Value.fastDecode(from: sqliteStatement, index: Int32(index))
    }
    
    func fastDecodeIfPresent<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int) -> Value?
    {
        return Value.fastDecodeIfPresent(from: sqliteStatement, atUncheckedIndex: Int32(index))
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        return statementRef.takeUnretainedValue().columnNames[index]
    }
    
    func index(ofColumn name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercased()]
    }
    
    func copiedRow(_ row: Row) -> Row {
        return Row(copiedFromSQLiteStatement: sqliteStatement, statementRef: statementRef)
    }
}

// This one is not optimized at all, since it is only used in fatal conversion errors, so far
private struct SQLiteStatementRowImpl : RowImpl {
    let sqliteStatement: SQLiteStatement
    var count: Int { return Int(sqlite3_column_count(sqliteStatement)) }
    var isFetched: Bool { return true }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        return String(cString: sqlite3_column_name(sqliteStatement, Int32(index)))
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        return DatabaseValue(sqliteStatement: sqliteStatement, index: Int32(index))
    }
    
    func index(ofColumn name: String) -> Int? {
        let name = name.lowercased()
        for index in 0..<count where columnName(atUncheckedIndex: index).lowercased() == name {
            return index
        }
        return nil
    }
}

/// See Row.init()
private struct EmptyRowImpl : RowImpl {
    var count: Int {
        return 0
    }
    
    var isFetched: Bool {
        return false
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        // Programmer error
        fatalError("row index out of range")
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        // Programmer error
        fatalError("row index out of range")
    }
    
    func index(ofColumn name: String) -> Int? {
        return nil
    }
    
    func copiedRow(_ row: Row) -> Row {
        return row
    }
}
