extension Database {
    
    // MARK: - Database Observation
    
    /// Add a transaction observer, so that it gets notified of
    /// database changes.
    ///
    /// - parameter transactionObserver: A transaction observer.
    /// - parameter extent: The duration of the observation. The default is
    ///   the observer lifetime (observation lasts until observer
    ///   is deallocated).
    public func add(
        transactionObserver: TransactionObserver,
        extent: TransactionObservationExtent = .observerLifetime)
    {
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
    ///     try dbQueue.write { db in
    ///         db.afterNextTransactionCommit { _ in
    ///             print("success")
    ///         }
    ///         ...
    ///     } // prints "success"
    ///
    /// If the transaction is rollbacked, the closure is not executed.
    ///
    /// If the transaction is committed, the closure is executed in a protected
    /// dispatch queue, serialized will all database updates.
    public func afterNextTransactionCommit(_ closure: @escaping (Database) -> Void) {
        class CommitHandler: TransactionObserver {
            let closure: (Database) -> Void
            
            init(_ closure: @escaping (Database) -> Void) {
                self.closure = closure
            }
            
            // Ignore individual changes and transaction rollbacks
            func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { false }
            func databaseDidChange(with event: DatabaseEvent) { }
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

// MARK: - DatabaseObservationBroker

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
///         try db.execute(sql: "BEGIN TRANSACTION")
///
/// Then a statement is executed:
///
///         try db.execute(sql: "INSERT INTO document ...")
///
/// The observation process starts when the statement is *compiled*:
/// sqlite3_set_authorizer tells that the statement performs insertion into the
/// `document` table. Generally speaking, statements may have many effects, by
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
///         try db.execute(sql: "SAVEPOINT foo")
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
///         try db.execute(sql: "INSERT INTO document ...")
///
/// This time, when the statement is *executed* and SQLite tells that a row has
/// been inserted, the broker buffers the change event instead of immediately
/// notifying the activated observers. That is because the savepoint can be
/// rollbacked, and GRDB guarantees observers that they are only notified of
/// changes that have an opportunity to be committed.
///
/// The savepoint is released:
///
///         try db.execute(sql: "RELEASE SAVEPOINT foo")
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
///         try db.execute(sql: "COMMIT")
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
    private unowned var database: Database
    private var savepointStack = SavepointStack()
    private var transactionState: TransactionState = .none
    private var transactionObservations: [TransactionObservation] = []
    private var statementObservations: [StatementObservation] = [] {
        didSet { observesDatabaseChanges = !statementObservations.isEmpty }
    }
    private var observesDatabaseChanges: Bool = false {
        didSet {
            if observesDatabaseChanges == oldValue { return }
            if observesDatabaseChanges {
                installUpdateHook()
            } else {
                uninstallUpdateHook()
            }
        }
    }
    
    init(_ database: Database) {
        self.database = database
    }
    
    // MARK: - Transaction observers
    
    func add(transactionObserver: TransactionObserver, extent: Database.TransactionObservationExtent) {
        transactionObservations.append(TransactionObservation(observer: transactionObserver, extent: extent))
    }
    
    func remove(transactionObserver: TransactionObserver) {
        transactionObservations.removeFirst { $0.isWrapping(transactionObserver) }
    }
    
    func disableUntilNextTransaction(transactionObserver: TransactionObserver) {
        if let observation = transactionObservations.first(where: { $0.isWrapping(transactionObserver) }) {
            observation.isDisabled = true
            statementObservations.removeFirst { $0.0 === observation }
        }
    }
    
    // MARK: - Statement execution
    
    /// Setups observation of changes that are about to be performed by the
    /// statement, and returns the authorizer that should be used during
    /// statement execution.
    func updateStatementWillExecute(_ statement: UpdateStatement) -> StatementAuthorizer? {
        // If any observer observes row deletions, we'll have to disable
        // [truncate optimization](https://www.sqlite.org/lang_delete.html#truncateopt)
        // so that observers are notified.
        var observesRowDeletion = false
        
        if transactionObservations.isEmpty == false {
            // As statement executes, it may trigger database changes that will
            // be notified to transaction observers. As a consequence, observers
            // may disable themselves with stopObservingDatabaseChangesUntilNextTransaction()
            //
            // This method takes no argument, and requires access to the "current
            // broker", which is a per-thread global stored in
            // SchedulingWatchdog.current:
            SchedulingWatchdog.current!.databaseObservationBroker = self
            
            // Fill statementObservations with observations that are interested in
            // the kind of events performed by the statement.
            //
            // Those statementObservations will be notified of individual changes
            // in databaseWillChange() and databaseDidChange().
            let eventKinds = statement.databaseEventKinds
            
            switch eventKinds.count {
            case 0:
                // Statement has no effect on any database table.
                //
                // For example: PRAGMA foreign_keys = ON
                statementObservations = []
            case 1:
                // We'll execute a simple statement without any side effect.
                // Eventual database events will thus all have the same kind. All
                // detabase events can be notified to interested observations.
                //
                // For example, if one observes all deletions in the table T, then
                // all individual deletions of DELETE FROM T are notified:
                let eventKind = eventKinds[0]
                statementObservations = transactionObservations.compactMap { observation in
                    guard observation.observes(eventsOfKind: eventKind) else {
                        // observation is not interested
                        return nil
                    }
                    
                    if case .delete = eventKind {
                        observesRowDeletion = true
                    }
                    
                    // observation will be notified of all individual events
                    return (observation, DatabaseEventPredicate.true)
                }
            default:
                // We'll execute a complex statement with side effects performed by
                // an SQL trigger or a foreign key action. Eventual database events
                // may not all have the same kind: we need to filter them before
                // notifying interested observations.
                //
                // For example, if DELETE FROM T1 generates deletions in T1 and T2
                // by the mean of a foreign key action, then when one only observes
                // deletions in T1, one must not be notified of deletions in T2:
                statementObservations = transactionObservations.compactMap { observation in
                    let observedKinds = eventKinds.filter(observation.observes)
                    if observedKinds.isEmpty {
                        // observation is not interested
                        return nil
                    }
                    
                    for eventKind in observedKinds {
                        if case .delete = eventKind {
                            observesRowDeletion = true
                            break
                        }
                    }
                    
                    // observation will only be notified of individual events that
                    // match one of the observed kinds.
                    return (
                        observation,
                        DatabaseEventPredicate.matching(
                            observedKinds: observedKinds,
                            advertisedKinds: eventKinds))
                }
            }
        }
        
        switch transactionState {
        case .none:
            break
        default:
            // May happen after "PRAGMA journal_mode = WAL" executed with a
            // SelectStatement.
            // TODO: Maybe this state machine should be run for *all* statements,
            // not ony update statements.
            transactionState = .none
        }
        
        if observesRowDeletion {
            return TruncateOptimizationBlocker()
        } else {
            return nil
        }
    }
    
    func updateStatementDidFail(_ statement: UpdateStatement) throws {
        // Undo updateStatementWillExecute
        statementObservations = []
        SchedulingWatchdog.current!.databaseObservationBroker = nil
        
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
    
    func updateStatementDidExecute(_ statement: UpdateStatement) throws {
        // Undo updateStatementWillExecute
        if transactionObservations.isEmpty == false {
            statementObservations = []
            SchedulingWatchdog.current!.databaseObservationBroker = nil
        }
        
        // Has statement any effect on transaction/savepoints?
        if let transactionEffect = statement.transactionEffect {
            switch transactionEffect {
            case .beginTransaction:
                break
                
            case .commitTransaction:                    // 1. A COMMIT statement has been executed
                if case .none = self.transactionState { // 2. sqlite3_commit_hook was not triggered
                    // 1+2 mean that an empty deferred transaction has been completed:
                    //
                    //   BEGIN DEFERRED TRANSACTION; COMMIT
                    //
                    // This special case has a dedicated handling:
                    try databaseDidCommitEmptyDeferredTransaction()
                    return
                }
                
            case .rollbackTransaction:
                break
                
            case .beginSavepoint(let name):
                savepointStack.savepointDidBegin(name)
                
            case .releaseSavepoint(let name):          // 1. A RELEASE SAVEPOINT statement has been executed
                savepointStack.savepointDidRelease(name)
                
                if case .none = self.transactionState, // 2. sqlite3_commit_hook was not triggered
                   !database.isInsideTransaction       // 3. database is no longer inside a transaction
                {
                    // 1+2+3 mean that an empty deferred transaction has been completed:
                    //
                    //   SAVEPOINT foo; RELEASE SAVEPOINT foo
                    //
                    // This special case has a dedicated handling:
                    try databaseDidCommitEmptyDeferredTransaction()
                    return
                }
                
                if savepointStack.isEmpty {
                    notifyBufferedEvents()
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
            for (observation, predicate) in statementObservations where predicate.evaluate(event) {
                observation.databaseWillChange(with: event)
            }
        } else {
            // Buffer
            savepointStack.eventsBuffer.append((event: event.copy(), statementObservations: statementObservations))
        }
    }
    #endif
    
    // Called from sqlite3_update_hook
    private func databaseDidChange(with event: DatabaseEvent) {
        // We're about to call the databaseDidChange(with:) method of
        // transaction observers. In this method, observers may disable
        // themselves with stopObservingDatabaseChangesUntilNextTransaction()
        //
        // This method takes no argument, and requires access to the "current
        // broker", which is a per-thread global stored in
        // SchedulingWatchdog.current:
        assert(SchedulingWatchdog.current?.databaseObservationBroker != nil)
        
        if savepointStack.isEmpty {
            // Notify now
            for (observation, predicate) in statementObservations where predicate.evaluate(event) {
                observation.databaseDidChange(with: event)
            }
        } else {
            // Buffer
            savepointStack.eventsBuffer.append((event: event.copy(), statementObservations: statementObservations))
        }
    }
    
    // MARK: - End of transaction
    
    // Called from sqlite3_commit_hook and databaseDidCommitEmptyDeferredTransaction()
    private func databaseWillCommit() throws {
        notifyBufferedEvents()
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
        databaseDidEndTransaction()
    }
    
    // Called from updateStatementDidExecute
    private func databaseDidCommitEmptyDeferredTransaction() throws {
        // A statement that ends a transaction has been executed. But for
        // SQLite, no transaction at all has started, and sqlite3_commit_hook
        // was not triggered:
        //
        //   try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
        //   try db.execute(sql: "COMMIT") // <- no sqlite3_commit_hook callback invocation
        //
        // Should we tell transaction observers of this transaction, or not?
        // The code says that a transaction was open, but SQLite says the
        // opposite. How do we lift this ambiguity? Should we notify of
        // *transactions expressed in the code*, or *SQLite transactions* only?
        //
        // If we would notify of SQLite transactions only, then we'd notify of
        // all transactions expressed in the code, but empty deferred
        // transaction. This means that we'd make an exception. And exceptions
        // are the recipe for both surprise and confusion.
        //
        // For example, is the code below expected to print "did commit"?
        //
        //   db.afterNextTransactionCommit { _ in print("did commit") }
        //   try db.inTransaction {
        //       performSomeTask(db)
        //       return .commit
        //   }
        //
        // Yes it is. And the only way to make it reliably print "did commit" is
        // to behave consistently, regardless of the implementation of the
        // `performSomeTask` function. Even if the `performSomeTask` is empty,
        // even if we actually execute an empty deferred transaction.
        //
        // For better or for worse, let's simulate a transaction:
        
        do {
            try databaseWillCommit()
            databaseDidCommit()
        } catch {
            databaseDidRollback(notifyTransactionObservers: true)
            throw error
        }
    }
    
    // Called from updateStatementDidExecute or updateStatementDidFails
    private func databaseDidRollback(notifyTransactionObservers: Bool) {
        savepointStack.clear()
        
        if notifyTransactionObservers {
            for observation in transactionObservations {
                observation.databaseDidRollback(database)
            }
        }
        databaseDidEndTransaction()
    }
    
    /// Remove transaction observers that have stopped observing transaction,
    /// and uninstall SQLite update hooks if there is no remaining observers.
    private func databaseDidEndTransaction() {
        assert(!database.isInsideTransaction)
        transactionObservations = transactionObservations.filter(\.isObserving)
        
        // Undo disableUntilNextTransaction(transactionObserver:)
        for observation in transactionObservations {
            observation.isDisabled = false
        }
    }
    
    private func notifyBufferedEvents() {
        // We're about to call the databaseDidChange(with:) method of
        // transaction observers. In this method, observers may disable
        // themselves with stopObservingDatabaseChangesUntilNextTransaction()
        //
        // This method takes no argument, and requires access to the "current
        // broker", which is a per-thread global stored in
        // SchedulingWatchdog.current.
        //
        // Normally, notifyBufferedEvents() is called as part of statement
        // execution, and the current broker has been set in
        // updateStatementWillExecute(). An assertion should be enough:
        //
        //      assert(SchedulingWatchdog.current?.databaseObservationBroker != nil)
        //
        // But we have to deal with a particular case:
        //
        //      let journalMode = String.fetchOne(db, sql: "PRAGMA journal_mode = wal")
        //
        // It runs a SelectStatement, not an UpdateStatement. But this not why
        // this case is particular. What is unexpected is that it triggers
        // the commit hook when the "PRAGMA journal_mode = wal" statement is
        // finalized, long after it has executed:
        //
        // 1. Statement.deinit()
        // 2. sqlite3_finalize()
        // 3. commit hook
        // 4. DatabaseObservationBroker.databaseWillCommit()
        // 5. DatabaseObservationBroker.notifyBufferedEvents()
        //
        // I don't know if this behavior is something that can be relied
        // upon. One would naively expect, for example, that changing the
        // journal mode would trigger the commit hook in sqlite3_step(),
        // not in sqlite3_finalize().
        //
        // Anyway: in this scenario, updateStatementWillExecute() has not been
        // called, and the current broker is nil.
        //
        // Let's not try to outsmart SQLite, and build a complex state machine.
        // Instead, let's just make sure that the current broker is set to self
        // when this method is called.
        
        let watchDog = SchedulingWatchdog.current!
        watchDog.databaseObservationBroker = self
        defer {
            watchDog.databaseObservationBroker = nil
        }
        
        // Now we can safely notify:
        
        let eventsBuffer = savepointStack.eventsBuffer
        savepointStack.clear()
        
        for (event, statementObservations) in eventsBuffer {
            for (observation, predicate) in statementObservations where predicate.evaluate(event) {
                event.send(to: observation)
            }
        }
    }
    
    // MARK: - SQLite hooks
    
    func installCommitAndRollbackHooks() {
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
    
    private func installUpdateHook() {
        let brokerPointer = Unmanaged.passUnretained(self).toOpaque()
        
        sqlite3_update_hook(
            database.sqliteConnection,
            { (brokerPointer, updateKind, databaseNameCString, tableNameCString, rowID) in
                let broker = Unmanaged<DatabaseObservationBroker>.fromOpaque(brokerPointer!).takeUnretainedValue()
                broker.databaseDidChange(
                    with: DatabaseEvent(
                        kind: DatabaseEvent.Kind(rawValue: updateKind)!,
                        rowID: rowID,
                        databaseNameCString: databaseNameCString,
                        tableNameCString: tableNameCString))
            },
            brokerPointer)
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
        sqlite3_preupdate_hook(
            database.sqliteConnection,
            // swiftlint:disable:next line_length
            { (brokerPointer, databaseConnection, updateKind, databaseNameCString, tableNameCString, initialRowID, finalRowID) in
                let broker = Unmanaged<DatabaseObservationBroker>.fromOpaque(brokerPointer!).takeUnretainedValue()
                broker.databaseWillChange(
                    with: DatabasePreUpdateEvent(
                        connection: databaseConnection!,
                        kind: DatabasePreUpdateEvent.Kind(rawValue: updateKind)!,
                        initialRowID: initialRowID,
                        finalRowID: finalRowID,
                        databaseNameCString: databaseNameCString,
                        tableNameCString: tableNameCString))
            },
            brokerPointer)
        #endif
    }
    
    private func uninstallUpdateHook() {
        sqlite3_update_hook(database.sqliteConnection, nil, nil)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
        sqlite3_preupdate_hook(database.sqliteConnection, nil, nil)
        #endif
    }
    
    /// The various states of SQLite transactions
    enum TransactionState {
        case none
        case commit
        case rollback
        case cancelledCommit(Error)
    }
}

// MARK: - TransactionObserver

/// A transaction observer is notified of all changes and transactions committed
/// or rollbacked on a database.
///
/// Adopting types must be a class.
public protocol TransactionObserver: AnyObject {
    
    /// Filters database changes that should be notified the the
    /// databaseDidChange(with:) method.
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool
    
    /// Notifies a database change (insert, update, or delete).
    ///
    /// The change is pending until the current transaction ends. See
    /// databaseWillCommit, databaseDidCommit and databaseDidRollback.
    ///
    /// This method is called in a protected dispatch queue, serialized will all
    /// database updates.
    ///
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy: `event.copy()`
    ///
    /// The observer has an opportunity to stop receiving further change events
    /// from the current transaction by calling the
    /// stopObservingDatabaseChangesUntilNextTransaction() method.
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
    /// This method is called in a protected dispatch queue, serialized will all
    /// database updates.
    ///
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy: `event.copy()`
    ///
    /// - warning: this method must not change the database.
    ///
    /// **Availability Info**
    ///
    /// Requires SQLite 3.13.0 +
    /// Compiled with option SQLITE_ENABLE_PREUPDATE_HOOK
    ///
    /// As of OSX 10.11.5, and iOS 9.3.2, the built-in SQLite library
    /// does not have this enabled, so you'll need to compile your own
    /// version of SQLite:
    /// See https://github.com/groue/GRDB.swift/blob/master/Documentation/CustomSQLiteBuilds.md
    ///
    /// The databaseDidChangeWithEvent callback is always available,
    /// and may provide most/all of what you need.
    func databaseWillChange(with event: DatabasePreUpdateEvent)
    #endif
}

extension TransactionObserver {
    /// Default implementation does nothing
    public func databaseWillCommit() throws {
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    /// Default implementation does nothing
    public func databaseWillChange(with event: DatabasePreUpdateEvent) {
    }
    #endif
    
    /// After this method has been called, the `databaseDidChange(with:)`
    /// method won't be called until the next transaction.
    ///
    /// For example:
    ///
    ///     class PlayerObserver: TransactionObserver {
    ///         var playerTableWasModified = false
    ///
    ///         func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
    ///             return eventKind.tableName == "player"
    ///         }
    ///
    ///         func databaseDidChange(with event: DatabaseEvent) {
    ///             playerTableWasModified = true
    ///
    ///             // It is pointless to keep on tracking further changes:
    ///             stopObservingDatabaseChangesUntilNextTransaction()
    ///         }
    ///     }
    ///
    /// - precondition: This method must be called from `databaseDidChange(with:)`.
    public func stopObservingDatabaseChangesUntilNextTransaction() {
        guard let broker = SchedulingWatchdog.current?.databaseObservationBroker else {
            fatalError("""
                stopObservingDatabaseChangesUntilNextTransaction must be called \
                from the databaseDidChange method
                """)
        }
        broker.disableUntilNextTransaction(transactionObserver: self)
    }
}

// MARK: - TransactionObservation

/// This class manages the observation extent of a transaction observer
final class TransactionObservation {
    let extent: Database.TransactionObservationExtent
    
    // A disabled observation is not interested in individual database changes.
    // It is still interested in transactions commits & rollbacks.
    var isDisabled: Bool = false
    
    private weak var weakObserver: TransactionObserver?
    private var strongObserver: TransactionObserver?
    private var observer: TransactionObserver? { strongObserver ?? weakObserver }
    
    fileprivate var isObserving: Bool {
        observer != nil
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
        self.observer === observer
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        if isDisabled { return false }
        return observer?.observes(eventsOfKind: eventKind) ?? false
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    func databaseWillChange(with event: DatabasePreUpdateEvent) {
        if isDisabled { return }
        observer?.databaseWillChange(with: event)
    }
    #endif
    
    func databaseDidChange(with event: DatabaseEvent) {
        if isDisabled { return }
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
                // Observer must not get any further notification.
                // So we "forget" the observer before its `databaseDidCommit`
                // implementation eventually triggers another database change.
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
                // Observer must not get any further notification.
                // So we "forget" the observer before its `databaseDidRollback`
                // implementation eventually triggers another database change.
                strongObserver = nil
                observer.databaseDidRollback(db)
            }
        }
    }
}

typealias StatementObservation = (TransactionObservation, DatabaseEventPredicate)

// MARK: - Database events

/// A kind of database event. See the `TransactionObserver` protocol for
/// more information.
public enum DatabaseEventKind {
    /// The insertion of a row in a database table
    case insert(tableName: String)
    
    /// The deletion of a row in a database table
    case delete(tableName: String)
    
    /// The update of a set of columns in a database table
    case update(tableName: String, columnNames: Set<String>)
    
    var modifiedRegion: DatabaseRegion {
        switch self {
        case let .delete(tableName):
            return DatabaseRegion(table: tableName)
        case let .insert(tableName):
            return DatabaseRegion(table: tableName)
        case let .update(tableName, updatedColumnNames):
            return DatabaseRegion(table: tableName, columns: updatedColumnNames)
        }
    }
}

extension DatabaseEventKind {
    /// The impacted database table
    public var tableName: String {
        switch self {
        case let .insert(tableName: tableName): return tableName
        case let .delete(tableName: tableName): return tableName
        case let .update(tableName: tableName, columnNames: _): return tableName
        }
    }
}

protocol DatabaseEventProtocol {
    func send(to observer: TransactionObservation)
    func matchesKind(_ databaseEventKind: DatabaseEventKind) -> Bool
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
    
    private let impl: DatabaseEventImpl
    
    /// The event kind
    public let kind: Kind
    
    /// The database name
    public var databaseName: String { impl.databaseName }
    
    /// The table name
    public var tableName: String { impl.tableName }
    
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
        impl.copy(self)
    }
    
    fileprivate init(kind: Kind, rowID: Int64, impl: DatabaseEventImpl) {
        self.kind = kind
        self.rowID = rowID
        self.impl = impl
    }
    
    init(kind: Kind, rowID: Int64, databaseNameCString: UnsafePointer<Int8>?, tableNameCString: UnsafePointer<Int8>?) {
        self.init(
            kind: kind,
            rowID: rowID,
            impl: MetalDatabaseEventImpl(
                databaseNameCString: databaseNameCString,
                tableNameCString: tableNameCString))
    }
}

extension DatabaseEvent: DatabaseEventProtocol {
    func send(to observer: TransactionObservation) {
        observer.databaseDidChange(with: self)
    }
    
    func matchesKind(_ databaseEventKind: DatabaseEventKind) -> Bool {
        switch (kind, databaseEventKind) {
        case (.insert, .insert(let tableName)): return self.tableName == tableName
        case (.delete, .delete(let tableName)): return self.tableName == tableName
        case (.update, .update(let tableName, _)): return self.tableName == tableName
        default:
            return false
        }
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
private struct MetalDatabaseEventImpl: DatabaseEventImpl {
    let databaseNameCString: UnsafePointer<Int8>?
    let tableNameCString: UnsafePointer<Int8>?
    
    var databaseName: String { String(cString: databaseNameCString!) }
    var tableName: String { String(cString: tableNameCString!) }
    
    func copy(_ event: DatabaseEvent) -> DatabaseEvent {
        DatabaseEvent(
            kind: event.kind,
            rowID: event.rowID,
            impl: CopiedDatabaseEventImpl(
                databaseName: databaseName,
                tableName: tableName))
    }
}

/// Impl for DatabaseEvent that contains copies of event strings.
private struct CopiedDatabaseEventImpl: DatabaseEventImpl {
    let databaseName: String
    let tableName: String
    func copy(_ event: DatabaseEvent) -> DatabaseEvent { event }
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
    public var databaseName: String { impl.databaseName }
    
    /// The table name
    public var tableName: String { impl.tableName }
    
    /// The number of columns in the row that is being inserted, updated, or deleted.
    public var count: Int { Int(impl.columnCount) }
    
    /// The triggering depth of the row update
    /// Returns:
    ///     0  if the preupdate callback was invoked as a result of a direct insert,
    //         update, or delete operation;
    ///     1  for inserts, updates, or deletes invoked by top-level triggers;
    ///     2  for changes resulting from triggers called by top-level triggers;
    ///     ... and so forth
    public var depth: CInt { impl.depth }
    
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
        guard kind == .update || kind == .delete else { return nil }
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
        guard kind == .update || kind == .delete else { return nil }
        return impl.initialDatabaseValue(atIndex: index)
    }
    
    /// The final database values in the row.
    ///
    /// Values appear in the same order as the columns in the table.
    ///
    /// The result is nil if the event is a .Delete event.
    public var finalDatabaseValues: [DatabaseValue]? {
        guard kind == .update || kind == .insert else { return nil }
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
        guard kind == .update || kind == .insert else { return nil }
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
        impl.copy(self)
    }
    
    fileprivate init(kind: Kind, initialRowID: Int64?, finalRowID: Int64?, impl: DatabasePreUpdateEventImpl) {
        self.kind = kind
        self.initialRowID = (kind == .update || kind == .delete ) ? initialRowID : nil
        self.finalRowID = (kind == .update || kind == .insert ) ? finalRowID : nil
        self.impl = impl
    }
    
    init(
        connection: SQLiteConnection,
        kind: Kind,
        initialRowID: Int64,
        finalRowID: Int64,
        databaseNameCString: UnsafePointer<Int8>?,
        tableNameCString: UnsafePointer<Int8>?)
    {
        self.init(
            kind: kind,
            initialRowID: (kind == .update || kind == .delete ) ? finalRowID : nil,
            finalRowID: (kind == .update || kind == .insert ) ? finalRowID : nil,
            impl: MetalDatabasePreUpdateEventImpl(
                connection: connection,
                kind: kind,
                databaseNameCString: databaseNameCString,
                tableNameCString: tableNameCString))
    }
    
    private let impl: DatabasePreUpdateEventImpl
}

extension DatabasePreUpdateEvent: DatabaseEventProtocol {
    func send(to observer: TransactionObservation) {
        observer.databaseWillChange(with: self)
    }
    
    func matchesKind(_ databaseEventKind: DatabaseEventKind) -> Bool {
        switch (kind, databaseEventKind) {
        case (.insert, .insert(let tableName)): return self.tableName == tableName
        case (.delete, .delete(let tableName)): return self.tableName == tableName
        case (.update, .update(let tableName, _)): return self.tableName == tableName
        default:
            return false
        }
    }
}

/// Protocol for internal implementation of DatabaseEvent
private protocol DatabasePreUpdateEventImpl {
    var databaseName: String { get }
    var tableName: String { get }
    
    var columnCount: CInt { get }
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
private struct MetalDatabasePreUpdateEventImpl: DatabasePreUpdateEventImpl {
    let connection: SQLiteConnection
    let kind: DatabasePreUpdateEvent.Kind
    
    let databaseNameCString: UnsafePointer<Int8>?
    let tableNameCString: UnsafePointer<Int8>?
    
    var databaseName: String { String(cString: databaseNameCString!) }
    var tableName: String { String(cString: tableNameCString!) }
    
    var columnCount: CInt { sqlite3_preupdate_count(connection) }
    var depth: CInt { sqlite3_preupdate_depth(connection) }
    var initialDatabaseValues: [DatabaseValue]? {
        guard kind == .update || kind == .delete else { return nil }
        return preupdate_getValues_old(connection)
    }
    
    var finalDatabaseValues: [DatabaseValue]? {
        guard kind == .update || kind == .insert else { return nil }
        return preupdate_getValues_new(connection)
    }
    
    func initialDatabaseValue(atIndex index: Int) -> DatabaseValue? {
        precondition(index >= 0 && index < Int(columnCount), "row index out of range")
        return getValue(
            connection,
            column: CInt(index),
            sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                sqlite3_preupdate_old(connection, column, &value)
            })
    }
    
    func finalDatabaseValue(atIndex index: Int) -> DatabaseValue? {
        precondition(index >= 0 && index < Int(columnCount), "row index out of range")
        return getValue(
            connection,
            column: CInt(index),
            sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                sqlite3_preupdate_new(connection, column, &value)
            })
    }
    
    func copy(_ event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent {
        DatabasePreUpdateEvent(
            kind: event.kind,
            initialRowID: event.initialRowID,
            finalRowID: event.finalRowID,
            impl: CopiedDatabasePreUpdateEventImpl(
                databaseName: databaseName,
                tableName: tableName,
                columnCount: columnCount,
                depth: depth,
                initialDatabaseValues: initialDatabaseValues,
                finalDatabaseValues: finalDatabaseValues))
    }
    
    private func preupdate_getValues(
        _ connection: SQLiteConnection,
        sqlite_func: (_ connection: SQLiteConnection, _ column: CInt, _ value: inout SQLiteValue? ) -> CInt)
    -> [DatabaseValue]?
    {
        let columnCount = self.columnCount
        guard columnCount > 0 else { return nil }
        
        var columnValues = [DatabaseValue]()
        
        for i in 0..<columnCount {
            let value = getValue(connection, column: i, sqlite_func: sqlite_func)!
            columnValues.append(value)
        }
        
        return columnValues
    }
    
    private func getValue(
        _ connection: SQLiteConnection,
        column: CInt,
        sqlite_func: (_ connection: SQLiteConnection, _ column: CInt, _ value: inout SQLiteValue? ) -> CInt)
    -> DatabaseValue?
    {
        var value: SQLiteValue? = nil
        guard sqlite_func(connection, column, &value) == SQLITE_OK else { return nil }
        if let value = value {
            return DatabaseValue(sqliteValue: value)
        }
        return nil
    }
    
    private func preupdate_getValues_old(_ connection: SQLiteConnection) -> [DatabaseValue]? {
        preupdate_getValues(
            connection,
            sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                sqlite3_preupdate_old(connection, column, &value)
            })
    }
    
    private func preupdate_getValues_new(_ connection: SQLiteConnection) -> [DatabaseValue]? {
        preupdate_getValues(
            connection,
            sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) -> CInt in
                sqlite3_preupdate_new(connection, column, &value)
            })
    }
}

/// Impl for DatabasePreUpdateEvent that contains copies of all event data.
private struct CopiedDatabasePreUpdateEventImpl: DatabasePreUpdateEventImpl {
    let databaseName: String
    let tableName: String
    let columnCount: CInt
    let depth: CInt
    let initialDatabaseValues: [DatabaseValue]?
    let finalDatabaseValues: [DatabaseValue]?
    
    func initialDatabaseValue(atIndex index: Int) -> DatabaseValue? { initialDatabaseValues?[index] }
    func finalDatabaseValue(atIndex index: Int) -> DatabaseValue? { finalDatabaseValues?[index] }
    
    func copy(_ event: DatabasePreUpdateEvent) -> DatabasePreUpdateEvent { event }
}

#endif

// A predicate that filters database events
enum DatabaseEventPredicate {
    // Yes filter
    case `true`
    // Only events that match observedKinds
    case matching(observedKinds: [DatabaseEventKind], advertisedKinds: [DatabaseEventKind])
    
    func evaluate(_ event: DatabaseEventProtocol) -> Bool {
        switch self {
        case .true:
            return true
        case let .matching(observedKinds: observedKinds, advertisedKinds: advertisedKinds):
            if observedKinds.contains(where: { event.matchesKind($0) }) {
                return true
            }
            if !advertisedKinds.contains(where: { event.matchesKind($0) }) {
                // FTS4 (and maybe other virtual tables) perform unadvertised
                // changes. For example, an "INSERT INTO document ..." statement
                // advertises an insertion in the `document` table, but the
                // actual change events happen in the `document_content` shadow
                // table. When such a non-advertised event happens, assume that
                // the event has to be notified.
                // See https://github.com/groue/GRDB.swift/issues/620
                return true
            }
            return false
        }
    }
}

// MARK: - SavepointStack

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
    /// The buffered events (see DatabaseObservationBroker.databaseDidChange(with:))
    var eventsBuffer: [(event: DatabaseEventProtocol, statementObservations: [StatementObservation])] = []
    
    /// The savepoint stack, as an array of tuples (savepointName, index in the eventsBuffer array).
    /// Indexes let us drop rollbacked events from the event buffer.
    private var savepoints: [(name: String, index: Int)] = []
    
    /// If true, there is no current save point.
    var isEmpty: Bool { savepoints.isEmpty }
    
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
