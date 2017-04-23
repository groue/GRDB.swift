// MARK: - SQLExpressible

/// The protocol for all types that can be turned into an SQL expression.
///
/// It is adopted by protocols like DatabaseValueConvertible, and types
/// like Column.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol SQLExpressible {
    /// Returns an SQLExpression
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    var sqlExpression: SQLExpression { get }
}

// MARK: - SQLSpecificExpressible

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

// MARK: - SQLExpressible & SQLOrderingTerm

extension SQLExpressible where Self: SQLOrderingTerm {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLOrderingTerm.reversed
    public var reversed: SQLOrderingTerm {
        return SQLOrdering.desc(sqlExpression)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLOrderingTerm.orderingTermSQL(_)
    public func orderingTermSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.expressionSQL(&arguments)
    }
}

// MARK: - SQLExpressible & SQLSelectable

extension SQLExpressible where Self: SQLSelectable {
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLSelectable.resultColumnSQL(_)
    public func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.expressionSQL(&arguments)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLSelectable.countedSQL(_)
    public func countedSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.expressionSQL(&arguments)
    }
    
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLSelectable.count(distinct:from:aliased:)
    public func count(distinct: Bool) -> SQLCount? {
        return sqlExpression.count(distinct: distinct)
    }
}
