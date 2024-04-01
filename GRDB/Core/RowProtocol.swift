import Foundation

/// Support for ``DatabaseDateDecodingStrategy`` and similar types.
public protocol _RowDecodingStrategy {
    associatedtype _RowDecodingOutput
    
    /// - precondition: value is not NULL
    func _decode(
        sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: CInt,
        context: @autoclosure () -> _RowDecodingContext
    ) throws -> _RowDecodingOutput
    
    func _decode(
        databaseValue: DatabaseValue,
        context: @autoclosure () -> _RowDecodingContext
    ) throws -> _RowDecodingOutput
}

public protocol _Row {
    func _decode<Strategy: _RowDecodingStrategy>(
        with strategy: Strategy,
        atUncheckedIndex index: Int
    ) throws -> Strategy._RowDecodingOutput
    
    func _decode<Value: DatabaseValueConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int
    ) throws -> Value
    
    func _fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int
    ) throws -> Value
    
    /// Returns true if and only if the row was fetched from a database.
    var _isFetched: Bool { get }

    func _scopes(prefetchedRows: Row.PrefetchedRowsView) -> Row.ScopesView
    func _columnName(atUncheckedIndex index: Int) -> String
    func _hasNull(atUncheckedIndex index: Int) -> Bool
    func _databaseValue(atUncheckedIndex index: Int) -> DatabaseValue
    
    /// Calls the given closure with the `Data` at given index.
    ///
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    ///
    /// If the SQLite value is `NULL`, the data is nil. If the SQLite value can
    /// not be converted to `Data`, an error is thrown.
    ///
    /// - warning: The `Data` argument to the body must not be stored or used
    ///   outside of the lifetime of the call to the closure.
    func _withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T
    
    var _unscopedRow: Row { get }
    var _unadaptedRow: Row { get }
    #warning("TODO: remove")
    var _copiedRow: Row { get }
    
    func _makeRowDecodingContext(forKey key: _RowKey?) -> _RowDecodingContext
}

public protocol RowProtocol: _Row, RandomAccessCollection where Index == RowIndex, Element == (String, DatabaseValue) {
    /// Returns the index of the leftmost column that matches *name* (case-insensitive)
    func index(forColumn name: String) -> Int?
    
    #warning("TODO: only on copied database rows")
    var prefetchedRows: Row.PrefetchedRowsView { get }
    
    #warning("TODO: check relevance")
    func copy() -> Row
}

// MARK: - Extracting Values

extension RowProtocol {
    
