import Foundation

/// Support for ValueObservation.
/// See DatabaseWriter.add(observation:onError:onChange:)
final class ValueObserver<Reducer: ValueReducer> {
    var isCompleted: Bool { synchronized { _isCompleted } }
    let events: ValueObservationEvents
    let trackingMode: ValueObservationTrackingMode
    private var observedRegion: DatabaseRegion? {
        didSet {
            if let willTrackRegion = events.willTrackRegion,
               let region = observedRegion,
               region != oldValue
            {
                willTrackRegion(region)
            }
        }
    }
    private var _isCompleted = false
    private var reducer: Reducer
    private let requiresWriteAccess: Bool
    private weak var writer: DatabaseWriter?
    private let scheduler: ValueObservationScheduler
    private let reduceQueue: DispatchQueue
    private var isChanged = false
    private let onChange: (Reducer.Value) -> Void
    
    // This lock protects `_isCompleted`.
    // It also protects `reducer` because of what is likely a compiler bug:
    // - <https://github.com/groue/GRDB.swift/issues/1026>
    // - <https://github.com/groue/GRDB.swift/pull/1025>
    private var lock = NSRecursiveLock() // protects _isCompleted and reducer
    
    init(
        events: ValueObservationEvents,
        reducer: Reducer,
        requiresWriteAccess: Bool,
        trackingMode: ValueObservationTrackingMode,
        writer: DatabaseWriter,
        scheduler: ValueObservationScheduler,
        reduceQueue: DispatchQueue,
        onChange: @escaping (Reducer.Value) -> Void)
    {
        self.events = events
        self.reducer = reducer
        self.requiresWriteAccess = requiresWriteAccess
        self.trackingMode = trackingMode
        self.writer = writer
        self.scheduler = scheduler
        self.reduceQueue = reduceQueue
        self.onChange = onChange
    }
    
    convenience init(
        observation: ValueObservation<Reducer>,
        writer: DatabaseWriter,
        scheduler: ValueObservationScheduler,
        reduceQueue: DispatchQueue,
        onChange: @escaping (Reducer.Value) -> Void)
    {
        self.init(
            events: observation.events,
            reducer: observation.makeReducer(),
            requiresWriteAccess: observation.requiresWriteAccess,
            trackingMode: observation.trackingMode,
            writer: writer,
            scheduler: scheduler,
            reduceQueue: reduceQueue,
            onChange: onChange)
    }
}

// MARK: - TransactionObserver

extension ValueObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        assert(
            observedRegion != nil,
            "fetchInitialValue() was not called before ValueObserver was added as a transaction observer")
        return observedRegion!.isModified(byEventsOfKind: eventKind)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        assert(
            observedRegion != nil,
            "fetchInitialValue() was not called before ValueObserver was added as a transaction observer")
        if observedRegion!.isModified(by: event) {
            isChanged = true
            stopObservingDatabaseChangesUntilNextTransaction()
        }
    }
    
    func databaseDidCommit(_ writerDB: Database) {
        guard isChanged else { return }
        isChanged = false
        if isCompleted { return }
        
        events.databaseDidChange?()
        
        guard let future = fetchFuture(writerDB) else {
            // Database connection closed: give up
            return
        }
        
        reduce(future: future)
    }
    
    func databaseDidRollback(_ db: Database) {
        isChanged = false
    }
}

// MARK: - Internal

extension ValueObserver {
    /// Fetch the initial observed value, and moves the reducer forward.
    ///
    /// This method must be called once, before the observer is added
    /// to the database writer.
    func fetchInitialValue(_ db: Database) throws -> Reducer.Value {
        guard let value = try fetchValue(db) else {
            fatalError("Contract broken: reducer has no initial value")
        }
        return value
    }
    
    /// Fetch an observed value, and moves the reducer forward.
    func fetchValue(_ db: Database) throws -> Reducer.Value? {
        try db.isolated(readOnly: !requiresWriteAccess) {
            try updatingObserverRegionIfNeeded(db) {
                try synchronized {
                    try reducer.fetchAndReduce(db)
                }
            }
        }
    }
    
