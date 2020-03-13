import Foundation

/// Support for ValueObservation.
/// See DatabaseWriter.add(observation:onError:onChange:)
final class ValueObserver<Reducer: _ValueReducer> {
    var baseRegion = DatabaseRegion() {
        didSet { observedRegion = baseRegion.union(selectedRegion) }
    }
    var selectedRegion = DatabaseRegion() {
        didSet { observedRegion = baseRegion.union(selectedRegion) }
    }
    var observedRegion: DatabaseRegion! // internal for testability
    private var reducer: Reducer
    private let requiresWriteAccess: Bool
    private let observesSelectedRegion: Bool
    private unowned let writer: DatabaseWriter
    private let notificationQueue: DispatchQueue?
    private let reduceQueue: DispatchQueue
    private let onError: (Error) -> Void
    private let onChange: (Reducer.Value) -> Void
    private var isChanged = false
    private var isCancelled = false
    
    init(
        requiresWriteAccess: Bool,
        observesSelectedRegion: Bool,
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
        self.observesSelectedRegion = observesSelectedRegion
        self.notificationQueue = notificationQueue
        self.reduceQueue = reduceQueue
        self.onError = onError
        self.onChange = onChange
    }
    
    // Fetch initial value, with two side effects:
    //
    // This method must be called at most once, before the observer is added
    // to the database writer.
    func fetchInitialValue(_ db: Database) throws -> Reducer.Value {
        let value = try recordingSelectedRegionIfNeeded(db) {
            try reducer.fetchAndReduce(db, requiringWriteAccess: requiresWriteAccess)
        }
        if let value = value {
            return value
        }
        fatalError("Contract broken: reducer has no initial value")
    }
    
    func cancel() {
        isCancelled = true
    }
}

extension ValueObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        if isCancelled { return false }
        return observedRegion.isModified(byEventsOfKind: eventKind)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        if isCancelled { return }
        if observedRegion.isModified(by: event) {
            isChanged = true
            stopObservingDatabaseChangesUntilNextTransaction()
        }
    }
    
    func databaseDidCommit(_ db: Database) {
        if isCancelled { return }
        guard isChanged else { return }
        isChanged = false
        
        let reducer = self.reducer
        let fetchedValue: DatabaseFuture<Reducer.Fetched>
        
        if requiresWriteAccess || observesSelectedRegion {
            // Synchronous fetch
            fetchedValue = DatabaseFuture(Result {
                try recordingSelectedRegionIfNeeded(db) {
                    try reducer.fetch(db, requiringWriteAccess: requiresWriteAccess)
                }
            })
        } else {
            // Asynchronous fetch
            fetchedValue = writer.concurrentRead(reducer.fetch)
        }
        
        // Wait for future fetched value in reduceQueue. This guarantees:
        // - that notifications have the same ordering as transactions.
        // - that expensive reduce operations are computed without blocking
        //   any database dispatch queue.
        reduceQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isCancelled { return }
            
            Self.reduce(fetchedValue: fetchedValue, with: reducer) { [weak self] result in
                guard let self = self else { return }
                if self.isCancelled { return }
                
                // Check that we're still on reduce queue.
                if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
                    dispatchPrecondition(condition: .onQueue(self.reduceQueue))
                }
                
                do {
                    let (reducer, value) = try result.get()
                    self.reducer = reducer
                    self.notify(value)
                } catch {
                    self.notify(error)
                }
            }
        }
    }
    
    func databaseDidRollback(_ db: Database) {
        isChanged = false
    }
}

extension ValueObserver {
    private static func reduce(
        fetchedValue: DatabaseFuture<Reducer.Fetched>,
        with reducer: Reducer,
        completion: @escaping (Result<(Reducer, Reducer.Value), Error>) -> Void)
    {
        do {
            var reducer = reducer
            if let value = try reducer.value(fetchedValue.wait()) {
                completion(.success((reducer, value)))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    private func recordingSelectedRegionIfNeeded<T>(_ db: Database, _ block: () throws -> T) rethrows -> T {
        if observesSelectedRegion {
            let result: T
            (result, selectedRegion) = try db.recordingSelectedRegion(block)
            return result
        } else {
            return try block()
        }
    }
    
    private func notify(_ value: Reducer.Value) {
        assert(!isCancelled)
        if let queue = notificationQueue {
            let onChange = self.onChange
            queue.async { [weak self] in
                guard let self = self else { return }
                if self.isCancelled { return }
                onChange(value)
            }
        } else {
            onChange(value)
        }
    }
    
    private func notify(_ error: Error) {
        assert(!isCancelled)
        if let queue = notificationQueue {
            let onError = self.onError
            queue.async { [weak self] in
                guard let self = self else { return }
                if self.isCancelled { return }
                onError(error)
            }
        } else {
            onError(error)
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
        let observer = self.observer
        observer.cancel()
        writer?.asyncWriteWithoutTransaction { db in
            db.remove(transactionObserver: observer)
        }
    }
}
