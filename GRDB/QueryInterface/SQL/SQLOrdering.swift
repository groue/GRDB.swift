/// The type that can be used as an SQL ordering term, as described at
/// https://www.sqlite.org/syntax/ordering-term.html
public struct SQLOrdering {
    private var impl: Impl
    
    private enum Impl {
        /// An expression
        ///
        ///     ORDER BY score
        case expression(SQLExpression)
        
        /// An ascending expression
        ///
        ///     ORDER BY score ASC
        case asc(SQLExpression)
        
        /// An descending expression
        ///
        ///     ORDER BY score DESC
        case desc(SQLExpression)
        
        /// Only available from SQLite 3.30.0
        case ascNullsLast(SQLExpression)
        
        /// Only available from SQLite 3.30.0
        case descNullsFirst(SQLExpression)
        
        /// A literal SQL ordering
        case literal(SQL)
    }
    
    static func expression(_ expression: SQLExpression) -> SQLOrdering {
        self.init(impl: .expression(expression))
    }
    
    static func asc(_ expression: SQLExpression) -> SQLOrdering {
        self.init(impl: .asc(expression))
    }
    
    static func desc(_ expression: SQLExpression) -> SQLOrdering {
        self.init(impl: .desc(expression))
    }
    
    static func ascNullsLast(_ expression: SQLExpression) -> SQLOrdering {
        self.init(impl: .ascNullsLast(expression))
    }
    
    static func descNullsFirst(_ expression: SQLExpression) -> SQLOrdering {
        self.init(impl: .descNullsFirst(expression))
    }
    
    static func literal(_ sqlLiteral: SQL) -> SQLOrdering {
        self.init(impl: .literal(sqlLiteral))
    }
}

extension SQLOrdering {
    func sql(_ context: SQLGenerationContext) throws -> String {
        switch impl {
        case .expression(let expression):
            return try expression.sql(context)
        case .asc(let expression):
            return try expression.sql(context) + " ASC"
        case .desc(let expression):
            return try expression.sql(context) + " DESC"
        case .ascNullsLast(let expression):
            return try expression.sql(context) + " ASC NULLS LAST"
        case .descNullsFirst(let expression):
            return try expression.sql(context) + " DESC NULLS FIRST"
        case .literal(let literal):
            return try literal.sql(context)
        }
    }
}

extension SQLOrdering {
    func qualified(with alias: TableAlias) -> SQLOrdering {
        switch impl {
        case .expression(let expression):
            return .expression(expression.qualified(with: alias))
        case .asc(let expression):
            return .asc(expression.qualified(with: alias))
        case .desc(let expression):
            return .desc(expression.qualified(with: alias))
        case .ascNullsLast(let expression):
            return .ascNullsLast(expression.qualified(with: alias))
        case .descNullsFirst(let expression):
            return .descNullsFirst(expression.qualified(with: alias))
        case .literal(let literal):
            return .literal(literal.qualified(with: alias))
        }
    }
}

extension SQLOrdering {
    var reversed: SQLOrdering {
        switch impl {
        case .expression(let expression):
            return .desc(expression)
        case .asc(let expression):
            return .desc(expression)
        case .desc(let expression):
            return .asc(expression)
        case .ascNullsLast(let expression):
            return .descNullsFirst(expression)
        case .descNullsFirst(let expression):
            return .ascNullsLast(expression)
        case .literal:
            fatalError("""
                Ordering literals can't be reversed. \
                To resolve this error, order by expression literals instead.
                """)
        }
    }
}

// MARK: - SQLOrderingTerm

/// The protocol for all types that can be used as an SQL ordering term, as
/// described at https://www.sqlite.org/syntax/ordering-term.html
public protocol SQLOrderingTerm {
    /// Returns an SQL ordering.
    var sqlOrdering: SQLOrdering { get }
}

extension SQLOrdering: SQLOrderingTerm {
    // Not a real deprecation, just a usage warning
    @available(*, deprecated, message: "Already QLOrdering:")
    public var sqlOrdering: SQLOrdering { self }
}
