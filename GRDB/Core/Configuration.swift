/**
Configuration are arguments to the DatabaseQueue initializers.
*/
public struct Configuration {
    
    // =========================================================================
    // MARK: - Misc options
    
    /// If true, the database has support for foreign keys.
    public var foreignKeysEnabled: Bool
    
    /// If true, the database is opened readonly.
    public var readonly: Bool
    
    
    // =========================================================================
    // MARK: - Transactions
    
    /// Default transaction kind
    public var defaultTransactionKind: TransactionKind
    
    /// The optional transaction observer
    public var transactionObserver: TransactionObserverType?
    
    
    // =========================================================================
    // MARK: - Concurrency
    
    /// Busy Mode
    public var busyMode: BusyMode
    
    /// The Threading mode
    ///
    /// Not public because we don't expose any public API that could have a use
    /// for it.
    var threadingMode: ThreadingMode
    
    
    // =========================================================================
    // MARK: - Logging
    
    /**
    An optional tracing function.

    You can use the global GRDB.LogSQL function as a tracing function: it logs
    all SQL statements with NSLog().
    */
    public var trace: TraceFunction?
    
    
    // =========================================================================
    // MARK: - Factory Configuration
    
    /**
    Returns a factory configuration:
    
    - `foreignKeysEnabled`: true
    - `readonly`: false
    - `defaultTransactionKind`: Immediate
    - `transactionDelegate`: nil
    - `busyMode`: Immediate error
    - `trace`: nil
    */
    public init()
    {
        self.foreignKeysEnabled = true
        self.readonly = false
        
        self.defaultTransactionKind = .Immediate
        self.transactionObserver = nil
        
        self.busyMode = .ImmediateError
        self.threadingMode = .Default
        
        self.trace = nil
    }
    
    
    // =========================================================================
    // MARK: - SQLite flags
    
    var sqliteOpenFlags: Int32 {
        return threadingMode.sqliteOpenFlags | (readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE))
    }
}

/**
A tracing function.

- parameter sql: An SQL query
- parameter arguments: Eventual query arguments.
*/
public typealias TraceFunction = (String) -> Void

/// A tracing function that logs SQL statements with NSLog
public func LogSQL(sql: String) {
    NSLog("GRDB: %@", sql)
}

