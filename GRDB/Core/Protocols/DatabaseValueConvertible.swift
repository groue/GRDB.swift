// MARK: - DatabaseValueConvertible

/**
Types that adopt DatabaseValueConvertible can be initialized from database
values.

The protocol comes with built-in methods that allow to fetch lazy sequences,
arrays, or single instances:

    String.fetch(db, "SELECT name FROM ...", arguments:...)    // AnySequence<String?>
    String.fetchAll(db, "SELECT name FROM ...", arguments:...) // [String?]
    String.fetchOne(db, "SELECT name FROM ...", arguments:...) // String?
    
    let statement = db.selectStatement("SELECT name FROM ...")
    String.fetch(statement, arguments:...)           // AnySequence<String?>
    String.fetchAll(statement, arguments:...)        // [String?]
    String.fetchOne(statement, arguments:...)        // String?

DatabaseValueConvertible is adopted by Bool, Int, String, etc.
*/
public protocol DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Create an instance initialized to `databaseValue`.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self?
}


// MARK: - Fetching

/**
Types that adopt DatabaseValueConvertible can be initialized from database
values.

The protocol comes with built-in methods that allow to fetch lazy sequences,
arrays, or single instances:

    String.fetch(db, "SELECT name FROM ...", arguments:...)    // AnySequence<String?>
    String.fetchAll(db, "SELECT name FROM ...", arguments:...) // [String?]
    String.fetchOne(db, "SELECT name FROM ...", arguments:...) // String?
    
    let statement = db.selectStatement("SELECT name FROM ...")
    String.fetch(statement, arguments:...)           // AnySequence<String?>
    String.fetchAll(statement, arguments:...)        // [String?]
    String.fetchOne(statement, arguments:...)        // String?

DatabaseValueConvertible is adopted by Bool, Int, String, etc.
*/
public extension DatabaseValueConvertible {
    
    // MARK: - Fetching From SelectStatement
    
    /**
    Fetches a lazy sequence of DatabaseValueConvertible values.
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let names = String.fetch(statement) // AnySequence<String?>
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: A lazy sequence of values.
    */
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil) -> AnySequence<Self?> {
        let rowSequence = Row.fetch(statement, arguments: arguments)
        return AnySequence({
            let rowGenerator = rowSequence.generate()
            return anyGenerator {
                guard let row = rowGenerator.next() else {
                    return nil
                }
                return row.value(atIndex: 0)
            }
        } as () -> AnyGenerator<Self?>)
    }
    
    /**
    Fetches an array of DatabaseValueConvertible values.
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let names = String.fetchAll(statement)  // [String?]
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: An array of values.
    */
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil) -> [Self?] {
        return Array(fetch(statement, arguments: arguments))
    }
    
    /**
    Fetches a single DatabaseValueConvertible value
    
        let statement = db.selectStatement("SELECT name FROM ...")
        let name = String.fetchOne(statement)   // String?
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: An optional value.
    */
    public static func fetchOne(statement: SelectStatement, arguments: StatementArguments? = nil) -> Self? {
        guard let value = fetch(statement, arguments: arguments).generate().next() else {
            return nil
        }
        return value
    }
    
    
    // MARK: - Fetching From Database
    
    /**
    Fetches a lazy sequence of DatabaseValueConvertible values.
    
        let names = String.fetch(db, "SELECT name FROM ...") // AnySequence<String?>
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: A lazy sequence of values.
    */
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> AnySequence<Self?> {
        return self.fetch(db.selectStatement(sql), arguments: arguments)
    }
    
    /**
    Fetches an array of DatabaseValueConvertible values.
    
        let names = String.fetchAll(db, "SELECT name FROM ...") // [String?]
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: An array of values.
    */
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> [Self?] {
        return Array(fetch(db, sql, arguments: arguments))
    }
    
    /**
    Fetches a single DatabaseValueConvertible value.
    
        let name = String.fetchOne(db, "SELECT name FROM ...") // String?
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: An optional value.
    */
    public static func fetchOne(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> Self? {
        guard let value = fetch(db, sql, arguments: arguments).generate().next() else {
            return nil
        }
        return value
    }
}
