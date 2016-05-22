/// The protocol for all types that define a way to fetch values from
/// a database.
///
/// It is adopted by QueryInterfaceRequest. Your own custom types can adopt it
/// as well, and define a way to fetch values, rows, and records.
public protocol FetchRequest {
    /// A prepared statement that is ready to be executed.
    func selectStatement(db: Database) throws -> SelectStatement

    /// An eventual RowAdapter
    func adapter(statement: SelectStatement) throws -> RowAdapter?
}


struct SQLFetchRequest {
    let sql: String
    let arguments: StatementArguments?
    let adapter: RowAdapter?
    
    init(sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) {
        self.sql = sql
        self.arguments = arguments
        self.adapter = adapter
    }
}


extension SQLFetchRequest : FetchRequest {
    func selectStatement(db: Database) throws -> SelectStatement {
        let statement = try db.selectStatement(sql)
        if let arguments = arguments {
            try statement.setArgumentsWithValidation(arguments)
        }
        return statement
    }
    
    func adapter(statement: SelectStatement) throws -> RowAdapter? {
        return adapter
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
        return try! fetch(request.selectStatement(db))
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
        return try! fetchAll(request.selectStatement(db))
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
        return try! fetchOne(request.selectStatement(db))
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
        return try! fetch(request.selectStatement(db))
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
        return try! fetchAll(request.selectStatement(db))
    }
}


extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
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
        return try! fetch(request.selectStatement(db))
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
        return try! fetchAll(request.selectStatement(db))
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
        return try! fetchOne(request.selectStatement(db))
    }
}


extension RowConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of records fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("firstName")
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
    @warn_unused_result
    public static func fetch(db: Database, _ request: FetchRequest) -> DatabaseSequence<Self> {
        let statement = try! request.selectStatement(db)
        let adapter = try! request.adapter(statement)
        return fetch(statement, adapter: adapter)
    }
    
    /// Returns an array of records fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.order(nameColumn)
    ///     let identities = Identity.fetchAll(db, request) // [Identity]
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchAll(db: Database, _ request: FetchRequest) -> [Self] {
        let statement = try! request.selectStatement(db)
        let adapter = try! request.adapter(statement)
        return fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single record fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.order(nameColumn)
    ///     let identity = Identity.fetchOne(db, request) // Identity?
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchOne(db: Database, _ request: FetchRequest) -> Self? {
        let statement = try! request.selectStatement(db)
        let adapter = try! request.adapter(statement)
        return fetchOne(statement, adapter: adapter)
    }
}


extension RowConvertible where Self: TableMapping {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of all records fetched from the database.
    ///
    ///     let persons = Person.fetch(db) // DatabaseSequence<Person>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let persons = Person.fetch(db)
    ///     Array(persons).count // 3
    ///     db.execute("DELETE ...")
    ///     Array(persons).count // 2
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public static func fetch(db: Database) -> DatabaseSequence<Self> {
        return all().fetch(db)
    }
    
    /// Returns an array of all records fetched from the database.
    ///
    ///     let persons = Person.fetchAll(db) // [Person]
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchAll(db: Database) -> [Self] {
        return all().fetchAll(db)
    }
    
    /// Returns the first record fetched from a fetch request.
    ///
    ///     let person = Person.fetchOne(db) // Person?
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchOne(db: Database) -> Self? {
        return all().fetchOne(db)
    }
}


extension Row {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of rows fetched from a fetch request.
    ///
    ///     let idColumn = SQLColumn("id")
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(idColumn, nameColumn)
    ///     for row in Row.fetch(db, request) {
    ///         let id: Int64 = row.value(atIndex: 0)
    ///         let name: String = row.value(atIndex: 1)
    ///     }
    ///
    /// Fetched rows are reused during the sequence iteration: don't wrap a row
    /// sequence in an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let rows = Row.fetch(statement)
    ///     for row in rows { ... } // 3 steps
    ///     db.execute("DELETE ...")
    ///     for row in rows { ... } // 2 steps
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements of the sequence are undefined.
    @warn_unused_result
    public static func fetch(db: Database, _ request: FetchRequest) -> DatabaseSequence<Row> {
        let statement = try! request.selectStatement(db)
        let adapter = try! request.adapter(statement)
        return fetch(statement, adapter: adapter)
    }
    
    /// Returns an array of rows fetched from a fetch request.
    ///
    ///     let idColumn = SQLColumn("id")
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(idColumn, nameColumn)
    ///     let rows = Row.fetchAll(db, request)
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchAll(db: Database, _ request: FetchRequest) -> [Row] {
        let statement = try! request.selectStatement(db)
        let adapter = try! request.adapter(statement)
        return fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single row fetched from a fetch request.
    ///
    ///     let idColumn = SQLColumn("id")
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(idColumn, nameColumn)
    ///     let row = Row.fetchOne(db, request)
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchOne(db: Database, _ request: FetchRequest) -> Row? {
        let statement = try! request.selectStatement(db)
        let adapter = try! request.adapter(statement)
        return fetchOne(statement, adapter: adapter)
    }
}
