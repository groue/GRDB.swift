// TODO: documentation
public struct SQLLiteral {
    private(set) public var sql: String
    private(set) public var arguments: StatementArguments
    
    public init(rawSQL sql: String, arguments: StatementArguments = StatementArguments()) {
        self.sql = sql
        self.arguments = arguments
    }
    
    /// Returns a literal whose SQL is transformed by the given closure.
    public func mapSQL(_ transform: (String) throws -> String) rethrows -> SQLLiteral {
        var result = self
        result.sql = try transform(sql)
        return result
    }
}

extension SQLLiteral {
    public static func + (lhs: SQLLiteral, rhs: SQLLiteral) -> SQLLiteral {
        var result = lhs
        result += rhs
        return result
    }
    
    public static func += (lhs: inout SQLLiteral, rhs: SQLLiteral) {
        lhs.sql += rhs.sql
        lhs.arguments += rhs.arguments
    }
    
    public mutating func append(literal sqlLiteral: SQLLiteral) {
        self += sqlLiteral
    }

    public mutating func append(rawSQL sql: String, arguments: StatementArguments = StatementArguments()) {
        self += SQLLiteral(rawSQL: sql, arguments: arguments)
    }
}

// MARK: - ExpressibleByStringInterpolation

#if swift(>=5.0)
extension SQLLiteral: ExpressibleByStringInterpolation {
    /// :nodoc
    public init(unicodeScalarLiteral: String) {
        self.init(rawSQL: unicodeScalarLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(extendedGraphemeClusterLiteral: String) {
        self.init(rawSQL: extendedGraphemeClusterLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(stringLiteral: String) {
        self.init(rawSQL: stringLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(stringInterpolation sqlInterpolation: SQLInterpolation) {
        self.init(rawSQL: sqlInterpolation.sql, arguments: sqlInterpolation.arguments)
    }
}
#endif
