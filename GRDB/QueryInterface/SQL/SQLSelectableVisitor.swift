/// :nodoc:
public protocol _SQLSelectableVisitor: _SQLExpressionVisitor {
    mutating func visit(_ selectable: AllColumns) throws
    mutating func visit(_ selectable: _SQLAliasedExpression) throws
    mutating func visit(_ selectable: _SQLQualifiedAllColumns) throws
    mutating func visit(_ selectable: _SQLSelectionLiteral) throws
}
