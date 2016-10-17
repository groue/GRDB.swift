/// You use FetchedRecordsController to track changes in the results of an
/// SQLite request.
///
/// On iOS, FetchedRecordsController can feed a UITableView, and animate rows
/// when the results of the request change.
///
/// See https://github.com/groue/GRDB.swift#fetchedrecordscontroller for
/// more information.
public final class FetchedRecordsController<Record: RowConvertible> {
    
    // MARK: - Initialization
    
    /// Creates a fetched records controller initialized from a SQL query and
    /// its eventual arguments.
    ///
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         sql: "SELECT * FROM wines WHERE color = ? ORDER BY name",
    ///         arguments: [Color.red],
    ///         isSameRecord: { (wine1, wine2) in wine1.id == wine2.id })
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    ///     - queue: Optional dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller delegate will be notified of
    ///         record changes in this queue. The controller itself must be used
    ///         from this queue.
    ///
    ///         This dispatch queue must be serial.
    ///
    ///     - isSameRecord: Optional function that compares two records.
    ///
    ///         This function should return true if the two records have the
    ///         same identity. For example, they have the same id.
    public convenience init(_ databaseWriter: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, queue: DispatchQueue = .main, isSameRecord: ((Record, Record) -> Bool)? = nil) {
        self.init(databaseWriter, request: SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter), queue: queue, isSameRecord: isSameRecord)
    }
    
    /// Creates a fetched records controller initialized from a fetch request
    /// from the [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
    ///
    ///     let request = Wine.order(Column("name"))
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         request: request,
    ///         isSameRecord: { (wine1, wine2) in wine1.id == wine2.id })
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - request: A fetch request.
    ///     - queue: Optional dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller delegate will be notified of
    ///         record changes in this queue. The controller itself must be used
    ///         from this queue.
    ///
    ///         This dispatch queue must be serial.
    ///
    ///     - isSameRecord: Optional function that compares two records.
    ///
    ///         This function should return true if the two records have the
    ///         same identity. For example, they have the same id.
    public convenience init(_ databaseWriter: DatabaseWriter, request: FetchRequest, queue: DispatchQueue = .main, isSameRecord: ((Record, Record) -> Bool)? = nil) {
        if let isSameRecord = isSameRecord {
            self.init(databaseWriter, request: request, queue: queue, isSameItemFactory: { _ in { isSameRecord($0.record, $1.record) } })
        } else {
            self.init(databaseWriter, request: request, queue: queue, isSameItemFactory: { _ in { _ in false } })
        }
    }
    
    fileprivate init(_ databaseWriter: DatabaseWriter, request: FetchRequest, queue: DispatchQueue, isSameItemFactory: @escaping (Database) -> (Item<Record>, Item<Record>) -> Bool) {
        self.request = request
        self.databaseWriter = databaseWriter
        self.isSameItem = { _ in return false }
        self.isSameItemFactory = isSameItemFactory
        self.queue = queue
    }
    
    /// Executes the controller's fetch request.
    ///
    /// After executing this method, you can access the the fetched objects with
    /// the property fetchedRecords.
    public func performFetch() {
        // If some changes are currently processed, make sure they are
        // discarded. But preserve eventual changes processing for future
        // changes.
        let checkForChanges = observer?.checkForChanges
        observer?.invalidate()
        observer = nil
        
        // Fetch items on the writing dispatch queue, so that the transaction
        // observer is added on the same serialized queue as transaction
        // callbacks.
        databaseWriter.writeForIssue117 { db in
            let (statement, adapter) = try! request.prepare(db)
            let initialItems = Item<Record>.fetchAll(statement, adapter: adapter)
            fetchedItems = initialItems
            isSameItem = isSameItemFactory(db)
            
            if let checkForChanges = checkForChanges {
                let observer = FetchedRecordsObserver(readInfo: statement.readInfo, checkForChanges: checkForChanges)
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
    
    /// Updates the fetch request, and notifies the delegate of changes in the
    /// fetched records if delegate is not nil, and performFetch() has been
    /// called.
    public func setRequest(_ request: FetchRequest) {
        // We don't provide a setter for the request property because we need a
        // non-optional request.
        self.request = request
    }
    
    /// Updates the fetch request, and notifies the delegate of changes in the
    /// fetched records if delegate is not nil, and performFetch() has been
    /// called.
    public func setRequest(sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) {
        setRequest(SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    #if os(iOS)
    /// Registers changes notification callbacks (iOS only).
    ///
    /// - parameters:
    ///     - recordsWillChange: Invoked before records are updated.
    ///     - tableViewEvent: Invoked for each record that has been added,
    ///       removed, moved, or updated.
    ///     - recordsDidChange: Invoked after records have been updated.
    public func trackChanges(
        recordsWillChange: ((FetchedRecordsController<Record>) -> ())? = nil,
        tableViewEvent: ((FetchedRecordsController<Record>, Record, TableViewEvent) -> ())? = nil,
        recordsDidChange: ((FetchedRecordsController<Record>) -> ())? = nil)
    {
        let recordsWillChangeWithVoidAlongside: ((FetchedRecordsController<Record>, Void) -> ())?
        if let recordsWillChange = recordsWillChange {
            recordsWillChangeWithVoidAlongside = { (controller, _) in
                recordsWillChange(controller)
            }
        } else {
            recordsWillChangeWithVoidAlongside = nil
        }
        
        let recordsDidChangeWithVoidAlongside: ((FetchedRecordsController<Record>, Void) -> ())?
        if let recordsDidChange = recordsDidChange {
            recordsDidChangeWithVoidAlongside = { (controller, _) in recordsDidChange(controller) }
        } else {
            recordsDidChangeWithVoidAlongside = nil
        }
        
        trackChanges(
            fetchAlongside: { _ in },
            recordsWillChange: recordsWillChangeWithVoidAlongside,
            tableViewEvent: tableViewEvent,
            recordsDidChange: recordsDidChangeWithVoidAlongside)
    }
    #else
    /// Registers changes notification callbacks.
    ///
    /// - parameters:
    ///     - recordsWillChange: Invoked before records are updated.
    ///     - recordsDidChange: Invoked after records have been updated.
    public func trackChanges(
        recordsWillChange: ((FetchedRecordsController<Record>) -> ())? = nil,
        recordsDidChange: ((FetchedRecordsController<Record>) -> ())? = nil)
    {
        let recordsWillChangeWithVoidAlongside: ((FetchedRecordsController<Record>, Void) -> ())?
        if let recordsWillChange = recordsWillChange {
            recordsWillChangeWithVoidAlongside = { (controller, _) in recordsWillChange(controller) }
        } else {
            recordsWillChangeWithVoidAlongside = nil
        }
        
        let recordsDidChangeWithVoidAlongside: ((FetchedRecordsController<Record>, Void) -> ())?
        if let recordsDidChange = recordsDidChange {
            recordsDidChangeWithVoidAlongside = { (controller, _) in recordsDidChange(controller) }
        } else {
            recordsDidChangeWithVoidAlongside = nil
        }
        
        trackChanges(
            fetchAlongside: { _ in },
            recordsWillChange: recordsWillChangeWithVoidAlongside,
            recordsDidChange: recordsDidChangeWithVoidAlongside)
    }
    #endif
    
    #if os(iOS)
    /// Registers changes notification callbacks (iOS only).
    ///
    /// - parameters:
    ///     - fetchAlongside: The value returned from this closure is given to
    ///       recordsWillChange and recordsDidChange callbacks, as their
    ///       `fetchedAlongside` argument. The closure is guaranteed to see the
    ///       database in the state it has just after eventual changes to the
    ///       fetched records have been performed. Use it in order to fetch
    ///       values that must be consistent with the fetched records.
    ///     - recordsWillChange: Invoked before records are updated.
    ///     - tableViewEvent: Invoked for each record that has been added,
    ///       removed, moved, or updated.
    ///     - recordsDidChange: Invoked after records have been updated.
    public func trackChanges<T>(
        fetchAlongside: @escaping (Database) -> T,
        recordsWillChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> ())? = nil,
        tableViewEvent: ((FetchedRecordsController<Record>, Record, TableViewEvent) -> ())? = nil,
        recordsDidChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> ())? = nil)
    {
        // If some changes are currently processed, make sure they are
        // discarded because they would trigger previously set callbacks.
        observer?.invalidate()
        observer = nil
        
        guard (recordsWillChange != nil) || (tableViewEvent != nil) || (recordsDidChange != nil) else {
            // Stop tracking
            return
        }
        
        let initialItems = fetchedItems
        databaseWriter.writeForIssue117 { db in
            let fetchedChangesController = FetchedChangesController(
                controller: self,
                isSameItem: isSameItemFactory(db),
                fetchAlongside: fetchAlongside,
                recordsWillChange: recordsWillChange,
                tableViewEvent: tableViewEvent,
                recordsDidChange: recordsDidChange)
            
            // This closure erases the generic type T of data fetched alongside.
            let checkForChanges = { (observer: FetchedRecordsObserver<Record>) -> () in
                fetchedChangesController.checkForChanges(observer)
            }

            let (statement, _) = try! request.prepare(db)
            let observer = FetchedRecordsObserver(readInfo: statement.readInfo, checkForChanges: checkForChanges)
            self.observer = observer
            if let initialItems = initialItems {
                observer.items = initialItems
                db.add(transactionObserver: observer)
                observer.performChangesChecking()
            }
        }
    }
    #else
    /// Registers changes notification callbacks.
    ///
    /// - parameters:
    ///     - fetchAlongside: The value returned from this closure is given to
    ///       recordsWillChange and recordsDidChange callbacks, as their
    ///       `fetchedAlongside` argument. The closure is guaranteed to see the
    ///       database in the state it has just after eventual changes to the
    ///       fetched records have been performed. Use it in order to fetch
    ///       values that must be consistent with the fetched records.
    ///     - recordsWillChange: Invoked before records are updated.
    ///     - recordsDidChange: Invoked after records have been updated.
    public func trackChanges<T>(
        fetchAlongside: @escaping (Database) -> T,
        recordsWillChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> ())? = nil,
        recordsDidChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> ())? = nil)
    {
        // If some changes are currently processed, make sure they are
        // discarded because they would trigger previously set callbacks.
        observer?.invalidate()
        observer = nil
        
        guard (recordsWillChange != nil) || (recordsDidChange != nil) else {
            // Stop tracking
            return
        }
        
        let initialItems = fetchedItems
        databaseWriter.writeForIssue117 { db in
            let fetchedChangesController = FetchedChangesController(
                controller: self,
                fetchAlongside: fetchAlongside,
                recordsWillChange: recordsWillChange,
                recordsDidChange: recordsDidChange)
            
            // This closure erases the generic type T of data fetched alongside.
            let checkForChanges = { (observer: FetchedRecordsObserver<Record>) -> () in
                fetchedChangesController.checkForChanges(observer)
            }

            let (statement, _) = try! request.prepare(db)
            let observer = FetchedRecordsObserver(readInfo: statement.readInfo, checkForChanges: checkForChanges)
            self.observer = observer
            if let initialItems = initialItems {
                observer.items = initialItems
                db.add(transactionObserver: observer)
                observer.performChangesChecking()
            }
        }
    }
    #endif
    
    
    // MARK: - Accessing Records
    
    /// The fetched records.
    ///
    /// The value of this property is nil if performFetch() hasn't been called.
    ///
    /// The records reflect the state of the database after the initial
    /// call to performFetch, and after each database transaction that affects
    /// the results of the fetch request.
    public var fetchedRecords: [Record]? {
        guard let fetchedItems = fetchedItems else {
            return nil
        }
        return fetchedItems.map { $0.record }
    }
    
    
    // MARK: - Not public
    
    
    // The items
    fileprivate var fetchedItems: [Item<Record>]?
    
    // The record comparator
    fileprivate var isSameItem: (Item<Record>, Item<Record>) -> Bool
    
    // The record comparator builder. It helps us supporting types that adopt
    // MutablePersistable: we just have to wait for a database connection, in
    // performFetch(), to get primary key information and generate a primary
    // key comparator.
    private let isSameItemFactory: (Database) -> (Item<Record>, Item<Record>) -> Bool
    
    /// The request
    fileprivate var request: FetchRequest {
        didSet {
            guard let observer = observer else { return }
            
            // If some changes are currently processed, make sure they are
            // discarded. But preserve eventual changes processing.
            let checkForChanges = observer.checkForChanges
            observer.invalidate()
            self.observer = nil
            
            // Replace observer so that it tracks a new set of columns,
            // and notify eventual changes
            let initialItems = fetchedItems
            databaseWriter.writeForIssue117 { db in
                let (statement, _) = try! request.prepare(db)
                let observer = FetchedRecordsObserver(readInfo: statement.readInfo, checkForChanges: checkForChanges)
                self.observer = observer
                observer.items = initialItems
                db.add(transactionObserver: observer)
                observer.performChangesChecking()
            }
        }
    }
    
    // The eventual current database observer
    private var observer: FetchedRecordsObserver<Record>?
}


