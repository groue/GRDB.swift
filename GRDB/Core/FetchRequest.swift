// MARK: - PreparedRequest

/// A PreparedRequest is a request that is ready to be executed.
public struct PreparedRequest {
    /// A prepared statement
    public var statement: SelectStatement
    
    /// An eventual adapter for rows fetched by the select statement
    public var adapter: RowAdapter?
    
    /// Support for eager loading of hasMany associations.
    var supplementaryFetch: (([Row]) throws -> Void)?
    
    // TODO: remove when FetchRequest is a closed protocol.
    /// Creates a PreparedRequest.
    ///
    /// - parameter statement: A prepared statement that is ready to
    ///   be executed.
    /// - parameter adapter: An eventual adapter for rows fetched by the
    ///   select statement.
    public init(
        statement: SelectStatement,
        adapter: RowAdapter? = nil)
    {
        self.init(statement: statement, adapter: adapter, supplementaryFetch: nil)
    }
    
    init(
        statement: SelectStatement,
        adapter: RowAdapter?,
        supplementaryFetch: (([Row]) throws -> Void)?)
    {
        self.statement = statement
        self.adapter = adapter
        self.supplementaryFetch = supplementaryFetch
    }
    
    // TODO: remove when FetchRequest is a closed protocol.
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns the request SQL.
    ///
    /// - parameter context: An SQL generation context.
    /// - returns: An SQL string.
    public func requestSQL(_ context: SQLGenerationContext) throws -> String {
        try SQLLiteral(sql: statement.sql, arguments: statement.arguments).sql(context)
    }
}

extension PreparedRequest: Refinable { }

// MARK: - FetchRequest

/// The protocol for all requests that fetch database rows, and tell how those
/// rows should be interpreted.
///
///     struct Player: FetchableRecord { ... }
///     let request: ... // Some FetchRequest that fetches Player
///     try request.fetchCursor(db) // Cursor of Player
///     try request.fetchAll(db)    // [Player]
///     try request.fetchOne(db)    // Player?
///     try request.fetchCount(db)  // Int
///
/// To build a custom FetchRequest, declare a type with the `RowDecoder`
/// associated type, and implement the `requestSQL(_:forSingleResult:)` method
/// with the help of SQLLiteral.
///
/// For example:
///
///     struct PlayerRequest: FetchRequest {
///         typealias RowDecoder = Player
///         var id: Int64
///         func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
///             let query: SQLLiteral = "SELECT * FROM player WHERE id = \(id)"
///             return try query.sql(context)
///         }
///     }
///
///     let player = try dbQueue.read { db in
///         try PlayerRequest(id: 42).fetchOne(db)
///     }
public protocol FetchRequest: SQLRequestProtocol, DatabaseRegionConvertible {
    /// The type that tells how fetched database rows should be interpreted.
    associatedtype RowDecoder
    
    /// Returns a PreparedRequest that is ready to be executed.
    ///
    /// - parameter db: A database connection.
    /// - parameter singleResult: A hint that a single result row will be
    ///   consumed. Implementations can optionally use it to optimize the
    ///   prepared statement, for example by adding a `LIMIT 1` SQL clause.
    ///
    ///       // Calls makePreparedRequest(db, forSingleResult: true)
    ///       try request.fetchOne(db)
    ///
    ///       // Calls makePreparedRequest(db, forSingleResult: false)
    ///       try request.fetchAll(db)
    /// - returns: A prepared request.
    func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest
    
    /// Returns the number of rows fetched by the request.
    ///
    /// - parameter db: A database connection.
    func fetchCount(_ db: Database) throws -> Int
}

extension FetchRequest {
    /// Returns the number of rows fetched by the request.
    ///
    /// The default implementation builds a naive SQL query based on the
    /// statement returned by the `requestSQL(_:forSingleResult:)` method:
    /// `SELECT COUNT(*) FROM (...)`.
    ///
    /// - parameter db: A database connection.
    public func fetchCount(_ db: Database) throws -> Int {
        let context = SQLGenerationContext(db)
        let sql = try requestSQL(context, forSingleResult: false)
        let countSQL = "SELECT COUNT(*) FROM (\(sql))"
        return try Int.fetchOne(db, sql: countSQL, arguments: context.arguments)!
    }
    
