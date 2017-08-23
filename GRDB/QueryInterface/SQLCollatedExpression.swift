/// SQLCollatedExpression taints an expression so that every derived expression
/// is eventually evaluated using an SQLite collation.
///
/// You create one by calling the SQLSpecificExpressible.collating() method.
///
///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
///
///     // SELECT * FROM players WHERE email = 'arthur@example.com' COLLATE NOCASE
///     Players.filter(email == "arthur@example.com")
public struct SQLCollatedExpression {
    /// The tainted expression
    public let expression: SQLExpression
    
    /// The name of the collation
    public let collationName: Database.CollationName
    
    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM players ORDER BY email COLLATE NOCASE ASC
    ///     Players.order(email.asc)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: SQLOrderingTerm {
        return SQLOrdering.asc(sqlExpression)
    }
    
    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM players ORDER BY email COLLATE NOCASE DESC
    ///     Players.order(email.desc)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: SQLOrderingTerm {
        return SQLOrdering.desc(sqlExpression)
    }
    
    init(_ expression: SQLExpression, collationName: Database.CollationName) {
        self.expression = expression
        self.collationName = collationName
    }
    
    var sqlExpression: SQLExpression {
        return SQLExpressionCollate(expression, collationName: collationName)
    }
}

extension SQLCollatedExpression : SQLOrderingTerm {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public var reversed: SQLOrderingTerm {
        return desc
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func orderingTermSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.orderingTermSQL(&arguments)
    }
}
