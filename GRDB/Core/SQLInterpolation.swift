/// :nodoc:
public struct SQLInterpolation: StringInterpolationProtocol {
    var elements: [SQL.Element]
    
    public init(literalCapacity: Int, interpolationCount: Int) {
        elements = []
        elements.reserveCapacity(interpolationCount + 1)
    }
    
    public mutating func appendLiteral(_ sql: String) {
        if sql.isEmpty { return }
        elements.append(.sql(sql))
    }
    
    /// Appends a raw SQL snippet, with eventual arguments.
    ///
    /// For example:
    ///
    ///     "SELECT * FROM \(sql: "player")"
    ///     "SELECT * FROM player WHERE \(sql: "name = ?", arguments: ["O'Brien"])"
    public mutating func appendInterpolation(sql: String, arguments: StatementArguments = StatementArguments()) {
        elements.append(.sql(sql, arguments))
    }
    
    /// Appends a raw `SQL` literal.
    ///
    /// For example:
    ///
    ///     "SELECT * FROM \(SQL("player"))"
    ///     "SELECT * FROM player WHERE \(SQL("name = \("O'Brien")"))"
    public mutating func appendInterpolation(_ sqlLiteral: SQL) {
        elements.append(contentsOf: sqlLiteral.elements)
    }
    
    /// Appends a String expression.
    ///
    /// For example:
    ///
    ///     "SELECT * FROM player WHERE name = \("O'Brien")"
    public mutating func appendInterpolation<S: StringProtocol>(_ string: S) {
        elements.append(.expression(String(string).sqlExpression))
    }
    
    /// Appends a raw `SQL` literal.
    ///
    /// For example:
    ///
    ///     "SELECT * FROM player WHERE \(literal: "name = \("O'Brien")")"
    public mutating func appendInterpolation(literal sqlLiteral: SQL) {
        elements.append(contentsOf: sqlLiteral.elements)
    }
}
