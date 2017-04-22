// MARK: - SQLSelectable

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
///
/// # Low Level Query Interface
///
/// SQLSelectable is the protocol for types that can be selected, as
/// described at https://www.sqlite.org/syntax/result-column.html
public protocol SQLSelectable {
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String
    func countedSQL(_ arguments: inout StatementArguments?) -> String
    func count(distinct: Bool) -> SQLCount?
}

// MARK: - Counting

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public enum SQLCount {
    /// Represents COUNT(*)
    case star
    
    /// Represents COUNT(DISTINCT expression)
    case distinct(SQLExpression)
}
