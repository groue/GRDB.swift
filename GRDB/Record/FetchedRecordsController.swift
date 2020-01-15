import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// You use FetchedRecordsController to track changes in the results of an
/// SQLite request.
///
/// See https://github.com/groue/GRDB.swift#fetchedrecordscontroller for
/// more information.
public final class FetchedRecordsController<Record: FetchableRecord> {

    public typealias Section = ArraySection<FetchedRecordsSectionInfo<Record>, Item<Record>>

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
        sectionColumn: ColumnExpression? = nil) throws
    {
        try self.init(
            databaseWriter,
            request: SQLRequest<Record>(sql: sql, arguments: arguments, adapter: adapter),
            queue: queue,
            sectionColumn: sectionColumn)
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
    public init<Request>(
        _ databaseWriter: DatabaseWriter,
        request: Request,
        queue: DispatchQueue = .main,
        sectionColumn: ColumnExpression? = nil) throws
        where Request: FetchRequest, Request.RowDecoder == Record
    {
        self.request = ItemRequest(request)
        self.databaseWriter = databaseWriter
        self.queue = queue
        self.sectionColumn = sectionColumn
    }
    
    /// Executes the controller's fetch request.
    ///
    /// After executing this method, you can access the the fetched objects with
    /// the `fetchedRecords` property.
    ///
    /// This method must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    public func performFetch(async: Bool = false) throws {
        guard observerToken == nil else {
            return
        }

        let reducer = { [weak self] (db: Database) -> AnyValueReducer<[Section], StagedChangeset<[Section]>> in
            return AnyValueReducer(fetch: { [weak self] db -> [Section] in
                guard let strongSelf = self else {
                    return []
                }
                let rows = try Row.fetchAll(db, strongSelf.request)
                if let sectionColumn = self?.sectionColumn {
                    var dict: Dictionary<String, Section> = .init()
                    var sectionIndex = 0
                    rows.forEach { row in
                        guard let columnValue = row[sectionColumn.name],
                            let keyCharacter = "\(columnValue)".first?.uppercased() else {
                            return
                        }
                        let key = "\(keyCharacter)"
                        if var section = dict[key] {
                            section.elements.append(.init(row: row))
                            dict[key] = section
                        } else {
                            let newIndex: IndexPath = .init(item: 0, section: sectionIndex)
                            let newInfo: FetchedRecordsSectionInfo<Record> = .init(indexPath: newIndex,
                                                                                   name: key,
                                                                                   controller: self)
                            let newSection: Section = .init(model: newInfo, elements: [.init(row: row)])
                            dict[key] = newSection
                            sectionIndex += 1
                        }
                    }
                    return dict.sorted { lhs, rhs -> Bool in
                        return lhs.value.model.indexPath < rhs.value.model.indexPath
                    }.compactMap { pair in
                        return pair.value
                    }
                } else {
                    let items: [Item<Record>] = rows.compactMap(Item.init)
                    let sectionInfo: FetchedRecordsSectionInfo<Record> = .init(indexPath: .init(item: 0, section: 0),
                                                                               name: "",
                                                                               controller: self)
                    return [.init(model: sectionInfo, elements: items)]
                }
            }, value: { (newSections: [Section]) -> StagedChangeset<[Section]> in
                guard let strongSelf = self else {
                    return StagedChangeset()
                }
                let oldSections = strongSelf.fetchedSections
                strongSelf.fetchedSections = newSections
                return StagedChangeset(source: oldSections, target: newSections)
            })
        }

        var observation = ValueObservation.tracking(request, reducer: reducer)
        if async {
            observation.scheduling = .async(onQueue: queue, startImmediately: true)
        }
        observerToken = try observation.start(in: databaseWriter, onChange: { [weak self] result in
            self?.changes?(result)
        })
    }

    public func track(changes: @escaping (StagedChangeset<[Section]>) -> Void) {
        self.changes = changes
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

    /// The column in which fetched records should be sectioned by.
    ///
    /// Setting a new sectionColumn will require another call to `performFetch()`
    public var sectionColumn: ColumnExpression? {
        didSet {
            observerToken = nil
        }
    }
    
    /// Updates the fetch request, and eventually notifies the tracking
    /// callbacks if `performFetch()` has been called.
    ///
    /// This method must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    public func setRequest<Request>(_ request: Request) where Request: FetchRequest, Request.RowDecoder == Record {
        self.observerToken = nil
        self.request = ItemRequest(request)
    }
    
    /// Updates the fetch request, and eventually notifies the tracking
    /// callbacks if `performFetch()` has been called.
    ///
    /// This method must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    public func setRequest(sql: String,
                           arguments: StatementArguments = StatementArguments(),
                           adapter: RowAdapter? = nil) {
        setRequest(SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    // MARK: - Accessing Records
    
    /// The fetched records.
    ///
    /// The value of this property is empty until performFetch() has been called.
    ///
    /// The records reflect the state of the database after the initial
    /// call to performFetch, and after each database transaction that affects
    /// the results of the fetch request.
    ///
    /// This property must be used from the controller's dispatch queue (the
    /// main queue unless stated otherwise in the controller's initializer).
    public var fetchedRecords: [Record] {
        return fetchedSections.flatMap { $0.elements }.compactMap { $0.record }
    }
    
    // MARK: - Not public

    /// The sections
    fileprivate var fetchedSections: [Section] = []

    /// The request typealias
    private typealias ItemRequest = AnyFetchRequest<Item<Record>>

    /// The request
    private var request: ItemRequest

    /// The transaction observer for change tracking
    private var observerToken: TransactionObserver?

    /// A closure that is invoked when changes are tracked
    private var changes: ((StagedChangeset<[Section]>) -> Void)?
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
        queue: DispatchQueue = .main,
        sectionColumn: ColumnExpression? = nil) throws
    {
        try self.init(
            databaseWriter,
            request: SQLRequest(sql: sql, arguments: arguments, adapter: adapter),
            queue: queue,
            sectionColumn: sectionColumn)
    }
}