extension FetchedRecordsController where Record: TableMapping {
    
    // MARK: - Initialization
    
    /// Creates a fetched records controller initialized from a SQL query and
    /// its eventual arguments.
    ///
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         sql: "SELECT * FROM wines WHERE color = ? ORDER BY name",
    ///         arguments: [Color.red],
    ///         compareRecordsByPrimaryKey: true)
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    ///     - queue: Optional dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller delegate will be notified of
    ///         record changes in this queue. The controller itself must be used
    ///         from this queue.
    ///
    ///         This dispatch queue must be serial.
    ///
    ///     - compareRecordsByPrimaryKey: A boolean that tells if two records
    ///         share the same identity if they share the same primay key.
    public convenience init(_ databaseWriter: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, queue: DispatchQueue = .main, compareRecordsByPrimaryKey: Bool) {
        self.init(databaseWriter, request: SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter), queue: queue, compareRecordsByPrimaryKey: compareRecordsByPrimaryKey)
    }
    
    /// Creates a fetched records controller initialized from a fetch request.
    /// from the [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
    ///
    ///     let request = Wine.order(Column("name"))
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         request: request,
    ///         compareRecordsByPrimaryKey: true)
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - request: A fetch request.
    ///     - queue: Optional dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller delegate will be notified of
    ///         record changes in this queue. The controller itself must be used
    ///         from this queue.
    ///
    ///         This dispatch queue must be serial.
    ///
    ///     - compareRecordsByPrimaryKey: A boolean that tells if two records
    ///         share the same identity if they share the same primay key.
    public convenience init(_ databaseWriter: DatabaseWriter, request: FetchRequest, queue: DispatchQueue = .main, compareRecordsByPrimaryKey: Bool) {
        if compareRecordsByPrimaryKey {
            self.init(databaseWriter, request: request, queue: queue, isSameItemFactory: { db in
                let comparator = try! Record.primaryKeyComparator(db)
                return { comparator($0.row, $1.row) }
            })
        } else {
            self.init(databaseWriter, request: request, queue: queue, isSameItemFactory: { _ in { _ in false } })
        }
    }
}


