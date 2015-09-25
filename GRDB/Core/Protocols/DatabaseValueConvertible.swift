// MARK: - DatabaseValueConvertible

/**
Types that adopt DatabaseValueConvertible can be initialized from database
values.

The protocol comes with built-in methods that allow to fetch sequences, arrays,
or single instances:

    String.fetch(db, "SELECT name FROM ...", arguments:...)    // DatabaseSequence<String?>
    String.fetchAll(db, "SELECT name FROM ...", arguments:...) // [String?]
    String.fetchOne(db, "SELECT name FROM ...", arguments:...) // String?
    
    let statement = db.selectStatement("SELECT name FROM ...")
    String.fetch(statement, arguments:...)           // DatabaseSequence<String?>
    String.fetchAll(statement, arguments:...)        // [String?]
    String.fetchOne(statement, arguments:...)        // String?

DatabaseValueConvertible is adopted by Bool, Int, String, etc.
*/
public protocol DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /**
    Returns an instance initialized from *databaseValue*, if possible.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional Self.
    */
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self?
}


// MARK: - Fetching optional DatabaseValueConvertible

/**
Types that adopt DatabaseValueConvertible can be initialized from database
values.

The protocol comes with built-in methods that allow to fetch sequences, arrays,
or single instances:

    String.fetch(db, "SELECT name FROM ...", arguments:...)    // DatabaseSequence<String>
    String.fetchAll(db, "SELECT name FROM ...", arguments:...) // [String]

    let statement = db.selectStatement("SELECT name FROM ...")
    String.fetch(statement, arguments:...)           // DatabaseSequence<String>
    String.fetchAll(statement, arguments:...)        // [String]

DatabaseValueConvertible is adopted by Bool, Int, String, etc.
*/
extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: - Fetching From SelectStatement
    
    /**
    Fetches a sequence of optional values.
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let names = Optional<String>.fetch(statement) // DatabaseSequence<String?>
    
    The returned sequence can be consumed several times, but it may yield
    different results, should database changes have occurred between two
    generations:
    
        let names = Optional<String>.fetch(statement)
        Array(names) // Arthur, Barbara
        db.execute("DELETE ...")
        Array(names) // Arthur
    
    If the database is modified while the sequence is iterating, the remaining
    elements are undefined.
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: A sequence of optional values.
    */
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil) -> DatabaseSequence<Wrapped?> {
        let sqliteStatement = statement.sqliteStatement
        return statement.fetch(arguments: arguments) {
            Wrapped.fromDatabaseValue(DatabaseValue(sqliteStatement: sqliteStatement, index: 0))
        }
    }
    
    /**
    Fetches an array of optional values.
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let names = Optional<String>.fetchAll(statement)  // [String?]
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: An array of optional values.
    */
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil) -> [Wrapped?] {
        return Array(fetch(statement, arguments: arguments))
    }
    
    
    // MARK: - Fetching From Database
    
    /**
    Fetches a sequence of optional values.
    
        let names = Optional<String>.fetch(db, "SELECT name FROM ...") // DatabaseSequence<String?>
    
    The returned sequence can be consumed several times, but it may yield
    different results, should database changes have occurred between two
    generations:
    
        let names = Optional<String>.fetch(db, "SELECT name FROM ...")
        Array(names) // Arthur, Barbara
        db.execute("DELETE ...")
        Array(names) // Arthur
    
    If the database is modified while the sequence is iterating, the remaining
    elements are undefined.
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: A sequence of optional values.
    */
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> DatabaseSequence<Wrapped?> {
        return fetch(db.selectStatement(sql), arguments: arguments)
    }
    
    /**
    Fetches an array of optional values.
    
        let names = String.fetchAll(db, "SELECT name FROM ...") // [String?]
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: An array of optional values.
    */
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> [Wrapped?] {
        return fetchAll(db.selectStatement(sql), arguments: arguments)
    }
}


// MARK: - Fetching non null DatabaseValueConvertible

