/// The protocol for all types that define a way to fetch database rows.
///
/// Requests can feed the fetching methods of any fetchable type (Row,
/// value, record):
///
///     let request: Request = ...
///     try Row.fetchCursor(db, request) // DatabaseCursor<Row>
///     try String.fetchAll(db, request) // [String]
///     try Person.fetchOne(db, request) // Person?
public protocol Request {
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?)
    
    /// The number of rows fetched by the request.
    ///
    /// Default implementation builds a naive SQL query based on the statement
    /// returned by the `prepare` method: `SELECT COUNT(*) FROM (...)`.
    ///
    /// Adopting types can refine this countRequest method and return more
    /// efficient SQL.
    ///
    /// - parameter db: A database connection.
    func fetchCount(_ db: Database) throws -> Int
}

extension Request {
    /// The number of rows fetched by the request.
    ///
    /// This default implementation builds a naive SQL query based on the
    /// statement returned by the `prepare` method: `SELECT COUNT(*) FROM (...)`.
    ///
    /// - parameter db: A database connection.
    public func fetchCount(_ db: Database) throws -> Int {
        let (statement, _) = try prepare(db)
        let sql = "SELECT COUNT(*) FROM (\(statement.sql))"
        return try Int.fetchOne(db, sql, arguments: statement.arguments)!
    }
}

extension Request {
    /// Returns a request bound to type T.
    ///
    /// The returned request can fetch if the type T is fetchable (Row,
    /// value, record).
    ///
    ///     // minHeight in Double?
    ///     let minHeight = Person
    ///         .select(min(heightColumn))
    ///         .asRequest(of: Double.self)    // <--
    ///         .fetchOne(db)
    ///
    /// - parameter type: The fetched type T
    /// - returns: A typed request bound to type T.
    public func asRequest<T>(of type: T.Type) -> AnyTypedRequest<T> {
        return AnyTypedRequest { try self.prepare($0) }
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns an adapted request.
    public func adapted(_ adapter: @escaping (Database) throws -> RowAdapter) -> AdaptedRequest<Self> {
        return AdaptedRequest(self, adapter)
    }
}

/// An adapted request.
public struct AdaptedRequest<Base: Request> : Request {
    /// Creates an adapted request from a base request and a closure that builds
    /// a row adapter from a database connection.
    init(_ base: Base, _ adapter: @escaping (Database) throws -> RowAdapter) {
        self.base = base
        self.adapter = adapter
    }
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    ///
    /// - parameter db: A database connection.
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let (statement, baseAdapter) = try base.prepare(db)
        if let baseAdapter = baseAdapter {
            return try (statement, ChainedAdapter(first: baseAdapter, second: adapter(db)))
        } else {
            return try (statement, adapter(db))
        }
    }
    
    /// The number of rows fetched by the request.
    ///
    /// - parameter db: A database connection.
    public func fetchCount(_ db: Database) throws -> Int {
        return try base.fetchCount(db)
    }
    
    private let base: Base
    private let adapter: (Database) throws -> RowAdapter
}

/// A type-erased Request.
///
/// An instance of AnyRequest forwards its operations to an underlying request,
/// hiding its specifics.
public struct AnyRequest : Request {
    /// Creates a new request that wraps and forwards operations to `request`.
    public init(_ request: Request) {
        self._prepare = { try request.prepare($0) }
    }
    
    /// Creates a new request whose `prepare()` method wraps and forwards
    /// operations the argument closure.
    public init(_ prepare: @escaping (Database) throws -> (SelectStatement, RowAdapter?)) {
        _prepare = prepare
    }
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    ///
    /// - parameter db: A database connection.
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try _prepare(db)
    }
    
    private let _prepare: (Database) throws -> (SelectStatement, RowAdapter?)
}

/// A Request built from raw SQL.
public struct SQLRequest : Request {
    /// Creates a new request from an SQL string, optional arguments, and
    /// optional row adapter.
    ///
    ///     let request = SQLRequest("SELECT * FROM persons")
    ///     let request = SQLRequest("SELECT * FROM persons WHERE id = ?", arguments: [1])
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter.
    ///     - cached: Defaults to false. If true, the request reuses a cached
    ///       prepared statement.
    /// - returns: A SQLRequest
    public init(_ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, cached: Bool = false) {
        self.init(sql, arguments: arguments, adapter: adapter, fromCache: cached ? .user : nil)
    }
    
