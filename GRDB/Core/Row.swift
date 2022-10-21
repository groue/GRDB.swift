import Foundation

/// A database row.
///
/// ## Topics
///
/// ### Creating Rows
///
/// - ``init()``
/// - ``init(_:)-5uezw``
/// - ``init(_:)-65by6``
///
/// ### Copying a Row
///
/// - ``copy()``
///
/// ### Row Informations
///
/// - ``columnNames``
/// - ``containsNonNullValue``
/// - ``count-5flaw``
/// - ``databaseValues``
/// - ``hasColumn(_:)``
/// - ``hasNull(atIndex:)``
///
/// ### Accessing Row Values by Int Index
///
/// - ``subscript(_:)-9c1fw``
/// - ``subscript(_:)-3jhwm``
/// - ``subscript(_:)-7krrg``
///
/// ### Accessing Row Values by Column Name
///
/// - ``subscript(_:)-3tp8o``
/// - ``subscript(_:)-4k8od``
/// - ``subscript(_:)-9rbo7``
///
/// ### Accessing Row Values by Column
///
/// - ``subscript(_:)-9txgm``
/// - ``subscript(_:)-2esg7``
/// - ``subscript(_:)-wl9a``
///
/// ### Accessing Data Values
///
/// - ``dataNoCopy(_:)``
/// - ``dataNoCopy(atIndex:)``
/// - ``dataNoCopy(named:)``
///
/// ### Row Scopes & Associated Rows
///
/// - ``prefetchedRows``
/// - ``scopes``
/// - ``scopesTree``
/// - ``unadapted``
/// - ``unscoped``
/// - ``subscript(_:)-4dx01``
/// - ``subscript(_:)-6ge6t``
/// - ``subscript(_:)-8god3``
/// - ``subscript(_:)-jwnx``
/// - ``PrefetchedRowsView``
/// - ``ScopesTreeView``
/// - ``ScopesView``
///
/// ### Fetching Rows
///
/// ### Row as RandomAccessCollection
///
/// - ``columnNames``
/// - ``count-5flaw``
/// - ``databaseValues``
/// - ``subscript(_:)-11eb``
/// - ``RowIndex``
///
/// ### Adapting Rows
///
/// - ``RowAdapter``
///
/// ### Supporting Types
///
/// - ``RowCursor``
public final class Row {
    // It is not a violation of the Demeter law when another type uses this
    // property, which is exposed for optimizations.
    let impl: any RowImpl
    
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
    
    /// Creates a row from a dictionary of database values.
    public convenience init(_ dictionary: [String: (any DatabaseValueConvertible)?]) {
        self.init(impl: ArrayRowImpl(columns: dictionary.map { ($0, $1?.databaseValue ?? .null) }))
    }
    
    /// Creates a row from a dictionary.
    ///
    /// The result is nil unless all dictionary keys are strings, and values
    /// conform to ``DatabaseValueConvertible``.
    public convenience init?(_ dictionary: [AnyHashable: Any]) {
        var initDictionary = [String: (any DatabaseValueConvertible)?]()
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
    
    init(impl: any RowImpl) {
        self.statement = nil
        self.sqliteStatement = nil
        self.impl = impl
        self.count = impl.count
    }
}

extension Row {
    
    // MARK: - Columns
    
    /// The names of columns in the row, from left to right.
    ///
    /// Columns appear in the same order as they occur as the `.0` member
    /// of column-value pairs in `self`.
    public var columnNames: LazyMapCollection<Row, String> {
        lazy.map { $0.0 }
    }
    
    /// Returns whether the row has one column with the given name
    /// (case-insensitive).
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
    
