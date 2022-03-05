import Foundation

/// A database row.
public final class Row: Equatable, Hashable, RandomAccessCollection,
                        ExpressibleByDictionaryLiteral, CustomStringConvertible,
                        CustomDebugStringConvertible
{
    // It is not a violation of the Demeter law when another type uses this
    // property, which is exposed for optimizations.
    let impl: RowImpl
    
    /// Unless we are producing a row array, we use a single row when iterating
    /// a statement:
    ///
    ///     let rows = try Row.fetchCursor(db, sql: "SELECT ...")
    ///     let players = try Player.fetchAll(db, sql: "SELECT ...")
    let statement: Statement?
    @usableFromInline
    let sqliteStatement: SQLiteStatement?
    
    /// The number of columns in the row.
    public let count: Int
    
    /// A view on the prefetched associated rows.
    ///
    /// For example:
    ///
    ///     let request = Author.including(all: Author.books)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(row)
    ///     // Prints [id:1 name:"Herman Melville"]
    ///
    ///     let bookRows = row.prefetchedRows["books"]
    ///     print(bookRows[0])
    ///     // Prints [id:42 title:"Moby-Dick"]
    public internal(set) var prefetchedRows = PrefetchedRowsView()
    
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
    
    // ExpressibleByDictionaryLiteral
    /// Creates a row initialized with elements. Column order is preserved, and
    /// duplicated columns names are allowed.
    ///
    ///     let row: Row = ["foo": 1, "foo": "bar", "baz": nil]
    ///     print(row)
    ///     // Prints [foo:1 foo:"bar" baz:NULL]
    public convenience init(dictionaryLiteral elements: (String, DatabaseValueConvertible?)...) {
        self.init(impl: ArrayRowImpl(columns: elements.map { ($0, $1?.databaseValue ?? .null) }))
    }
    
    /// Returns an immutable copy of the row.
    ///
    /// For performance reasons, rows fetched from a cursor are reused during
    /// the iteration of a query: make sure to make a copy of it whenever you
    /// want to keep a specific one: `row.copy()`.
    public func copy() -> Row {
        impl.copiedRow(self)
    }
    
    // MARK: - Not Public
    
    /// Returns true if and only if the row was fetched from a database.
    var isFetched: Bool { impl.isFetched }
    
    /// Creates a row that maps an SQLite statement. Further calls to
    /// sqlite3_step() modify the row.
    ///
    /// The row is implemented on top of StatementRowImpl, which grants *direct*
    /// access to the SQLite statement. Iteration of the statement does modify
    /// the row.
    init(statement: Statement) {
        self.statement = statement
        self.sqliteStatement = statement.sqliteStatement
        self.impl = StatementRowImpl(sqliteStatement: statement.sqliteStatement, statement: statement)
        self.count = Int(sqlite3_column_count(sqliteStatement))
    }
    
    /// Creates a row that maps an SQLite statement. Further calls to
    /// sqlite3_step() modify the row.
    init(sqliteStatement: SQLiteStatement) {
        self.statement = nil
        self.sqliteStatement = sqliteStatement
        self.impl = SQLiteStatementRowImpl(sqliteStatement: sqliteStatement)
        self.count = Int(sqlite3_column_count(sqliteStatement))
    }
    
    /// Creates a row that contain a copy of the current state of the
    /// SQLite statement. Further calls to sqlite3_step() do not modify the row.
    ///
    /// The row is implemented on top of StatementCopyRowImpl, which *copies*
    /// the values from the SQLite statement so that further iteration of the
    /// statement does not modify the row.
    convenience init(
        copiedFromSQLiteStatement sqliteStatement: SQLiteStatement,
        statement: Statement)
    {
        self.init(impl: StatementCopyRowImpl(
                    sqliteStatement: sqliteStatement,
                    columnNames: statement.columnNames))
    }
    
    init(impl: RowImpl) {
        self.statement = nil
        self.sqliteStatement = nil
        self.impl = impl
        self.count = impl.count
    }
}

extension Row {
    
    // MARK: - Columns
    
    /// The names of columns in the row.
    ///
    /// Columns appear in the same order as they occur as the `.0` member
    /// of column-value pairs in `self`.
    public var columnNames: LazyMapCollection<Row, String> {
        lazy.map { $0.0 }
    }
    
    /// Returns true if and only if the row has that column.
    ///
    /// This method is case-insensitive.
    public func hasColumn(_ columnName: String) -> Bool {
        index(forColumn: columnName) != nil
    }
    
    @usableFromInline
    func index(forColumn name: String) -> Int? {
        impl.index(forColumn: name)
    }
}

extension Row {
    
    // MARK: - Extracting Values
    
    /// Fatal errors if index is out of bounds
    @inline(__always)
    @usableFromInline
    /* private */ func _checkIndex(_ index: Int, file: StaticString = #file, line: UInt = #line) {
        GRDBPrecondition(index >= 0 && index < count, "row index out of range", file: file, line: line)
    }
    
