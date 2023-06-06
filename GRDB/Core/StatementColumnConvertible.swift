/// A type that can decode itself from the low-level C interface to
/// SQLite results.
///
/// `StatementColumnConvertible` is adopted by `Bool`, `Int`, `String`,
/// `Date`, and most common values.
///
/// When a type conforms to both ``DatabaseValueConvertible`` and
/// `StatementColumnConvertible`, GRDB can apply some optimization whenever
/// direct access to SQLite is possible. For example:
///
/// ```swift
/// // Optimized
/// let scores = Int.fetchAll(db, sql: "SELECT score FROM player")
///
/// let rows = try Row.fetchCursor(db, sql: "SELECT * FROM player")
/// while let row = try rows.next() {
///     // Optimized
///     let int: Int = row[0]
///     let name: String = row[1]
/// }
///
/// struct Player: FetchableRecord {
///     var name: String
///     var score: Int
///
///     init(row: Row) {
///         // Optimized
///         name = row["name"]
///         score = row["score"]
///     }
/// }
/// ```
///
/// To conform to `StatementColumnConvertible`, provide a custom implementation
/// of ``init(sqliteStatement:index:)-354je``. This implementation is ready-made
/// for `RawRepresentable` types whose `RawValue`
/// is `StatementColumnConvertible`.
///
/// Related SQLite documentation: <https://www.sqlite.org/c3ref/column_blob.html>
///
/// ## Topics
///
/// ### Creating a Value
///
/// - ``init(sqliteStatement:index:)-354je``
/// - ``fromStatement(_:atUncheckedIndex:)-2i8y6``
///
/// ### Fetching Values from Raw SQL
///
/// - ``DatabaseValueConvertible/fetchCursor(_:sql:arguments:adapter:)-4xfxh``
/// - ``DatabaseValueConvertible/fetchAll(_:sql:arguments:adapter:)-7bn2i``
/// - ``DatabaseValueConvertible/fetchSet(_:sql:arguments:adapter:)-1ythd``
/// - ``DatabaseValueConvertible/fetchOne(_:sql:arguments:adapter:)-563lc``
///
/// ### Fetching Values from a Prepared Statement
///
/// - ``DatabaseValueConvertible/fetchCursor(_:arguments:adapter:)-81f9d``
/// - ``DatabaseValueConvertible/fetchAll(_:arguments:adapter:)-64gua``
/// - ``DatabaseValueConvertible/fetchSet(_:arguments:adapter:)-9fh2b``
/// - ``DatabaseValueConvertible/fetchOne(_:arguments:adapter:)-8cbzp``
///
/// ### Fetching Values from a Request
///
/// - ``DatabaseValueConvertible/fetchCursor(_:_:)-77a34``
/// - ``DatabaseValueConvertible/fetchAll(_:_:)-7tnun``
/// - ``DatabaseValueConvertible/fetchSet(_:_:)-4bc1m``
/// - ``DatabaseValueConvertible/fetchOne(_:_:)-94q4e``
///
/// ### Supporting Types
///
/// - ``FastDatabaseValueCursor``
public protocol StatementColumnConvertible {
    /// Creates an instance from a raw SQLite statement pointer, if possible.
    ///
    /// This method can be called with a NULL database value.
    ///
    /// - warning: Do not customize the default implementation.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    /// - returns: A decoded value, or, if decoding is impossible, nil.
    static func fromStatement(
        _ sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: CInt)
    -> Self?
    
    /// Creates an instance from a raw SQLite statement pointer, if possible.
    ///
    /// Do not check for `NULL` in your implementation of this method. Null
    /// database values are handled
    /// in ``StatementColumnConvertible/fromStatement(_:atUncheckedIndex:)-2i8y6``.
    ///
    /// For example, here is the how Int64 adopts StatementColumnConvertible:
    ///
    /// ```swift
    /// extension Int64: StatementColumnConvertible {
    ///     public init(sqliteStatement: SQLiteStatement, index: CInt) {
    ///         self = sqlite3_column_int64(sqliteStatement, index)
    ///     }
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/column_blob.html>
    ///
    /// - precondition: This initializer is not called with a NULL
    ///   database value.
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    /// - returns: A decoded value, or, if decoding is impossible, nil.
    init?(sqliteStatement: SQLiteStatement, index: CInt)
}

extension StatementColumnConvertible {
    // `Optional` overrides this default behavior.
    /// Default implementation fails on decoding NULL.
    @inline(__always)
    @inlinable
    public static func fromStatement(_ sqliteStatement: SQLiteStatement, atUncheckedIndex index: CInt) -> Self? {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            return nil
        }
        return self.init(sqliteStatement: sqliteStatement, index: index)
    }
}

