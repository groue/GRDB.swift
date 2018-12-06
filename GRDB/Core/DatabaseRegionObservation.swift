public final class DatabaseRegionObservation {
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
    
    public convenience init(tracking regions: DatabaseRegionConvertible...) {
        self.init(tracking: regions)
    }
    
    public convenience init(tracking regions: [DatabaseRegionConvertible]) {
        self.init(tracking: DatabaseRegion.union(regions))
    }
}

extension DatabaseWriter {
    public func add(observation: DatabaseRegionObservation, onChange: @escaping (Database) -> Void) throws -> TransactionObserver {
        return try writeWithoutTransaction { db -> TransactionObserver in
            let region = try observation.observedRegion(db)
            let observer = DatabaseRegionObserver(region: region, onChange: onChange)
            add(transactionObserver: observer)
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
