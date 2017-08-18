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
public protocol SQLExpression : SQLSpecificExpressible, SQLSelectable, SQLOrderingTerm {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns an SQL string that represents the expression.
    ///
    /// When the arguments parameter is nil, any value must be written down as
    /// a literal in the returned SQL:
    ///
    ///     var arguments: StatementArguments? = nil
    ///     let expression = "foo'bar".databaseValue
    ///     expression.expressionSQL(&arguments)  // "'foo''bar'"
    ///
    /// When the arguments parameter is not nil, then values may be replaced by
    /// `?` or colon-prefixed tokens, and fed into arguments.
    ///
    ///     var arguments = StatementArguments()
    ///     let expression = "foo'bar".databaseValue
    ///     expression.expressionSQL(&arguments)  // "?"
    ///     arguments                             // ["foo'bar"]
    func expressionSQL(_ arguments: inout StatementArguments?) -> String
    
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
}

extension SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The default implementation returns the expression prefixed by `NOT`.
    ///
    ///     let column = Column("favorite")
    ///     column.negated  // NOT favorite
    ///
    public var negated: SQLExpression {
        return SQLExpressionNot(self)
    }
}

// SQLExpression: SQLExpressible

extension SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public var sqlExpression: SQLExpression {
        return self
    }
}

// SQLExpression: SQLSelectable

extension SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
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
    
    func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return "NOT \(expression.expressionSQL(&arguments))"
    }
    
    var negated: SQLExpression {
        return expression
    }
}