    /// Creates a new request from an SQL string, optional arguments, and
    /// optional row adapter.
    ///
    ///     let request = SQLRequest("SELECT * FROM persons")
    ///     let request = SQLRequest("SELECT * FROM persons WHERE id = ?", arguments: [1])
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter.
    ///     - statementCacheName: Optional statement cache name.
    /// - returns: A SQLRequest
    init(_ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, fromCache statementCacheName: Database.StatementCacheName?) {
        self.sql = sql
        self.arguments = arguments
        self.adapter = adapter
        self.statementCacheName = statementCacheName
    }
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    ///
    /// - parameter db: A database connection.
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let statement: SelectStatement
        if let statementCacheName = statementCacheName {
            statement = try db.selectStatement(sql, fromCache: statementCacheName)
        } else {
            statement = try db.makeSelectStatement(sql)
        }
        if let arguments = arguments {
            try statement.setArgumentsWithValidation(arguments)
        }
        return (statement, adapter)
    }
    
    private let sql: String
    private let arguments: StatementArguments?
    private let adapter: RowAdapter?
    private let statementCacheName: Database.StatementCacheName?
}

/// The protocol for requests that know how to decode database rows.
///
/// Typed requests can fetch if their associated type RowDecoder is able to
/// decode rows (Row, value, record)
///
///     struct Person: RowConvertible { ... }
///     let request: ... // Some TypedRequest that fetches Person
///     try request.fetchCursor(db) // DatabaseCursor<Person>
///     try request.fetchAll(db)    // [Person]
///     try request.fetchOne(db)    // Person?
public protocol TypedRequest : Request {
    
    /// The type that can convert raw database rows to fetched values
    associatedtype RowDecoder
}

extension TypedRequest {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns an adapted typed request.
    public func adapted(_ adapter: @escaping (Database) throws -> RowAdapter) -> AdaptedTypedRequest<Self> {
        return AdaptedTypedRequest(self, adapter)
    }
}

/// An adapted typed request.
public struct AdaptedTypedRequest<Base: TypedRequest> : TypedRequest {
    
    /// The type that can convert raw database rows to fetched values
    public typealias RowDecoder = Base.RowDecoder
    
    /// Creates an adapted request from a base request and a closure that builds
    /// a row adapter from a database connection.
    init(_ base: Base, _ adapter: @escaping (Database) throws -> RowAdapter) {
        self.base = base
        self.adapter = adapter
    }
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    ///
    /// - parameter db: A database connection.
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let (statement, baseAdapter) = try base.prepare(db)
        if let baseAdapter = baseAdapter {
            return try (statement, ChainedAdapter(first: baseAdapter, second: adapter(db)))
        } else {
            return try (statement, adapter(db))
        }
    }
    
    /// The number of rows fetched by the request.
    ///
    /// - parameter db: A database connection.
    public func fetchCount(_ db: Database) throws -> Int {
        return try base.fetchCount(db)
    }
    
    private let base: Base
    private let adapter: (Database) throws -> RowAdapter
}

/// A type-erased TypedRequest.
///
/// An instance of AnyTypedRequest forwards its operations to an underlying
/// typed request, hiding its specifics.
public struct AnyTypedRequest<T> : TypedRequest {
    /// The type that can convert raw database rows to fetched values
    public typealias RowDecoder = T
    
    /// Creates a new request that wraps and forwards operations to `request`.
    public init<Request>(_ request: Request) where Request: TypedRequest, Request.RowDecoder == RowDecoder {
        self._prepare = { try request.prepare($0) }
    }
    
    /// Creates a new request whose `prepare()` method wraps and forwards
    /// operations the argument closure.
    public init(_ prepare: @escaping (Database) throws -> (SelectStatement, RowAdapter?)) {
        _prepare = prepare
    }
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    ///
    /// - parameter db: A database connection.
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try _prepare(db)
    }
    
    private let _prepare: (Database) throws -> (SelectStatement, RowAdapter?)
}

extension TypedRequest where RowDecoder: RowConvertible {
    
    // MARK: Fetching Record and RowConvertible
    
    /// A cursor over fetched records.
    ///
    ///     let request: ... // Some TypedRequest that fetches Person
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
    public func fetchCursor(_ db: Database) throws -> DatabaseCursor<RowDecoder> {
        return try RowDecoder.fetchCursor(db, self)
    }
    
