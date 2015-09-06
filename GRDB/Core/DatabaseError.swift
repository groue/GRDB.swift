/**
DatabaseError wraps a SQLite error.
*/
public struct DatabaseError : ErrorType {
    
    /// The SQLite error code (see https://www.sqlite.org/c3ref/c_abort.html).
    public let code: Int
    
    /// The SQLite error message.
    public let message: String?
    
    /// The SQL query that yielded the error (if relevant).
    public let sql: String?
    
    
    // MARK: Not public
    
    /// The query arguments that yielded the error (if relevant).
    /// Not public because the StatementArguments class has no public method.
    let arguments: StatementArguments?
    
    init(code: Int32, message: String? = nil, sql: String? = nil, arguments: StatementArguments? = nil) {
        self.code = Int(code)
        self.message = message
        self.sql = sql
        self.arguments = arguments
    }
}

extension DatabaseError: CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        // How to write this with a switch?
        if let sql = sql {
            if let message = message {
                if let arguments = arguments {
                    return "SQLite error \(code) with statement `\(sql)` arguments \(arguments): \(message)"
                } else {
                    return "SQLite error \(code) with statement `\(sql)`: \(message)"
                }
            } else {
                if let arguments = arguments {
                    return "SQLite error \(code) with statement `\(sql)` arguments \(arguments)"
                } else {
                    return "SQLite error \(code) with statement `\(sql)`"
                }
            }
        } else {
            if let message = message {
                return "SQLite error \(code): \(message)"
            } else {
                return "SQLite error \(code)"
            }
        }
    }
}
