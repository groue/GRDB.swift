/// SQLCollatedExpression taints an expression so that every derived expression
/// is eventually evaluated using an SQLite collation.
///
/// You create one by calling the SQLSpecificExpressible.collating() method.
///
///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
///
///     // SELECT * FROM persons WHERE email = 'arthur@example.com' COLLATE NOCASE
///     Persons.filter(email == "arthur@example.com")
public struct SQLCollatedExpression {
    /// The tainted expression
    public let expression: SQLExpression
    
    /// The name of the collation
    public let collationName: Database.CollationName
    
    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM persons ORDER BY email COLLATE NOCASE ASC
    ///     Persons.order(email.asc)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: SQLOrderingTerm {
        return SQLOrdering.asc(sqlExpression)
    }
    
    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM persons ORDER BY email COLLATE NOCASE DESC
    ///     Persons.order(email.desc)
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
    
    /// Returns self.desc
    public var reversed: SQLOrderingTerm {
        return desc
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func orderingTermSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.orderingTermSQL(&arguments)
    }
}