    func complete() {
        synchronized {
            _isCompleted = true
            writer?.remove(transactionObserver: self)
        }
    }
    
    func cancel() {
        synchronized {
            if _isCompleted { return }
            complete()
            events.didCancel?()
        }
    }
    
    func notifyChange(_ value: Reducer.Value) {
        if isCompleted { return }
        scheduler.schedule {
            if self.isCompleted { return }
            self.onChange(value)
        }
    }
    
    func notifyErrorAndComplete(_ error: Error) {
        if isCompleted { return }
        scheduler.schedule {
            let shouldNotify: Bool = self.synchronized {
                if self._isCompleted {
                    return false
                } else {
                    self.complete()
                    return true
                }
            }
            if shouldNotify {
                self.events.didFail?(error)
            }
        }
    }
}

// MARK: - Private

extension ValueObserver {
    /// Returns nil if the database was closed
    private func fetchFuture(_ writerDB: Database) -> DatabaseFuture<Reducer.Fetched>? {
        if requiresWriteAccess {
            // We obviously need to fetch from the writer connection
            return fetchFutureSync(writerDB)
        }
        
        switch trackingMode {
        case .nonConstantRegionRecordedFromSelection:
            // When the tracked region is not constant, we must fetch from the
            // writer connection so that we do not miss future changes that
            // would modify the tracked region.
            return fetchFutureSync(writerDB)
            
        case .constantRegion, .constantRegionRecordedFromSelection:
            // When the tracked region is constant, we can fetch concurrently.
            return fetchFutureConcurrent(writerDB)
        }
    }
    
    private func fetchFutureSync(_ writerDB: Database) -> DatabaseFuture<Reducer.Fetched> {
        DatabaseFuture(Result {
            try writerDB.isolated(readOnly: !requiresWriteAccess) {
                try fetchUpdatingObserverRegionIfNeeded(writerDB)
            }
        })
    }
    
    /// Returns nil if the database was closed
    private func fetchFutureConcurrent(_ writerDB: Database) -> DatabaseFuture<Reducer.Fetched>? {
        guard let writer = writer else {
            // Database connection closed: give up
            return nil
        }
        return writer.concurrentRead { readerDB in
            try self.fetchUpdatingObserverRegionIfNeeded(readerDB)
        }
    }
    
    private func fetchUpdatingObserverRegionIfNeeded(_ db: Database) throws -> Reducer.Fetched {
        try updatingObserverRegionIfNeeded(db) {
            let reducer = synchronized { self.reducer }
            return try reducer._fetch(db)
        }
    }

    private func reduce(future: DatabaseFuture<Reducer.Fetched>) {
        // Wait for the future fetched value in reduceQueue. This guarantees:
        // - that notifications have the same ordering as transactions.
        // - that expensive reduce operations are computed without blocking
        //   any database dispatch queue.
        reduceQueue.async {
            if self.isCompleted { return }
            do {
                let fetchedValue = try future.wait()
                if let value = try self.synchronized({ try self.reducer._value(fetchedValue) }) {
                    self.notifyChange(value)
                }
            } catch {
                self.notifyErrorAndComplete(error)
            }
        }
    }
    
    private func synchronized<T>(_ execute: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try execute()
    }
    
    private func updatingObserverRegionIfNeeded<T>(
        _ db: Database,
        fetch: () throws -> T)
    throws -> T
    {
        switch trackingMode {
        case let .constantRegion(regions):
            if observedRegion == nil {
                observedRegion = try DatabaseRegion.union(regions)(db)
            }
            return try fetch()
        case .constantRegionRecordedFromSelection:
            if observedRegion == nil {
                return try recordingSelectedRegion(db, fetch: fetch)
            } else {
                return try fetch()
            }
        case .nonConstantRegionRecordedFromSelection:
            return try recordingSelectedRegion(db, fetch: fetch)
        }
    }
    
    private func recordingSelectedRegion<T>(
        _ db: Database,
        fetch: () throws -> T)
    throws -> T
    {
        var region = DatabaseRegion()
        let result = try db.recordingSelection(&region, fetch)
        observedRegion = try region.observableRegion(db)
        return result
    }
}
