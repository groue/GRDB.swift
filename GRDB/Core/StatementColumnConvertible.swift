#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// The StatementColumnConvertible protocol grants access to the low-level C
/// interface that extracts values from query results:
/// https://www.sqlite.org/c3ref/column_blob.html. It can bring performance
/// improvements.
///
/// To use it, have a value type adopt both StatementColumnConvertible and
/// DatabaseValueConvertible. GRDB will then automatically apply the
/// optimization whenever direct access to SQLite is possible:
///
///     let rows = Row.fetchCursor(db, "SELECT ...")
///     while let row = try rows.next() {
///         let int: Int = row[0]                 // there
///     }
///     let ints = Int.fetchAll(db, "SELECT ...") // there
///     struct Player {
///         init(row: Row) {
///             name = row["name"]                // there
///             score = row["score"]              // there
///         }
///     }
///
/// StatementColumnConvertible is already adopted by all Swift integer types,
/// Float, Double, String, and Bool.
public protocol StatementColumnConvertible {
    
    /// Initializes a value from a raw SQLite statement pointer.
    ///
    /// For example, here is the how Int64 adopts StatementColumnConvertible:
    ///
    ///     extension Int64: StatementColumnConvertible {
    ///         init(sqliteStatement: SQLiteStatement, index: Int32) {
    ///             self = sqlite3_column_int64(sqliteStatement, index)
    ///         }
    ///     }
    ///
    /// This initializer is never called for NULL database values: don't perform
    /// any extra check.
    ///
    /// See https://www.sqlite.org/c3ref/column_blob.html for more information.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    init(sqliteStatement: SQLiteStatement, index: Int32)
}

/// A cursor of database values extracted from a single column.
/// For example:
///
///     try dbQueue.inDatabase { db in
///         let names: ColumnCursor<String> = try String.fetchCursor(db, "SELECT name FROM players")
///         while let name = names.next() { // String
///             print(name)
///         }
///     }
public final class ColumnCursor<Value: DatabaseValueConvertible & StatementColumnConvertible> : Cursor {
    private let statement: SelectStatement
    private let sqliteStatement: SQLiteStatement
    private let columnIndex: Int32
    private var done = false
    
    init(statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws {
        self.statement = statement
        // We'll read from leftmost column at index 0, unless adapter mangles columns
        self.columnIndex = try Int32(adapter?.baseColumnIndex(atIndex: 0, layout: statement) ?? 0)
        self.sqliteStatement = statement.sqliteStatement
        statement.cursorReset(arguments: arguments)
    }
    
    public func next() throws -> Value? {
        if done { return nil }
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE:
            done = true
            return nil
        case SQLITE_ROW:
            if sqlite3_column_type(sqliteStatement, columnIndex) == SQLITE_NULL {
                var error = "could not convert database value NULL to \(Value.self) with statement `\(statement.sql)`"
                if !statement.arguments.isEmpty {
                    error += " arguments \(statement.arguments)"
                }
                fatalError(error)
            }
            return Value(sqliteStatement: sqliteStatement, index: columnIndex)
        case let code:
            statement.database.selectStatementDidFail(statement)
            throw DatabaseError(resultCode: code, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments)
        }
    }
}

/// A cursor of optional database values extracted from a single column.
/// For example:
///
///     try dbQueue.inDatabase { db in
///         let emails: NullableColumnCursor<String> = try Optional<String>.fetchCursor(db, "SELECT email FROM players")
///         while let email = emails.next() { // String?
///             print(email ?? "<NULL>")
///         }
///     }
public final class NullableColumnCursor<Value: DatabaseValueConvertible & StatementColumnConvertible> : Cursor {
    private let statement: SelectStatement
    private let sqliteStatement: SQLiteStatement
    private let columnIndex: Int32
    private var done = false
    
    init(statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws {
        self.statement = statement
        // We'll read from leftmost column at index 0, unless adapter mangles columns
        self.columnIndex = try Int32(adapter?.baseColumnIndex(atIndex: 0, layout: statement) ?? 0)
        self.sqliteStatement = statement.sqliteStatement
        statement.cursorReset(arguments: arguments)
    }
    
    public func next() throws -> Value?? {
        if done { return nil }
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE:
            done = true
            return nil
        case SQLITE_ROW:
            if sqlite3_column_type(sqliteStatement, columnIndex) == SQLITE_NULL {
                return .some(nil)
            }
            return Value(sqliteStatement: sqliteStatement, index: columnIndex)
        case let code:
            statement.database.selectStatementDidFail(statement)
            throw DatabaseError(resultCode: code, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments)
        }
    }
}

