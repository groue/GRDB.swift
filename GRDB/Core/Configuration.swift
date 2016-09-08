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
    
    
    // MARK: - File Attributes
    
    /// The file attributes that should be applied to the database files (see
    /// `NSFileMnager.setAttributes(_,ofItemAtPath:)`).
    ///
    /// SQLite will create [temporary files](https://www.sqlite.org/tempfiles.html)
    /// when it needs them.
    ///
    /// In WAL mode (see DatabasePool), SQLite will also eventually create
    /// `-shm` and `-wal` files.
    ///
    /// GRDB will apply file attributes to all those files.
    ///
    /// Default: nil
    public var fileAttributes: [String: AnyObject]? = nil
    
    
    // MARK: - Transactions
    
    /// The default kind of transaction.
    ///
    /// Default: Immediate
    public var defaultTransactionKind: TransactionKind = .Immediate
    
    
    // MARK: - Concurrency
    
    /// The behavior in case of SQLITE_BUSY error. See https://www.sqlite.org/rescode.html#busy
    ///
    /// Default: ImmediateError
    public var busyMode: BusyMode = .ImmediateError
    
    /// The maximum number of concurrent readers (applies to database
    /// pools only).
    ///
    /// Default: 5
    public var maximumReaderCount: Int = 5
    
    
    // MARK: - Factory Configuration
    
    /// Creates a factory configuration
    public init() { }
    
    
    // MARK: - Not Public
    
    var threadingMode: ThreadingMode = .Default
    var SQLiteConnectionDidOpen: (() -> ())?
    var SQLiteConnectionWillClose: ((SQLiteConnection) -> ())?
    var SQLiteConnectionDidClose: (() -> ())?
    var SQLiteOpenFlags: Int32 {
        return threadingMode.SQLiteOpenFlags | (readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE))
    }
}

/// A tracing function that takes an SQL string.
public typealias TraceFunction = (String) -> Void

/// A tracing function that logs SQL statements with NSLog
public func LogSQL(sql: String) {
    NSLog("SQLite: %@", sql)
}

