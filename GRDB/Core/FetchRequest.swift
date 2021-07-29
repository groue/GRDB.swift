// MARK: - FetchRequest

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
public protocol FetchRequest: SQLSubqueryable, DatabaseRegionConvertible {
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
    /// Returns the database region that the request feeds from.
    ///
    /// - parameter db: A database connection.
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        try makePreparedRequest(db, forSingleResult: false).statement.databaseRegion
    }
}

// MARK: - PreparedRequest

/// A PreparedRequest is a request that is ready to be executed.
public struct PreparedRequest {
    /// A prepared statement
    public var statement: Statement
    
    /// An eventual adapter for rows fetched by the select statement
    public var adapter: RowAdapter?
    
    /// Support for eager loading of hasMany associations.
    var supplementaryFetch: ((Database, [Row]) throws -> Void)?
    
    init(
        statement: Statement,
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
    
    public var sqlSubquery: SQLSubquery {
        base.sqlSubquery
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
    
    public var sqlSubquery: SQLSubquery {
        request.sqlSubquery
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
    
    var sqlSubquery: SQLSubquery {
        fatalError("subclass must override")
    }
    
    func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
        fatalError("subclass must override")
    }
    
    func fetchCount(_ db: Database) throws -> Int {
        fatalError("subclass must override")
    }
}

private final class ConcreteFetchRequestEraser<Request: FetchRequest>: FetchRequestEraser {
    let request: Request
    
    init(request: Request) {
        self.request = request
    }
    
    override var sqlSubquery: SQLSubquery {
        request.sqlSubquery
    }
    
    override func fetchCount(_ db: Database) throws -> Int {
        try request.fetchCount(db)
    }
    
    override func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
        try request.makePreparedRequest(db, forSingleResult: singleResult)
    }
}
