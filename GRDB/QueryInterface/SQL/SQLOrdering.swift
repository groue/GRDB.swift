/// Implementation details of `SQLOrderingTerm`.
///
/// :nodoc:
public protocol _SQLOrderingTerm {
    /// The ordering term, reversed
    var _reversed: SQLOrderingTerm { get }
    
    /// Returns a qualified ordering
    func _qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm
    
    /// Returns the SQL that feeds the `ORDER BY` clause.
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func _orderingTermSQL(_ context: SQLGenerationContext) throws -> String
}

/// The protocol for all types that can be used as an SQL ordering term, as
/// described at https://www.sqlite.org/syntax/ordering-term.html
public protocol SQLOrderingTerm: _SQLOrderingTerm { }

/// :nodoc:
enum SQLOrdering: SQLOrderingTerm, Refinable {
    case asc(SQLExpression)
    case desc(SQLExpression)
    
    // Only available from SQLite 3.30.0. This enum is not public, so those
    // cases don't harm as long as we don't expose them through public APIs.
    case ascNullsLast(SQLExpression)
    case descNullsFirst(SQLExpression)
    
    var expression: SQLExpression {
        get {
            switch self {
            case .asc(let expression):
                return expression
            case .desc(let expression):
                return expression
            case .ascNullsLast(let expression):
                return expression
            case .descNullsFirst(let expression):
                return expression
            }
        }
        set {
            switch self {
            case .asc:
                self = .asc(newValue)
            case .desc:
                self = .desc(newValue)
            case .ascNullsLast:
                self = .ascNullsLast(newValue)
            case .descNullsFirst:
                self = .descNullsFirst(newValue)
            }
        }
    }
    
    func _orderingTermSQL(_ context: SQLGenerationContext) throws -> String {
        switch self {
        case .asc(let expression):
            return try expression._expressionSQL(context, wrappedInParenthesis: false) + " ASC"
        case .desc(let expression):
            return try expression._expressionSQL(context, wrappedInParenthesis: false) + " DESC"
        case .ascNullsLast(let expression):
            return try expression._expressionSQL(context, wrappedInParenthesis: false) + " ASC NULLS LAST"
        case .descNullsFirst(let expression):
            return try expression._expressionSQL(context, wrappedInParenthesis: false) + " DESC NULLS FIRST"
        }
    }
    
    func _qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm {
        map(\.expression) { $0._qualifiedExpression(with: alias) }
    }
    
    var _reversed: SQLOrderingTerm {
        switch self {
        case .asc(let expression):
            return SQLOrdering.desc(expression)
        case .desc(let expression):
            return SQLOrdering.asc(expression)
        case .ascNullsLast(let expression):
            return SQLOrdering.descNullsFirst(expression)
        case .descNullsFirst(let expression):
            return SQLOrdering.ascNullsLast(expression)
        }
    }
}
