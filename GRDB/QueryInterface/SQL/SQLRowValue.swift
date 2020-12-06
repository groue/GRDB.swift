/// A [row value](https://www.sqlite.org/rowvalue.html).
///
/// :nodoc:
public struct _SQLRowValue: SQLExpression {
    let expressions: [SQLExpression]
    
    /// SQLite row values were shipped in SQLite 3.15:
    /// https://www.sqlite.org/releaselog/3_15_0.html
    public /* public for tests */ static let isAvailable = (sqlite3_libversion_number() >= 3015000)
    
    /// - precondition: `expressions` is not empty
    init(_ expressions: [SQLExpression]) {
        assert(!expressions.isEmpty)
        self.expressions = expressions
    }
    
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLRowValue(expressions.map { $0._qualifiedExpression(with: alias) })
    }
    
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        if let expression = expressions.first, expressions.count == 1 {
            try expression._accept(&visitor)
        } else {
            try visitor.visit(self)
        }
    }
}
