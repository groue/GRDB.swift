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
private class FetchRequestEraser: @unchecked Sendable {
    // @unchecked Sendable because abstract.
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

private final class ConcreteFetchRequestEraser<Request: FetchRequest>: FetchRequestEraser, @unchecked Sendable {
    // @unchecked Sendable because Request is Sendable, and superclass is @unchecked Sendable
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
