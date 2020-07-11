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
    func _accept<Visitor: _SQLOrderingTermVisitor>(_ visitor: inout Visitor) throws
}

/// The protocol for all types that can be used as an SQL ordering term, as
/// described at https://www.sqlite.org/syntax/ordering-term.html
///
public protocol SQLOrderingTerm: _SQLOrderingTerm { }

// MARK: - _SQLOrdering

/// :nodoc:
public enum _SQLOrdering: SQLOrderingTerm, Refinable {
    case asc(SQLExpression)
    case desc(SQLExpression)
    #if GRDBCUSTOMSQLITE
    case ascNullsLast(SQLExpression)
    case descNullsFirst(SQLExpression)
    #endif
    
    var expression: SQLExpression {
        get {
            switch self {
            case .asc(let expression):
                return expression
            case .desc(let expression):
                return expression
                #if GRDBCUSTOMSQLITE
            case .ascNullsLast(let expression):
                return expression
            case .descNullsFirst(let expression):
                return expression
                #endif
            }
        }
        set {
            switch self {
            case .asc:
                self = .asc(newValue)
            case .desc:
                self = .desc(newValue)
                #if GRDBCUSTOMSQLITE
            case .ascNullsLast:
                self = .ascNullsLast(newValue)
            case .descNullsFirst:
                self = .descNullsFirst(newValue)
                #endif
            }
        }
    }
    
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
        map(\.expression) { $0._qualifiedExpression(with: alias) }
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLOrderingTermVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}
