//
//  ValueObservation+Row.swift
//  GRDB
//
//  Created by Gwendal Roué on 24/11/2018.
//  Copyright © 2018 Gwendal Roué. All rights reserved.
//

extension ValueObservation where Reducer == Void {

    // MARK: - Row Observation
    
    /// Creates a ValueObservation which observes *request*, and notifies
    /// fresh rows whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player")
    ///     let observation = ValueObservation.trackingAll(request)
    ///
    ///     let observer = try observation.start(in: dbQueue) { rows: [Row] in
    ///         print("Players have changed")
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
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Distinct<[Row]>>
        where Request.RowDecoder == Row
    {
        return ValueObservation.tracking(request, fetchDistinct: request.fetchAll)
    }
    
    /// Creates a ValueObservation which observes *request*, and notifies a
    /// fresh row whenever the request is modified by a database transaction.
    ///
    /// For example:
    ///
    ///     let request = SQLRequest<Row>("SELECT * FROM player WHERE id = ?", arguments: [1])
    ///     let observation = ValueObservation.trackingOne(request)
    ///
    ///     let observer = try observation.start(in: dbQueue) { row: Row? in
    ///         print("Players have changed")
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
    public static func trackingOne<Request: FetchRequest>(_ request: Request)
        -> ValueObservation<ValueReducers.Distinct<Row?>>
        where Request.RowDecoder == Row
    {
        return ValueObservation.tracking(request, fetchDistinct: request.fetchOne)
    }
}
