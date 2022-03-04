/// Types that adopt DatabaseValueConvertible can be initialized from
/// database values.
///
/// The protocol comes with built-in methods that allow to fetch cursors,
/// arrays, or single values:
///
///     try String.fetchCursor(db, sql: "SELECT name FROM ...", arguments:...) // Cursor of String
///     try String.fetchAll(db, sql: "SELECT name FROM ...", arguments:...)    // [String]
///     try String.fetchOne(db, sql: "SELECT name FROM ...", arguments:...)    // String?
///
///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
///     try String.fetchCursor(statement, arguments:...) // Cursor of String
///     try String.fetchAll(statement, arguments:...)    // [String]
///     try String.fetchOne(statement, arguments:...)    // String?
///
/// DatabaseValueConvertible is adopted by Bool, Int, String, etc.
public protocol DatabaseValueConvertible: SQLExpressible, StatementBinding {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Creates a value from a missing column, if possible. This method makes
    /// it possible to decode missing columns as nil optionals.
    ///
    /// - returns: A decoded value, or, if decoding is impossible, nil.
    /// :nodoc:
    static func _fromMissingColumn() -> Self?
    
    /// Creates a value from `dbValue`, if possible.
    ///
    /// - parameter dbValue: A DatabaseValue.
    /// - returns: A decoded value, or, if decoding is impossible, nil.
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self?
}

extension DatabaseValueConvertible {
    public var sqlExpression: SQLExpression {
        .databaseValue(databaseValue)
    }
    
    public func bind(to sqliteStatement: SQLiteStatement, at index: CInt) -> CInt {
        databaseValue.bind(to: sqliteStatement, at: index)
    }
    
    /// Default implementation fails to decode a value from a missing column.
    /// `Optional` overrides this default behavior.
    /// :nodoc:
    public static func _fromMissingColumn() -> Self? {
        nil // failure.
    }
}

// MARK: - Conversions