/// Types that adopt both DatabaseValueConvertible and
/// StatementColumnConvertible can be efficiently initialized from
/// database values.
///
/// See DatabaseValueConvertible for more information.
extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    
    // MARK: Fetching From SelectStatement
    
    /// Returns a cursor over values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
    ///     let names = try String.fetchCursor(statement) // Cursor of String
    ///     while let name = try names.next() { // String
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> ColumnCursor<Self> {
        return try ColumnCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
    ///     let names = try String.fetchAll(statement)  // [String]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Self] {
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
    ///     let name = try String.fetchOne(statement)   // String?
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional value.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Self? {
        // fetchOne returns nil if there is no row, or if there is a row with a null value
        let cursor = try NullableColumnCursor<Self>(statement: statement, arguments: arguments, adapter: adapter)
        return try cursor.next() ?? nil
    }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    // MARK: Fetching From Request
    
    /// Returns a cursor over values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn)
    ///     let names = try String.fetchCursor(db, request) // Cursor of String
    ///     while let name = try names.next() { // String
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A fetch request.
    /// - returns: A cursor over fetched values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: Request) throws -> ColumnCursor<Self> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    /// Returns an array of values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn)
    ///     let names = try String.fetchAll(db, request)  // [String]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: Request) throws -> [Self] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single value fetched from a fetch request.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn)
    ///     let name = try String.fetchOne(db, request)   // String?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ request: Request) throws -> Self? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible {

    // MARK: Fetching From SQL
    
    /// Returns a cursor over values fetched from an SQL query.
    ///
    ///     let names = try String.fetchCursor(db, "SELECT name FROM ...") // Cursor of String
    ///     while let name = try names.next() { // String
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> ColumnCursor<Self> {
        return try fetchCursor(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of values fetched from an SQL query.
    ///
    ///     let names = try String.fetchAll(db, "SELECT name FROM ...") // [String]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Self] {
        return try fetchAll(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from an SQL query.
    ///
    ///     let name = try String.fetchOne(db, "SELECT name FROM ...") // String?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional value.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Self? {
        return try fetchOne(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
}


/// Swift's Optional comes with built-in methods that allow to fetch cursors
/// and arrays of optional DatabaseValueConvertible:
///
///     try Optional<String>.fetchCursor(db, "SELECT name FROM ...", arguments:...) // Cursor of String?
///     try Optional<String>.fetchAll(db, "SELECT name FROM ...", arguments:...)    // [String?]
///
///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
///     try Optional<String>.fetchCursor(statement, arguments:...) // Cursor of String?
///     try Optional<String>.fetchAll(statement, arguments:...)    // [String?]
///
/// DatabaseValueConvertible is adopted by Bool, Int, String, etc.
extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible {
    
    // MARK: Fetching From SelectStatement
    
    /// Returns a cursor over optional values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
    ///     let names = try Optional<String>.fetchCursor(statement) // Cursor of String?
    ///     while let name = try names.next() { // String?
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> NullableColumnCursor<Wrapped> {
        return try NullableColumnCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of optional values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
    ///     let names = try Optional<String>.fetchAll(statement)  // [String?]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Wrapped?] {
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
}

extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible {
    
    // MARK: Fetching From Request
    
    /// Returns a cursor over optional values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn)
    ///     let names = try Optional<String>.fetchCursor(db, request) // Cursor of String?
    ///     while let name = try names.next() { // String?
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - requet: A fetch request.
    /// - returns: A cursor over fetched optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: Request) throws -> NullableColumnCursor<Wrapped> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    /// Returns an array of optional values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn)
    ///     let names = try Optional<String>.fetchAll(db, request) // [String?]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: Request) throws -> [Wrapped?] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
}

extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible {
    
    // MARK: Fetching From SQL
    
    /// Returns a cursor over optional values fetched from an SQL query.
    ///
    ///     let names = try Optional<String>.fetchCursor(db, "SELECT name FROM ...") // Cursor of String?
    ///     while let name = try names.next() { // String?
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> NullableColumnCursor<Wrapped> {
        return try fetchCursor(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of optional values fetched from an SQL query.
    ///
    ///     let names = try String.fetchAll(db, "SELECT name FROM ...") // [String?]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - parameter arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Wrapped?] {
        return try fetchAll(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
}