// MARK: - FetchedChangesController

/// FetchedChangesController computes and notifies changes
private class FetchedChangesController<Record: RowConvertible, T> {
    // THIS WEAK REFERENCE MUST NEVER BECOME STRONG if we want to allow user
    // callbacks to avoid retain cycle with unowned references:
    //
    //      controller.trackChanges { [unowned self] ... }
    //
    // Should controller become strong at any point before callbacks are
    // called, such unowned reference would have an opportunity to crash.
    weak var controller: FetchedRecordsController<Record>?
    let fetchAlongside: (Database) -> T
    let recordsWillChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> ())?
    let recordsDidChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> ())?

    #if os(iOS)
    let isSameItem: (Item<Record>, Item<Record>) -> Bool
    var tableViewEvent: ((FetchedRecordsController<Record>, Record, TableViewEvent) -> ())?
    
    init(
        controller: FetchedRecordsController<Record>,
        isSameItem: @escaping (Item<Record>, Item<Record>) -> Bool,
        fetchAlongside: @escaping (Database) -> T,
        recordsWillChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> ())?,
        tableViewEvent: ((FetchedRecordsController<Record>, Record, TableViewEvent) -> ())?,
        recordsDidChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> ())?)
    {
        self.controller = controller
        self.isSameItem = isSameItem
        self.fetchAlongside = fetchAlongside
        self.recordsWillChange = recordsWillChange
        self.tableViewEvent = tableViewEvent
        self.recordsDidChange = recordsDidChange
    }
    #else
    init(
        controller: FetchedRecordsController<Record>,
        fetchAlongside: @escaping (Database) -> T,
        recordsWillChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> ())?,
        recordsDidChange: ((FetchedRecordsController<Record>, _ fetchedAlongside: T) -> ())?)
    {
        self.controller = controller
        self.fetchAlongside = fetchAlongside
        self.recordsWillChange = recordsWillChange
        self.recordsDidChange = recordsDidChange
    }
    #endif
    
    // Precondition: this method must be called from the database writer's
    // serialized dispatch queue.
    func checkForChanges(_ observer: FetchedRecordsObserver<Record>) {
        // Observer invalidated?
        guard observer.isValid else { return }
        
        // Controller alive?
        guard let request = controller?.request, let databaseWriter = controller?.databaseWriter else { return }
        
        // Fetch items.
        //
        // This method is called from the database writer's serialized queue, so
        // that we can fetch items before other writes have the opportunity to
        // modify the database.
        //
        // However, we don't have to block the writer queue for all the duration
        // of the fetch. We just need to block the writer queue until we can
        // perform a fetch in isolation. This is the role of the readFromWrite
        // method (see below).
        //
        // However, our fetch will last for an unknown duration. And since we
        // release the writer queue early, the next database modification will
        // triggers this callback while our fetch is, maybe, still running. This
        // next callback will also perform its own fetch, that will maybe end
        // before our own fetch.
        //
        // We have to make sure that our fetch is processed *before* the next
        // fetch: let's immediately dispatch the processing task in our
        // serialized FIFO queue, but have it wait for our fetch to complete,
        // with a semaphore:
        let semaphore = DispatchSemaphore(value: 0)
        var fetchedItems: [Item<Record>]! = nil
        var fetchedAlongside: T! = nil
        
        databaseWriter.readFromWrite { db in
            fetchedItems = Item<Record>.fetchAll(db, request)
            fetchedAlongside = self.fetchAlongside(db)
            
            // Fetch is complete:
            semaphore.signal()
        }
        
        
        // Process the fetched items
        
        observer.queue.async { [weak observer] in
            // Wait for the fetch to complete:
            _ = semaphore.wait(timeout: .distantFuture)
            assert(fetchedItems != nil)
            assert(fetchedAlongside != nil)
            
            // Observer invalidated?
            guard let strongObserver = observer else { return }
            guard strongObserver.isValid else { return }
            
            // Controller alive?
            guard let controllerQueue = self.controller?.queue else { return }

            // Changes?
            #if os(iOS)
                let tableViewChanges: [TableViewChange<Record>]?
                if self.tableViewEvent != nil {
                    // Compute table view changes
                    let changes = self.computeTableViewChanges(from: strongObserver.items, to: fetchedItems)
                    guard !changes.isEmpty else {
                        return
                    }
                    tableViewChanges = changes
                } else {
                    // Look for a row difference
                    guard fetchedItems.count != strongObserver.items.count || zip(fetchedItems, strongObserver.items).contains(where: { (fetchedItem, item) in fetchedItem.row != item.row }) else {
                        return
                    }
                    tableViewChanges = nil
                }
            #else
                // Look for a row difference
                guard fetchedItems.count != strongObserver.items.count || zip(fetchedItems, strongObserver.items).contains(where: { (fetchedItem, item) in fetchedItem.row != item.row }) else {
                    return
                }
            #endif
            
            // Ready for next check
            strongObserver.items = fetchedItems
            
            controllerQueue.async {
                // Observer invalidated?
                guard let strongObserver = observer else { return }
                guard strongObserver.isValid else { return }
                
                // Now we can retain controller.
                guard let controller = self.controller else { return }
                
                if let recordsWillChange = self.recordsWillChange {
                    recordsWillChange(controller, fetchedAlongside)
                }
                
                controller.fetchedItems = fetchedItems
                
                #if os(iOS)
                    if let tableViewEvent = self.tableViewEvent, let tableViewChanges = tableViewChanges {
                        for change in tableViewChanges {
                            tableViewEvent(controller, change.record, change.event)
                        }
                    }
                #endif
                
                if let recordsDidChange = self.recordsDidChange {
                    recordsDidChange(controller, fetchedAlongside)
                }
            }
        }
    }
}


