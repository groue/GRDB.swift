// MARK: - SQLOrderingTerm

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The protocol for all types that can be used as an SQL ordering term, as
/// described at https://www.sqlite.org/syntax/ordering-term.html
public protocol SQLOrderingTerm {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The ordering term, reversed
    var reversed: SQLOrderingTerm { get }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns an SQL string that represents the ordering term.
    ///
    /// When the arguments parameter is nil, any value must be written down as
    /// a literal in the returned SQL:
    ///
    ///     var arguments: StatementArguments? = nil
    ///     let orderingTerm = Column("name") ?? "Anonymous"
    ///     orderingTerm.orderingTermSQL(&arguments) // "IFNULL(name, 'Anonymous')"
    ///
    /// When the arguments parameter is not nil, then values may be replaced by
    /// `?` or colon-prefixed tokens, and fed into arguments.
    ///
    ///     var arguments = StatementArguments()
    ///     let orderingTerm = Column("name") ?? "Anonymous"
    ///     orderingTerm.orderingTermSQL(&arguments) // "IFNULL(name, ?)"
    ///     arguments                                // ["Anonymous"]
    func orderingTermSQL(_ arguments: inout StatementArguments?) -> String
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
    
    func orderingTermSQL(_ arguments: inout StatementArguments?) -> String {
        switch self {
        case .asc(let expression):
            return expression.expressionSQL(&arguments) + " ASC"
        case .desc(let expression):
            return expression.expressionSQL(&arguments) + " DESC"
        }
    }
}
