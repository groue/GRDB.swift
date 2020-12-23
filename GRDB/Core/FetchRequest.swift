// MARK: - FetchRequest

/// Implementation details of `FetchRequest`.
///
/// :nodoc:
public protocol _FetchRequest {
    /// The number of columns selected by the request.
    ///
    /// This method makes it possible to find the columns of a CTE in a request
    /// that includes a CTE association:
    ///
    ///     // WITH cte AS (SELECT 1 AS a, 2 AS b)
    ///     // SELECT player.*, cte.*
    ///     // FROM player
    ///     // JOIN cte
    ///     let cte = CommonTableExpression<Void>(named: "cte", sql: "SELECT 1 AS a, 2 AS b")
    ///     let request = Player
    ///         .with(cte)
    ///         .including(required: Player.association(to: cte))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     // We know that "SELECT 1 AS a, 2 AS b" selects two columns,
    ///     // so we can find cte columns in the row:
    ///     row.scopes["cte"] // [a:1, b:2]
    ///
    /// :nodoc:
    func _selectedColumnCount(_ db: Database) throws -> Int
    
    /// Returns the request SQL.
    ///
    /// This method makes it possible to embed a request as a subquery:
    ///
    ///     // SELECT *
    ///     // FROM "player"
    ///     // WHERE "score" = (SELECT MAX("score") FROM "player")
    ///     let maxScore = Player.select(max(Column("score")))
    ///     let players = try Player
    ///         .filter(Column("score") == maxScore)
    ///         .fetchAll(db)
    ///
    /// - parameter context: An SQL generation context.
    /// - parameter singleResult: A hint that a single result row will be
    ///   consumed. Implementations can optionally use it to optimize the
    ///   generated SQL, for example by adding a `LIMIT 1` SQL clause.
    /// - returns: An SQL string.
    ///
    /// :nodoc:
    func _requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String
}

/// The protocol for all requests that fetch database rows, and tell how those
/// rows should be interpreted.
///
///     struct Player: FetchableRecord { ... }
///     let request: ... // Some FetchRequest that fetches Player
///     try request.fetchCursor(db) // Cursor of Player
///     try request.fetchAll(db)    // [Player]
///     try request.fetchSet(db)    // Set<Player>
///     try request.fetchOne(db)    // Player?
///     try request.fetchCount(db)  // Int
public protocol FetchRequest: _FetchRequest, DatabaseRegionConvertible, SQLExpression, SQLCollection {
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
    // MARK: DatabaseRegionConvertible
    
    /// Returns the database region that the request feeds from.
    ///
    /// - parameter db: A database connection.
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        try makePreparedRequest(db, forSingleResult: false).statement.databaseRegion
    }
    
    // MARK: SQLCollection
    
    /// :nodoc:
    public var _collectionExpressions: [SQLExpression]? { nil }
    
    /// :nodoc:
    public func _collectionSQL(_ context: SQLGenerationContext) throws -> String {
        try "("
            + _requestSQL(context, forSingleResult: false)
            + ")"
    }
    
    public func contains(_ value: SQLExpressible) -> SQLExpression {
        SQLExpressionContains(value, self)
    }
    
    /// :nodoc:
    public func _qualifiedCollection(with alias: TableAlias) -> SQLCollection { self }
    
    // MARK: SQLExpression
    
    /// :nodoc:
    public func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        try "("
            + _requestSQL(context, forSingleResult: false)
            + ")"
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression { self }
}

// MARK: - PreparedRequest

/// A PreparedRequest is a request that is ready to be executed.
public struct PreparedRequest {
    /// A prepared statement
    public var statement: SelectStatement
    
    /// An eventual adapter for rows fetched by the select statement
    public var adapter: RowAdapter?
    
    /// Support for eager loading of hasMany associations.
    var supplementaryFetch: ((Database, [Row]) throws -> Void)?
    
    init(
        statement: SelectStatement,
        adapter: RowAdapter?,
        supplementaryFetch: ((Database, [Row]) throws -> Void)? = nil)
    {
        self.statement = statement
        self.adapter = adapter
        self.supplementaryFetch = supplementaryFetch
    }
}

