import Foundation

#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif

/// DatabaseError wraps an SQLite error.
public struct DatabaseError : Error {
    
    /// The SQLite error code (see https://www.sqlite.org/c3ref/c_abort.html).
    public let code: Int32
    
    /// The SQLite error message.
    public let message: String?
    
    /// The SQL query that yielded the error (if relevant).
    public let sql: String?
    
    public init(code: Int32 = SQLITE_ERROR, message: String? = nil, sql: String? = nil, arguments: StatementArguments? = nil) {
        self.code = code
        self.message = message
        self.sql = sql
        self.arguments = arguments
    }
    
    
    // MARK: Not public
    
    /// The query arguments that yielded the error (if relevant).
    /// Not public because the StatementArguments class has no public method.
    let arguments: StatementArguments?
}

extension DatabaseError: CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        var description = "SQLite error \(code)"
        if let sql = sql {
            description += " with statement `\(sql)`"
        }
        if let arguments = arguments, !arguments.isEmpty {
            description += " arguments \(arguments)"
        }
        if let message = message {
            description += ": \(message)"
        }
        return description
    }
}

extension DatabaseError : CustomNSError {
    
    /// NSError bridging: the domain of the error.
    public static var errorDomain: String {
        return "GRDB.DatabaseError"
    }
    
    /// NSError bridging: the error code within the given domain.
    public var errorCode: Int {
        return Int(code)
    }
    
    /// NSError bridging: the user-info dictionary.
    public var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: description]
    }
}
