/**
Configuration are arguments to the DatabaseQueue initializers.
*/
public struct Configuration {
    
    // MARK: - Utilities
    
    /// A tracing function that logs SQL statements
    public static func logSQL(sql: String, arguments: StatementArguments?) {
        if let arguments = arguments {
            NSLog("GRDB: %@ -- arguments: %@", sql, arguments.description)
        } else {
            NSLog("GRDB: %@", sql)
        }
    }
    
    // MARK: - Configuration options
    
    /// A SQLite threading mode. See https://www.sqlite.org/threadsafe.html.
    enum ThreadingMode {
        case Default
        case MultiThread
        case Serialized
        
        var sqliteOpenFlags: Int32 {
            switch self {
            case .Default:
                return 0
            case .MultiThread:
                return SQLITE_OPEN_NOMUTEX
            case .Serialized:
                return SQLITE_OPEN_FULLMUTEX
            }
        }
    }
    
    /**
    A tracing function.

    - parameter sql: An SQL query
    - parameter arguments: Eventual query arguments.
    */
    public typealias TraceFunction = (sql: String, arguments: StatementArguments?) -> Void
    
    /// If true, the database has support for foreign keys.
    public var foreignKeysEnabled: Bool
    
    /// If true, the database is opened readonly.
    public var readonly: Bool
    
    /// The Threading mode
    ///
    /// Not public because we don't expose any public API that could have a use
    /// for it.
    var threadingMode: ThreadingMode = .Default
    
    /**
    An optional tracing function.

    You can use Configuration.logSQL as a tracing function: it logs all SQL
    statements with NSLog().
    */
    public var trace: TraceFunction?
    
    
    // MARK: - Initialization
    
    /**
    Setup a configuration.
    
    You can use Configuration.logSQL as a tracing function: it logs all SQL
    statements with NSLog().
    
    - parameter foreignKeysEnabled: If true (the default), the database has
                                    support for foreign keys.
    - parameter readonly:           If false (the default), the database will be
                                    created and opened for writing. If true, the
                                    database is opened readonly.
    - parameter trace:              An optional tracing function (default nil).
    
    - returns: A Configuration.
    */
    public init(foreignKeysEnabled: Bool = true, readonly: Bool = false, trace: TraceFunction? = nil) {
        self.foreignKeysEnabled = foreignKeysEnabled
        self.readonly = readonly
        self.trace = trace
    }
    
    
    // MARK: - Not public
    
    var sqliteOpenFlags: Int32 {
        return threadingMode.sqliteOpenFlags | (readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE))
    }
}
