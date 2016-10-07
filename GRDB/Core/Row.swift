import Foundation

#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif

/// A database row.
public final class Row {
    
    // MARK: - Building rows
    
    /// Creates an empty row.
    public convenience init() {
        self.init(impl: EmptyRowImpl())
    }
    
    /// Creates a row from a dictionary of values.
    public convenience init(_ dictionary: [String: DatabaseValueConvertible?]) {
        self.init(impl: DictionaryRowImpl(dictionary: dictionary))
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
            guard let databaseValue = DatabaseValue(value: value) else {
                return nil
            }
            initDictionary[columnName] = databaseValue
        }
        self.init(initDictionary)
    }
    
    /// Returns a copy of the row.
    ///
    /// Fetched rows are reused during the iteration of a query, for performance
    /// reasons: make sure to make a copy of it whenever you want to keep a
    /// specific one: `row.copy()`.
    public func copy() -> Row {
        return impl.copy(self)
    }
    
    
    // MARK: - Not Public
    
    let impl: RowImpl
    
    /// Unless we are producing a row array, we use a single row when iterating a
    /// statement:
    ///
    ///     for row in Row.fetch(db, "SELECT ...") { ... }
    ///     for person in Person.fetch(db, "SELECT ...") { ... }
    ///
    /// This row keeps an unmanaged reference to the statement, and a handle to
    /// the sqlite statement, so that we avoid many retain/release invocations.
    ///
    /// The statementRef is released in deinit.
    let statementRef: Unmanaged<SelectStatement>?
    let sqliteStatement: SQLiteStatement?
    
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
    
    /// Creates a row from the *current state* of the SQLite statement.
    ///
    /// The row is implemented on top of StatementCopyRowImpl, which *copies*
    /// the values from the SQLite statement so that further iteration of the
    /// statement does not modify the row.
    convenience init(copiedFromSQLiteStatement sqliteStatement: SQLiteStatement, columnNames: [String]) {
        self.init(impl: StatementCopyRowImpl(sqliteStatement: sqliteStatement, columnNames: columnNames))
    }
    
    init(impl: RowImpl) {
        self.impl = impl
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
    public func value(atIndex index: Int) -> DatabaseValueConvertible? {
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
        return impl.databaseValue(atUncheckedIndex: index).value()
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// If the SQLite value is NULL, the result is nil. Otherwise the SQLite
    /// value is converted to the requested type `Value`. Should this conversion
    /// fail, a fatal error is raised.
    public func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value? {
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
        return impl.databaseValue(atUncheckedIndex: index).value()
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
    public func value<Value: DatabaseValueConvertible & StatementColumnConvertible>(atIndex index: Int) -> Value? {
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
        guard let sqliteStatement = sqliteStatement else {
            return impl.databaseValue(atUncheckedIndex: index).value()
        }
        return Row.statementColumnConvertible(atUncheckedIndex: index, in: sqliteStatement)
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    public func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value {
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
        return impl.databaseValue(atUncheckedIndex: index).value()
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
    public func value<Value: DatabaseValueConvertible & StatementColumnConvertible>(atIndex index: Int) -> Value {
        GRDBPrecondition(index >= 0 && index < count, "row index out of range")
        guard let sqliteStatement = sqliteStatement else {
            return impl.databaseValue(atUncheckedIndex: index).value()
        }
        return Row.statementColumnConvertible(atUncheckedIndex: index, in: sqliteStatement)
    }
    
    /// Returns Int64, Double, String, Data or nil, depending on the value
    /// stored at the given column.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// The result is nil if the row does not contain the column.
    public func value(named columnName: String) -> DatabaseValueConvertible? {
        // IMPLEMENTATION NOTE
        // This method has a single know use case: checking if the value is nil,
        // as in:
        //
        //     if row.value(named: "foo") != nil { ... }
        //
        // Without this method, the code above would not compile.
        guard let index = impl.index(ofColumn: columnName) else {
            return nil
        }
        return impl.databaseValue(atUncheckedIndex: index).value()
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. Otherwise the SQLite value is converted to the requested type
    /// `Value`. Should this conversion fail, a fatal error is raised.
    public func value<Value: DatabaseValueConvertible>(named columnName: String) -> Value? {
        guard let index = impl.index(ofColumn: columnName) else {
            return nil
        }
        return impl.databaseValue(atUncheckedIndex: index).value()
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
    public func value<Value: DatabaseValueConvertible & StatementColumnConvertible>(named columnName: String) -> Value? {
        guard let index = impl.index(ofColumn: columnName) else {
            return nil
        }
        guard let sqliteStatement = sqliteStatement else {
            return impl.databaseValue(atUncheckedIndex: index).value()
        }
        return Row.statementColumnConvertible(atUncheckedIndex: index, in: sqliteStatement)
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
    public func value<Value: DatabaseValueConvertible>(named columnName: String) -> Value {
        guard let index = impl.index(ofColumn: columnName) else {
            fatalError("no such column: \(columnName)")
        }
        return impl.databaseValue(atUncheckedIndex: index).value()
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
    public func value<Value: DatabaseValueConvertible & StatementColumnConvertible>(named columnName: String) -> Value {
        guard let index = impl.index(ofColumn: columnName) else {
            fatalError("no such column: \(columnName)")
        }
        guard let sqliteStatement = sqliteStatement else {
            return impl.databaseValue(atUncheckedIndex: index).value()
        }
        return Row.statementColumnConvertible(atUncheckedIndex: index, in: sqliteStatement)
    }
    
    /// Returns Int64, Double, String, NSData or nil, depending on the value
    /// stored at the given column.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// The result is nil if the row does not contain the column.
    public func value(_ column: Column) -> DatabaseValueConvertible? {
        return value(named: column.name)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. Otherwise the SQLite value is converted to the requested type
    /// `Value`. Should this conversion fail, a fatal error is raised.
    public func value<Value: DatabaseValueConvertible>(_ column: Column) -> Value? {
        return value(named: column.name)
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
    public func value<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ column: Column) -> Value? {
        return value(named: column.name)
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
    public func value<Value: DatabaseValueConvertible>(_ column: Column) -> Value {
        return value(named: column.name)
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
    public func value<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ column: Column) -> Value {
        return value(named: column.name)
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
    
    fileprivate static func statementColumnConvertible<Value: StatementColumnConvertible>(atUncheckedIndex index: Int, in sqliteStatement: SQLiteStatement) -> Value? {
        guard sqlite3_column_type(sqliteStatement, Int32(index)) != SQLITE_NULL else {
            return nil
        }
        return Value.init(sqliteStatement: sqliteStatement, index: Int32(index))
    }
    
    fileprivate static func statementColumnConvertible<Value: StatementColumnConvertible>(atUncheckedIndex index: Int, in sqliteStatement: SQLiteStatement) -> Value {
        guard sqlite3_column_type(sqliteStatement, Int32(index)) != SQLITE_NULL else {
            fatalError("could not convert database NULL value to \(Value.self)")
        }
        return Value.init(sqliteStatement: sqliteStatement, index: Int32(index))
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
    ///     let row = Row.fetchOne(db, sql, adapter: adapter)!
    ///
    ///     // Scoped rows:
    ///     if let fooRow = row.scoped(on: "foo") {
    ///         fooRow.value(named: "value")    // "foo"
    ///     }
    ///     if let barRow = row.scopeed(on: "bar") {
    ///         barRow.value(named: "value")    // "bar"
    ///     }
    public func scoped(on name: String) -> Row? {
        return impl.scoped(on: name)
    }
}

extension Row {
    
    // MARK: - Fetching From SelectStatement
    
    /// Returns a sequence of rows fetched from a prepared statement.
    ///
    ///     let statement = db.makeSelectStatement("SELECT ...")
    ///     for row in Row.fetch(statement) {
    ///         let id: Int64 = row.value(atIndex: 0)
    ///         let name: String = row.value(atIndex: 1)
    ///     }
    ///
    /// Fetched rows are reused during the sequence iteration: don't wrap a row
    /// sequence in an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let rows = Row.fetch(statement)
    ///     for row in rows { ... } // 3 steps
    ///     db.execute("DELETE ...")
    ///     for row in rows { ... } // 2 steps
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements of the sequence are undefined.
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A sequence of rows.
    public static func fetch(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> DatabaseSequence<Row> {
        // Metal rows can be reused. And reusing them yields better performance.
        let row = try! Row(statement: statement).adaptedRow(adapter: adapter, statement: statement)
        return statement.fetchSequence(arguments: arguments) {
            row
        }
    }
    
    /// Returns an array of rows fetched from a prepared statement.
    ///
    ///     let statement = db.makeSelectStatement("SELECT ...")
    ///     let rows = Row.fetchAll(statement)
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    public static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> [Row] {
        let sqliteStatement = statement.sqliteStatement
        let columnNames = statement.columnNames
        let sequence: DatabaseSequence<Row>
        if let adapter = adapter {
            let concreteRowAdapter = try! adapter.concreteRowAdapter(with: statement)
            sequence = statement.fetchSequence(arguments: arguments) {
                Row(baseRow: Row(copiedFromSQLiteStatement: sqliteStatement, columnNames: columnNames), concreteRowAdapter: concreteRowAdapter)
            }
        } else {
            sequence = statement.fetchSequence(arguments: arguments) {
                Row(copiedFromSQLiteStatement: sqliteStatement, columnNames: columnNames)
            }
        }
        return Array(sequence)
    }
    
    /// Returns a single row fetched from a prepared statement.
    ///
    ///     let statement = db.makeSelectStatement("SELECT ...")
    ///     let row = Row.fetchOne(statement)
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    public static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Row? {
        let sqliteStatement = statement.sqliteStatement
        let columnNames = statement.columnNames
        let sequence = statement.fetchSequence(arguments: arguments) {
            Row(copiedFromSQLiteStatement: sqliteStatement, columnNames: columnNames)
        }
        guard let row = sequence.makeIterator().next() else {
            return nil
        }
        return try! row.adaptedRow(adapter: adapter, statement: statement)
    }
}


extension Row {
    
    // MARK: - Fetching From FetchRequest
    
    /// Returns a sequence of rows fetched from a fetch request.
    ///
    ///     let idColumn = Column("id")
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(idColumn, nameColumn)
    ///     for row in Row.fetch(db, request) {
    ///         let id: Int64 = row.value(atIndex: 0)
    ///         let name: String = row.value(atIndex: 1)
    ///     }
    ///
    /// Fetched rows are reused during the sequence iteration: don't wrap a row
    /// sequence in an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let rows = Row.fetch(statement)
    ///     for row in rows { ... } // 3 steps
    ///     db.execute("DELETE ...")
    ///     for row in rows { ... } // 2 steps
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements of the sequence are undefined.
    public static func fetch(_ db: Database, _ request: FetchRequest) -> DatabaseSequence<Row> {
        let (statement, adapter) = try! request.prepare(db)
        return fetch(statement, adapter: adapter)
    }
    
    /// Returns an array of rows fetched from a fetch request.
    ///
    ///     let idColumn = Column("id")
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(idColumn, nameColumn)
    ///     let rows = Row.fetchAll(db, request)
    ///
    /// - parameter db: A database connection.
    public static func fetchAll(_ db: Database, _ request: FetchRequest) -> [Row] {
        let (statement, adapter) = try! request.prepare(db)
        return fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single row fetched from a fetch request.
    ///
    ///     let idColumn = Column("id")
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(idColumn, nameColumn)
    ///     let row = Row.fetchOne(db, request)
    ///
    /// - parameter db: A database connection.
    public static func fetchOne(_ db: Database, _ request: FetchRequest) -> Row? {
        let (statement, adapter) = try! request.prepare(db)
        return fetchOne(statement, adapter: adapter)
    }
}


extension Row {
    
    // MARK: - Fetching From SQL
    
    /// Returns a sequence of rows fetched from an SQL query.
    ///
    ///     for row in Row.fetch(db, "SELECT id, name FROM persons") {
    ///         let id: Int64 = row.value(atIndex: 0)
    ///         let name: String = row.value(atIndex: 1)
    ///     }
    ///
    /// Fetched rows are reused during the sequence iteration: don't wrap a row
    /// sequence in an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let rows = Row.fetch(db, "SELECT...")
    ///     for row in rows { ... } // 3 steps
    ///     db.execute("DELETE ...")
    ///     for row in rows { ... } // 2 steps
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements of the sequence are undefined.
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A sequence of rows.
    public static func fetch(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> DatabaseSequence<Row> {
        return fetch(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of rows fetched from an SQL query.
    ///
    ///     let rows = Row.fetchAll(db, "SELECT ...")
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> [Row] {
        return fetchAll(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single row fetched from an SQL query.
    ///
    ///     let row = Row.fetchOne(db, "SELECT ...")
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    public static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Row? {
        return fetchOne(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension Row : ExpressibleByDictionaryLiteral {
    
    /// Creates a row initialized with elements.
    public convenience init(dictionaryLiteral elements: (String, DatabaseValueConvertible?)...) {
        self.init(Dictionary(keyValueSequence: elements))
    }
}

extension Row : Collection {
    
    // MARK: - Row as a Collection of (ColumnName, DatabaseValue) Pairs
    
    /// The number of columns in the row.
    public var count: Int {
        return impl.count
    }
    
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


extension Row : Equatable {
    
    /// Returns true if and only if both rows have the same columns and values,
    /// in the same order. Columns are compared in a case-sensitive way.
    public static func ==(lhs: Row, rhs: Row) -> Bool {
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

/// Row adopts CustomStringConvertible.
extension Row: CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        return "<Row"
            + map { (column, dbv) in
                " \(column):\(dbv)"
                }.joined(separator: "")
            + ">"
    }
}


// MARK: - RowIndex

/// Indexes to (columnName, databaseValue) pairs in a database row.
public struct RowIndex : Comparable {
    let index: Int
    init(_ index: Int) { self.index = index }
    
    public static func ==(lhs: RowIndex, rhs: RowIndex) -> Bool {
        return lhs.index == rhs.index
    }
    
    public static func <(lhs: RowIndex, rhs: RowIndex) -> Bool {
        return lhs.index < rhs.index
    }
}


// MARK: - RowImpl

// The protocol for Row underlying implementation
protocol RowImpl {
    var count: Int { get }
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
private struct DictionaryRowImpl : RowImpl {
    let dictionary: [String: DatabaseValueConvertible?]
    
    init (dictionary: [String: DatabaseValueConvertible?]) {
        self.dictionary = dictionary
    }
    
    var count: Int {
        return dictionary.count
    }
    
    func dataNoCopy(atUncheckedIndex index:Int) -> Data? {
        return databaseValue(atUncheckedIndex: index).value()
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        let i = dictionary.index(dictionary.startIndex, offsetBy: index)
        return dictionary[i].1?.databaseValue ?? .null
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        let i = dictionary.index(dictionary.startIndex, offsetBy: index)
        return dictionary[i].0
    }
    
    // This method MUST be case-insensitive, and returns the index of the
    // leftmost column that matches *name*.
    func index(ofColumn name: String) -> Int? {
        let lowercaseName = name.lowercased()
        guard let index = dictionary.index(where: { (column, value) in column.lowercased() == lowercaseName }) else {
            return nil
        }
        return dictionary.distance(from: dictionary.startIndex, to: index)
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
    let databaseValues: ContiguousArray<DatabaseValue>
    let columnNames: [String]
    
    init(sqliteStatement: SQLiteStatement, columnNames: [String]) {
        let sqliteStatement = sqliteStatement
        self.databaseValues = ContiguousArray((0..<sqlite3_column_count(sqliteStatement)).map { DatabaseValue(sqliteStatement: sqliteStatement, index: $0) } as [DatabaseValue])
        self.columnNames = columnNames
    }
    
    var count: Int {
        return columnNames.count
    }
    
    func dataNoCopy(atUncheckedIndex index:Int) -> Data? {
        return databaseValue(atUncheckedIndex: index).value()
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        return databaseValues[index]
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
        // Optimize row.value(named: "...")
        let lowercaseColumnNames = (0..<sqlite3_column_count(sqliteStatement)).map { String(cString: sqlite3_column_name(sqliteStatement, Int32($0))).lowercased() }
        self.lowercaseColumnIndexes = Dictionary(keyValueSequence: lowercaseColumnNames.enumerated().map { ($1, $0) }.reversed())
    }
    
    var count: Int {
        return Int(sqlite3_column_count(sqliteStatement))
    }
    
    func dataNoCopy(atUncheckedIndex index:Int) -> Data? {
        guard sqlite3_column_type(sqliteStatement, Int32(index)) != SQLITE_NULL else {
            return nil
        }
        guard let bytes = sqlite3_column_blob(sqliteStatement, Int32(index)) else {
            return nil
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
    var count: Int { return 0 }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        fatalError("row index out of range")
    }
    
    func dataNoCopy(atUncheckedIndex index:Int) -> Data? {
        fatalError("row index out of range")
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
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
