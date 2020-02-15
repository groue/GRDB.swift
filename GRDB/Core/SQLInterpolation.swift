#if swift(>=5.0)
/// :nodoc:
public struct SQLInterpolation: StringInterpolationProtocol {
    var elements: [SQLLiteral.Element]
    
    public init(literalCapacity: Int, interpolationCount: Int) {
        elements = []
        elements.reserveCapacity(interpolationCount + 1)
    }
    
    /// "SELECT * FROM player"
    public mutating func appendLiteral(_ sql: String) {
        elements.append(.sql(sql))
    }
    
    /// "SELECT * FROM \(sql: "player")"
    public mutating func appendInterpolation(sql: String, arguments: StatementArguments = StatementArguments()) {
        elements.append(.sql(sql, arguments))
    }
    
    /// "SELECT * FROM player WHERE \(literal: condition)"
    public mutating func appendInterpolation(literal sqlLiteral: SQLLiteral) {
        elements.append(contentsOf: sqlLiteral.elements)
    }
}
#endif
