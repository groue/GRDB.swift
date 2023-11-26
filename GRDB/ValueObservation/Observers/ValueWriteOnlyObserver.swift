import Foundation

/// `ValueWriteOnlyObserver` observes the database for `ValueObservation`.
///
/// It performs the following database observation cycle:
///
/// 1. Start observation or detect a database change
/// 2. Fetch
/// 3. Reduce
/// 4. Notify
///
/// **Fetch** is always performed from the writer database connection (hence
/// the name of this observer).
///
/// **Reduce** is the operation that turns the fetched database values into the
/// observed values. Those are not the same. Consider, for example, the `map()`
/// and `removeDuplicates()` operators: they perform their job during the
/// reducing stage.
///
/// **Notify** is calling user callbacks, in case of database change or error.
final class ValueWriteOnlyObserver<
    Writer: DatabaseWriter,
    Reducer: ValueReducer,
    Scheduler: ValueObservationScheduler>
{
    // MARK: - Configuration
    //
    // Configuration is not mutable.
    
    /// How to schedule observed values and errors.
    private let scheduler: Scheduler
    
    /// Configures the tracked database region.
    private let trackingMode: ValueObservationTrackingMode
    
    // MARK: - Mutable State
    //
    // The observer has four distinct mutable states that evolve independently,
    // and are made thread-safe with various mechanisms:
    //
    // - A `DatabaseAccess`: ability to access the database. It is constant but
    //   turns nil after the observation fails or is cancelled, in order to
    //   release memory and resources when the observation completes. It is
    //   guarded by `lock`, because observation can fail or be cancelled from
    //   multiple threads.
    //
    // - A `NotificationCallbacks`: ability to notify observation events. It is
    //   constant but turns nil when failure or cancellation is notified, in
    //   order to release memory and resources when the observation completes.
    //   It is guarded by `lock`, because observation can fail or be cancelled
    //   from multiple threads.
    //
    // - An `ObservationState`: relationship with the `TransactionObserver`
    //   protocol. It is only accessed from the serialized writer
    //   dispatch queue.
    //
    // - A `Reducer`: the observation reducer, only accessed from the
    //   serialized dispatch queue `reduceQueue`.
    //
    // The `reduceQueue` guarantees that fresh value notifications have the same
    // order as transactions. It is different from the serialized writer
    // dispatch queue because we do not want to lock the database as
    // computations (`map`, `removeDuplicates()`, etc.) are performed.
    //
    // Despite being protected by the same lock, `DatabaseAccess` and
    // `NotificationCallbacks` are not merged together. This is because the
    // observer does not lose `DatabaseAccess` at the same time it
    // looses `NotificationCallbacks`:
    //
    // - In case of cancellation, `NotificationCallbacks` is lost first, and
    //   `DatabaseAccess` is lost asynchronously, after the observer could
    //   resign as a transaction observer. See `cancel()`.
    //
    // - In case of error, `DatabaseAccess` is lost first, and
    //   `NotificationCallbacks` is lost asynchronously, after the error could
    //   be notified. See error catching clauses.
    
    /// Ability to access the database
    private struct DatabaseAccess {
        /// The observed DatabaseWriter.
        let writer: Writer
        
        /// If true, database values are fetched from a read-only access.
        private let readOnly: Bool
        
        /// A reducer that fetches database values.
        private let reducer: Reducer
        
        init(writer: Writer, readOnly: Bool, reducer: Reducer) {
            self.writer = writer
            self.readOnly = readOnly
            self.reducer = reducer
        }
        
        func fetch(_ db: Database) throws -> Reducer.Fetched {
            try db.isolated(readOnly: readOnly) {
                try reducer._fetch(db)
            }
        }
        
        func fetchRecordingObservedRegion(_ db: Database) throws -> (Reducer.Fetched, DatabaseRegion) {
            var region = DatabaseRegion()
            let fetchedValue = try db.isolated(readOnly: readOnly) {
                try db.recordingSelection(&region) {
                    try reducer._fetch(db)
                }
            }
            return try (fetchedValue, region.observableRegion(db))
        }
    }
    
    /// Ability to notify observation events
    private struct NotificationCallbacks {
        let events: ValueObservationEvents
        let onChange: (Reducer.Value) -> Void
    }
    
    /// Relationship with the `TransactionObserver` protocol
    private struct ObservationState {
        var region: DatabaseRegion?
        var isModified = false
        
        static var notObserving: Self { .init(region: nil, isModified: false) }
    }
    
    /// Protects `databaseAccess` and `notificationCallbacks`.
    private let lock = NSLock()
    
    /// The dispatch queue where database values are reduced into observed
    /// values before being notified. Protects `reducer`.
    private let reduceQueue: DispatchQueue
    
    /// Access to the database, protected by `lock`.
    private var databaseAccess: DatabaseAccess?
    
    /// Ability to notify observation events, protected by `lock`.
    private var notificationCallbacks: NotificationCallbacks?
    
    /// Support for `TransactionObserver`, protected by the serialized writer
    /// dispatch queue.
    private var observationState = ObservationState.notObserving
    
    /// Protected by `reduceQueue`.
    private var reducer: Reducer
    
    init(
        writer: Writer,
        scheduler: Scheduler,
        readOnly: Bool,
        trackingMode: ValueObservationTrackingMode,
        reducer: Reducer,
        events: ValueObservationEvents,
        onChange: @escaping (Reducer.Value) -> Void)
    {
        // Configuration
        self.scheduler = scheduler
        self.trackingMode = trackingMode
        
        // State
        self.databaseAccess = DatabaseAccess(
            writer: writer,
            readOnly: readOnly,
            // ValueReducer semantics guarantees that reducer._fetch
            // is independent from the reducer state
            reducer: reducer)
        self.notificationCallbacks = NotificationCallbacks(events: events, onChange: onChange)
        self.reducer = reducer
        self.reduceQueue = DispatchQueue(
            label: writer.configuration.identifier(
                defaultLabel: "GRDB",
                purpose: "ValueObservation"),
            qos: writer.configuration.readQoS)
    }
}

