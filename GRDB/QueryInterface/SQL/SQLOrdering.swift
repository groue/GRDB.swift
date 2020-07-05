// MARK: - SQLOrderingTerm

/// Implementation details of SQLOrderingTerm.
///
/// :nodoc:
public protocol _SQLOrderingTerm {
    /// The ordering term, reversed
    var _reversed: SQLOrderingTerm { get }
    
    /// Returns a qualified ordering
    func _qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm
    
    /// Accepts a visitor
    func _accept<Visitor: _SQLOrderingVisitor>(_ visitor: inout Visitor) throws
}

/// The protocol for all types that can be used as an SQL ordering term, as
/// described at https://www.sqlite.org/syntax/ordering-term.html
///
public protocol SQLOrderingTerm: _SQLOrderingTerm { }

// MARK: - _SQLOrdering

/// :nodoc:
public enum _SQLOrdering: SQLOrderingTerm {
    case asc(SQLExpression)
    case desc(SQLExpression)
    #if GRDBCUSTOMSQLITE
    case ascNullsLast(SQLExpression)
    case descNullsFirst(SQLExpression)
    #endif
    
    /// :nodoc:
    public var _reversed: SQLOrderingTerm {
        switch self {
        case .asc(let expression):
            return _SQLOrdering.desc(expression)
        case .desc(let expression):
            return _SQLOrdering.asc(expression)
            #if GRDBCUSTOMSQLITE
        case .ascNullsLast(let expression):
            return _SQLOrdering.descNullsFirst(expression)
        case .descNullsFirst(let expression):
            return _SQLOrdering.ascNullsLast(expression)
            #endif
        }
    }
    
    /// :nodoc:
    public func _qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm {
        switch self {
        case .asc(let expression):
            return _SQLOrdering.asc(expression._qualifiedExpression(with: alias))
        case .desc(let expression):
            return _SQLOrdering.desc(expression._qualifiedExpression(with: alias))
            #if GRDBCUSTOMSQLITE
        case .ascNullsLast(let expression):
            return _SQLOrdering.ascNullsLast(expression._qualifiedExpression(with: alias))
        case .descNullsFirst(let expression):
            return _SQLOrdering.descNullsFirst(expression._qualifiedExpression(with: alias))
            #endif
        }
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLOrderingVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}
