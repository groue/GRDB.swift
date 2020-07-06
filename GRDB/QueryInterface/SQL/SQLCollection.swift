// MARK: - SQLCollection

/// Implementation details of SQLCollection.
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
            // [].contains(Column("name")) => 0
            return false.databaseValue
        }
        if expressions.count == 1 {
            #warning("TODO: make sure we do not produce 'column IS NULL'")
            // ["foo"].contains(Column("name")) => name = 'foo'
            return value == expression
        }
        // ["foo", "bar"].contains(Column("name")) => name IN ('foo', 'bar')
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
