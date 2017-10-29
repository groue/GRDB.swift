// MARK: - Transactions & Savepoint

extension Database {
    /// Executes a block inside a database transaction.
    ///
    ///     try dbQueue.inDatabase do {
    ///         try db.inTransaction {
    ///             try db.execute("INSERT ...")
    ///             return .commit
    ///         }
    ///     }
    ///
    /// If the block throws an error, the transaction is rollbacked and the
    /// error is rethrown.
    ///
    /// This method is not reentrant: you can't nest transactions.
    ///
    /// - parameters:
    ///     - kind: The transaction type (default nil). If nil, the transaction
    ///       type is configuration.defaultTransactionKind, which itself
    ///       defaults to .immediate. See https://www.sqlite.org/lang_transaction.html
    ///       for more information.
    ///     - block: A block that executes SQL statements and return either
    ///       .commit or .rollback.
    /// - throws: The error thrown by the block.
    public func inTransaction(_ kind: TransactionKind? = nil, _ block: () throws -> TransactionCompletion) throws {
        // Begin transaction
        try beginTransaction(kind)
        
        // Now that transaction has begun, we'll rollback in case of error.
        // But we'll throw the first caught error, so that user knows
        // what happened.
        var firstError: Error? = nil
        let needsRollback: Bool
        do {
            let completion = try block()
            switch completion {
            case .commit:
                try commit()
                needsRollback = false
            case .rollback:
                needsRollback = true
            }
        } catch {
            firstError = error
            needsRollback = true
        }
        
        if needsRollback {
            do {
                try rollback()
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        if let firstError = firstError {
            throw firstError
        }
    }
    
    /// Executes a block inside a savepoint.
    ///
    ///     try dbQueue.inDatabase do {
    ///         try db.inSavepoint {
    ///             try db.execute("INSERT ...")
    ///             return .commit
    ///         }
    ///     }
    ///
    /// If the block throws an error, the savepoint is rollbacked and the
    /// error is rethrown.
    ///
    /// This method is reentrant: you can nest savepoints.
    ///
    /// - parameter block: A block that executes SQL statements and return
    ///   either .commit or .rollback.
    /// - throws: The error thrown by the block.
    public func inSavepoint(_ block: () throws -> TransactionCompletion) throws {
        // By default, top level SQLite savepoints open a deferred transaction.
        //
        // But GRDB database configuration mandates a default transaction kind
        // that we have to honor.
        //
        // So when the default GRDB transaction kind is not deferred, we open a
        // transaction instead
        guard isInsideTransaction || configuration.defaultTransactionKind == .deferred else {
            return try inTransaction(nil, block)
        }

        // If the savepoint is top-level, we'll use ROLLBACK TRANSACTION in
        // order to perform the special error handling of rollbacks (see
        // the rollback method).
        let topLevelSavepoint = !isInsideTransaction
        
        // Begin savepoint
        //
        // We use a single name for savepoints because there is no need
        // using unique savepoint names. User could still mess with them
        // with raw SQL queries, but let's assume that it is unlikely that
        // the user uses "grdb" as a savepoint name.
        try execute("SAVEPOINT grdb")
        
        // Now that savepoint has begun, we'll rollback in case of error.
        // But we'll throw the first caught error, so that user knows
        // what happened.
        var firstError: Error? = nil
        let needsRollback: Bool
        do {
            let completion = try block()
            switch completion {
            case .commit:
                try execute("RELEASE SAVEPOINT grdb")
                needsRollback = false
            case .rollback:
                needsRollback = true
            }
        } catch {
            firstError = error
            needsRollback = true
        }
        
        if needsRollback {
            do {
                if topLevelSavepoint {
                    try rollback()
                } else {
                    // Rollback, and release the savepoint.
                    // Rollback alone is not enough to clear the savepoint from
                    // the SQLite savepoint stack.
                    try execute("ROLLBACK TRANSACTION TO SAVEPOINT grdb")
                    try execute("RELEASE SAVEPOINT grdb")
                }
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }
        
        if let firstError = firstError {
            throw firstError
        }
    }
    
    func beginTransaction(_ kind: TransactionKind? = nil) throws {
        switch kind ?? configuration.defaultTransactionKind {
        case .deferred:
            try execute("BEGIN DEFERRED TRANSACTION")
        case .immediate:
            try execute("BEGIN IMMEDIATE TRANSACTION")
        case .exclusive:
            try execute("BEGIN EXCLUSIVE TRANSACTION")
        }
    }
    
    private func rollback() throws {
        // The SQLite documentation contains two related but distinct techniques
        // to handle rollbacks and errors:
        //
        // https://www.sqlite.org/lang_transaction.html#immediate
        //
        // > Response To Errors Within A Transaction
        // >
        // > If certain kinds of errors occur within a transaction, the
        // > transaction may or may not be rolled back automatically.
        // > The errors that can cause an automatic rollback include:
        // >
        // > - SQLITE_FULL: database or disk full
        // > - SQLITE_IOERR: disk I/O error
        // > - SQLITE_BUSY: database in use by another process
        // > - SQLITE_NOMEM: out or memory
        // >
        // > [...] It is recommended that applications respond to the
        // > errors listed above by explicitly issuing a ROLLBACK
        // > command. If the transaction has already been rolled back
        // > automatically by the error response, then the ROLLBACK
        // > command will fail with an error, but no harm is caused
        // > by this.
        //
        // https://sqlite.org/c3ref/get_autocommit.html
        //
        // > The sqlite3_get_autocommit() interface returns non-zero or zero if
        // > the given database connection is or is not in autocommit mode,
        // > respectively.
        // >
        // > [...] If certain kinds of errors occur on a statement within a
        // > multi-statement transaction (errors including SQLITE_FULL,
        // > SQLITE_IOERR, SQLITE_NOMEM, SQLITE_BUSY, and SQLITE_INTERRUPT) then
        // > the transaction might be rolled back automatically. The only way to
        // > find out whether SQLite automatically rolled back the transaction
        // > after an error is to use this function.
        //
        // The second technique is more robust, because we don't have to guess
        // which rollback errors should be ignored, and which rollback errors
        // should be exposed to the library user.
        if sqlite3_get_autocommit(sqliteConnection) == 0 {
            try execute("ROLLBACK TRANSACTION")
        }
    }
    
    func commit() throws {
        try execute("COMMIT TRANSACTION")
    }
    
    /// Add a transaction observer, so that it gets notified of
    /// database changes.
    ///
    /// - parameter transactionObserver: A transaction observer.
    /// - parameter extent: The duration of the observation. The default is
    ///   the observer lifetime (observation lasts until observer
    ///   is deallocated).
    public func add(transactionObserver: TransactionObserver, extent: TransactionObservationExtent = .observerLifetime) {
        SchedulingWatchdog.preconditionValidQueue(self)
        transactionObservers.append(ManagedTransactionObserver(observer: transactionObserver, extent: extent))
        if transactionObservers.count == 1 {
            installUpdateHook()
        }
    }
    
    /// Remove a transaction observer.
    public func remove(transactionObserver: TransactionObserver) {
        SchedulingWatchdog.preconditionValidQueue(self)
        transactionObservers.removeFirst { $0.isWrapping(transactionObserver) }
        if transactionObservers.isEmpty {
            uninstallUpdateHook()
        }
    }
    
    /// Registers a closure to be executed after the next or current
    /// transaction completion.
    ///
    ///     dbQueue.inTransaction { db in
    ///         db.afterNextTransactionCommit { _ in
    ///             print("commit did succeed")
    ///         }
    ///         ...
    ///         return .commit // prints "commit did succeed"
    ///     }
    ///
    /// If the transaction is rollbacked, the closure is not executed.
    ///
    /// If the transaction is committed, the closure is executed in a protected
    /// dispatch queue, serialized will all database updates.
    public func afterNextTransactionCommit(_ closure: @escaping (Database) -> ()) {
        class CommitHandler : TransactionObserver {
            let closure: (Database) -> ()
            
            init(_ closure: @escaping (Database) -> ()) {
                self.closure = closure
            }
            
            // Ignore individual changes and transaction rollbacks
            func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { return false }
            #if SQLITE_ENABLE_PREUPDATE_HOOK
            func databaseWillChange(with event: DatabasePreUpdateEvent) { }
            #endif
            func databaseDidChange(with event: DatabaseEvent) { }
            func databaseWillCommit() throws { }
            func databaseDidRollback(_ db: Database) { }
            
            // On commit, run closure
            func databaseDidCommit(_ db: Database) {
                closure(db)
            }
        }
        
        add(transactionObserver: CommitHandler(closure), extent: .nextTransaction)
    }
    
    /// Remove transaction observers that have stopped observing transaction,
    /// and uninstall SQLite update hooks if there is no remaining observers.
    private func cleanupTransactionObservers() {
        transactionObservers = transactionObservers.filter { $0.isObserving }
        if transactionObservers.isEmpty {
            uninstallUpdateHook()
        }
    }
    
    /// Checks that a SQL query is valid for a select statement.
    ///
    /// Select statements do not call database.updateStatementDidExecute().
    /// Here we make sure that the update statements we track are not hidden in
    /// a select statement.
    ///
    /// An INSERT statement will pass, but not DROP TABLE (which invalidates the
    /// database cache), or RELEASE SAVEPOINT (which alters the savepoint stack)
    static func preconditionValidSelectStatement(sql: String, authorizer: StatementCompilationAuthorizer) {
        GRDBPrecondition(authorizer.invalidatesDatabaseSchemaCache == false, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
        GRDBPrecondition(authorizer.transactionStatementInfo == nil, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
        
        // Don't check for authorizer.databaseEventKinds.isEmpty
        //
        // When authorizer.databaseEventKinds.isEmpty is NOT empty, this means
        // that the database is changed by the statement.
        //
        // It thus looks like the statement should be performed by an
        // UpdateStatement, not a SelectStatement: transaction authorizers are not
        // notified of database changes when they are executed by
        // a SelectStatement.
        //
        // However https://github.com/groue/GRDB.swift/issues/80 and
        // https://github.com/groue/GRDB.swift/issues/82 have shown that SELECT
        // statements on virtual tables can generate database changes.
        //
        // :-(
        //
        // OK, this is getting very difficult to protect the user against
        // himself: just give up, and allow SelectStatement to execute database
        // changes. We'll cope with eventual troubles later, when they occur.
        //
        // GRDBPrecondition(authorizer.databaseEventKinds.isEmpty, "Invalid statement type for query \(String(reflecting: sql)): use UpdateStatement instead.")
    }
    
    func updateStatementWillExecute(_ statement: UpdateStatement) {
        // Grab the transaction observers that are interested in the actions
        // performed by the statement.
        let databaseEventKinds = statement.databaseEventKinds
        activeTransactionObservers = transactionObservers.filter { observer in
            return databaseEventKinds.contains(where: observer.observes)
        }
    }
    
    func selectStatementDidFail(_ statement: SelectStatement) {
        // Failed statements can not be reused, because sqlite3_reset won't
        // be able to restore the statement to its initial state:
        // https://www.sqlite.org/c3ref/reset.html
        //
        // So make sure we clear this statement from the cache.
        internalStatementCache.remove(statement)
        publicStatementCache.remove(statement)
    }
    
    /// Some failed statements interest transaction observers.
    func updateStatementDidFail(_ statement: UpdateStatement) throws {
        // Wait for next statement
        activeTransactionObservers = []
        
        // Reset transactionHookState before didRollback eventually executes
        // other statements.
        let transactionHookState = self.transactionHookState
        self.transactionHookState = .pending
        
        // Failed statements can not be reused, because sqlite3_reset won't
        // be able to restore the statement to its initial state:
        // https://www.sqlite.org/c3ref/reset.html
        //
        // So make sure we clear this statement from the cache.
        internalStatementCache.remove(statement)
        publicStatementCache.remove(statement)
        
        switch transactionHookState {
        case .rollback:
            // Don't notify observers because we're in a failed implicit
            // transaction here (like an INSERT which fails with
            // SQLITE_CONSTRAINT error)
            didRollback(notifyTransactionObservers: false)
        case .cancelledCommit(let error):
            didRollback(notifyTransactionObservers: true)
            throw error
        default:
            break
        }
    }
    
    /// Some succeeded statements invalidate the database cache, others interest
    /// transaction observers, and others modify the savepoint stack.
    func updateStatementDidExecute(_ statement: UpdateStatement) {
        // Wait for next statement
        activeTransactionObservers = []
        
        if statement.invalidatesDatabaseSchemaCache {
            clearSchemaCache()
        }
        
        if let transactionStatementInfo = statement.transactionStatementInfo {
            switch transactionStatementInfo {
            case .transaction(action: let action):
                switch action {
                case .begin:
                    break
                case .commit:
                    if case .pending = self.transactionHookState {
                        // A COMMIT statement has ended a deferred transaction
                        // that did not open, and sqlite_commit_hook was not
                        // called.
                        //
                        //  BEGIN DEFERRED TRANSACTION
                        //  COMMIT
                        self.transactionHookState = .commit
                    }
                case .rollback:
                    break
                }
            case .savepoint(name: let name, action: let action):
                switch action {
                case .begin:
                    savepointStack.beginSavepoint(named: name)
                case .release:
                    savepointStack.releaseSavepoint(named: name)
                    if savepointStack.isEmpty {
                        let eventsBuffer = savepointStack.eventsBuffer
                        savepointStack.clear()
                        for (event, observers) in eventsBuffer {
                            for observer in observers {
                                event.send(to: observer)
                            }
                        }
                    }
                case .rollback:
                    savepointStack.rollbackSavepoint(named: name)
                }
            }
        }
        
        // Reset transactionHookState before didCommit or didRollback eventually
        // execute other statements.
        let transactionHookState = self.transactionHookState
        self.transactionHookState = .pending
        
        switch transactionHookState {
        case .commit:
            didCommit()
        case .rollback:
            didRollback(notifyTransactionObservers: true)
        default:
            break
        }
    }
    
    /// See sqlite3_commit_hook
    func willCommit() throws {
        let eventsBuffer = savepointStack.eventsBuffer
        savepointStack.clear()

        for (event, observers) in eventsBuffer {
            for observer in observers {
                event.send(to: observer)
            }
        }
        for observer in transactionObservers {
            try observer.databaseWillCommit()
        }
    }
    
#if SQLITE_ENABLE_PREUPDATE_HOOK
    /// See sqlite3_preupdate_hook
    private func willChange(with event: DatabasePreUpdateEvent) {
        if savepointStack.isEmpty {
            // Notify all interested transactionObservers.
            for observer in activeTransactionObservers {
                observer.databaseWillChange(with: event)
            }
        } else {
            // Buffer both event and the observers that should be notified of the event.
            savepointStack.eventsBuffer.append((event: event.copy(), observers: activeTransactionObservers))
        }
    }
#endif
    
    /// See sqlite3_update_hook
    private func didChange(with event: DatabaseEvent) {
        if savepointStack.isEmpty {
            // Notify all interested transactionObservers.
            for observer in activeTransactionObservers {
                observer.databaseDidChange(with: event)
            }
        } else {
            // Buffer both event and the observers that should be notified of the event.
            savepointStack.eventsBuffer.append((event: event.copy(), observers: activeTransactionObservers))
        }
    }
    
    private func didCommit() {
        savepointStack.clear()
        
        for observer in transactionObservers {
            observer.databaseDidCommit(self)
        }
        cleanupTransactionObservers()
    }
    
    private func didRollback(notifyTransactionObservers: Bool) {
        savepointStack.clear()
        
        if notifyTransactionObservers {
            for observer in transactionObservers {
                observer.databaseDidRollback(self)
            }
        }
        cleanupTransactionObservers()
    }
    
    private func installUpdateHook() {
        let dbPointer = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_update_hook(sqliteConnection, { (dbPointer, updateKind, databaseNameCString, tableNameCString, rowID) in
            let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
            db.didChange(with: DatabaseEvent(
                kind: DatabaseEvent.Kind(rawValue: updateKind)!,
                rowID: rowID,
                databaseNameCString: databaseNameCString,
                tableNameCString: tableNameCString))
        }, dbPointer)
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            sqlite3_preupdate_hook(sqliteConnection, { (dbPointer, databaseConnection, updateKind, databaseNameCString, tableNameCString, initialRowID, finalRowID) in
                let db = Unmanaged<Database>.fromOpaque(dbPointer!).takeUnretainedValue()
                db.willChange(with: DatabasePreUpdateEvent(
                    connection: databaseConnection!,
                    kind: DatabasePreUpdateEvent.Kind(rawValue: updateKind)!,
                    initialRowID: initialRowID,
                    finalRowID: finalRowID,
                    databaseNameCString: databaseNameCString,
                    tableNameCString: tableNameCString))
            }, dbPointer)
        #endif
    }
    
    private func uninstallUpdateHook() {
        sqlite3_update_hook(sqliteConnection, nil, nil)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            sqlite3_preupdate_hook(sqliteConnection, nil, nil)
        #endif
    }
    
    /// The extent of a transaction observation
    ///
    /// See Database.add(transactionObserver:extent:)
    public enum TransactionObservationExtent {
        /// Observation lasts until observer is deallocated
        case observerLifetime
        /// Observation lasts until the next transaction
        case nextTransaction
        /// Observation lasts until the database is closed
        case databaseLifetime
    }
    
    /// The states that keep track of transaction completions in order to notify
    /// transaction observers.
    enum TransactionHookState {
        case pending
        case commit
        case rollback
        case cancelledCommit(Error)
    }
}

/// A transaction observer is notified of all changes and transactions committed
/// or rollbacked on a database.
///
/// Adopting types must be a class.
public protocol TransactionObserver : class {
    
    /// Filters database changes that should be notified the the
    /// databaseDidChange(with:) method.
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool
    
    /// Notifies a database change (insert, update, or delete).
    ///
    /// The change is pending until the end of the current transaction, notified
    /// to databaseWillCommit, databaseDidCommit and databaseDidRollback.
    ///
    /// This method is called on the database queue.
    ///
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy of its properties.
    ///
    /// - warning: this method must not change the database.
    func databaseDidChange(with event: DatabaseEvent)
    
    /// When a transaction is about to be committed, the transaction observer
    /// has an opportunity to rollback pending changes by throwing an error.
    ///
    /// This method is called on the database queue.
    ///
    /// - warning: this method must not change the database.
    ///
    /// - throws: An eventual error that rollbacks pending changes.
    func databaseWillCommit() throws
    
    /// Database changes have been committed.
    ///
    /// This method is called on the database queue. It can change the database.
    func databaseDidCommit(_ db: Database)
    
    /// Database changes have been rollbacked.
    ///
    /// This method is called on the database queue. It can change the database.
    func databaseDidRollback(_ db: Database)
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    /// Notifies before a database change (insert, update, or delete)
    /// with change information (initial / final values for the row's
    /// columns). (Called *before* databaseDidChangeWithEvent.)
    ///
    /// The change is pending until the end of the current transaction,
    /// and you always get a second chance to get basic event information in
    /// the databaseDidChangeWithEvent callback.
    ///
    /// This callback is mostly useful for calculating detailed change
    /// information for a row, and provides the initial / final values.
    ///
    /// This method is called on the database queue.
    ///
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy of its properties.
    ///
    /// - warning: this method must not change the database.
    ///
    /// Availability Info:
    ///
    ///     Requires SQLite 3.13.0 +
    ///     Compiled with option SQLITE_ENABLE_PREUPDATE_HOOK
    ///
    ///     As of OSX 10.11.5, and iOS 9.3.2, the built-in SQLite library
    ///     does not have this enabled, so you'll need to compile your own
    ///     copy using GRDBCustomSQLite. See the README.md in /SQLiteCustom/
    ///
    ///     The databaseDidChangeWithEvent callback is always available,
    ///     and may provide most/all of what you need.
    ///     (For example, FetchedRecordsController is built without using
    ///     this functionality.)
    ///
    func databaseWillChange(with event: DatabasePreUpdateEvent)
    #endif
}

/// This class manages the observation extent of a transaction observer
final class ManagedTransactionObserver {
    let extent: Database.TransactionObservationExtent
    private weak var weakObserver: TransactionObserver?
    private var strongObserver: TransactionObserver?
    private var observer: TransactionObserver? { return strongObserver ?? weakObserver }
    
    fileprivate var isObserving: Bool {
        return observer != nil
    }
    
    init(observer: TransactionObserver, extent: Database.TransactionObservationExtent) {
        self.extent = extent
        switch extent {
        case .observerLifetime:
            weakObserver = observer
        case .nextTransaction:
            // This strong reference will be released in databaseDidCommit() and databaseDidRollback()
            strongObserver = observer
        case .databaseLifetime:
            strongObserver = observer
        }
    }
    
    func isWrapping(_ observer: TransactionObserver) -> Bool {
        return self.observer === observer
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return observer?.observes(eventsOfKind: eventKind) ?? false
    }

    func databaseDidChange(with event: DatabaseEvent) {
        observer?.databaseDidChange(with: event)
    }

    func databaseWillCommit() throws {
        try observer?.databaseWillCommit()
    }

    func databaseDidCommit(_ db: Database) {
        switch extent {
        case .observerLifetime, .databaseLifetime:
            observer?.databaseDidCommit(db)
        case .nextTransaction:
            if let observer = self.observer {
                // make sure observer is no longer notified
                strongObserver = nil
                observer.databaseDidCommit(db)
            }
        }
    }

    func databaseDidRollback(_ db: Database) {
        switch extent {
        case .observerLifetime, .databaseLifetime:
            observer?.databaseDidRollback(db)
        case .nextTransaction:
            if let observer = self.observer {
                // make sure observer is no longer notified
                strongObserver = nil
                observer.databaseDidRollback(db)
            }
        }
    }

    #if SQLITE_ENABLE_PREUPDATE_HOOK
    func databaseWillChange(with event: DatabasePreUpdateEvent) {
        observer?.databaseWillChange(with: event)
    }
    #endif
}

/// A kind of database event. See Database.add(transactionObserver:)
/// and DatabaseWriter.add(transactionObserver:).
public enum DatabaseEventKind {
    /// The insertion of a row in a database table
    case insert(tableName: String)
    
    /// The deletion of a row in a database table
    case delete(tableName: String)
    
    /// The update of a set of columns in a database table
    case update(tableName: String, columnNames: Set<String>)
    
    /// Returns whether event has any impact on tables and columns described
    /// by selectionInfo.
    public func impacts(_ selectionInfo: SelectStatement.SelectionInfo) -> Bool {
        switch self {
        case .delete(let tableName):
            return selectionInfo.contains(anyColumnFrom: tableName)
        case .insert(let tableName):
            return selectionInfo.contains(anyColumnFrom: tableName)
        case .update(let tableName, let updatedColumnNames):
            return selectionInfo.contains(anyColumnIn: updatedColumnNames, from: tableName)
        }
    }

}

extension DatabaseEventKind {
    /// The impacted database table
    public var tableName: String {
        switch self {
        case .insert(tableName: let tableName): return tableName
        case .delete(tableName: let tableName): return tableName
        case .update(tableName: let tableName, columnNames: _): return tableName
        }
    }
}

protocol DatabaseEventProtocol {
    func send(to observer: ManagedTransactionObserver)
}

/// A database event, notified to TransactionObserver.
public struct DatabaseEvent {
    
    /// An event kind
    public enum Kind: Int32 {
        /// SQLITE_INSERT
        case insert = 18
        
        /// SQLITE_DELETE
        case delete = 9
        
        /// SQLITE_UPDATE
        case update = 23
    }
    
    /// The event kind
    public let kind: Kind
    
    /// The database name
    public var databaseName: String { return impl.databaseName }

    /// The table name
    public var tableName: String { return impl.tableName }
    
    /// The rowID of the changed row.
    public let rowID: Int64
    
    /// Returns an event that can be stored:
    ///
    ///     class MyObserver: TransactionObserver {
    ///         var events: [DatabaseEvent]
    ///         func databaseDidChange(with event: DatabaseEvent) {
    ///             events.append(event.copy())
    ///         }
    ///     }
    public func copy() -> DatabaseEvent {
        return impl.copy(self)
    }
    
    fileprivate init(kind: Kind, rowID: Int64, impl: DatabaseEventImpl) {
        self.kind = kind
        self.rowID = rowID
        self.impl = impl
    }
    
    init(kind: Kind, rowID: Int64, databaseNameCString: UnsafePointer<Int8>?, tableNameCString: UnsafePointer<Int8>?) {
        self.init(kind: kind, rowID: rowID, impl: MetalDatabaseEventImpl(databaseNameCString: databaseNameCString, tableNameCString: tableNameCString))
    }
    
    private let impl: DatabaseEventImpl
}

extension DatabaseEvent : DatabaseEventProtocol {
    func send(to observer: ManagedTransactionObserver) {
        observer.databaseDidChange(with: self)
    }
}

/// Protocol for internal implementation of DatabaseEvent
private protocol DatabaseEventImpl {
    var databaseName: String { get }
    var tableName: String { get }
    func copy(_ event: DatabaseEvent) -> DatabaseEvent
}

/// Optimization: MetalDatabaseEventImpl does not create Swift strings from raw
/// SQLite char* until actually asked for databaseName or tableName.
private struct MetalDatabaseEventImpl : DatabaseEventImpl {
    let databaseNameCString: UnsafePointer<Int8>?
    let tableNameCString: UnsafePointer<Int8>?

    var databaseName: String { return String(cString: databaseNameCString!) }
    var tableName: String { return String(cString: tableNameCString!) }
    func copy(_ event: DatabaseEvent) -> DatabaseEvent {
        return DatabaseEvent(kind: event.kind, rowID: event.rowID, impl: CopiedDatabaseEventImpl(databaseName: databaseName, tableName: tableName))
    }
}

/// Impl for DatabaseEvent that contains copies of event strings.
private struct CopiedDatabaseEventImpl : DatabaseEventImpl {
    let databaseName: String
    let tableName: String
    func copy(_ event: DatabaseEvent) -> DatabaseEvent {
        return event
    }
}

#if SQLITE_ENABLE_PREUPDATE_HOOK

    public struct DatabasePreUpdateEvent {
        
        /// An event kind
        public enum Kind: Int32 {
            /// SQLITE_INSERT
            case insert = 18
            
            /// SQLITE_DELETE
            case delete = 9
            
            /// SQLITE_UPDATE
            case update = 23
        }
        
        /// The event kind
        public let kind: Kind
        
        /// The database name
        public var databaseName: String { return impl.databaseName }
        
        /// The table name
        public var tableName: String { return impl.tableName }
        
        /// The number of columns in the row that is being inserted, updated, or deleted.
        public var count: Int { return Int(impl.columnsCount) }
        
        /// The triggering depth of the row update
        /// Returns:
        ///     0  if the preupdate callback was invoked as a result of a direct insert,
        //         update, or delete operation;
        ///     1  for inserts, updates, or deletes invoked by top-level triggers;
        ///     2  for changes resulting from triggers called by top-level triggers;
        ///     ... and so forth
        public var depth: CInt { return impl.depth }
        
        /// The initial rowID of the row being changed for .Update and .Delete changes,
        /// and nil for .Insert changes.
        public let initialRowID: Int64?
        
        /// The final rowID of the row being changed for .Update and .Insert changes,
        /// and nil for .Delete changes.
        public let finalRowID: Int64?
        
        /// The initial database values in the row.
        ///
        /// Values appear in the same order as the columns in the table.
        ///
        /// The result is nil if the event is an .Insert event.
        public var initialDatabaseValues: [DatabaseValue]? {
            guard (kind == .update || kind == .delete) else { return nil }
            return impl.initialDatabaseValues
        }
        
        /// Returns the initial `DatabaseValue` at given index.
        ///
        /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
        /// righmost column.
        ///
        /// The result is nil if the event is an .Insert event.
        public func initialDatabaseValue(atIndex index: Int) -> DatabaseValue? {
            GRDBPrecondition(index >= 0 && index < count, "row index out of range")
            guard (kind == .update || kind == .delete) else { return nil }
            return impl.initialDatabaseValue(atIndex: index)
        }
        
        /// The final database values in the row.
        ///
        /// Values appear in the same order as the columns in the table.
        ///
        /// The result is nil if the event is a .Delete event.
        public var finalDatabaseValues: [DatabaseValue]? {
            guard (kind == .update || kind == .insert) else { return nil }
            return impl.finalDatabaseValues
        }
        
        /// Returns the final `DatabaseValue` at given index.
        ///
        /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
        /// righmost column.
        ///
        /// The result is nil if the event is a .Delete event.
        public func finalDatabaseValue(atIndex index: Int) -> DatabaseValue? {
            GRDBPrecondition(index >= 0 && index < count, "row index out of range")
            guard (kind == .update || kind == .insert) else { return nil }
            return impl.finalDatabaseValue(atIndex: index)
        }
        
        /// Returns an event that can be stored:
        ///
        ///     class MyObserver: TransactionObserver {
        ///         var events: [DatabasePreUpdateEvent]
        ///         func databaseWillChange(with event: DatabasePreUpdateEvent) {
        ///             events.append(event.copy())
        ///         }
        ///     }
        public func copy() -> DatabasePreUpdateEvent {
            return impl.copy(self)
        }
        
        fileprivate init(kind: Kind, initialRowID: Int64?, finalRowID: Int64?, impl: DatabasePreUpdateEventImpl) {
            self.kind = kind
            self.initialRowID = (kind == .update || kind == .delete ) ? initialRowID : nil
            self.finalRowID = (kind == .update || kind == .insert ) ? finalRowID : nil
            self.impl = impl
        }
        
        init(connection: SQLiteConnection, kind: Kind, initialRowID: Int64, finalRowID: Int64, databaseNameCString: UnsafePointer<Int8>?, tableNameCString: UnsafePointer<Int8>?) {
            self.init(kind: kind,
                      initialRowID: (kind == .update || kind == .delete ) ? finalRowID : nil,
                      finalRowID: (kind == .update || kind == .insert ) ? finalRowID : nil,
                      impl: MetalDatabasePreUpdateEventImpl(connection: connection, kind: kind, databaseNameCString: databaseNameCString, tableNameCString: tableNameCString))
        }
        
        private let impl: DatabasePreUpdateEventImpl
    }
    
    extension DatabasePreUpdateEvent : DatabaseEventProtocol {
        func send(to observer: ManagedTransactionObserver) {
            observer.databaseWillChange(with: self)
        }
    }
    
    /// Protocol for internal implementation of DatabaseEvent
    private protocol DatabasePreUpdateEventImpl {
        var databaseName: String { get }
        var tableName: String { get }
        
        var columnsCount: CInt { get }
        var depth: CInt { get }
        var initialDatabaseValues: [DatabaseValue]? { get }
        var finalDatabaseValues: [DatabaseValue]? { get }
        
        func initialDatabaseValue(atIndex index: Int) -> DatabaseValue?
        func finalDatabaseValue(atIndex index: Int) -> DatabaseValue?
        
        func copy(_ event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent
    }
    
    /// Optimization: MetalDatabasePreUpdateEventImpl does not create Swift strings from raw
    /// SQLite char* until actually asked for databaseName or tableName,
    /// nor does it request other data via the sqlite3_preupdate_* APIs
    /// until asked.
    private struct MetalDatabasePreUpdateEventImpl : DatabasePreUpdateEventImpl {
        let connection: SQLiteConnection
        let kind: DatabasePreUpdateEvent.Kind
        
        let databaseNameCString: UnsafePointer<Int8>?
        let tableNameCString: UnsafePointer<Int8>?
        
        var databaseName: String { return String(cString: databaseNameCString!) }
        var tableName: String { return String(cString: tableNameCString!) }
        
        var columnsCount: CInt { return sqlite3_preupdate_count(connection) }
        var depth: CInt { return sqlite3_preupdate_depth(connection) }
        var initialDatabaseValues: [DatabaseValue]? {
            guard (kind == .update || kind == .delete) else { return nil }
            return preupdate_getValues_old(connection)
        }
        
        var finalDatabaseValues: [DatabaseValue]? {
            guard (kind == .update || kind == .insert) else { return nil }
            return preupdate_getValues_new(connection)
        }
        
        func initialDatabaseValue(atIndex index: Int) -> DatabaseValue? {
            let columnCount = columnsCount
            precondition(index >= 0 && index < Int(columnCount), "row index out of range")
            return getValue(connection, column: CInt(index), sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                return sqlite3_preupdate_old(connection, column, &value)
            })
        }
        
        func finalDatabaseValue(atIndex index: Int) -> DatabaseValue? {
            let columnCount = columnsCount
            precondition(index >= 0 && index < Int(columnCount), "row index out of range")
            return getValue(connection, column: CInt(index), sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                return sqlite3_preupdate_new(connection, column, &value)
            })
        }
        
        func copy(_ event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent {
            return DatabasePreUpdateEvent(kind: event.kind, initialRowID: event.initialRowID, finalRowID: event.finalRowID, impl: CopiedDatabasePreUpdateEventImpl(
                    databaseName: databaseName,
                    tableName: tableName,
                    columnsCount: columnsCount,
                    depth: depth,
                    initialDatabaseValues: initialDatabaseValues,
                    finalDatabaseValues: finalDatabaseValues))
        }
    
        private func preupdate_getValues(_ connection: SQLiteConnection, sqlite_func: (_ connection: SQLiteConnection, _ column: CInt, _ value: inout SQLiteValue? ) -> CInt ) -> [DatabaseValue]? {
            let columnCount = sqlite3_preupdate_count(connection)
            guard columnCount > 0 else { return nil }
            
            var columnValues = [DatabaseValue]()
            
            for i in 0..<columnCount {
                let value = getValue(connection, column: i, sqlite_func: sqlite_func)!
                columnValues.append(value)
            }
            
            return columnValues
        }
        
        private func getValue(_ connection: SQLiteConnection, column: CInt, sqlite_func: (_ connection: SQLiteConnection, _ column: CInt, _ value: inout SQLiteValue? ) -> CInt ) -> DatabaseValue? {
            var value : SQLiteValue? = nil
            guard sqlite_func(connection, column, &value) == SQLITE_OK else { return nil }
            if let value = value {
                return DatabaseValue(sqliteValue: value)
            }
            return nil
        }
        
        private func preupdate_getValues_old(_ connection: SQLiteConnection) -> [DatabaseValue]? {
            return preupdate_getValues(connection, sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                return sqlite3_preupdate_old(connection, column, &value)
            })
        }
        
        private func preupdate_getValues_new(_ connection: SQLiteConnection) -> [DatabaseValue]? {
            return preupdate_getValues(connection, sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                return sqlite3_preupdate_new(connection, column, &value)
            })
        }
    }
    
    /// Impl for DatabasePreUpdateEvent that contains copies of all event data.
    private struct CopiedDatabasePreUpdateEventImpl : DatabasePreUpdateEventImpl {
        let databaseName: String
        let tableName: String
        let columnsCount: CInt
        let depth: CInt
        let initialDatabaseValues: [DatabaseValue]?
        let finalDatabaseValues: [DatabaseValue]?
        
        func initialDatabaseValue(atIndex index: Int) -> DatabaseValue? { return initialDatabaseValues?[index] }
        func finalDatabaseValue(atIndex index: Int) -> DatabaseValue? { return finalDatabaseValues?[index] }
        
        func copy(_ event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent {
            return event
        }
    }

#endif

/// The SQLite savepoint stack is described at
/// https://www.sqlite.org/lang_savepoint.html
///
/// This class reimplements the SQLite stack, so that we can:
///
/// - know if there are currently active savepoints (isEmpty)
/// - buffer database events when a savepoint is active, in order to avoid
///   notifying transaction observers of database events that could be
///   rollbacked.
class SavepointStack {
    /// The buffered events. See Database.didChange(with:)
    fileprivate var eventsBuffer: [(event: DatabaseEventProtocol, observers: [ManagedTransactionObserver])] = []
    
    /// The savepoint stack, as an array of tuples (savepointName, index in the eventsBuffer array).
    /// Indexes let us drop rollbacked events from the event buffer.
    private var savepoints: [(name: String, index: Int)] = []
    
    var isEmpty: Bool { return savepoints.isEmpty }
    
    func clear() {
        eventsBuffer.removeAll()
        savepoints.removeAll()
    }
    
    func beginSavepoint(named name: String) {
        savepoints.append((name: name.lowercased(), index: eventsBuffer.count))
    }
    
    // https://www.sqlite.org/lang_savepoint.html
    // > The ROLLBACK command with a TO clause rolls back transactions going
    // > backwards in time back to the most recent SAVEPOINT with a matching
    // > name. The SAVEPOINT with the matching name remains on the transaction
    // > stack, but all database changes that occurred after that SAVEPOINT was
    // > created are rolled back. If the savepoint-name in a ROLLBACK TO
    // > command does not match any SAVEPOINT on the stack, then the ROLLBACK
    // > command fails with an error and leaves the state of the
    // > database unchanged.
    func rollbackSavepoint(named name: String) {
        let name = name.lowercased()
        while let pair = savepoints.last, pair.name != name {
            savepoints.removeLast()
        }
        if let savepoint = savepoints.last {
            eventsBuffer.removeLast(eventsBuffer.count - savepoint.index)
        }
        assert(!savepoints.isEmpty || eventsBuffer.isEmpty)
    }
    
    // https://www.sqlite.org/lang_savepoint.html
    // > The RELEASE command starts with the most recent addition to the
    // > transaction stack and releases savepoints backwards in time until it
    // > releases a savepoint with a matching savepoint-name. Prior savepoints,
    // > even savepoints with matching savepoint-names, are unchanged.
    func releaseSavepoint(named name: String) {
        let name = name.lowercased()
        while let pair = savepoints.last, pair.name != name {
            savepoints.removeLast()
        }
        if !savepoints.isEmpty {
            savepoints.removeLast()
        }
    }
}
