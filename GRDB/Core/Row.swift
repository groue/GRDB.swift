import Foundation
#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// A database row.
public final class Row {
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
        return impl.copy(self)
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
        return impl.index(ofColumn: columnName) != nil
    }
}

extension Row {
    
    // MARK: - Extracting Values
    
    /// Returns Int64, Double, String, Data or nil, depending on the value
    /// stored at the given index.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    public subscript(_ index: Int) -> DatabaseValueConvertible? {
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
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
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
        return impl.databaseValue(atUncheckedIndex: index).losslessConvert()
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
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
        if let sqliteStatement = sqliteStatement { // fast path
            return Row.statementColumnConvertible(atUncheckedIndex: Int32(index), in: sqliteStatement)
        }
        return impl.databaseValue(atUncheckedIndex: index).losslessConvert()
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    public subscript<Value: DatabaseValueConvertible>(_ index: Int) -> Value {
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
        return impl.databaseValue(atUncheckedIndex: index).losslessConvert()
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
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
        if let sqliteStatement = sqliteStatement { // fast path
            return Row.statementColumnConvertible(atUncheckedIndex: Int32(index), in: sqliteStatement)
        }
        return impl.databaseValue(atUncheckedIndex: index).losslessConvert()
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
        guard let index = impl.index(ofColumn: columnName) else {
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
        guard let index = impl.index(ofColumn: columnName) else {
            return nil
        }
        return impl.databaseValue(atUncheckedIndex: index).losslessConvert()
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
        guard let index = impl.index(ofColumn: columnName) else {
            return nil
        }
        if let sqliteStatement = sqliteStatement { // fast path
            return Row.statementColumnConvertible(atUncheckedIndex: Int32(index), in: sqliteStatement)
        }
        return impl.databaseValue(atUncheckedIndex: index).losslessConvert()
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
        guard let index = impl.index(ofColumn: columnName) else {
            // Programmer error
            fatalError("no such column: \(columnName)")
        }
        return impl.databaseValue(atUncheckedIndex: index).losslessConvert()
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
        guard let index = impl.index(ofColumn: columnName) else {
             // Programmer error
            fatalError("no such column: \(columnName)")
        }
        if let sqliteStatement = sqliteStatement { // fast path
            return Row.statementColumnConvertible(atUncheckedIndex: Int32(index), in: sqliteStatement)
        }
        return impl.databaseValue(atUncheckedIndex: index).losslessConvert()
    }
    
    /// Returns Int64, Double, String, NSData or nil, depending on the value
    /// stored at the given column.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// The result is nil if the row does not contain the column.
    public subscript(_ column: Column) -> DatabaseValueConvertible? {
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
    public subscript<Value: DatabaseValueConvertible>(_ column: Column) -> Value? {
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
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ column: Column) -> Value? {
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
    public subscript<Value: DatabaseValueConvertible>(_ column: Column) -> Value {
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
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ column: Column) -> Value {
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
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
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
        guard let index = impl.index(ofColumn: columnName) else {
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
    public func dataNoCopy(_ column: Column) -> Data? {
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
    
    // MARK: - Helpers
    @inline(__always)
    private static func statementColumnConvertible<Value: StatementColumnConvertible>(atUncheckedIndex index: Int32, in sqliteStatement: SQLiteStatement) -> Value? {
        guard sqlite3_column_type(sqliteStatement, index) != SQLITE_NULL else {
            return nil
        }
        return Value.init(sqliteStatement: sqliteStatement, index: index)
    }
    
    @inline(__always)
    private static func statementColumnConvertible<Value: StatementColumnConvertible>(atUncheckedIndex index: Int32, in sqliteStatement: SQLiteStatement) -> Value {
        guard sqlite3_column_type(sqliteStatement, index) != SQLITE_NULL else {
            // Programmer error
            fatalError("could not convert database value NULL to \(Value.self)")
        }
        return Value.init(sqliteStatement: sqliteStatement, index: index)
    }
}

extension Row {
    
    // MARK: - Scopes
    
    /// Returns a scoped row, if the row was fetched along with a row adapter
    /// that defines this scope.
    ///
    ///     // Two adapters
    ///     let fooAdapter = ColumnMapping(["value": "foo"])
    ///     let barAdapter = ColumnMapping(["value": "bar"])
    ///
    ///     // Define scopes
    ///     let adapter = ScopeAdapter([
    ///         "foo": fooAdapter,
    ///         "bar": barAdapter])
    ///
    ///     // Fetch
    ///     let sql = "SELECT 'foo' AS foo, 'bar' AS bar"
    ///     let row = try Row.fetchOne(db, sql, adapter: adapter)!
    ///
    ///     // Scoped rows:
    ///     if let fooRow = row.scoped(on: "foo") {
    ///         fooRow["value"]    // "foo"
    ///     }
    ///     if let barRow = row.scopeed(on: "bar") {
    ///         barRow["value"]    // "bar"
    ///     }
    public func scoped(on name: String) -> Row? {
        return impl.scoped(on: name)
    }
}

/// A cursor of database rows. For example:
///
///     try dbQueue.inDatabase { db in
///         let rows: RowCursor = try Row.fetchCursor(db, "SELECT * FROM players")
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
        statement.cursorReset(arguments: arguments)
    }
    
    public func next() throws -> Row? {
        if done { return nil }
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
        // The cursor reuses a single mutable row. Return an immutable copy.
        return try fetchCursor(statement, arguments: arguments, adapter: adapter).next().map { $0.copy() }
    }
}

extension Row {
    
    // MARK: - Fetching From Request
    
    /// Returns a cursor over rows fetched from a fetch request.
    ///
    ///     let idColumn = Column("id")
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(idColumn, nameColumn)
    ///     let rows = try Row.fetchCursor(db) // RowCursor
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
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A fetch request.
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: Request) throws -> RowCursor {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    /// Returns an array of rows fetched from a fetch request.
    ///
    ///     let idColumn = Column("id")
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(idColumn, nameColumn)
    ///     let rows = try Row.fetchAll(db, request)
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: Request) throws -> [Row] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single row fetched from a fetch request.
    ///
    ///     let idColumn = Column("id")
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(idColumn, nameColumn)
    ///     let row = try Row.fetchOne(db, request)
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ request: Request) throws -> Row? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

extension Row {
    
    // MARK: - Fetching From SQL
    
    /// Returns a cursor over rows fetched from an SQL query.
    ///
    ///     let rows = try Row.fetchCursor(db, "SELECT id, name FROM players") // RowCursor
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
        return try fetchCursor(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
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
        return try fetchAll(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
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
        return try fetchOne(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
}

extension Row : ExpressibleByDictionaryLiteral {
    
    /// Creates a row initialized with elements. Column order is preserved, and
    /// duplicated columns names are allowed.
    ///
    ///     let row: Row = ["foo": 1, "foo": "bar", "baz": nil]
    ///     print(row)
    ///     // Prints <Row foo:1 foo:"bar" baz:NULL>
    public convenience init(dictionaryLiteral elements: (String, DatabaseValueConvertible?)...) {
        self.init(impl: ArrayRowImpl(columns: elements.map { ($0, $1?.databaseValue ?? .null) }))
    }
}

extension Row : Collection {
    
    // MARK: - Row as a Collection of (ColumnName, DatabaseValue) Pairs
    
    /// The index of the first (ColumnName, DatabaseValue) pair.
    public var startIndex: RowIndex {
        return Index(0)
    }
    
    /// The "past-the-end" index, successor of the index of the last
    /// (ColumnName, DatabaseValue) pair.
    public var endIndex: RowIndex {
        return Index(count)
    }
    
    /// Accesses the (ColumnName, DatabaseValue) pair at given index.
    public subscript(position: RowIndex) -> (String, DatabaseValue) {
        let index = position.index
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
        return (
            impl.columnName(atUncheckedIndex: index),
            impl.databaseValue(atUncheckedIndex: index))
    }
    
    /// Returns the position immediately after `i`.
    ///
    /// - Precondition: `(startIndex..<endIndex).contains(i)`
    public func index(after i: RowIndex) -> RowIndex {
        return RowIndex(i.index + 1)
    }
    
    /// Replaces `i` with its successor.
    public func formIndex(after i: inout RowIndex) {
        i = RowIndex(i.index + 1)
    }
}

/// Row adopts Equatable.
extension Row : Equatable {
    
    /// Returns true if and only if both rows have the same columns and values,
    /// in the same order. Columns are compared in a case-sensitive way.
    public static func == (lhs: Row, rhs: Row) -> Bool {
        if lhs === rhs {
            return true
        }
        
        guard lhs.count == rhs.count else {
            return false
        }
        
        var liter = lhs.makeIterator()
        var riter = rhs.makeIterator()
        
        while let (lcol, lval) = liter.next(), let (rcol, rval) = riter.next() {
            guard lcol == rcol else {
                return false
            }
            guard lval == rval else {
                return false
            }
        }
        
        let lscopeNames = lhs.impl.scopeNames
        let rscopeNames = rhs.impl.scopeNames
        guard lscopeNames == rscopeNames else {
            return false
        }
        
        for name in lscopeNames {
            let lscope = lhs.scoped(on: name)
            let rscope = rhs.scoped(on: name)
            guard lscope == rscope else {
                return false
            }
        }
        
        return true
    }
}

/// Row adopts Hashable.
extension Row : Hashable {
    /// The hash value
    public var hashValue: Int {
        return columnNames.reduce(0) { (acc, column) in acc ^ column.hashValue } ^
            databaseValues.reduce(0) { (acc, dbValue) in acc ^ dbValue.hashValue }
    }
}

/// Row adopts CustomStringConvertible.
extension Row: CustomStringConvertible {
    public var description: String {
        return "<Row"
            + map { (column, dbValue) in
                " \(column):\(dbValue)"
                }.joined(separator: "")
            + ">"
    }
}


// MARK: - RowIndex

/// Indexes to (columnName, dbValue) pairs in a database row.
public struct RowIndex : Comparable {
    let index: Int
    init(_ index: Int) { self.index = index }
    
    /// Equality operator
    public static func == (lhs: RowIndex, rhs: RowIndex) -> Bool {
        return lhs.index == rhs.index
    }
    
    // Comparison operator
    public static func < (lhs: RowIndex, rhs: RowIndex) -> Bool {
        return lhs.index < rhs.index
    }
}


// MARK: - RowImpl

// The protocol for Row underlying implementation
protocol RowImpl {
    var count: Int { get }
    var isFetched: Bool { get }
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue
    func dataNoCopy(atUncheckedIndex index:Int) -> Data?
    func columnName(atUncheckedIndex index: Int) -> String
    
    // This method MUST be case-insensitive, and returns the index of the
    // leftmost column that matches *name*.
    func index(ofColumn name: String) -> Int?
    
    func scoped(on name: String) -> Row?
    var scopeNames: Set<String> { get }
    
    // row.impl is guaranteed to be self.
    func copy(_ row: Row) -> Row
}


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
    
    func dataNoCopy(atUncheckedIndex index:Int) -> Data? {
        return databaseValue(atUncheckedIndex: index).losslessConvert()
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        return columns[index].1
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        return columns[index].0
    }
    
    // This method MUST be case-insensitive, and returns the index of the
    // leftmost column that matches *name*.
    func index(ofColumn name: String) -> Int? {
        let lowercaseName = name.lowercased()
        return columns.index { (column, _) in column.lowercased() == lowercaseName }
    }
    
    func scoped(on name: String) -> Row? {
        return nil
    }
    
    var scopeNames: Set<String> {
        return []
    }
    
    func copy(_ row: Row) -> Row {
        return row
    }
}


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
    
    func dataNoCopy(atUncheckedIndex index:Int) -> Data? {
        return databaseValue(atUncheckedIndex: index).losslessConvert()
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        return dbValues[index]
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        return columnNames[index]
    }
    
    // This method MUST be case-insensitive, and returns the index of the
    // leftmost column that matches *name*.
    func index(ofColumn name: String) -> Int? {
        let lowercaseName = name.lowercased()
        return columnNames.index { $0.lowercased() == lowercaseName }
    }
    
    func scoped(on name: String) -> Row? {
        return nil
    }
    
    var scopeNames: Set<String> {
        return []
    }
    
    func copy(_ row: Row) -> Row {
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
        // Optimize row["..."]
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
    
    func columnName(atUncheckedIndex index: Int) -> String {
        return statementRef.takeUnretainedValue().columnNames[index]
    }
    
    // This method MUST be case-insensitive, and returns the index of the
    // leftmost column that matches *name*.
    func index(ofColumn name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercased()]
    }
    
    func scoped(on name: String) -> Row? {
        return nil
    }
    
    var scopeNames: Set<String> {
        return []
    }
    
    func copy(_ row: Row) -> Row {
        return Row(copiedFromSQLiteStatement: sqliteStatement, statementRef: statementRef)
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
    
    func dataNoCopy(atUncheckedIndex index:Int) -> Data? {
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
    
    func scoped(on name: String) -> Row? {
        return nil
    }
    
    var scopeNames: Set<String> {
        return []
    }
    
    func copy(_ row: Row) -> Row {
        return row
    }
}
