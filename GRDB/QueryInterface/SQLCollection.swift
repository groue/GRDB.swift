// MARK: - SQLCollection

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
///
/// # Low Level Query Interface
///
/// SQLCollection is the protocol for types that can be checked for inclusion.
public protocol SQLCollection {
    /// This function is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// Returns an SQL string that represents the collection.
    ///
    /// When the arguments parameter is nil, any value must be written down as
    /// a literal in the returned SQL:
    ///
    ///     var arguments: StatementArguments? = nil
    ///     let collection = SQLExpressionsArray([1,2,3])
    ///     collection.collectionSQL(&arguments)  // "1,2,3"
    ///
    /// When the arguments parameter is not nil, then values may be replaced by
    /// `?` or colon-prefixed tokens, and fed into arguments.
    ///
    ///     var arguments = StatementArguments()
    ///     let collection = SQLExpressionsArray([1,2,3])
    ///     collection.collectionSQL(&arguments)  // "?,?,?"
    ///     arguments                             // [1,2,3]
    func collectionSQL(_ arguments: inout StatementArguments?) -> String
    
    /// Returns an expression that check whether the collection contains
    /// the expression.
    ///
    /// The default implementation returns a SQLExpressionContains which applies
    /// the `IN` operator:
    ///
    ///     let request = Person.select(Column("id"))
    ///     request.contains(Column("id"))   // id IN (SELECT id FROM persons)
    func contains(_ value: SQLExpressible) -> SQLExpression
}


// MARK: Default Implementations

extension SQLCollection {
    /// Returns a SQLExpressionContains which applies the `IN` operator:
    ///
    ///     let request = Person.select(Column("id"))
    ///     request.contains(Column("id"))   // id IN (SELECT id FROM persons)
    public func contains(_ value: SQLExpressible) -> SQLExpression {
        return SQLExpressionContains(value, self)
    }
}


// MARK: - SQLExpressionsArray

/// SQLExpressionsArray wraps an array of expressions
///
///     SQLExpressionsArray([1, 2, 3])
struct SQLExpressionsArray : SQLCollection {
    let expressions: [SQLExpression]
    
    init<S: Sequence>(_ expressions: S) where S.Iterator.Element : SQLExpressible {
        self.expressions = expressions.map { $0.sqlExpression }
    }
    
    func collectionSQL(_ arguments: inout StatementArguments?) -> String {
        return (expressions.map { $0.expressionSQL(&arguments) } as [String]).joined(separator: ", ")
    }
    
    func contains(_ value: SQLExpressible) -> SQLExpression {
        if expressions.isEmpty {
            return false.databaseValue
        } else {
            return SQLExpressionContains(value, self)
        }
    }
}