extension DatabaseValueConvertible {
    static func decode(
        fromDatabaseValue dbValue: DatabaseValue,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self
    {
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else {
            throw DatabaseDecodingError.valueMismatch(Self.self, context: context(), databaseValue: dbValue)
        }
    }
    
    static func decode(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self
    {
        let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: index)
        return try decode(fromDatabaseValue: dbValue, context: context())
    }
    
    @usableFromInline
    static func decode(fromRow row: Row, atUncheckedIndex index: Int) throws -> Self {
        if let sqliteStatement = row.sqliteStatement {
            return try decode(
                fromStatement: sqliteStatement,
                atUncheckedIndex: Int32(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
        return try decode(
            fromDatabaseValue: row.impl.databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: row, key: .columnIndex(index)))
    }
    
    // Support for Decodable
    @usableFromInline
    static func decodeIfPresent(fromRow row: Row, atUncheckedIndex index: Int) throws -> Self? {
        try Optional<Self>.decode(fromRow: row, atUncheckedIndex: index)
    }
}

// MARK: - Cursors

/// A cursor of database values extracted from a single column.
/// For example:
///
///     try dbQueue.read { db in
///         let urls: DatabaseValueCursor<URL> = try URL.fetchCursor(db, sql: "SELECT url FROM link")
///         while let url = urls.next() { // URL
///             print(url)
///         }
///     }
public final class DatabaseValueCursor<Value: DatabaseValueConvertible>: DatabaseCursor {
    public typealias Element = Value
    public let statement: Statement
    /// :nodoc:
    public var _isDone = false
    private let columnIndex: Int32
    
    init(statement: Statement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws {
        self.statement = statement
        if let adapter = adapter {
            // adapter may redefine the index of the leftmost column
            columnIndex = try Int32(adapter.baseColumnIndex(atIndex: 0, layout: statement))
        } else {
            columnIndex = 0
        }
        
        // Assume cursor is created for immediate iteration: reset and set arguments
        try statement.reset(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? statement.reset()
    }
    
    /// :nodoc:
    public func _element(sqliteStatement: SQLiteStatement) throws -> Value {
        try Value.decode(
            fromStatement: sqliteStatement,
            atUncheckedIndex: columnIndex,
            context: RowDecodingContext(statement: statement, index: Int(columnIndex)))
    }
}

/// DatabaseValueConvertible comes with built-in methods that allow to fetch
/// cursors, arrays, or single values:
///
///     try String.fetchCursor(db, sql: "SELECT name FROM ...", arguments:...) // Cursor of String
///     try String.fetchAll(db, sql: "SELECT name FROM ...", arguments:...)    // [String]
///     try String.fetchOne(db, sql: "SELECT name FROM ...", arguments:...)    // String?
///
///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
///     try String.fetchCursor(statement, arguments:...) // Cursor of String
///     try String.fetchAll(statement, arguments:...)    // [String]
///     try String.fetchOne(statement, arguments:...)    // String
///
/// DatabaseValueConvertible is adopted by Bool, Int, String, etc.
extension DatabaseValueConvertible {
    
    // MARK: Fetching From Prepared Statement
    
    /// Returns a cursor over values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
    ///     let names = try String.fetchCursor(statement) // Cursor of String
    ///     while let name = try names.next() { // String
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> DatabaseValueCursor<Self>
    {
        try DatabaseValueCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
    ///     let names = try String.fetchAll(statement)  // [String]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> [Self]
    {
        try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from a prepared statement.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
    ///     let name = try String.fetchOne(statement)   // String?
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional value.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> Self?
    {
        // fetchOne handles both a missing row, and one row with a NULL value.
        let cursor = try DatabaseValueCursor<Self?>(
            statement: statement,
            arguments: arguments,
            adapter: adapter)
        return try cursor.next() ?? nil
    }
}

extension DatabaseValueConvertible where Self: Hashable {
    /// Returns a set of values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
    ///     let names = try String.fetchSet(statement)  // Set<String>
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchSet(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> Set<Self>
    {
        try Set(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
}

extension DatabaseValueConvertible {
    
    // MARK: Fetching From SQL
    
    /// Returns a cursor over values fetched from an SQL query.
    ///
    ///     let names = try String.fetchCursor(db, sql: "SELECT name FROM ...") // Cursor of String
    ///     while let name = try name.next() { // String
    ///         ...
    ///     }
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
    /// - returns: A cursor over fetched values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> DatabaseValueCursor<Self>
    {
        try fetchCursor(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of values fetched from an SQL query.
    ///
    ///     let names = try String.fetchAll(db, sql: "SELECT name FROM ...") // [String]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> [Self]
    {
        try fetchAll(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from an SQL query.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let name = try String.fetchOne(db, sql: "SELECT name FROM ...") // String?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional value.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> Self?
    {
        try fetchOne(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension DatabaseValueConvertible where Self: Hashable {
    /// Returns a set of values fetched from an SQL query.
    ///
    ///     let names = try String.fetchSet(db, sql: "SELECT name FROM ...") // Set<String>
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchSet(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> Set<Self>
    {
        try fetchSet(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension DatabaseValueConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a cursor over values fetched from a fetch request.
    ///
    ///     let request = Player.select(Column("name"))
    ///     let names = try String.fetchCursor(db, request) // Cursor of String
    ///     while let name = try name.next() { // String
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A cursor over fetched values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor<R: FetchRequest>(_ db: Database, _ request: R) throws -> DatabaseValueCursor<Self> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchCursor(request.statement, adapter: request.adapter)
    }
    
    /// Returns an array of values fetched from a fetch request.
    ///
    ///     let request = Player.select(Column("name"))
    ///     let names = try String.fetchAll(db, request) // [String]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An array.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll<R: FetchRequest>(_ db: Database, _ request: R) throws -> [Self] {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchAll(request.statement, adapter: request.adapter)
    }
    
    /// Returns a single value fetched from a fetch request.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let request = Player.filter(key: 1).select(Column("name"))
    ///     let name = try String.fetchOne(db, request) // String?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An optional value.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne<R: FetchRequest>(_ db: Database, _ request: R) throws -> Self? {
        let request = try request.makePreparedRequest(db, forSingleResult: true)
        return try fetchOne(request.statement, adapter: request.adapter)
    }
}

extension DatabaseValueConvertible where Self: Hashable {
    /// Returns a set of values fetched from a fetch request.
    ///
    ///     let request = Player.select(Column("name"))
    ///     let names = try String.fetchSet(db, request) // Set<String>
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A set.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchSet<R: FetchRequest>(_ db: Database, _ request: R) throws -> Set<Self> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchSet(request.statement, adapter: request.adapter)
    }
}

extension FetchRequest where RowDecoder: DatabaseValueConvertible {
    
    // MARK: Fetching Values
    
    /// A cursor over fetched values.
    ///
    ///     let request: ... // Some FetchRequest that fetches String
    ///     let strings = try request.fetchCursor(db) // Cursor of String
    ///     while let string = try strings.next() {   // String
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> DatabaseValueCursor<RowDecoder> {
        try RowDecoder.fetchCursor(db, self)
    }
    
    /// An array of fetched values.
    ///
    ///     let request: ... // Some FetchRequest that fetches String
    ///     let strings = try request.fetchAll(db) // [String]
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        try RowDecoder.fetchAll(db, self)
    }
    
    /// The first fetched value.
    ///
    /// The result is nil if the request returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let request: ... // Some FetchRequest that fetches String
    ///     let string = try request.fetchOne(db) // String?
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional value.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        try RowDecoder.fetchOne(db, self)
    }
}

extension FetchRequest where RowDecoder: DatabaseValueConvertible & Hashable {
    /// A set of fetched values.
    ///
    ///     let request: ... // Some FetchRequest that fetches String
    ///     let strings = try request.fetchSet(db) // Set<String>
    ///
    /// - parameter db: A database connection.
    /// - returns: A set of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder> {
        try RowDecoder.fetchSet(db, self)
    }
}
