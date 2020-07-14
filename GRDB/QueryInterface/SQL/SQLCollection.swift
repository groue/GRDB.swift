// MARK: - SQLCollection

/// Implementation details of `SQLCollection`.
///
/// :nodoc:
public protocol _SQLCollection {
    /// Returns a qualified collection
    func _qualifiedCollection(with alias: TableAlias) -> SQLCollection
    
    /// Accepts a visitor
    func _accept<Visitor: _SQLCollectionVisitor>(_ visitor: inout Visitor) throws
}

/// SQLCollection is the protocol for types that can be checked for inclusion.
public protocol SQLCollection: _SQLCollection {
    /// Returns an expression that check whether the collection contains
    /// the expression.
    func contains(_ value: SQLExpressible) -> SQLExpression
}

// MARK: - _SQLExpressionsArray

/// _SQLExpressionsArray wraps an array of expressions
///
///     _SQLExpressionsArray([1, 2, 3])
///
/// :nodoc:
public struct _SQLExpressionsArray: SQLCollection {
    let expressions: [SQLExpression]
    
    public func contains(_ value: SQLExpressible) -> SQLExpression {
        guard let expression = expressions.first else {
            return false.databaseValue
        }
        
        // With SQLite, `expr IN (NULL)` never succeeds.
        //
        // We must not provide special handling of NULL, because we can not
        // guess if our `expressions` array contains a value evaluates to NULL.
        
        if expressions.count == 1 {
            // Output `expr = value` instead of `expr IN (value)`, because it
            // looks nicer. And make sure we do not produce 'expr IS NULL'.
            return _SQLExpressionEqual(.equal, value.sqlExpression, expression)
        }
        
        return _SQLExpressionContains(value, self)
    }
    
    /// :nodoc:
    public func _qualifiedCollection(with alias: TableAlias) -> SQLCollection {
        _SQLExpressionsArray(expressions: expressions.map { $0._qualifiedExpression(with: alias) })
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLCollectionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - SQLCollectionExpressions

extension SQLCollection {
    func expressions() -> [SQLExpression]? {
        var visitor = SQLCollectionExpressions()
        try! _accept(&visitor)
        return visitor.expressions
    }
}

/// Support for SQLCollection.expressions
private struct SQLCollectionExpressions: _SQLCollectionVisitor {
    var expressions: [SQLExpression]?
    
    mutating func visit(_ collection: _SQLExpressionsArray) throws {
        expressions = collection.expressions
    }
    
    // MARK: _FetchRequestVisitor
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws { }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws { }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws { }
}
