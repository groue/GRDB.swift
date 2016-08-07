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
///     let statement = db.makeSelectStatement("SELECT ...")
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
    init(row: Row)
    
    /// Do not call this method directly.
    ///
    /// This method is called in an arbitrary dispatch queue, after a record
    /// has been fetched from the database.
    ///
    /// Types that adopt RowConvertible have an opportunity to complete their
    /// initialization.
    mutating func awakeFromFetch(row: Row)
}


extension RowConvertible {
    
    /// Default implementation, which does nothing.
    public func awakeFromFetch(row: Row) { }

    
    // MARK: Fetching From SelectStatement
    
    /// Returns a sequence of records fetched from a prepared statement.
    ///
    ///     let statement = db.makeSelectStatement("SELECT * FROM persons")
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
    ///     - adapter: Optional RowAdapter
    /// - returns: A sequence of records.
    public static func fetch(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> DatabaseSequence<Self> {
        let row = try! Row(statement: statement).adaptedRow(adapter: adapter, statement: statement)
        return statement.fetchSequence(arguments: arguments) {
            var value = self.init(row: row)
            value.awakeFromFetch(row: row)
            return value
        }
    }
    
    /// Returns an array of records fetched from a prepared statement.
    ///
    ///     let statement = db.makeSelectStatement("SELECT * FROM persons")
    ///     let persons = Person.fetchAll(statement) // [Person]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of records.
    public static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> [Self] {
        return Array(fetch(statement, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single record fetched from a prepared statement.
    ///
    ///     let statement = db.makeSelectStatement("SELECT * FROM persons")
    ///     let person = Person.fetchOne(statement) // Person?
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional record.
    public static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Self? {
        return fetch(statement, arguments: arguments, adapter: adapter).makeIterator().next()
    }
}


extension RowConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of records fetched from a fetch request.
    ///
    ///     let nameColumn = Column("firstName")
    ///     let request = Person.order(nameColumn)
    ///     let identities = Identity.fetch(db, request) // DatabaseSequence<Identity>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let identities = Identity.fetch(db, request)
    ///     Array(identities).count // 3
    ///     db.execute("DELETE ...")
    ///     Array(identities).count // 2
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    public static func fetch(_ db: Database, _ request: FetchRequest) -> DatabaseSequence<Self> {
        let (statement, adapter) = try! request.prepare(db)
        return fetch(statement, adapter: adapter)
    }
    
    /// Returns an array of records fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
    ///     let identities = Identity.fetchAll(db, request) // [Identity]
    ///
    /// - parameter db: A database connection.
    public static func fetchAll(_ db: Database, _ request: FetchRequest) -> [Self] {
        let (statement, adapter) = try! request.prepare(db)
        return fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single record fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
    ///     let identity = Identity.fetchOne(db, request) // Identity?
    ///
    /// - parameter db: A database connection.
    public static func fetchOne(_ db: Database, _ request: FetchRequest) -> Self? {
        let (statement, adapter) = try! request.prepare(db)
        return fetchOne(statement, adapter: adapter)
    }
}


extension RowConvertible {
    
    // MARK: Fetching From SQL
    
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
    ///     - adapter: Optional RowAdapter
    /// - returns: A sequence of records.
    public static func fetch(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> DatabaseSequence<Self> {
        return fetch(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of records fetched from an SQL query.
    ///
    ///     let persons = Person.fetchAll(db, "SELECT * FROM persons") // [Person]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of records.
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> [Self] {
        return fetchAll(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single record fetched from an SQL query.
    ///
    ///     let person = Person.fetchOne(db, "SELECT * FROM persons") // Person?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional record.
    public static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Self? {
        return fetchOne(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}
