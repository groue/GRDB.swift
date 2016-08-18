// MARK: - SQLExpressible

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SQLExpressible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    var sqlExpression: _SQLExpression { get }
}

/// The protocol for all types that can be turned into an SQL expression.
///
/// It is adopted by protocols like DatabaseValueConvertible, and types
/// like Column.
///
/// Do not declare adoption of SQLExpressible on any type: you would have to
/// use semi-private APIs and types, whose name start with an underscore, that
/// are subject to change as GRDB evolves.
public protocol SQLExpressible : _SQLExpressible {
}


// MARK: - DatabaseValueConvertible

/// Types that adopt DatabaseValueConvertible can be initialized from
/// database values.
///
/// The protocol comes with built-in methods that allow to fetch sequences,
/// arrays, or single values:
///
///     String.fetch(db, "SELECT name FROM ...", arguments:...)    // DatabaseSequence<String?>
///     String.fetchAll(db, "SELECT name FROM ...", arguments:...) // [String?]
///     String.fetchOne(db, "SELECT name FROM ...", arguments:...) // String?
///
///     let statement = db.selectStatement("SELECT name FROM ...")
///     String.fetch(statement, arguments:...)           // DatabaseSequence<String?>
///     String.fetchAll(statement, arguments:...)        // [String?]
///     String.fetchOne(statement, arguments:...)        // String?
///
/// DatabaseValueConvertible is adopted by Bool, Int, String, etc.
public protocol DatabaseValueConvertible : SQLExpressible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self?
}


// SQLExpressible adoption
extension DatabaseValueConvertible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var sqlExpression: _SQLExpression {
        return .Value(databaseValue)
    }
}


/// DatabaseValueConvertible comes with built-in methods that allow to fetch
/// sequences, arrays, or single values:
///
///     String.fetch(db, "SELECT name FROM ...", arguments:...)    // DatabaseSequence<String>
///     String.fetchAll(db, "SELECT name FROM ...", arguments:...) // [String]
///     String.fetchOne(db, "SELECT name FROM ...", arguments:...) // String
///
///     let statement = db.selectStatement("SELECT name FROM ...")
///     String.fetch(statement, arguments:...)           // DatabaseSequence<String>
///     String.fetchAll(statement, arguments:...)        // [String]
///     String.fetchOne(statement, arguments:...)        // String
///
/// DatabaseValueConvertible is adopted by Bool, Int, String, etc.
public extension DatabaseValueConvertible {
    
    
    // MARK: Fetching From SelectStatement
    
    /// Returns a sequence of values fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT name FROM ...")
    ///     let names = String.fetch(statement) // DatabaseSequence<String>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = String.fetch(statement)
    ///     Array(names) // Arthur, Barbara
    ///     db.execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A sequence.
    @warn_unused_result
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> DatabaseSequence<Self> {
        let row = try! Row(statement: statement).adaptedRow(adapter: adapter, statement: statement)
        return statement.fetchSequence(arguments: arguments) {
            row.value(atIndex: 0)
        }
    }
    
    /// Returns an array of values fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT name FROM ...")
    ///     let names = String.fetchAll(statement)  // [String]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array.
    @warn_unused_result
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> [Self] {
        return Array(fetch(statement, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from a prepared statement.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let statement = db.selectStatement("SELECT name FROM ...")
    ///     let name = String.fetchOne(statement)   // String?
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional value.
    @warn_unused_result
    public static func fetchOne(statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Self? {
        let row = try! Row(statement: statement).adaptedRow(adapter: adapter, statement: statement)
        let sequence = statement.fetchSequence(arguments: arguments) {
            row.value(atIndex: 0) as Self?
        }
        if let value = sequence.generate().next() {
            return value
        }
        return nil
    }
}


extension DatabaseValueConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of values fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn)
    ///     let names = String.fetch(db, request) // DatabaseSequence<String>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = String.fetch(db, request)
    ///     Array(names) // Arthur, Barbara
    ///     db.execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public static func fetch(db: Database, _ request: FetchRequest) -> DatabaseSequence<Self> {
        let (statement, adapter) = try! request.prepare(db)
        return fetch(statement, adapter: adapter)
    }
    
    /// Returns an array of values fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn)
    ///     let names = String.fetchAll(db, request)  // [String]
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchAll(db: Database, _ request: FetchRequest) -> [Self] {
        let (statement, adapter) = try! request.prepare(db)
        return fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single value fetched from a fetch request.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn)
    ///     let name = String.fetchOne(db, request)   // String?
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchOne(db: Database, _ request: FetchRequest) -> Self? {
        let (statement, adapter) = try! request.prepare(db)
        return fetchOne(statement, adapter: adapter)
    }
}


extension DatabaseValueConvertible {

