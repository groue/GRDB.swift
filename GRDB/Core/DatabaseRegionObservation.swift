public struct DatabaseRegionObservation {
    public var extent = Database.TransactionObservationExtent.observerLifetime
    
    /// A closure that is evaluated when the observation starts, and returns
    /// the observed database region.
    var observedRegion: (Database) throws -> DatabaseRegion

    public init(tracking region: @escaping (Database) throws -> DatabaseRegion) {
        self.observedRegion = { db in
            // Remove views from the observed region.
            //
            // We can do it because we are only interested in modifications in
            // actual tables. And we want to do it because we have a fast path
            // for simple regions that span a single table.
            let views = try db.schema().names(ofType: .view)
            return try region(db).ignoring(views)
        }
    }
    
    public init(tracking regions: DatabaseRegionConvertible...) {
        self.init(tracking: regions)
    }
    
    public init(tracking regions: [DatabaseRegionConvertible]) {
        self.init(tracking: DatabaseRegion.union(regions))
    }
}

extension DatabaseRegionObservation {
    public func start(in dbWriter: DatabaseWriter, onChange: @escaping (Database) -> Void) throws -> TransactionObserver {
        // Use unsafeReentrantWrite so that observation can start from any
        // dispatch queue.
        return try dbWriter.unsafeReentrantWrite { db -> TransactionObserver in
            let region = try observedRegion(db)
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