// MARK: - Starting the Observation

extension ValueWriteOnlyObserver {
    // Starts the observation
    func start() -> AnyDatabaseCancellable {
        let (notificationCallbacks, writer) = lock.synchronized {
            (self.notificationCallbacks, self.databaseAccess?.writer)
        }
        guard let notificationCallbacks, let writer else {
            // Likely a GRDB bug: during a synchronous start, user is not
            // able to cancel observation.
            fatalError("can't start a cancelled or failed observation")
        }
        
        if scheduler.immediateInitialValue() {
            do {
                // Start the observation in an synchronous way
                let initialValue = try syncStart(from: writer)
                
                // Notify the initial value from the dispatch queue the
                // observation was started from
                notificationCallbacks.onChange(initialValue)
            } catch {
                // Notify error from the dispatch queue the observation
                // was started from.
                notificationCallbacks.events.didFail?(error)
                
                // Early return!
                return AnyDatabaseCancellable { /* nothing to cancel */ }
            }
        } else {
            // Start the observation in an asynchronous way
            asyncStart(from: writer)
        }
        
        // Make sure the returned cancellable cancels the observation
        // when deallocated. We can't relying on the deallocation of
        // self to trigger early cancellation, because self may be retained by
        // some closure waiting to run in some DispatchQueue.
        return AnyDatabaseCancellable(self)
    }
    
    /// Synchronously starts the observation, and returns the initial value.
    ///
    /// Unlike `asyncStart()`, this method does not notify the initial value or error.
    private func syncStart(from writer: Writer) throws -> Reducer.Value {
        // Start from a write access, so that self can register as a
        // transaction observer.
        //
        // Start in a synchronous reentrant way, in case this method is called
        // from a database access.
        try writer.unsafeReentrantWrite { db in
            // Fetch & Start observing the database
            guard let fetchedValue = try fetchAndStartObservation(db) else {
                // Likely a GRDB bug: during a synchronous start, user is not
                // able to cancel observation.
                fatalError("can't start a cancelled or failed observation")
            }
            
            // Reduce
            return try reduceQueue.sync {
                guard let initialValue = try reducer._value(fetchedValue) else {
                    fatalError("Broken contract: reducer has no initial value")
                }
                
                return initialValue
            }
        }
    }
    
