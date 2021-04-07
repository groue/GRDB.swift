import Foundation

/// Support for ValueObservation.
/// See DatabaseWriter.add(observation:onError:onChange:)
final class ValueObserver<Reducer: ValueReducer> {
    var isCompleted: Bool { synchronized { _isCompleted } }
    let events: ValueObservationEvents
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
    private var lock = NSRecursiveLock() // protects _isCompleted
    
    init(
        events: ValueObservationEvents,
        reducer: Reducer,
        requiresWriteAccess: Bool,
        writer: DatabaseWriter,
        scheduler: ValueObservationScheduler,
        reduceQueue: DispatchQueue,
        onChange: @escaping (Reducer.Value) -> Void)
    {
        self.events = events
        self.reducer = reducer
        self.requiresWriteAccess = requiresWriteAccess
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
    
    func databaseDidCommit(_ db: Database) {
        guard isChanged else { return }
        isChanged = false
        if isCompleted { return }
        
        events.databaseDidChange?()
        
        // 1. Fetch
        let fetchedFuture: DatabaseFuture<Reducer.Fetched>
        if requiresWriteAccess || needsRecordingSelectedRegion {
            // Synchronously
            fetchedFuture = DatabaseFuture(Result {
                try recordingSelectedRegionIfNeeded(db) {
                    try reducer.fetch(db, requiringWriteAccess: requiresWriteAccess)
                }
            })
        } else {
            // Concurrently
            guard let writer = writer else { return }
            fetchedFuture = writer.concurrentRead(reducer._fetch)
        }
        
        // 2. Reduce
        //
        // Wait for the future fetched value in reduceQueue. This guarantees:
        // - that notifications have the same ordering as transactions.
        // - that expensive reduce operations are computed without blocking
        //   any database dispatch queue.
        reduceQueue.async {
            if self.isCompleted { return }
            do {
                let fetchedValue = try fetchedFuture.wait()
                if let value = self.reducer._value(fetchedValue) {
                    self.notifyChange(value)
                }
            } catch {
                self.notifyErrorAndComplete(error)
            }
        }
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
        try recordingSelectedRegionIfNeeded(db) {
            try reducer.fetchAndReduce(db, requiringWriteAccess: requiresWriteAccess)
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
    private func synchronized<T>(_ execute: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try execute()
    }
    
    private var needsRecordingSelectedRegion: Bool {
        observedRegion == nil || !reducer._isSelectedRegionDeterministic
    }
    
    private func recordingSelectedRegionIfNeeded<T>(
        _ db: Database,
        fetch: () throws -> T)
    throws -> T
    {
        guard needsRecordingSelectedRegion else {
            return try fetch()
        }
        
        var region = DatabaseRegion()
        let result = try db.recordingSelection(&region, fetch)
        observedRegion = try region.observableRegion(db)
        return result
    }
}
