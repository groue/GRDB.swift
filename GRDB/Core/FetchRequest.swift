/// The protocol for all types that define a way to fetch values from
/// a database.
public protocol FetchRequest {
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?)
}

extension FetchRequest {
    /// TODO
    public func bound<T>(to type: T.Type) -> AnyTypedFetchRequest<T> {
        return AnyTypedFetchRequest(untypedRequest: self)
    }
}

/// TODO
public struct AnyFetchRequest : FetchRequest {
    /// TODO
    public init<Request>(_ request: Request) where Request: FetchRequest {
        self._prepare = { try request.prepare($0) }
    }
    
    /// TODO
    public init(_ prepare: @escaping (Database) throws -> (SelectStatement, RowAdapter?)) {
        _prepare = prepare
    }
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try _prepare(db)
    }
    
    private let _prepare: (Database) throws -> (SelectStatement, RowAdapter?)
}

struct SQLFetchRequest : FetchRequest {
    let sql: String
    let arguments: StatementArguments?
    let adapter: RowAdapter?
    
    init(sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) {
        self.sql = sql
        self.arguments = arguments
        self.adapter = adapter
    }
    
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let statement = try db.makeSelectStatement(sql)
        if let arguments = arguments {
            try statement.setArgumentsWithValidation(arguments)
        }
        return (statement, adapter)
    }
}

/// The protocol for all types that define a way to fetch values from
/// a database, with an attached type.
public protocol TypedFetchRequest : FetchRequest {
    associatedtype FetchedType
}

/// TODO
public struct AnyTypedFetchRequest<T> : TypedFetchRequest {
    /// TODO
    public typealias FetchedType = T
    
    init(untypedRequest request: FetchRequest) {
        self.request = request
    }
    
    /// TODO
    public init<Request>(_ request: Request) where Request: TypedFetchRequest, Request.FetchedType == FetchedType {
        self.request = request
    }
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try request.prepare(db)
    }
    
    private let request : FetchRequest
}

struct SQLTypedFetchRequest<T> : TypedFetchRequest {
    /// TODO
    typealias FetchedType = T
    
    let sql: String
    let arguments: StatementArguments?
    let adapter: RowAdapter?
    
    init(sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) {
        self.sql = sql
        self.arguments = arguments
        self.adapter = adapter
    }
    
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let statement = try db.makeSelectStatement(sql)
        if let arguments = arguments {
            try statement.setArgumentsWithValidation(arguments)
        }
        return (statement, adapter)
    }
}

extension TypedFetchRequest where FetchedType: RowConvertible {
    
    // MARK: Fetching Record and RowConvertible
    
    /// TODO
    /// A cursor over fetched records.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
    ///     let persons = try request.fetchCursor(db) // DatabaseCursor<Person>
    ///     while let person = try persons.next() {   // Person
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> DatabaseCursor<FetchedType> {
        return try FetchedType.fetchCursor(db, self)
    }
    
    /// TODO
    /// An array of fetched records.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
    ///     let persons = try request.fetchAll(db) // [Person]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [FetchedType] {
        return try FetchedType.fetchAll(db, self)
    }
    
    /// TODO
    /// The first fetched record.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
    ///     let person = try request.fetchOne(db) // Person?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> FetchedType? {
        return try FetchedType.fetchOne(db, self)
    }
}

extension TypedFetchRequest where FetchedType: DatabaseValueConvertible {
    
    // MARK: Fetching Values
    
    /// TODO
    /// A cursor over fetched values.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
    ///     let persons = try request.fetchCursor(db) // DatabaseCursor<Person>
    ///     while let person = try persons.next() {   // Person
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> DatabaseCursor<FetchedType> {
        return try FetchedType.fetchCursor(db, self)
    }
    
    /// TODO
    /// An array of fetched values.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
    ///     let persons = try request.fetchAll(db) // [Person]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [FetchedType] {
        return try FetchedType.fetchAll(db, self)
    }
    
    /// TODO
    /// The first fetched value.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
    ///     let person = try request.fetchOne(db) // Person?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> FetchedType? {
        return try FetchedType.fetchOne(db, self)
    }
}

/// TODO
public protocol OptionalProtocol {
    associatedtype Value
}

extension Optional : OptionalProtocol {
    public typealias Value = Wrapped
}

extension TypedFetchRequest where FetchedType: OptionalProtocol, FetchedType.Value: DatabaseValueConvertible {

    // MARK: Fetching Optional values

    /// TODO
    /// Returns a cursor over optional values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(nameColumn)
    ///     let names = try Optional<String>.fetchCursor(db, request) // DatabaseCursor<String?>
    ///     while let name = try names.next() { // String?
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
    ///     - requet: A fetch request.
    /// - returns: A cursor over fetched optional values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> DatabaseCursor<FetchedType.Value?> {
        return try Optional<FetchedType.Value>.fetchCursor(db, self)
    }

    /// TODO
    /// Returns an array of optional values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(nameColumn)
    ///     let names = try Optional<String>.fetchAll(db, request) // [String?]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [FetchedType.Value?] {
        return try Optional<FetchedType.Value>.fetchAll(db, self)
    }
}

extension TypedFetchRequest where FetchedType: Row {

    // MARK: Fetching Rows

    /// TODO
    /// Returns a cursor over rows fetched from a fetch request.
    ///
    ///     let idColumn = Column("id")
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(idColumn, nameColumn)
    ///     let rows = try Row.fetchCursor(db) // DatabaseCursor<Row>
    ///     while let row = try rows.next() {  // Row
    ///         let id: Int64 = row.value(atIndex: 0)
    ///         let name: String = row.value(atIndex: 1)
    ///     }
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A fetch request.
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> DatabaseCursor<Row> {
        return try Row.fetchCursor(db, self)
    }

    /// TODO
    /// Returns an array of rows fetched from a fetch request.
    ///
    ///     let idColumn = Column("id")
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(idColumn, nameColumn)
    ///     let rows = try Row.fetchAll(db, request)
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [Row] {
        return try Row.fetchAll(db, self)
    }

    /// TODO
    /// Returns a single row fetched from a fetch request.
    ///
    ///     let idColumn = Column("id")
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(idColumn, nameColumn)
    ///     let row = try Row.fetchOne(db, request)
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> Row? {
        return try Row.fetchOne(db, self)
    }
}
