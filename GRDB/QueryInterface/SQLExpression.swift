// MARK: - SQLExpression

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpression is the protocol for types that represent an SQL expression, as
/// described at https://www.sqlite.org/lang_expr.html
///
/// GRDB ships with a variety of types that already adopt this protocol, and
/// allow to represent many SQLite expressions:
///
/// - Column
/// - DatabaseValue
/// - SQLExpressionLiteral
/// - SQLExpressionUnary
/// - SQLExpressionBinary
/// - SQLExpressionExists
/// - SQLExpressionFunction
/// - SQLExpressionCollate
///
/// :nodoc:
public protocol SQLExpression : SQLSpecificExpressible, SQLSelectable, SQLOrderingTerm {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns an SQL string that represents the expression.
    func expressionSQL(_ context: inout SQLGenerationContext) -> String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
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
    var negated: SQLExpression { get }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns the rowIds matched by the expression.
    func matchedRowIds(rowIdName: String?) -> Set<Int64>? // FIXME: this method should take TableAlias in account
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression
}

extension SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The default implementation returns the expression prefixed by `NOT`.
    ///
    ///     let column = Column("favorite")
    ///     column.negated  // NOT favorite
    ///
    /// :nodoc:
    public var negated: SQLExpression {
        return SQLExpressionNot(self)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The default implementation returns nil
    ///
    /// :nodoc:
    public func matchedRowIds(rowIdName: String?) -> Set<Int64>? {
        return nil
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The default implementation returns qualifiedExpression(with:)
    ///
    /// :nodoc:
    public func qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        return qualifiedExpression(with: alias)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The default implementation returns qualifiedExpression(with:)
    ///
    /// :nodoc:
    public func qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm {
        return qualifiedExpression(with: alias)
    }
}

// SQLExpression: SQLExpressible

extension SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public var sqlExpression: SQLExpression {
        return self
    }
}

// SQLExpression: SQLSelectable

extension SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func count(distinct: Bool) -> SQLCount? {
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

// MARK: - SQLExpressionNot

struct SQLExpressionNot : SQLExpression {
    let expression: SQLExpression
    
    init(_ expression: SQLExpression) {
        self.expression = expression
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        return "NOT \(expression.expressionSQL(&context))"
    }
    
    var negated: SQLExpression {
        return expression
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionNot(expression.qualifiedExpression(with: alias))
    }
    
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return SQLExpressionNot(expression.resolvedExpression(inContext: context))
    }
}
