#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// Types that adopt RowConvertible can be initialized from a database Row.
///
///     let row = try Row.fetchOne(db, "SELECT ...")!
///     let player = Player(row)
///
/// The protocol comes with built-in methods that allow to fetch cursors,
/// arrays, or single records:
///
///     try Player.fetchCursor(db, "SELECT ...", arguments:...) // Cursor of Player
///     try Player.fetchAll(db, "SELECT ...", arguments:...)    // [Player]
///     try Player.fetchOne(db, "SELECT ...", arguments:...)    // Player?
///
///     let statement = try db.makeSelectStatement("SELECT ...")
///     try Player.fetchCursor(statement, arguments:...) // Cursor of Player
///     try Player.fetchAll(statement, arguments:...)    // [Player]
///     try Player.fetchOne(statement, arguments:...)    // Player?
///
/// RowConvertible is adopted by Record.
public protocol RowConvertible {
    
    /// Initializes a record from `row`.
    ///
    /// For performance reasons, the row argument may be reused during the
    /// iteration of a fetch query. If you want to keep the row for later use,
    /// make sure to store a copy: `self.row = row.copy()`.
    init(row: Row)
}

/// A cursor of records. For example:
///
///     struct Player : RowConvertible { ... }
///     try dbQueue.inDatabase { db in
///         let players: RecordCursor<Player> = try Player.fetchCursor(db, "SELECT * FROM players")
///     }
public final class RecordCursor<Record: RowConvertible> : Cursor {
    private let statement: SelectStatement
    private let row: Row // Reused for performance
    private let sqliteStatement: SQLiteStatement
    private var done = false
    
    init(statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws {
        self.statement = statement
        self.row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        self.sqliteStatement = statement.sqliteStatement
        statement.cursorReset(arguments: arguments)
    }
    
    public func next() throws -> Record? {
        if done { return nil }
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE:
            done = true
            return nil
        case SQLITE_ROW:
            return Record(row: row)
        case let code:
            statement.database.selectStatementDidFail(statement)
            throw DatabaseError(resultCode: code, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments)
        }
    }
}

extension RowConvertible {
    
    // MARK: Fetching From SelectStatement
    
    /// A cursor over records fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT * FROM players")
    ///     let players = try Player.fetchCursor(statement) // Cursor of Player
    ///     while let player = try players.next() { // Player
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
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> RecordCursor<Self> {
        return try RecordCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of records fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT * FROM players")
    ///     let players = try Player.fetchAll(statement) // [Player]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Self] {
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single record fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT * FROM players")
    ///     let player = try Player.fetchOne(statement) // Player?
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Self? {
        return try fetchCursor(statement, arguments: arguments, adapter: adapter).next()
    }
}

extension RowConvertible {
    
    // MARK: Fetching From Request
    
    /// Returns a cursor over records fetched from a fetch request.
    ///
    ///     let nameColumn = Column("firstName")
    ///     let request = Player.order(nameColumn)
    ///     let identities = try Identity.fetchCursor(db, request) // Cursor of Identity
    ///     while let identity = try identities.next() { // Identity
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
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: Request) throws -> RecordCursor<Self> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    /// Returns an array of records fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.order(nameColumn)
    ///     let identities = try Identity.fetchAll(db, request) // [Identity]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: Request) throws -> [Self] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single record fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.order(nameColumn)
    ///     let identity = try Identity.fetchOne(db, request) // Identity?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ request: Request) throws -> Self? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

extension RowConvertible {
    
    // MARK: Fetching From SQL
    
    /// Returns a cursor over records fetched from an SQL query.
    ///
    ///     let players = try Player.fetchCursor(db, "SELECT * FROM players") // Cursor of Player
    ///     while let player = try players.next() { // Player
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
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> RecordCursor<Self> {
        return try fetchCursor(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of records fetched from an SQL query.
    ///
    ///     let players = try Player.fetchAll(db, "SELECT * FROM players") // [Player]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Self] {
        return try fetchAll(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single record fetched from an SQL query.
    ///
    ///     let player = try Player.fetchOne(db, "SELECT * FROM players") // Player?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Self? {
        return try fetchOne(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
}