    /// Returns true if and only if one column contains a non-null value, or if
    /// the row was fetched with a row adapter that defines a scoped row that
    /// contains a non-null value.
    ///
    /// For example:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 'foo', 1")!
    ///     row.containsNonNullValue // true
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT NULL, NULL")!
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
        _checkIndex(index)
        return impl.hasNull(atUncheckedIndex: index)
    }
    
    /// Returns Int64, Double, String, Data or nil, depending on the value
    /// stored at the given index.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    public subscript(_ index: Int) -> DatabaseValueConvertible? {
        databaseValue(atIndex: index).storage.value
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// For example:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 42")!
    ///     let score: Int = try row[0] // 42
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 'Alice'")!
    ///     let name: String = try row[0] // "Alice"
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT NULL")!
    ///     let name: String? = try row[0] // nil
    @inlinable
    public subscript<Value: DatabaseValueConvertible>(_ index: Int) -> Value {
        get throws { try decode(Value.self, atIndex: index) }
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// `StatementColumnConvertible`. It can trigger SQLite built-in conversions
    /// (see <https://www.sqlite.org/datatype3.html>).
    ///
    /// For example:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 42")!
    ///     let score: Int = try row[0] // 42
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 'Alice'")!
    ///     let name: String = try row[0] // "Alice"
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT NULL")!
    ///     let name: String? = try row[0] // nil
    @inline(__always)
    @inlinable
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ index: Int) -> Value {
        get throws { try decode(Value.self, atIndex: index) }
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
        databaseValue(forColumn: columnName)?.storage.value
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// For example:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 42 AS score")!
    ///     let score: Int = try row["score"] // 42
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    ///     let name: String = try row["name"] // "Alice"
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT NULL AS name")!
    ///     let name: String? = try row["name"] // nil
    ///
    /// When the column does not exist, nil is returned:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT ...")!
    ///     let name: String? = try row["missing"] // nil
    @inlinable
    public subscript<Value: DatabaseValueConvertible>(_ columnName: String) -> Value {
        get throws { try decode(Value.self, forColumn: columnName) }
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// `StatementColumnConvertible`. It can trigger SQLite built-in conversions
    /// (see <https://www.sqlite.org/datatype3.html>).
    ///
    /// For example:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 42 AS score")!
    ///     let score: Int = try row["score"] // 42
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    ///     let name: String = try row["name"] // "Alice"
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT NULL AS name")!
    ///     let name: String? = try row["name"] // nil
    ///
    /// When the column does not exist, nil is returned:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT ...")!
    ///     let name: String? = try row["missing"] // nil
    @inlinable
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ columnName: String) -> Value {
        get throws { try decode(Value.self, forColumn: columnName) }
    }
    
    /// Returns Int64, Double, String, Data or nil, depending on the value
    /// stored at the given column.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// The result is nil if the row does not contain the column.
    public subscript<Column: ColumnExpression>(_ column: Column) -> DatabaseValueConvertible? {
        databaseValue(forColumn: column.name)?.storage.value
    }

    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// For example:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 42 AS score")!
    ///     let score: Int = try row[Column("score")] // 42
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    ///     let name: String = try row[Column("name")] // "Alice"
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT NULL AS name")!
    ///     let name: String? = try row[Column("name")] // nil
    ///
    /// When the column does not exist, nil is returned:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT ...")!
    ///     let name: String? = try row[Column("missing")] // nil
    @inlinable
    public subscript<Value: DatabaseValueConvertible, Column: ColumnExpression>(_ column: Column) -> Value {
        get throws { try decode(Value.self, forColumn: column.name) }
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// `StatementColumnConvertible`. It can trigger SQLite built-in conversions
    /// (see <https://www.sqlite.org/datatype3.html>).
    ///
    /// For example:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 42 AS score")!
    ///     let score: Int = try row[Column("score")] // 42
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    ///     let name: String = try row[Column("name")] // "Alice"
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT NULL AS name")!
    ///     let name: String? = try row[Column("name")] // nil
    ///
    /// When the column does not exist, nil is returned:
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT ...")!
    ///     let name: String? = try row[Column("missing")] // nil
    @inlinable
    public subscript<Value, Column>(_ column: Column)
    -> Value
    where
        Value: DatabaseValueConvertible & StatementColumnConvertible,
        Column: ColumnExpression
    {
        get throws { try decode(Value.self, forColumn: column.name) }
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
    public func dataNoCopy(atIndex index: Int) throws -> Data? {
        try decodeDataNoCopyIfPresent(atIndex: index)
    }
    
    /// Returns the optional `Data` at given column.
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
    public func dataNoCopy(named columnName: String) throws -> Data? {
        try decodeDataNoCopyIfPresent(forColumn: columnName)
    }
    
    /// Returns the optional `Data` at given column.
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
    public func dataNoCopy<Column: ColumnExpression>(_ column: Column) throws -> Data? {
        try decodeDataNoCopyIfPresent(forColumn: column.name)
    }
}

extension Row {
    
    // MARK: - Extracting DatabaseValue
    
    /// The database values in the row.
    ///
    /// Values appear in the same order as they occur as the `.1` member
    /// of column-value pairs in `self`.
    public var databaseValues: LazyMapCollection<Row, DatabaseValue> {
        lazy.map { $0.1 }
    }

    /// Returns the `DatabaseValue` at the given index.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    public func databaseValue(atIndex index: Int) -> DatabaseValue {
        _checkIndex(index)
        return impl.databaseValue(atUncheckedIndex: index)
    }
    
    /// Returns the `DatabaseValue` at the given index.
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        impl.databaseValue(atUncheckedIndex: index)
    }
    
    /// Returns the `DatabaseValue` at the given column.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// The result is nil if the row does not contain the column.
    public func databaseValue(forColumn columnName: String) -> DatabaseValue? {
        guard let index = index(forColumn: columnName) else {
            return nil
        }
        return impl.databaseValue(atUncheckedIndex: index)
    }
    
    /// Returns the `DatabaseValue` at the given index.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// The result is nil if the row does not contain the column.
    public func databaseValue<Column: ColumnExpression>(forColumn column: Column) -> DatabaseValue? {
        databaseValue(forColumn: column.name)
    }
}

extension Row {
    
    // MARK: - Extracting Records
    
