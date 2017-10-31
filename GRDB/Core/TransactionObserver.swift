#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

extension Database {

    // MARK: - Database Observation
    
    /// Add a transaction observer, so that it gets notified of
    /// database changes.
    ///
    /// - parameter transactionObserver: A transaction observer.
    /// - parameter extent: The duration of the observation. The default is
    ///   the observer lifetime (observation lasts until observer
    ///   is deallocated).
    public func add(transactionObserver: TransactionObserver, extent: TransactionObservationExtent = .observerLifetime) {
        SchedulingWatchdog.preconditionValidQueue(self)
        observationBroker.add(transactionObserver: transactionObserver, extent: extent)
    }
    
    /// Remove a transaction observer.
    public func remove(transactionObserver: TransactionObserver) {
        SchedulingWatchdog.preconditionValidQueue(self)
        observationBroker.remove(transactionObserver: transactionObserver)
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
}

/// This class provides support for transaction observers.
///
/// Let's have a detailed look at how a transaction observer is notified:
///
///     class MyObserver: TransactionObserver {
///         func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool
///         func databaseDidChange(with event: DatabaseEvent)
///         func databaseWillCommit() throws
///         func databaseDidCommit(_ db: Database)
///         func databaseDidRollback(_ db: Database)
///     }
///
/// First observer is added, and a transaction is started. At this point,
/// there's not much to say:
///
///     let observer = MyObserver()
///     dbQueue.add(transactionObserver: observer)
///     dbQueue.inDatabase { db in
///         try db.execute("BEGIN TRANSACTION")
///
/// Then a statement is executed:
///
///         try db.execute("INSERT INTO documents ...")
///
/// The observation process starts when the statement is *compiled*:
/// sqlite3_set_authorizer tells that the statement performs insertion into the
/// `documents` table. Generally speaking, statements may have many effects, by
/// the mean of foreign key actions and SQL triggers. SQLite takes care of
/// exposing all those effects to sqlite3_set_authorizer.
///
/// When the statement is *about to be executed*, the broker queries the
/// observer.observes(eventsOfKind:) method. If it returns true, the observer is
/// *activated*.
///
/// During the statement *execution*, SQLite tells that a row has been inserted
/// through sqlite3_update_hook: the broker calls the observer.databaseDidChange(with:)
/// method, if and only if the observer has been activated at the previous step.
///
/// Now a savepoint is started:
///
///         try db.execute("SAVEPOINT foo")
///
/// Statement compilation has sqlite3_set_authorizer tell that this statement
/// begins a "foo" savepoint.
///
/// After the statement *has been executed*, the broker knows that the SQLite
/// [savepoint stack](https://www.sqlite.org/lang_savepoint.html) contains the
/// "foo" savepoint.
///
/// Then another statement is executed:
///
///         try db.execute("INSERT INTO documents ...")
///
/// This time, when the statement is *executed* and SQLite tells that a row has
/// been inserted, the broker buffers the change event instead of immediately
/// notifying the activated observers. That is because the savepoint can be
/// rollbacked, and GRDB guarantees observers that they are only notified of
/// changes that have an opportunity to be committed.
///
/// The savepoint is released:
///
///         try db.execute("RELEASE SAVEPOINT foo")
///
/// Statement compilation has sqlite3_set_authorizer tell that this statement
/// releases the "foo" savepoint.
///
/// After the statement *has been executed*, the broker knows that the SQLite
/// [savepoint stack](https://www.sqlite.org/lang_savepoint.html) is now empty,
/// and notifies the buffered changes to activated observers.
///
/// Finally the transaction is committed:
///
///         try db.execute("COMMIT")
///
/// During the statement *execution*, SQlite tells the broker that the
/// transaction is about to be committed through sqlite3_commit_hook. The broker
/// invokes observer.databaseWillCommit(). If the observer throws an error, the
/// broker asks SQLite to rollback the transaction. Otherwise, the broker lets
/// the transaction complete.
///
/// After the statement *has been executed*, the broker calls
/// observer.databaseDidCommit().
class DatabaseObservationBroker {
    unowned var database: Database
    var savepointStack = SavepointStack()
    var transactionState: TransactionState = .none
    var transactionObservations = [TransactionObservation]()
    var activeTransactionObservations = [TransactionObservation]()
    
    init(_ database: Database) {
        self.database = database
    }
    
    func setup() {
        let brokerPointer = Unmanaged.passUnretained(self).toOpaque()
        
        sqlite3_commit_hook(database.sqliteConnection, { brokerPointer in
            let broker = Unmanaged<DatabaseObservationBroker>.fromOpaque(brokerPointer!).takeUnretainedValue()
            do {
                try broker.databaseWillCommit()
                broker.transactionState = .commit
                // Next step: updateStatementDidExecute()
                return 0
            } catch {
                broker.transactionState = .cancelledCommit(error)
                // Next step: sqlite3_rollback_hook callback
                return 1
            }
        }, brokerPointer)
        
        
        sqlite3_rollback_hook(database.sqliteConnection, { brokerPointer in
            let broker = Unmanaged<DatabaseObservationBroker>.fromOpaque(brokerPointer!).takeUnretainedValue()
            switch broker.transactionState {
            case .cancelledCommit:
                // Next step: updateStatementDidFail()
                break
            default:
                broker.transactionState = .rollback
                // Next step: updateStatementDidExecute()
            }
        }, brokerPointer)
    }
    
