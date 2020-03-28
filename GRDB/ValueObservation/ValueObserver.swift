import Foundation

/// Support for ValueObservation.
/// See DatabaseWriter.add(observation:onError:onChange:)
final class ValueObserver<Reducer: _ValueReducer> {
    var observedRegion: DatabaseRegion?
    private(set) var isCancelled = false
    private var reducer: Reducer
    private let requiresWriteAccess: Bool
    private weak var writer: DatabaseWriter?
    private let scheduler: ValueObservationScheduler
    private let reduceQueue: DispatchQueue
    private let onError: (Error) -> Void
    private let onChange: (Reducer.Value) -> Void
    private var isChanged = false
    
    init(
        requiresWriteAccess: Bool,
        writer: DatabaseWriter,
        reducer: Reducer,
        scheduler: ValueObservationScheduler,
        reduceQueue: DispatchQueue,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
    {
        self.writer = writer
        self.reducer = reducer
        self.requiresWriteAccess = requiresWriteAccess
        self.scheduler = scheduler
        self.reduceQueue = reduceQueue
        self.onError = onError
        self.onChange = onChange
    }
}

extension ValueObserver {
    /// This method must be called once, before the observer is added
    /// to the database writer.
    func fetchInitialValue(_ db: Database) throws -> Reducer.Value {
        guard let value = try fetchNextValue(db) else {
            fatalError("Contract broken: reducer has no initial value")
        }
        return value
    }
    
    func fetchNextValue(_ db: Database) throws -> Reducer.Value? {
        try recordingObservedRegionIfNeeded(db) {
            try reducer.fetchAndReduce(db, requiringWriteAccess: requiresWriteAccess)
        }
    }
    
    func cancel() {
        isCancelled = true
        writer?.asyncWriteWithoutTransaction { db in
            db.remove(transactionObserver: self)
        }
    }
    
    func send(_ value: Reducer.Value) {
        if isCancelled { return }
        scheduler.impl.schedule {
            if self.isCancelled { return }
            self.onChange(value)
        }
    }
    
    func complete(withError error: Error) {
        if isCancelled { return }
        scheduler.impl.schedule {
            if self.isCancelled { return }
            self.onError(error)
            self.cancel()
        }
    }
}

extension ValueObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        if isCancelled { return false }
        return observedRegion!.isModified(byEventsOfKind: eventKind)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        if isCancelled { return }
        if observedRegion!.isModified(by: event) {
            isChanged = true
            stopObservingDatabaseChangesUntilNextTransaction()
        }
    }
    
    func databaseDidCommit(_ db: Database) {
        guard let writer = writer else { return }
        if isCancelled { return }
        guard isChanged else { return }
        isChanged = false
        
        // Fetch
        let fetchedValue: DatabaseFuture<Reducer.Fetched>
        if requiresWriteAccess || needsRecordingObservedRegion {
            // Synchronously
            fetchedValue = DatabaseFuture(Result {
                try recordingObservedRegionIfNeeded(db) {
                    try reducer.fetch(db, requiringWriteAccess: requiresWriteAccess)
                }
            })
        } else {
            // Concurrently
            fetchedValue = writer.concurrentRead(reducer.fetch)
        }
        
        // Reduce
        //
        // Wait for future fetched value in reduceQueue. This guarantees:
        // - that notifications have the same ordering as transactions.
        // - that expensive reduce operations are computed without blocking
        //   any database dispatch queue.
        reduceQueue.async {
            if self.isCancelled { return }
            do {
                if let value = try self.reducer.value(fetchedValue.wait()) {
                    self.send(value)
                }
            } catch {
                self.complete(withError: error)
            }
        }
    }
    
    func databaseDidRollback(_ db: Database) {
        isChanged = false
    }
}

extension ValueObserver {
    private var needsRecordingObservedRegion: Bool {
        observedRegion == nil || !reducer.isObservedRegionDeterministic
    }
    
    private func recordingObservedRegionIfNeeded<T>(
        _ db: Database,
        fetch: () throws -> T)
        throws -> T
    {
        if needsRecordingObservedRegion {
            var region = DatabaseRegion()
            let result = try db.recordingSelection(&region, fetch)
            
            // Don't record views, because they are never exposed to the
            // TransactionObserver protocol.
            //
            // Don't record schema introspection queries, which may be
            // run, or not, depending on the state of the schema cache.
            observedRegion = try region.ignoringViews(db).ignoringInternalSQLiteTables()
            
            return result
        } else {
            return try fetch()
        }
    }
}

// TODO: remove when we have proper support for cancellation
class ValueObserverToken<Reducer: _ValueReducer>: TransactionObserver {
    // Useless junk
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { false }
    func databaseDidChange(with event: DatabaseEvent) { }
    func databaseDidCommit(_ db: Database) { }
    func databaseDidRollback(_ db: Database) { }
    
    weak var writer: DatabaseWriter?
    var observer: ValueObserver<Reducer>
    
    init(writer: DatabaseWriter, observer: ValueObserver<Reducer>) {
        self.writer = writer
        self.observer = observer
    }
    
    deinit {
        observer.cancel()
    }
}