    /// Returns the database region that the request looks into.
    ///
    /// This default implementation returns a region built from the statement
    /// returned by the `requestSQL(_:forSingleResult)` method.
    ///
    /// - parameter db: A database connection.
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        let context = SQLGenerationContext(db)
        let sql = try requestSQL(context, forSingleResult: false)
        let statement = try db.makeSelectStatement(sql: sql)
        return statement.databaseRegion
    }
    
    /// Returns a PreparedRequest that is ready to be executed.
    ///
    /// This default implementation returns a request built from the
    /// `requestSQL(_:forSingleResult)` method.
    ///
    /// - parameter db: A database connection.
    /// - parameter singleResult: A hint that a single result row will be
    ///   consumed. Implementations can optionally use this to optimize the
    ///   prepared statement.
    /// - returns: A prepared request.
    public func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
        let context = SQLGenerationContext(db)
        let sql = try requestSQL(context, forSingleResult: singleResult)
        let statement = try db.makeSelectStatement(sql: sql)
        statement.arguments = context.arguments
        return PreparedRequest(statement: statement)
    }
}

// MARK: - AdaptedFetchRequest

extension FetchRequest {
    /// Returns an adapted request.
    public func adapted(_ adapter: @escaping (Database) throws -> RowAdapter) -> AdaptedFetchRequest<Self> {
        AdaptedFetchRequest(self, adapter)
    }
}

/// An adapted request.
public struct AdaptedFetchRequest<Base: FetchRequest>: FetchRequest {
    public typealias RowDecoder = Base.RowDecoder
    
    private let base: Base
    private let adapter: (Database) throws -> RowAdapter
    
    /// Creates an adapted request from a base request and a closure that builds
    /// a row adapter from a database connection.
    init(_ base: Base, _ adapter: @escaping (Database) throws -> RowAdapter) {
        self.base = base
        self.adapter = adapter
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
        try base.requestSQL(context, forSingleResult: singleResult)
    }
    
    /// :nodoc:
    public func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
        var request = try base.makePreparedRequest(db, forSingleResult: singleResult)
        if let baseAdapter = request.adapter {
            request.adapter = try ChainedAdapter(first: baseAdapter, second: adapter(db))
        } else {
            request.adapter = try adapter(db)
        }
        return request
    }
    
    /// :nodoc:
    public func fetchCount(_ db: Database) throws -> Int {
        try base.fetchCount(db)
    }
    
    /// :nodoc:
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        try base.databaseRegion(db)
    }
}

// MARK: - AnyFetchRequest

/// A type-erased FetchRequest.
///
/// An AnyFetchRequest forwards its operations to an underlying request,
/// hiding its specifics.
public struct AnyFetchRequest<RowDecoder>: FetchRequest {
    // DatabaseRegionConvertible
    private let _databaseRegion: (Database) throws -> DatabaseRegion
    
    // SQLRequestProtocol
    private let _requestSQL: (SQLGenerationContext, _ singleResult: Bool) throws -> String
    
    // FetchRequest
    private let _makePreparedRequest: (Database, _ singleResult: Bool) throws -> PreparedRequest
    private let _fetchCount: (Database) throws -> Int
    
    /// Creates a request bound to type RowDecoder.
    ///
    /// - parameter type: The fetched type RowDecoder
    /// - returns: A request bound to type RowDecoder.
    public func asRequest<RowDecoder>(of type: RowDecoder.Type) -> AnyFetchRequest<RowDecoder> {
        AnyFetchRequest<RowDecoder>(
            _databaseRegion: _databaseRegion,
            _requestSQL: _requestSQL,
            _makePreparedRequest: _makePreparedRequest,
            _fetchCount: _fetchCount)
    }
    
    /// :nodoc:
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        try _databaseRegion(db)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
        try _requestSQL(context, singleResult)
    }
    
    /// :nodoc:
    public func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
        try _makePreparedRequest(db, singleResult)
    }
    
    /// :nodoc:
    public func fetchCount(_ db: Database) throws -> Int {
        try _fetchCount(db)
    }
}

extension AnyFetchRequest {
    /// Creates a request that wraps and forwards operations to `request`.
    public init<Request: FetchRequest>(_ request: Request)
        where Request.RowDecoder == RowDecoder
    {
        self.init(
            _databaseRegion: request.databaseRegion,
            _requestSQL: request.requestSQL,
            _makePreparedRequest: request.makePreparedRequest,
            _fetchCount: request.fetchCount)
    }
}