    /// Returns the record associated with the given scope.
    ///
    /// For example:
    ///
    ///     let request = Book.including(required: Book.author)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let author: Author = try row["author"]
    ///     print(author.name)
    ///     // Prints "Herman Melville"
    ///
    /// Associated records stored in nested associations are available, too:
    ///
    ///     let request = Book.including(required: Book.author.including(required: Author.country))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let country: Country = try row["country"]
    ///     print(country.name)
    ///     // Prints "United States"
    ///
    /// A fatal error is raised if the scope is not available, or contains only
    /// null values.
    ///
    /// See <https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support>
    /// for more information.
    public subscript<Record: FetchableRecord>(_ scope: String) -> Record {
        get throws { try decode(Record.self, forScope: scope) }
    }
    
    /// Returns the eventual record associated with the given scope.
    ///
    /// For example:
    ///
    ///     let request = Book.including(optional: Book.author)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let author: Author? = try row["author"]
    ///     print(author.name)
    ///     // Prints "Herman Melville"
    ///
    /// Associated records stored in nested associations are available, too:
    ///
    ///     let request = Book.including(optional: Book.author.including(optional: Author.country))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let country: Country? = try row["country"]
    ///     print(country.name)
    ///     // Prints "United States"
    ///
    /// Nil is returned if the scope is not available, or contains only
    /// null values.
    ///
    /// See <https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support>
    /// for more information.
    public subscript<Record: FetchableRecord>(_ scope: String) -> Record? {
        get throws { try decodeIfPresent(Record.self, forScope: scope) }
    }
    
    /// Returns the records encoded in the given prefetched rows.
    ///
    /// For example:
    ///
    ///     let request = Author.including(all: Author.books)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Author(row: row).name)
    ///     // Prints "Herman Melville"
    ///
    ///     let books: [Book] = try row["books"]
    ///     print(books[0].title)
    ///     // Prints "Moby-Dick"
    public subscript<Collection>(_ key: String)
    -> Collection
    where
        Collection: RangeReplaceableCollection,
        Collection.Element: FetchableRecord
    {
        get throws { try decode(Collection.self, forPrefetchKey: key) }
    }
    
    /// Returns the set of records encoded in the given prefetched rows.
    ///
    /// For example:
    ///
    ///     let request = Author.including(all: Author.books)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Author(row: row).name)
    ///     // Prints "Herman Melville"
    ///
    ///     let books: Set<Book> = try row["books"]
    ///     print(books.first!.title)
    ///     // Prints "Moby-Dick"
    public subscript<Record: FetchableRecord & Hashable>(_ key: String) -> Set<Record> {
        get throws { try decode(Set<Record>.self, forPrefetchKey: key) }
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
    ///     let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
    ///
    ///     row.scopes.count  // 2
    ///     row.scopes.names  // ["foo", "bar"]
    ///
    ///     row.scopes["foo"] // [foo:1]
    ///     row.scopes["bar"] // [bar:2]
    ///     row.scopes["baz"] // nil
    public var scopes: ScopesView {
        impl.scopes(prefetchedRows: prefetchedRows)
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
    ///     let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
    ///
    ///     row.scopesTree.names  // ["foo", "bar", "baz"]
    ///
    ///     row.scopesTree["foo"] // [foo:1]
    ///     row.scopesTree["bar"] // [bar:2]
    ///     row.scopesTree["baz"] // [baz:3]
    public var scopesTree: ScopesTreeView {
        ScopesTreeView(scopes: scopes)
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
        var row = impl.unscopedRow(self)
        
        // Remove prefetchedRows as well (yes the property is badly named).
        // The goal is to ease testing, so we remove everything which is
        // not columns.
        if row.prefetchedRows.isEmpty == false {
            // Make sure we build another Row instance
            row = Row(impl: row.copy().impl)
            assert(row !== self)
            assert(row.prefetchedRows.isEmpty)
        }
        return row
    }
    
    /// Return the raw row fetched from the database.
    ///
    /// This property can turn out useful when you debug the consumption of
    /// adapted rows, such as rows fetched from joined requests.
    public var unadapted: Row {
        impl.unadaptedRow(self)
    }
}

// MARK: - Throwing DatabaseValueConvertible Decoding Methods

extension Row {
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// If the SQLite value is NULL, or if the conversion fails, a
    /// `DatabaseDecodingError` is thrown.
    @inlinable
    func decode<Value: DatabaseValueConvertible>(
        _ type: Value.Type = Value.self,
        atIndex index: Int)
    throws -> Value
    {
        _checkIndex(index)
        return try Value.decode(fromRow: self, atUncheckedIndex: index)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the row does not contain the column, or if the SQLite value is NULL,
    /// or if the SQLite value can not be converted to `Value`, a
    /// `DatabaseDecodingError` is thrown.
    @inlinable
    func decode<Value: DatabaseValueConvertible>(
        _ type: Value.Type = Value.self,
        forColumn column: String)
    throws -> Value
    {
        guard let index = index(forColumn: column) else {
            if let value = Value._fromMissingColumn() {
                return value
            } else {
                throw DatabaseDecodingError.columnNotFound(column, context: RowDecodingContext(
                    row: self,
                    key: .columnName(column)))
            }
        }
        return try Value.decode(fromRow: self, atUncheckedIndex: index)
    }
}

// MARK: - Throwing DatabaseValueConvertible & StatementColumnConvertible Decoding Methods

extension Row {
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// If the SQLite value is NULL, or if the conversion fails, a
    /// `DatabaseDecodingError` is thrown.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// StatementColumnConvertible. It *may* trigger SQLite built-in conversions
    /// (see <https://www.sqlite.org/datatype3.html>).
    @inline(__always)
    @inlinable
    func decode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type = Value.self,
        atIndex index: Int)
    throws -> Value
    {
        _checkIndex(index)
        return try Value.fastDecode(fromRow: self, atUncheckedIndex: index)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the row does not contain the column, or if the SQLite value is NULL,
    /// or if the SQLite value can not be converted to `Value`, a
    /// `DatabaseDecodingError` is thrown.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// StatementColumnConvertible. It *may* trigger SQLite built-in conversions
    /// (see <https://www.sqlite.org/datatype3.html>).
    @inlinable
    func decode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type = Value.self,
        forColumn column: String)
    throws -> Value
    {
        guard let index = index(forColumn: column) else {
            if let value = Value._fromMissingColumn() {
                return value
            } else {
                throw DatabaseDecodingError.columnNotFound(column, context: RowDecodingContext(
                    row: self,
                    key: .columnName(column)))
            }
        }
        return try Value.fastDecode(fromRow: self, atUncheckedIndex: index)
    }
    
    // Support for fast decoding in scoped rows
    @usableFromInline
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value
    {
        try impl.fastDecode(type, atUncheckedIndex: index)
    }
}

// MARK: - Throwing Data Decoding Methods

extension Row {
    /// Returns the optional Data at given index.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// If the SQLite value is NULL, the result is nil. If the SQLite value can
    /// not be converted to Data, a `DatabaseDecodingError` is thrown.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    func decodeDataNoCopyIfPresent(atIndex index: Int) throws -> Data? {
        _checkIndex(index)
        return try impl.fastDecodeDataNoCopyIfPresent(atUncheckedIndex: index)
    }
    
    /// Returns the Data at given index.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// If the SQLite value is NULL, or if the SQLite value can not be converted
    /// to Data, a `DatabaseDecodingError` is thrown.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    func decodeDataNoCopy(atIndex index: Int) throws -> Data {
        _checkIndex(index)
        return try impl.fastDecodeDataNoCopy(atUncheckedIndex: index)
    }
    
