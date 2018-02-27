/// The protocol for all types that define a way to fetch database content.
///
///     struct Player: RowConvertible { ... }
///     let request: ... // Some FetchRequest that fetches Player
///     try request.fetchCursor(db) // Cursor of Player
///     try request.fetchAll(db)    // [Player]
///     try request.fetchOne(db)    // Player?
public protocol FetchRequest {
    /// The type that can convert raw database rows to fetched values
    associatedtype RowDecoder
    
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
    
    /// The database region that the request looks into.
    ///
    /// This method has a default implementation.
    ///
    /// - parameter db: A database connection.
    func fetchedRegion(_ db: Database) throws -> DatabaseRegion
}

extension FetchRequest {
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
    
    /// The database region that the request looks into.
    ///
    /// - parameter db: A database connection.
    public func fetchedRegion(_ db: Database) throws -> DatabaseRegion {
        let (statement, _) = try prepare(db)
        return statement.fetchedRegion
    }
}

extension FetchRequest {
    /// Returns a request bound to type T.
    ///
    /// The returned request can fetch if the type T is fetchable (Row,
    /// value, record).
    ///
    ///     // Int?
    ///     let maxScore = Player
    ///         .select(max(scoreColumn))
    ///         .asRequest(of: Int.self)    // <--
    ///         .fetchOne(db)
    ///
    /// - parameter type: The fetched type T
    /// - returns: A typed request bound to type T.
    public func asRequest<T>(of type: T.Type) -> AnyFetchRequest<T> {
        return AnyFetchRequest(self)
    }
    
    /// Returns an adapted request.
    public func adapted(_ adapter: @escaping (Database) throws -> RowAdapter) -> AdaptedFetchRequest<Self> {
        return AdaptedFetchRequest(self, adapter)
    }
}

/// An adapted request.
public struct AdaptedFetchRequest<Base: FetchRequest> : FetchRequest {
    public typealias RowDecoder = Base.RowDecoder
    
    private let base: Base
    private let adapter: (Database) throws -> RowAdapter
    
    /// Creates an adapted request from a base request and a closure that builds
    /// a row adapter from a database connection.
    init(_ base: Base, _ adapter: @escaping (Database) throws -> RowAdapter) {
        self.base = base
        self.adapter = adapter
    }
    
    /// :nodoc:
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let (statement, baseAdapter) = try base.prepare(db)
        if let baseAdapter = baseAdapter {
            return try (statement, ChainedAdapter(first: baseAdapter, second: adapter(db)))
        } else {
            return try (statement, adapter(db))
        }
    }
    
    /// :nodoc:
    public func fetchCount(_ db: Database) throws -> Int {
        return try base.fetchCount(db)
    }
    
    /// :nodoc:
    public func fetchedRegion(_ db: Database) throws -> DatabaseRegion {
        return try base.fetchedRegion(db)
    }
}

/// A type-erased FetchRequest.
///
/// An AnyFetchRequest forwards its operations to an underlying request,
/// hiding its specifics.
public struct AnyFetchRequest<T> : FetchRequest {
    public typealias RowDecoder = T
    
    private let _prepare: (Database) throws -> (SelectStatement, RowAdapter?)
    private let _fetchCount: (Database) throws -> Int
    private let _fetchedRegion: (Database) throws -> DatabaseRegion
    
    /// Creates a new request that wraps and forwards operations to `request`.
    public init<Request: FetchRequest>(_ request: Request) {
        _prepare = request.prepare
        _fetchCount = request.fetchCount
        _fetchedRegion = request.fetchedRegion
    }
    
    /// Creates a new request whose `prepare()` method wraps and forwards
    /// operations the argument closure.
    public init(_ prepare: @escaping (Database) throws -> (SelectStatement, RowAdapter?)) {
        _prepare = { db in
            try prepare(db)
        }
        
        _fetchCount = { db in
            let (statement, _) = try prepare(db)
            let sql = "SELECT COUNT(*) FROM (\(statement.sql))"
            return try Int.fetchOne(db, sql, arguments: statement.arguments)!
        }
        
        _fetchedRegion = { db in
            let (statement, _) = try prepare(db)
            return statement.fetchedRegion
        }
    }
    
    /// :nodoc:
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try _prepare(db)
    }
    
    /// :nodoc:
    public func fetchCount(_ db: Database) throws -> Int {
        return try _fetchCount(db)
    }
    
    /// :nodoc:
    public func fetchedRegion(_ db: Database) throws -> DatabaseRegion {
        return try _fetchedRegion(db)
    }
}

/// A Request built from raw SQL.
public struct SQLRequest<T> : FetchRequest {
    public typealias RowDecoder = T
    
    public let sql: String
    public let arguments: StatementArguments?
    public let adapter: RowAdapter?
    private let cache: Cache?
    
    /// Creates a new request from an SQL string, optional arguments, and
    /// optional row adapter.
    ///
    ///     let request = SQLRequest("SELECT * FROM players")
    ///     let request = SQLRequest("SELECT * FROM players WHERE id = ?", arguments: [1])
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter.
    ///     - cached: Defaults to false. If true, the request reuses a cached
    ///       prepared statement.
    /// - returns: A SQLRequest
    public init(_ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, cached: Bool = false) {
        self.init(sql, arguments: arguments, adapter: adapter, fromCache: cached ? .public : nil)
    }
    
    /// Creates a new SQL request from any other fetch request.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A request.
    ///     - cached: Defaults to false. If true, the request reuses a cached
    ///       prepared statement.
    /// - returns: An SQLRequest
    public init<Request: FetchRequest>(_ db: Database, request: Request, cached: Bool = false) throws where Request.RowDecoder == RowDecoder {
        let (statement, adapter) = try request.prepare(db)
        self.init(statement.sql, arguments: statement.arguments, adapter: adapter, cached: cached)
    }
    
    /// Creates a new SQL request from an SQL string, optional arguments, and
    /// optional row adapter.
    ///
    ///     let request = SQLRequest("SELECT * FROM players")
    ///     let request = SQLRequest("SELECT * FROM players WHERE id = ?", arguments: [1])
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter.
    ///     - statementCacheName: Optional statement cache name.
    /// - returns: A SQLRequest
    init(_ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, fromCache cache: Cache?) {
        self.sql = sql
        self.arguments = arguments
        self.adapter = adapter
        self.cache = cache
    }
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    ///
    /// - parameter db: A database connection.
    ///
    /// :nodoc:
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let statement: SelectStatement
        switch cache {
        case .none:
            statement = try db.makeSelectStatement(sql)
        case .public?:
            statement = try db.cachedSelectStatement(sql)
        case .internal?:
            statement = try db.internalCachedSelectStatement(sql)
        }
        if let arguments = arguments {
            try statement.setArgumentsWithValidation(arguments)
        }
        return (statement, adapter)
    }
    
    /// There are two statement caches: one for statements generated by the
    /// user, and one for the statements generated by GRDB. Those are separated
    /// so that GRDB has no opportunity to inadvertently modify the arguments of
    /// user's cached statements.
    enum Cache {
        /// The public cache, for library user
        case `public`
        
        /// The internal cache, for grdb
        case `internal`
    }
}
