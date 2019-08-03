/// DatabaseRegionObservation tracks changes in the results of database
/// requests, and notifies each database transaction whenever the
/// database changes.
///
/// For example:
///
///     let observation = DatabaseRegionObservation(tracking: Player.all)
///     let observer = try observation.start(in: dbQueue) { db: Database in
///         print("Players have changed.")
///     }
public struct DatabaseRegionObservation {
    /// The extent of the database observation. The default is
    /// `.observerLifetime`: the observation lasts until the
    /// observer returned by the `start(in:onChange:)` method
    /// is deallocated.
    public var extent: Database.TransactionObservationExtent
    
    /// A closure that is evaluated when the observation starts, and returns
    /// the observed database region.
    var observedRegion: (Database) throws -> DatabaseRegion
}

extension DatabaseRegionObservation {
    /// Creates a DatabaseRegionObservation which observes *regions*, and
    /// notifies whenever one of the observed regions is modified by a
    /// database transaction.
    ///
    /// For example, this sample code counts the number of a times the player
    /// table is modified:
    ///
    ///     let observation = DatabaseRegionObservation(tracking: Player.all())
    ///
    ///     var count = 0
    ///     let observer = observation.start(in: dbQueue) { _ in
    ///         count += 1
    ///         print("Players have been modified \(count) times.")
    ///     }
    ///
    /// The observation lasts until the observer returned by `start` is
    /// deallocated. See the `extent` property for more information.
    ///
    /// - parameter regions: A list of observed regions.
    public init(tracking regions: DatabaseRegionConvertible...) {
        self.init(tracking: regions)
    }
    
    /// Creates a DatabaseRegionObservation which observes *regions*, and
    /// notifies whenever one of the observed regions is modified by a
    /// database transaction.
    ///
    /// For example, this sample code counts the number of a times the player
    /// table is modified:
    ///
    ///     let observation = DatabaseRegionObservation(tracking: [Player.all()])
    ///
    ///     var count = 0
    ///     let observer = observation.start(in: dbQueue) { _ in
    ///         count += 1
    ///         print("Players have been modified \(count) times.")
    ///     }
    ///
    /// The observation lasts until the observer returned by `start` is
    /// deallocated. See the `extent` property for more information.
    ///
    /// - parameter regions: A list of observed regions.
    public init(tracking regions: [DatabaseRegionConvertible]) {
        self.init(
            extent: .observerLifetime,
            observedRegion: DatabaseRegion.union(regions))
    }
}

extension DatabaseRegionObservation {
    /// Starts the observation in the provided database writer (such as
    /// a database queue or database pool), and returns a transaction observer.
    ///
    /// - parameter reader: A DatabaseWriter.
    /// - parameter onChange: A closure that is provided a database connection
    ///   with write access each time the observed region has been modified.
    /// - returns: a TransactionObserver
    public func start(
        in dbWriter: DatabaseWriter,
        onChange: @escaping (Database) -> Void)
        throws -> TransactionObserver
    {
        // Use unsafeReentrantWrite so that observation can start from any
        // dispatch queue.
        return try dbWriter.unsafeReentrantWrite { db -> TransactionObserver in
            let region = try observedRegion(db).ignoringViews(db)
            let observer = DatabaseRegionObserver(region: region, onChange: onChange)
            db.add(transactionObserver: observer, extent: extent)
            return observer
        }
    }
}

private class DatabaseRegionObserver: TransactionObserver {
    let region: DatabaseRegion
    let onChange: (Database) -> Void
    var isChanged = false
    
    init(region: DatabaseRegion, onChange: @escaping (Database) -> Void) {
        self.region = region
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
        
        onChange(db)
    }
    
    func databaseDidRollback(_ db: Database) {
        isChanged = false
    }
}
