import Dispatch
import Foundation

/// Configuration for a DatabaseQueue or DatabasePool.
public struct Configuration {
    
    // MARK: - Misc options
    
    /// If true (the default), support for foreign keys is enabled.
    /// See <https://www.sqlite.org/foreignkeys.html> for more information.
    ///
    /// Default: true
    public var foreignKeysEnabled = true
    
    /// If true, database modifications are disallowed.
    ///
    /// Default: false
    public var readonly = false
    
    /// The configuration label.
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
    /// The configuration label is also used to name Database connections (the
    /// `Database.description` property), and the various dispatch queues
    /// created by GRDB, visible in debugging sessions and crash logs.
    ///
    /// Those connection names and dispatch queue labels are intended for
    /// debugging only. Their format may change between GRDB releases.
    /// Applications should not depend on connection names and dispatch
    /// queue labels.
    ///
    /// If the configuration label is nil, the current GRDB implementation uses
    /// the following names:
    ///
    /// - `GRDB.DatabaseQueue`: the (unique) connection of a DatabaseQueue
    /// - `GRDB.DatabasePool.writer`: the (unique) writer connection of
    ///   a DatabasePool
    /// - `GRDB.DatabasePool.reader.N`, where N is 1, 2, ...: one of the reader
    ///   connection(s) of a DatabasePool. N may get bigger than the maximum
    ///   number of concurrent readers, as SQLite connections get closed and new
    ///   ones are opened.
    /// - `GRDB.DatabasePool.snapshot.N`: the connection of a DatabaseSnapshot.
    ///   N grows with the number of snapshots.
    ///
    /// If the configuration label is not nil, for example "MyDatabase", the
    /// current GRDB implementation uses the following names:
    ///
    /// - `MyDatabase`: the (unique) connection of a DatabaseQueue
    /// - `MyDatabase.writer`: the (unique) writer connection of a DatabasePool
    /// - `MyDatabase.reader.N`, where N is 1, 2, ...: one of the reader
    ///   connection(s) of a DatabasePool. N may get bigger than the maximum
    ///   number of concurrent readers, as SQLite connections get closed and new
    ///   ones are opened.
    /// - `MyDatabase.snapshot.N`: the connection of a DatabaseSnapshot. N grows
    ///   with the number of snapshots.
    ///
    /// The default configuration label is nil.
    public var label: String? = nil
    
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
    /// exception](https://developer.apple.com/documentation/xcode/understanding-the-exception-types-in-a-crash-report).
    ///
    /// During suspension, all database accesses but reads in WAL mode may throw
    /// a DatabaseError of code `SQLITE_INTERRUPT`, or `SQLITE_ABORT`. You can
    /// check for those error codes with the
    /// `DatabaseError.isInterruptionError` property.
    ///
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public var observesSuspensionNotifications = false
    
    /// If false (the default), statement arguments are not visible in the
    /// description of database errors and trace events, preventing sensitive
    /// information from leaking in unexpected places.
    ///
    /// For example:
    ///
    ///     // Error: sensitive information is not printed when an error occurs:
    ///     do {
    ///         let email = "..." // sensitive information
    ///         let player = try Player.filter(Column("email") == email).fetchOne(db)
    ///     } catch {
    ///         print(error)
    ///     }
    ///
    ///     // Trace: sensitive information is not printed when a statement is traced:
    ///     db.trace { event in
    ///         print(event)
    ///     }
    ///     let email = "..." // sensitive information
    ///     let player = try Player.filter(Column("email") == email).fetchOne(db)
    ///
    /// For debugging purpose, you can set this flag to true, and get more
    /// precise database reports. It is your responsibility to prevent sensitive
    /// information from leaking in unexpected locations, so you should not set
    /// this flag in release builds (think about GDPR and other
    /// privacy-related rules):
    ///
    ///     var config = Configuration()
    ///     #if DEBUG
    ///     // Protect sensitive information by enabling verbose debugging in DEBUG builds only
    ///     config.publicStatementArguments = true
    ///     #endif
    ///
    ///     // The descriptions of trace events and errors now contain the
    ///     // sensitive information:
    ///     db.trace { event in
    ///         print(event)
    ///     }
    ///     do {
    ///         let email = "..."
    ///         let player = try Player.filter(Column("email") == email).fetchOne(db)
    ///     } catch {
    ///         print(error)
    ///     }
    public var publicStatementArguments = false
    