    /// Fatal errors if index is out of bounds
    @inline(__always)
    @usableFromInline
    func _checkIndex(_ index: Int, file: StaticString = #file, line: UInt = #line) {
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
        for i in (0..<count) where !_hasNull(atUncheckedIndex: i) {
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
        return _hasNull(atUncheckedIndex: index)
    }
    
    /// Returns `Int64`, `Double`, `String`, `Data` or nil, depending on the
    /// value stored at the given index.
    ///
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    public subscript(_ index: Int) -> (any DatabaseValueConvertible)? {
        _checkIndex(index)
        return _databaseValue(atUncheckedIndex: index).storage.value
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
        try! fastDecode(Value.self, atIndex: index)
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
        return _databaseValue(atUncheckedIndex: index).storage.value
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
        try! fastDecode(Value.self, forKey: columnName)
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
        try! fastDecode(Value.self, forKey: column.name)
    }
    
    /// Calls the given closure with the `Data` at given index.
    ///
    /// Indexes span from `0` for the leftmost column to `row.count - 1` for the
    /// rightmost column.
    ///
    /// If the SQLite value is `NULL`, the data is nil. If the SQLite value can
    /// not be converted to `Data`, an error is thrown.
    ///
    /// - warning: The `Data` argument to the body must not be stored or used
    ///   outside of the lifetime of the call to the closure.
    public func withUnsafeData<T>(atIndex index: Int, _ body: (Data?) throws -> T) throws -> T {
        _checkIndex(index)
        return try _withUnsafeData(atUncheckedIndex: index, body)
    }
    
    /// Calls the given closure with the `Data` at the given column.
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// If the row does not contain any column with that name, or if the SQLite
    /// value is `NULL`, the data is nil. If the SQLite value can not be
    /// converted to `Data`, an error is thrown.
    ///
    /// - warning: The `Data` argument to the body must not be stored or used
    ///   outside of the lifetime of the call to the closure.
    public func withUnsafeData<T>(named columnName: String, _ body: (Data?) throws -> T) throws -> T {
        guard let index = index(forColumn: columnName) else {
            return try body(nil)
        }
        return try _withUnsafeData(atUncheckedIndex: index, body)
    }
    
    /// Calls the given closure with the `Data` at the given column.
    ///
    /// Column name lookup is case-insensitive. When several columns exist with
    /// the same name, the leftmost column is considered.
    ///
    /// If the row does not contain any column with that name, or if the SQLite
    /// value is `NULL`, the data is nil. If the SQLite value can not be
    /// converted to `Data`, an error is thrown.
    ///
    /// - warning: The `Data` argument to the body must not be stored or used
    ///   outside of the lifetime of the call to the closure.
    public func withUnsafeData<T>(at column: some ColumnExpression, _ body: (Data?) throws -> T) throws -> T {
        try withUnsafeData(named: column.name, body)
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
    @available(*, deprecated, message: "Use withUnsafeData(atIndex:_:) instead.")
    public func dataNoCopy(atIndex index: Int) -> Data? {
        try! withUnsafeData(atIndex: index, { $0 })
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
    @available(*, deprecated, message: "Use withUnsafeData(named:_:) instead.")
    public func dataNoCopy(named columnName: String) -> Data? {
        guard let index = index(forColumn: columnName) else {
            return nil
        }
        return try! _withUnsafeData(atUncheckedIndex: index, { $0 })
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
    @available(*, deprecated, message: "Use withUnsafeData(at:_:) instead.")
    public func dataNoCopy(_ column: some ColumnExpression) -> Data? {
        dataNoCopy(named: column.name)
    }
}

// MARK: - Extracting DatabaseValue

extension RowProtocol {
    /// The database values in the row, from left to right.
    ///
    /// Values appear in the same order as they occur as the `.1` member
    /// of column-value pairs in `self`.
    public var databaseValues: LazyMapCollection<Self, DatabaseValue> {
        lazy.map { $0.1 }
    }
}

// MARK: - Extracting Records

extension RowProtocol {
    /// The record associated to the given scope.
    ///
    /// Row scopes can be defined manually, with ``ScopeAdapter``.
    /// The ``JoinableRequest/including(required:)`` and
    /// ``JoinableRequest/including(optional:)`` request methods define scopes
    /// named after the key of included associations between record types.
    ///
    /// A breadth-first search is performed in all available scopes in the row,
    /// recursively.
    ///
    /// A fatal error is raised if the scope is not available, or contains only
    /// `NULL` values.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord, FetchableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord, FetchableRecord {
    ///     static let country = belongsTo(Country.self)
    /// }
    ///
    /// struct Country: TableRecord, FetchableRecord { }
    ///
    /// // Fetch a book, with its author, and the country of its author.
    /// let request = Book
    ///     .including(required: Book.author
    ///         .including(required: Author.country))
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// let book = try Book(row: bookRow)
    /// let author: Author = bookRow["author"]
    /// let country: Country = bookRow["country"]
    /// ```
    ///
    /// See also: ``scopesTree``
    ///
    /// - parameter scope: A scope identifier.
    public subscript<Record: FetchableRecord>(_ scope: String) -> Record {
        try! decode(Record.self, forKey: scope)
    }
    
    /// The eventual record associated to the given scope.
    ///
    /// Row scopes can be defined manually, with ``ScopeAdapter``.
    /// The ``JoinableRequest/including(required:)`` and
    /// ``JoinableRequest/including(optional:)`` request methods define scopes
    /// named after the key of included associations between record types.
    ///
    /// A breadth-first search is performed in all available scopes in the row,
    /// recursively.
    ///
    /// The result is nil if the scope is not available, or contains only
    /// `NULL` values.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord, FetchableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord, FetchableRecord {
    ///     static let country = belongsTo(Country.self)
    /// }
    ///
    /// struct Country: TableRecord, FetchableRecord { }
    ///
    /// // Fetch a book, with its author, and the country of its author.
    /// let request = Book
    ///     .including(optional: Book.author
    ///         .including(optional: Author.country))
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// let book = try Book(row: bookRow)
    /// let author: Author? = bookRow["author"]
    /// let country: Country? = bookRow["country"]
    /// ```
    ///
    /// See also: ``scopesTree``
    ///
    /// - parameter scope: A scope identifier.
    public subscript<Record: FetchableRecord>(_ scope: String) -> Record? {
        try! decodeIfPresent(Record.self, forKey: scope)
    }
    
    /// A collection of prefetched records associated to the given
    /// association key.
    ///
    /// Prefetched rows are defined by the ``JoinableRequest/including(all:)``
    /// request method.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord {
    ///     static let books = hasMany(Book.self)
    /// }
    ///
    /// struct Book: TableRecord, FetchableRecord { }
    ///
    /// let request = Author.including(all: Author.books)
    /// let authorRow = try Row.fetchOne(db, request)!
    ///
    /// let author = try Author(row: authorRow)
    /// let books: [Book] = author["books"]
    /// ```
    ///
    /// See also: ``prefetchedRows``
    ///
    /// - parameter key: An association key.
    public subscript<Records>(_ key: String)
    -> Records
    where
        Records: RangeReplaceableCollection,
        Records.Element: FetchableRecord
    {
        try! decode(Records.self, forKey: key)
    }
    
    /// A set prefetched records associated to the given association key.
    ///
    /// Prefetched rows are defined by the ``JoinableRequest/including(all:)``
    /// request method.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord {
    ///     static let books = hasMany(Book.self)
    /// }
    ///
    /// struct Book: TableRecord, FetchableRecord, Hashable { }
    ///
    /// let request = Author.including(all: Author.books)
    /// let authorRow = try Row.fetchOne(db, request)!
    ///
    /// let author = try Author(row: authorRow)
    /// let books: Set<Book> = author["books"]
    /// ```
    ///
    /// See also: ``prefetchedRows``
    ///
    /// - parameter key: An association key.
    public subscript<Record: FetchableRecord & Hashable>(_ key: String) -> Set<Record> {
        try! decode(Set<Record>.self, forKey: key)
    }
}

extension RowProtocol {
    @inlinable
    func _decodeIfPresent<Strategy: _RowDecodingStrategy>(
        with strategy: Strategy,
        atUncheckedIndex index: Int)
    throws -> Strategy._RowDecodingOutput?
    {
        if _hasNull(atUncheckedIndex: index) {
            return nil
        }
        return try _decode(with: strategy, atUncheckedIndex: index)
    }
    
    @inlinable
    func _decodeIfPresent<Value: DatabaseValueConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value?
    {
        try _decode(Optional<Value>.self, atUncheckedIndex: index)
    }
    
    @inlinable
    func _fastDecodeIfPresent<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value?
    {
        try _fastDecode(Optional<Value>.self, atUncheckedIndex: index)
    }
    
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
    /// See ``splittingRowAdapters(columnCounts:)`` for a sample code.
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
    /// See ``splittingRowAdapters(columnCounts:)`` for a sample code.
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
                        decodingContext: _makeRowDecodingContext(forKey: nil),
                        debugDescription: """
                            scope not found: \(String(reflecting: scope))
                            """))
            } else {
                throw RowDecodingError.keyNotFound(
                    .scope(scope),
                    RowDecodingError.Context(
                        decodingContext: _makeRowDecodingContext(forKey: nil),
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
                    decodingContext: _makeRowDecodingContext(forKey: .scope(scope)),
                    debugDescription: """
                        scope \(String(reflecting: scope)) only contains null values
                        """))
        }
        return try Record(row: scopedRow)
    }
}

