/// The `StatementColumnConvertible` protocol grants access to the low-level C
/// interface that extracts values from query results:
/// <https://www.sqlite.org/c3ref/column_blob.html>. It can bring performance
/// improvements.
///
/// To use it, have a value type adopt both `StatementColumnConvertible` and
/// `DatabaseValueConvertible`. GRDB will then automatically apply the
/// optimization whenever direct access to SQLite is possible:
///
///     let rows = Row.fetchCursor(db, sql: "SELECT ...")
///     while let row = try rows.next() {
///         let int: Int = row[0]                 // there
///     }
///     let ints = Int.fetchAll(db, sql: "SELECT ...") // there
///     struct Player {
///         init(row: Row) {
///             name = row["name"]                // there
///             score = row["score"]              // there
///         }
///     }
public protocol StatementColumnConvertible {
    
    /// Initializes a value from a raw SQLite statement pointer, if possible.
    ///
    /// For example, here is the how Int64 adopts StatementColumnConvertible:
    ///
    ///     extension Int64: StatementColumnConvertible {
    ///         init?(sqliteStatement: SQLiteStatement, index: Int32) {
    ///             self = sqlite3_column_int64(sqliteStatement, index)
    ///         }
    ///     }
    ///
    /// This initializer is never called for NULL database values. Just return
    /// `nil` for failed conversions: GRDB will interpret a nil result as a
    /// decoding failure.
    ///
    /// See <https://www.sqlite.org/c3ref/column_blob.html> for more information.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    init?(sqliteStatement: SQLiteStatement, index: Int32)
}

