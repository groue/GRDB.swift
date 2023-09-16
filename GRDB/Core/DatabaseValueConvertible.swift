import Foundation

// Standard collections `Array`, `Set`, and `Dictionary` do not conform to
// `DatabaseValueConvertible`, on purpose.
//
// Adding `DatabaseValueConvertible` conformance to those collection types
// would litter JSON values in unexpected places, and foster misuse. For
// example, it is better when the code below *does not compile*:
//
// ```swift
// // MISUSE: if Array would conform to DatabaseValueConvertible, this
// // code would compile, and run the incorrect SQLite query
// // `SELECT ... WHERE id IN ('[1,2,3]')`, instead of the expected
// // `SELECT ... WHERE id IN (1, 2, 3)`.
// let ids = [1, 2, 3]
// let players = try Player.fetchAll(db, sql: """
//     SELECT * FROM player WHERE id IN (?)
//     """, arguments: [ids])
// ```
//
// Correct and fostered versions of the code above are:
//
// ```swift
// // CORRECT (explicit SQLite arguments):
// let ids = [1, 2, 3]
// let questionMarks = databaseQuestionMarks(count: ids.count) // "?,?,?"
// let players = try Player.fetchAll(db, sql: """
//     SELECT * FROM player WHERE id IN (\(questionMarks))
//     """, arguments: StatementArguments(ids))
//
// // CORRECT (SQL interpolation):
// let ids = [1, 2, 3]
// let request: SQLRequest<Player> = """
//     SELECT * FROM player WHERE id IN \(ids)
//     """
// let players = try request.fetchAll(db)
// ```
public protocol DatabaseValueConvertible: SQLExpressible, StatementBinding {
    /// A database value.
    var databaseValue: DatabaseValue { get }
    
    /// Creates an instance with the specified database value.
    ///
    /// If there is no value of the type that corresponds with the specified
    /// database value, this method returns nil. For example:
    ///
    /// ```swift
    /// let dbValue = "Arthur".databaseValue
    ///
    /// String.fromDatabaseValue(dbValue) // "Arthur"
    /// Int.fromDatabaseValue(dbValue)    // nil
    /// ```
    ///
    /// - parameter dbValue: A DatabaseValue.
    /// - returns: A decoded value, or, if decoding is impossible, nil.
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self?
    
    /// Creates an instance from a missing column, if possible.
    ///
    /// - warning: Do not customize the default implementation.
    ///
    /// - returns: A decoded value, or, if decoding is impossible, nil.
    static func fromMissingColumn() -> Self?
    
    /// Returns the `JSONDecoder` that decodes the value.
    ///
    /// This method is dedicated to ``DatabaseValueConvertible`` types that 
    /// also conform to the standard `Decodable` protocol.
    static func databaseJSONDecoder() -> JSONDecoder
    
    /// Returns the `JSONEncoder` that encodes the value.
    ///
    /// This method is dedicated to ``DatabaseValueConvertible`` types that
    /// also conform to the standard `Encodable` protocol.
    static func databaseJSONEncoder() -> JSONEncoder
}

extension DatabaseValueConvertible {
    public var sqlExpression: SQLExpression {
        .databaseValue(databaseValue)
    }
    
    public func bind(to sqliteStatement: SQLiteStatement, at index: CInt) -> CInt {
        databaseValue.bind(to: sqliteStatement, at: index)
    }

    // `Optional` overrides this default behavior.
    /// Default implementation fails to decode a value from a missing column.
    public static func fromMissingColumn() -> Self? {
        nil // failure.
    }
    
