import Foundation

/// Support for ValueObservation.
/// See DatabaseWriter.add(observation:onError:onChange:)
class ValueObserver<Reducer: ValueReducer>: TransactionObserver {
    /* private */ let region: DatabaseRegion // Internal for testability
    private var reducer: Reducer
    private var requiresWriteAccess: Bool
    unowned private var writer: DatabaseWriter
    private let notificationQueue: DispatchQueue?
    private let reduceQueue: DispatchQueue
    private let onError: ((Error) -> Void)?
    private let onChange: (Reducer.Value) -> Void
    private var isChanged = false
    
    init(
        region: DatabaseRegion,
        reducer: Reducer,
        requiresWriteAccess: Bool,
        writer: DatabaseWriter,
        notificationQueue: DispatchQueue?,
        reduceQueue: DispatchQueue,
        onError: ((Error) -> Void)?,
        onChange: @escaping (Reducer.Value) -> Void)
    {
        self.writer = writer
        self.region = region
        self.reducer = reducer
        self.requiresWriteAccess = requiresWriteAccess
        self.notificationQueue = notificationQueue
        self.reduceQueue = reduceQueue
        self.onError = onError
        self.onChange = onChange
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return region.isModified(byEventsOfKind: eventKind)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        if region.isModified(by: event) {
            isChanged = true
            stopObservingDatabaseChangesUntilNextTransaction()
        }
    }
    
    func databaseDidCommit(_ db: Database) {
        guard isChanged else { return }
        isChanged = false
        
        // Grab future fetched value
        let future = reducer.fetchFuture(db, writer: writer, requiringWriteAccess: requiresWriteAccess)
        
        // Wait for future fetched value in reduceQueue. This guarantees:
        // - that notifications have the same ordering as transactions.
        // - that expensive reduce operations are computed without blocking
        // any database dispatch queue.
        reduceQueue.async { [weak self] in
            // Never ever retain self so that notifications stop when self
            // is deallocated by the user.
            do {
                if let value = try self?.reducer.value(future.wait()) {
                    if let queue = self?.notificationQueue {
                        queue.async {
                            self?.onChange(value)
                        }
                    } else {
                        self?.onChange(value)
                    }
                }
            } catch {
                guard self?.onError != nil else {
                    // TODO: how can we let the user know about the error?
                    return
                }
                if let queue = self?.notificationQueue {
                    queue.async {
                        self?.onError?(error)
                    }
                } else {
                    self?.onError?(error)
                }
            }
        }
    }
    
    func databaseDidRollback(_ db: Database) {
        isChanged = false
    }
}
