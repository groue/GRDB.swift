extension Database {
    
    // MARK: - Database Observation
    
    /// Adds a transaction observer, so that it gets notified of
    /// database changes and transactions.
    ///
    /// This method has no effect on read-only database connections.
    ///
    /// - parameter transactionObserver: A transaction observer.
    /// - parameter extent: The duration of the observation. The default is
    ///   the observer lifetime (observation lasts until observer
    ///   is deallocated).
    public func add(
        transactionObserver: some TransactionObserver,
        extent: TransactionObservationExtent = .observerLifetime)
    {
        SchedulingWatchdog.preconditionValidQueue(self)
        guard let observationBroker else { return }
        
        // Drop cached statements that delete, because the addition of an
        // observer may change the need for truncate optimization prevention.
        publicStatementCache.removeAll { $0.isDeleteStatement }
        internalStatementCache.removeAll { $0.isDeleteStatement }
        
        observationBroker.add(transactionObserver: transactionObserver, extent: extent)
    }
    
    /// Removes a transaction observer.
    public func remove(transactionObserver: some TransactionObserver) {
        SchedulingWatchdog.preconditionValidQueue(self)
        guard let observationBroker else { return }
        
        // Drop cached statements that delete, because the removal of an
        // observer may change the need for truncate optimization prevention.
        publicStatementCache.removeAll { $0.isDeleteStatement }
        internalStatementCache.removeAll { $0.isDeleteStatement }
        
        observationBroker.remove(transactionObserver: transactionObserver)
    }
    
    /// Registers closures to be executed after the next or current
    /// transaction completes.
    ///
    /// This method helps synchronizing the database with other resources,
    /// such as files, or system services.
    ///
    /// In the example below, a `CLLocationManager` starts monitoring a
    /// `CLRegion` if and only if it has successfully been stored in
    /// the database:
    ///
    /// ```swift
    /// /// Inserts a region in the database, and start monitoring upon
    /// /// successful insertion.
    /// func startMonitoring(_ db: Database, region: CLRegion) throws {
    ///     // Make sure database is inside a transaction
    ///     try db.inSavepoint {
    ///
    ///         // Save the region in the database
    ///         try insert(...)
    ///
    ///         // Start monitoring if and only if the insertion is
    ///         // eventually committed to disk
    ///         db.afterNextTransaction { _ in
    ///             // locationManager prefers the main queue:
    ///             DispatchQueue.main.async {
    ///                 locationManager.startMonitoring(for: region)
    ///             }
    ///         }
    ///
    ///         return .commit
    ///     }
    /// }
    /// ```
    ///
    /// The method above won't trigger the location manager if the transaction
    /// is eventually rollbacked (explicitly, or because of an error).
    ///
    /// The `onCommit` and `onRollback` closures are executed in the writer
    /// dispatch queue, serialized will all database updates.
    ///
    /// - precondition: Database connection is not read-only.
    /// - parameter onCommit: A closure executed on transaction commit.
    /// - parameter onRollback: A closure executed on transaction rollback.
    public func afterNextTransaction(
        onCommit: @escaping (Database) -> Void,
        onRollback: @escaping (Database) -> Void = { _ in })
    {
        class TransactionHandler: TransactionObserver {
            let onCommit: (Database) -> Void
            let onRollback: (Database) -> Void

            init(onCommit: @escaping (Database) -> Void, onRollback: @escaping (Database) -> Void) {
                self.onCommit = onCommit
                self.onRollback = onRollback
            }
            
            // Ignore changes
            func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { false }
            func databaseDidChange(with event: DatabaseEvent) { }
            
            func databaseDidCommit(_ db: Database) {
                onCommit(db)
            }
            
            func databaseDidRollback(_ db: Database) {
                onRollback(db)
            }
        }
        
        // We don't notify read-only transactions to transaction observers
        GRDBPrecondition(!isReadOnly, "Read-only transactions are not notified")
        
        add(
            transactionObserver: TransactionHandler(onCommit: onCommit, onRollback: onRollback),
            extent: .nextTransaction)
    }
    
    /// The extent of the observation performed by a ``TransactionObserver``.
    public enum TransactionObservationExtent {
        /// Observation lasts until observer is deallocated.
        case observerLifetime
        /// Observation lasts until the next transaction.
        case nextTransaction
        /// Observation lasts until the database is closed.
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
/// During the statement *execution*, SQLite tells the broker that the
/// transaction is about to be committed through sqlite3_commit_hook. The broker
/// invokes observer.databaseWillCommit(). If the observer throws an error, the
/// broker asks SQLite to rollback the transaction. Otherwise, the broker lets
/// the transaction complete.
///
/// After the statement *has been executed*, the broker calls
/// observer.databaseDidCommit().
class DatabaseObservationBroker {
    private unowned let database: Database
    
    /// The savepoint stack allows us to hold database event notifications until
    /// all savepoints are released. The goal is to only tell transaction
    /// observers about database changes that have a chance to be committed
    /// on disk.
    private let savepointStack = SavepointStack()
    
    /// Tracks the transaction completion, as reported by the
    /// `sqlite3_commit_hook` and `sqlite3_rollback_hook` callbacks.
    private var transactionCompletion = TransactionCompletion.none
    
    /// The registered transaction observers.
    private var transactionObservations: [TransactionObservation] = []
    
    /// The observers for an individual statement execution.
    private var statementObservations: [StatementObservation] = [] {
        didSet {
            let isEmpty = statementObservations.isEmpty
            if isEmpty != oldValue.isEmpty {
                if isEmpty {
                    // Avoid processing database changes if nobody is interested
                    uninstallUpdateHook()
                } else {
                    installUpdateHook()
                }
            }
        }
    }
    
    init(_ database: Database) {
        self.database = database
    }
    
    // MARK: - Transaction observers
    
    func add(transactionObserver: some TransactionObserver, extent: Database.TransactionObservationExtent) {
        transactionObservations.append(TransactionObservation(observer: transactionObserver, extent: extent))
    }
    
    func remove(transactionObserver: some TransactionObserver) {
        transactionObservations.removeFirst { $0.isWrapping(transactionObserver) }
    }
    
    /// Called from ``TransactionObserver/stopObservingDatabaseChangesUntilNextTransaction()``.
    func disableUntilNextTransaction(transactionObserver: some TransactionObserver) {
        if let observation = transactionObservations.first(where: { $0.isWrapping(transactionObserver) }) {
            observation.isEnabled = false
            statementObservations.removeFirst { $0.transactionObservation === observation }
        }
    }
    
    // MARK: - Statement execution
    
    /// Returns true if there exists some transaction observer interested in
    /// the deletions in the given table.
    func observesDeletions(on table: String) -> Bool {
        transactionObservations.contains { observation in
            observation.observes(eventsOfKind: .delete(tableName: table))
        }
    }
    
    /// Prepares observation of changes that are about to be performed by the statement.
    func statementWillExecute(_ statement: Statement) {
        if !database.isReadOnly && !transactionObservations.isEmpty {
            // As statement executes, it may trigger database changes that will
            // be notified to transaction observers. As a consequence, observers
            // may disable themselves with stopObservingDatabaseChangesUntilNextTransaction()
            //
            // This method takes no argument, and requires access to the "current
            // broker", which is a per-thread global stored in
            // SchedulingWatchdog.current:
            SchedulingWatchdog.current!.databaseObservationBroker = self
            
            // Fill statementObservations with observations that are interested
            // in the kind of database events performed by the statement, as
            // reported by `sqlite3_set_authorizer`.
            //
            // Those statementObservations will be notified of individual changes
            // in databaseWillChange() and databaseDidChange().
            let authorizerEventKinds = statement.authorizerEventKinds
            
            switch authorizerEventKinds.count {
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
                let eventKind = authorizerEventKinds[0]
                statementObservations = transactionObservations.compactMap { observation in
                    guard observation.observes(eventsOfKind: eventKind) else {
                        // observation is not interested
                        return nil
                    }
                    
                    // Observation will be notified of all individual events
                    return StatementObservation(
                        transactionObservation: observation,
                        trackingEvents: .all)
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
                    let observedEventKinds = authorizerEventKinds.filter(observation.observes)
                    if observedEventKinds.isEmpty {
                        // observation is not interested
                        return nil
                    }
                    
                    // Observation will only be notified of individual events
                    // it is interested into.
                    return StatementObservation(
                        transactionObservation: observation,
                        trackingEvents: .matching(
                            observedEventKinds: observedEventKinds,
                            authorizerEventKinds: authorizerEventKinds))
                }
            }
        }
        
        transactionCompletion = .none
    }
    
    /// May throw the user-provided cancelled commit error, if a transaction
    /// observer has cancelled a transaction.
    func statementDidFail(_ statement: Statement) throws {
        // Undo statementWillExecute
        statementObservations = []
        SchedulingWatchdog.current!.databaseObservationBroker = nil
        
        // Reset transactionCompletion before databaseDidRollback eventually
        // executes other statements.
        let transactionCompletion = self.transactionCompletion
        self.transactionCompletion = .none
        
        switch transactionCompletion {
        case .rollback:
            // Don't notify observers because we're in a failed implicit
            // transaction here (like an INSERT which fails with
            // SQLITE_CONSTRAINT error)
            databaseDidRollback(notifyTransactionObservers: false)
        case .cancelledCommit(let error):
            databaseDidRollback(notifyTransactionObservers: !database.isReadOnly)
            throw error
        default:
            break
        }
    }
    
    /// May throw the user-provided cancelled commit error, if the statement
    /// commits an empty transaction, and a transaction observer cancels this
    /// empty transaction.
    func statementDidExecute(_ statement: Statement) throws {
        // Undo statementWillExecute
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
                if case .none = transactionCompletion { // 2. sqlite3_commit_hook was not called
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
                
                if case .none = transactionCompletion, // 2. sqlite3_commit_hook was not called
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
        
        // Reset transactionCompletion before databaseDidCommit or
        // databaseDidRollback eventually execute other statements.
        let transactionCompletion = self.transactionCompletion
        self.transactionCompletion = .none
        
        switch transactionCompletion {
        case .commit:
            databaseDidCommit()
        case .rollback:
            databaseDidRollback(notifyTransactionObservers: !database.isReadOnly)
        default:
            break
        }
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    // Called from sqlite3_preupdate_hook
    private func databaseWillChange(with event: DatabasePreUpdateEvent) {
        assert(!database.isReadOnly, "Read-only transactions are not notified")
        
        if savepointStack.isEmpty {
            // Notify now
            for statementObservation in statementObservations where statementObservation.tracksEvent(event) {
                statementObservation.transactionObservation.databaseWillChange(with: event)
            }
        } else {
            // Buffer
            savepointStack.eventsBuffer.append((event: event.copy(), statementObservations: statementObservations))
        }
    }
    #endif
    
    // Called from sqlite3_update_hook
    private func databaseDidChange(with event: DatabaseEvent) {
        assert(!database.isReadOnly, "Read-only transactions are not notified")
        
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
            for statementObservation in statementObservations where statementObservation.tracksEvent(event) {
                statementObservation.transactionObservation.databaseDidChange(with: event)
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
        if !database.isReadOnly {
            for observation in transactionObservations {
                try observation.databaseWillCommit()
            }
        }
    }
    
    // Called from statementDidExecute
    private func databaseDidCommit() {
        savepointStack.clear()
        
        if !database.isReadOnly {
            for observation in transactionObservations {
                observation.databaseDidCommit(database)
            }
        }
        
        databaseDidEndTransaction()
    }
    
    // Called from statementDidExecute
    /// May throw a cancelled commit error, if a transaction observer cancels
    /// the empty transaction.
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
        //   db.afterNextTransaction { _ in print("did commit") }
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
            databaseDidRollback(notifyTransactionObservers: !database.isReadOnly)
            throw error
        }
    }
    
    // Called from statementDidExecute or statementDidFail
    private func databaseDidRollback(notifyTransactionObservers: Bool) {
        savepointStack.clear()
        
        if notifyTransactionObservers {
            assert(!database.isReadOnly, "Read-only transactions are not notified")
            for observation in transactionObservations {
                observation.databaseDidRollback(database)
            }
        }
        databaseDidEndTransaction()
    }
    
    // Called from both databaseDidCommit() and databaseDidRollback()
    private func databaseDidEndTransaction() {
        assert(!database.isInsideTransaction)
        
        // Remove transaction observations that are no longer observing, because
        // a transaction observer registered with the `.observerLifetime` extent
        // was deallocated, or because a transaction observer was registered
        // with the `.nextTransaction` extent.
        transactionObservations = transactionObservations.filter(\.isObserving)
        
        // Undo disableUntilNextTransaction(transactionObserver:)
        for observation in transactionObservations {
            observation.isEnabled = true
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
        // statementWillExecute(). An assertion should be enough:
        //
        //      assert(SchedulingWatchdog.current?.databaseObservationBroker != nil)
        //
        // But we have to deal with a particular case:
        //
        //      let journalMode = String.fetchOne(db, sql: "PRAGMA journal_mode = wal")
        //
        // It triggers the commit hook when the "PRAGMA journal_mode = wal"
        // statement is finalized, long after it has executed:
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
        // Anyway: in this scenario, statementWillExecute() has not been
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
            assert(statementObservations.isEmpty || !database.isReadOnly, "Read-only transactions are not notified")
            for statementObservation in statementObservations where statementObservation.tracksEvent(event) {
                event.send(to: statementObservation.transactionObservation)
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
                broker.transactionCompletion = .commit
                // Next step: statementDidExecute(_:)
                return 0
            } catch {
                broker.transactionCompletion = .cancelledCommit(error)
                // Next step: sqlite3_rollback_hook callback
                return 1
            }
        }, brokerPointer)
        
        sqlite3_rollback_hook(database.sqliteConnection, { brokerPointer in
            let broker = Unmanaged<DatabaseObservationBroker>.fromOpaque(brokerPointer!).takeUnretainedValue()
            switch broker.transactionCompletion {
            case .cancelledCommit:
                // Next step: statementDidFail(_:)
                break
            default:
                broker.transactionCompletion = .rollback
                // Next step: statementDidExecute(_:)
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
    
    /// The various SQLite transactions completions, as reported by the
    /// `sqlite3_commit_hook` and `sqlite3_rollback_hook` callbacks.
    fileprivate enum TransactionCompletion {
        /// Transaction state is unchanged.
        case none
        
        /// Transaction turns committed.
        case commit
        
        /// Transaction turns rollbacked.
        case rollback
        
        /// Transaction turns rollbacked because a transaction observer has
        /// cancelled a commit by throwing an error.
        case cancelledCommit(Error)
    }
}

// MARK: - TransactionObserver

public protocol TransactionObserver: AnyObject {
    
    /// Returns whether specific kinds of database changes should be notified
    /// to the observer.
    ///
    /// When this method returns false, database events of this kind are not
    /// notified to the ``databaseDidChange(with:)`` method.
    ///
    /// For example:
    ///
    /// ```swift
    /// // An observer that is only interested in the "player" table
    /// class PlayerObserver: TransactionObserver {
    ///     func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
    ///         return eventKind.tableName == "player"
    ///     }
    /// }
    /// ```
    ///
    /// When this method returns true for deletion events, the observer
    /// prevents the
    /// [truncate optimization](https://www.sqlite.org/lang_delete.html#the_truncate_optimization)
    /// from being applied on the observed tables.
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool
    
    /// Called when the database is changed by an insert, update, or
    /// delete event.
    ///
    /// The change is pending until the current transaction ends. See
    /// ``databaseWillCommit()-7mksu``, ``databaseDidCommit(_:)`` and
    /// ``databaseDidRollback(_:)``.
    ///
    /// The observer has an opportunity to stop receiving further change events
    /// from the current transaction by calling the
    /// ``stopObservingDatabaseChangesUntilNextTransaction()`` method.
    ///
    /// - note: The event is only valid for the duration of this method call.
    ///   If you need to keep it longer, store a copy: `event.copy()`.
    ///
    /// - precondition: This method must not access the database.
    func databaseDidChange(with event: DatabaseEvent)
    
    /// Called when a transaction is about to be committed.
    ///
    /// The transaction observer has an opportunity to rollback pending changes
    /// by throwing an error from this method.
    ///
    /// - precondition: This method must not access the database.
    /// - throws: The eventual error that rollbacks pending changes.
    func databaseWillCommit() throws
    
    /// Called when a transaction has been committed on disk.
    func databaseDidCommit(_ db: Database)
    
    /// Called when a transaction has been rollbacked.
    func databaseDidRollback(_ db: Database)
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    /// Called when the database is changed by an insert, update, or
    /// delete event.
    ///
    /// Notifies before a database change (insert, update, or delete)
    /// with change information (initial / final values for the row's
    /// columns). (Called *before* ``databaseDidChange(with:)``.)
    ///
    /// The change is pending until the end of the current transaction,
    /// and you always get a second chance to get basic event information in
    /// the ``databaseDidChange(with:)`` callback.
    ///
    /// This callback is mostly useful for calculating detailed change
    /// information for a row, and provides the initial / final values.
    ///
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy: `event.copy()`
    ///
    /// - warning: this method must not access the database.
    ///
    /// **Availability Info**
    ///
    /// Requires SQLite compiled with option SQLITE_ENABLE_PREUPDATE_HOOK.
    ///
    /// As of macOS 10.11.5, and iOS 9.3.2, the built-in SQLite library
    /// does not have this enabled, so you'll need to compile your own
    /// version of SQLite:
    /// See <https://github.com/groue/GRDB.swift/blob/master/Documentation/CustomSQLiteBuilds.md>
    func databaseWillChange(with event: DatabasePreUpdateEvent)
    #endif
}

extension TransactionObserver {
    /// The default implementation does nothing.
    public func databaseWillCommit() throws { }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    /// The default implementation does nothing.
    public func databaseWillChange(with event: DatabasePreUpdateEvent) { }
    #endif
    
    /// Prevents the observer from receiving further change notifications until
    /// the next transaction.
    ///
    /// After this method has been called, the ``databaseDidChange(with:)``
    /// method won't be called until the next transaction.
    ///
    /// For example:
    ///
    /// ```swift
    /// // An observer that is only interested in the "player" table
    /// class PlayerObserver: TransactionObserver {
    ///     var playerTableWasModified = false
    ///
    ///     func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
    ///         return eventKind.tableName == "player"
    ///     }
    ///
    ///     func databaseDidChange(with event: DatabaseEvent) {
    ///         playerTableWasModified = true
    ///
    ///         // It is pointless to keep on tracking further changes:
    ///         stopObservingDatabaseChangesUntilNextTransaction()
    ///     }
    /// }
    /// ```
    ///
    /// - precondition: This method must be called from
    ///   ``databaseDidChange(with:)``.
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
    
    /// A disabled observation is not interested in individual database changes.
    /// It is still interested in transactions commits & rollbacks.
    var isEnabled = true
    
    private weak var weakObserver: (any TransactionObserver)?
    private var strongObserver: (any TransactionObserver)?
    private var observer: (any TransactionObserver)? { strongObserver ?? weakObserver }
    
    fileprivate var isObserving: Bool {
        observer != nil
    }
    
    init(observer: some TransactionObserver, extent: Database.TransactionObservationExtent) {
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
    
    func isWrapping(_ observer: some TransactionObserver) -> Bool {
        self.observer === observer
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        observer?.observes(eventsOfKind: eventKind) ?? false
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    func databaseWillChange(with event: DatabasePreUpdateEvent) {
        guard isEnabled else { return }
        observer?.databaseWillChange(with: event)
    }
    #endif
    
    func databaseDidChange(with event: DatabaseEvent) {
        guard isEnabled else { return }
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
                assert(weakObserver == nil, "expected observer to be stored in strongObserver")
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
                assert(weakObserver == nil, "expected observer to be stored in strongObserver")
                strongObserver = nil
                observer.databaseDidRollback(db)
            }
        }
    }
}

/// The observation of one particular statement, by a particular
/// transaction observer.
struct StatementObservation {
    var transactionObservation: TransactionObservation
    
    /// A predicate that filters database events that should be notified.
    ///
    /// Call this predicate as a method:
    ///
    /// ```
    /// if observation.tracksEvent(event) { ... }
    /// ```
    var tracksEvent: DatabaseEventPredicate
    
    init(transactionObservation: TransactionObservation, trackingEvents predicate: DatabaseEventPredicate) {
        self.transactionObservation = transactionObservation
        self.tracksEvent = predicate
    }
}

// MARK: - Database events

/// A kind of database event.
///
/// See the ``TransactionObserver/observes(eventsOfKind:)`` method in the
/// ``TransactionObserver`` protocol for more information.
@frozen
public enum DatabaseEventKind {
    /// The insertion of a row in a database table.
    case insert(tableName: String)
    
    /// The deletion of a row in a database table.
    case delete(tableName: String)
    
    /// The update of a set of columns in a database table.
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
    
    /// Returns whether this is a delete event.
    var isDelete: Bool {
        if case .delete = self {
            return true
        } else {
            return false
        }
    }
}

extension DatabaseEventKind {
    /// The name of the impacted database table.
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

/// A database event.
///
/// See the ``TransactionObserver/databaseDidChange(with:)`` method in the
/// ``TransactionObserver`` protocol for more information.
public struct DatabaseEvent {
    /// An event kind.
    public enum Kind: CInt {
        /// An insertion event
        case insert = 18 // SQLITE_INSERT
        
        /// A deletion event
        case delete = 9 // SQLITE_DELETE
        
        /// An update event
        case update = 23 // SQLITE_UPDATE
    }
    
    private let impl: any DatabaseEventImpl
    
    /// The event kind (insert, delete, or update).
    public let kind: Kind
    
    /// The name of the changed database.
    public var databaseName: String { impl.databaseName }
    
    /// The name of the changed database table.
    public var tableName: String { impl.tableName }
    
    /// The rowID of the changed row.
    public let rowID: Int64
    
    /// Returns a copy of the event.
    ///
    /// An event is only valid for the duration of the
    /// ``TransactionObserver/databaseDidChange(with:)`` method. You must copy
    /// the event when you want to store it for later:
    ///
    /// ```swift
    /// class MyObserver: TransactionObserver {
    ///     var events: [DatabaseEvent]
    ///     func databaseDidChange(with event: DatabaseEvent) {
    ///         events.append(event.copy())
    ///     }
    /// }
    /// ```
    public func copy() -> DatabaseEvent {
        impl.copy(self)
    }
    
    fileprivate init(kind: Kind, rowID: Int64, impl: any DatabaseEventImpl) {
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
    public enum Kind: CInt {
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
    ///        update, or delete operation;
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
    /// rightmost column.
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
    /// rightmost column.
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
    
    fileprivate init(kind: Kind, initialRowID: Int64?, finalRowID: Int64?, impl: any DatabasePreUpdateEventImpl) {
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
    
    private let impl: any DatabasePreUpdateEventImpl
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
            sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) in
                sqlite3_preupdate_old(connection, column, &value)
            })
    }
    
    func finalDatabaseValue(atIndex index: Int) -> DatabaseValue? {
        precondition(index >= 0 && index < Int(columnCount), "row index out of range")
        return getValue(
            connection,
            column: CInt(index),
            sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) in
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
        if let value {
            return DatabaseValue(sqliteValue: value)
        }
        return nil
    }
    
    private func preupdate_getValues_old(_ connection: SQLiteConnection) -> [DatabaseValue]? {
        preupdate_getValues(
            connection,
            sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) in
                sqlite3_preupdate_old(connection, column, &value)
            })
    }
    
    private func preupdate_getValues_new(_ connection: SQLiteConnection) -> [DatabaseValue]? {
        preupdate_getValues(
            connection,
            sqlite_func: { (connection: SQLiteConnection, column: CInt, value: inout SQLiteValue? ) in
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

/// A predicate that filters database events reported by `sqlite3_update_hook`.
enum DatabaseEventPredicate {
    /// All events.
    case all
    
    /// Filters events that match `observedEventKinds`, or are not
    ///
    /// - parameter observedEventKinds: Event kinds observed by
    ///   the TransactionObserver.
    /// - parameter authorizerEventKinds: Event kinds reported by the
    ///   statement authorizer.
    case matching(observedEventKinds: [DatabaseEventKind], authorizerEventKinds: [DatabaseEventKind])
    
    func callAsFunction(_ event: some DatabaseEventProtocol) -> Bool {
        switch self {
        case .all:
            return true
            
        case let .matching(observedEventKinds: observedEventKinds, authorizerEventKinds: authorizerEventKinds):
            if observedEventKinds.contains(where: { event.matchesKind($0) }) {
                return true
            }
            if !authorizerEventKinds.contains(where: { event.matchesKind($0) }) {
                // Here, `sqlite3_update_hook` emits an unexpected event, that
                // was not advertised by `sqlite3_set_authorizer` when the
                // statement was compiled:
                //
                // 1. Compile "INSERT INTO document ...": the authorizer
                //    reports an insertion in the `document` table.
                // 2. Execute "INSERT INTO document ...": the update hook
                //    reports an insertion in another table!
                //
                // Well, FTS4 (and maybe other virtual tables) perform such
                // unadvertised changes. Executing the "INSERT INTO document ..."
                // statement reports changes in the `document_content` shadow
                // table, not the `document` table reported when the
                // statement was compiled.
                //
                // When such a non-advertised event happens, we notify the
                // event to the transaction observer.
                //
                // See https://github.com/groue/GRDB.swift/issues/620
                return true
            }
            return false
        }
    }
}

// MARK: - SavepointStack

/// The SQLite savepoint stack is described at
/// <https://www.sqlite.org/lang_savepoint.html>
///
/// This class reimplements the SQLite stack, so that we can:
///
/// - know if there are currently active savepoints (isEmpty)
/// - buffer database events when a savepoint is active, in order to avoid
///   notifying transaction observers of database events that could be
///   rollbacked.
class SavepointStack {
    /// The buffered events (see DatabaseObservationBroker.databaseDidChange(with:))
    var eventsBuffer: [(event: any DatabaseEventProtocol, statementObservations: [StatementObservation])] = []
    
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
