// TODO: documentation
public struct SQLLiteral {
    private(set) public var sql: String
    private(set) public var arguments: StatementArguments
    
    public init(sql: String, arguments: StatementArguments = StatementArguments()) {
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
    
    public mutating func append(_ sqlLiteral: SQLLiteral) {
        self += sqlLiteral
    }

    public mutating func append(sql: String, arguments: StatementArguments = StatementArguments()) {
        self += SQLLiteral(sql: sql, arguments: arguments)
    }
}

extension Sequence where Element == SQLLiteral {
    public func joined(separator: String = "") -> SQLLiteral {
        var sql = ""
        var arguments = StatementArguments()
        var first = true
        for literal in self {
            if first {
                first = false
            } else {
                sql += separator
            }
            sql += literal.sql
            arguments += literal.arguments
        }
        return SQLLiteral(sql: sql, arguments: arguments)
    }
}

extension Collection where Element == SQLLiteral {
    public func joined(separator: String = "") -> SQLLiteral {
        let sql = map { $0.sql }.joined(separator: separator)
        let arguments = reduce(into: StatementArguments()) { $0 += $1.arguments }
        return SQLLiteral(sql: sql, arguments: arguments)
    }
}

// MARK: - ExpressibleByStringInterpolation

#if swift(>=5.0)
extension SQLLiteral: ExpressibleByStringInterpolation {
    /// :nodoc
    public init(unicodeScalarLiteral: String) {
        self.init(sql: unicodeScalarLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(extendedGraphemeClusterLiteral: String) {
        self.init(sql: extendedGraphemeClusterLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(stringLiteral: String) {
        self.init(sql: stringLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(stringInterpolation sqlInterpolation: SQLInterpolation) {
        self.init(sql: sqlInterpolation.sql, arguments: sqlInterpolation.arguments)
    }
}
#endif