extension PreparedRequest: Refinable { }

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
    
    let base: Base
    let adapter: (Database) throws -> RowAdapter
    
    /// Creates an adapted request from a base request and a closure that builds
    /// a row adapter from a database connection.
    init(_ base: Base, _ adapter: @escaping (Database) throws -> RowAdapter) {
        self.base = base
        self.adapter = adapter
    }
    
    public func fetchCount(_ db: Database) throws -> Int {
        try base.fetchCount(db)
    }
    
    public func makePreparedRequest(
        _ db: Database,
        forSingleResult singleResult: Bool = false)
    throws -> PreparedRequest
    {
        var preparedRequest = try base.makePreparedRequest(db, forSingleResult: singleResult)
        
        if let baseAdapter = preparedRequest.adapter {
            preparedRequest.adapter = try ChainedAdapter(first: baseAdapter, second: adapter(db))
        } else {
            preparedRequest.adapter = try adapter(db)
        }
        
        return preparedRequest
    }
    
    /// :nodoc:
    public func _selectedColumnCount(_ db: Database) throws -> Int {
        try base._selectedColumnCount(db)
    }
    
    /// :nodoc:
    public func _requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
        try base._requestSQL(context, forSingleResult: singleResult)
    }
}

// MARK: - AnyFetchRequest

/// A type-erased FetchRequest.
///
/// An `AnyFetchRequest` forwards its operations to an underlying request,
/// hiding its specifics.
public struct AnyFetchRequest<RowDecoder>: FetchRequest {
    private let request: FetchRequestEraser
    
    /// Creates a request bound to type RowDecoder.
    ///
    /// - parameter type: The fetched type RowDecoder
    /// - returns: A request bound to type RowDecoder.
    public func asRequest<RowDecoder>(of type: RowDecoder.Type) -> AnyFetchRequest<RowDecoder> {
        AnyFetchRequest<RowDecoder>(request: request)
    }
    
    /// :nodoc:
    public func _selectedColumnCount(_ db: Database) throws -> Int {
        try request._selectedColumnCount(db)
    }
    
    public func fetchCount(_ db: Database) throws -> Int {
        try request.fetchCount(db)
    }
    
    public func makePreparedRequest(
        _ db: Database,
        forSingleResult singleResult: Bool = false)
    throws -> PreparedRequest
    {
        try request.makePreparedRequest(db, forSingleResult: singleResult)
    }
    
    /// :nodoc:
    public func _requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
        try request._requestSQL(context, forSingleResult: singleResult)
    }
}

extension AnyFetchRequest {
    /// Creates a request that wraps and forwards operations to `request`.
    public init<Request: FetchRequest>(_ request: Request)
    where Request.RowDecoder == RowDecoder
    {
        self.init(request: ConcreteFetchRequestEraser(request: request))
    }
}

// Class-based type erasure, so that we preserve full type information.
private class FetchRequestEraser: FetchRequest {
    typealias RowDecoder = Void
    
    func _selectedColumnCount(_ db: Database) throws -> Int {
        fatalError("subclass must override")
    }
    
    func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
        fatalError("subclass must override")
    }
    
    func fetchCount(_ db: Database) throws -> Int {
        fatalError("subclass must override")
    }
    
    func _requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
        fatalError("subclass must override")
    }
}

private final class ConcreteFetchRequestEraser<Request: FetchRequest>: FetchRequestEraser {
    let request: Request
    
    init(request: Request) {
        self.request = request
    }
    
    override func _selectedColumnCount(_ db: Database) throws -> Int {
        try request._selectedColumnCount(db)
    }
    
    override func fetchCount(_ db: Database) throws -> Int {
        try request.fetchCount(db)
    }
    
    override func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
        try request.makePreparedRequest(db, forSingleResult: singleResult)
    }
    
    override func _requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
        try request._requestSQL(context, forSingleResult: singleResult)
    }
}
