#if canImport(Combine)
import Combine
#endif
import Foundation

public struct DatabaseRegionObservation {
    /// A closure that is evaluated when the observation starts, and returns
    /// the observed database region.
    var observedRegion: (Database) throws -> DatabaseRegion
}

extension DatabaseRegionObservation {
    /// Creates a `DatabaseRegionObservation` that notifies all transactions
    /// that modify one of the provided regions.
    ///
    /// For example:
    ///
    /// ```swift
    /// // An observation that tracks the 'player' table
    /// let observation = DatabaseRegionObservation(tracking: Player.all())
    /// ```
    ///
    /// - parameter regions: A list of observed regions.
    public init(tracking regions: any DatabaseRegionConvertible...) {
        self.init(tracking: regions)
    }
    
    /// Creates a `DatabaseRegionObservation` that notifies all transactions
    /// that modify one of the provided regions.
    ///
    /// For example:
    ///
    /// ```swift
    /// // An observation that tracks the 'player' table
    /// let observation = DatabaseRegionObservation(tracking: [Player.all()])
    /// ```
    ///
    /// - parameter regions: An array of observed regions.
    public init(tracking regions: [any DatabaseRegionConvertible]) {
        self.init(observedRegion: DatabaseRegion.union(regions))
    }
}

extension DatabaseRegionObservation {
    /// The state of a started DatabaseRegionObservation
    private enum ObservationState {
        case cancelled
        case pending
        case started(DatabaseRegionObserver)
    }
    
    /// Starts observing the database.
    ///
    /// The observation lasts until the returned cancellable is cancelled
    /// or deallocated.
    ///
    /// For example:
    ///
    /// ```swift
    /// let observation = DatabaseRegionObservation(tracking: Player.all())
    ///
    /// let cancellable = try observation.start(in: dbQueue) { error in
    ///     // handle error
    /// } onChange: { (db: Database) in
    ///     print("A modification of the player table has just been committed.")
    /// }
    /// ```
    ///
    /// If this method is called from the writer dispatch queue of `writer` (see
    /// ``DatabaseWriter``), the observation starts immediately. Otherwise, it
    /// blocks the current thread until a write access can be established.
    ///
    /// Both `onError` and `onChange` closures are executed in the writer
    /// dispatch queue, serialized with all database updates performed
    /// by `writer`.
    ///
    /// The ``Database`` argument to `onChange` is valid only during the
    /// execution of the closure. Do not store or return the database connection
    /// for later use.
    ///
    /// - parameter writer: A DatabaseWriter.
    /// - parameter onError: The closure to execute when the observation fails.
    /// - parameter onChange: The closure to execute when a transaction has
    ///   modified the observed region.
    /// - returns: A DatabaseCancellable that can stop the observation.
    public func start(
        in writer: some DatabaseWriter,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Database) -> Void)
    -> AnyDatabaseCancellable
    {
        @LockedBox var state = ObservationState.pending
        
        // Use unsafeReentrantWrite so that observation can start from any
        // dispatch queue.
        writer.unsafeReentrantWrite { db in
            do {
                let region = try observedRegion(db).observableRegion(db)
                $state.update {
                    let observer = DatabaseRegionObserver(region: region, onChange: {
                        if case .cancelled = state {
                            return
                        }
                        onChange($0)
                    })
                    
                    // Use the `.observerLifetime` extent so that we can cancel
                    // the observation by deallocating the observer. This is
                    // a simpler way to cancel the observation than waiting for
                    // *another* write access in order to explicitly remove
                    // the observer.
                    db.add(transactionObserver: observer, extent: .observerLifetime)
                    
                    $0 = .started(observer)
                }
            } catch {
                onError(error)
            }
        }
        
        return AnyDatabaseCancellable {
            // Deallocates the transaction observer. This makes sure that the
            // `onChange` callback will never be called again, because the
            // observation was started with the `.observerLifetime` extent.
            state = .cancelled
        }
    }
}