    /// Returns a boolean value indicating if the row contains one value this
    /// is not `NULL`.
    ///
    /// For example:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 'foo', NULL")!
    /// row.containsNonNullValue // true
    ///
    /// let row = try Row.fetchOne(db, sql: "SELECT NULL, NULL")!
    /// row.containsNonNullValue // false
    /// ```
    public var containsNonNullValue: Bool {
        for i in (0..<count) where !impl.hasNull(atUncheckedIndex: i) {
            return true
        }
        
        for (_, scopedRow) in scopes where scopedRow.containsNonNullValue {
            return true
        }
        
        return false
    }
    
    /// Returns whether the row has a `NULL` value at given index.
    ///
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    ///
    /// This method is equivalent to `row[index] == nil`, but may be preferred
    /// in performance-critical code because it avoids decoding
    /// database values.
    public func hasNull(atIndex index: Int) -> Bool {
        _checkIndex(index)
        return impl.hasNull(atUncheckedIndex: index)
    }
    
    /// Returns `Int64`, `Double`, `String`, `Data` or nil, depending on the
    /// value stored at the given index.
    ///
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    public subscript(_ index: Int) -> (any DatabaseValueConvertible)? {
        _checkIndex(index)
        return impl.databaseValue(atUncheckedIndex: index).storage.value
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    ///
    /// For example:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 42")!
    /// let score: Int = row[0] // 42
    ///
    /// let row = try Row.fetchOne(db, sql: "SELECT 'Alice'")!
    /// let name: String = row[0] // "Alice"
    /// ```
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT NULL")!
    /// let name: String? = row[0] // nil
    /// ```
    @inlinable
    public subscript<Value: DatabaseValueConvertible>(_ index: Int) -> Value {
        try! decode(Value.self, atIndex: index)
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// ``StatementColumnConvertible``. It can trigger [SQLite built-in
    /// conversions](https://www.sqlite.org/datatype3.html).
    ///
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    ///
    /// For example:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 42")!
    /// let score: Int = row[0] // 42
    ///
    /// let row = try Row.fetchOne(db, sql: "SELECT 'Alice'")!
    /// let name: String = row[0] // "Alice"
    /// ```
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT NULL")!
    /// let name: String? = row[0] // nil
    /// ```
    @inline(__always)
    @inlinable
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ index: Int) -> Value {
        try! decode(Value.self, atIndex: index)
    }
    
    /// Returns `Int64`, `Double`, `String`, `Data` or nil, depending on the
    /// value stored at the given column.
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// The result is nil if the row does not contain any column with that name.
    public subscript(_ columnName: String) -> (any DatabaseValueConvertible)? {
        // IMPLEMENTATION NOTE
        // This method has a single known use case: checking if the value is nil,
        // as in:
        //
        //     if row["foo"] != nil { ... }
        //
        // Without this method, the code above would not compile.
        guard let index = index(forColumn: columnName) else {
            return nil
        }
        return impl.databaseValue(atUncheckedIndex: index).storage.value
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// For example:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 42 AS score")!
    /// let score: Int = row["score"] // 42
    ///
    /// let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    /// let name: String = row["name"] // "Alice"
    /// ```
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT NULL AS name")!
    /// let name: String? = row["name"] // nil
    /// ```
    ///
    /// When the column does not exist, nil is returned:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    /// let name: String? = row["missing"] // nil
    /// ```
    @inlinable
    public subscript<Value: DatabaseValueConvertible>(_ columnName: String) -> Value {
        try! decode(Value.self, forKey: columnName)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// ``StatementColumnConvertible``. It can trigger [SQLite built-in
    /// conversions](https://www.sqlite.org/datatype3.html).
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// For example:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 42 AS score")!
    /// let score: Int = row["score"] // 42
    ///
    /// let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    /// let name: String = row["name"] // "Alice"
    /// ```
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT NULL AS name")!
    /// let name: String? = row["name"] // nil
    /// ```
    ///
    /// When the column does not exist, nil is returned:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    /// let name: String? = row["missing"] // nil
    /// ```
    @inlinable
    public subscript<Value: DatabaseValueConvertible & StatementColumnConvertible>(_ columnName: String) -> Value {
        try! decode(Value.self, forKey: columnName)
    }
    
    /// Returns `Int64`, `Double`, `String`, `Data` or nil, depending on the
    /// value stored at the given column.
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// The result is nil if the row does not contain any column with that name.
    public subscript(_ column: some ColumnExpression) -> (any DatabaseValueConvertible)? {
        self[column.name]
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// For example:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 42 AS score")!
    /// let score: Int = row[Column("score")] // 42
    ///
    /// let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    /// let name: String = row[Column("name")] // "Alice"
    /// ```
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT NULL AS name")!
    /// let name: String? = row[Column("name")] // nil
    /// ```
    ///
    /// When the column does not exist, nil is returned:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    /// let name: String? = row[Column("missing")] // nil
    /// ```
    @inlinable
    public subscript<Value: DatabaseValueConvertible>(_ column: some ColumnExpression) -> Value {
        try! decode(Value.self, forKey: column.name)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// ``StatementColumnConvertible``. It can trigger [SQLite built-in
    /// conversions](https://www.sqlite.org/datatype3.html).
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// For example:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 42 AS score")!
    /// let score: Int = row[Column("score")] // 42
    ///
    /// let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    /// let name: String = row[Column("name")] // "Alice"
    /// ```
    ///
    /// When the database value may be nil, ask for an optional:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT NULL AS name")!
    /// let name: String? = row[Column("name")] // nil
    /// ```
    ///
    /// When the column does not exist, nil is returned:
    ///
    /// ```swift
    /// let row = try Row.fetchOne(db, sql: "SELECT 'Alice' AS name")!
    /// let name: String? = row[Column("missing")] // nil
    /// ```
    @inlinable
    public subscript<Value>(_ column: some ColumnExpression)
    -> Value
    where Value: DatabaseValueConvertible & StatementColumnConvertible
    {
        try! decode(Value.self, forKey: column.name)
    }
    
    /// Returns the optional `Data` at given index.
    ///
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    ///
    /// If the SQLite value is NULL, the result is nil. If the SQLite value can
    /// not be converted to Data, a fatal error is raised.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    public func dataNoCopy(atIndex index: Int) -> Data? {
        try! decodeDataNoCopyIfPresent(atIndex: index)
    }
    
    /// Returns the optional `Data` at given column.
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. If the SQLite value can not be converted to Data, a fatal error
    /// is raised.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    public func dataNoCopy(named columnName: String) -> Data? {
        try! decodeDataNoCopyIfPresent(forKey: columnName)
    }
    
    /// Returns the optional `Data` at given column.
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. If the SQLite value can not be converted to Data, a fatal error
    /// is raised.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    public func dataNoCopy(_ column: some ColumnExpression) -> Data? {
        try! decodeDataNoCopyIfPresent(forKey: column.name)
    }
}

extension Row {
    
    // MARK: - Extracting DatabaseValue
    
    /// The database values in the row, from left to right.
    ///
    /// Values appear in the same order as they occur as the `.1` member
    /// of column-value pairs in `self`.
    public var databaseValues: LazyMapCollection<Row, DatabaseValue> {
        lazy.map { $0.1 }
    }
}

extension Row {
    
    // MARK: - Extracting Records
    
    /// Returns the record associated with the given scope.
    ///
    /// For example:
    ///
    /// ```swift
    /// let request = Book.including(required: Book.author)
    /// let row = try Row.fetchOne(db, request)!
    ///
    /// try print(Book(row: row).title)
    /// // Prints "Moby-Dick"
    ///
    /// let author: Author = row["author"]
    /// print(author.name)
    /// // Prints "Herman Melville"
    /// ```
    ///
    /// Associated records stored in nested associations are available, too:
    ///
    /// ```swift
    /// let request = Book.including(required: Book.author.including(required: Author.country))
    /// let row = try Row.fetchOne(db, request)!
    ///
    /// try print(Book(row: row).title)
    /// // Prints "Moby-Dick"
    ///
    /// let country: Country = row["country"]
    /// print(country.name)
    /// // Prints "United States"
    /// ```
    ///
    /// A fatal error is raised if the scope is not available, or contains only
    /// null values.
    ///
    /// See <https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support>
    /// for more information.
    public subscript<Record: FetchableRecord>(_ scope: String) -> Record {
        try! decode(Record.self, forKey: scope)
    }
    
    /// Returns the eventual record associated with the given scope.
    ///
    /// For example:
    ///
    /// ```swift
    /// let request = Book.including(optional: Book.author)
    /// let row = try Row.fetchOne(db, request)!
    ///
    /// try print(Book(row: row).title)
    /// // Prints "Moby-Dick"
    ///
    /// let author: Author? = row["author"]
    /// print(author.name)
    /// // Prints "Herman Melville"
    /// ```
    ///
    /// Associated records stored in nested associations are available, too:
    ///
    /// ```swift
    /// let request = Book.including(optional: Book.author.including(optional: Author.country))
    /// let row = try Row.fetchOne(db, request)!
    ///
    /// try print(Book(row: row).title)
    /// // Prints "Moby-Dick"
    ///
    /// let country: Country? = row["country"]
    /// print(country.name)
    /// // Prints "United States"
    /// ```
    ///
    /// Nil is returned if the scope is not available, or contains only
    /// null values.
    ///
    /// See <https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support>
    /// for more information.
    public subscript<Record: FetchableRecord>(_ scope: String) -> Record? {
        try! decodeIfPresent(Record.self, forKey: scope)
    }
    
    /// Returns the records encoded in the given prefetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// let request = Author.including(all: Author.books)
    /// let row = try Row.fetchOne(db, request)!
    ///
    /// try print(Author(row: row).name)
    /// // Prints "Herman Melville"
    ///
    /// let books: [Book] = row["books"]
    /// print(books[0].title)
    /// // Prints "Moby-Dick"
    /// ```
    public subscript<Records>(_ key: String)
    -> Records
    where
        Records: RangeReplaceableCollection,
        Records.Element: FetchableRecord
    {
        try! decode(Records.self, forKey: key)
    }
    
    /// Returns the set of records encoded in the given prefetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// let request = Author.including(all: Author.books)
    /// let row = try Row.fetchOne(db, request)!
    ///
    /// try print(Author(row: row).name)
    /// // Prints "Herman Melville"
    ///
    /// let books: Set<Book> = row["books"]
    /// print(books.first!.title)
    /// // Prints "Moby-Dick"
    /// ```
    public subscript<Record: FetchableRecord & Hashable>(_ key: String) -> Set<Record> {
        try! decode(Set<Record>.self, forKey: key)
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
        
        // Remove prefetchedRows
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
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    ///
    /// If the SQLite value is NULL, or if the conversion fails, a
    /// `RowDecodingError` is thrown.
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
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// If the row does not contain the column, or if the SQLite value is NULL,
    /// or if the SQLite value can not be converted to `Value`, a
    /// `RowDecodingError` is thrown.
    @inlinable
    func decode<Value: DatabaseValueConvertible>(
        _ type: Value.Type = Value.self,
        forKey columnName: String)
    throws -> Value
    {
        guard let index = index(forColumn: columnName) else {
            if let value = Value.fromMissingColumn() {
                return value
            } else {
                throw RowDecodingError.columnNotFound(columnName, context: RowDecodingContext(row: self))
            }
        }
        return try Value.decode(fromRow: self, atUncheckedIndex: index)
    }
}

// MARK: - Throwing DatabaseValueConvertible & StatementColumnConvertible Decoding Methods

extension Row {
    /// Returns the value at given index, converted to the requested type.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// ``StatementColumnConvertible``. It can trigger [SQLite built-in
    /// conversions](https://www.sqlite.org/datatype3.html).
    ///
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    ///
    /// If the SQLite value is NULL, or if the conversion fails, a
    /// `RowDecodingError` is thrown.
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
    /// This method exists as an optimization opportunity for types that adopt
    /// ``StatementColumnConvertible``. It can trigger [SQLite built-in
    /// conversions](https://www.sqlite.org/datatype3.html).
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// If the row does not contain the column, or if the SQLite value is NULL,
    /// or if the SQLite value can not be converted to `Value`, a
    /// `RowDecodingError` is thrown.
    @inlinable
    func decode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type = Value.self,
        forKey columnName: String)
    throws -> Value
    {
        guard let index = index(forColumn: columnName) else {
            if let value = Value.fromMissingColumn() {
                return value
            } else {
                throw RowDecodingError.columnNotFound(columnName, context: RowDecodingContext(row: self))
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
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    ///
    /// If the SQLite value is NULL, the result is nil. If the SQLite value can
    /// not be converted to Data, a `RowDecodingError` is thrown.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    func decodeDataNoCopyIfPresent(atIndex index: Int) throws -> Data? {
        _checkIndex(index)
        return try impl.fastDecodeDataNoCopyIfPresent(atUncheckedIndex: index)
    }
    
    /// Returns the Data at given index.
    ///
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    ///
    /// If the SQLite value is NULL, or if the SQLite value can not be converted
    /// to Data, a `RowDecodingError` is thrown.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    func decodeDataNoCopy(atIndex index: Int) throws -> Data {
        _checkIndex(index)
        return try impl.fastDecodeDataNoCopy(atUncheckedIndex: index)
    }
    
    /// Returns the optional Data at given column.
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing or if the SQLite value is NULL, the result is
    /// nil. If the SQLite value can not be converted to Data, a
    /// `RowDecodingError` is thrown.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    func decodeDataNoCopyIfPresent(forKey columnName: String) throws -> Data? {
        guard let index = index(forColumn: columnName) else {
            return nil
        }
        return try impl.fastDecodeDataNoCopyIfPresent(atUncheckedIndex: index)
    }
    
    /// Returns the Data at given column.
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// If the column is missing, or if the SQLite value is NULL, or if the
    /// SQLite value can not be converted to Data, a
    /// `RowDecodingError` is thrown.
    ///
    /// The returned data does not owns its bytes: it must not be used longer
    /// than the row's lifetime.
    func decodeDataNoCopy(forKey columnName: String) throws -> Data {
        guard let index = index(forColumn: columnName) else {
            throw RowDecodingError.columnNotFound(columnName, context: RowDecodingContext(row: self))
        }
        return try impl.fastDecodeDataNoCopy(atUncheckedIndex: index)
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
    ///     try print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let author: Author? = row["author"]
    ///     print(author.name)
    ///     // Prints "Herman Melville"
    ///
    /// Associated records stored in nested associations are available, too:
    ///
    ///     let request = Book.including(optional: Book.author.including(optional: Author.country))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     try print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let country: Country? = row["country"]
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
        forKey scope: String)
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
    ///     try print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let author: Author = row["author"]
    ///     print(author.name)
    ///     // Prints "Herman Melville"
    ///
    /// Associated records stored in nested associations are available, too:
    ///
    ///     let request = Book.including(required: Book.author.including(required: Author.country))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     try print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let country: Country = row["country"]
    ///     print(country.name)
    ///     // Prints "United States"
    ///
    /// A fatal error is raised if the scope is not available, or contains only
    /// null values.
    ///
    /// See <https://github.com/groue/GRDB.swift/blob/master/README.md#joined-queries-support>
    /// for more information.
    func decode<Record: FetchableRecord>(
        _ type: Record.Type = Record.self,
        forKey scope: String)
    throws -> Record
    {
        guard let scopedRow = scopesTree[scope] else {
            let availableScopes = scopesTree.names
            if availableScopes.isEmpty {
                throw RowDecodingError.keyNotFound(
                    .scope(scope),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                            scope not found: \(String(reflecting: scope))
                            """))
            } else {
                throw RowDecodingError.keyNotFound(
                    .scope(scope),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                            scope not found: \(String(reflecting: scope)) - \
                            available scopes: \(availableScopes.sorted())
                            """))
            }
        }
        guard scopedRow.containsNonNullValue else {
            throw RowDecodingError.valueMismatch(
                Record.self,
                RowDecodingError.Context(
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
    ///     try print(Author(row: row).name)
    ///     // Prints "Herman Melville"
    ///
    ///     let books: [Book] = row["books"]
    ///     print(books[0].title)
    ///     // Prints "Moby-Dick"
    func decode<Collection>(
        _ type: Collection.Type = Collection.self,
        forKey key: String)
    throws -> Collection
    where
        Collection: RangeReplaceableCollection,
        Collection.Element: FetchableRecord
    {
        guard let rows = prefetchedRows[key] else {
            let availableKeys = prefetchedRows.keys
            if availableKeys.isEmpty {
                throw RowDecodingError.keyNotFound(
                    .prefetchKey(key),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                        key for prefetched rows not found: \(String(reflecting: key))
                        """))
            } else {
                throw RowDecodingError.keyNotFound(
                    .prefetchKey(key),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                        key for prefetched rows not found: \(String(reflecting: key)) \
                        - available keys: \(availableKeys.sorted())
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
    ///     try print(Author(row: row).name)
    ///     // Prints "Herman Melville"
    ///
    ///     let books: Set<Book> = row["books"]
    ///     print(books.first!.title)
    ///     // Prints "Moby-Dick"
    func decode<Record: FetchableRecord & Hashable>(
        _ type: Set<Record>.Type = Set<Record>.self,
        forKey key: String)
    throws -> Set<Record>
    {
        guard let rows = prefetchedRows[key] else {
            let availableKeys = prefetchedRows.keys
            if availableKeys.isEmpty {
                throw RowDecodingError.keyNotFound(
                    .prefetchKey(key),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                        key for prefetched rows not found: \(String(reflecting: key))
                        """))
            } else {
                throw RowDecodingError.keyNotFound(
                    .prefetchKey(key),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                        key for prefetched rows not found: \(String(reflecting: key)) \
                        - available keys: \(availableKeys.sorted())
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

/// A cursor of raw database rows.
///
/// A `RowCursor` iterates all rows from a database request.
///
/// For example:
///
/// ```swift
/// try dbQueue.read { db in
///     let rows = try Row.fetchCursor(db, sql: """
///         SELECT * FROM player
///         """)
///     while let row = try rows.next() {
///         let id: Int64 = row[0]
///         let name: String = row[1]
///     }
/// }
/// ```
public final class RowCursor: DatabaseCursor {
    public typealias Element = Row
    public let _statement: Statement
    public var _isDone = false
    @usableFromInline let _row: Row // Reused for performance
    
    init(statement: Statement, arguments: StatementArguments? = nil, adapter: (any RowAdapter)? = nil) throws {
        self._statement = statement
        self._row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        
        // Assume cursor is created for immediate iteration: reset and set arguments
        try statement.reset(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? _statement.reset()
    }
    
    @inlinable
    public func _element(sqliteStatement: SQLiteStatement) -> Row { _row }
}

extension Row {
    
    // MARK: - Fetching From Prepared Statement
    
    /// Returns a cursor over rows fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT ...")
    ///     let rows = try Row.fetchCursor(statement) // RowCursor
    ///     while let row = try rows.next() {
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
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
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
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> [Row]
    {
        // The cursor reuses a single mutable row. Return immutable copies.
        try Array(fetchCursor(statement, arguments: arguments, adapter: adapter).map { $0.copy() })
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
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> Set<Row>
    {
        // The cursor reuses a single mutable row. Return immutable copies.
        try Set(fetchCursor(statement, arguments: arguments, adapter: adapter).map { $0.copy() })
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
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
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
    ///     while let row = try rows.next() {
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
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> RowCursor
    {
        try fetchCursor(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of rows fetched from an SQL query.
    ///
    ///     let rows = try Row.fetchAll(db, sql: "SELECT id, name FROM player") // [Row]
    ///     for row in rows {
    ///         let id: Int64 = row[0]
    ///         let name: String = row[1]
    ///     }
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> [Row]
    {
        try fetchAll(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a set of rows fetched from an SQL query.
    ///
    ///     let rows = try Row.fetchSet(db, sql: "SELECT id, name FROM player") // Set<Row>
    ///     for row in rows {
    ///         let id: Int64 = row[0]
    ///         let name: String = row[1]
    ///     }
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> Set<Row>
    {
        try fetchSet(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single row fetched from an SQL query.
    ///
    ///     let row = try Row.fetchOne(db, sql: "SELECT id, name FROM player") // Row?
    ///     if let row = row {
    ///         let id: Int64 = row[0]
    ///         let name: String = row[1]
    ///     }
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
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
    ///     while let row = try rows.next() {
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
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: some FetchRequest) throws -> RowCursor {
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
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: some FetchRequest) throws -> [Row] {
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
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(_ db: Database, _ request: some FetchRequest) throws -> Set<Row> {
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
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ request: some FetchRequest) throws -> Row? {
        let request = try request.makePreparedRequest(db, forSingleResult: true)
        guard let row = try fetchOne(request.statement, adapter: request.adapter) else {
            return nil
        }
        try request.supplementaryFetch?(db, [row])
        return row
    }
}

extension FetchRequest<Row> {
    
    // MARK: Fetching Rows
    
    /// Returns a cursor over fetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///     let rows = try request.fetchCursor(db)
    ///     while let row = try rows.next() {
    ///         let id: Int64 = row[0]
    ///         let name: String = row[1]
    ///     }
    /// }
    /// ```
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` since you would not get the
    /// distinct rows you expect.
    /// Use ``FetchRequest/fetchAll(_:)-7p809`` instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameter db: A database connection.
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RowCursor {
        try Row.fetchCursor(db, self)
    }
    
    /// Returns an array of fetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///     let rows = try request.fetchAll(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [Row] {
        try Row.fetchAll(db, self)
    }
    
    /// Returns a set of fetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///     let rows = try request.fetchSet(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: A set of fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<Row> {
        try Row.fetchSet(db, self)
    }
    
    /// Returns a single row.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName) LIMIT 1
    ///         """
    ///     let rows = try request.fetchOne(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional row.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> Row? {
        try Row.fetchOne(db, self)
    }
}

extension Row: RandomAccessCollection {
    
    /// The index of the first (ColumnName, DatabaseValue) pair.
    public var startIndex: RowIndex { RowIndex(0) }
    
    /// The "past-the-end" index, successor of the index of the last
    /// (ColumnName, DatabaseValue) pair.
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

extension Row: Equatable {
    /// Returns true if and only if both rows have the same columns and values,
    /// in the same order. Columns are compared in a case-sensitive way.
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

extension Row: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for (column, dbValue) in self {
            hasher.combine(column)
            hasher.combine(dbValue)
        }
    }
}

extension Row: CustomStringConvertible {
    public var description: String {
        "["
        + map { (column, dbValue) in "\(column):\(dbValue)" }.joined(separator: " ")
        + "]"
    }
}

extension Row: CustomDebugStringConvertible {
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
            // rows is nil if key is a pivot in a "through" association
            if let rows = prefetchedRows[key] {
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
        }
        
        return str
    }
}

extension Row: ExpressibleByDictionaryLiteral {
    /// Creates a row initialized with elements. Column order is preserved, and
    /// duplicated columns names are allowed.
    ///
    ///     let row: Row = ["foo": 1, "foo": "bar", "baz": nil]
    ///     print(row)
    ///     // Prints [foo:1 foo:"bar" baz:NULL]
    public convenience init(dictionaryLiteral elements: (String, (any DatabaseValueConvertible)?)...) {
        self.init(impl: ArrayRowImpl(columns: elements.map { ($0, $1?.databaseValue ?? .null) }))
    }
}

// MARK: - RowIndex

/// Indexes to (ColumnName, DatabaseValue) pairs in a database row.
public struct RowIndex {
    let index: Int
    init(_ index: Int) { self.index = index }
}

extension RowIndex: Equatable {
    public static func == (lhs: RowIndex, rhs: RowIndex) -> Bool {
        lhs.index == rhs.index
    }
}

extension RowIndex: Comparable {
    public static func < (lhs: RowIndex, rhs: RowIndex) -> Bool {
        lhs.index < rhs.index
    }
}

extension RowIndex: Strideable {
    public func distance(to other: RowIndex) -> Int {
        other.index - index
    }
    
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
        public typealias Index = Dictionary<String, any _LayoutedRowAdapter>.Index
        private let row: Row
        private let scopes: [String: any _LayoutedRowAdapter]
        private let prefetchedRows: Row.PrefetchedRowsView
        
        /// The scopes defined on this row.
        public var names: Dictionary<String, any _LayoutedRowAdapter>.Keys {
            scopes.keys
        }
        
        init() {
            self.init(row: Row(), scopes: [:], prefetchedRows: Row.PrefetchedRowsView())
        }
        
        init(row: Row, scopes: [String: any _LayoutedRowAdapter], prefetchedRows: Row.PrefetchedRowsView) {
            self.row = row
            self.scopes = scopes
            self.prefetchedRows = prefetchedRows
        }
        
        public var startIndex: Index {
            scopes.startIndex
        }
        
        public var endIndex: Index {
            scopes.endIndex
        }
        
        public func index(after i: Index) -> Index {
            scopes.index(after: i)
        }
        
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
                if prefetchKey == key,
                   let rows = prefetch.rows // nil for "through" associations
                {
                    return rows
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

extension OrderedDictionary<String, Row.Prefetch> {
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
    
    func fastDecodeDataNoCopy(atUncheckedIndex index: Int) throws -> Data {
        // unless customized, copy data (see StatementRowImpl and AdaptedRowImpl for customization)
        try Data.decode(
            fromDatabaseValue: databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: Row(impl: self), key: .columnIndex(index)))
    }
    
    func fastDecodeDataNoCopyIfPresent(atUncheckedIndex index: Int) throws -> Data? {
        // unless customized, copy data (see StatementRowImpl and AdaptedRowImpl for customization)
        try Optional<Data>.decode(
            fromDatabaseValue: databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: Row(impl: self), key: .columnIndex(index)))
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
    
    func fastDecodeDataNoCopy(atUncheckedIndex index: Int) throws -> Data {
        guard sqlite3_column_type(sqliteStatement, CInt(index)) != SQLITE_NULL else {
            throw RowDecodingError.valueMismatch(Data.self, statement: statement, index: index)
        }
        guard let bytes = sqlite3_column_blob(sqliteStatement, CInt(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(sqliteStatement, CInt(index)))
        return Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes), count: count, deallocator: .none)
    }
    
    func fastDecodeDataNoCopyIfPresent(atUncheckedIndex index: Int) throws -> Data? {
        guard sqlite3_column_type(sqliteStatement, CInt(index)) != SQLITE_NULL else {
            return nil
        }
        guard let bytes = sqlite3_column_blob(sqliteStatement, CInt(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(sqliteStatement, CInt(index)))
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
