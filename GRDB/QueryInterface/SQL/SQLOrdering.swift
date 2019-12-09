// MARK: - SQLOrderingTerm

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The protocol for all types that can be used as an SQL ordering term, as
/// described at https://www.sqlite.org/syntax/ordering-term.html
///
/// :nodoc:
public protocol SQLOrderingTerm {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The ordering term, reversed
    var reversed: SQLOrderingTerm { get }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns an SQL string that represents the ordering term.
    func orderingTermSQL(_ context: inout SQLGenerationContext) -> String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm
}

// MARK: - SQLOrdering

enum SQLOrdering: SQLOrderingTerm {
    case asc(SQLExpression)
    case desc(SQLExpression)
    #if GRDBCUSTOMSQLITE
    case ascNullsLast(SQLExpression)
    case descNullsFirst(SQLExpression)
    #endif
    
    var reversed: SQLOrderingTerm {
        switch self {
        case .asc(let expression):
            return SQLOrdering.desc(expression)
        case .desc(let expression):
            return SQLOrdering.asc(expression)
            #if GRDBCUSTOMSQLITE
        case .ascNullsLast(let expression):
            return SQLOrdering.descNullsFirst(expression)
        case .descNullsFirst(let expression):
            return SQLOrdering.ascNullsLast(expression)
            #endif
        }
    }
    
    func orderingTermSQL(_ context: inout SQLGenerationContext) -> String {
        switch self {
        case .asc(let expression):
            return expression.expressionSQL(&context, wrappedInParenthesis: false) + " ASC"
        case .desc(let expression):
            return expression.expressionSQL(&context, wrappedInParenthesis: false) + " DESC"
            #if GRDBCUSTOMSQLITE
        case .ascNullsLast(let expression):
            return expression.expressionSQL(&context, wrappedInParenthesis: false) + " ASC NULLS LAST"
        case .descNullsFirst(let expression):
            return expression.expressionSQL(&context, wrappedInParenthesis: false) + " DESC NULLS FIRST"
            #endif
        }
    }
    
    func qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm {
        switch self {
        case .asc(let expression):
            return SQLOrdering.asc(expression.qualifiedExpression(with: alias))
        case .desc(let expression):
            return SQLOrdering.desc(expression.qualifiedExpression(with: alias))
            #if GRDBCUSTOMSQLITE
        case .ascNullsLast(let expression):
            return SQLOrdering.ascNullsLast(expression.qualifiedExpression(with: alias))
        case .descNullsFirst(let expression):
            return SQLOrdering.descNullsFirst(expression.qualifiedExpression(with: alias))
            #endif
        }
    }
}
