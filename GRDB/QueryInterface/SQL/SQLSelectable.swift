// MARK: - SQLSelectable

/// Implementation details of `SQLSelectable`.
///
/// :nodoc:
public protocol _SQLSelectable {
    /// If the selectable can be counted, return how to count it.
    func _count(distinct: Bool) -> _SQLCount?
    
    /// Returns the number of columns in the selectable.
    func _columnCount(_ db: Database) throws -> Int

    /// Returns a qualified selectable
    func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable
    
    /// Accepts a visitor
    func _accept<Visitor: _SQLSelectableVisitor>(_ visitor: inout Visitor) throws
}

/// SQLSelectable is the protocol for types that can be selected, as
/// described at https://www.sqlite.org/syntax/result-column.html
///
/// :nodoc:
public protocol SQLSelectable: _SQLSelectable { }

// MARK: - Counting

/// :nodoc:
public enum _SQLCount {
    /// Represents `COUNT(*)`
    case all
    
    /// Represents `COUNT(DISTINCT expression)`
    case distinct(SQLExpression)
}
