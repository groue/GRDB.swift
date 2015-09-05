/**
Configuration are arguments to the DatabaseQueue initializers.
*/
public struct Configuration {
    
    // MARK: - Utilities
    
    /// A tracing function that logs SQL statements
    public static func logSQL(sql: String, arguments: StatementArguments?) {
        NSLog("GRDB: %@", sql)
        if let arguments = arguments {
            NSLog("GRDB: arguments %@", arguments.description)
        }
    }
    
    // MARK: - Configuration options
    
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
        // IMPLEMENTATION NOTE
        //
        // According to https://www.sqlite.org/threadsafe.html:
        //
        // > The SQLITE_OPEN_NOMUTEX flag causes the database connection to be
        // > in the multi-thread mode.
        // >
        // > ...
        // >
        // > In the multi-thread mode, SQLite can be safely used by multiple
        // > threads provided that no single database connection is used
        // > simultaneously in two or more threads.
        //
        // We set the flag SQLITE_OPEN_NOMUTEX, because database connections are
        // only used via DatabaseQueue, which serializes database accesses in
        // a serial dispatch queue. There is no purpose using SQLite's native
        // mutex.
        //
        // Of course, the decision of using SQLITE_OPEN_NOMUTEX should not
        // belong to the Configuration type. This has to be refactored.

        return SQLITE_OPEN_NOMUTEX | (readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE))
    }
}
