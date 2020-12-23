// MARK: - SQLExpressible

/// `SQLExpressible` is the protocol for all types that can be used as an
/// SQL expression.
///
/// It is adopted by protocols like `DatabaseValueConvertible`, and types
/// like `Column`.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol SQLExpressible {
    /// Returns an SQL expression.
    var sqlExpression: SQLExpression { get }
}

// MARK: - SQLSpecificExpressible

/// SQLSpecificExpressible is a protocol for all database-specific types that can
/// be turned into an SQL expression. Types whose existence is not purely
/// dedicated to the database should adopt the SQLExpressible protocol instead.
///
/// For example, Column is a type that only exists to help you build requests,
/// and it adopts SQLSpecificExpressible.
///
/// On the other side, Int adopts SQLExpressible (via DatabaseValueConvertible).
///
/// :nodoc:
public protocol SQLSpecificExpressible: SQLExpressible {
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
