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
    
    /// Returns a fetched records controller initialized from a SQL query and
    /// its eventual arguments.
    ///
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         sql: "SELECT * FROM wines WHERE color = ? ORDER BY name",
    ///         arguments: [Color.Red],
    ///         isSameRecord: { (wine1, wine2) in wine1.id == wine2.id })
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
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
    public convenience init(_ databaseWriter: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, queue: dispatch_queue_t = dispatch_get_main_queue(), isSameRecord: ((Record, Record) -> Bool)? = nil) {
        self.init(databaseWriter, request: SQLRequest(sql: sql, arguments: arguments), queue: queue, isSameRecord: isSameRecord)
    }
    
    /// Returns a fetched records controller initialized from a fetch request
    /// from the [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
    ///
    ///     let request = Wine.order(SQLColumn("name"))
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
    public convenience init(_ databaseWriter: DatabaseWriter, request: FetchRequest, queue: dispatch_queue_t = dispatch_get_main_queue(), isSameRecord: ((Record, Record) -> Bool)? = nil) {
        if let isSameRecord = isSameRecord {
            self.init(databaseWriter, request: request, queue: queue, isSameRecordBuilder: { _ in isSameRecord })
        } else {
            self.init(databaseWriter, request: request, queue: queue, isSameRecordBuilder: { _ in { _ in false } })
        }
    }
    
    private init(_ databaseWriter: DatabaseWriter, request: FetchRequest, queue: dispatch_queue_t, isSameRecordBuilder: (Database) -> (Record, Record) -> Bool) {
        self.request = request
        self.databaseWriter = databaseWriter
        self.isSameRecord = { _ in return false }
        self.isSameRecordBuilder = isSameRecordBuilder
        self.queue = queue
    }
    
    /// Executes the controller's fetch request.
    ///
    /// After executing this method, you can access the the fetched objects with
    /// the property fetchedRecords.
    public func performFetch() {
        // If some changes are currently processed, make sure they are discarded.
        observer?.invalidate()
        
        // Fetch items on the writing dispatch queue, so that the transaction
        // observer is added on the same serialized queue as transaction
        // callbacks.
        databaseWriter.write { db in
            let statement = try! self.request.selectStatement(db)
            let items = Item<Record>.fetchAll(statement)
            self.fetchedItems = items
            self.isSameRecord = self.isSameRecordBuilder(db)
            
            if self.hasChangesCallbacks {
                // Setup a new transaction observer.
                let observer = FetchedRecordsObserver(
                    controller: self,
                    initialItems: items,
                    observedTables: statement.sourceTables,
                    isSameRecord: self.isSameRecord)
                self.observer = observer
                db.addTransactionObserver(observer)
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
    public let queue: dispatch_queue_t
    
    /// Updates the fetch request, and notifies the delegate of changes in the
    /// fetched records if delegate is not nil, and performFetch() has been
    /// called.
    public func setRequest(request: FetchRequest) {
        // We don't provide a setter for the request property because we need a
        // non-optional request.
        self.request = request
    }
    
    /// Updates the fetch request, and notifies the delegate of changes in the
    /// fetched records if delegate is not nil, and performFetch() has been
    /// called.
    public func setRequest(sql sql: String, arguments: StatementArguments? = nil) {
        request = SQLRequest(sql: sql, arguments: arguments)
    }
    
    public typealias WillChangeCallback = FetchedRecordsController<Record> -> ()
    public typealias DidChangeCallback = FetchedRecordsController<Record> -> ()
    
    private var willChangeCallback: WillChangeCallback?
    private var didChangeCallback: DidChangeCallback?
    
    #if os(iOS)
    public typealias TableViewEventCallback = (controller: FetchedRecordsController<Record>, record: Record, event: TableViewEvent) -> ()
    private var tableViewEventCallback: TableViewEventCallback?
    
    /// Registers changes notification callbacks (iOS only).
    ///
    /// - parameters:
    ///     - willChangeCallback: Invoked before records are updated.
    ///     - tableViewEventCallback: Invoked for each record that has been
    ///       added, removed, moved, or updated.
    ///     - didChangeCallback: Invoked after records have been updated.
    public func trackChanges(recordsWillChange willChangeCallback: WillChangeCallback? = nil, tableViewEvent tableViewEventCallback: TableViewEventCallback? = nil, recordsDidChange didChangeCallback: DidChangeCallback? = nil) {
        self.willChangeCallback = willChangeCallback
        self.tableViewEventCallback = tableViewEventCallback
        self.didChangeCallback = didChangeCallback
        self.hasChangesCallbacks = (willChangeCallback != nil) || (tableViewEventCallback != nil) || (didChangeCallback != nil)
    }
    #else
    /// Registers changes notification callbacks.
    ///
    /// - parameters:
    ///     - willChangeCallback: Invoked before records are updated.
    ///     - didChangeCallback: Invoked after records have been updated.
    public func trackChanges(recordsWillChange willChangeCallback: WillChangeCallback? = nil, recordsDidChange didChangeCallback: DidChangeCallback? = nil) {
        self.willChangeCallback = willChangeCallback
        self.didChangeCallback = didChangeCallback
        self.hasChangesCallbacks = (willChangeCallback != nil) || (didChangeCallback != nil)
    }
    #endif
    
    private var hasChangesCallbacks: Bool = false {
        didSet {
            // Setting hasChangesCallbacks to false *will* stop database changes
            // observation only after last changes are processed, in
            // FetchedRecordsObserver.databaseDidCommit. This allows user code
            // to change callbacks multiple times: tracking will stop if and
            // only if the last set callbacks are nil.
            //
            // Conversely, setting hasChangesCallbacks to true must make
            // sure that database changes are observed. But only if
            // performFetch() has been called.
            if let items = fetchedItems where hasChangesCallbacks && observer == nil {
                // Setup a new transaction observer. Use
                // database.write, so that the transaction observer is added on the
                // same serialized queue as transaction callbacks.
                databaseWriter.write { db in
                    let statement = try! self.request.selectStatement(db)
                    let observer = FetchedRecordsObserver(
                        controller: self,
                        initialItems: items,
                        observedTables: statement.sourceTables,
                        isSameRecord: self.isSameRecordBuilder(db))
                    self.observer = observer
                    db.addTransactionObserver(observer)
                    observer.checkForChangesInDatabase(db)
                }
            }
        }
    }
    
    
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
    private var fetchedItems: [Item<Record>]?
    
    // The record comparator
    private var isSameRecord: ((Record, Record) -> Bool)
    
    // The record comparator builder. It helps us supporting types that adopt
    // MutablePersistable: we just have to wait for a database connection, in
    // performFetch(), to get primary key information and generate a primary
    // key comparator.
    private let isSameRecordBuilder: (Database) -> (Record, Record) -> Bool
    
    /// The request
    private var request: FetchRequest {
        didSet {
            guard let observer = observer else { return }
            databaseWriter.write { db in
                observer.checkForChangesInDatabase(db)
            }
        }
    }
    
    // The eventual current database observer
    private var observer: FetchedRecordsObserver<Record>?
    
    private func stopTrackingChanges() {
        observer?.invalidate()
        observer = nil
    }
}


extension FetchedRecordsController where Record: MutablePersistable {
    
    // MARK: - Initialization
    
    /// Returns a fetched records controller initialized from a SQL query and
    /// its eventual arguments.
    ///
    /// The type of the fetched records must be a subclass of the Record class,
    /// or adopt both RowConvertible, and Persistable or MutablePersistable
    /// protocols.
    ///
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         sql: "SELECT * FROM wines WHERE color = ? ORDER BY name",
    ///         arguments: [Color.Red],
    ///         compareRecordsByPrimaryKey: true)
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
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
    public convenience init(_ databaseWriter: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, queue: dispatch_queue_t = dispatch_get_main_queue(), compareRecordsByPrimaryKey: Bool) {
        let request = SQLRequest(sql: sql, arguments: arguments)
        if compareRecordsByPrimaryKey {
            self.init(databaseWriter, request: request, queue: queue, isSameRecordBuilder: { db in try! Record.primaryKeyComparator(db) })
        } else {
            self.init(databaseWriter, request: request, queue: queue, isSameRecordBuilder: { _ in { _ in false } })
        }
    }
    
    /// Returns a fetched records controller initialized from a fetch request.
    ///
    ///     let request = Wine.order(SQLColumn("name"))
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
    public convenience init(_ databaseWriter: DatabaseWriter, request: FetchRequest, queue: dispatch_queue_t = dispatch_get_main_queue(), compareRecordsByPrimaryKey: Bool) {
        if compareRecordsByPrimaryKey {
            self.init(databaseWriter, request: request, queue: queue, isSameRecordBuilder: { db in try! Record.primaryKeyComparator(db) })
        } else {
            self.init(databaseWriter, request: request, queue: queue, isSameRecordBuilder: { _ in { _ in false } })
        }
    }
}


// MARK: - FetchedRecordsObserver

/// FetchedRecordsController adopts TransactionObserverType so that it can
/// monitor changes to its fetched records.
private final class FetchedRecordsObserver<Record: RowConvertible> : TransactionObserverType {
    weak var controller: FetchedRecordsController<Record>?  // If nil, self is invalidated.
    let observedTables: Set<String>
    let isSameRecord: (Record, Record) -> Bool
    var needsComputeChanges: Bool
    var items: [Item<Record>]
    let queue: dispatch_queue_t // protects items
    
    init(controller: FetchedRecordsController<Record>, initialItems: [Item<Record>], observedTables: Set<String>, isSameRecord: (Record, Record) -> Bool) {
        self.controller = controller
        self.items = initialItems
        self.observedTables = observedTables
        self.isSameRecord = isSameRecord
        self.needsComputeChanges = false
        self.queue = dispatch_queue_create("GRDB.FetchedRecordsObserver", DISPATCH_QUEUE_SERIAL)
    }
    
    func invalidate() {
        controller = nil
    }
    
    /// Part of the TransactionObserverType protocol
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        if !needsComputeChanges && observedTables.contains(event.tableName) {
            needsComputeChanges = true
        }
    }
    
    /// Part of the TransactionObserverType protocol
    func databaseWillCommit() throws { }
    
    /// Part of the TransactionObserverType protocol
    func databaseDidRollback(db: Database) {
        needsComputeChanges = false
    }
    
    /// Part of the TransactionObserverType protocol
    func databaseDidCommit(db: Database) {
        // The databaseDidCommit callback is called in the database writer
        // dispatch queue, which is serialized: it is guaranteed to process the
        // last database transaction.
        
        // Were observed tables modified?
        guard needsComputeChanges else { return }
        needsComputeChanges = false
        
        checkForChangesInDatabase(db)
    }
    
    // Precondition: this method must be called from the database writer's
    // serialized dispatch queue.
    func checkForChangesInDatabase(db: Database) {
        // Invalidated?
        guard let controller = self.controller else { return }
        
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
        let semaphore = dispatch_semaphore_create(0)
        var fetchedItems: [Item<Record>]! = nil
        
        controller.databaseWriter.readFromWrite { db in
            fetchedItems = Item<Record>.fetchAll(db, controller.request)
            
            // Fetch is complete:
            dispatch_semaphore_signal(semaphore)
        }
        
        
        // Process the fetched items
        
        dispatch_async(queue) {
            // Wait for the fetch to complete:
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            assert(fetchedItems != nil)
            
            // Invalidated?
            guard let controller = self.controller else { return }
            
            // Changes?
            #if os(iOS)
                let tableViewChanges: [TableViewChange<Record>]?
                if controller.tableViewEventCallback != nil {
                    // Compute table view changes
                    let changes = self.computeTableViewChanges(from: self.items, to: fetchedItems)
                    guard !changes.isEmpty else {
                        return
                    }
                    tableViewChanges = changes
                } else {
                    // Look for a row difference
                    guard fetchedItems.count != self.items.count || zip(fetchedItems, self.items).any({ (fetchedItem, item) in fetchedItem.row != item.row }) else {
                        return
                    }
                    tableViewChanges = nil
                }
            #else
                // Look for a row difference
                guard fetchedItems.count != self.items.count || zip(fetchedItems, self.items).any({ (fetchedItem, item) in fetchedItem.row != item.row }) else {
                    return
                }
            #endif
            
            // Ready for next check
            self.items = fetchedItems
            
            dispatch_async(controller.queue) {
                // Invalidated?
                guard let controller = self.controller else { return }
                
                if controller.hasChangesCallbacks {
                    controller.willChangeCallback?(controller)
                    controller.fetchedItems = fetchedItems
                    #if os(iOS)
                        if let tableViewEventCallback = controller.tableViewEventCallback, let tableViewChanges = tableViewChanges {
                            for change in tableViewChanges {
                                tableViewEventCallback(controller: controller, record: change.record, event: change.event)
                            }
                        }
                    #endif
                    controller.didChangeCallback?(controller)
                } else {
                    controller.stopTrackingChanges()
                }
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
        public func recordAtIndexPath(indexPath: NSIndexPath) -> Record {
            guard let fetchedItems = fetchedItems else {
                fatalError("performFetch() has not been called.")
            }
            return fetchedItems[indexPath.indexAtPosition(1)].record
        }
        
        /// Returns the indexPath of a given record (iOS only).
        ///
        /// - returns: The index path of *record* in the fetched records, or nil
        ///   if record could not be found.
        public func indexPathForRecord(record: Record) -> NSIndexPath? {
            guard let fetchedItems = fetchedItems, let index = fetchedItems.indexOf({ isSameRecord($0.record, record) }) else {
                return nil
            }
            return makeIndexPath(forRow: index, inSection: 0)
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
    
    extension FetchedRecordsObserver {
        
        private func computeTableViewChanges(from s: [Item<Record>], to t: [Item<Record>]) -> [TableViewChange<Record>] {
            let m = s.count
            let n = t.count
            
            // Fill first row and column of insertions and deletions.
            
            var d: [[[TableViewChange<Record>]]] = Array(count: m + 1, repeatedValue: Array(count: n + 1, repeatedValue: []))
            
            var changes = [TableViewChange<Record>]()
            for (row, item) in s.enumerate() {
                let deletion = TableViewChange.Deletion(item: item, indexPath: makeIndexPath(forRow: row, inSection: 0))
                changes.append(deletion)
                d[row + 1][0] = changes
            }
            
            changes.removeAll()
            for (col, item) in t.enumerate() {
                let insertion = TableViewChange.Insertion(item: item, indexPath: makeIndexPath(forRow: col, inSection: 0))
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
                            let deletion = TableViewChange.Deletion(item: s[sx], indexPath: makeIndexPath(forRow: sx, inSection: 0))
                            del.append(deletion)
                            d[sx+1][tx+1] = del
                        } else if ins.count == minimumCount {
                            let insertion = TableViewChange.Insertion(item: t[tx], indexPath: makeIndexPath(forRow: tx, inSection: 0))
                            ins.append(insertion)
                            d[sx+1][tx+1] = ins
                        } else {
                            let deletion = TableViewChange.Deletion(item: s[sx], indexPath: makeIndexPath(forRow: sx, inSection: 0))
                            let insertion = TableViewChange.Insertion(item: t[tx], indexPath: makeIndexPath(forRow: tx, inSection: 0))
                            sub.append(deletion)
                            sub.append(insertion)
                            d[sx+1][tx+1] = sub
                        }
                    }
                }
            }
            
            /// Returns an array where deletion/insertion pairs of the same element are replaced by `.Move` change.
            func standardizeChanges(changes: [TableViewChange<Record>]) -> [TableViewChange<Record>] {
                
                /// Returns a potential .Move or .Update if *change* has a matching change in *changes*:
                /// If *change* is a deletion or an insertion, and there is a matching inverse
                /// insertion/deletion with the same value in *changes*, a corresponding .Move or .Update is returned.
                /// As a convenience, the index of the matched change is returned as well.
                func mergedChange(change: TableViewChange<Record>, inChanges changes: [TableViewChange<Record>]) -> (mergedChange: TableViewChange<Record>, mergedIndex: Int)? {
                    
                    /// Returns the changes between two rows: a dictionary [key: oldValue]
                    /// Precondition: both rows have the same columns
                    func changedValues(from oldRow: Row, to newRow: Row) -> [String: DatabaseValue] {
                        var changedValues: [String: DatabaseValue] = [:]
                        for (column, newValue) in newRow {
                            let oldValue = oldRow.databaseValue(named: column)
                            if newValue != oldValue {
                                changedValues[column] = oldValue
                            }
                        }
                        return changedValues
                    }
                    
                    switch change {
                    case .Insertion(let newItem, let newIndexPath):
                        // Look for a matching deletion
                        for (index, otherChange) in changes.enumerate() {
                            guard case .Deletion(let oldItem, let oldIndexPath) = otherChange else { continue }
                            guard isSameRecord(oldItem.record, newItem.record) else { continue }
                            let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                            if oldIndexPath == newIndexPath {
                                return (TableViewChange.Update(item: newItem, indexPath: oldIndexPath, changes: rowChanges), index)
                            } else {
                                return (TableViewChange.Move(item: newItem, indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges), index)
                            }
                        }
                        return nil
                        
                    case .Deletion(let oldItem, let oldIndexPath):
                        // Look for a matching insertion
                        for (index, otherChange) in changes.enumerate() {
                            guard case .Insertion(let newItem, let newIndexPath) = otherChange else { continue }
                            guard isSameRecord(oldItem.record, newItem.record) else { continue }
                            let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                            if oldIndexPath == newIndexPath {
                                return (TableViewChange.Update(item: newItem, indexPath: oldIndexPath, changes: rowChanges), index)
                            } else {
                                return (TableViewChange.Move(item: newItem, indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges), index)
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
                    if let (mergedChange, mergedIndex) = mergedChange(change, inChanges: mergedChanges) {
                        mergedChanges.removeAtIndex(mergedIndex)
                        switch mergedChange {
                        case .Update:
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
            
            return standardizeChanges(d[m][n])
        }
    }
    
    private enum TableViewChange<T: RowConvertible> {
        case Insertion(item: Item<T>, indexPath: NSIndexPath)
        case Deletion(item: Item<T>, indexPath: NSIndexPath)
        case Move(item: Item<T>, indexPath: NSIndexPath, newIndexPath: NSIndexPath, changes: [String: DatabaseValue])
        case Update(item: Item<T>, indexPath: NSIndexPath, changes: [String: DatabaseValue])
    }
    
    extension TableViewChange {
        var record: T {
            switch self {
            case .Insertion(item: let item, indexPath: _):
                return item.record
            case .Deletion(item: let item, indexPath: _):
                return item.record
            case .Move(item: let item, indexPath: _, newIndexPath: _, changes: _):
                return item.record
            case .Update(item: let item, indexPath: _, changes: _):
                return item.record
            }
        }
        
        var event: TableViewEvent {
            switch self {
            case .Insertion(item: _, indexPath: let indexPath):
                return .Insertion(indexPath: indexPath)
            case .Deletion(item: _, indexPath: let indexPath):
                return .Deletion(indexPath: indexPath)
            case .Move(item: _, indexPath: let indexPath, newIndexPath: let newIndexPath, changes: let changes):
                return .Move(indexPath: indexPath, newIndexPath: newIndexPath, changes: changes)
            case .Update(item: _, indexPath: let indexPath, changes: let changes):
                return .Update(indexPath: indexPath, changes: changes)
            }
        }
    }
    
    extension TableViewChange: CustomStringConvertible {
        var description: String {
            switch self {
            case .Insertion(let item, let indexPath):
                return "Insert \(item) at \(indexPath)"
                
            case .Deletion(let item, let indexPath):
                return "Delete \(item) from \(indexPath)"
                
            case .Move(let item, let indexPath, let newIndexPath, changes: let changes):
                return "Move \(item) from \(indexPath) to \(newIndexPath) with changes: \(changes)"
                
            case .Update(let item, let indexPath, let changes):
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
        case Insertion(indexPath: NSIndexPath)
        
        /// A deletion event, at given indexPath.
        case Deletion(indexPath: NSIndexPath)
        
        /// A move event, from indexPath to newIndexPath. The *changes* are a
        /// dictionary whose keys are column names, and values the old values that
        /// have been changed.
        case Move(indexPath: NSIndexPath, newIndexPath: NSIndexPath, changes: [String: DatabaseValue])
        
        /// An update event, at given indexPath. The *changes* are a dictionary
        /// whose keys are column names, and values the old values that have
        /// been changed.
        case Update(indexPath: NSIndexPath, changes: [String: DatabaseValue])
    }
    
    extension TableViewEvent: CustomStringConvertible {
        
        /// A textual representation of `self`.
        public var description: String {
            switch self {
            case .Insertion(let indexPath):
                return "Insertion at \(indexPath)"
                
            case .Deletion(let indexPath):
                return "Deletion from \(indexPath)"
                
            case .Move(let indexPath, let newIndexPath, changes: let changes):
                return "Move from \(indexPath) to \(newIndexPath) with changes: \(changes)"
                
            case .Update(let indexPath, let changes):
                return "Update at \(indexPath) with changes: \(changes)"
            }
        }
    }
    
    /// A section given by a FetchedRecordsController.
    public struct FetchedRecordsSectionInfo<Record: RowConvertible> {
        private let controller: FetchedRecordsController<Record>
        
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
    
    // TODO: Is is a good idea to lazily load records?
    lazy var record: T = {
        var record = T(self.row)
        record.awakeFromFetch(row: self.row)
        return record
    }()
    
    init(_ row: Row) {
        self.row = row.copy()
    }
}

private func ==<T>(lhs: Item<T>, rhs: Item<T>) -> Bool {
    return lhs.row == rhs.row
}


// MARK: - Utils

/// Same as NSIndexPath(forRow:inSection:); works when UIKit is not available.
private func makeIndexPath(forRow row:Int, inSection section: Int) -> NSIndexPath {
    return [section, row].withUnsafeBufferPointer { buffer in NSIndexPath(indexes: buffer.baseAddress, length: buffer.count) }
}