    // MARK: - Managing SQLite Connections
    
    private var setups: [(Database) throws -> Void] = []
    
    /// The function argument is run when an SQLite connection is opened,
    /// before the connection is made available for database access methods.
    ///
    /// This method can be called several times. The preparation functions are
    /// run in the same order.
    ///
    /// For example:
    ///
    ///     var config = Configuration()
    ///     config.prepareDatabase { db in
    ///         try db.execute(sql: "PRAGMA kdf_iter = 10000")
    ///     }
    ///
    /// When you use a `DatabasePool`, preparation functions are called for
    /// the writer connection and all reader connections. You can distinguish
    /// them by querying `db.configuration.readonly`:
    ///
    ///     var config = Configuration()
    ///     config.prepareDatabase { db in
    ///         if db.configuration.readonly {
    ///             // reader connection
    ///         } else {
    ///             // writer connection
    ///         }
    ///     }
    ///
    /// On newly created databases, `DatabasePool` the WAL mode is activated
    /// after the preparation functions have run.
    public mutating func prepareDatabase(_ setup: @escaping (Database) throws -> Void) {
        setups.append(setup)
    }
    
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
    public var allowsUnsafeTransactions = false
    
    // MARK: - Concurrency
    
    /// The behavior in case of SQLITE_BUSY error. See <https://www.sqlite.org/rescode.html#busy>
    ///
    /// Default: immediateError
    public var busyMode: Database.BusyMode = .immediateError
    
    /// The behavior in case of SQLITE_BUSY error, for read-only connections.
    /// If nil, GRDB picks a default one.
    var readonlyBusyMode: Database.BusyMode? = nil
    
    /// The maximum number of concurrent readers (applies to database
    /// pools only).
    ///
    /// Default: 5
    public var maximumReaderCount: Int = 5
    
    /// The quality of service class for the work performed by the database.
    ///
    /// The quality of service is ignored if you supply a target queue.
    ///
    /// Default: .default
    public var qos: DispatchQoS = .default
    
    /// A target queue for database accesses.
    ///
    /// Database connections which are not read-only will prefer
    /// `writeTargetQueue` instead, if it is not nil.
    ///
    /// When you use a database pool, make sure this queue is concurrent. This
    /// is because in a serial dispatch queue, no concurrent database access can
    /// happen, and you may experience deadlocks.
    ///
    /// If the queue is nil, all database accesses happen in unspecified
    /// dispatch queues whose quality of service is determined by the
    /// `qos` property.
    ///
    /// Default: nil
    public var targetQueue: DispatchQueue? = nil
    
    /// The target queue for database connections which are not read-only.
    ///
    /// If this queue is nil, writer connections are controlled by `targetQueue`.
    ///
    /// Default: nil
    public var writeTargetQueue: DispatchQueue? = nil
    
    // MARK: - Factory Configuration
    
    /// Creates a factory configuration
    public init() { }
    
    // MARK: - Not Public
    
    var threadingMode: Database.ThreadingMode = .`default`
    var SQLiteConnectionDidOpen: (() -> Void)?
    var SQLiteConnectionWillClose: ((SQLiteConnection) -> Void)?
    var SQLiteConnectionDidClose: (() -> Void)?
    var SQLiteOpenFlags: Int32 {
        let readWriteFlags = readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
        return threadingMode.SQLiteOpenFlags | readWriteFlags
    }
    
    func setUp(_ db: Database) throws {
        for f in setups {
            try f(db)
        }
    }
    
    func identifier(defaultLabel: String, purpose: String? = nil) -> String {
        (self.label ?? defaultLabel) + (purpose.map { "." + $0 } ?? "")
    }
    
    func makeWriterDispatchQueue(label: String) -> DispatchQueue {
        if let targetQueue = writeTargetQueue ?? targetQueue {
            return DispatchQueue(label: label, target: targetQueue)
        } else {
            return DispatchQueue(label: label, qos: qos)
        }
    }
    
    func makeReaderDispatchQueue(label: String) -> DispatchQueue {
        if let targetQueue = targetQueue {
            return DispatchQueue(label: label, target: targetQueue)
        } else {
            return DispatchQueue(label: label, qos: qos)
        }
    }
}
