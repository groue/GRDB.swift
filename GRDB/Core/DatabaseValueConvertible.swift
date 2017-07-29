// MARK: - DatabaseValueConvertible

/// Types that adopt DatabaseValueConvertible can be initialized from
/// database values.
///
/// The protocol comes with built-in methods that allow to fetch cursors,
/// arrays, or single values:
///
///     try String.fetchCursor(db, "SELECT name FROM ...", arguments:...) // DatabaseCursor<String>
///     try String.fetchAll(db, "SELECT name FROM ...", arguments:...)    // [String]
///     try String.fetchOne(db, "SELECT name FROM ...", arguments:...)    // String?
///
///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
///     try String.fetchCursor(statement, arguments:...) // DatabaseCursor<String>
///     try String.fetchAll(statement, arguments:...)    // [String]
///     try String.fetchOne(statement, arguments:...)    // String?
///
/// DatabaseValueConvertible is adopted by Bool, Int, String, etc.
public protocol DatabaseValueConvertible : SQLExpressible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns a value initialized from *dbValue*, if possible.
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self?
}

// SQLExpressible adoption
extension DatabaseValueConvertible {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public var sqlExpression: SQLExpression {
        return databaseValue
    }
}


/// DatabaseValueConvertible comes with built-in methods that allow to fetch
/// cursors, arrays, or single values:
///
///     try String.fetchCursor(db, "SELECT name FROM ...", arguments:...) // DatabaseCursor<String>
///     try String.fetchAll(db, "SELECT name FROM ...", arguments:...)    // [String]
///     try String.fetchOne(db, "SELECT name FROM ...", arguments:...)    // String?
///
///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
///     try String.fetchCursor(statement, arguments:...) // DatabaseCursor<String>
///     try String.fetchAll(statement, arguments:...)    // [String]
///     try String.fetchOne(statement, arguments:...)    // String
///
/// DatabaseValueConvertible is adopted by Bool, Int, String, etc.
extension DatabaseValueConvertible {
    
    
    // MARK: Fetching From SelectStatement
    
    /// Returns a cursor over values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
    ///     let names = try String.fetchCursor(statement) // DatabaseCursor<String>
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
    public static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DatabaseCursor<Self> {
        // Reuse a single mutable row for performance
        let row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        return statement.cursor(arguments: arguments, next: {
            let dbValue: DatabaseValue = row[0]
            return dbValue.losslessConvert(sql: statement.sql, arguments: arguments) as Self
        })
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
    /// - returns: An array.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Self] {
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from a prepared statement.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
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
        // Reuse a single mutable row for performance
        let row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        let cursor: DatabaseCursor<Self?> = statement.cursor(arguments: arguments, next: {
            let dbValue: DatabaseValue = row[0]
            return dbValue.losslessConvert(sql: statement.sql, arguments: arguments) as Self?
        })
        return try cursor.next() ?? nil
    }
}

extension DatabaseValueConvertible {
    
    // MARK: Fetching From Request
    
    /// Returns a cursor over values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(nameColumn)
    ///     let names = try String.fetchCursor(db, request) // DatabaseCursor<String>
    ///     for let name = try names.next() { // String
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
    public static func fetchCursor(_ db: Database, _ request: Request) throws -> DatabaseCursor<Self> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    /// Returns an array of values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(nameColumn)
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
    ///     let request = Person.select(nameColumn)
    ///     let name = try String.fetchOne(db, request)   // String?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ request: Request) throws -> Self? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

extension DatabaseValueConvertible {

    // MARK: Fetching From SQL
    
    /// Returns a cursor over values fetched from an SQL query.
    ///
    ///     let names = try String.fetchCursor(db, "SELECT name FROM ...") // DatabaseCursor<String>
    ///     while let name = try name.next() { // String
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
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DatabaseCursor<Self> {
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
    /// - returns: An array.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Self] {
        return try fetchAll(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from an SQL query.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
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
///     try Optional<String>.fetchCursor(db, "SELECT name FROM ...", arguments:...) // DatabaseCursor<String?>
///     try Optional<String>.fetchAll(db, "SELECT name FROM ...", arguments:...)    // [String?]
///
///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
///     try Optional<String>.fetchCursor(statement, arguments:...) // DatabaseCursor<String?>
///     try Optional<String>.fetchAll(statement, arguments:...)    // [String?]
///
/// DatabaseValueConvertible is adopted by Bool, Int, String, etc.
extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From SelectStatement
    
    /// Returns a cursor over optional values fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT name FROM ...")
    ///     let names = try Optional<String>.fetchCursor(statement) // DatabaseCursor<String?>
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
    public static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DatabaseCursor<Wrapped?> {
        // Reuse a single mutable row for performance
        let row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        return statement.cursor(arguments: arguments, next: {
            let dbValue: DatabaseValue = row[0]
            return dbValue.losslessConvert(sql: statement.sql, arguments: arguments) as Wrapped?
        })
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

extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From Request
    
    /// Returns a cursor over optional values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(nameColumn)
    ///     let names = try Optional<String>.fetchCursor(db, request) // DatabaseCursor<String?>
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
    public static func fetchCursor(_ db: Database, _ request: Request) throws -> DatabaseCursor<Wrapped?> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    /// Returns an array of optional values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(nameColumn)
    ///     let names = try Optional<String>.fetchAll(db, request) // [String?]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: Request) throws -> [Wrapped?] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
}

extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From SQL
    
    /// Returns a cursor over optional values fetched from an SQL query.
    ///
    ///     let names = try Optional<String>.fetchCursor(db, "SELECT name FROM ...") // DatabaseCursor<String?>
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
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DatabaseCursor<Wrapped?> {
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
