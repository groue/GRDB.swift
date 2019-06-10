extension FetchRequest {
    
    // MARK: - Observation
    
    /// Creates a ValueObservation which observes *request*, and notifies its
    /// count whenever it is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = request.observationForCount()
    ///
    ///     let observer = try observation.start(in: dbQueue) { count: Int in
    ///         print("Number of players has changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `start(in:onError:onChange:)` method, a fresh
    /// value is immediately notified on the main queue.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `start` is deallocated.
    ///
    /// - returns: a ValueObservation.
    public func observationForCount() ->
        ValueObservation<ValueReducers.RemoveDuplicates<ValueReducers.Fetch<Int>>>
    {
        return ValueObservation
            .tracking(self, fetch: fetchCount)
            .removeDuplicates()
    }
}

extension TableRecord {
    
    // MARK: - Observation
    
    /// Creates a ValueObservation which observes the record table, and notifies
    /// its count whenever it is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let observation = Player.observationForCount()
    ///
    ///     let observer = try observation.start(in: dbQueue) { count: Int in
    ///         print("Number of players has changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `start(in:onError:onChange:)` method, a fresh
    /// value is immediately notified on the main queue.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `start` is deallocated.
    ///
    /// - returns: a ValueObservation.
    public static func observationForCount() ->
        ValueObservation<ValueReducers.RemoveDuplicates<ValueReducers.Fetch<Int>>>
    {
        return all().observationForCount()
    }
}

extension ValueObservation where Reducer == Void {
    
    // MARK: - Count Observation
    
    /// Creates a ValueObservation which observes *request*, and notifies its
    /// count whenever it is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = Player.all()
    ///     let observation = ValueObservation.trackingCount(request)
    ///
    ///     let observer = try observation.start(in: dbQueue) { count: Int in
    ///         print("Number of players has changed")
    ///     }
    ///
    /// The returned observation has the default configuration:
    ///
    /// - When started with the `start(in:onError:onChange:)` method, a fresh
    /// value is immediately notified on the main queue.
    /// - Upon subsequent database changes, fresh values are notified on the
    /// main queue.
    /// - The observation lasts until the observer returned by
    /// `start` is deallocated.
    ///
    /// - parameter request: the observed request.
    /// - returns: a ValueObservation.
    @available(*, deprecated, message: "Use request.observationForCount() instead")
    public static func trackingCount<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.RemoveDuplicates<ValueReducers.Fetch<Int>>>
    {
        return request.observationForCount()
    }
}
