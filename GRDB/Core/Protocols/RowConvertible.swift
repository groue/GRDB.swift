/// Types that adopt RowConvertible can be initialized from a database Row.
///
///     let row = Row.fetchOne(db, "SELECT ...")!
///     let person = Person(row)
///
/// The protocol comes with built-in methods that allow to fetch sequences,
/// arrays, or single values:
///
///     Person.fetch(db, "SELECT ...", arguments:...)    // DatabaseSequence<Person>
///     Person.fetchAll(db, "SELECT ...", arguments:...) // [Person]
///     Person.fetchOne(db, "SELECT ...", arguments:...) // Person?
///
///     let statement = db.selectStatement("SELECT ...")
///     Person.fetch(statement, arguments:...)           // DatabaseSequence<Person>
///     Person.fetchAll(statement, arguments:...)        // [Person]
///     Person.fetchOne(statement, arguments:...)        // Person?
///
/// RowConvertible is adopted by Record.
public protocol RowConvertible {
    
    /// Initializes a value from `row`.
    ///
    /// For performance reasons, the row argument may be reused during the
    /// iteration of a fetch query. If you want to keep the row for later use,
    /// make sure to store a copy: `self.row = row.copy()`.
    init(_ row: Row)
    
    /// Do not call this method directly.
    ///
    /// Types that adopt RowConvertible have an opportunity to complete their
    /// initialization.
    mutating func awakeFromFetch(row row: Row, database: Database)
}

extension RowConvertible {
    
    /// Default implementation, which does nothing.
    public func awakeFromFetch(row row: Row, database: Database) { }

    
    // MARK: - Fetching From SelectStatement
    
    /// Returns a sequence of records fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT * FROM persons")
    ///     let persons = Person.fetch(statement) // DatabaseSequence<Person>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let persons = Person.fetch(statement)
    ///     Array(persons).count // 3
    ///     db.execute("DELETE ...")
    ///     Array(persons).count // 2
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    /// - returns: A sequence of records.
    @warn_unused_result
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil) -> DatabaseSequence<Self> {
        let row = Row(statement: statement)
        let database = statement.database
        return statement.fetchSequence(arguments: arguments) {
            var value = self.init(row)
            value.awakeFromFetch(row: row, database: database)
            return value
        }
    }
    
    /// Returns an array of records fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT * FROM persons")
    ///     let persons = Person.fetchAll(statement) // [Person]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    /// - returns: An array of records.
    @warn_unused_result
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil) -> [Self] {
        return Array(fetch(statement, arguments: arguments))
    }
    
    /// Returns a single record fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT * FROM persons")
    ///     let person = Person.fetchOne(statement) // Person?
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    /// - returns: An optional record.
    @warn_unused_result
    public static func fetchOne(statement: SelectStatement, arguments: StatementArguments? = nil) -> Self? {
        return fetch(statement, arguments: arguments).generate().next()
    }
    
    
    // MARK: - Fetching From SQL
    
    /// Returns a sequence of records fetched from an SQL query.
    ///
    ///     let persons = Person.fetch(db, "SELECT * FROM persons") // DatabaseSequence<Person>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let persons = Person.fetch(db, "SELECT * FROM persons")
    ///     Array(persons).count // 3
    ///     db.execute("DELETE ...")
    ///     Array(persons).count // 2
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    /// - returns: A sequence of records.
    @warn_unused_result
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> DatabaseSequence<Self> {
        return fetch(try! db.selectStatement(sql), arguments: arguments)
    }
    
    /// Returns an array of records fetched from an SQL query.
    ///
    ///     let persons = Person.fetchAll(db, "SELECT * FROM persons") // [Person]
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    /// - returns: An array of records.
    @warn_unused_result
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> [Self] {
        return fetchAll(try! db.selectStatement(sql), arguments: arguments)
    }
    
    /// Returns a single record fetched from an SQL query.
    ///
    ///     let person = Person.fetchOne(db, "SELECT * FROM persons") // Person?
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    /// - returns: An optional record.
    @warn_unused_result
    public static func fetchOne(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> Self? {
        return fetchOne(try! db.selectStatement(sql), arguments: arguments)
    }
}
