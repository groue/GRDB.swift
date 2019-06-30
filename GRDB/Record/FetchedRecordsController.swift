import Foundation

#if os(iOS)
import UIKit
#endif

/// You use FetchedRecordsController to track changes in the results of an
/// SQLite request.
///
/// See https://github.com/groue/GRDB.swift#fetchedrecordscontroller for
/// more information.
public final class FetchedRecordsController<Record: FetchableRecord> {
    
    // MARK: - Initialization
    
    /// Creates a fetched records controller initialized from a SQL query and
    /// its eventual arguments.
    ///
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         sql: "SELECT * FROM wine WHERE color = ? ORDER BY name",
    ///         arguments: [Color.red],
    ///         isSameRecord: { (wine1, wine2) in wine1.id == wine2.id })
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    ///     - queue: A serial dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller tracking callbacks will be
    ///         notified of changes in this queue. The controller itself must be
    ///         used from this queue.
    ///
    ///     - isSameRecord: Optional function that compares two records.
    ///
    ///         This function should return true if the two records have the
    ///         same identity. For example, they have the same id.
    public convenience init(
        _ databaseWriter: DatabaseWriter,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil,
        queue: DispatchQueue = .main,
        isSameRecord: ((Record, Record) -> Bool)? = nil) throws
    {
        try self.init(
            databaseWriter,
            request: SQLRequest<Record>(sql: sql, arguments: arguments, adapter: adapter),
            queue: queue,
            isSameRecord: isSameRecord)
    }
    
    /// Creates a fetched records controller initialized from a fetch request
    /// from the [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
    ///
    ///     let request = Wine.order(Column("name"))
    ///     let controller = FetchedRecordsController(
    ///         dbQueue,
    ///         request: request,
    ///         isSameRecord: { (wine1, wine2) in wine1.id == wine2.id })
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - request: A fetch request.
    ///     - queue: A serial dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller tracking callbacks will be
    ///         notified of changes in this queue. The controller itself must be
    ///         used from this queue.
    ///
    ///     - isSameRecord: Optional function that compares two records.
    ///
    ///         This function should return true if the two records have the
    ///         same identity. For example, they have the same id.
    public convenience init<Request>(
        _ databaseWriter: DatabaseWriter,
        request: Request,
        queue: DispatchQueue = .main,
        isSameRecord: ((Record, Record) -> Bool)? = nil) throws
        where Request: FetchRequest, Request.RowDecoder == Record
    {
        let itemsAreIdenticalFactory: ItemComparatorFactory<Record>
        if let isSameRecord = isSameRecord {
            itemsAreIdenticalFactory = { _ in { isSameRecord($0.record, $1.record) } }
        } else {
            itemsAreIdenticalFactory = { _ in { _, _ in false } }
        }
        
        try self.init(
            databaseWriter,
            request: request,
            queue: queue,
            itemsAreIdenticalFactory: itemsAreIdenticalFactory)
    }
    
    private init<Request>(
        _ databaseWriter: DatabaseWriter,
        request: Request,
        queue: DispatchQueue,
        itemsAreIdenticalFactory: @escaping ItemComparatorFactory<Record>) throws
        where Request: FetchRequest, Request.RowDecoder == Record
    {
        self.itemsAreIdenticalFactory = itemsAreIdenticalFactory
        self.request = ItemRequest(request)
        (self.region, self.itemsAreIdentical) = try databaseWriter.unsafeRead { db in
            let region = try request.databaseRegion(db)
            let itemsAreIdentical = try itemsAreIdenticalFactory(db)
            return (region, itemsAreIdentical)
        }
        self.databaseWriter = databaseWriter
        self.queue = queue
    }
    
    /// Executes the controller's fetch request.
    ///
    /// After executing this method, you can access the the fetched objects with
    /// the `fetchedRecords` property.
    ///
    /// This method must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    public func performFetch() throws {
        // If some changes are currently processed, make sure they are
        // discarded. But preserve eventual changes processing for future
        // changes.
        let fetchAndNotifyChanges = observer?.fetchAndNotifyChanges
        observer?.invalidate()
        observer = nil
        
