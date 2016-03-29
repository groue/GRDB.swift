//
//  FetchedRecordsController.swift
//  GRDB
//
//  Created by Pascal Edmond on 09/12/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//
import UIKit

/// You use a FetchedRecordsController to feed a UITableView with the results
/// returned from an SQLite request.
///
/// It looks and behaves very much like Core Data's NSFetchedResultsController.
///
/// Given a fetch request, and a type that adopts the RowConvertible protocol,
/// such as a subclass of the Record class, a FetchedRecordsController is able
/// to return the results of the request in a form that is suitable for a
/// UITableView, with one table view row per fetched record.
///
/// FetchedRecordsController can also track changes in the results of the fetch
/// request, and notify its delegate of those changes. Change tracking is active
/// if and only if the delegate is not nil.
///
///
/// # Creating the Fetched Records Controller
///
/// You typically create an instance of FetchedRecordsController as a property
/// of a table view controller. When you initialize the fetch records
/// controller, you provide the following information:
///
/// - The type of the fetched records. It must be a type that adopts the
///   RowConvertible protocol, such as a subclass of the Record class.
///
/// - A fetch request. It can be a raw SQL query with its arguments, or a
///   FetchRequest from the GRDB [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
///
/// - Optionally, a way to tell if two records have the same identity. Without
///   this identity comparison, all record updates are seen as replacements,
///   and your table view updates are less smooth.
///
/// After creating an instance, you invoke `performFetch()` to actually execute
/// the fetch.
///
///     class Person : Record { ... }
///
///     let dbQueue = DatabaseQueue(...)
///     let request = Person.order(SQLColumn("name"))
///     let controller: FetchedRecordsController<Person> = FetchedRecordsController(
///         dbQueue,
///         request: request,
///         compareRecordsByPrimaryKey: true)
///     controller.performFetch()
///
/// In the example above, two persons are considered identical if they share
/// the same primary key, thanks to the `compareRecordsByPrimaryKey` argument.
/// This initializer argument is only available for types such as
/// Record subclasses that adopt the RowConvertible protocol, and also the
/// Persistable or MutablePersistable protocols.
///
/// If your type only adopts RowConvertible, you need to be more explicit, and
/// provide your own identity comparison function:
///
///     struct Person : RowConvertible {
///         let id: Int64
///         ...
///     }
///
///     let controller: FetchedRecordsController<Person> = FetchedRecordsController(
///         dbQueue,
///         request: request,
///         isSameRecord: { (person1, person2) in person1.id == person2.id })
///
/// Instead of a FetchRequest object, you can also provide a raw SQL query:
///
///     let controller: FetchedRecordsController<Person> = FetchedRecordsController(
///         dbQueue,
///         sql: "SELECT * FROM persons ORDER BY name",
///         compareRecordsByPrimaryKey: true)
///
/// The fetch request can involve several database tables:
///
///     let controller: FetchedRecordsController<Person> = FetchedRecordsController(
///         dbQueue,
///         sql: "SELECT persons.*, COUNT(books.id) AS bookCount " +
///              "FROM persons " +
///              "LEFT JOIN books ON books.owner_id = persons.id " +
///              "GROUP BY persons.id " +
///              "ORDER BY persons.name",
///         compareRecordsByPrimaryKey: true)
///
///
/// # The Controller's Delegate
///
/// Any change in the database that affects the record set is processed and the
/// records are updated accordingly. The controller notifies the delegate when
/// records change location (see FetchedRecordsControllerDelegate). You
/// typically use these methods to update the display of the table view.
///
///
/// # Implementing the Table View Datasource Methods
///
/// The table view data source asks the fetched records controller to provide
/// relevant information:
///
///     func numberOfSectionsInTableView(tableView: UITableView) -> Int {
///         return fetchedRecordsController.sections.count
///     }
///
///     func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
///         return fetchedRecordsController.sections[section].numberOfRecords
///     }
///
///     func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
///         let cell = /* Get the cell */
///         let record = fetchedRecordsController.recordAtIndexPath(indexPath)
///         /* Configure the cell */
///         return cell
///     }
///
///
/// # Responding to Changes
///
/// In general, FetchedRecordsController is designed to respond to changes at
/// the database layer, by informing its delegate when database rows change
/// location or values.
///
/// Changes are not reflected until they are applied in the database by a
/// successful transaction. Transactions can be explicit, or implicit:
///
///     try dbQueue.inTransaction { db in
///         /* Change a person's attributes */
///         try person.save(db)
///         return .Commit      // Explicit transaction
///     }
///
///     try dbQueue.inDatabase { db in
///         /* Change a person's attributes */
///         try person.save(db) // Implicit transaction
///     }
///
/// When you apply several changes to the database, you should group them in a
/// single transaction. The controller will then notify its delegate of all
/// changes together.
///
///
/// # Modifying the Fetch Request
///
/// You can change a fetched records controller's fetch request or SQL query.
/// The delegate gets notified of changes in the fetched records:
///
///     controller.setRequest(Person.order(SQLColumn("name")))
///     controller.setSQL("SELECT ...")
///
///
/// # Concurrency
///
/// A fetched records controller *can not* be used from any thread.
///
/// By default, it must be used from the main thread, and its delegate is
/// notified of record changes on the main thread.
///
/// When you create a controller, you can give it a serial dispatch queue. The
/// controller must then be used from this queue, and its delegate gets notified
/// of record changes on this queue as well.
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
    ///     - db: A DatabaseWriter (DatabaseQueue, or DatabasePool)
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
    public convenience init(_ db: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, queue: dispatch_queue_t = dispatch_get_main_queue(), isSameRecord: ((Record, Record) -> Bool)? = nil) {
        let source: DatabaseSource<Record> = .SQL(sql, arguments)
        self.init(db: db, source: source, queue: queue, isSameRecord: isSameRecord)
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
    ///     - db: A DatabaseWriter (DatabaseQueue, or DatabasePool)
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
    public convenience init<T>(_ db: DatabaseWriter, request: FetchRequest<T>, queue: dispatch_queue_t = dispatch_get_main_queue(), isSameRecord: ((Record, Record) -> Bool)? = nil) {
        // Retype the fetch request
        let request: FetchRequest<Record> = FetchRequest(query: request.query)
        let source = DatabaseSource.FetchRequest(request)
        self.init(db: db, source: source, queue: queue, isSameRecord: isSameRecord)
    }
    
    private convenience init(db: DatabaseWriter, source: DatabaseSource<Record>, queue: dispatch_queue_t, isSameRecord: ((Record, Record) -> Bool)?) {
        if let isSameRecord = isSameRecord {
            self.init(db: db, source: source, queue: queue, isSameRecordBuilder: { _ in isSameRecord })
        } else {
            self.init(db: db, source: source, queue: queue, isSameRecordBuilder: { _ in { _ in false } })
        }
    }
    
    private init(db: DatabaseWriter, source: DatabaseSource<Record>, queue: dispatch_queue_t, isSameRecordBuilder: (Database) -> (Record, Record) -> Bool) {
        self.source = source
        self.writer = db
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
        writer.write { db in
            let statement = try! self.source.selectStatement(db)
            let items = Item<Record>.fetchAll(statement)
            self.fetchedItems = items
            self.isSameRecord = self.isSameRecordBuilder(db)
            
            if self.delegate != nil {
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
    
    /// The object that is notified when the fetched records changed.
    public weak var delegate: FetchedRecordsControllerDelegate? {
        didSet {
            // Setting the delegate to nil *will* stop database changes
            // observation only after last changes are processed, in
            // FetchedRecordsObserver.databaseDidCommit. This allows user code
            // to change the delegate multiple times: tracking will stop if and
            // only if the last delegate value is nil.
            //
            // Conversely, setting the delegate to a non-nil value must make
            // sure that database changes are observed. But only if
            // performFetch() has been called.
            if let items = fetchedItems where delegate != nil && observer == nil {
                // Setup a new transaction observer. Use
                // database.write, so that the transaction observer is added on the
                // same serialized queue as transaction callbacks.
                writer.write { db in
                    let statement = try! self.source.selectStatement(db)
                    let observer = FetchedRecordsObserver(
                        controller: self,
                        initialItems: items,
                        observedTables: statement.sourceTables,
                        isSameRecord: self.isSameRecordBuilder(db))
                    self.observer = observer
                    db.addTransactionObserver(observer)
                }
            }
        }
    }
    
    
    // Configuration: database
    
    /// The database writer used to fetch records.
    ///
    /// The controller registers as a transaction observer in order to respond
    /// to changes.
    public let writer: DatabaseWriter
    
    /// The dispatch queue on which the controller must be used.
    ///
    /// Unless specified otherwise at initialization time, it is the main queue.
    public let queue: dispatch_queue_t
    
    /// The fetch request. Nil if controller uses a raw SQL query (see
    /// sqlAndArguments property).
    public var request: FetchRequest<Record>? {
        guard case .FetchRequest(let request) = source else {
            return nil
        }
        return request
    }
    
    /// The SQL query, and eventual arguments. Nil if controller uses a
    /// fetch request (see request property).
    public var sqlAndArguments: (sql: String, arguments: StatementArguments?)? {
        guard case .SQL(let sql, let arguments) = source else {
            return nil
        }
        return (sql: sql, arguments: arguments)
    }
    
    /// Updates the fetch request, and notifies the delegate of changes in the
    /// fetched records.
    public func setRequest<T>(request: FetchRequest<T>) {
        // Retype the fetch request
        let request: FetchRequest<Record> = FetchRequest(query: request.query)
        self.source = DatabaseSource.FetchRequest(request)
    }
    
    /// Updates the fetch request, and notifies the delegate of changes in the
    /// fetched records.
    public func setSQL(sql: String, arguments: StatementArguments? = nil) {
        self.source = DatabaseSource.SQL(sql, arguments)
    }
    
    
    // MARK: - Accessing records
    
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
    
    /// Returns the object at the given index path.
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
    
    /// Returns the indexPath of a given record.
    ///
    /// - returns: The index path of *record* in the fetched records, or nil if
    ///   record could not be found.
    public func indexPathForRecord(record: Record) -> NSIndexPath? {
        guard let fetchedItems = fetchedItems, let index = fetchedItems.indexOf({ isSameRecord($0.record, record) }) else {
            return nil
        }
        return NSIndexPath(forRow: index, inSection: 0)
    }
    
    
    // MARK: - Querying Sections Information
    
    /// The sections for the fetched records.
    ///
    /// You typically use the sections array when implementing
    /// UITableViewDataSource methods, such as `numberOfSectionsInTableView`.
    public var sections: [FetchedRecordsSectionInfo<Record>] {
        // We only support a single section
        return [FetchedRecordsSectionInfo(controller: self)]
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
    
    /// The source
    private var source: DatabaseSource<Record> {
        didSet {
            guard let observer = observer else { return }
            writer.write { db in
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
    ///     - db: A DatabaseWriter (DatabaseQueue, or DatabasePool)
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
    public convenience init(_ db: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, queue: dispatch_queue_t = dispatch_get_main_queue(), compareRecordsByPrimaryKey: Bool) {
        let source: DatabaseSource<Record> = .SQL(sql, arguments)
        if compareRecordsByPrimaryKey {
            self.init(db: db, source: source, queue: queue, isSameRecordBuilder: { db in try! Record.primaryKeyComparator(db) })
        } else {
            self.init(db: db, source: source, queue: queue, isSameRecordBuilder: { _ in { _ in false } })
        }
    }
    
    /// Returns a fetched records controller initialized from a fetch request
    /// from the [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
    ///
    ///     let request = Wine.order(SQLColumn("name"))
    ///     let controller = FetchedRecordsController<Wine>(
    ///         dbQueue,
    ///         request: request,
    ///         compareRecordsByPrimaryKey: true)
    ///
    /// - parameters:
    ///     - db: A DatabaseWriter (DatabaseQueue, or DatabasePool)
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
    public convenience init<U>(_ db: DatabaseWriter, request: FetchRequest<U>, queue: dispatch_queue_t = dispatch_get_main_queue(), compareRecordsByPrimaryKey: Bool) {
        // Retype the fetch request
        let request: FetchRequest<Record> = FetchRequest(query: request.query)
        let source = DatabaseSource.FetchRequest(request)
        if compareRecordsByPrimaryKey {
            self.init(db: db, source: source, queue: queue, isSameRecordBuilder: { db in try! Record.primaryKeyComparator(db) })
        } else {
            self.init(db: db, source: source, queue: queue, isSameRecordBuilder: { _ in { _ in false } })
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
        if observedTables.contains(event.tableName) {
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
        // serialized FIFO queue, but have it wait for our fetch to complete
        // with a semaphore:
        let semaphore = dispatch_semaphore_create(0)
        var fetchedItems: [Item<Record>]! = nil
        
        controller.writer.readFromWrite { db in
            let statement = try! controller.source.selectStatement(db)
            fetchedItems = Item<Record>.fetchAll(statement)
            
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
            
            // Compute changes
            let changes = self.computeChanges(from: self.items, to: fetchedItems)
            self.items = fetchedItems
            
            // No changes?
            guard !changes.isEmpty else { return }
            
            dispatch_async(controller.queue) {
                // Invalidated?
                guard let controller = self.controller else { return }
                
                if let delegate = controller.delegate {
                    delegate.controllerWillChangeRecords(controller)
                    controller.fetchedItems = fetchedItems
                    for change in changes {
                        delegate.controller(controller, didChangeRecord: change.record, withEvent: change.event)
                    }
                    delegate.controllerDidChangeRecords(controller)
                } else {
                    // There is no delegate interested in changes: stop tracking
                    // changes.
                    controller.stopTrackingChanges()
                }
            }
        }
    }
    
    func computeChanges(from s: [Item<Record>], to t: [Item<Record>]) -> [ItemChange<Record>] {
        let m = s.count
        let n = t.count
        
        // Fill first row and column of insertions and deletions.
        
        var d: [[[ItemChange<Record>]]] = Array(count: m + 1, repeatedValue: Array(count: n + 1, repeatedValue: []))
        
        var changes = [ItemChange<Record>]()
        for (row, item) in s.enumerate() {
            let deletion = ItemChange.Deletion(item: item, indexPath: NSIndexPath(forRow: row, inSection: 0))
            changes.append(deletion)
            d[row + 1][0] = changes
        }
        
        changes.removeAll()
        for (col, item) in t.enumerate() {
            let insertion = ItemChange.Insertion(item: item, indexPath: NSIndexPath(forRow: col, inSection: 0))
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
                        let deletion = ItemChange.Deletion(item: s[sx], indexPath: NSIndexPath(forRow: sx, inSection: 0))
                        del.append(deletion)
                        d[sx+1][tx+1] = del
                    } else if ins.count == minimumCount {
                        let insertion = ItemChange.Insertion(item: t[tx], indexPath: NSIndexPath(forRow: tx, inSection: 0))
                        ins.append(insertion)
                        d[sx+1][tx+1] = ins
                    } else {
                        let deletion = ItemChange.Deletion(item: s[sx], indexPath: NSIndexPath(forRow: sx, inSection: 0))
                        let insertion = ItemChange.Insertion(item: t[tx], indexPath: NSIndexPath(forRow: tx, inSection: 0))
                        sub.append(deletion)
                        sub.append(insertion)
                        d[sx+1][tx+1] = sub
                    }
                }
            }
        }
        
        /// Returns an array where deletion/insertion pairs of the same element are replaced by `.Move` change.
        func standardizeChanges(changes: [ItemChange<Record>]) -> [ItemChange<Record>] {
            
            /// Returns a potential .Move or .Update if *change* has a matching change in *changes*:
            /// If *change* is a deletion or an insertion, and there is a matching inverse
            /// insertion/deletion with the same value in *changes*, a corresponding .Move or .Update is returned.
            /// As a convenience, the index of the matched change is returned as well.
            func mergedChange(change: ItemChange<Record>, inChanges changes: [ItemChange<Record>]) -> (mergedChange: ItemChange<Record>, mergedIndex: Int)? {
                
                /// Returns the changes between two rows: a dictionary [key: oldValue]
                /// Precondition: both rows have the same columns
                func changedValues(from oldRow: Row, to newRow: Row) -> [String: DatabaseValue] {
                    var changedValues: [String: DatabaseValue] = [:]
                    for (column, newValue) in newRow {
                        let oldValue = oldRow[column]!
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
                            return (ItemChange.Update(item: newItem, indexPath: oldIndexPath, changes: rowChanges), index)
                        } else {
                            return (ItemChange.Move(item: newItem, indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges), index)
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
                            return (ItemChange.Update(item: newItem, indexPath: oldIndexPath, changes: rowChanges), index)
                        } else {
                            return (ItemChange.Move(item: newItem, indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges), index)
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


// =============================================================================
// MARK: - FetchedRecordsControllerDelegate

/// An instance of FetchedRecordsController uses methods in this protocol to
/// notify its delegate that the controller’s fetched records have been changed
/// due to some add, remove, move, or update operations.
///
///
/// # Typical Use
///
/// You can use controllerWillChangeRecords: and controllerDidChangeRecord: to
/// bracket updates to a table view whose content is provided by the fetched
/// records controller as illustrated in the following example:
///
///     // Assume self has a tableView property, and a
///     // configureCell(_:atIndexPath:) method which updates the contents of a
///     // given cell.
///
///     func controllerWillChangeRecords<T>(controller: FetchedRecordsController<T>) {
///         tableView.beginUpdates()
///     }
///
///     func controller<T>(controller: FetchedRecordsController<T>, didChangeRecord record: T, withEvent event:FetchedRecordsEvent) {
///         switch event {
///         case .Insertion(let indexPath):
///             tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
///
///         case .Deletion(let indexPath):
///             tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
///
///         case .Update(let indexPath, _):
///             if let cell = tableView.cellForRowAtIndexPath(indexPath) {
///                 configureCell(cell, atIndexPath: indexPath)
///             }
///
///         case .Move(let indexPath, let newIndexPath, _):
///             tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
///             tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
///
///             // // Alternate technique (which actually moves cells around):
///             // let cell = tableView.cellForRowAtIndexPath(indexPath)
///             // tableView.moveRowAtIndexPath(indexPath, toIndexPath: newIndexPath)
///             // if let cell = cell {
///             //     configureCell(cell, atIndexPath: newIndexPath)
///             // }
///         }
///     }
///
///     func controllerDidChangeRecords<T>(controller: FetchedRecordsController<T>) {
///         tableView.endUpdates()
///     }
public protocol FetchedRecordsControllerDelegate : class {
    /// Notifies that the fetched records controller is about to start
    /// processing of one or more changes due to an add, remove, move,
    // or update.
    ///
    /// - parameter controller: The fetched records controller that sent
    ///   the message.
    func controllerWillChangeRecords<T>(controller: FetchedRecordsController<T>)
    
    /// Notifies that a record has been changed due to an add, remove, move,
    /// or update.
    ///
    /// Swift mandates the delegate to implement this method as a generic
    /// method on the type of the changed record.
    ///
    /// The advantage is that a single object can be the delegate of multiple
    /// fetched records controllers that fetch multiple types of records. The
    /// downside is that the actual type of the changed record is erased: you
    /// must cast it to the expected type:
    ///
    ///     let personsController: FetchedRecordsController<Person>
    ///
    ///     func controller<T>(controller: FetchedRecordsController<T>, didChangeRecord record: T, withEvent event:FetchedRecordsEvent) {
    ///         if controller === personsController {
    ///             let person = record as! Person // Explicit cast
    ///         }
    ///     }
    ///
    /// - parameters:
    ///     - controller: The fetched records controller that sent the message.
    ///     - record: The record that changed.
    ///     - event: The type of change (see FetchedRecordsEvent).
    func controller<T>(controller: FetchedRecordsController<T>, didChangeRecord record: T, withEvent event:FetchedRecordsEvent)
    
    /// Notifies that the fetched records controller has completed processing
    /// of one or more changes due to an add, remove, move, or update.
    ///
    /// - parameter controller: The fetched records controller that sent
    ///   the message.
    func controllerDidChangeRecords<T>(controller: FetchedRecordsController<T>)
}

public extension FetchedRecordsControllerDelegate {
    /// The default implementation does nothing.
    func controllerWillChangeRecords<T>(controller: FetchedRecordsController<T>) { }

    /// The default implementation does nothing.
    func controller<T>(controller: FetchedRecordsController<T>, didChangeRecord record: T, withEvent event:FetchedRecordsEvent) { }
    
    /// The default implementation does nothing.
    func controllerDidChangeRecords<T>(controller: FetchedRecordsController<T>) { }
}



// =============================================================================
// MARK: - FetchedRecordsSectionInfo

/// A section given by a FetchedRecordsController.
public struct FetchedRecordsSectionInfo<T: RowConvertible> {
    private let controller: FetchedRecordsController<T>
    
    /// The number of records (rows) in the section.
    public var numberOfRecords: Int {
        // We only support a single section
        return controller.fetchedItems!.count
    }
    
    /// The array of records in the section.
    public var records: [T] {
        // We only support a single section
        return controller.fetchedItems!.map { $0.record }
    }
}


// =============================================================================
// MARK: - FetchedRecordsEvent

/// A change event given by a FetchedRecordsController to its delegate.
///
/// The move and update events hold a *changes* dictionary. Its keys are column
/// names, and values the old values that have been changed.
public enum FetchedRecordsEvent {
    
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

extension FetchedRecordsEvent: CustomStringConvertible {
    
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


// =============================================================================
// MARK: - DatabaseSource

private enum DatabaseSource<T> {
    case SQL(String, StatementArguments?)
    case FetchRequest(GRDB.FetchRequest<T>)
    
    func selectStatement(db: Database) throws -> SelectStatement {
        switch self {
        case .SQL(let sql, let arguments):
            let statement = try db.selectStatement(sql)
            if let arguments = arguments {
                try statement.validateArguments(arguments)
                statement.unsafeSetArguments(arguments)
            }
            return statement
        case .FetchRequest(let request):
            return try request.selectStatement(db)
        }
    }
}


// =============================================================================
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


// =============================================================================
// MARK: - ItemChange

private enum ItemChange<T: RowConvertible> {
    case Insertion(item: Item<T>, indexPath: NSIndexPath)
    case Deletion(item: Item<T>, indexPath: NSIndexPath)
    case Move(item: Item<T>, indexPath: NSIndexPath, newIndexPath: NSIndexPath, changes: [String: DatabaseValue])
    case Update(item: Item<T>, indexPath: NSIndexPath, changes: [String: DatabaseValue])
}

extension ItemChange {
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
    
    var event: FetchedRecordsEvent {
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

extension ItemChange: CustomStringConvertible {
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
