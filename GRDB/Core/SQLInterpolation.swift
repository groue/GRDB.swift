/// :nodoc:
public struct SQLInterpolation: StringInterpolationProtocol {
    var elements: [SQLLiteral.Element]
    
    public init(literalCapacity: Int, interpolationCount: Int) {
        elements = []
        elements.reserveCapacity(interpolationCount + 1)
    }
    
    /// "SELECT * FROM player"
    public mutating func appendLiteral(_ sql: String) {
        if sql.isEmpty { return }
        elements.append(.sql(sql))
    }
    
    /// "SELECT * FROM \(sql: "player")"
    public mutating func appendInterpolation(sql: String, arguments: StatementArguments = StatementArguments()) {
        elements.append(.sql(sql, arguments))
    }
    
    /// "SELECT * FROM player WHERE \(SQLLiteral(...))"
    public mutating func appendInterpolation(_ sqlLiteral: SQLLiteral) {
        elements.append(contentsOf: sqlLiteral.elements)
    }

    /// "SELECT * FROM player WHERE \(SQLLiteral(...))"
    public mutating func appendInterpolation<S: StringProtocol>(_ string: S) {
        elements.append(.expression(String(string).sqlExpression))
    }

    /// "SELECT * FROM player WHERE \(literal: "...")"
    public mutating func appendInterpolation(literal sqlLiteral: SQLLiteral) {
        elements.append(contentsOf: sqlLiteral.elements)
    }
}