    func add(transactionObserver: TransactionObserver, extent: Database.TransactionObservationExtent) {
        transactionObservations.append(TransactionObservation(observer: transactionObserver, extent: extent))
        if transactionObservations.count == 1 {
            installUpdateHook()
        }
    }
    
    func remove(transactionObserver: TransactionObserver) {
        transactionObservations.removeFirst { $0.isWrapping(transactionObserver) }
        if transactionObservations.isEmpty {
            uninstallUpdateHook()
        }
    }
    
    func updateStatementWillExecute(_ statement: UpdateStatement) {
        // Activate the transaction observers that are interested in the actions
        // performed by the statement.
        let databaseEventKinds = statement.databaseEventKinds
        activeTransactionObservations = transactionObservations.filter { observer in
            return databaseEventKinds.contains(where: observer.observes)
        }
    }
    
    func updateStatementDidFail(_ statement: UpdateStatement) throws {
        // Wait for next statement
        activeTransactionObservations = []
        
        // Reset transactionState before databaseDidRollback eventually
        // executes other statements.
        let transactionState = self.transactionState
        self.transactionState = .none
        
        switch transactionState {
        case .rollback:
            // Don't notify observers because we're in a failed implicit
            // transaction here (like an INSERT which fails with
            // SQLITE_CONSTRAINT error)
            databaseDidRollback(notifyTransactionObservers: false)
        case .cancelledCommit(let error):
            databaseDidRollback(notifyTransactionObservers: true)
            throw error
        default:
            break
        }
    }
    
    func updateStatementDidExecute(_ statement: UpdateStatement) {
        // Wait for next statement
        activeTransactionObservations = []
        
        if let transactionEffect = statement.transactionEffect {
            // Statement has modified transaction/savepoint state
            switch transactionEffect {
            case .beginTransaction:
                break
                
            case .commitTransaction:
                if case .none = self.transactionState {
                    // A COMMIT statement has ended an empty deferred
                    // transaction. For SQLite, no transaction has ever begun:
                    //
                    //   BEGIN DEFERRED TRANSACTION
                    //   COMMIT
                    //
                    // We don't need to tell transaction observers about it.
                    //
                    // But we have to take care of the .nextTransaction
                    // observation extent. In the sample code below, the
                    // observer must not be notified of the second transaction,
                    // because this is the intent of the programmer:
                    //
                    //   // Register an observer for next transaction only
                    //   let observer = Observer()
                    //   dbQueue.add(transactionObserver:observer, extent: .nextTransaction)
                    //
                    //   try dbQueue.inTransaction(.deferred) { db in
                    //       return .commit
                    //   }
                    //
                    //   // Must not notify observer
                    //   try dbQueue.inTransaction(.deferred) { db in
                    //       try db.execute("...")
                    //       return .commit
                    //   }
                    emptyDeferredTransactionDidCommit()
                }
                
            case .rollbackTransaction:
                break
                
            case .beginSavepoint(let name):
                savepointStack.savepointDidBegin(name)
                
            case .releaseSavepoint(let name):
                savepointStack.savepointDidRelease(name)
                if savepointStack.isEmpty {
                    // Notify buffered events
                    let eventsBuffer = savepointStack.eventsBuffer
                    savepointStack.clear()
                    for (event, observations) in eventsBuffer {
                        for observation in observations {
                            event.send(to: observation)
                        }
                    }
                }
                
            case .rollbackSavepoint(let name):
                savepointStack.savepointDidRollback(name)
            }
        }
        
        // Reset transactionState before databaseDidCommit or
        // databaseDidRollback eventually execute other statements.
        let transactionState = self.transactionState
        self.transactionState = .none
        
        switch transactionState {
        case .commit:
            databaseDidCommit()
        case .rollback:
            databaseDidRollback(notifyTransactionObservers: true)
        default:
            break
        }
    }
    
#if SQLITE_ENABLE_PREUPDATE_HOOK
    // Called from sqlite3_preupdate_hook
    private func databaseWillChange(with event: DatabasePreUpdateEvent) {
        if savepointStack.isEmpty {
            // Notify now
            for observation in activeTransactionObservations {
                observation.databaseWillChange(with: event)
            }
        } else {
            // Buffer
            savepointStack.eventsBuffer.append((event: event.copy(), observations: activeTransactionObservations))
        }
    }
#endif
    
    // Called from sqlite3_update_hook
    private func databaseDidChange(with event: DatabaseEvent) {
        if savepointStack.isEmpty {
            // Notify now
            for observation in activeTransactionObservations {
                observation.databaseDidChange(with: event)
            }
        } else {
            // Buffer
            savepointStack.eventsBuffer.append((event: event.copy(), observations: activeTransactionObservations))
        }
    }
    
