/// Types that adopt RowConvertible can be initialized from a database Row.
///
///     let row = try Row.fetchOne(db, "SELECT ...")!
///     let person = Person(row)
///
/// The protocol comes with built-in methods that allow to fetch cursors,
/// arrays, or single records:
///
///     try Person.fetchCursor(db, "SELECT ...", arguments:...) // DatabaseCursor<Person>
///     try Person.fetchAll(db, "SELECT ...", arguments:...)    // [Person]
///     try Person.fetchOne(db, "SELECT ...", arguments:...)    // Person?
///
///     let statement = try db.makeSelectStatement("SELECT ...")
///     try Person.fetchCursor(statement, arguments:...) // DatabaseCursor<Person>
///     try Person.fetchAll(statement, arguments:...)    // [Person]
///     try Person.fetchOne(statement, arguments:...)    // Person?
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

extension RowConvertible {
    
    // MARK: Fetching From SelectStatement
    
    /// A cursor over records fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT * FROM persons")
    ///     let persons = try Person.fetchCursor(statement) // DatabaseCursor<Person>
    ///     while let person = try persons.next() { // Person
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
    public static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DatabaseCursor<Self> {
        // Reuse a single mutable row for performance.
        // It is the record's responsibility to copy the row if needed.
        let row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        return statement.cursor(arguments: arguments, next: { self.init(row: row) })
    }
    
    /// Returns an array of records fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT * FROM persons")
    ///     let persons = try Person.fetchAll(statement) // [Person]
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
    ///     let statement = try db.makeSelectStatement("SELECT * FROM persons")
    ///     let person = try Person.fetchOne(statement) // Person?
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
    ///     let request = Person.order(nameColumn)
    ///     let identities = try Identity.fetchCursor(db, request) // DatabaseCursor<Identity>
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
    public static func fetchCursor(_ db: Database, _ request: Request) throws -> DatabaseCursor<Self> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    /// Returns an array of records fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
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
    ///     let request = Person.order(nameColumn)
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
    ///     let persons = try Person.fetchCursor(db, "SELECT * FROM persons") // DatabaseCursor<Person>
    ///     while let person = try persons.next() { // Person
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
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DatabaseCursor<Self> {
        return try fetchCursor(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of records fetched from an SQL query.
    ///
    ///     let persons = try Person.fetchAll(db, "SELECT * FROM persons") // [Person]
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
    ///     let person = try Person.fetchOne(db, "SELECT * FROM persons") // Person?
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
