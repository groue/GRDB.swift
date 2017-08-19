import Foundation
#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

/// Configuration for a DatabaseQueue or DatabasePool.
public struct Configuration {
    
    // MARK: - Misc options
    
    /// If true, foreign key constraints are checked.
    ///
    /// Default: true
    public var foreignKeysEnabled: Bool = true
    
    /// If true, database modifications are disallowed.
    ///
    /// Default: false
    public var readonly: Bool = false
    
    /// A function that is called on every statement executed by the database.
    ///
    /// Default: nil
    public var trace: TraceFunction?
    
    
    // MARK: - Encryption
    
    #if SQLITE_HAS_CODEC
    /// The passphrase for encrypted database.
    ///
    /// Default: nil
    public var passphrase: String?
    #endif
    
    
    // MARK: - Transactions
    
    /// The default kind of transaction.
    ///
    /// Default: deferred
    public var defaultTransactionKind: Database.TransactionKind = .deferred
    
    
    // MARK: - Concurrency
    
    /// The behavior in case of SQLITE_BUSY error. See https://www.sqlite.org/rescode.html#busy
    ///
    /// Default: immediateError
    public var busyMode: Database.BusyMode = .immediateError
    
    /// The maximum number of concurrent readers (applies to database
    /// pools only).
    ///
    /// Default: 5
    public var maximumReaderCount: Int = 5
    
    
    // MARK: - Factory Configuration
    
    /// Creates a factory configuration
    public init() { }
    
    
    // MARK: - Not Public
    
    var threadingMode: Database.ThreadingMode = .`default`
    var SQLiteConnectionDidOpen: (() -> ())?
    var SQLiteConnectionWillClose: ((SQLiteConnection) -> ())?
    var SQLiteConnectionDidClose: (() -> ())?
    var SQLiteOpenFlags: Int32 {
        let readWriteFlags = readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
        return threadingMode.SQLiteOpenFlags | readWriteFlags
    }
}

/// A tracing function that takes an SQL string.
public typealias TraceFunction = (String) -> Void