    /// Returns the optional Data at given column.
    ///
    /// Column name lookup is case-insensitive, and when several columns have
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. If the SQLite value can not be converted to Data, a
    /// `DatabaseDecodingError` is thrown.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    func decodeDataNoCopyIfPresent(forColumn column: String) throws -> Data? {
        guard let index = index(forColumn: column) else {
            return nil
        }
        return try impl.fastDecodeDataNoCopyIfPresent(atUncheckedIndex: index)
    }
    
    // Support for fast decoding in scoped rows
    func fastDecodeDataNoCopy(atUncheckedIndex index: Int) throws -> Data {
        try impl.fastDecodeDataNoCopy(atUncheckedIndex: index)
    }
    
    // Support for fast decoding in scoped rows
    func fastDecodeDataNoCopyIfPresent(atUncheckedIndex index: Int) throws -> Data? {
        try impl.fastDecodeDataNoCopyIfPresent(atUncheckedIndex: index)
    }
}

// MARK: - Throwing Record Decoding Methods

extension Row {
    /// Returns the eventual record associated with the given scope.
    ///
    /// For example:
    ///
    ///     let request = Book.including(optional: Book.author)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let author: Author? = try row["author"]
    ///     print(author.name)
    ///     // Prints "Herman Melville"
    ///
    /// Associated records stored in nested associations are available, too:
    ///
    ///     let request = Book.including(optional: Book.author.including(optional: Author.country))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let country: Country? = try row["country"]
    ///     print(country.name)
    ///     // Prints "United States"
    ///
    /// Nil is returned if the scope is not available, or contains only
    /// null values.
    ///
    /// See <https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support>
    /// for more information.
    func decodeIfPresent<Record: FetchableRecord>(
        _ type: Record.Type = Record.self,
        forScope scope: String)
    throws -> Record?
    {
        guard let scopedRow = scopesTree[scope], scopedRow.containsNonNullValue else {
            return nil
        }
        return try Record(row: scopedRow)
    }
    
    /// Returns the record associated with the given scope.
    ///
    /// For example:
    ///
    ///     let request = Book.including(required: Book.author)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let author: Author = try row["author"]
    ///     print(author.name)
    ///     // Prints "Herman Melville"
    ///
    /// Associated records stored in nested associations are available, too:
    ///
    ///     let request = Book.including(required: Book.author.including(required: Author.country))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let country: Country = try row["country"]
    ///     print(country.name)
    ///     // Prints "United States"
    ///
    /// An error is raised if the scope is not available, or contains only
    /// null values.
    ///
    /// See <https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support>
    /// for more information.
    func decode<Record: FetchableRecord>(
        _ type: Record.Type = Record.self,
        forScope scope: String)
    throws -> Record
    {
        guard let scopedRow = scopesTree[scope] else {
            let availableScopes = scopesTree.names
            if availableScopes.isEmpty {
                throw DatabaseDecodingError.keyNotFound(.scope(scope), DatabaseDecodingError.Context(
                    decodingContext: RowDecodingContext(row: self, key: .scope(scope)),
                    debugDescription: """
                        scope not found: \(String(reflecting: scope))
                        """))
            } else {
                throw DatabaseDecodingError.keyNotFound(.scope(scope), DatabaseDecodingError.Context(
                    decodingContext: RowDecodingContext(row: self, key: .scope(scope)),
                    debugDescription: """
                        scope not found: \(String(reflecting: scope)) - \
                        available scopes: \(availableScopes.sorted())
                        """))
            }
        }
        guard scopedRow.containsNonNullValue else {
            throw DatabaseDecodingError.valueMismatch(
                Record.self,
                DatabaseDecodingError.Context(
                    decodingContext: RowDecodingContext(row: self, key: .scope(scope)),
                    debugDescription: """
                        scope \(String(reflecting: scope)) only contains null values
                        """))
        }
        return try Record(row: scopedRow)
    }
}

// MARK: - Throwing Record RangeReplaceableCollection and Set Methods