    /// Asynchronously starts the observation
    ///
    /// Unlike `syncStart()`, this method does notify the initial value or error.
    private func asyncStart(from writer: Writer) {
        // Start from a write access, so that self can register as a
        // transaction observer.
        writer.asyncWriteWithoutTransaction { db in
            do {
                // Fetch & Start observing the database
                guard let fetchedValue = try self.fetchAndStartObservation(db) else {
                    return /* Cancelled */
                }
                
                // Reduce
                //
                // Reducing is performed asynchronously, so that we do not lock
                // the writer dispatch queue longer than necessary.
                //
                // Important: reduceQueue.async guarantees the same ordering
                // between transactions and notifications!
                self.reduceQueue.async {
                    let isNotifying = self.lock.synchronized { self.notificationCallbacks != nil }
                    guard isNotifying else { return /* Cancelled */ }
                    
                    do {
                        guard let initialValue = try self.reducer._value(fetchedValue) else {
                            fatalError("Broken contract: reducer has no initial value")
                        }
                        
                        // Notify
                        self.scheduler.schedule {
                            let onChange = self.lock.synchronized { self.notificationCallbacks?.onChange }
                            guard let onChange else { return /* Cancelled */ }
                            onChange(initialValue)
                        }
                    } catch {
                        let writer = self.lock.synchronized { self.databaseAccess?.writer }
                        writer?.asyncWriteWithoutTransaction { db in
                            self.stopDatabaseObservation(db)
                        }
                        self.notifyError(error)
                    }
                }
            } catch {
                self.stopDatabaseObservation(db)
                self.notifyError(error)
            }
        }
    }
    
    /// Fetches the initial value, and start observing the database.
    ///
    /// Returns nil if the observation was cancelled before database observation
    /// could start.
    ///
    /// By grouping the initial fetch and the beginning of observation in a
    /// single database access, we are sure that no concurrent write can happen
    /// during the initial fetch, and that we won't miss any future change.
    private func fetchAndStartObservation(_ db: Database) throws -> Reducer.Fetched? {
        let (events, databaseAccess) = lock.synchronized {
            (notificationCallbacks?.events, self.databaseAccess)
        }
        guard let events, let databaseAccess else {
            return nil /* Cancelled */
        }
        
        switch trackingMode {
        case let .constantRegion(regions):
            let fetchedValue = try databaseAccess.fetch(db)
            let region = try DatabaseRegion.union(regions)(db)
            let observedRegion = try region.observableRegion(db)
            events.willTrackRegion?(observedRegion)
            startObservation(db, observedRegion: observedRegion)
            return fetchedValue
            
        case .constantRegionRecordedFromSelection,
                .nonConstantRegionRecordedFromSelection:
            let (fetchedValue, observedRegion) = try databaseAccess.fetchRecordingObservedRegion(db)
            events.willTrackRegion?(observedRegion)
            startObservation(db, observedRegion: observedRegion)
            return fetchedValue
        }
    }
    
    private func startObservation(_ db: Database, observedRegion: DatabaseRegion) {
        observationState.region = observedRegion
        assert(observationState.isModified == false)
        db.add(transactionObserver: self, extent: .observerLifetime)
    }
}

// MARK: - Observing Database Transactions