extension RowProtocol {
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
                        decodingContext: _makeRowDecodingContext(forKey: nil),
                        debugDescription: """
                        key for prefetched rows not found: \(String(reflecting: key))
                        """))
            } else {
                throw RowDecodingError.keyNotFound(
                    .prefetchKey(key),
                    RowDecodingError.Context(
                        decodingContext: _makeRowDecodingContext(forKey: nil),
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
                        decodingContext: _makeRowDecodingContext(forKey: nil),
                        debugDescription: """
                        key for prefetched rows not found: \(String(reflecting: key))
                        """))
            } else {
                throw RowDecodingError.keyNotFound(
                    .prefetchKey(key),
                    RowDecodingError.Context(
                        decodingContext: _makeRowDecodingContext(forKey: nil),
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

// MARK: - Scopes

extension RowProtocol {
    /// A view on the scopes defined by row adapters.
    ///
    /// The returned object provides an access to all available scopes in
    /// the row.
    ///
    /// Row scopes can be defined manually, with ``ScopeAdapter``.
    /// The ``JoinableRequest/including(required:)`` and
    /// ``JoinableRequest/including(optional:)`` request methods define scopes
    /// named after the key of included associations between record types.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord {
    ///     static let country = belongsTo(Country.self)
    /// }
    ///
    /// struct Country: TableRecord { }
    ///
    /// // Fetch a book, with its author, and the country of its author.
    /// let request = Book
    ///     .including(required: Book.author
    ///         .including(required: Author.country))
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// print(bookRow)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1]
    ///
    /// let authorRow = bookRow.scopes["author"]!
    /// print(authorRow)
    /// // Prints [id:1, name:"Herman Melville", countryCode: "US"]
    ///
    /// let countryRow = authorRow.scopes["country"]!
    /// print(countryRow)
    /// // Prints [code:"US" name:"United States of America"]
    /// ```
    ///
    /// See also ``scopesTree``.
    public var scopes: Row.ScopesView {
        _scopes(prefetchedRows: prefetchedRows)
    }
    
    /// A view on the scopes tree defined by row adapters.
    ///
    /// The returned object provides an access to all available scopes in
    /// the row, recursively. For any given scope identifier, a breadth-first
    /// search is performed.
    ///
    /// Row scopes can be defined manually, with ``ScopeAdapter``.
    /// The ``JoinableRequest/including(required:)`` and
    /// ``JoinableRequest/including(optional:)`` request methods define scopes
    /// named after the key of included associations between record types.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord {
    ///     static let country = belongsTo(Country.self)
    /// }
    ///
    /// struct Country: TableRecord { }
    ///
    /// // Fetch a book, with its author, and the country of its author.
    /// let request = Book
    ///     .including(required: Book.author
    ///         .including(required: Author.country))
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// print(bookRow)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1]
    ///
    /// print(bookRow.scopesTree["author"])
    /// // Prints [id:1, name:"Herman Melville", countryCode: "US"]
    ///
    /// print(bookRow.scopesTree["country"])
    /// // Prints [code:"US" name:"United States of America"]
    /// ```
    ///
    /// See also ``scopes``.
    public var scopesTree: Row.ScopesTreeView {
        Row.ScopesTreeView(scopes: scopes)
    }
    
    /// The row, without any scope of prefetched rows.
    ///
    /// This property is useful when testing the content of rows fetched from
    /// joined requests.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    ///     static let awards = hasMany(Award.self)
    /// }
    ///
    /// struct Author: TableRecord { }
    /// struct Award: TableRecord { }
    ///
    /// // Fetch a book, with its author, and its awards.
    /// let request = Book
    ///     .including(required: Book.author)
    ///     .including(all: Book.awards)
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// // Failure
    /// XCTAssertEqual(bookRow, ["id":42, "title":"Moby-Dick", "authorId":1])
    ///
    /// // Success
    /// XCTAssertEqual(bookRow.unscoped, ["id":42, "title":"Moby-Dick", "authorId":1])
    /// ```
    public var unscoped: Row {
        var row = _unscopedRow
        
        // Remove prefetchedRows
        if row.prefetchedRows.isEmpty == false {
            // Make sure we build another Row instance
            row = Row(impl: row.copy().impl)
            assert(row.prefetchedRows.isEmpty)
        }
        return row
    }
    
    /// The raw row fetched from the database.
    ///
    /// This property is useful when debugging the content of rows fetched from
    /// joined requests.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord { }
    ///
    /// // SELECT book.*, author.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// let request = Book.including(required: Book.author)
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// print(bookRow)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1]
    ///
    /// print(bookRow.unadapted)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1, id:1, name:"Herman Melville"]
    /// ```
    public var unadapted: Row {
        _unadaptedRow
    }
}

// MARK: - Columns

extension RowProtocol {
    
    // MARK: - Columns
    
    /// The names of columns in the row, from left to right.
    ///
    /// Columns appear in the same order as they occur as the `.0` member
    /// of column-value pairs in `self`.
    public var columnNames: LazyMapCollection<Self, String> {
        lazy.map { $0.0 }
    }
    
    /// Returns whether the row has one column with the given name
    /// (case-insensitive).
    public func hasColumn(_ columnName: String) -> Bool {
        index(forColumn: columnName) != nil
    }
}

// MARK: - Throwing DatabaseValueConvertible Decoding Methods

extension RowProtocol {
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
        return try _decode(Value.self, atUncheckedIndex: index)
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
                throw RowDecodingError.columnNotFound(columnName, context: _makeRowDecodingContext(forKey: nil))
            }
        }
        return try _decode(Value.self, atUncheckedIndex: index)
    }
}

