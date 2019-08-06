import Foundation

/// Support for ValueObservation.
/// See DatabaseWriter.add(observation:onError:onChange:)
class ValueObserver<Reducer: ValueReducer>: TransactionObserver {
    // Reducer and notificationQueue must be set before observer is
    // added to a database.
    var reducer: Reducer!
    var notificationQueue: DispatchQueue?
    
    var baseRegion = DatabaseRegion() {
        didSet { observedRegion = baseRegion.union(selectedRegion) }
    }
    var selectedRegion = DatabaseRegion() {
        didSet { observedRegion = baseRegion.union(selectedRegion) }
    }
    var observedRegion: DatabaseRegion! // internal for testability
    private var requiresWriteAccess: Bool
    private var observesSelectedRegion: Bool
    private unowned var writer: DatabaseWriter
    private let reduceQueue: DispatchQueue
    private let onError: (Error) -> Void
    private let onChange: (Reducer.Value) -> Void
    private var isChanged = false
    private var isCancelled = false
    
    init(
        requiresWriteAccess: Bool,
        observesSelectedRegion: Bool,
        writer: DatabaseWriter,
        reduceQueue: DispatchQueue,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
    {
        self.writer = writer
        self.requiresWriteAccess = requiresWriteAccess
        self.observesSelectedRegion = observesSelectedRegion
        self.reduceQueue = reduceQueue
        self.onError = onError
        self.onChange = onChange
    }
    
    func cancel() {
        isCancelled = true
    }
    
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
        
        // Grab future fetched value
        let future: DatabaseFuture<Reducer.Fetched>
        if requiresWriteAccess {
            // Synchronous read/write fetch
            if observesSelectedRegion {
                do {
                    var fetchedValue: Reducer.Fetched!
                    var selectedRegion: DatabaseRegion!
                    try db.inTransaction {
                        let (_fetchedValue, _selectedRegion) = try db.recordingSelectedRegion {
                            try reducer.fetch(db)
                        }
                        fetchedValue = _fetchedValue
                        selectedRegion = _selectedRegion
                        return .commit
                    }
                    self.selectedRegion = selectedRegion
                    future = DatabaseFuture(DatabaseResult.success(fetchedValue))
                } catch {
                    future = DatabaseFuture(DatabaseResult.failure(error))
                }
            } else {
                // Synchronous read/write fetch
                future = DatabaseFuture(DatabaseResult {
                    var fetchedValue: Reducer.Fetched!
                    try db.inTransaction {
                        fetchedValue = try reducer.fetch(db)
                        return .commit
                    }
                    return fetchedValue
                })
            }
        } else {
            if observesSelectedRegion {
                // Synchronous read-only fetch
                do {
                    let (fetchedValue, selectedRegion) = try db.readOnly {
                        try db.recordingSelectedRegion {
                            try reducer.fetch(db)
                        }
                    }
                    self.selectedRegion = selectedRegion
                    future = DatabaseFuture(DatabaseResult.success(fetchedValue))
                } catch {
                    future = DatabaseFuture(DatabaseResult.failure(error))
                }
            } else {
                // Concurrent fetch
                future = writer.concurrentRead(reducer.fetch)
            }
        }
        
        // Wait for future fetched value in reduceQueue. This guarantees:
        // - that notifications have the same ordering as transactions.
        // - that expensive reduce operations are computed without blocking
        // any database dispatch queue.
        reduceQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isCancelled { return }
            self.reduce(future: future)
        }
    }
    
    func reduce(future: DatabaseFuture<Reducer.Fetched>) {
        do {
            if let value = try reducer.value(future.wait()) {
                if let queue = notificationQueue {
                    queue.async { [weak self] in
                        guard let self = self else { return }
                        if self.isCancelled { return }
                        self.onChange(value)
                    }
                } else {
                    onChange(value)
                }
            }
        } catch {
            if let queue = notificationQueue {
                queue.async { [weak self] in
                    guard let self = self else { return }
                    if self.isCancelled { return }
                    self.onError(error)
                }
            } else {
                onError(error)
            }
        }
    }
    
    func databaseDidRollback(_ db: Database) {
        isChanged = false
    }
}

class ValueObserverToken<Reducer: ValueReducer>: TransactionObserver {
    // Useless junk
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { return false }
    func databaseDidChange(with event: DatabaseEvent) { }
    func databaseDidCommit(_ db: Database) { }
    func databaseDidRollback(_ db: Database) { }
    
    weak var writer: DatabaseWriter?
    var observer: ValueObserver<Reducer>
    
    init(writer: DatabaseWriter, observer: ValueObserver<Reducer>) {
        self.writer = writer
        self.observer = observer
    }
    
    // The most ugly stuff ever
    deinit {
        observer.cancel()
        // TODO: have it not wait for the writer queue
        writer?.remove(transactionObserver: observer)
    }
}
