/// SQLCollatedExpression taints an expression so that every derived expression
/// is eventually evaluated using an SQLite collation.
///
/// You create one by calling the SQLSpecificExpressible.collating() method.
///
///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
///
///     // SELECT * FROM player WHERE email = 'arthur@example.com' COLLATE NOCASE
///     Player.filter(email == "arthur@example.com")
///
/// :nodoc:
public struct SQLCollatedExpression {
    /// The tainted expression
    public let expression: SQLExpression
    
    /// The name of the collation
    public let collationName: Database.CollationName
    
    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM player ORDER BY email COLLATE NOCASE ASC
    ///     Player.order(email.asc)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: SQLOrderingTerm {
        SQLOrdering.asc(sqlExpression)
    }
    
    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM player ORDER BY email COLLATE NOCASE DESC
    ///     Player.order(email.desc)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: SQLOrderingTerm {
        SQLOrdering.desc(sqlExpression)
    }
    
    #if GRDBCUSTOMSQLITE
    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM player ORDER BY email COLLATE NOCASE ASC NULLS LAST
    ///     Player.order(email.ascNullsLast)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var ascNullsLast: SQLOrderingTerm {
        SQLOrdering.ascNullsLast(sqlExpression)
    }
    
    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM player ORDER BY email COLLATE NOCASE DESC NULLS FIRST
    ///     Player.order(email.descNullsFirst)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var descNullsFirst: SQLOrderingTerm {
        SQLOrdering.descNullsFirst(sqlExpression)
    }
    #endif
    
    init(_ expression: SQLExpression, collationName: Database.CollationName) {
        self.expression = expression
        self.collationName = collationName
    }
    
    var sqlExpression: SQLExpression {
        SQLExpressionCollate(expression, collationName: collationName)
    }
}

/// :nodoc:
extension SQLCollatedExpression: SQLOrderingTerm {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public var reversed: SQLOrderingTerm {
        desc
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func orderingTermSQL(_ context: SQLGenerationContext) throws -> String {
        try sqlExpression.orderingTermSQL(context)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm {
        SQLCollatedExpression(expression.qualifiedExpression(with: alias), collationName: collationName)
    }
}