// MARK: - Throwing DatabaseValueConvertible & StatementColumnConvertible Decoding Methods

extension RowProtocol {
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
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type = Value.self,
        atIndex index: Int)
    throws -> Value
    {
        _checkIndex(index)
        return try _fastDecode(Value.self, atUncheckedIndex: index)
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
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type = Value.self,
        forKey columnName: String)
    throws -> Value
    {
        guard let index = index(forColumn: columnName) else {
            if let value = Value.fromMissingColumn() {
                return value
            } else {
                throw RowDecodingError.columnNotFound(columnName, context: _makeRowDecodingContext(forKey: nil))
            }
        }
        return try _fastDecode(Value.self, atUncheckedIndex: index)
    }
}

extension RowProtocol where Self: CustomStringConvertible {
    public var description: String {
        "["
        + map { (column, dbValue) in "\(column):\(dbValue)" }.joined(separator: " ")
        + "]"
    }
}

// MARK: - RandomAccessCollection

extension RowProtocol {
    public var startIndex: RowIndex { RowIndex(0) }
    
    public var endIndex: RowIndex { RowIndex(count) }
    
    /// Returns the (column, value) pair at given index.
    public subscript(position: RowIndex) -> (String, DatabaseValue) {
        let index = position.index
        _checkIndex(index)
        return (
            _columnName(atUncheckedIndex: index),
            _databaseValue(atUncheckedIndex: index))
    }
}

/// An index to a (column, value) pair in a ``Row``.
public struct RowIndex: Sendable {
    @usableFromInline
    var index: Int
    
    @usableFromInline
    init(_ index: Int) { self.index = index }
}

extension RowIndex: Hashable { }

extension RowIndex: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.index < rhs.index
    }
}

extension RowIndex: Strideable {
    public func distance(to other: Self) -> Int {
        other.index - index
    }
    
    public func advanced(by n: Int) -> Self {
        RowIndex(index + n)
    }
}
