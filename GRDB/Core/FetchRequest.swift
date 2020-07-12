// MARK: - FetchRequest

/// Implementation details of `FetchRequest`.
///
/// :nodoc:
public protocol _FetchRequest {
    /// Accepts a visitor
    func _accept<Visitor: _FetchRequestVisitor>(_ visitor: inout Visitor) throws
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
}

extension FetchRequest {
    /// :nodoc:
    public func _qualifiedCollection(with alias: TableAlias) -> SQLCollection {
        self
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        self
    }
    
    /// Returns an expression which applies the `IN` SQL operator.
    public func contains(_ value: SQLExpressible) -> SQLExpression {
        _SQLExpressionContains(value, self)
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
    
    let base: Base
    let adapter: (Database) throws -> RowAdapter
    
    /// Creates an adapted request from a base request and a closure that builds
    /// a row adapter from a database connection.
    init(_ base: Base, _ adapter: @escaping (Database) throws -> RowAdapter) {
        self.base = base
        self.adapter = adapter
    }
    
    /// :nodoc:
    public func _accept<Visitor: _FetchRequestVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
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
    public func _accept<Visitor: _FetchRequestVisitor>(_ visitor: inout Visitor) throws {
        try request._accept(&visitor)
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

// Class-based type erasure, so that we preserve full type information in
// the generic `_accept<Visitor: _FetchRequestVisitor>(_:)`
private class FetchRequestEraser: FetchRequest {
    typealias RowDecoder = Void
    
    func _accept<Visitor: _FetchRequestVisitor>(_ visitor: inout Visitor) throws {
        fatalError("Abstract Method")
    }
}

private final class ConcreteFetchRequestEraser<Request: FetchRequest>: FetchRequestEraser {
    let request: Request
    
    init(request: Request) {
        self.request = request
    }
    
    override func _accept<Visitor: _FetchRequestVisitor>(_ visitor: inout Visitor) throws {
        try request._accept(&visitor)
    }
}
