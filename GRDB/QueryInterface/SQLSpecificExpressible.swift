/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
///
/// # Low Level Query Interface
///
/// SQLSpecificExpressible is a protocol for all query interface types that can
/// be turned into an SQL expression. Other types whose existence is not purely
/// dedicated to the query interface should adopt the SQLExpressible
/// protocol instead.
///
/// For example, Column is a type that only exists to help you build requests,
/// and it adopts SQLSpecificExpressible.
///
/// On the other side, Int adopts SQLExpressible (via DatabaseValueConvertible).
public protocol SQLSpecificExpressible : SQLExpressible {
    // SQLExpressible can be adopted by Swift standard types, and user
    // types, through the DatabaseValueConvertible protocol which inherits
    // from SQLExpressible.
    //
    // For example, Int adopts SQLExpressible through
    // DatabaseValueConvertible.
    //
    // SQLSpecificExpressible, on the other side, is not adopted by any
    // Swift standard type or any user type. It is only adopted by GRDB types,
    // such as Column and SQLExpression.
    //
    // This separation lets us define functions and operators that do not
    // spill out. The three declarations below have no chance overloading a
    // Swift-defined operator, or a user-defined operator:
    //
    // - ==(SQLExpressible, SQLSpecificExpressible)
    // - ==(SQLSpecificExpressible, SQLExpressible)
    // - ==(SQLSpecificExpressible, SQLSpecificExpressible)
}


// MARK: - SQL Ordering Support

extension SQLSpecificExpressible {
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: SQLOrderingTerm {
        return SQLOrdering.asc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: SQLOrderingTerm {
        return SQLOrdering.desc(sqlExpression)
    }
}


// MARK: - SQL Selection Support

extension SQLSpecificExpressible {
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.select()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func aliased(_ alias: String) -> SQLSelectable {
        return SQLAliasedExpression(sqlExpression, alias: alias)
    }
}


// MARK: - SQL Collations Support

extension SQLSpecificExpressible {
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func collating(_ collation: Database.CollationName) -> SQLCollatedExpression {
        return SQLCollatedExpression(sqlExpression, collationName: collation)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func collating(_ collation: DatabaseCollation) -> SQLCollatedExpression {
        return SQLCollatedExpression(sqlExpression, collationName: Database.CollationName(collation.name))
    }
}

