import Dispatch
import Foundation

/// The configuration of a ``Database``, ``DatabaseQueue``, or ``DatabasePool``.
///
/// Usage:
///
/// ```swift
/// var config = Configuration()
/// config.readonly = true
/// config.foreignKeysEnabled = true // Default is already true
/// config.label = "MyDatabase"      // Useful when your app opens multiple databases
/// config.maximumReaderCount = 10   // (DatabasePool only) The default is 5
///
/// let dbQueue = try DatabaseQueue( // or DatabasePool
///     path: "/path/to/database.sqlite",
///     configuration: config)
/// ```
public struct Configuration {
    
    // MARK: - Misc options
    
    /// A boolean value indicating whether foreign key support is enabled.
    ///
    /// The default is true.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/foreignkeys.html>.
    public var foreignKeysEnabled = true
    
    /// A boolean value indicating whether an SQLite connection is read-only.
    ///
    /// The default is false.
    public var readonly = false
    
    /// A label that describes a database connection.
    ///
    /// You can query this label at runtime:
    ///
    /// ```swift
    /// var configuration = Configuration()
    /// configuration.label = "MyDatabase"
    /// let dbQueue = try DatabaseQueue(path: ..., configuration: configuration)
    ///
    /// try dbQueue.read { db in
    ///     print(db.configuration.label) // Prints "MyDatabase"
    /// }
    /// ```
    ///
    /// The configuration label is also used to name ``Database`` connections
    /// (their ``Database/description`` property), and the various dispatch
    /// queues created by GRDB, visible in debugging sessions and crash logs.
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
    
    /// A boolean value indicating whether SQLite 3.29+ interprets
    /// double-quoted strings as string literals when they does not match any
    /// valid identifier.
    ///
    /// The default and recommended value is false.
    ///
    /// For example:
    ///
    /// ```swift
    /// // Error: no such column: foo
    /// let name = try String.fetchOne(db, sql: """
    ///     SELECT "foo" FROM "player"
    ///     """)
    /// ```
    ///
    /// When true, or before SQLite version 3.29.0, such strings are interpreted
    /// as string literals, as in the example below. This is a well known SQLite
    /// [misfeature](https://sqlite.org/quirks.html#dblquote):
    ///
    /// ```swift
    /// // Success: "foo"
    /// let name = try String.fetchOne(db, sql: """
    ///     SELECT "foo" FROM "player"
    ///     """)
    /// ```
    public var acceptsDoubleQuotedStringLiterals = false
    
    /// A boolean value indicating whether the database connection listens to
    /// the ``Database/suspendNotification`` and ``Database/resumeNotification``
    /// notifications.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// Database suspension helps avoiding the
    /// [`0xdead10cc` exception](https://developer.apple.com/documentation/xcode/understanding-the-exception-types-in-a-crash-report).
    ///
    /// During suspension, all database accesses but reads in WAL mode may throw
    /// a ``DatabaseError`` of code `SQLITE_INTERRUPT` or `SQLITE_ABORT`. You
    /// can check for those error codes with the
    /// ``DatabaseError/isInterruptionError`` property.
    public var observesSuspensionNotifications = false
    
    /// A boolean value indicating whether statement arguments are visible in
    /// the description of database errors and trace events.
    ///
    /// The default and recommended value is false: statement arguments are not
    /// visible in database errors and trace events, preventing sensitive
    /// information from leaking in unexpected places.
    ///
    /// For example:
    ///
    /// ```swift
    /// // Error: sensitive information is not printed when an error occurs:
    /// do {
    ///     let email = "..." // sensitive information
    ///     let player = try Player.filter(Column("email") == email).fetchOne(db)
    /// } catch {
    ///     print(error)
    /// }
    ///
    /// // Trace: sensitive information is not printed when a statement is traced:
    /// db.trace { event in
    ///     print(event)
    /// }
    /// let email = "..." // sensitive information
    /// let player = try Player.filter(Column("email") == email).fetchOne(db)
    /// ```
    ///
    /// For debugging purpose, you can set this flag to true, and get more
    /// precise database reports. It is your responsibility to prevent sensitive
    /// information from leaking in unexpected locations, so you should not set
    /// this flag in release builds (think about GDPR and other
    /// privacy-related rules):
    ///
    /// ```swift
    /// var config = Configuration()
    /// #if DEBUG
    /// // Protect sensitive information by enabling verbose debugging in DEBUG builds only
    /// config.publicStatementArguments = true
    /// #endif
    ///
    /// // The descriptions of trace events and errors now contain the
    /// // sensitive information:
    /// db.trace { event in
    ///     print(event)
    /// }
    /// do {
    ///     let email = "..."
    ///     let player = try Player.filter(Column("email") == email).fetchOne(db)
    /// } catch {
    ///     print(error)
    /// }
    /// ```
    public var publicStatementArguments = false
    
    // MARK: - Managing SQLite Connections
    
    private var setups: [(Database) throws -> Void] = []
    
    /// Defines a function to run whenever an SQLite connection is opened.
    ///
    /// The preparation function is run before the connection is made available
    /// for database access methods.
    ///
    /// This method can be called several times. The preparation functions are
    /// run in the same order.
    ///
    /// For example:
    ///
    /// ```swift
    /// var config = Configuration()
    /// config.prepareDatabase { db in
    ///     try db.execute(sql: "PRAGMA kdf_iter = 10000")
    /// }
    /// ```
    ///
    /// When you use a ``DatabasePool``, preparation functions are called for
    /// the writer connection and all reader connections. You can distinguish
    /// them by querying `db.configuration.readonly`:
    ///
    /// ```swift
    /// var config = Configuration()
    /// config.prepareDatabase { db in
    ///     if db.configuration.readonly {
    ///         // reader connection
    ///     } else {
    ///         // writer connection
    ///     }
    /// }
    /// ```
    ///
    /// On newly created databases files, ``DatabasePool`` activates the WAL
    /// mode after the preparation functions have run.
    public mutating func prepareDatabase(_ setup: @escaping (Database) throws -> Void) {
        setups.append(setup)
    }
    
