#if swift(>=5.0)
extension SQLInterpolation {
    /// "SELECT * FROM \(Player.self)"
    public mutating func appendInterpolation<T: TableRecord>(_ table: T.Type) {
        sql += table.databaseTableName.quotedDatabaseIdentifier
    }
    
    /// "SELECT \(AllColumns()) FROM player"
    public mutating func appendInterpolation(_ selection: SQLSelectable) {
        sql += selection.resultColumnSQL(&context)
    }
    
    /// "SELECT score + \(bonus) FROM player"
    /// "SELECT \(Column("name")) FROM player"
    public mutating func appendInterpolation(_ expressible: SQLExpressible & SQLSelectable & SQLOrderingTerm) {
        sql += expressible.sqlExpression.expressionSQL(&context)
    }
    
    /// "SELECT \(CodingKey.name) FROM player"
    public mutating func appendInterpolation(_ expressible: SQLExpressible & SQLSelectable & SQLOrderingTerm & CodingKey) {
        sql += expressible.sqlExpression.expressionSQL(&context)
    }
    
    /// "SELECT \(Column("name")) FROM player"
    /// "SELECT score + \(bonus) FROM player"
    public mutating func appendInterpolation<T: SQLExpressible>(_ expressible: T?) {
        if let expressible = expressible {
            sql += expressible.sqlExpression.expressionSQL(&context)
        } else {
            sql += "NULL"
        }
    }
    
    /// "SELECT \(CodingKey.name) FROM player"
    public mutating func appendInterpolation(_ codingKey: CodingKey) {
        appendInterpolation(Column(codingKey.stringValue))
    }
    
    /// "SELECT * FROM player WHERE id IN \([1, 2, 3])"
    public mutating func appendInterpolation<S>(_ sequence: S) where S: Sequence, S.Element: SQLExpressible {
        sql += "("
        var first = true
        for element in sequence {
            if first {
                first = false
            } else {
                sql += ","
            }
            appendInterpolation(element)
        }
        sql += ")"
    }
    
    /// "SELECT * FROM player WHERE id IN \([Column("a"), Column("b" + 1)])"
    public mutating func appendInterpolation<S>(_ sequence: S) where S: Sequence, S.Element == SQLExpression {
        sql += "("
        var first = true
        for element in sequence {
            if first {
                first = false
            } else {
                sql += ","
            }
            appendInterpolation(element)
        }
        sql += ")"
    }
    
    /// "SELECT * FROM player ORDER BY \(Column("name").desc)"
    public mutating func appendInterpolation(_ ordering: SQLOrderingTerm) {
        sql += ordering.orderingTermSQL(&context)
    }
}
#endif
