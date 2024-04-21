import Foundation

extension Row {
    /// The names of columns in the row, from left to right.
    ///
    /// Columns appear in the same order as they occur as the `.0` member
    /// of column-value pairs in `self`.
    public var columnNames: LazyMapCollection<Row, String> {
        lazy.map { $0.0 }
    }
    
    /// The database values in the row, from left to right.
    ///
    /// Values appear in the same order as they occur as the `.1` member
    /// of column-value pairs in `self`.
    public var databaseValues: LazyMapCollection<Row, DatabaseValue> {
        lazy.map { $0.1 }
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
        return try impl.withUnsafeData(atUncheckedIndex: index, body)
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
        return try impl.withUnsafeData(atUncheckedIndex: index, body)
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
        return try! withUnsafeData(atUncheckedIndex: index, { $0 })
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

// MARK: - Support for DatabaseValueConvertible

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

// MARK: - Support for DatabaseValueConvertible & StatementColumnConvertible

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

// MARK: - Support for Data

extension Row {
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
    func withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T {
        try impl.withUnsafeData(atUncheckedIndex: index, body)
    }
}
