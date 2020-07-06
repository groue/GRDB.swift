/// Implementation details of SQLRequestProtocol.
///
/// :nodoc:
public protocol _SQLRequestProtocol {
    // TODO: rename to _requestSQL when FetchRequest is a closed protocol.
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns the request SQL.
    ///
    /// - parameter context: An SQL generation context.
    /// - parameter singleResult: A hint that a single result row will be
    ///   consumed. Implementations can optionally use it to optimize the
    ///   generated SQL, for example by adding a `LIMIT 1` SQL clause.
    /// - returns: An SQL string.
    func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String
}

/// The protocol that can generate SQL requests and subqueries.
public protocol SQLRequestProtocol: _SQLRequestProtocol, SQLExpression, SQLCollection { }

// MARK: - SQLExpression

extension SQLRequestProtocol {
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        self
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - SQLCollection

extension SQLRequestProtocol {
    /// Returns an expression which applies the `IN` SQL operator.
    public func contains(_ value: SQLExpressible) -> SQLExpression {
        _SQLExpressionContains(value, self)
    }
    
    /// :nodoc:
    public func _qualifiedCollection(with alias: TableAlias) -> SQLCollection {
        self
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLCollectionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}
