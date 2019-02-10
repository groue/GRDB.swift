#if swift(>=5.0)
/// :nodoc:
public struct SQLInterpolation: StringInterpolationProtocol {
    var sql: String
    var arguments: StatementArguments {
        get { return context.arguments! }
        set { context.arguments = newValue }
    }
    var context = SQLGenerationContext.literalGenerationContext(withArguments: true)

    public init(literalCapacity: Int, interpolationCount: Int) {
        sql = ""
        sql.reserveCapacity(literalCapacity + interpolationCount)
    }

    /// "SELECT * FROM player"
    public mutating func appendLiteral(_ literal: String) {
        sql += literal
    }

    /// "SELECT * FROM \(raw: "player")"
    public mutating func appendInterpolation(sql literal: String, arguments: StatementArguments? = nil) {
        sql += literal
        if let arguments = arguments {
            self.arguments += arguments
        }
    }

    /// "SELECT * FROM player WHERE \(condition)"
    public mutating func appendInterpolation(_ sqlString: SQLString) {
        sql += sqlString.sql
        arguments += sqlString.arguments
    }
}
#endif
