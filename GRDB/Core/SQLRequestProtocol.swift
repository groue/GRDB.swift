/// The protocol that can generate SQL requests and subqueries.
public protocol SQLRequestProtocol: SQLExpression, SQLCollection {
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

// MARK: - SQLExpression

extension SQLRequestProtocol {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        let sql = try requestSQL(context, forSingleResult: false)
        return "(\(sql))"
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        self
    }
}

// MARK: - SQLCollection

extension SQLRequestProtocol {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func collectionSQL(_ context: SQLGenerationContext) throws -> String {
        try requestSQL(context, forSingleResult: false)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedCollection(with alias: TableAlias) -> SQLCollection {
        self
    }
}
