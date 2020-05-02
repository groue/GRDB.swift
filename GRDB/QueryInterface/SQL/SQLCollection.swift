// MARK: - SQLCollection

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLCollection is the protocol for types that can be checked for inclusion.
///
/// :nodoc:
public protocol SQLCollection {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns an SQL string that represents the collection.
    func collectionSQL(_ context: SQLGenerationContext) throws -> String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns an expression that check whether the collection contains
    /// the expression.
    func contains(_ value: SQLExpressible) -> SQLExpression
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func qualifiedCollection(with alias: TableAlias) -> SQLCollection
}


// MARK: Default Implementations

/// :nodoc:
extension SQLCollection {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns a SQLExpressionContains which applies the `IN` SQL operator.
    public func contains(_ value: SQLExpressible) -> SQLExpression {
        SQLExpressionContains(value, self)
    }
}


// MARK: - SQLExpressionsArray

/// SQLExpressionsArray wraps an array of expressions
///
///     SQLExpressionsArray([1, 2, 3])
struct SQLExpressionsArray: SQLCollection {
    let expressions: [SQLExpression]
    
    func collectionSQL(_ context: SQLGenerationContext) throws -> String {
        try expressions
            .map { try $0.expressionSQL(context, wrappedInParenthesis: false) }
            .joined(separator: ", ")
    }
    
    func contains(_ value: SQLExpressible) -> SQLExpression {
        guard let expression = expressions.first else {
            // [].contains(Column("name")) => 0
            return false.databaseValue
        }
        if expressions.count == 1 {
            // ["foo"].contains(Column("name")) => name = 'foo'
            return value == expression
        }
        // ["foo", "bar"].contains(Column("name")) => name IN ('foo', 'bar')
        return SQLExpressionContains(value, self)
    }
    
    func qualifiedCollection(with alias: TableAlias) -> SQLCollection {
        SQLExpressionsArray(expressions: expressions.map { $0.qualifiedExpression(with: alias) })
    }
}