    // MARK: - Transactions
    
    /// The default kind of transaction.
    ///
    /// The default is ``Database/TransactionKind/deferred``.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_transaction.html>
    public var defaultTransactionKind: Database.TransactionKind = .deferred
    
    /// A boolean value indicating whether it is valid to leave a transaction
    /// opened at the end of a database access method.
    ///
    /// The default value is false: not completing a transaction is a
    /// programmer error:
    ///
    /// ```swift
    /// let dbQueue = try DatabaseQueue()
    ///
    /// // fatal error: A transaction has been left opened at the end of a database access
    /// try dbQueue.inDatabase { db in
    ///     try db.beginTransaction()
    /// }
    /// ```
    ///
    /// When true, one can leave opened transaction at the end of database
    /// access method:
    ///
    /// ```swift
    /// var config = Configuration()
    /// config.allowsUnsafeTransactions = true
    /// let dbQueue = try DatabaseQueue(configuration: config)
    ///
    /// try dbQueue.inDatabase { db in
    ///     try db.beginTransaction()
    /// }
    ///
    /// try dbQueue.inDatabase { db in
    ///     try db.commit()
    /// }
    /// ```
    ///
    /// This configuration flag has no effect on ``DatabasePool`` reader
    /// connections: those never allow leaving a transaction opened at the end
    /// of a read access.
    public var allowsUnsafeTransactions = false
    
    // MARK: - Concurrency
    
    /// Defines the how `SQLITE_BUSY` errors are handled.
    ///
    /// The default is ``Database/BusyMode/immediateError``.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/rescode.html#busy>
    public var busyMode: Database.BusyMode = .immediateError
    
    /// The behavior in case of SQLITE_BUSY error, for read-only connections.
    /// If nil, GRDB picks a default one.
    var readonlyBusyMode: Database.BusyMode? = nil
    
    /// The maximum number of concurrent readers.
    ///
    /// This configuration applies to ``DatabasePool`` only. The default value
    /// is 5.
    public var maximumReaderCount: Int = 5
    
    /// The quality of service, or the execution priority, or database accesses.
    ///
    /// The quality of service is ignored if you supply a ``targetQueue``.
    ///
    /// The default is `userInitiated`.
    public var qos: DispatchQoS = .userInitiated
    
    /// The quality of service of read accesses
    var readQoS: DispatchQoS {
        targetQueue?.qos ?? self.qos
    }
    
    /// The target dispatch queue for database accesses.
    ///
    /// Database connections which are not read-only will prefer
    /// ``writeTargetQueue`` instead, if it is not nil.
    ///
    /// When you use ``DatabasePool``, make sure this queue is concurrent. This
    /// is because in a serial dispatch queue, no concurrent database access can
    /// happen, and you may experience deadlocks.
    ///
    /// If the queue is nil, all database accesses happen in unspecified
    /// dispatch queues whose quality of service is determined by the
    /// ``qos`` property.
    ///
    /// The default is nil.
    public var targetQueue: DispatchQueue? = nil
    
    /// The target dispatch queue for database accesses which are not read-only.
    ///
    /// If this queue is nil, writer connections are controlled
    /// by ``targetQueue``.
    ///
    /// The default is nil.
    public var writeTargetQueue: DispatchQueue? = nil

#if os(iOS)
    /// A boolean value indicating whether the database connection releases
    /// memory when entering the background or upon receiving a memory warning
    /// in iOS.
    ///
    /// The default is true.
    public var automaticMemoryManagement = true
#endif

    // MARK: - Factory Configuration
    
    /// Creates a factory configuration.
    public init() { }
    
    // MARK: - Not Public
    
    var threadingMode: Database.ThreadingMode = .`default`
    var SQLiteConnectionDidOpen: (() -> Void)?
    var SQLiteConnectionWillClose: ((SQLiteConnection) -> Void)?
    var SQLiteConnectionDidClose: (() -> Void)?
    var SQLiteOpenFlags: CInt {
        var flags = readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
        if sqlite3_libversion_number() >= 3037000 {
            flags |= 0x02000000 // SQLITE_OPEN_EXRESCODE
        }
        return threadingMode.SQLiteOpenFlags | flags
    }
    
    func setUp(_ db: Database) throws {
        for f in setups {
            try f(db)
        }
    }
    
    func identifier(defaultLabel: String, purpose: String? = nil) -> String {
        (self.label ?? defaultLabel) + (purpose.map { "." + $0 } ?? "")
    }
    
    /// Creates a DispatchQueue which has the quality of service and target
    /// queue of write accesses.
    func makeWriterDispatchQueue(label: String) -> DispatchQueue {
        if let targetQueue = writeTargetQueue ?? targetQueue {
            return DispatchQueue(label: label, target: targetQueue)
        } else {
            return DispatchQueue(label: label, qos: qos)
        }
    }
    
    /// Creates a DispatchQueue which has the quality of service and target
    /// queue of read accesses.
    func makeReaderDispatchQueue(label: String) -> DispatchQueue {
        if let targetQueue = targetQueue {
            return DispatchQueue(label: label, target: targetQueue)
        } else {
            return DispatchQueue(label: label, qos: qos)
        }
    }
}
