// MARK: - SQLExpression

/// Implementation details of `SQLExpression`.
///
/// :nodoc:
public protocol _SQLExpression {
    /// Returns the expression, negated. This property fuels the `!` operator.
    ///
    /// The default implementation returns the expression prefixed by `NOT`.
    ///
    ///     let column = Column("favorite")
    ///     column.negated  // NOT favorite
    ///
    /// Some expressions may provide a custom implementation that returns a
    /// more natural SQL expression.
    ///
    ///     let expression = [1,2,3].contains(Column("id")) // id IN (1,2,3)
    ///     expression.negated // id NOT IN (1,2,3)
    var _negated: SQLExpression { get }
    
    /// Returns a qualified expression
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression
    
    /// Accepts a visitor
    func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws
}

/// SQLExpression is the protocol for types that represent an SQL expression, as
/// described at https://www.sqlite.org/lang_expr.html
public protocol SQLExpression: _SQLExpression, SQLSpecificExpressible, SQLSelectable, SQLOrderingTerm { }

extension SQLExpression {
    /// :nodoc:
    public func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        _qualifiedExpression(with: alias)
    }
    
    /// :nodoc:
    public func _qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm {
        _qualifiedExpression(with: alias)
    }
}

// SQLExpression: SQLExpressible

extension SQLExpression {
    /// :nodoc:
    public var sqlExpression: SQLExpression {
        self
    }
}

// SQLExpression: SQLSelectable

extension SQLExpression {
    /// :nodoc:
    public func _count(distinct: Bool) -> _SQLCount? {
        if distinct {
            // SELECT DISTINCT expr FROM tableName ...
            // ->
            // SELECT COUNT(DISTINCT expr) FROM tableName ...
            return .distinct(self)
        } else {
            // SELECT expr FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            return .all
        }
    }
}