// MARK: - FetchedRecordsObserver

/// FetchedRecordsController adopts TransactionObserverType so that it can
/// monitor changes to its fetched records.
private final class FetchedRecordsObserver<Record: RowConvertible> : TransactionObserver {
    var isValid: Bool
    var needsComputeChanges: Bool
    var items: [Item<Record>]!  // ought to be not nil when observer has started tracking transactions
    let queue: DispatchQueue // protects items
    let readInfo: SelectStatement.ReadInfo
    var checkForChanges: (FetchedRecordsObserver<Record>) -> ()
    
    init(readInfo: SelectStatement.ReadInfo, checkForChanges: @escaping (FetchedRecordsObserver<Record>) -> ()) {
        self.isValid = true
        self.items = nil
        self.needsComputeChanges = false
        self.queue = DispatchQueue(label: "GRDB.FetchedRecordsObserver")
        self.readInfo = readInfo
        self.checkForChanges = checkForChanges
    }
    
    func invalidate() {
        isValid = false
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        switch eventKind {
        case .delete(let tableName):
            return readInfo[tableName] != nil
        case .insert(let tableName):
            return readInfo[tableName] != nil
        case .update(let tableName, let updatedColumnNames):
            if let observedColumnNames = readInfo[tableName] {
                return !updatedColumnNames.isDisjoint(with: observedColumnNames)
            } else {
                return false
            }
        }
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    /// Part of the TransactionObserverType protocol
    func databaseWillChange(with event: DatabasePreUpdateEvent) { }
    #endif
    
    /// Part of the TransactionObserverType protocol
    func databaseDidChange(with event: DatabaseEvent) {
        needsComputeChanges = true
    }
    
    /// Part of the TransactionObserverType protocol
    func databaseWillCommit() throws { }
    
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
        
        performChangesChecking()
    }
    