extension Row {
    /// Returns the records encoded in the given prefetched rows.
    ///
    /// For example:
    ///
    ///     let request = Author.including(all: Author.books)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Author(row: row).name)
    ///     // Prints "Herman Melville"
    ///
    ///     let books: [Book] = try row["books"]
    ///     print(books[0].title)
    ///     // Prints "Moby-Dick"
    func decode<Collection>(
        _ type: Collection.Type = Collection.self,
        forPrefetchKey key: String)
    throws -> Collection
    where
        Collection: RangeReplaceableCollection,
        Collection.Element: FetchableRecord
    {
        guard let rows = prefetchedRows[key] else {
            let availableKeys = prefetchedRows.keys
            if availableKeys.isEmpty {
                throw DatabaseDecodingError.keyNotFound(.prefetchKey(key), DatabaseDecodingError.Context(
                    decodingContext: RowDecodingContext(row: self, key: .prefetchKey(key)),
                    debugDescription: """
                        prefetch key not found: \(String(reflecting: key))
                        """))
            } else {
                throw DatabaseDecodingError.keyNotFound(.prefetchKey(key), DatabaseDecodingError.Context(
                    decodingContext: RowDecodingContext(row: self, key: .prefetchKey(key)),
                    debugDescription: """
                        prefetch key not found: \(String(reflecting: key)) - \
                        available prefetch keys: \(availableKeys.sorted())
                        """))
            }
        }
        
        var collection = Collection()
        collection.reserveCapacity(rows.count)
        for row in rows {
            try collection.append(Collection.Element(row: row))
        }
        return collection
    }
    
    /// Returns the set of records encoded in the given prefetched rows.
    ///
    /// For example:
    ///
    ///     let request = Author.including(all: Author.books)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(Author(row: row).name)
    ///     // Prints "Herman Melville"
    ///
    ///     let books: Set<Book> = try row["books"]
    ///     print(books.first!.title)
    ///     // Prints "Moby-Dick"
    func decode<Record: FetchableRecord & Hashable>(
        _ type: Set<Record>.Type = Set<Record>.self,
        forPrefetchKey key: String)
    throws -> Set<Record>
    {
        guard let rows = prefetchedRows[key] else {
            let availableKeys = prefetchedRows.keys
            if availableKeys.isEmpty {
                throw DatabaseDecodingError.keyNotFound(.prefetchKey(key), DatabaseDecodingError.Context(
                    decodingContext: RowDecodingContext(row: self, key: .prefetchKey(key)),
                    debugDescription: """
                        prefetch key not found: \(String(reflecting: key))
                        """))
            } else {
                throw DatabaseDecodingError.keyNotFound(.prefetchKey(key), DatabaseDecodingError.Context(
                    decodingContext: RowDecodingContext(row: self, key: .prefetchKey(key)),
                    debugDescription: """
                        prefetch key not found: \(String(reflecting: key)) - \
                        available prefetch keys: \(availableKeys.sorted())
                        """))
            }
        }
        var set = Set<Record>(minimumCapacity: rows.count)
        for row in rows {
            try set.insert(Record(row: row))
        }
        return set
    }
}

// MARK: - RowCursor

/// A cursor of database rows. For example:
///
///     try dbQueue.read { db in
///         let rows: RowCursor = try Row.fetchCursor(db, sql: "SELECT * FROM player")
///     }
public final class RowCursor: DatabaseCursor {
    public typealias Element = Row
    public let statement: Statement
    /// :nodoc:
    public var _isDone = false
    @usableFromInline let _row: Row // Reused for performance
    
