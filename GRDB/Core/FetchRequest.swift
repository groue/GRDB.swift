// MARK: - FetchRequest

/// A type that fetches and decodes database rows.
///
/// The main kinds of fetch requests are ``SQLRequest``
/// and ``QueryInterfaceRequest``:
///
/// ```swift
/// let lastName = "O'Reilly"
///
/// // SQLRequest
/// let request: SQLRequest<Player> = """
///     SELECT * FROM player WHERE lastName = \(lastName)
///     """
///
/// // QueryInterfaceRequest
/// let request = Player.filter(Column("lastName") == lastName)
///
/// // Use the request
/// try dbQueue.read { db in
///     let players = try request.fetchAll(db) // [Player]
/// }
/// ```
///
/// ## Topics
///
/// ### Counting the Results
///
/// - ``fetchCount(_:)``
///
/// ### Fetching Database Rows
///
/// - ``fetchCursor(_:)-9283d``
/// - ``fetchAll(_:)-7p809``
/// - ``fetchOne(_:)-9fafl``
/// - ``fetchSet(_:)-6bdrd``
///
/// ### Fetching Database Values
///
/// - ``fetchCursor(_:)-19f5g``
/// - ``fetchCursor(_:)-66xoi``
/// - ``fetchAll(_:)-1loau``
/// - ``fetchAll(_:)-28pne``
/// - ``fetchOne(_:)-44mvv``
/// - ``fetchOne(_:)-5hlkf``
/// - ``fetchSet(_:)-4hhtm``
/// - ``fetchSet(_:)-9wshm``
///
/// ### Fetching Records
///
/// - ``fetchCursor(_:)-2ah3q``
/// - ``fetchAll(_:)-vdos``
/// - ``fetchOne(_:)-2bq0k``
/// - ``fetchSet(_:)-4jdrq``
///
/// ### Preparing Database Requests
///
/// - ``makePreparedRequest(_:forSingleResult:)``
/// - ``PreparedRequest``
///
/// ### Adapting the Fetched Rows
///
/// - ``adapted(_:)``
/// - ``AdaptedFetchRequest``
///
/// ### Supporting Types
///
/// - ``AnyFetchRequest``
public protocol FetchRequest<RowDecoder>: SQLSubqueryable, DatabaseRegionConvertible {
    /// The type that tells how fetched database rows should be interpreted.
    associatedtype RowDecoder
    
    /// Returns a ``PreparedRequest``.
    ///
    /// The `singleResult` argument is a hint that a single result row will be
    /// consumed. Implementations can optionally use it to optimize the
    /// prepared statement, for example by adding a `LIMIT 1` SQL clause:
    ///
    /// ```swift
    /// // Calls makePreparedRequest(db, forSingleResult: true)
    /// try request.fetchOne(db)
    ///
    /// // Calls makePreparedRequest(db, forSingleResult: false)
    /// try request.fetchAll(db)
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter singleResult: A hint that a single result row will be
    ///   consumed.
    func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest
    
    /// Returns the number of rows fetched by the request.
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
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

/// A closure executed before a supplementary fetch is performed.
///
/// Support for `Database.dumpRequest`.
///
/// - parameter request: The supplementary request
/// - parameter keyPath: The key path target of the supplementary fetch.
typealias WillExecuteSupplementaryRequest = (_ request: AnyFetchRequest<Row>, _ keyPath: [String]) throws -> Void

/// A closure that performs supplementary fetches.
///
/// Support for eager loading of hasMany associations.
///
/// - parameter db: A database connection.
/// - parameter rows: The rows that are modified by the supplementary fetch.
/// - parameter willExecuteSupplementaryRequest: A closure to execute before
///   performing supplementary fetches.
typealias SupplementaryFetch = (
    _ db: Database,
    _ rows: [Row],
    _ willExecuteSupplementaryRequest: WillExecuteSupplementaryRequest?)
throws -> Void

/// A `PreparedRequest` is a request that is ready to be executed.
public struct PreparedRequest {
    /// A prepared statement with bound parameters.
    public var statement: Statement
    
    /// An eventual adapter for rows fetched by the select statement.
    public var adapter: (any RowAdapter)?
    
    /// A closure that performs supplementary fetches.
    /// Support for eager loading of hasMany associations.
    var supplementaryFetch: SupplementaryFetch?
    
    init(
        statement: Statement,
        adapter: (any RowAdapter)?,
        supplementaryFetch: SupplementaryFetch? = nil)
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
    ///
    /// The returned request performs an identical database query, but adapts
    /// the fetched rows. See ``RowAdapter``, and
    /// ``splittingRowAdapters(columnCounts:)`` for a sample code that uses
    /// `adapted(_:)`.
    ///
    /// - parameter adapter: A closure that accepts a database connection and
    ///   returns a row adapter.
    public func adapted(_ adapter: @escaping (Database) throws -> any RowAdapter) -> AdaptedFetchRequest<Self> {
        AdaptedFetchRequest(self, adapter)
    }
}

/// An adapted request.
///
/// See ``FetchRequest/adapted(_:)``.
public struct AdaptedFetchRequest<Base: FetchRequest> {
    let base: Base
    let adapter: (Database) throws -> any RowAdapter
    
    /// Creates an adapted request from a base request and a closure that builds
    /// a row adapter from a database connection.
    init(_ base: Base, _ adapter: @escaping (Database) throws -> any RowAdapter) {
        self.base = base
        self.adapter = adapter
    }
}

extension AdaptedFetchRequest: SQLSubqueryable {
    public var sqlSubquery: SQLSubquery {
        base.sqlSubquery
    }
}

extension AdaptedFetchRequest: FetchRequest {
    public typealias RowDecoder = Base.RowDecoder
    
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
public struct AnyFetchRequest<RowDecoder> {
    private let request: FetchRequestEraser
    
    /// Returns a request that performs an identical database query, but decodes
    /// database rows with `type`.
    ///
    /// For example:
    ///
    /// ```swift
    /// // AnyFetchRequest<Player>
    /// let playerRequest = AnyFetchRequest(Player.all())
    ///
    /// // AnyFetchRequest<Row>
    /// let rowRequest = playerRequest.asRequest(of: Row.self)
    public func asRequest<T>(of type: T.Type) -> AnyFetchRequest<T> {
        AnyFetchRequest<T>(request: request)
    }
}

extension AnyFetchRequest {
    /// Creates a request that wraps and forwards operations to `request`.
    public init(_ request: some FetchRequest<RowDecoder>) {
        self.init(request: ConcreteFetchRequestEraser(request: request))
    }
}

extension AnyFetchRequest: SQLSubqueryable {
    public var sqlSubquery: SQLSubquery {
        request.sqlSubquery
    }
}

extension AnyFetchRequest: FetchRequest {
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
