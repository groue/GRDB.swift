import Foundation

/// Configure a DatabaseQueue
public struct Configuration {
    
    // MARK: - Misc options
    
    public var foreignKeysEnabled: Bool = true
    public var readonly: Bool = false
    
    /// A function that is called on every statement executed by the database.
    public var trace: TraceFunction?
    
    
    // MARK: - Transactions
    
    /// The default kind of transaction.
    public var defaultTransactionKind: TransactionKind = .Immediate
    
    
    // MARK: - Concurrency
    
    public var busyMode: BusyMode = .ImmediateError
    var threadingMode: ThreadingMode = .Default
    
    
    // MARK: - Factory Configuration
    
    /// Returns a factory configuration:
    ///
    /// - foreignKeysEnabled: true
    /// - readonly: false
    /// - trace: nil
    /// - defaultTransactionKind: .Immediate
    /// - transactionObserver: nil
    /// - busyMode: .ImmediateError
    public init() { }
    
    
    // MARK: - SQLite flags
    
    var sqliteOpenFlags: Int32 {
        return threadingMode.sqliteOpenFlags | (readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE))
    }
}

/// A tracing function that takes an SQL string.
public typealias TraceFunction = (String) -> Void

/// A tracing function that logs SQL statements with NSLog
public func LogSQL(sql: String) {
    NSLog("SQLite: %@", sql)
}

