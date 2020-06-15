// MARK: - SQLExpression

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpression is the protocol for types that represent an SQL expression, as
/// described at https://www.sqlite.org/lang_expr.html
///
/// :nodoc:
public protocol SQLExpression: SQLSpecificExpressible, SQLSelectable, SQLOrderingTerm {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns an SQL string that represents the expression.
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    /// - parameter wrappedInParenthesis: If true, the returned SQL should be
    ///   wrapped inside parenthesis.
    func expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String
    
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
    ///
    /// The elements of the returned array, when joined with the AND operator,
    /// are guaranteed to have the same truth value as the receiver.
    ///
    /// Those truth components allow easier introspection of the expression.
    /// For example:
    ///
    ///     // No change:
    ///     // [Column("a")]
    ///     Column("a").truthComponents
    ///
    ///     // Erase a SQLExpressionBinaryReduce `and` expression:
    ///     // [Column("a"), Column("b")]
    ///     [Column("a"), Column("b")].joined(operator: .and).truthComponents
    ///
    ///     // Erase a SQLExpressionBinaryReduce `or` expression:
    ///     // [Column("a")]
    ///     [Column("a")].joined(operator: .or).truthComponents
    var truthComponents: [SQLExpression] { get }
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
        SQLExpressionNot(self)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The default implementation returns nil
    ///
    /// :nodoc:
    public func matchedRowIds(rowIdName: String?) -> Set<Int64>? {
        nil
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The default implementation returns qualifiedExpression(with:)
    ///
    /// :nodoc:
    public func qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        qualifiedExpression(with: alias)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The default implementation returns qualifiedExpression(with:)
    ///
    /// :nodoc:
    public func qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm {
        qualifiedExpression(with: alias)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The default implementation returns [self]
    ///
    /// :nodoc:
    public var truthComponents: [SQLExpression] { [self] }
}

// SQLExpression: SQLExpressible

extension SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public var sqlExpression: SQLExpression {
        self
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

struct SQLExpressionNot: SQLExpression {
    let expression: SQLExpression
    
    init(_ expression: SQLExpression) {
        self.expression = expression
    }
    
    func expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        if wrappedInParenthesis {
            return try "(\(expressionSQL(context, wrappedInParenthesis: false)))"
        }
        return try "NOT \(expression.expressionSQL(context, wrappedInParenthesis: true))"
    }
    
    var negated: SQLExpression {
        expression
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionNot(expression.qualifiedExpression(with: alias))
    }
}
