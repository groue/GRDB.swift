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

enum SQLOrdering : SQLOrderingTerm {
    case asc(SQLExpression)
    case desc(SQLExpression)
    
    var reversed: SQLOrderingTerm {
        switch self {
        case .asc(let expression):
            return SQLOrdering.desc(expression)
        case .desc(let expression):
            return SQLOrdering.asc(expression)
        }
    }
    
    func orderingTermSQL(_ context: inout SQLGenerationContext) -> String {
        switch self {
        case .asc(let expression):
            return expression.expressionSQL(&context) + " ASC"
        case .desc(let expression):
            return expression.expressionSQL(&context) + " DESC"
        }
    }
    
    func qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm {
        switch self {
        case .asc(let expression):
            return SQLOrdering.asc(expression.qualifiedExpression(with: alias))
        case .desc(let expression):
            return SQLOrdering.desc(expression.qualifiedExpression(with: alias))
        }
    }
}
