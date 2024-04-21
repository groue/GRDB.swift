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

// Explicit non-conformance to Sendable: `PreparedRequest` contains
// a statement.
@available(*, unavailable)
extension PreparedRequest: Sendable { }

extension PreparedRequest: Refinable { }