    // Called from sqlite3_commit_hook
    private func databaseWillCommit() throws {
        // Time to send all buffered events
        
        let eventsBuffer = savepointStack.eventsBuffer
        savepointStack.clear()
        
        for (event, observations) in eventsBuffer {
            for observation in observations {
                event.send(to: observation)
            }
        }
        
        for observation in transactionObservations {
            try observation.databaseWillCommit()
        }
    }
    
    // Called from updateStatementDidExecute
    private func databaseDidCommit() {
        savepointStack.clear()
        
        for observation in transactionObservations {
            observation.databaseDidCommit(database)
        }
        cleanupTransactionObservations()
    }
    
    // Called from updateStatementDidExecute
    private func emptyDeferredTransactionDidCommit() {
        for observation in transactionObservations {
            observation.emptyDeferredTransactionDidCommit(database)
        }
        cleanupTransactionObservations()
    }
    
    // Called from updateStatementDidExecute or updateStatementDidFails
    private func databaseDidRollback(notifyTransactionObservers: Bool) {
        savepointStack.clear()
        
        if notifyTransactionObservers {
            for observation in transactionObservations {
                observation.databaseDidRollback(database)
            }
        }
        cleanupTransactionObservations()
    }
    
    private func installUpdateHook() {
        let brokerPointer = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_update_hook(database.sqliteConnection, { (brokerPointer, updateKind, databaseNameCString, tableNameCString, rowID) in
            let broker = Unmanaged<DatabaseObservationBroker>.fromOpaque(brokerPointer!).takeUnretainedValue()
            broker.databaseDidChange(with: DatabaseEvent(
                kind: DatabaseEvent.Kind(rawValue: updateKind)!,
                rowID: rowID,
                databaseNameCString: databaseNameCString,
                tableNameCString: tableNameCString))
        }, brokerPointer)
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            sqlite3_preupdate_hook(database.sqliteConnection, { (brokerPointer, databaseConnection, updateKind, databaseNameCString, tableNameCString, initialRowID, finalRowID) in
                let broker = Unmanaged<DatabaseObservationBroker>.fromOpaque(brokerPointer!).takeUnretainedValue()
                broker.databaseWillChange(with: DatabasePreUpdateEvent(
                    connection: databaseConnection!,
                    kind: DatabasePreUpdateEvent.Kind(rawValue: updateKind)!,
                    initialRowID: initialRowID,
                    finalRowID: finalRowID,
                    databaseNameCString: databaseNameCString,
                    tableNameCString: tableNameCString))
            }, brokerPointer)
        #endif
    }
    
    private func uninstallUpdateHook() {
        sqlite3_update_hook(database.sqliteConnection, nil, nil)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            sqlite3_preupdate_hook(database.sqliteConnection, nil, nil)
        #endif
    }
    
    /// Remove transaction observers that have stopped observing transaction,
    /// and uninstall SQLite update hooks if there is no remaining observers.
    private func cleanupTransactionObservations() {
        transactionObservations = transactionObservations.filter { $0.isObserving }
        if transactionObservations.isEmpty {
            uninstallUpdateHook()
        }
    }
    
    /// The states that keep track of transaction completions
    enum TransactionState {
        case none
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
final class TransactionObservation {
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
                // Observer most not get any further notification.
                // So we "forget" the observer before its `databaseDidCommit`
                // implementation eventually triggers another database change.
                strongObserver = nil
                observer.databaseDidCommit(db)
            }
        }
    }
    
    func emptyDeferredTransactionDidCommit(_ db: Database) {
        switch extent {
        case .observerLifetime, .databaseLifetime:
            break
        case .nextTransaction:
            // Observer most not get any further notification.
            strongObserver = nil
        }
    }

    func databaseDidRollback(_ db: Database) {
        switch extent {
        case .observerLifetime, .databaseLifetime:
            observer?.databaseDidRollback(db)
        case .nextTransaction:
            if let observer = self.observer {
                // Observer most not get any further notification.
                // So we "forget" the observer before its `databaseDidRollback`
                // implementation eventually triggers another database change.
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
    func send(to observer: TransactionObservation)
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
    func send(to observer: TransactionObservation) {
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
        func send(to observer: TransactionObservation) {
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
    var eventsBuffer: [(event: DatabaseEventProtocol, observations: [TransactionObservation])] = []
    
    /// The savepoint stack, as an array of tuples (savepointName, index in the eventsBuffer array).
    /// Indexes let us drop rollbacked events from the event buffer.
    private var savepoints: [(name: String, index: Int)] = []
    
    /// If true, there is no current save point.
    var isEmpty: Bool { return savepoints.isEmpty }
    
    func clear() {
        eventsBuffer.removeAll()
        savepoints.removeAll()
    }
    
    func savepointDidBegin(_ name: String) {
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
    func savepointDidRollback(_ name: String) {
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
    func savepointDidRelease(_ name: String) {
        let name = name.lowercased()
        while let pair = savepoints.last, pair.name != name {
            savepoints.removeLast()
        }
        if !savepoints.isEmpty {
            savepoints.removeLast()
        }
    }
}