        // Fetch items on the writing dispatch queue, so that the transaction
        // observer is added on the same serialized queue as transaction
        // callbacks.
        try databaseWriter.write { db in
            let initialItems = try request.fetchAll(db)
            fetchedItems = initialItems
            if let fetchAndNotifyChanges = fetchAndNotifyChanges {
                let observer = FetchedRecordsObserver(region: self.region, fetchAndNotifyChanges: fetchAndNotifyChanges)
                self.observer = observer
                observer.items = initialItems
                db.add(transactionObserver: observer)
            }
        }
    }
    
    
    // MARK: - Configuration
    
    /// The database writer used to fetch records.
    ///
    /// The controller registers as a transaction observer in order to respond
    /// to changes.
    public let databaseWriter: DatabaseWriter
    
    /// The dispatch queue on which the controller must be used.
    ///
    /// Unless specified otherwise at initialization time, it is the main queue.
    public let queue: DispatchQueue
    
    /// Updates the fetch request, and eventually notifies the tracking
    /// callbacks if performFetch() has been called.
    ///
    /// This method must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    public func setRequest<Request>(_ request: Request)
        throws
        where Request: FetchRequest, Request.RowDecoder == Record
    {
        self.request = ItemRequest(request)
        (self.region, self.itemsAreIdentical) = try databaseWriter.unsafeRead { db in
            let region = try request.databaseRegion(db)
            let itemsAreIdentical = try itemsAreIdenticalFactory(db)
            return (region, itemsAreIdentical)
        }
        
        // No observer: don't look for changes
        guard let observer = observer else { return }
        
        // If some changes are currently processed, make sure they are
        // discarded. But preserve eventual changes processing.
        let fetchAndNotifyChanges = observer.fetchAndNotifyChanges
        observer.invalidate()
        self.observer = nil
        
        // Replace observer so that it tracks a new set of columns,
        // and notify eventual changes
        let initialItems = fetchedItems
        databaseWriter.writeWithoutTransaction { db in
            let observer = FetchedRecordsObserver(region: region, fetchAndNotifyChanges: fetchAndNotifyChanges)
            self.observer = observer
            observer.items = initialItems
            db.add(transactionObserver: observer)
            observer.fetchAndNotifyChanges(observer)
        }
    }
    
    /// Updates the fetch request, and eventually notifies the tracking
    /// callbacks if performFetch() has been called.
    ///
    /// This method must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    public func setRequest(
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil)
        throws
    {
        try setRequest(SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Registers changes notification callbacks.
    ///
    /// This method must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    ///
    /// - parameters:
    ///     - willChange: Invoked before records are updated.
    ///     - onChange: Invoked for each record that has been added,
    ///       removed, moved, or updated.
    ///     - didChange: Invoked after records have been updated.
    public func trackChanges(
        willChange: ((FetchedRecordsController<Record>) -> Void)? = nil,
        onChange: ((FetchedRecordsController<Record>, Record, FetchedRecordChange) -> Void)? = nil,
        didChange: ((FetchedRecordsController<Record>) -> Void)? = nil)
    {
        // Without SE-0110, we could simply:
        //
        //  trackChanges(
        //      fetchAlongside: { _ in },
        //      willChange: willChange.map { callback in { (controller, _) in callback(controller) } },
        //      onChange: onChange,
        //      didChange: didChange.map { callback in { (controller, _) in callback(controller) } })
        //
        // But instead:
        let wrappedWillChange: ((FetchedRecordsController<Record>, Void) -> Void)?
        if let willChange = willChange {
            wrappedWillChange = { (controller, _) in willChange(controller) }
        } else {
            wrappedWillChange = nil
        }
        
        let wrappedDidChange: ((FetchedRecordsController<Record>, Void) -> Void)?
        if let didChange = didChange {
            wrappedDidChange = { (controller, _) in didChange(controller) }
        } else {
            wrappedDidChange = nil
        }
        
        trackChanges(
            fetchAlongside: { _ in },
            willChange: wrappedWillChange,
            onChange: onChange,
            didChange: wrappedDidChange)
    }
    
    /// Registers changes notification callbacks.
    ///
    /// This method must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    ///
    /// - parameters:
    ///     - fetchAlongside: The value returned from this closure is given to
    ///       willChange and didChange callbacks, as their
    ///       `fetchedAlongside` argument. The closure is guaranteed to see the
    ///       database in the state it has just after eventual changes to the
    ///       fetched records have been performed. Use it in order to fetch
    ///       values that must be consistent with the fetched records.
    ///     - willChange: Invoked before records are updated.
    ///     - onChange: Invoked for each record that has been added,
    ///       removed, moved, or updated.
    ///     - didChange: Invoked after records have been updated.
    public func trackChanges<T>(
        fetchAlongside: @escaping (Database) throws -> T,
        willChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> Void)? = nil,
        onChange: ((FetchedRecordsController<Record>, Record, FetchedRecordChange) -> Void)? = nil,
        didChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> Void)? = nil)
    {
        // If some changes are currently processed, make sure they are
        // discarded because they would trigger previously set callbacks.
        observer?.invalidate()
        observer = nil
        
        guard (willChange != nil) || (onChange != nil) || (didChange != nil) else {
            // Stop tracking
            return
        }
        
        var willProcessTransaction: () -> Void = { }
        var didProcessTransaction: () -> Void = { }
        #if os(iOS)
        if let application = application {
            var backgroundTaskID: UIBackgroundTaskIdentifier! = nil
            willProcessTransaction = {
                backgroundTaskID = application.beginBackgroundTask {
                    application.endBackgroundTask(backgroundTaskID)
                }
            }
            didProcessTransaction = {
                application.endBackgroundTask(backgroundTaskID)
            }
        }
        #endif
        
        let initialItems = fetchedItems
        databaseWriter.writeWithoutTransaction { db in
            let fetchAndNotifyChanges = makeFetchAndNotifyChangesFunction(
                controller: self,
                fetchAlongside: fetchAlongside,
                itemsAreIdentical: itemsAreIdentical,
                willProcessTransaction: willProcessTransaction,
                willChange: willChange,
                onChange: onChange,
                didChange: didChange,
                didProcessTransaction: didProcessTransaction)
            let observer = FetchedRecordsObserver(region: region, fetchAndNotifyChanges: fetchAndNotifyChanges)
            self.observer = observer
            if let initialItems = initialItems {
                observer.items = initialItems
                db.add(transactionObserver: observer)
                observer.fetchAndNotifyChanges(observer)
            }
        }
    }
    
    /// Registers an error callback.
    ///
    /// Whenever the controller could not look for changes after a transaction
    /// has potentially modified the tracked request, this error handler is
    /// called.
    ///
    /// The request observation is not stopped, though: future transactions may
    /// successfully be handled, and the notified changes will then be based on
    /// the last successful fetch.
    ///
    /// This method must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    public func trackErrors(_ errorHandler: @escaping (FetchedRecordsController<Record>, Error) -> Void) {
        self.errorHandler = errorHandler
    }
    
    #if os(iOS)
    /// Call this method when changes performed while the application is
    /// in the background should be processed before the application enters the
    /// suspended state.
    ///
    /// Whenever the tracked request is changed, the fetched records controller
    /// sets up a background task using
    /// `UIApplication.beginBackgroundTask(expirationHandler:)` which is ended
    /// after the `didChange` callback has completed.
    public func allowBackgroundChangesTracking(in application: UIApplication) {
        self.application = application
    }
    #endif
    
    // MARK: - Accessing Records
    
    /// The fetched records.
    ///
    /// The value of this property is nil until performFetch() has been called.
    ///
    /// The records reflect the state of the database after the initial
    /// call to performFetch, and after each database transaction that affects
    /// the results of the fetch request.
    ///
    /// This property must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    public var fetchedRecords: [Record] {
        guard let fetchedItems = fetchedItems else {
            fatalError("the performFetch() method must be called before accessing fetched records")
        }
        return fetchedItems.map { $0.record }
    }
    
    
    // MARK: - Not public
    
    #if os(iOS)
    /// Support for allowBackgroundChangeTracking(in:)
    var application: UIApplication?
    #endif
    
    /// The items
    fileprivate var fetchedItems: [Item<Record>]?
    
    /// The record comparator
    private var itemsAreIdentical: ItemComparator<Record>
    
    /// The record comparator factory (support for request change)
    private let itemsAreIdenticalFactory: ItemComparatorFactory<Record>
    
    /// The request
    fileprivate typealias ItemRequest = AnyFetchRequest<Item<Record>>
    fileprivate var request: ItemRequest
    
    /// The observed database region
    private var region: DatabaseRegion
    
    /// The eventual current database observer
    private var observer: FetchedRecordsObserver<Record>?
    
    /// The eventual error handler
    fileprivate var errorHandler: ((FetchedRecordsController<Record>, Error) -> Void)?
}

