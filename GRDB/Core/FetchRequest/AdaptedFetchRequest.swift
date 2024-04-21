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
