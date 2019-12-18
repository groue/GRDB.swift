import Foundation
import Dispatch
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
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
    
    /// If false, SQLite from version 3.29.0 will not interpret a double-quoted
    /// string as a string literal if it does not match any valid identifier.
    ///
    /// For example:
    ///
    ///     // Error: no such column: foo
    ///     let name = try String.fetchOne(db, sql: """
    ///         SELECT "foo" FROM "player"
    ///         """)
    ///
    /// When true, or before version 3.29.0, such strings are interpreted as
    /// string literals, as in the example below. This is a well known SQLite
    /// [misfeature](https://sqlite.org/quirks.html#dblquote).
    ///
    ///     // Success: "foo"
    ///     let name = try String.fetchOne(db, sql: """
    ///         SELECT "foo" FROM "player"
    ///         """)
    ///
    /// - Recommended value: false
    /// - Default value: false
    public var acceptsDoubleQuotedStringLiterals = false
    
    /// When true, the `Database.suspendNotification` and
    /// `Database.resumeNotification` suspend and resume the database. Database
    /// suspension helps avoiding the [`0xdead10cc`
    /// exception](https://developer.apple.com/library/archive/technotes/tn2151/_index.html).
    ///
    /// During suspension, all database accesses but reads in WAL mode may throw
    /// a DatabaseError of code `SQLITE_INTERRUPT`, or `SQLITE_ABORT`. You can
    /// check for those error codes with the
    /// `DatabaseError.isInterruptionError` property.
    ///
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public var observesSuspensionNotifications = false
    
    // MARK: - Encryption
    
    #if SQLITE_HAS_CODEC
    // TODO: remove when the deprecated passphrase turns unavailable.
    var _passphrase: String?
    
    /// The passphrase for the encrypted database.
    ///
    /// Default: nil
    @available(*, deprecated, message: "Use Database.usePassphrase(_:) in Configuration.prepareDatabase instead.")
    public var passphrase: String? {
        get { return _passphrase }
        set { _passphrase = newValue }
    }
    #endif
    
    // MARK: - Managing SQLite Connections
    
    /// A function that is run when an SQLite connection is opened, before the
    /// connection is made available for database access methods.
    ///
    /// For example:
    ///
    ///     var config = Configuration()
    ///     config.prepareDatabase = { db in
    ///         try db.execute(sql: "PRAGMA kdf_iter = 10000")
    ///     }
    public var prepareDatabase: ((Database) throws -> Void)?
    
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
    
    /// The quality of service class for the work performed by the database.
    ///
    /// The quality of service is ignored if you supply a target queue.
    ///
    /// Default: .default (.unspecified on macOS < 10.10)
    public var qos: DispatchQoS
    
    /// The target queue for all database accesses.
    ///
    /// When you use a database pool, make sure the queue is concurrent. If
    /// it is serial, no concurrent database access can happen, and you may
    /// experience deadlocks.
    ///
    /// If the queue is nil, all database accesses happen in unspecified
    /// dispatch queues whose quality of service and label are determined by the
    /// `qos` and `label` Configuration properties.
    ///
    /// Default: nil
    public var targetQueue: DispatchQueue? = nil
    
    // MARK: - Factory Configuration
    
    /// Creates a factory configuration
    public init() {
        if #available(OSX 10.10, *) {
            qos = .default
        } else {
            qos = .unspecified
        }
    }
    
    
    // MARK: - Not Public
    
    var threadingMode: Database.ThreadingMode = .`default`
    var SQLiteConnectionDidOpen: (() -> Void)?
    var SQLiteConnectionWillClose: ((SQLiteConnection) -> Void)?
    var SQLiteConnectionDidClose: (() -> Void)?
    var SQLiteOpenFlags: Int32 {
        let readWriteFlags = readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
        return threadingMode.SQLiteOpenFlags | readWriteFlags
    }
    
    func makeDispatchQueue(defaultLabel: String, purpose: String? = nil) -> DispatchQueue {
        let label = (self.label ?? defaultLabel) + (purpose.map { "." + $0 } ?? "")
        if let targetQueue = targetQueue {
            return DispatchQueue(label: label, target: targetQueue)
        } else {
            return DispatchQueue(label: label, qos: qos)
        }
    }
}

/// A tracing function that takes an SQL string.
public typealias TraceFunction = (String) -> Void