    init(statement: Statement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws {
        self.statement = statement
        self._row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        
        // Assume cursor is created for immediate iteration: reset and set arguments
        try statement.reset(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? statement.reset()
    }
    
    /// :nodoc:
    @inlinable
    public func _element(sqliteStatement: SQLiteStatement) -> Row { _row }
}

extension Row {
    
    // MARK: - Fetching From Prepared Statement
    
    /// Returns a cursor over rows fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT ...")
    ///     let rows = try Row.fetchCursor(statement) // RowCursor
    ///     while let row = try rows.next() { // Row
    ///         let id: Int64 = try row[0]
    ///         let name: String = try row[1]
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
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> RowCursor
    {
        try RowCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of rows fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT ...")
    ///     let rows = try Row.fetchAll(statement)
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> [Row]
    {
        // The cursor reuses a single mutable row. Return immutable copies.
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter).map { $0.copy() })
    }
    
    /// Returns a set of rows fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT ...")
    ///     let rows = try Row.fetchSet(statement)
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchSet(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> Set<Row>
    {
        // The cursor reuses a single mutable row. Return immutable copies.
        return try Set(fetchCursor(statement, arguments: arguments, adapter: adapter).map { $0.copy() })
    }
    
    /// Returns a single row fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT ...")
    ///     let row = try Row.fetchOne(statement)
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> Row?
    {
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
    ///     let rows = try Row.fetchCursor(db, sql: "SELECT id, name FROM player") // RowCursor
    ///     while let row = try rows.next() { // Row
    ///         let id: Int64 = try row[0]
    ///         let name: String = try row[1]
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
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> RowCursor
    {
        try fetchCursor(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of rows fetched from an SQL query.
    ///
    ///     let rows = try Row.fetchAll(db, sql: "SELECT id, name FROM player") // [Row]
    ///     for row in rows {
    ///         let id: Int64 = try row[0]
    ///         let name: String = try row[1]
    ///     }
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> [Row]
    {
        try fetchAll(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a set of rows fetched from an SQL query.
    ///
    ///     let rows = try Row.fetchSet(db, sql: "SELECT id, name FROM player") // Set<Row>
    ///     for row in rows {
    ///         let id: Int64 = try row[0]
    ///         let name: String = try row[1]
    ///     }
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchSet(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> Set<Row>
    {
        try fetchSet(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single row fetched from an SQL query.
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT id, name FROM player") // Row?
    ///     if let row = row {
    ///         let id: Int64 = try row[0]
    ///         let name: String = try row[1]
    ///     }
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> Row?
    {
        try fetchOne(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension Row {
    
    // MARK: - Fetching From FetchRequest
    
    /// Returns a cursor over rows fetched from a fetch request.
    ///
    ///     let request = Player.all()
    ///     let rows = try Row.fetchCursor(db, request) // RowCursor
    ///     while let row = try rows.next() { // Row
    ///         let id: Int64 = try row["id"]
    ///         let name: String = try row["name"]
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
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor<R: FetchRequest>(_ db: Database, _ request: R) throws -> RowCursor {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        precondition(request.supplementaryFetch == nil, "Not implemented: fetchCursor with supplementary fetch")
        return try fetchCursor(request.statement, adapter: request.adapter)
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
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        let rows = try fetchAll(request.statement, adapter: request.adapter)
        try request.supplementaryFetch?(db, rows)
        return rows
    }
    
    /// Returns a set of rows fetched from a fetch request.
    ///
    ///     let request = Player.all()
    ///     let rows = try Row.fetchSet(db, request)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A set of rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchSet<R: FetchRequest>(_ db: Database, _ request: R) throws -> Set<Row> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        if let supplementaryFetch = request.supplementaryFetch {
            let rows = try fetchAll(request.statement, adapter: request.adapter)
            try supplementaryFetch(db, rows)
            return Set(rows)
        } else {
            return try fetchSet(request.statement, adapter: request.adapter)
        }
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
        let request = try request.makePreparedRequest(db, forSingleResult: true)
        guard let row = try fetchOne(request.statement, adapter: request.adapter) else {
            return nil
        }
        try request.supplementaryFetch?(db, [row])
        return row
    }
}

extension FetchRequest where RowDecoder == Row {
    
    // MARK: Fetching Rows
    
    /// A cursor over fetched rows.
    ///
    ///     let request: ... // Some FetchRequest that fetches Row
    ///     let rows = try request.fetchCursor(db) // RowCursor
    ///     while let row = try rows.next() {  // Row
    ///         let id: Int64 = try row[0]
    ///         let name: String = try row[1]
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
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RowCursor {
        try Row.fetchCursor(db, self)
    }
    
    /// An array of fetched rows.
    ///
    ///     let request: ... // Some FetchRequest that fetches Row
    ///     let rows = try request.fetchAll(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [Row] {
        try Row.fetchAll(db, self)
    }
    
    /// A set of fetched rows.
    ///
    ///     let request: ... // Some FetchRequest that fetches Row
    ///     let rows = try request.fetchSet(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: A set of fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<Row> {
        try Row.fetchSet(db, self)
    }
    
    /// The first fetched row.
    ///
    ///     let request: ... // Some FetchRequest that fetches Row
    ///     let row = try request.fetchOne(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional row.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> Row? {
        try Row.fetchOne(db, self)
    }
}

// RandomAccessCollection
extension Row {
    
    // MARK: - Row as a Collection of (ColumnName, DatabaseValue) Pairs
    
    /// The index of the first (ColumnName, DatabaseValue) pair.
    /// :nodoc:
    public var startIndex: RowIndex { RowIndex(0) }
    
    /// The "past-the-end" index, successor of the index of the last
    /// (ColumnName, DatabaseValue) pair.
    /// :nodoc:
    public var endIndex: RowIndex { RowIndex(count) }
    
    /// Accesses the (ColumnName, DatabaseValue) pair at given index.
    public subscript(position: RowIndex) -> (String, DatabaseValue) {
        let index = position.index
        _checkIndex(index)
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
        
        guard lhs.prefetchedRows == rhs.prefetchedRows else {
            return false
        }
        
        return true
    }
}

// Hashable
extension Row {
    /// :nodoc:
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for (column, dbValue) in self {
            hasher.combine(column)
            hasher.combine(dbValue)
        }
    }
}

// CustomStringConvertible & CustomDebugStringConvertible
extension Row {
    /// :nodoc:
    public var description: String {
        "["
            + map { (column, dbValue) in "\(column):\(dbValue)" }.joined(separator: " ")
            + "]"
    }
    
    /// :nodoc:
    public var debugDescription: String {
        debugDescription(level: 0)
    }
    
    private func debugDescription(level: Int) -> String {
        if level == 0 && self == self.unadapted && prefetchedRows.prefetches.isEmpty {
            return description
        }
        let prefix = repeatElement("  ", count: level + 1).joined()
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
        for key in prefetchedRows.keys.sorted() {
            let rows = prefetchedRows[key]!
            let prefetchedRowsDescription: String
            switch rows.count {
            case 0:
                prefetchedRowsDescription = "0 row"
            case 1:
                prefetchedRowsDescription = "1 row"
            case let count:
                prefetchedRowsDescription = "\(count) rows"
            }
            str += "\n" + prefix + "+ " + key + ": \(prefetchedRowsDescription)"
        }
        
        return str
    }
}


// MARK: - RowIndex

/// Indexes to (ColumnName, DatabaseValue) pairs in a database row.
public struct RowIndex: Comparable, Strideable {
    let index: Int
    init(_ index: Int) { self.index = index }
}

// Comparable
extension RowIndex {
    /// :nodoc:
    public static func == (lhs: RowIndex, rhs: RowIndex) -> Bool {
        lhs.index == rhs.index
    }
    
    /// :nodoc:
    public static func < (lhs: RowIndex, rhs: RowIndex) -> Bool {
        lhs.index < rhs.index
    }
}

// Strideable: support for Row: RandomAccessCollection
extension RowIndex {
    /// :nodoc:
    public func distance(to other: RowIndex) -> Int {
        other.index - index
    }
    
    /// :nodoc:
    public func advanced(by n: Int) -> RowIndex {
        RowIndex(index + n)
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
    ///     let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
    ///
    ///     row.scopes.count  // 2
    ///     row.scopes.names  // ["foo", "bar"]
    ///
    ///     row.scopes["foo"] // [foo:1]
    ///     row.scopes["bar"] // [bar:2]
    ///     row.scopes["baz"] // nil
    public struct ScopesView: Collection {
        public typealias Index = Dictionary<String, _LayoutedRowAdapter>.Index
        private let row: Row
        private let scopes: [String: _LayoutedRowAdapter]
        private let prefetchedRows: Row.PrefetchedRowsView
        
        /// The scopes defined on this row.
        public var names: Dictionary<String, _LayoutedRowAdapter>.Keys {
            scopes.keys
        }
        
        init() {
            self.init(row: Row(), scopes: [:], prefetchedRows: Row.PrefetchedRowsView())
        }
        
        init(row: Row, scopes: [String: _LayoutedRowAdapter], prefetchedRows: Row.PrefetchedRowsView) {
            self.row = row
            self.scopes = scopes
            self.prefetchedRows = prefetchedRows
        }
        
        /// :nodoc:
        public var startIndex: Index {
            scopes.startIndex
        }
        
        /// :nodoc:
        public var endIndex: Index {
            scopes.endIndex
        }
        
        /// :nodoc:
        public func index(after i: Index) -> Index {
            scopes.index(after: i)
        }
        
        /// :nodoc:
        public subscript(position: Index) -> (name: String, row: Row) {
            let (name, adapter) = scopes[position]
            let adaptedRow = Row(base: row, adapter: adapter)
            if let prefetch = prefetchedRows.prefetches[name] {
                // Let the adapted row access its own prefetched rows.
                // Use case:
                //
                //      let request = A.including(required: A.b.including(all: B.c))
                //      let row = try Row.fetchOne(db, request)!
                //      row.prefetchedRows["cs"]              // Some array
                //      row.scopes["b"]!.prefetchedRows["cs"] // The same array
                adaptedRow.prefetchedRows = Row.PrefetchedRowsView(prefetches: prefetch.prefetches)
            }
            return (name: name, row: adaptedRow)
        }
        
        /// Returns the row associated with the given scope, or nil if the
        /// scope is not defined.
        public subscript(_ name: String) -> Row? {
            scopes.index(forKey: name).map { self[$0].row }
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
    ///     let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
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
        
        /// Returns the row associated with the given scope.
        ///
        /// For example:
        ///
        ///     let request = Book.including(required: Book.author)
        ///     let row = try Row.fetchOne(db, request)!
        ///
        ///     print(row)
        ///     // Prints [id:42 title:"Moby-Dick"]
        ///
        ///     let authorRow = row.scopesTree["author"]
        ///     print(authorRow)
        ///     // Prints [id:1 name:"Herman Melville"]
        ///
        /// Associated rows stored in nested associations are available, too:
        ///
        ///     let request = Book.including(required: Book.author.including(required: Author.country))
        ///     let row = try Row.fetchOne(db, request)!
        ///
        ///     print(row)
        ///     // Prints [id:42 title:"Moby-Dick"]
        ///
        ///     let countryRow = row.scopesTree["country"]
        ///     print(countryRow)
        ///     // Prints [code:"US" name:"United States"]
        ///
        /// Nil is returned if the scope is not available.
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

// MARK: - Row.PrefetchedRowsView

extension Row {
    fileprivate struct Prefetch: Equatable {
        // Nil for intermediate associations
        var rows: [Row]?
        // OrderedDictionary so that breadth-first search gives a consistent result
        // (we preserve the ordering of associations in the request)
        var prefetches: OrderedDictionary<String, Prefetch>
    }
    
    /// A view on the prefetched associated rows.
    ///
    /// For example:
    ///
    ///     let request = Author.including(all: Author.books)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     print(row)
    ///     // Prints [id:1 name:"Herman Melville"]
    ///
    ///     let bookRows = row.prefetchedRows["books"]
    ///     print(bookRows[0])
    ///     // Prints [id:42 title:"Moby-Dick"]
    public struct PrefetchedRowsView: Equatable {
        // OrderedDictionary so that breadth-first search gives a consistent result
        // (we preserve the ordering of associations in the request)
        fileprivate var prefetches: OrderedDictionary<String, Prefetch> = [:]
        
        /// True if there is no prefetched associated rows.
        public var isEmpty: Bool {
            prefetches.isEmpty
        }
        
        /// The keys for available prefetched rows
        ///
        /// For example:
        ///
        ///     let request = Author.including(all: Author.books)
        ///     let row = try Row.fetchOne(db, request)!
        ///
        ///     print(row.prefetchedRows.keys)
        ///     // Prints ["books"]
        public var keys: Set<String> {
            var result: Set<String> = []
            var fifo = Array(prefetches)
            while !fifo.isEmpty {
                let (prefetchKey, prefetch) = fifo.removeFirst()
                if prefetch.rows != nil {
                    result.insert(prefetchKey)
                }
                fifo.append(contentsOf: prefetch.prefetches)
            }
            return result
        }
        
        /// Returns the prefetched rows associated with the given key.
        ///
        /// For example:
        ///
        ///     let request = Author.including(all: Author.books)
        ///     let row = try Row.fetchOne(db, request)!
        ///
        ///     print(row)
        ///     // Prints [id:1 name:"Herman Melville"]
        ///
        ///     let bookRows = row.prefetchedRows["books"]
        ///     print(bookRows[0])
        ///     // Prints [id:42 title:"Moby-Dick"]
        ///
        /// Prefetched rows stored in nested "to-one" associations are
        /// available, too.
        ///
        /// Nil is returned if the key is not available.
        public subscript(_ key: String) -> [Row]? {
            var fifo = Array(prefetches)
            while !fifo.isEmpty {
                let (prefetchKey, prefetch) = fifo.removeFirst()
                if prefetchKey == key {
                    return prefetch.rows
                }
                fifo.append(contentsOf: prefetch.prefetches)
            }
            return nil
        }
        
        mutating func setRows(_ rows: [Row], forKeyPath keyPath: [String]) {
            prefetches.setRows(rows, forKeyPath: keyPath)
        }
    }
}

extension OrderedDictionary where Key == String, Value == Row.Prefetch {
    fileprivate mutating func setRows(_ rows: [Row], forKeyPath keyPath: [String]) {
        var keyPath = keyPath
        let key = keyPath.removeFirst()
        if keyPath.isEmpty {
            self[key, default: Row.Prefetch(rows: nil, prefetches: [:])].rows = rows
        } else {
            self[key, default: Row.Prefetch(rows: nil, prefetches: [:])].prefetches.setRows(rows, forKeyPath: keyPath)
        }
    }
}

// MARK: - RowImpl

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
    
    func fastDecodeDataNoCopy(atUncheckedIndex index: Int) throws -> Data
    
    func fastDecodeDataNoCopyIfPresent(atUncheckedIndex index: Int) throws -> Data?
    
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
        return Row(impl: ArrayRowImpl(columns: Array(row)))
    }
    
    func unscopedRow(_ row: Row) -> Row {
        // unless customized, assume unadapted row (see AdaptedRowImpl for customization)
        return row
    }
    
    func unadaptedRow(_ row: Row) -> Row {
        // unless customized, assume unadapted row (see AdaptedRowImpl for customization)
        return row
    }
    
    func scopes(prefetchedRows: Row.PrefetchedRowsView) -> Row.ScopesView {
        // unless customized, assume unuscoped row (see AdaptedRowImpl for customization)
        return Row.ScopesView()
    }
    
    func hasNull(atUncheckedIndex index: Int) -> Bool {
        // unless customized, use slow check (see StatementRowImpl and AdaptedRowImpl for customization)
        return databaseValue(atUncheckedIndex: index).isNull
    }
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value
    {
        // unless customized, use slow decoding (see StatementRowImpl and AdaptedRowImpl for customization)
        return try Value.decode(
            fromDatabaseValue: databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: Row(impl: self), key: .columnIndex(index)))
    }
    
    func fastDecodeDataNoCopy(atUncheckedIndex index: Int) throws -> Data {
        // unless customized, copy data (see StatementRowImpl and AdaptedRowImpl for customization)
        return try Data.decode(
            fromDatabaseValue: databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: Row(impl: self), key: .columnIndex(index)))
    }
    
    func fastDecodeDataNoCopyIfPresent(atUncheckedIndex index: Int) throws -> Data? {
        // unless customized, copy data (see StatementRowImpl and AdaptedRowImpl for customization)
        return try Optional<Data>.decode(
            fromDatabaseValue: databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: Row(impl: self), key: .columnIndex(index)))
    }
}

// TODO: merge with StatementCopyRowImpl eventually?
/// See Row.init(dictionary:)
struct ArrayRowImpl: RowImpl {
    let columns: [(String, DatabaseValue)]
    
    init<C>(columns: C)
    where C: Collection, C.Element == (String, DatabaseValue)
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

// @unchecked because columns property is not inferred as Sendable
// TODO: remove this @unchecked when compiler can handle tuples.
extension ArrayRowImpl: @unchecked Sendable { }


// TODO: merge with ArrayRowImpl eventually?
/// See Row.init(copiedFromStatementRef:sqliteStatement:)
private struct StatementCopyRowImpl: RowImpl {
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
private struct StatementRowImpl: RowImpl {
    let statement: Statement
    let sqliteStatement: SQLiteStatement
    let lowercaseColumnIndexes: [String: Int]
    
    init(sqliteStatement: SQLiteStatement, statement: Statement) {
        self.statement = statement
        self.sqliteStatement = sqliteStatement
        // Optimize row[columnName]
        let lowercaseColumnNames = (0..<sqlite3_column_count(sqliteStatement))
            .map { String(cString: sqlite3_column_name(sqliteStatement, Int32($0))).lowercased() }
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
        return sqlite3_column_type(sqliteStatement, Int32(index)) == SQLITE_NULL
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        DatabaseValue(sqliteStatement: sqliteStatement, index: Int32(index))
    }
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value
    {
        try Value.fastDecode(
            fromStatement: sqliteStatement,
            atUncheckedIndex: Int32(index),
            context: RowDecodingContext(statement: statement, index: index))
    }
    
    func fastDecodeDataNoCopy(atUncheckedIndex index: Int) throws -> Data {
        guard sqlite3_column_type(sqliteStatement, Int32(index)) != SQLITE_NULL else {
            throw DatabaseDecodingError.valueMismatch(Data.self, statement: statement, index: index)
        }
        guard let bytes = sqlite3_column_blob(sqliteStatement, Int32(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(sqliteStatement, Int32(index)))
        return Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes), count: count, deallocator: .none)
    }
    
    func fastDecodeDataNoCopyIfPresent(atUncheckedIndex index: Int) throws -> Data? {
        guard sqlite3_column_type(sqliteStatement, Int32(index)) != SQLITE_NULL else {
            return nil
        }
        guard let bytes = sqlite3_column_blob(sqliteStatement, Int32(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(sqliteStatement, Int32(index)))
        return Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes), count: count, deallocator: .none)
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
private struct SQLiteStatementRowImpl: RowImpl {
    let sqliteStatement: SQLiteStatement
    var count: Int { Int(sqlite3_column_count(sqliteStatement)) }
    var isFetched: Bool { true }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        String(cString: sqlite3_column_name(sqliteStatement, Int32(index)))
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        DatabaseValue(sqliteStatement: sqliteStatement, index: Int32(index))
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
private struct EmptyRowImpl: RowImpl {
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