extension FetchedRecordsController where Record: TableRecord {
    
    // MARK: - Initialization
    
    /// Creates a fetched records controller initialized from a SQL query and
    /// its eventual arguments.
    ///
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         sql: "SELECT * FROM wine WHERE color = ? ORDER BY name",
    ///         arguments: [Color.red])
    ///
    /// The records are compared by primary key (single-column primary key,
    /// compound primary key, or implicit rowid). For a database table which
    /// has an `id` primary key, this initializer is equivalent to:
    ///
    ///     // Assuming the wine table has an `id` primary key:
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         sql: "SELECT * FROM wine WHERE color = ? ORDER BY name",
    ///         arguments: [Color.red],
    ///         isSameRecord: { (wine1, wine2) in wine1.id == wine2.id })
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    ///     - queue: A serial dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller tracking callbacks will be
    ///         notified of changes in this queue. The controller itself must be
    ///         used from this queue.
    public convenience init(
        _ databaseWriter: DatabaseWriter,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil,
        queue: DispatchQueue = .main) throws
    {
        try self.init(
            databaseWriter,
            request: SQLRequest(sql: sql, arguments: arguments, adapter: adapter),
            queue: queue)
    }
    
    /// Creates a fetched records controller initialized from a fetch request
    /// from the [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
    ///
    ///     let request = Wine.order(Column("name"))
    ///     let controller = FetchedRecordsController(
    ///         dbQueue,
    ///         request: request)
    ///
    /// The records are compared by primary key (single-column primary key,
    /// compound primary key, or implicit rowid). For a database table which
    /// has an `id` primary key, this initializer is equivalent to:
    ///
    ///     // Assuming the wine table has an `id` primary key:
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         request: request,
    ///         isSameRecord: { (wine1, wine2) in wine1.id == wine2.id })
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - request: A fetch request.
    ///     - queue: A serial dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller tracking callbacks will be
    ///         notified of changes in this queue. The controller itself must be
    ///         used from this queue.
    public convenience init<Request>(
        _ databaseWriter: DatabaseWriter,
        request: Request,
        queue: DispatchQueue = .main) throws
        where Request: FetchRequest, Request.RowDecoder == Record
    {
        // Builds a function that returns true if and only if two items
        // have the same primary key and primary keys contain at least one
        // non-null value.
        let itemsAreIdenticalFactory: ItemComparatorFactory<Record> = { db in
            // Extract primary key columns from database table
            let columns = try db.primaryKey(Record.databaseTableName).columns
            
            // Compare primary keys
            assert(!columns.isEmpty)
            return { (lItem, rItem) in
                var notNullValue = false
                for column in columns {
                    let lValue: DatabaseValue = lItem.row[column]
                    let rValue: DatabaseValue = rItem.row[column]
                    if lValue != rValue {
                        // different primary keys
                        return false
                    }
                    if !lValue.isNull || !rValue.isNull {
                        notNullValue = true
                    }
                }
                // identical primary keys iff at least one value is not null
                return notNullValue
            }
        }
        try self.init(
            databaseWriter,
            request: request,
            queue: queue,
            itemsAreIdenticalFactory: itemsAreIdenticalFactory)
    }
}


