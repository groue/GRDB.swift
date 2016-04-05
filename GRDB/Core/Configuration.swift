import Foundation

#if !SQLITE_HAS_CODEC
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #endif
#endif

/// Configuration for a DatabaseQueue or DatabasePool.
public struct Configuration {
    
    // MARK: - Misc options
    
    public var foreignKeysEnabled: Bool = true
    public var readonly: Bool = false
    
    /// A function that is called on every statement executed by the database.
    public var trace: TraceFunction?
    
    
    // MARK: - Encryption
    
    #if SQLITE_HAS_CODEC
    /// The passphrase for encrypted database
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
    public var fileAttributes: [String: AnyObject]? = nil
    
    
    // MARK: - Transactions
    
    /// The default kind of transaction.
    public var defaultTransactionKind: TransactionKind = .Immediate
    
    
    // MARK: - Concurrency
    
    public var busyMode: BusyMode = .ImmediateError
    
    
    // MARK: - Internal
    
    var threadingMode: ThreadingMode = .Default
    var SQLiteConnectionDidOpen: (() -> ())?
    var SQLiteConnectionDidClose: (() -> ())?
    
    
    // MARK: - Factory Configuration
    
    /// Returns a factory configuration:
    ///
    /// - readonly: false
    /// - fileAttributes: nil
    /// - foreignKeysEnabled: true
    /// - trace: nil
    /// - defaultTransactionKind: .Immediate
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