    // Precondition: this method must be called from the database writer's
    // serialized dispatch queue.
    func performChangesChecking() {
        checkForChanges(self)
    }
}

private func databaseEventFilter(readInfo: SelectStatement.ReadInfo) -> (DatabaseEventKind) -> Bool {
    return { kind in
        switch kind {
        case .delete(let tableName):
            return readInfo[tableName] != nil
        case .insert(let tableName):
            return readInfo[tableName] != nil
        case .update(let tableName, let updatedColumnNames):
            if let observedColumnNames = readInfo[tableName] {
                return !updatedColumnNames.isDisjoint(with: observedColumnNames)
            } else {
                return false
            }
        }
    }
}


// MARK: UITableView Support

#if os(iOS)
    extension FetchedRecordsController {
        
        // MARK: - Accessing Records
        
        /// Returns the object at the given index path (iOS only).
        ///
        /// - parameter indexPath: An index path in the fetched records.
        ///
        ///     If indexPath does not describe a valid index path in the fetched
        ///     records, a fatal error is raised.
        public func record(at indexPath: IndexPath) -> Record {
            guard let fetchedItems = fetchedItems else {
                fatalError("performFetch() has not been called.")
            }
            return fetchedItems[indexPath.row].record
        }
        
        
        // MARK: - Querying Sections Information
        
        /// The sections for the fetched records (iOS only).
        ///
        /// You typically use the sections array when implementing
        /// UITableViewDataSource methods, such as `numberOfSectionsInTableView`.
        public var sections: [FetchedRecordsSectionInfo<Record>] {
            // We only support a single section
            return [FetchedRecordsSectionInfo(controller: self)]
        }
    }
    
    extension FetchedRecordsController where Record: MutablePersistable {
        
        /// Returns the indexPath of a given record (iOS only).
        ///
        /// - returns: The index path of *record* in the fetched records, or nil
        ///   if record could not be found.
        public func indexPath(for record: Record) -> IndexPath? {
            let item = Item<Record>(row: Row(record.persistentDictionary))
            guard let fetchedItems = fetchedItems, let index = fetchedItems.index(where: { isSameItem($0, item) }) else {
                return nil
            }
            return IndexPath(row: index, section: 0)
        }
    }
    
    extension FetchedChangesController {
        
        fileprivate func computeTableViewChanges(from s: [Item<Record>], to t: [Item<Record>]) -> [TableViewChange<Record>] {
            let m = s.count
            let n = t.count
            
            // Fill first row and column of insertions and deletions.
            
            var d: [[[TableViewChange<Record>]]] = Array(repeating: Array(repeating: [], count: n + 1), count: m + 1)
            
            var changes = [TableViewChange<Record>]()
            for (row, item) in s.enumerated() {
                let deletion = TableViewChange.deletion(item: item, indexPath: IndexPath(row: row, section: 0))
                changes.append(deletion)
                d[row + 1][0] = changes
            }
            
            changes.removeAll()
            for (col, item) in t.enumerated() {
                let insertion = TableViewChange.insertion(item: item, indexPath: IndexPath(row: col, section: 0))
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
                            let deletion = TableViewChange.deletion(item: s[sx], indexPath: IndexPath(row: sx, section: 0))
                            del.append(deletion)
                            d[sx+1][tx+1] = del
                        } else if ins.count == minimumCount {
                            let insertion = TableViewChange.insertion(item: t[tx], indexPath: IndexPath(row: tx, section: 0))
                            ins.append(insertion)
                            d[sx+1][tx+1] = ins
                        } else {
                            let deletion = TableViewChange.deletion(item: s[sx], indexPath: IndexPath(row: sx, section: 0))
                            let insertion = TableViewChange.insertion(item: t[tx], indexPath: IndexPath(row: tx, section: 0))
                            sub.append(deletion)
                            sub.append(insertion)
                            d[sx+1][tx+1] = sub
                        }
                    }
                }
            }
            
            /// Returns an array where deletion/insertion pairs of the same element are replaced by `.move` change.
            func standardize(changes: [TableViewChange<Record>]) -> [TableViewChange<Record>] {
                
                /// Returns a potential .move or .update if *change* has a matching change in *changes*:
                /// If *change* is a deletion or an insertion, and there is a matching inverse
                /// insertion/deletion with the same value in *changes*, a corresponding .move or .update is returned.
                /// As a convenience, the index of the matched change is returned as well.
                func merge(change: TableViewChange<Record>, in changes: [TableViewChange<Record>]) -> (mergedChange: TableViewChange<Record>, mergedIndex: Int)? {
                    
                    /// Returns the changes between two rows: a dictionary [key: oldValue]
                    /// Precondition: both rows have the same columns
                    func changedValues(from oldRow: Row, to newRow: Row) -> [String: DatabaseValue] {
                        var changedValues: [String: DatabaseValue] = [:]
                        for (column, newValue) in newRow {
                            let oldValue: DatabaseValue? = oldRow.value(named: column)
                            if newValue != oldValue {
                                changedValues[column] = oldValue
                            }
                        }
                        return changedValues
                    }
                    
                    switch change {
                    case .insertion(let newItem, let newIndexPath):
                        // Look for a matching deletion
                        for (index, otherChange) in changes.enumerated() {
                            guard case .deletion(let oldItem, let oldIndexPath) = otherChange else { continue }
                            guard isSameItem(oldItem, newItem) else { continue }
                            let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                            if oldIndexPath == newIndexPath {
                                return (TableViewChange.update(item: newItem, indexPath: oldIndexPath, changes: rowChanges), index)
                            } else {
                                return (TableViewChange.move(item: newItem, indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges), index)
                            }
                        }
                        return nil
                        
                    case .deletion(let oldItem, let oldIndexPath):
                        // Look for a matching insertion
                        for (index, otherChange) in changes.enumerated() {
                            guard case .insertion(let newItem, let newIndexPath) = otherChange else { continue }
                            guard isSameItem(oldItem, newItem) else { continue }
                            let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                            if oldIndexPath == newIndexPath {
                                return (TableViewChange.update(item: newItem, indexPath: oldIndexPath, changes: rowChanges), index)
                            } else {
                                return (TableViewChange.move(item: newItem, indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges), index)
                            }
                        }
                        return nil
                        
                    default:
                        return nil
                    }
                }
                
                // Updates must be pushed at the end
                var mergedChanges: [TableViewChange<Record>] = []
                var updateChanges: [TableViewChange<Record>] = []
                for change in changes {
                    if let (mergedChange, mergedIndex) = merge(change: change, in: mergedChanges) {
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
            
            return standardize(changes: d[m][n])
        }
    }
    
    private enum TableViewChange<T: RowConvertible> {
        case insertion(item: Item<T>, indexPath: IndexPath)
        case deletion(item: Item<T>, indexPath: IndexPath)
        case move(item: Item<T>, indexPath: IndexPath, newIndexPath: IndexPath, changes: [String: DatabaseValue])
        case update(item: Item<T>, indexPath: IndexPath, changes: [String: DatabaseValue])
    }
    
    extension TableViewChange {
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
        
        var event: TableViewEvent {
            switch self {
            case .insertion(item: _, indexPath: let indexPath):
                return .insertion(indexPath: indexPath)
            case .deletion(item: _, indexPath: let indexPath):
                return .deletion(indexPath: indexPath)
            case .move(item: _, indexPath: let indexPath, newIndexPath: let newIndexPath, changes: let changes):
                return .move(indexPath: indexPath, newIndexPath: newIndexPath, changes: changes)
            case .update(item: _, indexPath: let indexPath, changes: let changes):
                return .update(indexPath: indexPath, changes: changes)
            }
        }
    }
    
    extension TableViewChange: CustomStringConvertible {
        var description: String {
            switch self {
            case .insertion(let item, let indexPath):
                return "Insert \(item) at \(indexPath)"
                
            case .deletion(let item, let indexPath):
                return "Delete \(item) from \(indexPath)"
                
            case .move(let item, let indexPath, let newIndexPath, changes: let changes):
                return "Move \(item) from \(indexPath) to \(newIndexPath) with changes: \(changes)"
                
            case .update(let item, let indexPath, let changes):
                return "Update \(item) at \(indexPath) with changes: \(changes)"
            }
        }
    }
    
    /// A change event given by a FetchedRecordsController to its delegate.
    ///
    /// The move and update events hold a *changes* dictionary. Its keys are column
    /// names, and values the old values that have been changed.
    public enum TableViewEvent {
        
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
    
    extension TableViewEvent: CustomStringConvertible {
        
        /// A textual representation of `self`.
        public var description: String {
            switch self {
            case .insertion(let indexPath):
                return "Insertion at \(indexPath)"
                
            case .deletion(let indexPath):
                return "Deletion from \(indexPath)"
                
            case .move(let indexPath, let newIndexPath, changes: let changes):
                return "Move from \(indexPath) to \(newIndexPath) with changes: \(changes)"
                
            case .update(let indexPath, let changes):
                return "Update at \(indexPath) with changes: \(changes)"
            }
        }
    }
    
    /// A section given by a FetchedRecordsController.
    public struct FetchedRecordsSectionInfo<Record: RowConvertible> {
        fileprivate let controller: FetchedRecordsController<Record>
        
        /// The number of records (rows) in the section.
        public var numberOfRecords: Int {
            // We only support a single section
            return controller.fetchedItems!.count
        }
        
        /// The array of records in the section.
        public var records: [Record] {
            // We only support a single section
            return controller.fetchedItems!.map { $0.record }
        }
    }
#endif


// MARK: - Item

private final class Item<T: RowConvertible> : RowConvertible, Equatable {
    let row: Row
    
    // Records are lazily loaded
    lazy var record: T = {
        var record = T(row: self.row)
        record.awakeFromFetch(row: self.row)
        return record
    }()
    
    init(row: Row) {
        self.row = row.copy()
    }
}

private func ==<T>(lhs: Item<T>, rhs: Item<T>) -> Bool {
    return lhs.row == rhs.row
}


// MARK: - Utils

extension TableMapping {
    /// Returns a function that returns the primary key of a row.
    ///
    /// If the table has no primary key, and selectsRowID is true, use the
    /// "rowid" key.
    ///
    ///     dbQueue.inDatabase { db in
    ///         let primaryKey = Person.primaryKeyFunction(db)
    ///         let row = Row.fetchOne(db, "SELECT * FROM persons")!
    ///         primaryKey(row) // ["id": 1]
    ///     }
    ///
    /// - throws: A DatabaseError if table does not exist.
    static func primaryKeyFunction(_ db: Database) throws -> (Row) -> [String: DatabaseValue] {
        let columns: [String]
        if let primaryKey = try db.primaryKey(databaseTableName) {
            columns = primaryKey.columns
        } else if selectsRowID {
            columns = ["rowid"]
        } else {
            columns = []
        }
        return { row in
            return Dictionary<String, DatabaseValue>(keys: columns) { row.value(named: $0) }
        }
    }
    
    /// Returns a function that returns true if and only if two rows have the
    /// same primary key and both primary keys contain at least one non-null
    /// value.
    ///
    ///     dbQueue.inDatabase { db in
    ///         let comparator = Person.primaryKeyComparator(db)
    ///         let row0 = Row(["id": nil, "name": "Unsaved"])
    ///         let row1 = Row(["id": 1, "name": "Arthur"])
    ///         let row2 = Row(["id": 1, "name": "Arthur"])
    ///         let row3 = Row(["id": 2, "name": "Barbara"])
    ///         comparator(row0, row0) // false
    ///         comparator(row1, row2) // true
    ///         comparator(row1, row3) // false
    ///     }
    ///
    /// - throws: A DatabaseError if table does not exist.
    static func primaryKeyComparator(_ db: Database) throws -> (Row, Row) -> Bool {
        let primaryKey = try primaryKeyFunction(db)
        return { (lhs, rhs) in
            let (lhs, rhs) = (primaryKey(lhs), primaryKey(rhs))
            guard lhs.contains(where: { !$1.isNull }) else { return false }
            guard rhs.contains(where: { !$1.isNull }) else { return false }
            return lhs == rhs
        }
    }
}