    /// An array of fetched records.
    ///
    ///     let request: ... // Some TypedRequest that fetches Person
    ///     let persons = try request.fetchAll(db) // [Person]
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        return try RowDecoder.fetchAll(db, self)
    }
    
    /// The first fetched record.
    ///
    ///     let request: ... // Some TypedRequest that fetches Person
    ///     let person = try request.fetchOne(db) // Person?
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        return try RowDecoder.fetchOne(db, self)
    }
}

extension TypedRequest where RowDecoder: DatabaseValueConvertible {
    
    // MARK: Fetching Values
    
    /// A cursor over fetched values.
    ///
    ///     let request: ... // Some TypedRequest that fetches String
    ///     let strings = try request.fetchCursor(db) // DatabaseCursor<String>
    ///     while let string = try strings.next() {   // String
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
    public func fetchCursor(_ db: Database) throws -> DatabaseCursor<RowDecoder> {
        return try RowDecoder.fetchCursor(db, self)
    }
    
    /// An array of fetched values.
    ///
    ///     let request: ... // Some TypedRequest that fetches String
    ///     let strings = try request.fetchAll(db) // [String]
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        return try RowDecoder.fetchAll(db, self)
    }
    
    /// The first fetched value.
    ///
    /// The result is nil if the request returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let request: ... // Some TypedRequest that fetches String
    ///     let string = try request.fetchOne(db) // String?
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional value.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        return try RowDecoder.fetchOne(db, self)
    }
}

extension TypedRequest where RowDecoder: DatabaseValueConvertible & StatementColumnConvertible {
    
    // MARK: Fetching Values
    
    /// A cursor over fetched values.
    ///
    ///     let request: ... // Some TypedRequest that fetches String
    ///     let strings = try request.fetchCursor(db) // DatabaseCursor<String>
    ///     while let string = try strings.next() {   // String
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
    public func fetchCursor(_ db: Database) throws -> DatabaseCursor<RowDecoder> {
        return try RowDecoder.fetchCursor(db, self)
    }
    
    /// An array of fetched values.
    ///
    ///     let request: ... // Some TypedRequest that fetches String
    ///     let strings = try request.fetchAll(db) // [String]
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        return try RowDecoder.fetchAll(db, self)
    }
    
    /// The first fetched value.
    ///
    /// The result is nil if the request returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let request: ... // Some TypedRequest that fetches String
    ///     let string = try request.fetchOne(db) // String?
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional value.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        return try RowDecoder.fetchOne(db, self)
    }
}

extension TypedRequest where RowDecoder: _OptionalProtocol, RowDecoder._Wrapped: DatabaseValueConvertible {

    // MARK: Fetching Optional values

    /// A cursor over fetched optional values.
    ///
    ///     let request: ... // Some TypedRequest that fetches Optional<String>
    ///     let strings = try request.fetchCursor(db) // DatabaseCursor<String?>
    ///     while let string = try strings.next() {   // String?
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
    public func fetchCursor(_ db: Database) throws -> DatabaseCursor<RowDecoder._Wrapped?> {
        return try Optional<RowDecoder._Wrapped>.fetchCursor(db, self)
    }

    /// An array of fetched optional values.
    ///
    ///     let request: ... // Some TypedRequest that fetches Optional<String>
    ///     let strings = try request.fetchAll(db) // [String?]
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of values.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder._Wrapped?] {
        return try Optional<RowDecoder._Wrapped>.fetchAll(db, self)
    }
}

extension TypedRequest where RowDecoder: Row {

    // MARK: Fetching Rows

    /// A cursor over fetched rows.
    ///
    ///     let request: ... // Some TypedRequest that fetches Row
    ///     let rows = try request.fetchCursor(db) // DatabaseCursor<Row>
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
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> DatabaseCursor<Row> {
        return try Row.fetchCursor(db, self)
    }

    /// An array of fetched rows.
    ///
    ///     let request: ... // Some TypedRequest that fetches Row
    ///     let rows = try request.fetchAll(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [Row] {
        return try Row.fetchAll(db, self)
    }

    /// The first fetched row.
    ///
    ///     let request: ... // Some TypedRequest that fetches Row
    ///     let row = try request.fetchOne(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: A,n optional rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> Row? {
        return try Row.fetchOne(db, self)
    }
}
