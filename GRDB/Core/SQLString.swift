public struct SQLString {
    private(set) public var sql: String
    private(set) public var arguments: StatementArguments
    
    public init(sql: String, arguments: StatementArguments = []) {
        self.sql = sql
        self.arguments = arguments
    }
    
    public init(_ sqlString: SQLString) {
        self = sqlString
    }
}

extension SQLString {
    public static func + (lhs: SQLString, rhs: SQLString) -> SQLString {
        var result = lhs
        result += rhs
        return result
    }
    
    public static func += (lhs: inout SQLString, rhs: SQLString) {
        lhs.sql += rhs.sql
        lhs.arguments += rhs.arguments
    }
    
    public mutating func append(_ other: SQLString) {
        self += other
    }

    public mutating func append(sql: String, arguments: StatementArguments? = nil) {
        self.sql += sql
        if let arguments = arguments {
            self.arguments += arguments
        }
    }
}

// MARK: - ExpressibleByStringInterpolation

#if swift(>=5.0)
extension SQLString: ExpressibleByStringInterpolation {
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