// MARK: - Conversions

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    @usableFromInline
    /* private */ static func _valueMismatch(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
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
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self
    {
        guard sqlite3_column_type(sqliteStatement, index) != SQLITE_NULL,
              let value = self.init(sqliteStatement: sqliteStatement, index: index)
        else {
            try _valueMismatch(fromStatement: sqliteStatement, atUncheckedIndex: index, context: context())
        }
        return value
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
                atUncheckedIndex: Int32(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
        // Support for fast decoding from adapted rows
        return try row.fastDecode(Self.self, atUncheckedIndex: index)
    }
    
    @inline(__always)
    @inlinable
    static func fastDecodeIfPresent(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self?
    {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            return nil
        }
        guard let value = self.init(sqliteStatement: sqliteStatement, index: index) else {
            try _valueMismatch(fromStatement: sqliteStatement, atUncheckedIndex: index, context: context())
        }
        return value
    }
    
    @inline(__always)
    @inlinable
    static func fastDecodeIfPresent(
        fromRow row: Row,
        atUncheckedIndex index: Int)
    throws -> Self?
    {
        if let sqliteStatement = row.sqliteStatement {
            return try fastDecodeIfPresent(
                fromStatement: sqliteStatement,
                atUncheckedIndex: Int32(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
        // Support for fast decoding from adapted rows
        return try row.fastDecodeIfPresent(Self.self, atUncheckedIndex: index)
    }
}

// MARK: - Cursors

/// A cursor of database values extracted from a single column.
/// For example:
///
///     try dbQueue.read { db in
///         let names: ColumnCursor<String> = try String.fetchCursor(db, sql: "SELECT name FROM player")
///         while let name = names.next() { // String
///             print(name)
///         }
///     }
public final class FastDatabaseValueCursor<Value>: DatabaseCursor
where Value: DatabaseValueConvertible & StatementColumnConvertible
{
    public typealias Element = Value
    public let statement: Statement
    /// :nodoc:
    public var _isDone = false
    @usableFromInline let columnIndex: Int32
    
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
    @inlinable
    public func _element(sqliteStatement: SQLiteStatement) -> Value {
        // TODO GRDB6: don't crash on decoding errors
        try! Value.fastDecode(
            fromStatement: sqliteStatement,
            atUncheckedIndex: columnIndex,
            context: RowDecodingContext(statement: statement, index: Int(columnIndex)))
    }
}

/// A cursor of optional database values extracted from a single column.
/// For example:
///
///     try dbQueue.read { db in
///         let emails: FastNullableDatabaseValueCursor<String> =
///             try Optional<String>.fetchCursor(db, sql: "SELECT email FROM player")
///         while let email = emails.next() { // String?
///             print(email ?? "<NULL>")
///         }
///     }
public final class FastNullableDatabaseValueCursor<Value>: DatabaseCursor
where Value: DatabaseValueConvertible & StatementColumnConvertible
{
    public typealias Element = Value?
    public let statement: Statement
    /// :nodoc:
    public var _isDone = false
    @usableFromInline let columnIndex: Int32
    
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
    @inlinable
    public func _element(sqliteStatement: SQLiteStatement) -> Value? {
        // TODO GRDB6: don't crash on decoding errors
        try! Value.fastDecodeIfPresent(
            fromStatement: sqliteStatement,
            atUncheckedIndex: columnIndex,
            context: RowDecodingContext(statement: statement, index: Int(columnIndex)))
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
    throws -> FastDatabaseValueCursor<Self>
    {
        try FastDatabaseValueCursor(statement: statement, arguments: arguments, adapter: adapter)
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
    /// - returns: An array of values.
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
        let cursor = try FastNullableDatabaseValueCursor<Self>(
            statement: statement,
            arguments: arguments,
            adapter: adapter)
        return try cursor.next() ?? nil
    }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible & Hashable {
    /// Returns a set of values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT name FROM ...")
    ///     let names = try String.fetchSet(statement)  // Set<String>
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of values.
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

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    // MARK: Fetching From SQL
    
    /// Returns a cursor over values fetched from an SQL query.
    ///
    ///     let names = try String.fetchCursor(db, sql: "SELECT name FROM ...") // Cursor of String
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
    throws -> FastDatabaseValueCursor<Self>
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
    /// - returns: An array of values.
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

extension DatabaseValueConvertible where Self: StatementColumnConvertible & Hashable {
    /// Returns a set of values fetched from an SQL query.
    ///
    ///     let names = try String.fetchSet(db, sql: "SELECT name FROM ...") // Set<String>
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of values.
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

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a cursor over values fetched from a fetch request.
    ///
    ///     let request = Player.select(Column("name"))
    ///     let names = try String.fetchCursor(db, request) // Cursor of String
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
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A cursor over fetched values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor<R: FetchRequest>(_ db: Database, _ request: R)
    throws -> FastDatabaseValueCursor<Self>
    {
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
    /// - returns: An array of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll<R: FetchRequest>(_ db: Database, _ request: R) throws -> [Self] {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchAll(request.statement, adapter: request.adapter)
    }
    
    /// Returns a single value fetched from a fetch request.
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

extension DatabaseValueConvertible where Self: StatementColumnConvertible & Hashable {
    /// Returns a set of values fetched from a fetch request.
    ///
    ///     let request = Player.select(Column("name"))
    ///     let names = try String.fetchSet(db, request) // Set<String>
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A set of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchSet<R: FetchRequest>(_ db: Database, _ request: R) throws -> Set<Self> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchSet(request.statement, adapter: request.adapter)
    }
}

extension FetchRequest where RowDecoder: DatabaseValueConvertible & StatementColumnConvertible {
    
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
    public func fetchCursor(_ db: Database) throws -> FastDatabaseValueCursor<RowDecoder> {
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

extension FetchRequest where RowDecoder: DatabaseValueConvertible & StatementColumnConvertible & Hashable {
    /// A set of fetched values.
    ///
    ///     let request: ... // Some FetchRequest that fetches String
    ///     let strings = try request.fetchSet(db) // Set<String>
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of values.
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
extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible {
    
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
    throws -> FastNullableDatabaseValueCursor<Wrapped>
    {
        try FastNullableDatabaseValueCursor(statement: statement, arguments: arguments, adapter: adapter)
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

extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible & Hashable {
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

extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible {
    
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
    throws -> FastNullableDatabaseValueCursor<Wrapped>
    {
        try fetchCursor(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of optional values fetched from an SQL query.
    ///
    ///     let names = try Optional<String>.fetchAll(db, sql: "SELECT name FROM ...") // [String?]
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

extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible & Hashable {
    /// Returns a set of optional values fetched from an SQL query.
    ///
    ///     let names = try Optional<String>.fetchSet(db, sql: "SELECT name FROM ...") // Set<String?>
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

extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible {
    
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
    throws -> FastNullableDatabaseValueCursor<Wrapped>
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

extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible & Hashable {
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

extension FetchRequest
where
    RowDecoder: _OptionalProtocol,
    RowDecoder.Wrapped: DatabaseValueConvertible & StatementColumnConvertible
{
    
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
    public func fetchCursor(_ db: Database) throws -> FastNullableDatabaseValueCursor<RowDecoder.Wrapped> {
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

extension FetchRequest
where
    RowDecoder: _OptionalProtocol,
    RowDecoder.Wrapped: DatabaseValueConvertible & StatementColumnConvertible & Hashable
{
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
