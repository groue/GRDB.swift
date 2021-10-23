import Foundation

public enum SharedValueObservationExtent {
    case observationLifetime
    case whileObserved
}

extension ValueObservation {
    public func shared(
        in reader: DatabaseReader,
        scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main),
        extent: SharedValueObservationExtent = .whileObserved)
    -> SharedValueObservation<Reducer.Value>
    {
        SharedValueObservation(scheduling: scheduler, extent: extent) { onError, onChange in
            self.start(in: reader, scheduling: scheduler, onError: onError, onChange: onChange)
        }
    }
}

public final class SharedValueObservation<Element> {
    typealias StartFunction = (
        _ onError: @escaping (Error) -> Void,
        _ onChange: @escaping (Element) -> Void)
    -> DatabaseCancellable
    
    private let scheduler: ValueObservationScheduler
    private let extent: SharedValueObservationExtent
    private let startObservation: StartFunction
    private let lock = NSRecursiveLock() // support synchronous observation events
    
    // protected by lock
    private var clients: [Client]
    private var isObserving = false
    private var cancellable: AnyDatabaseCancellable?
    private var lastResult: Result<Element, Error>?
    
    private final class Client {
        var onError: (Error) -> Void
        var onChange: (Element) -> Void
        
        init(onError: @escaping (Error) -> Void, onChange: @escaping (Element) -> Void) {
            self.onError = onError
            self.onChange = onChange
        }
    }
    
    fileprivate init(
        scheduling scheduler: ValueObservationScheduler,
        extent: SharedValueObservationExtent,
        startObservation: @escaping StartFunction)
    {
        self.scheduler = scheduler
        self.extent = extent
        self.startObservation = startObservation
        self.clients = []
    }
    
    public func start(
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Element) -> Void)
    -> DatabaseCancellable
    {
        synchronized {
            // Support for reentrancy: a shared immediate observation is
            // started from the first value notification of that same shared
            // immediate observation. Yeah, users are nasty.
            // In this case, self.cancellable is still nil, because we are
            // still waiting for the upstream ValueObservation to start.
            // But we must not start another one.
            let needsStart = !isObserving
            
            // State change
            let client = Client(onError: onError, onChange: onChange)
            clients.append(client)
            isObserving = true
            
            // Side effect
            if needsStart {
                // Self retains the cancellable, so don't have the cancellable retain self.
                cancellable = AnyDatabaseCancellable(startObservation(
                    // onError
                    { [weak self] error in
                        self?.handleError(error)
                    },
                    // onChange
                    { [weak self] element in
                        self?.handleChange(element)
                    }))
            } else if let result = lastResult {
                // Notify last result as an initial value
                scheduler.scheduleInitial {
                    switch result {
                    case let .failure(error):
                        onError(error)
                    case let .success(value):
                        onChange(value)
                    }
                }
            }
            
            return AnyDatabaseCancellable {
                // Retain shared observation (self) until client cancels
                self.handleCancel(client)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        synchronized {
            let notifiedClients = clients
            
            // State change
            lastResult = .failure(error)
            clients = []
            
            // Side effect
            for client in notifiedClients {
                client.onError(error)
            }
        }
    }
    
    private func handleChange(_ value: Element) {
        synchronized {
            // State change
            lastResult = .success(value)
            
            // Side effect
            for client in clients {
                client.onChange(value)
            }
        }
    }
    
    private func handleCancel(_ client: Client) {
        synchronized {
            // State change
            clients.removeFirst(where: { $0 === client })
            if clients.isEmpty && extent == .whileObserved {
                isObserving = false
                cancellable = nil
            }
        }
    }
    
    private func synchronized<T>(_ execute: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try execute()
    }
}