extension ValueWriteOnlyObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        if let region = observationState.region {
            return region.isModified(byEventsOfKind: eventKind)
        } else {
            return false
        }
    }
    
    func databaseDidChange() {
        // Database was modified!
        observationState.isModified = true
        // We can stop observing the current transaction
        stopObservingDatabaseChangesUntilNextTransaction()
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        if let region = observationState.region, region.isModified(by: event) {
            // Database was modified!
            observationState.isModified = true
            // We can stop observing the current transaction
            stopObservingDatabaseChangesUntilNextTransaction()
        }
    }
    
    func databaseDidCommit(_ db: Database) {
        // Ignore transaction unless database was modified
        guard observationState.isModified else { return }
        
        // Reset the isModified flag until next transaction
        observationState.isModified = false
        
        // Ignore transaction unless we are still notifying database events, and
        // we can still fetch fresh values.
        let (events, databaseAccess) = lock.synchronized {
            (notificationCallbacks?.events, self.databaseAccess)
        }
        guard let events, let databaseAccess else { return /* Cancelled */ }
        
        // Notify
        events.databaseDidChange?()
        
        do {
            // Fetch
            let fetchedValue: Reducer.Fetched
            
            switch trackingMode {
            case .constantRegion, .constantRegionRecordedFromSelection:
                // Tracked region is already known. Fetch only.
                fetchedValue = try databaseAccess.fetch(db)
            case .nonConstantRegionRecordedFromSelection:
                // Fetch and update the tracked region.
                let (value, observedRegion) = try databaseAccess.fetchRecordingObservedRegion(db)
                fetchedValue = value
                
                // Don't spam the user with region tracking events: wait for an actual change
                if let willTrackRegion = events.willTrackRegion, observedRegion != observationState.region {
                    willTrackRegion(observedRegion)
                }
                
                observationState.region = observedRegion
            }
            
            // Reduce
            //
            // Reducing is performed asynchronously, so that we do not lock
            // the writer dispatch queue longer than necessary.
            //
            // Important: reduceQueue.async guarantees the same ordering between
            // transactions and notifications!
            reduceQueue.async {
                let isNotifying = self.lock.synchronized { self.notificationCallbacks != nil }
                guard isNotifying else { return /* Cancelled */ }
                
                do {
                    let value = try self.reducer._value(fetchedValue)
                    
                    // Notify value
                    if let value {
                        self.scheduler.schedule {
                            let onChange = self.lock.synchronized { self.notificationCallbacks?.onChange }
                            guard let onChange else { return /* Cancelled */ }
                            onChange(value)
                        }
                    }
                } catch {
                    let writer = self.lock.synchronized { self.databaseAccess?.writer }
                    writer?.asyncWriteWithoutTransaction { db in
                        self.stopDatabaseObservation(db)
                    }
                    self.notifyError(error)
                }
            }
        } catch {
            stopDatabaseObservation(db)
            notifyError(error)
        }
    }
    
    func databaseDidRollback(_ db: Database) {
        // Reset the isModified flag until next transaction
        observationState.isModified = false
    }
}

// MARK: - Ending the Observation

extension ValueWriteOnlyObserver: DatabaseCancellable {
    func cancel() {
        // Notify cancellation
        let (events, writer) = lock.synchronized {
            let events = notificationCallbacks?.events
            notificationCallbacks = nil
            return (events, databaseAccess?.writer)
        }
        
        guard let events else { return /* Cancelled or failed */ }
        events.didCancel?()
        
        // Stop observing the database
        // Do it asynchronously, so that we do not block the current thread:
        // cancellation may be triggered while a long write access is executing.
        guard let writer else { return /* Failed */ }
        writer.asyncWriteWithoutTransaction { db in
            self.stopDatabaseObservation(db)
        }
    }
    
    func notifyError(_ error: Error) {
        scheduler.schedule {
            let events = self.lock.synchronized {
                let events = self.notificationCallbacks?.events
                self.notificationCallbacks = nil
                return events
            }
            guard let events else { return /* Cancelled */ }
            events.didFail?(error)
        }
    }
    
    private func stopDatabaseObservation(_ db: Database) {
        db.remove(transactionObserver: self)
        observationState = .notObserving
        lock.synchronized {
            databaseAccess = nil
        }
    }
}
