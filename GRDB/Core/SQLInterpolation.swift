#if swift(>=5.0)
/// :nodoc:
public struct SQLInterpolation: StringInterpolationProtocol {
    var context = SQLGenerationContext.literalGenerationContext(withArguments: true)
    var sql: String
    var arguments: StatementArguments {
        get { return context.arguments! }
        set { context.arguments = newValue }
    }
    
    public init(literalCapacity: Int, interpolationCount: Int) {
        sql = ""
        sql.reserveCapacity(literalCapacity + interpolationCount)
    }
    
    /// "SELECT * FROM player"
    public mutating func appendLiteral(_ sql: String) {
        self.sql += sql
    }
    
    /// "SELECT * FROM \(sql: "player")"
    public mutating func appendInterpolation(sql: String, arguments: StatementArguments = StatementArguments()) {
        self.sql += sql
        self.arguments += arguments
    }
    
    /// "SELECT * FROM player WHERE \(literal: condition)"
    public mutating func appendInterpolation(literal sqlLiteral: SQLLiteral) {
        sql += sqlLiteral.sql
        arguments += sqlLiteral.arguments
    }
}
#endif
