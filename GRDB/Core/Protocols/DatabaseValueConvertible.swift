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
public protocol DatabaseValueConvertible : RowConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    ///
    /// - parameter databaseValue: A DatabaseValue.
    /// - returns: An optional Self.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self?
}

/// DatabaseValueConvertible adopts RowConvertible
public extension DatabaseValueConvertible {
    
    /// Returns the value initialized from the leftmost column of the row.
    static func fromRow(row: Row) -> Self {
        return row.databaseValues.first!.value()
    }
}


// MARK: - Fetching DatabaseValueConvertible

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
    
    /// Returns a single value fetched from a prepared statement.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let statement = db.selectStatement("SELECT name FROM ...")
    ///     let name = String.fetchOne(statement)   // String?
    ///
    /// - parameter statement: The statement to run.
    /// - parameter arguments: Statement arguments.
    /// - returns: An optional value.
    public static func fetchOne(statement: SelectStatement, arguments: StatementArguments = StatementArguments.Default) -> Self? {
        let sequence: DatabaseSequence<Self?> = statement.fetch(arguments: arguments) {
            fromDatabaseValue(DatabaseValue(sqliteStatement: statement.sqliteStatement, index: 0))
        }
        var generator = sequence.generate()
        if let value = generator.next() {   // Unwrap Self? from Self??
            return value
        }
        return nil
    }
    
    
    // MARK: - Fetching From Database
    
    /// Returns a single value fetched from an SQL query.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let name = String.fetchOne(db, "SELECT name FROM ...") // String?
    ///
    /// - parameter db: A Database.
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Statement arguments.
    /// - returns: An optional value.
    public static func fetchOne(db: Database, _ sql: String, arguments: StatementArguments = StatementArguments.Default) -> Self? {
        return fetchOne(db.selectStatement(sql), arguments: arguments)
    }
}


// MARK: - Fetching optional DatabaseValueConvertible

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
    /// - parameter statement: The statement to run.
    /// - parameter arguments: Statement arguments.
    /// - returns: A sequence of optional values.
    public static func fetch(statement: SelectStatement, arguments: StatementArguments = StatementArguments.Default) -> DatabaseSequence<Wrapped?> {
        let sqliteStatement = statement.sqliteStatement
        return statement.fetch(arguments: arguments) {
            Wrapped.fromDatabaseValue(DatabaseValue(sqliteStatement: sqliteStatement, index: 0))
        }
    }
    
    /// Returns an array of optional values fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT name FROM ...")
    ///     let names = Optional<String>.fetchAll(statement)  // [String?]
    ///
    /// - parameter statement: The statement to run.
    /// - parameter arguments: Statement arguments.
    /// - returns: An array of optional values.
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments = StatementArguments.Default) -> [Wrapped?] {
        return Array(fetch(statement, arguments: arguments))
    }
    
    
    // MARK: - Fetching From Database
    
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
    /// - parameter arguments: Statement arguments.
    /// - returns: A sequence of optional values.
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments = StatementArguments.Default) -> DatabaseSequence<Wrapped?> {
        return fetch(db.selectStatement(sql), arguments: arguments)
    }
    
    /// Returns an array of optional values fetched from an SQL query.
    ///
    ///     let names = String.fetchAll(db, "SELECT name FROM ...") // [String?]
    ///
    /// - parameter db: A Database.
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Statement arguments.
    /// - returns: An array of optional values.
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments = StatementArguments.Default) -> [Wrapped?] {
        return fetchAll(db.selectStatement(sql), arguments: arguments)
    }
}
