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
public protocol DatabaseValueConvertible : _SQLExpressionType {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self?
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
    
    
    // MARK: - Fetching From SelectStatement
    
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
    /// - returns: A sequence.
    @warn_unused_result
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil) -> DatabaseSequence<Self> {
        let sqliteStatement = statement.sqliteStatement
        return statement.fetchSequence(arguments: arguments) {
            DatabaseValue(sqliteStatement: sqliteStatement, index: 0).value()
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
    /// - returns: An array.
    @warn_unused_result
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil) -> [Self] {
        return Array(fetch(statement, arguments: arguments))
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
    /// - returns: An optional value.
    @warn_unused_result
    public static func fetchOne(statement: SelectStatement, arguments: StatementArguments? = nil) -> Self? {
        let sequence = statement.fetchSequence(arguments: arguments) {
            fromDatabaseValue(DatabaseValue(sqliteStatement: statement.sqliteStatement, index: 0))
        }
        if let value = sequence.generate().next() {
            return value
        }
        return nil
    }
    
    
    // MARK: - Fetching From SQL
    
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
    /// - returns: A sequence.
    @warn_unused_result
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> DatabaseSequence<Self> {
        return fetch(try! db.selectStatement(sql), arguments: arguments)
    }
    
    /// Returns an array of values fetched from an SQL query.
    ///
    ///     let names = String.fetchAll(db, "SELECT name FROM ...") // [String]
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    /// - returns: An array.
    @warn_unused_result
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> [Self] {
        return fetchAll(try! db.selectStatement(sql), arguments: arguments)
    }
    
    /// Returns a single value fetched from an SQL query.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let name = String.fetchOne(db, "SELECT name FROM ...") // String?
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    /// - returns: An optional value.
    @warn_unused_result
    public static func fetchOne(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> Self? {
        return fetchOne(try! db.selectStatement(sql), arguments: arguments)
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
    
    
    // MARK: - Fetching From SelectStatement
    
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
    /// - returns: A sequence of optional values.
    @warn_unused_result
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil) -> DatabaseSequence<Wrapped?> {
        let sqliteStatement = statement.sqliteStatement
        return statement.fetchSequence(arguments: arguments) {
            Wrapped.fromDatabaseValue(DatabaseValue(sqliteStatement: sqliteStatement, index: 0))
        }
    }
    
    /// Returns an array of optional values fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT name FROM ...")
    ///     let names = Optional<String>.fetchAll(statement)  // [String?]
    ///
    /// - parameter statement: The statement to run.
    /// - parameter arguments: Optional statement arguments.
    /// - returns: An array of optional values.
    @warn_unused_result
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil) -> [Wrapped?] {
        return Array(fetch(statement, arguments: arguments))
    }
    
    
    // MARK: - Fetching From SQL
    
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
    /// - parameter db: A Database.
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Optional statement arguments.
    /// - returns: A sequence of optional values.
    @warn_unused_result
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> DatabaseSequence<Wrapped?> {
        return fetch(try! db.selectStatement(sql), arguments: arguments)
    }
    
    /// Returns an array of optional values fetched from an SQL query.
    ///
    ///     let names = String.fetchAll(db, "SELECT name FROM ...") // [String?]
    ///
    /// - parameter db: A Database.
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Optional statement arguments.
    /// - returns: An array of optional values.
    @warn_unused_result
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> [Wrapped?] {
        return fetchAll(try! db.selectStatement(sql), arguments: arguments)
    }
}
