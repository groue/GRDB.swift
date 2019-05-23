// MARK: - FetchRequest

/// The protocol for all requests that run from a single select statement, and
/// tell how fetched rows should be interpreted.
///
///     struct Player: FetchableRecord { ... }
///     let request: ... // Some FetchRequest that fetches Player
///     try request.fetchCursor(db) // Cursor of Player
///     try request.fetchAll(db)    // [Player]
///     try request.fetchOne(db)    // Player?
public protocol FetchRequest: DatabaseRegionConvertible {
    /// The type that tells how fetched database rows should be interpreted.
    associatedtype RowDecoder

    /// Returns a tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    ///
    /// - parameter db: A database connection.
    /// - parameter singleResult: A hint that the query should return a single
    ///                           result. Implementations can optionally use
    ///                           this to optimize the prepared statement.
    /// - returns: A prepared statement and an eventual row adapter.
    func prepare(_ db: Database, forSingleResult singleResult: Bool) throws -> (SelectStatement, RowAdapter?)
    
    /// Returns the number of rows fetched by the request.
    ///
    /// The default implementation builds a naive SQL query based on the
    /// statement returned by the `prepare` method:
    /// `SELECT COUNT(*) FROM (...)`.
    ///
    /// Adopting types can refine this method in order to use more
    /// efficient SQL.
    ///
    /// - parameter db: A database connection.
    func fetchCount(_ db: Database) throws -> Int
}

extension FetchRequest {

    /// Returns an adapted request.
    public func adapted(_ adapter: @escaping (Database) throws -> RowAdapter) -> AdaptedFetchRequest<Self> {
        return AdaptedFetchRequest(self, adapter)
    }
    
    /// Returns the number of rows fetched by the request.
    ///
    /// This default implementation builds a naive SQL query based on the
    /// statement returned by the `prepare` method: `SELECT COUNT(*) FROM (...)`.
    ///
    /// - parameter db: A database connection.
    public func fetchCount(_ db: Database) throws -> Int {
        let (statement, _) = try prepare(db, forSingleResult: false)
        let sql = "SELECT COUNT(*) FROM (\(statement.sql))"
        return try Int.fetchOne(db, sql: sql, arguments: statement.arguments)!
    }
    
    /// Returns the database region that the request looks into.
    ///
    /// This default implementation returns a region built from the statement
    /// returned by the `prepare` method.
    ///
    /// - parameter db: A database connection.
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        let (statement, _) = try prepare(db, forSingleResult: false)
        return statement.databaseRegion
    }
}

// MARK: - AdaptedFetchRequest

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
    public func prepare(_ db: Database, forSingleResult singleResult: Bool) throws -> (SelectStatement, RowAdapter?) {
        let (statement, baseAdapter) = try base.prepare(db, forSingleResult: singleResult)
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
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        return try base.databaseRegion(db)
    }
}

// MARK: - AnyFetchRequest

/// A type-erased FetchRequest.
///
/// An AnyFetchRequest forwards its operations to an underlying request,
/// hiding its specifics.
public struct AnyFetchRequest<T> : FetchRequest {
    public typealias RowDecoder = T
    
    private let _prepare: (Database, _ singleResult: Bool) throws -> (SelectStatement, RowAdapter?)
    private let _fetchCount: (Database) throws -> Int
    private let _databaseRegion: (Database) throws -> DatabaseRegion
    
    /// Creates a request that wraps and forwards operations to `request`.
    public init<Request: FetchRequest>(_ request: Request) {
        _prepare = request.prepare
        _fetchCount = request.fetchCount
        _databaseRegion = request.databaseRegion
    }
    
    /// Creates a request whose `prepare()` method wraps and forwards
    /// operations the argument closure.
    public init(_ prepare: @escaping (Database, _ singleResult: Bool) throws -> (SelectStatement, RowAdapter?)) {
        _prepare = { db, singleResult in
            try prepare(db, singleResult)
        }
        
        _fetchCount = { db in
            let (statement, _) = try prepare(db, false)
            let sql = "SELECT COUNT(*) FROM (\(statement.sql))"
            return try Int.fetchOne(db, sql: sql, arguments: statement.arguments)!
        }
        
        _databaseRegion = { db in
            let (statement, _) = try prepare(db, false)
            return statement.databaseRegion
        }
    }
    
    /// :nodoc:
    public func prepare(_ db: Database, forSingleResult singleResult: Bool) throws -> (SelectStatement, RowAdapter?) {
        return try _prepare(db, singleResult)
    }
    
    /// :nodoc:
    public func fetchCount(_ db: Database) throws -> Int {
        return try _fetchCount(db)
    }
    
    /// :nodoc:
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        return try _databaseRegion(db)
    }
}
