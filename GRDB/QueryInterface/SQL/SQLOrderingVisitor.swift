/// :nodoc:
public protocol _SQLOrderingVisitor: _SQLExpressionVisitor {
    mutating func visit(_ ordering: SQLCollatedExpression) throws
    mutating func visit(_ ordering: _SQLOrdering) throws
    mutating func visit(_ ordering: _SQLOrderingLiteral) throws
}