// MARK: - Conversions

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    @usableFromInline
    /* private */ static func _valueMismatch(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: CInt,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Never
    {
        throw RowDecodingError.valueMismatch(
            Self.self,
            sqliteStatement: sqliteStatement,
            index: index,
            context: context())
    }
    
    @inline(__always)
    @inlinable
    static func fastDecode(
        fromRow row: Row,
        atUncheckedIndex index: Int)
    throws -> Self
    {
        if let sqliteStatement = row.sqliteStatement {
            return try fastDecode(
                fromStatement: sqliteStatement,
                atUncheckedIndex: CInt(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
        // Support for fast decoding from adapted rows
        return try row.fastDecode(Self.self, atUncheckedIndex: index)
    }
    
    @inline(__always)
    @inlinable
    static func fastDecode(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: CInt,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self
    {
        if let value = fromStatement(sqliteStatement, atUncheckedIndex: index) {
            return value
        } else {
            try _valueMismatch(fromStatement: sqliteStatement, atUncheckedIndex: index, context: context())
        }
    }
    
    // Support for Decodable
    @inline(__always)
    @inlinable
    static func fastDecodeIfPresent(
        fromRow row: Row,
        atUncheckedIndex index: Int)
    throws -> Self?
    {
        try Optional<Self>.fastDecode(fromRow: row, atUncheckedIndex: index)
    }
}

// MARK: - Cursors

/// A cursor of database values.
///
/// A `FastDatabaseValueCursor` iterates all rows from a database request. Its
/// elements are the database values decoded from the leftmost column.
///
/// For example:
///
/// ```swift
/// try dbQueue.read { db in
///     let names: FastDatabaseValueCursor<String> = try String.fetchCursor(db, sql: """
///         SELECT name FROM player
///         """)
///     while let name = names.next() { // String
///         print(name)
///     }
/// }
/// ```
public final class FastDatabaseValueCursor<Value>: DatabaseCursor
where Value: DatabaseValueConvertible & StatementColumnConvertible
{
    public typealias Element = Value
    public let _statement: Statement
    public var _isDone = false
    @usableFromInline let columnIndex: CInt
    
    init(statement: Statement, arguments: StatementArguments? = nil, adapter: (any RowAdapter)? = nil) throws {
        self._statement = statement
        if let adapter {
            // adapter may redefine the index of the leftmost column
            columnIndex = try CInt(adapter.baseColumnIndex(atIndex: 0, layout: statement))
        } else {
            columnIndex = 0
        }
        
        // Assume cursor is created for immediate iteration: reset and set arguments
        try statement.prepareExecution(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? _statement.reset()
    }
    
    @inlinable
    public func _element(sqliteStatement: SQLiteStatement) throws -> Value {
        try Value.fastDecode(
            fromStatement: sqliteStatement,
            atUncheckedIndex: columnIndex,
            context: RowDecodingContext(statement: _statement, index: Int(columnIndex)))
    }
}

/// Types that adopt both DatabaseValueConvertible and
/// StatementColumnConvertible can be efficiently initialized from
/// database values.
///
/// See DatabaseValueConvertible for more information.
extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    // MARK: Fetching From Prepared Statement
    
    /// Returns a cursor over values fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT score FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let scores = try Int.fetchCursor(statement, arguments: [lastName])
    ///     while let score = try scores.next() {
    ///         print(score)
    ///     }
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column if the `adapter` argument
    /// is nil.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A ``FastDatabaseValueCursor`` over fetched values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> FastDatabaseValueCursor<Self>
    {
        try FastDatabaseValueCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of values fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT score FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let scores = try Int.fetchAll(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column if the `adapter` argument
    /// is nil.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> [Self]
    {
        try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from a prepared statement.
    ///
    /// The value is decoded from the leftmost column if the `adapter` argument
    /// is nil.
    ///
    /// The result is nil if the request returns no row, or one row with a
    /// `NULL` value.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT score FROM player WHERE lastName = ? LIMIT 1"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let score = try Int.fetchOne(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional value.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> Self?
    {
        // fetchOne handles both a missing row, and one row with a NULL value.
        let cursor = try FastDatabaseValueCursor<Self?>(
            statement: statement,
            arguments: arguments,
            adapter: adapter)
        return try cursor.next() ?? nil
    }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible & Hashable {
    /// Returns a set of values fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT score FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let scores = try Int.fetchSet(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column if the `adapter` argument
    /// is nil.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> Set<Self>
    {
        try Set(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    // MARK: Fetching From SQL
    
    /// Returns a cursor over values fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT score FROM player WHERE lastName = ?"
    ///     let scores = try Int.fetchCursor(db, sql: sql, arguments: [lastName])
    ///     while let score = try scores.next() {
    ///         print(score)
    ///     }
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column if the `adapter` argument
    /// is nil.
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
    /// - returns: A ``FastDatabaseValueCursor`` over fetched values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> FastDatabaseValueCursor<Self>
    {
        try fetchCursor(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of values fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT score FROM player WHERE lastName = ?"
    ///     let scores = try Int.fetchAll(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column if the `adapter` argument
    /// is nil.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> [Self]
    {
        try fetchAll(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from an SQL query.
    ///
    /// The value is decoded from the leftmost column if the `adapter` argument
    /// is nil.
    ///
    /// The result is nil if the request returns no row, or one row with a
    /// `NULL` value.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT score FROM player WHERE lastName = ?"
    ///     let score = try Int.fetchOne(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional value.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> Self?
    {
        try fetchOne(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible & Hashable {
    /// Returns a set of values fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT score FROM player WHERE lastName = ?"
    ///     let scores = try Int.fetchSet(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column if the `adapter` argument
    /// is nil.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> Set<Self>
    {
        try fetchSet(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a cursor over values fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player
    ///         .select(Column("score"))
    ///         .filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Int> = """
    ///         SELECT score FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let scores = try Int.fetchCursor(db, request)
    ///     while let score = try scores.next() {
    ///         print(score)
    ///     }
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column.
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
    /// - returns: A ``FastDatabaseValueCursor`` over fetched values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: some FetchRequest)
    throws -> FastDatabaseValueCursor<Self>
    {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchCursor(request.statement, adapter: request.adapter)
    }
    
    /// Returns an array of values fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player
    ///         .select(Column("score"))
    ///         .filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Int> = """
    ///         SELECT score FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let scores = try Int.fetchAll(db, request)
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An array of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: some FetchRequest) throws -> [Self] {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchAll(request.statement, adapter: request.adapter)
    }
    
    /// Returns a single value fetched from a fetch request.
    ///
    /// The value is decoded from the leftmost column.
    ///
    /// The result is nil if the request returns no row, or one row with a
    /// `NULL` value.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player
    ///         .select(Column("score"))
    ///         .filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Int> = """
    ///         SELECT score FROM player WHERE lastName = \(lastName) LIMIT 1
    ///         """
    ///
    ///     let scores = try Int.fetchOne(db, request)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An optional value.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ request: some FetchRequest) throws -> Self? {
        let request = try request.makePreparedRequest(db, forSingleResult: true)
        return try fetchOne(request.statement, adapter: request.adapter)
    }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible & Hashable {
    /// Returns a set of values fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player
    ///         .select(Column("score"))
    ///         .filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Int> = """
    ///         SELECT score FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let scores = try Int.fetchAll(db, request)
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A set of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(_ db: Database, _ request: some FetchRequest) throws -> Set<Self> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchSet(request.statement, adapter: request.adapter)
    }
}

extension FetchRequest where RowDecoder: DatabaseValueConvertible & StatementColumnConvertible {
    
    // MARK: Fetching Values
    
    /// Returns a cursor over fetched values.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player
    ///         .filter(Column("lastName") == lastName)
    ///         .select(Column("score"), as: Int.self)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Int> = """
    ///         SELECT score FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let scores = try request.fetchCursor(db)
    ///     while let score = try scores.next() {
    ///         print(score)
    ///     }
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameter db: A database connection.
    /// - returns: A ``FastDatabaseValueCursor`` over fetched values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> FastDatabaseValueCursor<RowDecoder> {
        try RowDecoder.fetchCursor(db, self)
    }
    
    /// Returns an array of fetched values.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player
    ///         .filter(Column("lastName") == lastName)
    ///         .select(Column("score"), as: Int.self)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Int> = """
    ///         SELECT score FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let scores = try request.fetchAll(db)
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        try RowDecoder.fetchAll(db, self)
    }
    
    /// Returns a single fetched value.
    ///
    /// The value is decoded from the leftmost column.
    ///
    /// The result is nil if the request returns no row, or one row with a
    /// `NULL` value.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player
    ///         .filter(Column("lastName") == lastName)
    ///         .select(Column("score"), as: Int.self)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Int> = """
    ///         SELECT score FROM player WHERE lastName = \(lastName) LIMIT 1
    ///         """
    ///
    ///     let score = try request.fetchOne(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional value.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        try RowDecoder.fetchOne(db, self)
    }
}

extension FetchRequest where RowDecoder: DatabaseValueConvertible & StatementColumnConvertible & Hashable {
    /// Returns a set of fetched values.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player
    ///         .filter(Column("lastName") == lastName)
    ///         .select(Column("score"), as: Int.self)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Int> = """
    ///         SELECT score FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let scores = try request.fetchSet(db)
    /// }
    /// ```
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// - parameter db: A database connection.
    /// - returns: A set of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder> {
        try RowDecoder.fetchSet(db, self)
    }
}
