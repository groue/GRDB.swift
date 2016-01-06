import Foundation

/// Configuration are arguments to the DatabaseQueue initializers.
public struct Configuration {
    
    // MARK: - Misc options
    
    public var foreignKeysEnabled: Bool = true
    public var readonly: Bool = false
    public var trace: TraceFunction?
    
    
    // MARK: - Transactions
    
    public var defaultTransactionKind: TransactionKind = .Immediate
    public var transactionObserver: TransactionObserverType?
    
    
    // MARK: - Concurrency
    
    public var busyMode: BusyMode = .ImmediateError
    var threadingMode: ThreadingMode = .Default
    
    
    // MARK: - Factory Configuration
    
    /// Returns a factory configuration.
    public init() {
    }
    
    
    // MARK: - SQLite flags
    
    var sqliteOpenFlags: Int32 {
        return threadingMode.sqliteOpenFlags | (readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE))
    }
}

/// A tracing function.
///
/// - parameter sql: An SQL query
public typealias TraceFunction = (String) -> Void

/// A tracing function that logs SQL statements with NSLog
public func LogSQL(sql: String) {
    NSLog("SQLite: %@", sql)
}