    /// Returns the `JSONDecoder` that decodes the value.
    ///
    /// The default implementation returns a `JSONDecoder` with the
    /// following properties:
    ///
    /// - `dataDecodingStrategy`: `.base64`
    /// - `dateDecodingStrategy`: `.millisecondsSince1970`
    /// - `nonConformingFloatDecodingStrategy`: `.throw`
    public static func databaseJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .base64
        decoder.dateDecodingStrategy = .millisecondsSince1970
        decoder.nonConformingFloatDecodingStrategy = .throw
        return decoder
    }
    
    /// Returns the `JSONEncoder` that encodes the value.
    ///
    /// The default implementation returns a `JSONEncoder` with the
    /// following properties:
    ///
    /// - `dataEncodingStrategy`: `.base64`
    /// - `dateEncodingStrategy`: `.millisecondsSince1970`
    /// - `nonConformingFloatEncodingStrategy`: `.throw`
    /// - `outputFormatting`: `.sortedKeys`
    public static func databaseJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dataEncodingStrategy = .base64
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.nonConformingFloatEncodingStrategy = .throw
        // guarantee some stability in order to ease value comparison
        encoder.outputFormatting = .sortedKeys
        return encoder
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
            throw RowDecodingError.valueMismatch(Self.self, context: context(), databaseValue: dbValue)
        }
    }
    
    static func decode(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: CInt,
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
                atUncheckedIndex: CInt(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
        return try decode(
            fromDatabaseValue: row.impl.databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: row, key: .columnIndex(index)))
    }
    
    @usableFromInline
    static func decodeIfPresent(fromRow row: Row, atUncheckedIndex index: Int) throws -> Self? {
        try Optional<Self>.decode(fromRow: row, atUncheckedIndex: index)
    }
}

// MARK: - Cursors

/// A cursor of database values.
///
/// A `DatabaseValueCursor` iterates all rows from a database request. Its
/// elements are the database values decoded from the leftmost column.
///
/// For example:
///
/// ```swift
/// try dbQueue.read { db in
///     let names: DatabaseValueCursor<String> = try String.fetchCursor(db, sql: """
///         SELECT name FROM player
///         """)
///     while let name = names.next() { // String
///         print(name)
///     }
/// }
/// ```
public final class DatabaseValueCursor<Value: DatabaseValueConvertible>: DatabaseCursor {
    public typealias Element = Value
    public let _statement: Statement
    public var _isDone = false
    private let columnIndex: CInt
    
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
    
    public func _element(sqliteStatement: SQLiteStatement) throws -> Value {
        try Value.decode(
            fromStatement: sqliteStatement,
            atUncheckedIndex: columnIndex,
            context: RowDecodingContext(statement: _statement, index: Int(columnIndex)))
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
    /// - returns: A ``DatabaseValueCursor`` over fetched values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> DatabaseValueCursor<Self>
    {
        try DatabaseValueCursor(statement: statement, arguments: arguments, adapter: adapter)
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
    /// - returns: An array.
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
        // fetchOne returns nil if there is no row, or if there is a row with a null value
        let cursor = try DatabaseValueCursor<Self?>(statement: statement, arguments: arguments, adapter: adapter)
        return try cursor.next() ?? nil
    }
}

extension DatabaseValueConvertible where Self: Hashable {
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
    /// - returns: A set.
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

extension DatabaseValueConvertible {
    
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
    /// - returns: A ``DatabaseValueCursor`` over fetched values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> DatabaseValueCursor<Self>
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
    /// - returns: An array.
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

extension DatabaseValueConvertible where Self: Hashable {
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
    /// - returns: A set.
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

extension DatabaseValueConvertible {
    
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
    /// - returns: A ``DatabaseValueCursor`` over fetched values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: some FetchRequest) throws -> DatabaseValueCursor<Self> {
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
    /// - returns: An array.
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

extension DatabaseValueConvertible where Self: Hashable {
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
    /// - returns: A set.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(_ db: Database, _ request: some FetchRequest) throws -> Set<Self> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchSet(request.statement, adapter: request.adapter)
    }
}

extension FetchRequest where RowDecoder: DatabaseValueConvertible {
    
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
    /// - returns: A ``DatabaseValueCursor`` over fetched values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> DatabaseValueCursor<RowDecoder> {
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

extension FetchRequest where RowDecoder: DatabaseValueConvertible & Hashable {
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