    // MARK: Fetching From SQL
    
    /// Returns a sequence of values fetched from an SQL query.
    ///
    ///     let names = String.fetch(db, "SELECT name FROM ...") // DatabaseSequence<String>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = String.fetch(db, "SELECT name FROM ...")
    ///     Array(names) // Arthur, Barbara
    ///     execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A sequence.
    @warn_unused_result
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> DatabaseSequence<Self> {
        return fetch(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of values fetched from an SQL query.
    ///
    ///     let names = String.fetchAll(db, "SELECT name FROM ...") // [String]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array.
    @warn_unused_result
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> [Self] {
        return fetchAll(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from an SQL query.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let name = String.fetchOne(db, "SELECT name FROM ...") // String?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional value.
    @warn_unused_result
    public static func fetchOne(db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Self? {
        return fetchOne(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}


/// Swift's Optional comes with built-in methods that allow to fetch sequences
/// and arrays of optional DatabaseValueConvertible:
///
///     Optional<String>.fetch(db, "SELECT name FROM ...", arguments:...)    // DatabaseSequence<String?>
///     Optional<String>.fetchAll(db, "SELECT name FROM ...", arguments:...) // [String?]
///
///     let statement = db.selectStatement("SELECT name FROM ...")
///     Optional<String>.fetch(statement, arguments:...)           // DatabaseSequence<String?>
///     Optional<String>.fetchAll(statement, arguments:...)        // [String?]
///
/// DatabaseValueConvertible is adopted by Bool, Int, String, etc.
public extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From SelectStatement
    
    /// Returns a sequence of optional values fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT name FROM ...")
    ///     let names = Optional<String>.fetch(statement) // DatabaseSequence<String?>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = Optional<String>.fetch(statement)
    ///     Array(names) // Arthur, Barbara
    ///     db.execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A sequence of optional values.
    @warn_unused_result
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> DatabaseSequence<Wrapped?> {
        let row = try! Row(statement: statement).adaptedRow(adapter: adapter, statement: statement)
        return statement.fetchSequence(arguments: arguments) {
            row.value(atIndex: 0) as Wrapped?
        }
    }
    
    /// Returns an array of optional values fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT name FROM ...")
    ///     let names = Optional<String>.fetchAll(statement)  // [String?]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of optional values.
    @warn_unused_result
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> [Wrapped?] {
        return Array(fetch(statement, arguments: arguments, adapter: adapter))
    }
}


extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of optional values fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn)
    ///     let names = Optional<String>.fetch(db, request) // DatabaseSequence<String?>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = Optional<String>.fetch(db, request)
    ///     Array(names) // Arthur, Barbara
    ///     db.execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public static func fetch(db: Database, _ request: FetchRequest) -> DatabaseSequence<Wrapped?> {
        let (statement, adapter) = try! request.prepare(db)
        return fetch(statement, adapter: adapter)
    }
    
    /// Returns an array of optional values fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn)
    ///     let names = Optional<String>.fetchAll(db, request)  // [String?]
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchAll(db: Database, _ request: FetchRequest) -> [Wrapped?] {
        let (statement, adapter) = try! request.prepare(db)
        return fetchAll(statement, adapter: adapter)
    }
}


extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From SQL
    
    /// Returns a sequence of optional values fetched from an SQL query.
    ///
    ///     let names = Optional<String>.fetch(db, "SELECT name FROM ...") // DatabaseSequence<String?>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = Optional<String>.fetch(db, "SELECT name FROM ...")
    ///     Array(names) // Arthur, Barbara
    ///     db.execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A sequence of optional values.
    @warn_unused_result
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> DatabaseSequence<Wrapped?> {
        return fetch(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of optional values fetched from an SQL query.
    ///
    ///     let names = String.fetchAll(db, "SELECT name FROM ...") // [String?]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - parameter arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of optional values.
    @warn_unused_result
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> [Wrapped?] {
        return fetchAll(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}
