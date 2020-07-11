/// :nodoc:
public protocol _SQLOrderingTermVisitor: _SQLExpressionVisitor {
    mutating func visit(_ ordering: SQLCollatedExpression) throws
    mutating func visit(_ ordering: _SQLOrdering) throws
    mutating func visit(_ ordering: _SQLOrderingLiteral) throws
}
