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
    
    /// The database label.
    ///
    /// You can query this label at runtime:
    ///
    ///     var configuration = Configuration()
    ///     configuration.label = "MyDatabase"
    ///     let dbQueue = try DatabaseQueue(path: ..., configuration: configuration)
    ///
    ///     try dbQueue.read { db in
    ///         print(db.configuration.label) // Prints "MyDatabase"
    ///     }
    ///
    /// The database label is also used to name the various dispatch queues
    /// created by GRDB, visible in debugging sessions and crash logs. However
    /// those dispatch queue labels are intended for debugging only. Their
    /// format may change between GRDB releases. Applications should not depend
    /// on the GRDB dispatch queue labels.
    ///
    /// If the database label is nil, the current GRDB implementation uses the
    /// following dispatch queue labels:
    ///
    /// - `GRDB.DatabaseQueue`: the (unique) dispatch queue of a DatabaseQueue
    /// - `GRDB.DatabasePool.writer`: the (unique) writer dispatch queue of
    ///   a DatabasePool
    /// - `GRDB.DatabasePool.reader.N`, where N is 1, 2, ...: one of the reader
    ///   dispatch queue(s) of a DatabasePool. N grows with the number of SQLite
    ///   connections: it may get bigger than the maximum number of concurrent
    ///   readers, as SQLite connections get closed and new ones are opened.
    /// - `GRDB.DatabasePool.snapshot.N`: the dispatch queue of a
    ///   DatabaseSnapshot. N grows with the number of snapshots.
    ///
    /// If the database label is not nil, for example "MyDatabase", the current
    /// GRDB implementation uses the following dispatch queue labels:
    ///
    /// - `MyDatabase`: the (unique) dispatch queue of a DatabaseQueue
    /// - `MyDatabase.writer`: the (unique) writer dispatch queue of
    ///   a DatabasePool
    /// - `MyDatabase.reader.N`, where N is 1, 2, ...: one of the reader
    ///   dispatch queue(s) of a DatabasePool. N grows with the number of SQLite
    ///   connections: it may get bigger than the maximum number of concurrent
    ///   readers, as SQLite connections get closed and new ones are opened.
    /// - `MyDatabase.snapshot.N`: the dispatch queue of a
    ///   DatabaseSnapshot. N grows with the number of snapshots.
    ///
    /// The default label is nil.
    public var label: String? = nil
    
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
    
    /// If false, it is a programmer error to leave a transaction opened at the
    /// end of a database access block.
    ///
    /// For example:
    ///
    ///     let dbQueue = DatabaseQueue()
    ///
    ///     // fatal error: A transaction has been left opened at the end of a database access
    ///     try dbQueue.inDatabase { db in
    ///         try db.beginTransaction()
    ///     }
    ///
    /// If true, one can leave opened transaction at the end of database access
    /// blocks:
    ///
    ///     var config = Configuration()
    ///     config.allowsUnsafeTransactions = true
    ///     let dbQueue = DatabaseQueue(configuration: config)
    ///
    ///     try dbQueue.inDatabase { db in
    ///         try db.beginTransaction()
    ///     }
    ///
    ///     try dbQueue.inDatabase { db in
    ///         try db.commit()
    ///     }
    ///
    /// This configuration flag has no effect on DatabasePool readers: those
    /// never allow leaving a transaction opened at the end of a read access.
    ///
    /// Default: false
    public var allowsUnsafeTransactions: Bool = false
    
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
