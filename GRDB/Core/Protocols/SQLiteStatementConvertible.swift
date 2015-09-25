/**
When a type adopts both DatabaseValueConvertible and SQLiteStatementConvertible, it is granted
with faster access to the SQLite database values.
*/
public protocol SQLiteStatementConvertible {
    
    /**
    Returns an instance initialized from a raw SQLite statement pointer.
    
    As an example, here is the how Int64 adopts SQLiteStatementConvertible:
    
        extension Int64: SQLiteStatementConvertible {
            public init(sqliteStatement: SQLiteStatement, index: Int32) {
                self = sqlite3_column_int64(sqliteStatement, index)
            }
        }
    
    Implement this method in an optimistic mind: don't check for NULL, don't
    check for type mismatch.
    
    See https://www.sqlite.org/c3ref/column_blob.html for more information.
    
    - parameter sqliteStatement: A pointer to a SQLite statement.
    - parameter index: The column index.
    */
    init(sqliteStatement: SQLiteStatement, index: Int32)
}


// MARK: - Fetching non null SQLiteStatementConvertible

/**
Types that adopt both DatabaseValueConvertible and SQLiteStatementConvertible
can be efficiently initialized from database values.

See DatabaseValueConvertible for more information.
*/
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