// MARK: - UITableView Support

extension FetchedRecordsController {
    
    // MARK: - Accessing Records
    
    /// Returns the object at the given index path.
    ///
    /// - parameter indexPath: An index path in the fetched records.
    ///
    ///     If indexPath does not describe a valid index path in the fetched
    ///     records, a fatal error is raised.
    public func record(at indexPath: IndexPath) -> Record {
        return fetchedSections[indexPath.section].elements[indexPath.item].record
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
        if fetchedSections.isEmpty {
            return [FetchedRecordsSectionInfo(indexPath: .init(item: 0, section: 0), name: "", controller: self)]
        }
        return fetchedSections.map { $0.model }
    }
}

extension FetchedRecordsController where Record: FetchableRecord & Equatable {

    /// Returns the `indexPath` for a record if it exists
    ///
    /// - parameters:
    ///     - object: A record to be searched for
    public func indexPath(for record: Record) -> IndexPath? {
        for (sectionIndex, section) in fetchedSections.enumerated() {
            for (itemIndex, item) in section.elements.enumerated() where record == item.record {
                return .init(item: itemIndex, section: sectionIndex)
            }
        }
        return nil
    }
}

/// A section given by a FetchedRecordsController.
public final class FetchedRecordsSectionInfo<Record: FetchableRecord>: Hashable, Differentiable {
    public let indexPath: IndexPath
    public let name: String
    private(set) weak var controller: FetchedRecordsController<Record>?

    public init(indexPath: IndexPath, name: String, controller: FetchedRecordsController<Record>?) {
        self.indexPath = indexPath
        self.name = name
        self.controller = controller
    }

    /// The number of records (rows) in the section.
    public var numberOfRecords: Int {
        return controller?.fetchedSections[indexPath.section].elements.count ?? 0
    }
    
    /// The array of records in the section.
    public var records: [Record] {
        return controller?.fetchedSections[indexPath.section].elements.map { $0.record } ?? []
    }

    public static func == (lhs: FetchedRecordsSectionInfo<Record>, rhs: FetchedRecordsSectionInfo<Record>) -> Bool {
        return lhs.indexPath == rhs.indexPath && lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(indexPath)
        hasher.combine(name)
    }
}

// MARK: - Item

/// An item given by a FetchedRecordsController diff
public final class Item<T: FetchableRecord>: FetchableRecord, Hashable, ContentEquatable, ContentIdentifiable {
    let row: Row
    
    // Records are lazily loaded
    public lazy var record = T(row: self.row)
    
    public init(row: Row) {
        self.row = row.copy()
    }
    
    public static func ==<T> (lhs: Item<T>, rhs: Item<T>) -> Bool {
        return lhs.row == rhs.row
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(row)
    }
}