// MARK: - FetchedRecordsObserver

/// FetchedRecordsController adopts TransactionObserverType so that it can
/// monitor changes to its fetched records.
private final class FetchedRecordsObserver<Record: FetchableRecord>: TransactionObserver {
    var isValid: Bool
    var needsComputeChanges: Bool
    var items: [Item<Record>]!  // ought to be not nil when observer has started tracking transactions
    let queue: DispatchQueue // protects items
    let region: DatabaseRegion
    var fetchAndNotifyChanges: (FetchedRecordsObserver<Record>) -> Void
    
    init(region: DatabaseRegion, fetchAndNotifyChanges: @escaping (FetchedRecordsObserver<Record>) -> Void) {
        self.isValid = true
        self.items = nil
        self.needsComputeChanges = false
        self.queue = DispatchQueue(label: "GRDB.FetchedRecordsObserver")
        self.region = region
        self.fetchAndNotifyChanges = fetchAndNotifyChanges
    }
    
    func invalidate() {
        isValid = false
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return region.isModified(byEventsOfKind: eventKind)
    }
    
    /// Part of the TransactionObserverType protocol
    func databaseDidChange(with event: DatabaseEvent) {
        if region.isModified(by: event) {
            needsComputeChanges = true
            stopObservingDatabaseChangesUntilNextTransaction()
        }
    }
    