/**
Types that adopt DatabaseValueConvertible can be initialized from database
values.

The protocol comes with built-in methods that allow to fetch sequences, arrays,
or single instances:

    String.fetch(db, "SELECT name FROM ...", arguments:...)    // DatabaseSequence<String>
    String.fetchAll(db, "SELECT name FROM ...", arguments:...) // [String]
    String.fetchOne(db, "SELECT name FROM ...", arguments:...) // String
    
    let statement = db.selectStatement("SELECT name FROM ...")
    String.fetch(statement, arguments:...)           // DatabaseSequence<String>
    String.fetchAll(statement, arguments:...)        // [String]
    String.fetchOne(statement, arguments:...)        // String

DatabaseValueConvertible is adopted by Bool, Int, String, etc.
*/
public extension DatabaseValueConvertible {
    
    // MARK: - Fetching From SelectStatement
    
    /**
    Fetches a sequence of non null values.
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let names = String.fetch(statement) // DatabaseSequence<String>
    
    The returned sequence can be consumed several times, but it may yield
    different results, should database changes have occurred between two
    generations:
    
        let names = String.fetch(statement)
        Array(names) // Arthur, Barbara
        db.execute("DELETE ...")
        Array(names) // Arthur
    
    If the database is modified while the sequence is iterating, the remaining
    elements are undefined.
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: A sequence of non null values.
    */
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil) -> DatabaseSequence<Self> {
        let sqliteStatement = statement.sqliteStatement
        return statement.fetch(arguments: arguments) {
            guard let value = Self.fromDatabaseValue(DatabaseValue(sqliteStatement: sqliteStatement, index: 0)) else {
                if let arguments = statement.arguments {
                    fatalError("Found NULL \(Self.self) while iterating `\(statement.sql)` with arguments \(arguments).")
                } else {
                    fatalError("Found NULL \(Self.self) while iterating `\(statement.sql)`.")
                }
            }
            return value
        }
    }
    
    /**
    Fetches an array of non null values.
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let names = String.fetchAll(statement)  // [String]
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: An array of non null values.
    */
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil) -> [Self] {
        return Array(fetch(statement, arguments: arguments))
    }
    
    /**
    Fetches a single value.
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let name = String.fetchOne(statement)   // String?
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: An optional value.
    */
    public static func fetchOne(statement: SelectStatement, arguments: StatementArguments? = nil) -> Self? {
        let optionals = statement.fetch(arguments: arguments) {
            Self.fromDatabaseValue(DatabaseValue(sqliteStatement: statement.sqliteStatement, index: 0))
        }
        guard let value = optionals.generate().next() else {
            return nil
        }
        return value
    }
    
    
    // MARK: - Fetching From Database
    
    /**
    Fetches a sequence of non null values.
    
        let names = String.fetch(db, "SELECT name FROM ...") // DatabaseSequence<String>
    
    The returned sequence can be consumed several times, but it may yield
    different results, should database changes have occurred between two
    generations:
    
        let names = String.fetch(db, "SELECT name FROM ...")
        Array(names) // Arthur, Barbara
        db.execute("DELETE ...")
        Array(names) // Arthur
    
    If the database is modified while the sequence is iterating, the remaining
    elements are undefined.
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: A sequence of non null values.
    */
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> DatabaseSequence<Self> {
        return fetch(db.selectStatement(sql), arguments: arguments)
    }
    
    /**
    Fetches an array of non null values.
    
        let names = String.fetchAll(db, "SELECT name FROM ...") // [String]
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: An array of non null values.
    */
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> [Self] {
        return fetchAll(db.selectStatement(sql), arguments: arguments)
    }
    
    /**
    Fetches a single value.
    
        let name = String.fetchOne(db, "SELECT name FROM ...") // String?
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: An optional value.
    */
    public static func fetchOne(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> Self? {
        return fetchOne(db.selectStatement(sql), arguments: arguments)
    }
}


// MARK: - Fetching DatabaseValueConvertible + SQLiteStatementConvertible

public extension DatabaseValueConvertible where Self: SQLiteStatementConvertible {
    
