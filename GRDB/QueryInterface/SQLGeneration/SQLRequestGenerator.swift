extension _FetchRequest {
    /// Returns the request SQL.
    ///
    /// - parameter context: An SQL generation context.
    /// - parameter singleResult: A hint that a single result row will be
    ///   consumed. Implementations can optionally use it to optimize the
    ///   generated SQL, for example by adding a `LIMIT 1` SQL clause.
    /// - returns: An SQL string.
    func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
        var visitor = SQLRequestGenerator(context: context, forSingleResult: singleResult)
        try _accept(&visitor)
        return visitor.sql
    }
}

private struct SQLRequestGenerator: _FetchRequestVisitor {
    let context: SQLGenerationContext
    let singleResult: Bool
    var sql = ""
    
    init(context: SQLGenerationContext, forSingleResult singleResult: Bool) {
        self.context = context
        self.singleResult = singleResult
    }
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws {
        try request.base._accept(&self)
    }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws {
        let generator = SQLQueryGenerator(query: request.query, forSingleResult: singleResult)
        sql = try generator.requestSQL(context)
    }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws {
        sql = try request.sqlLiteral.sql(context)
    }
}
