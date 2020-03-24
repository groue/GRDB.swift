import Foundation

/// Support for ValueObservation.
/// See DatabaseWriter.add(observation:onError:onChange:)
final class ValueObserver<Reducer: _ValueReducer> {
    var observedRegion: DatabaseRegion?
    private(set) var isCancelled = false
    private var reducer: Reducer
    private let requiresWriteAccess: Bool
    private weak var writer: DatabaseWriter?
    private let notificationQueue: DispatchQueue?
    private let reduceQueue: DispatchQueue
    private let onError: (Error) -> Void
    private let onChange: (Reducer.Value) -> Void
    private var isChanged = false
    
    init(
        requiresWriteAccess: Bool,
        writer: DatabaseWriter,
        reducer: Reducer,
        notificationQueue: DispatchQueue?,
        reduceQueue: DispatchQueue,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
    {
        self.writer = writer
        self.reducer = reducer
        self.requiresWriteAccess = requiresWriteAccess
        self.notificationQueue = notificationQueue
        self.reduceQueue = reduceQueue
        self.onError = onError
        self.onChange = onChange
    }
}

extension ValueObserver {
    /// This method must be called at most once, before the observer is added
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
        if let queue = notificationQueue {
            let onChange = self.onChange
            queue.async {
                if self.isCancelled { return }
                onChange(value)
            }
        } else {
            onChange(value)
        }
    }
    
    func send(_ error: Error) {
        if isCancelled { return }
        if let queue = notificationQueue {
            let onError = self.onError
            queue.async {
                if self.isCancelled { return }
                onError(error)
            }
        } else {
            onError(error)
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
        
        let fetchedValue: DatabaseFuture<Reducer.Fetched>
        
        if requiresWriteAccess || needsRecordingObservedRegion {
            // Synchronous fetch
            fetchedValue = DatabaseFuture(Result {
                try recordingObservedRegionIfNeeded(db) {
                    try reducer.fetch(db, requiringWriteAccess: requiresWriteAccess)
                }
            })
        } else {
            // Concurrent fetch
            fetchedValue = writer.concurrentRead {
                return try self.reducer.fetch($0)
            }
        }
        
        // Wait for future fetched value in reduceQueue. This guarantees:
        // - that notifications have the same ordering as transactions.
        // - that expensive reduce operations are computed without blocking
        //   any database dispatch queue.
        reduceQueue.async {
            if self.isCancelled { return }
            self.reduce(fetchedValue: fetchedValue) { result in
                do {
                    try self.send(result.get())
                } catch {
                    self.send(error)
                }
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
            
            // Don't record schema introspection queries, which may be
            // run, or not, depending on the state of the schema cache.
            //
            // This gives us a quick way to make sure that the observation
            // below, which runs schema introspection queries as a side effect,
            // only tracks the "player" table:
            //
            //      let observation = ValueObservation.tracking { db in
            //          try Player.fetchOne(db, key: 1)
            //      }
            //
            // Strictly speaking, this prevents the recording of all schema
            // queries. But we assume, until proven wrong, that such recording
            // isn't needed by anyone.
            observedRegion = try region.ignoringViews(db).ignoringInternalSQLiteTables()
            return result
        } else {
            return try fetch()
        }
    }
    
    private func reduce(
        fetchedValue: DatabaseFuture<Reducer.Fetched>,
        completion: @escaping (Result<Reducer.Value, Error>) -> Void)
    {
        do {
            if let value = try reducer.value(fetchedValue.wait()) {
                completion(.success(value))
            }
        } catch {
            completion(.failure(error))
        }
    }
}

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
