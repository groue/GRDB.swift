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
    
    /// Returns a value initialized from `dbValue`, if possible.
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self?
}

extension DatabaseValueConvertible {
    public var sqlExpression: SQLExpression {
        .databaseValue(databaseValue)
    }
    
    public func bind(to sqliteStatement: SQLiteStatement, at index: CInt) -> CInt {
        databaseValue.bind(to: sqliteStatement, at: index)
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
    
    static func decodeIfPresent(
        fromDatabaseValue dbValue: DatabaseValue,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self?
    {
        // Use fromDatabaseValue before checking for null: this allows DatabaseValue to convert NULL to .null.
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else if dbValue.isNull {
            return nil
        } else {
            throw RowDecodingError.valueMismatch(Self.self, context: context(), databaseValue: dbValue)
        }
    }
    
    static func decodeIfPresent(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self?
    {
        let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: index)
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else if dbValue.isNull {
            return nil
        } else {
            throw RowDecodingError.valueMismatch(Self.self, context: context(), databaseValue: dbValue)
        }
    }
    
    @usableFromInline
    static func decodeIfPresent(fromRow row: Row, atUncheckedIndex index: Int) throws -> Self? {
        if let sqliteStatement = row.sqliteStatement {
            return try decodeIfPresent(
                fromStatement: sqliteStatement,
                atUncheckedIndex: Int32(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
        return try decodeIfPresent(
            fromDatabaseValue: row.impl.databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: row, key: .columnIndex(index)))
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
    public func _element(sqliteStatement: SQLiteStatement) -> Value {
        // TODO GRDB6: don't crash on decoding errors
        try! Value.decode(
            fromStatement: sqliteStatement,
            atUncheckedIndex: columnIndex,
            context: RowDecodingContext(statement: statement, index: Int(columnIndex)))
    }
}

/// A cursor of optional database values extracted from a single column.
/// For example:
///
///     try dbQueue.read { db in
///         let urls: NullableDatabaseValueCursor<URL> = try Optional<URL>.fetchCursor(db, sql: "SELECT url FROM link")
///         while let url = urls.next() { // URL?
///             print(url)
///         }
///     }
public final class NullableDatabaseValueCursor<Value: DatabaseValueConvertible>: DatabaseCursor {
    public typealias Element = Value?
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
    public func _element(sqliteStatement: SQLiteStatement) -> Value? {
        // TODO GRDB6: don't crash on decoding errors
        try! Value.decodeIfPresent(
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
        // fetchOne returns nil if there is no row, or if there is a row with a null value
        let cursor = try NullableDatabaseValueCursor<Self>(statement: statement, arguments: arguments, adapter: adapter)
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

/// Swift's Optional comes with built-in methods that allow to fetch cursors
/// and arrays of optional DatabaseValueConvertible:
///
///     try Optional<String>.fetchCursor(db, sql: "SELECT name FROM ...", arguments:...) // Cursor of String?
///     try Optional<String>.fetchAll(db, sql: "SELECT name FROM ...", arguments:...)    // [String?]
///
///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
///     try Optional<String>.fetchCursor(statement, arguments:...) // Cursor of String?
///     try Optional<String>.fetchAll(statement, arguments:...)    // [String?]
///
/// DatabaseValueConvertible is adopted by Bool, Int, String, etc.
extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From Prepared Statement
    
    /// Returns a cursor over optional values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
    ///     let names = try Optional<String>.fetchCursor(statement) // Cursor of String?
    ///     while let name = try names.next() { // String?
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
    /// - returns: A cursor over fetched optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> NullableDatabaseValueCursor<Wrapped>
    {
        try NullableDatabaseValueCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of optional values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
    ///     let names = try Optional<String>.fetchAll(statement)  // [String?]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> [Wrapped?]
    {
        try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
}

extension Optional where Wrapped: DatabaseValueConvertible & Hashable {
    /// Returns a set of optional values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
    ///     let names = try Optional<String>.fetchSet(statement)  // Set<String?>
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchSet(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
    throws -> Set<Wrapped?>
    {
        try Set(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
}

extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From SQL
    
    /// Returns a cursor over optional values fetched from an SQL query.
    ///
    ///     let names = try Optional<String>.fetchCursor(db, sql: "SELECT name FROM ...") // Cursor of String?
    ///     while let name = try names.next() { // String?
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
    /// - returns: A cursor over fetched optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> NullableDatabaseValueCursor<Wrapped>
    {
        try fetchCursor(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of optional values fetched from an SQL query.
    ///
    ///     let names = try String.fetchAll(db, sql: "SELECT name FROM ...") // [String?]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> [Wrapped?]
    {
        try fetchAll(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension Optional where Wrapped: DatabaseValueConvertible & Hashable {
    /// Returns a set of optional values fetched from an SQL query.
    ///
    ///     let names = try String.fetchSet(db, sql: "SELECT name FROM ...") // Set<String?>
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchSet(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
    throws -> Set<Wrapped?>
    {
        try fetchSet(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a cursor over optional values fetched from a fetch request.
    ///
    ///     let request = Player.select(Column("name"))
    ///     let names = try Optional<String>.fetchCursor(db, request) // Cursor of String?
    ///     while let name = try names.next() { // String?
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
    /// - returns: A cursor over fetched optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor<R: FetchRequest>(_ db: Database, _ request: R)
    throws -> NullableDatabaseValueCursor<Wrapped>
    {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchCursor(request.statement, adapter: request.adapter)
    }
    
    /// Returns an array of optional values fetched from a fetch request.
    ///
    ///     let request = Player.select(Column("name"))
    ///     let names = try Optional<String>.fetchAll(db, request) // [String?]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An array of optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll<R: FetchRequest>(_ db: Database, _ request: R) throws -> [Wrapped?] {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchAll(request.statement, adapter: request.adapter)
    }
}

extension Optional where Wrapped: DatabaseValueConvertible & Hashable {
    /// Returns a set of optional values fetched from a fetch request.
    ///
    ///     let request = Player.select(Column("name"))
    ///     let names = try Optional<String>.fetchSet(db, request) // Set<String?>
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A set of optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchSet<R: FetchRequest>(_ db: Database, _ request: R) throws -> Set<Wrapped?> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchSet(request.statement, adapter: request.adapter)
    }
}

extension FetchRequest where RowDecoder: _OptionalProtocol, RowDecoder.Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching Optional values
    
    /// A cursor over fetched optional values.
    ///
    ///     let request: ... // Some FetchRequest that fetches Optional<String>
    ///     let strings = try request.fetchCursor(db) // Cursor of String?
    ///     while let string = try strings.next() {   // String?
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
    public func fetchCursor(_ db: Database) throws -> NullableDatabaseValueCursor<RowDecoder.Wrapped> {
        try Optional<RowDecoder.Wrapped>.fetchCursor(db, self)
    }
    
    /// An array of fetched optional values.
    ///
    ///     let request: ... // Some FetchRequest that fetches Optional<String>
    ///     let strings = try request.fetchAll(db) // [String?]
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder.Wrapped?] {
        try Optional<RowDecoder.Wrapped>.fetchAll(db, self)
    }
    
    /// The first fetched value.
    ///
    /// The result is nil if the request returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let request: ... // Some FetchRequest that fetches String?
    ///     let string = try request.fetchOne(db) // String?
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional value.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder.Wrapped? {
        try RowDecoder.Wrapped.fetchOne(db, self)
    }
}

extension FetchRequest where RowDecoder: _OptionalProtocol, RowDecoder.Wrapped: DatabaseValueConvertible & Hashable {
    /// A set of fetched optional values.
    ///
    ///     let request: ... // Some FetchRequest that fetches Optional<String>
    ///     let strings = try request.fetchSet(db) // Set<String?>
    ///
    /// - parameter db: A database connection.
    /// - returns: A set of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder.Wrapped?> {
        try Optional<RowDecoder.Wrapped>.fetchSet(db, self)
    }
}