    /// Part of the TransactionObserverType protocol
    func databaseDidRollback(_ db: Database) {
        needsComputeChanges = false
    }
    
    /// Part of the TransactionObserverType protocol
    func databaseDidCommit(_ db: Database) {
        // The databaseDidCommit callback is called in the database writer
        // dispatch queue, which is serialized: it is guaranteed to process the
        // last database transaction.
        
        // Were observed tables modified?
        guard needsComputeChanges else { return }
        needsComputeChanges = false
        
        fetchAndNotifyChanges(self)
    }
}


// MARK: - Changes

private typealias FetchCompletionHandler<Record: FetchableRecord, T> = (
    DatabaseResult<(fetchedItems: [Item<Record>],
    fetchedAlongside: T,
    observer: FetchedRecordsObserver<Record>)>)
    -> Void

private func makeFetchFunction<Record, T>(
    controller: FetchedRecordsController<Record>,
    fetchAlongside: @escaping (Database) throws -> T,
    willProcessTransaction: @escaping () -> Void,
    completion: @escaping FetchCompletionHandler<Record, T>
    ) -> (FetchedRecordsObserver<Record>) -> Void
{
    // Make sure we keep a weak reference to the fetched records controller,
    // so that the user can use unowned references in callbacks:
    //
    //      controller.trackChanges { [unowned self] ... }
    //
    // Should controller become strong at any point before callbacks are
    // called, such unowned reference would have an opportunity to crash.
    return { [weak controller] observer in
        // Return if observer has been invalidated, or if fetched records
        // controller has been deallocated
        guard observer.isValid,
            let request = controller?.request,
            let databaseWriter = controller?.databaseWriter
            else { return }
        
        willProcessTransaction()
        
        // Perform a concurrent read so that writer dispatch queue is released
        // as soon as possible.
        let future = databaseWriter.concurrentRead { db in
            try (fetchedItems: request.fetchAll(db),
                 fetchedAlongside: fetchAlongside(db))
        }
        
        // Dispatch processing immediately on observer.queue in order to
        // process fetched values in the same order as transactions:
        observer.queue.async { [weak observer] in
            // Return if observer has been deallocated or invalidated
            guard let observer = observer,
                observer.isValid
                else { return }
            
            do {
                // Wait for concurrent read to complete
                let values = try future.wait()
                
                completion(.success((
                    fetchedItems: values.fetchedItems,
                    fetchedAlongside: values.fetchedAlongside,
                    observer: observer)))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

private func makeFetchAndNotifyChangesFunction<Record, T>(
    controller: FetchedRecordsController<Record>,
    fetchAlongside: @escaping (Database) throws -> T,
    itemsAreIdentical: @escaping ItemComparator<Record>,
    willProcessTransaction: @escaping () -> Void,
    willChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> Void)?,
    onChange: ((FetchedRecordsController<Record>, Record, FetchedRecordChange) -> Void)?,
    didChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> Void)?,
    didProcessTransaction: @escaping () -> Void
    ) -> (FetchedRecordsObserver<Record>) -> Void
{
    // Make sure we keep a weak reference to the fetched records controller,
    // so that the user can use unowned references in callbacks:
    //
    //      controller.trackChanges { [unowned self] ... }
    //
    // Should controller become strong at any point before callbacks are
    // called, such unowned reference would have an opportunity to crash.
    return makeFetchFunction(
        controller: controller,
        fetchAlongside: fetchAlongside,
        willProcessTransaction: willProcessTransaction)
    { [weak controller] result in
        // Return if fetched records controller has been deallocated
        guard let callbackQueue = controller?.queue else { return }
        
        switch result {
        case let .failure(error):
            callbackQueue.async {
                // Now we can retain controller
                guard let strongController = controller else { return }
                strongController.errorHandler?(strongController, error)
                didProcessTransaction()
            }
            
        case let .success((fetchedItems: fetchedItems, fetchedAlongside: fetchedAlongside, observer: observer)):
            // Return if there is no change
            let changes: [ItemChange<Record>]
            if onChange != nil {
                // Compute table view changes
                changes = computeChanges(from: observer.items, to: fetchedItems, itemsAreIdentical: itemsAreIdentical)
                if changes.isEmpty { return }
            } else {
                // Don't compute changes: just look for a row difference:
                if identicalItemArrays(fetchedItems, observer.items) { return }
                changes = []
            }
            
            // Ready for next check
            observer.items = fetchedItems
            
            callbackQueue.async { [weak observer] in
                // Return if observer has been invalidated
                guard let strongObserver = observer else { return }
                guard strongObserver.isValid else { return }
                
                // Now we can retain controller
                guard let strongController = controller else { return }
                
                // Notify changes
                willChange?(strongController, fetchedAlongside)
                strongController.fetchedItems = fetchedItems
                if let onChange = onChange {
                    for change in changes {
                        onChange(strongController, change.record, change.fetchedRecordChange)
                    }
                }
                didChange?(strongController, fetchedAlongside)
                didProcessTransaction()
            }
        }
    }
}

private func computeChanges<Record>(
    from s: [Item<Record>],
    to t: [Item<Record>],
    itemsAreIdentical: ItemComparator<Record>)
    -> [ItemChange<Record>]
{
    let m = s.count
    let n = t.count
    
    // Fill first row and column of insertions and deletions.
    
    var d: [[[ItemChange<Record>]]] = Array(repeating: Array(repeating: [], count: n + 1), count: m + 1)
    
    var changes = [ItemChange<Record>]()
    for (row, item) in s.enumerated() {
        let deletion = ItemChange.deletion(item: item, indexPath: IndexPath(indexes: [0, row]))
        changes.append(deletion)
        d[row + 1][0] = changes
    }
    
    changes.removeAll()
    for (col, item) in t.enumerated() {
        let insertion = ItemChange.insertion(item: item, indexPath: IndexPath(indexes: [0, col]))
        changes.append(insertion)
        d[0][col + 1] = changes
    }
    
    if m == 0 || n == 0 {
        // Pure deletions or insertions
        return d[m][n]
    }
    
    // Fill body of matrix.
    for tx in 0..<n {
        for sx in 0..<m {
            if s[sx] == t[tx] {
                d[sx+1][tx+1] = d[sx][tx] // no operation
            } else {
                var del = d[sx][tx+1]     // a deletion
                var ins = d[sx+1][tx]     // an insertion
                var sub = d[sx][tx]       // a substitution
                
                // Record operation.
                let minimumCount = min(del.count, ins.count, sub.count)
                if del.count == minimumCount {
                    let deletion = ItemChange.deletion(item: s[sx], indexPath: IndexPath(indexes: [0, sx]))
                    del.append(deletion)
                    d[sx+1][tx+1] = del
                } else if ins.count == minimumCount {
                    let insertion = ItemChange.insertion(item: t[tx], indexPath: IndexPath(indexes: [0, tx]))
                    ins.append(insertion)
                    d[sx+1][tx+1] = ins
                } else {
                    let deletion = ItemChange.deletion(item: s[sx], indexPath: IndexPath(indexes: [0, sx]))
                    let insertion = ItemChange.insertion(item: t[tx], indexPath: IndexPath(indexes: [0, tx]))
                    sub.append(deletion)
                    sub.append(insertion)
                    d[sx+1][tx+1] = sub
                }
            }
        }
    }
    
    /// Returns an array where deletion/insertion pairs of the same element are replaced by `.move` change.
    func standardize(changes: [ItemChange<Record>], itemsAreIdentical: ItemComparator<Record>) -> [ItemChange<Record>] {
        
        /// Returns a potential .move or .update if *change* has a matching change in *changes*:
        /// If *change* is a deletion or an insertion, and there is a matching inverse
        /// insertion/deletion with the same value in *changes*, a corresponding .move or .update is returned.
        /// As a convenience, the index of the matched change is returned as well.
        func merge(
            change: ItemChange<Record>,
            in changes: [ItemChange<Record>],
            itemsAreIdentical: ItemComparator<Record>)
            -> (mergedChange: ItemChange<Record>, mergedIndex: Int)?
        {
            /// Returns the changes between two rows: a dictionary [key: oldValue]
            /// Precondition: both rows have the same columns
            func changedValues(from oldRow: Row, to newRow: Row) -> [String: DatabaseValue] {
                var changedValues: [String: DatabaseValue] = [:]
                for (column, newValue) in newRow {
                    let oldValue: DatabaseValue? = oldRow[column]
                    if newValue != oldValue {
                        changedValues[column] = oldValue
                    }
                }
                return changedValues
            }
            
            switch change {
            case let .insertion(newItem, newIndexPath):
                // Look for a matching deletion
                for (index, otherChange) in changes.enumerated() {
                    guard case let .deletion(oldItem, oldIndexPath) = otherChange else { continue }
                    guard itemsAreIdentical(oldItem, newItem) else { continue }
                    let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                    if oldIndexPath == newIndexPath {
                        return (
                            ItemChange.update(
                                item: newItem,
                                indexPath: oldIndexPath,
                                changes: rowChanges),
                            index)
                    } else {
                        return (
                            ItemChange.move(
                                item: newItem,
                                indexPath: oldIndexPath,
                                newIndexPath: newIndexPath,
                                changes: rowChanges),
                            index)
                    }
                }
                return nil
                
            case let .deletion(oldItem, oldIndexPath):
                // Look for a matching insertion
                for (index, otherChange) in changes.enumerated() {
                    guard case let .insertion(newItem, newIndexPath) = otherChange else { continue }
                    guard itemsAreIdentical(oldItem, newItem) else { continue }
                    let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                    if oldIndexPath == newIndexPath {
                        return (
                            ItemChange.update(
                                item: newItem,
                                indexPath: oldIndexPath,
                                changes: rowChanges),
                            index)
                    } else {
                        return (
                            ItemChange.move(
                                item: newItem,
                                indexPath: oldIndexPath,
                                newIndexPath: newIndexPath,
                                changes: rowChanges),
                            index)
                    }
                }
                return nil
                
            default:
                return nil
            }
        }
        
        // Updates must be pushed at the end
        var mergedChanges: [ItemChange<Record>] = []
        var updateChanges: [ItemChange<Record>] = []
        for change in changes {
            if let (mergedChange, mergedIndex)
                = merge(change: change, in: mergedChanges, itemsAreIdentical: itemsAreIdentical)
            {
                mergedChanges.remove(at: mergedIndex)
                switch mergedChange {
                case .update:
                    updateChanges.append(mergedChange)
                default:
                    mergedChanges.append(mergedChange)
                }
            } else {
                mergedChanges.append(change)
            }
        }
        return mergedChanges + updateChanges
    }
    
    return standardize(changes: d[m][n], itemsAreIdentical: itemsAreIdentical)
}

private func identicalItemArrays<Record>(_ lhs: [Item<Record>], _ rhs: [Item<Record>]) -> Bool {
    guard lhs.count == rhs.count else {
        return false
    }
    for (lhs, rhs) in zip(lhs, rhs) where lhs.row != rhs.row {
        return false
    }
    return true
}


// MARK: - UITableView Support

private typealias ItemComparator<Record: FetchableRecord> = (Item<Record>, Item<Record>) -> Bool
private typealias ItemComparatorFactory<Record: FetchableRecord> = (Database) throws -> ItemComparator<Record>

extension FetchedRecordsController {
    
    // MARK: - Accessing Records
    
    /// Returns the object at the given index path.
    ///
    /// - parameter indexPath: An index path in the fetched records.
    ///
    ///     If indexPath does not describe a valid index path in the fetched
    ///     records, a fatal error is raised.
    public func record(at indexPath: IndexPath) -> Record {
        guard let fetchedItems = fetchedItems else {
            // Programmer error
            fatalError("performFetch() has not been called.")
        }
        return fetchedItems[indexPath[1]].record
    }
    
    
    // MARK: - Querying Sections Information
    
    /// The sections for the fetched records.
    ///
    /// You typically use the sections array when implementing
    /// UITableViewDataSource methods, such as `numberOfSectionsInTableView`.
    ///
    /// The sections array is never empty, even when there are no fetched
    /// records. In this case, there is a single empty section.
    public var sections: [FetchedRecordsSectionInfo<Record>] {
        // We only support a single section so far.
        // We also return a single section when there are no fetched
        // records, just like NSFetchedResultsController.
        return [FetchedRecordsSectionInfo(controller: self)]
    }
}

extension FetchedRecordsController where Record: EncodableRecord {
    
    /// Returns the indexPath of a given record.
    ///
    /// - returns: The index path of *record* in the fetched records, or nil
    ///   if record could not be found.
    public func indexPath(for record: Record) -> IndexPath? {
        let item = Item<Record>(row: Row(record))
        guard
            let fetchedItems = fetchedItems,
            let index = fetchedItems.firstIndex(where: { itemsAreIdentical($0, item) })
            else {
                return nil
        }
        return IndexPath(indexes: [0, index])
    }
}

private enum ItemChange<T: FetchableRecord> {
    case insertion(item: Item<T>, indexPath: IndexPath)
    case deletion(item: Item<T>, indexPath: IndexPath)
    case move(item: Item<T>, indexPath: IndexPath, newIndexPath: IndexPath, changes: [String: DatabaseValue])
    case update(item: Item<T>, indexPath: IndexPath, changes: [String: DatabaseValue])
}

extension ItemChange {
    var record: T {
        switch self {
        case .insertion(item: let item, indexPath: _):
            return item.record
        case .deletion(item: let item, indexPath: _):
            return item.record
        case .move(item: let item, indexPath: _, newIndexPath: _, changes: _):
            return item.record
        case .update(item: let item, indexPath: _, changes: _):
            return item.record
        }
    }
    
    var fetchedRecordChange: FetchedRecordChange {
        switch self {
        case let .insertion(item: _, indexPath: indexPath):
            return .insertion(indexPath: indexPath)
        case let .deletion(item: _, indexPath: indexPath):
            return .deletion(indexPath: indexPath)
        case let .move(item: _, indexPath: indexPath, newIndexPath: newIndexPath, changes: changes):
            return .move(indexPath: indexPath, newIndexPath: newIndexPath, changes: changes)
        case let .update(item: _, indexPath: indexPath, changes: changes):
            return .update(indexPath: indexPath, changes: changes)
        }
    }
}

extension ItemChange: CustomStringConvertible {
    var description: String {
        switch self {
        case let .insertion(item, indexPath):
            return "Insert \(item) at \(indexPath)"
            
        case let .deletion(item, indexPath):
            return "Delete \(item) from \(indexPath)"
            
        case let .move(item, indexPath, newIndexPath, changes: changes):
            return "Move \(item) from \(indexPath) to \(newIndexPath) with changes: \(changes)"
            
        case let .update(item, indexPath, changes):
            return "Update \(item) at \(indexPath) with changes: \(changes)"
        }
    }
}

/// A record change, given by a FetchedRecordsController to its change callback.
///
/// The move and update events hold a *changes* dictionary, whose keys are
/// column names, and values the old values that have been changed.
public enum FetchedRecordChange {
    
    /// An insertion event, at given indexPath.
    case insertion(indexPath: IndexPath)
    
    /// A deletion event, at given indexPath.
    case deletion(indexPath: IndexPath)
    
    /// A move event, from indexPath to newIndexPath. The *changes* are a
    /// dictionary whose keys are column names, and values the old values that
    /// have been changed.
    case move(indexPath: IndexPath, newIndexPath: IndexPath, changes: [String: DatabaseValue])
    
    /// An update event, at given indexPath. The *changes* are a dictionary
    /// whose keys are column names, and values the old values that have
    /// been changed.
    case update(indexPath: IndexPath, changes: [String: DatabaseValue])
}

extension FetchedRecordChange: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .insertion(indexPath):
            return "Insertion at \(indexPath)"
            
        case let .deletion(indexPath):
            return "Deletion from \(indexPath)"
            
        case let .move(indexPath, newIndexPath, changes: changes):
            return "Move from \(indexPath) to \(newIndexPath) with changes: \(changes)"
            
        case let .update(indexPath, changes):
            return "Update at \(indexPath) with changes: \(changes)"
        }
    }
}

/// A section given by a FetchedRecordsController.
public struct FetchedRecordsSectionInfo<Record: FetchableRecord> {
    fileprivate let controller: FetchedRecordsController<Record>
    
    /// The number of records (rows) in the section.
    public var numberOfRecords: Int {
        guard let items = controller.fetchedItems else {
            // Programmer error
            fatalError("the performFetch() method must be called before accessing section contents")
        }
        return items.count
    }
    
    /// The array of records in the section.
    public var records: [Record] {
        guard let items = controller.fetchedItems else {
            // Programmer error
            fatalError("the performFetch() method must be called before accessing section contents")
        }
        return items.map { $0.record }
    }
}


// MARK: - Item

private final class Item<T: FetchableRecord>: FetchableRecord, Equatable {
    let row: Row
    
    // Records are lazily loaded
    lazy var record = T(row: self.row)
    
    init(row: Row) {
        self.row = row.copy()
    }
    
    static func ==<T> (lhs: Item<T>, rhs: Item<T>) -> Bool {
        return lhs.row == rhs.row
    }
}
