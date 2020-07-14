extension SQLCollection {
    /// Returns an SQL string that represents the collection.
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func collectionSQL(_ context: SQLGenerationContext) throws -> String {
        var generator = SQLCollectionGenerator(context: context)
        try _accept(&generator)
        return generator.resultSQL
    }
}

private struct SQLCollectionGenerator: _SQLCollectionVisitor {
    let context: SQLGenerationContext
    var resultSQL = ""
    
    mutating func visit(_ collection: _SQLExpressionsArray) throws {
        resultSQL = try collection.expressions
            .map { try $0.expressionSQL(context, wrappedInParenthesis: false) }
            .joined(separator: ", ")
    }
    
    // MARK: _FetchRequestVisitor
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws {
        resultSQL = try request.requestSQL(context, forSingleResult: false)
    }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws {
        resultSQL = try request.requestSQL(context, forSingleResult: false)
    }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws {
        resultSQL = try request.requestSQL(context, forSingleResult: false)
    }
}