    // MARK: - Fetching From SelectStatement
    
    /**
    This method is an optimized specialization of
    DatabaseValueConvertible.fetch(_,arguments:) for types that adopt both
    DatabaseValueConvertible and SQLiteStatementConvertible protocols.
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let names = String.fetch(statement) // DatabaseSequence<String>
    
    See the documentation of DatabaseValueConvertible.fetch(_,arguments:) for
    more information.
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: A sequence of non null values.
    */
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil) -> DatabaseSequence<Self> {
        return statement.fetch(arguments: arguments) {
            let sqliteStatement = statement.sqliteStatement
            if sqlite3_column_type(sqliteStatement, 0) == SQLITE_NULL {
                if let arguments = statement.arguments {
                    fatalError("Found NULL \(Self.self) while iterating `\(statement.sql)` with arguments \(arguments).")
                } else {
                    fatalError("Found NULL \(Self.self) while iterating `\(statement.sql)`.")
                }
            } else {
                return Self.init(sqliteStatement: sqliteStatement, index: 0)
            }
        }
    }
    
    /**
    This method is an optimized specialization of
    DatabaseValueConvertible.fetchAll(_,arguments:) for types that adopt both
    DatabaseValueConvertible and SQLiteStatementConvertible protocols.
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let names = String.fetchAll(statement)  // [String]
    
    See the documentation of DatabaseValueConvertible.fetchAll(_,arguments:) for
    more information.
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: An array of non null values.
    */
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil) -> [Self] {
        return Array(fetch(statement, arguments: arguments))
    }
    
    /**
    This method is an optimized specialization of
    DatabaseValueConvertible.fetchOne(_,arguments:) for types that adopt both
    DatabaseValueConvertible and SQLiteStatementConvertible protocols.
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let name = String.fetchOne(statement)   // String?
    
    See the documentation of DatabaseValueConvertible.fetchOne(_,arguments:) for
    more information.
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: An optional value.
    */
    public static func fetchOne(statement: SelectStatement, arguments: StatementArguments? = nil) -> Self? {
        let optionals = statement.fetch(arguments: arguments) {
            Self.fromDatabaseValue(DatabaseValue(sqliteStatement: statement.sqliteStatement, index: 0))
        }
        guard let value = optionals.generate().next() else {
            return nil
        }
        return value
    }
    
    
    // MARK: - Fetching From Database
    
    /**
    This method is an optimized specialization of
    DatabaseValueConvertible.fetch(_,sql:,arguments:) for types that adopt both
    DatabaseValueConvertible and SQLiteStatementConvertible protocols.
    
        let names = String.fetch(db, "SELECT name FROM ...") // DatabaseSequence<String>
    
    See the documentation of DatabaseValueConvertible.fetch(_,sql:,arguments:)
    for more information.
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: A sequence of non null values.
    */
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> DatabaseSequence<Self> {
        return fetch(db.selectStatement(sql), arguments: arguments)
    }
    
    /**
    This method is an optimized specialization of
    DatabaseValueConvertible.fetchAll(_,sql:,arguments:) for types that adopt
    both DatabaseValueConvertible and SQLiteStatementConvertible protocols.
    
        let names = String.fetchAll(db, "SELECT name FROM ...") // [String?]
    
    See the documentation of DatabaseValueConvertible.fetchAll(_,sql:,arguments:)
    for more information.
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: An array of non null values.
    */
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> [Self] {
        return fetchAll(db.selectStatement(sql), arguments: arguments)
    }
    
    /**
    This method is an optimized specialization of
    DatabaseValueConvertible.fetchOne(_,sql:,arguments:) for types that adopt
    both DatabaseValueConvertible and SQLiteStatementConvertible protocols.
    
        let name = String.fetchOne(db, "SELECT name FROM ...") // String?
    
    See the documentation of DatabaseValueConvertible.fetchOne(_,sql:,arguments:)
    for more information.
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: An optional value.
    */
    public static func fetchOne(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> Self? {
        return fetchOne(db.selectStatement(sql), arguments: arguments)
    }
}
