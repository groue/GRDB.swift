import Foundation

/// Support for ValueObservation.
/// See DatabaseWriter.add(observation:onError:onChange:)
class ValueObserver<Reducer: ValueReducer>: TransactionObserver {
    // Region, reducer, and notificationQueue must be set before observer is
    // added to a database.
    var region: DatabaseRegion!
    var reducer: Reducer!
    var notificationQueue: DispatchQueue?

    private var requiresWriteAccess: Bool
    unowned private var writer: DatabaseWriter
    private let reduceQueue: DispatchQueue
    private let onError: (Error) -> Void
    private let onChange: (Reducer.Value) -> Void
    private var isChanged = false
    private var isCancelled = false
    
    init(
        requiresWriteAccess: Bool,
        writer: DatabaseWriter,
        reduceQueue: DispatchQueue,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
    {
        self.writer = writer
        self.requiresWriteAccess = requiresWriteAccess
        self.reduceQueue = reduceQueue
        self.onError = onError
        self.onChange = onChange
    }
    
    func cancel() {
        isCancelled = true
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        if isCancelled { return false }
        return region.isModified(byEventsOfKind: eventKind)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        if isCancelled { return }
        if region.isModified(by: event) {
            isChanged = true
            stopObservingDatabaseChangesUntilNextTransaction()
        }
    }
    
    func databaseDidCommit(_ db: Database) {
        if isCancelled { return }
        guard isChanged else { return }
        isChanged = false
        
        // Grab future fetched value
        let future = reducer.fetchFuture(db, writer: writer, requiringWriteAccess: requiresWriteAccess)
        
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
