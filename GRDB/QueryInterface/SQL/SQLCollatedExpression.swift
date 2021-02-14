/// SQLCollatedExpression taints an expression so that every derived expression
/// is eventually evaluated using an SQLite collation.
///
/// You create one by calling the `collating()` method:
///
///     let email = Column("email").collating(.nocase)
///
///     // SELECT * FROM player WHERE email = 'arthur@example.com' COLLATE NOCASE
///     Player.filter(email == "arthur@example.com")
public struct SQLCollatedExpression: SQLOrderingTerm {
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
    public var asc: SQLOrdering {
        .asc(sqlExpression)
    }

    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM player ORDER BY email COLLATE NOCASE DESC
    ///     Player.order(email.desc)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: SQLOrdering {
        .desc(sqlExpression)
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
    public var ascNullsLast: SQLOrdering {
        .ascNullsLast(sqlExpression)
    }

    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM player ORDER BY email COLLATE NOCASE DESC NULLS FIRST
    ///     Player.order(email.descNullsFirst)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var descNullsFirst: SQLOrdering {
        .descNullsFirst(sqlExpression)
    }
    #elseif !GRDBCIPHER
    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM player ORDER BY email COLLATE NOCASE ASC NULLS LAST
    ///     Player.order(email.ascNullsLast)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    @available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *)
    public var ascNullsLast: SQLOrdering {
        .ascNullsLast(sqlExpression)
    }

    /// Returns an ordering suitable for QueryInterfaceRequest.order()
    ///
    ///     let email: SQLCollatedExpression = Column("email").collating(.nocase)
    ///
    ///     // SELECT * FROM player ORDER BY email COLLATE NOCASE DESC NULLS FIRST
    ///     Player.order(email.descNullsFirst)
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    @available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *)
    public var descNullsFirst: SQLOrdering {
        .descNullsFirst(sqlExpression)
    }
    #endif

    init(_ expression: SQLExpression, collationName: Database.CollationName) {
        self.expression = expression
        self.collationName = collationName
    }
    
    var sqlExpression: SQLExpression {
        .collated(expression, collationName)
    }
    
    public var sqlOrdering: SQLOrdering {
        .expression(sqlExpression)
    }
}