#if canImport(Combine)
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension DatabaseRegionObservation {
    // MARK: - Publishing Impactful Transactions
    
    /// Returns a publisher that observes the database.
    ///
    /// The publisher publishes ``Database`` connections on the writer dispatch
    /// queue of `writer` (see ``DatabaseWriter``). Those connections are valid
    /// only when published. Do not store or return them for later use.
    ///
    /// Do not reschedule the publisher with `receive(on:options:)` or any
    /// `Publisher` method that schedules publisher elements.
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func publisher(in writer: some DatabaseWriter) -> DatabasePublishers.DatabaseRegion {
        DatabasePublishers.DatabaseRegion(self, in: writer)
    }
}
#endif

private class DatabaseRegionObserver: TransactionObserver {
    let region: DatabaseRegion
    let onChange: (Database) -> Void
    var isChanged = false
    
    init(region: DatabaseRegion, onChange: @escaping (Database) -> Void) {
        self.region = region
        self.onChange = onChange
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        region.isModified(byEventsOfKind: eventKind)
    }
    
    func databaseDidChange() {
        isChanged = true
        stopObservingDatabaseChangesUntilNextTransaction()
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
        
        onChange(db)
    }
    
    func databaseDidRollback(_ db: Database) {
        isChanged = false
    }
}

#if canImport(Combine)
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension DatabasePublishers {
    /// A publisher that tracks transactions that modify a database region.
    ///
    /// You build such a publisher from ``DatabaseRegionObservation``.
    public struct DatabaseRegion: Publisher {
        public typealias Output = Database
        public typealias Failure = Error
        
        let writer: any DatabaseWriter
        let observation: DatabaseRegionObservation
        
        init(_ observation: DatabaseRegionObservation, in writer: some DatabaseWriter) {
            self.writer = writer
            self.observation = observation
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            let subscription = DatabaseRegionSubscription(
                writer: writer,
                observation: observation,
                downstream: subscriber)
            subscriber.receive(subscription: subscription)
        }
    }
    
    private class DatabaseRegionSubscription<Downstream: Subscriber>: Subscription
    where Downstream.Failure == Error, Downstream.Input == Database
    {
        private struct WaitingForDemand {
            let downstream: Downstream
            let writer: any DatabaseWriter
            let observation: DatabaseRegionObservation
        }
        
        private struct Observing {
            let downstream: Downstream
            let writer: any DatabaseWriter // Retain writer until subscription is finished
            var remainingDemand: Subscribers.Demand
        }
        
        private enum State {
            // Waiting for demand, not observing the database.
            case waitingForDemand(WaitingForDemand)
            
            // Observing the database.
            case observing(Observing)
            
            // Completed or cancelled, not observing the database.
            case finished
        }
        
        // cancellable is not stored in self.state because we must enter the
        // .observing state *before* the observation starts.
        private var cancellable: AnyDatabaseCancellable?
        private var state: State
        private var lock = NSRecursiveLock() // Allow re-entrancy
        
        init(
            writer: some DatabaseWriter,
            observation: DatabaseRegionObservation,
            downstream: Downstream)
        {
            state = .waitingForDemand(WaitingForDemand(
                                        downstream: downstream,
                                        writer: writer,
                                        observation: observation))
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.synchronized {
                switch state {
                case let .waitingForDemand(info):
                    guard demand > 0 else {
                        return
                    }
                    state = .observing(Observing(
                        downstream: info.downstream,
                        writer: info.writer,
                        remainingDemand: demand))
                    cancellable = info.observation.start(
                        in: info.writer,
                        onError: { [weak self] in self?.receive(failure: $0) },
                        onChange: { [weak self] in self?.receive($0) })
                    
                case var .observing(info):
                    info.remainingDemand += demand
                    state = .observing(info)
                    
                case .finished:
                    break
                }
            }
        }
        
        func cancel() {
            lock.synchronized {
                cancellable = nil
                state = .finished
            }
        }
        
        private func receive(_ value: Database) {
            lock.synchronized {
                if case let .observing(info) = state,
                   info.remainingDemand > .none
                {
                    let additionalDemand = info.downstream.receive(value)
                    if case var .observing(info) = state {
                        info.remainingDemand += additionalDemand
                        info.remainingDemand -= 1
                        state = .observing(info)
                    }
                }
            }
        }
        
        private func receive(failure error: Error) {
            lock.synchronized {
                if case let .observing(info) = state {
                    state = .finished
                    info.downstream.receive(completion: .failure(error))
                }
            }
        }
    }
}
#endif
