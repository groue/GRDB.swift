//
//  FetchedRecordsController.swift
//  GRDB
//
//  Created by Pascal Edmond on 09/12/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//
import UIKit

public final class FetchedRecordsController<T: RowConvertible> {
    
    // MARK: - Initialization
    
    // TODO: document that queue MUST be serial
    public convenience init(_ database: DatabaseWriter, _ sql: String, arguments: StatementArguments? = nil, queue: dispatch_queue_t = dispatch_get_main_queue(), isSameRecord: ((T, T) -> Bool)? = nil) {
        let source: DatabaseSource<T> = .SQL(sql, arguments)
        self.init(database: database, source: source, queue: queue, isSameRecord: isSameRecord)
    }
    
    // TODO: document that queue MUST be serial
    public convenience init<U>(_ database: DatabaseWriter, _ request: FetchRequest<U>, queue: dispatch_queue_t = dispatch_get_main_queue(), isSameRecord: ((T, T) -> Bool)? = nil) {
        let request: FetchRequest<T> = FetchRequest(query: request.query) // Retype the fetch request
        let source = DatabaseSource.FetchRequest(request)
        self.init(database: database, source: source, queue: queue, isSameRecord: isSameRecord)
    }
    
    private convenience init(database: DatabaseWriter, source: DatabaseSource<T>, queue: dispatch_queue_t, isSameRecord: ((T, T) -> Bool)?) {
        if let isSameRecord = isSameRecord {
            self.init(database: database, source: source, queue: queue, isSameRecordBuilder: { _ in isSameRecord })
        } else {
            self.init(database: database, source: source, queue: queue, isSameRecordBuilder: { _ in { _ in false } })
        }
    }
    
    private init(database: DatabaseWriter, source: DatabaseSource<T>, queue: dispatch_queue_t, isSameRecordBuilder: (Database) -> (T, T) -> Bool) {
        self.source = source
        self.database = database
        self.isSameRecordBuilder = isSameRecordBuilder
        self.diffQueue = dispatch_queue_create("GRDB.FetchedRecordsController.diff", DISPATCH_QUEUE_SERIAL)
        self.mainQueue = queue
        database.addTransactionObserver(self)
    }
    
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public func performFetch() {
        // Use database.write, so that we are serialized with transaction
        // callbacks, which happen on the writing queue.
        database.write { db in
            let statement = try! self.source.selectStatement(db)
            self.mainItems = Item<T>.fetchAll(statement)
            if !self.isObserving {
                self.isSameRecord = self.isSameRecordBuilder(db)
                self.diffItems = self.mainItems
                self.observedTables = statement.sourceTables
                
                // OK now we can start observing
                db.addTransactionObserver(self)
                self.isObserving = true
            }
        }
    }
    
    
    
    // MARK: - Configuration
    
    // Configuration: database
    
    /// The databaseWriter
    public let database: DatabaseWriter
    
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public func willChange(callback:() -> ()) {
        willChangeCallback = callback
    }
    
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public func didChange(callback:() -> ()) {
        didChangeCallback = callback
    }
    
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public func onEvent(callback:(record: T, event: FetchedRecordsEvent) -> ()) {
        eventCallback = callback
    }
    
    
    // MARK: - Accessing records
    
    /// Returns the records of the query.
    /// Returns nil if performQuery() hasn't been called.
    ///
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public var fetchedRecords: [T]? {
        if isObserving {
            return mainItems.map { $0.record }
        }
        return nil
    }
    
    
    /// Returns the fetched record at a given indexPath.
    ///
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public func recordAtIndexPath(indexPath: NSIndexPath) -> T {
        return mainItems[indexPath.indexAtPosition(1)].record
    }
    
    /// Returns the indexPath of a given record.
    ///
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public func indexPathForRecord(record: T) -> NSIndexPath? {
        if let index = mainItems.indexOf({ isSameRecord($0.record, record) }) {
            return NSIndexPath(forRow: index, inSection: 0)
        }
        return nil
    }
    
    
    // MARK: - Querying Sections Information
    
    /// The sections
    ///
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public var sections: [FetchedRecordsSectionInfo<T>] {
        // We only support a single section
        return [FetchedRecordsSectionInfo(controller: self)]
    }
    
    
    // MARK: - Not public
    
    
    // mainQueue protected data exposed in public API
    private var mainQueue: dispatch_queue_t
    
    // Set to true in performFetch()
    private var isObserving: Bool = false           // protected by mainQueue
    
    // The items exposed on public API
    private var mainItems: [Item<T>] = []           // protected by mainQueue
    
    // The change callbacks
    private var willChangeCallback: (() -> ())?     // protected by mainQueue
    private var didChangeCallback: (() -> ())?      // protected by mainQueue
    private var eventCallback: ((record: T, event: FetchedRecordsEvent) -> ())? // protected by mainQueue
    
    // The record comparator. When T adopts MutablePersistable, we need to wait
    // for performFetch() in order to build it, because
    private var isSameRecord: ((T, T) -> Bool) = { _ in false }
    private let isSameRecordBuilder: (Database) -> (T, T) -> Bool
    
    
    /// The source
    private let source: DatabaseSource<T>
    
    /// The observed tables. Set in performFetch()
    private var observedTables: Set<String> = []    // protected by database queue
    
    /// True if databaseDidCommit(db) should compute changes
    private var needsComputeChanges = false         // protected by database queue
    
    
    
    // Configuration: records
    
    
    private var diffItems: [Item<T>] = []           // protected by diffQueue
    private var diffQueue: dispatch_queue_t

    private func computeChanges(fromRows s: [Item<T>], toRows t: [Item<T>]) -> [ItemChange<T>] {
        
        let m = s.count
        let n = t.count
        
        // Fill first row and column of insertions and deletions.
        
        var d: [[[ItemChange<T>]]] = Array(count: m + 1, repeatedValue: Array(count: n + 1, repeatedValue: []))
        
        var changes = [ItemChange<T>]()
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
        func standardizeChanges(changes: [ItemChange<T>]) -> [ItemChange<T>] {
            
            /// Returns a potential .Move or .Update if *change* has a matching change in *changes*:
            /// If *change* is a deletion or an insertion, and there is a matching inverse
            /// insertion/deletion with the same value in *changes*, a corresponding .Move or .Update is returned.
            /// As a convenience, the index of the matched change is returned as well.
            func mergedChange(change: ItemChange<T>, inChanges changes: [ItemChange<T>]) -> (mergedChange: ItemChange<T>, mergedIndex: Int)? {
                
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
            var mergedChanges: [ItemChange<T>] = []
            var updateChanges: [ItemChange<T>] = []
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

extension FetchedRecordsController where T: MutablePersistable {
    
    // TODO: document that queue MUST be serial
    public convenience init(_ database: DatabaseWriter, _ sql: String, arguments: StatementArguments? = nil, queue: dispatch_queue_t = dispatch_get_main_queue(), compareRecordsByPrimaryKey: Bool) {
        let source: DatabaseSource<T> = .SQL(sql, arguments)
        if compareRecordsByPrimaryKey {
            self.init(database: database, source: source, queue: queue, isSameRecordBuilder: { db in try! T.primaryKeyComparator(db) })
        } else {
            self.init(database: database, source: source, queue: queue, isSameRecordBuilder: { _ in { _ in false } })
        }
    }
    
    // TODO: document that queue MUST be serial
    public convenience init<U>(_ database: DatabaseWriter, _ request: FetchRequest<U>, queue: dispatch_queue_t = dispatch_get_main_queue(), compareRecordsByPrimaryKey: Bool) {
        let request: FetchRequest<T> = FetchRequest(query: request.query) // Retype the fetch request
        let source = DatabaseSource.FetchRequest(request)
        if compareRecordsByPrimaryKey {
            self.init(database: database, source: source, queue: queue, isSameRecordBuilder: { db in try! T.primaryKeyComparator(db) })
        } else {
            self.init(database: database, source: source, queue: queue, isSameRecordBuilder: { _ in { _ in false } })
        }
    }
}


// MARK: - <TransactionObserverType>

extension FetchedRecordsController : TransactionObserverType {
    
    public func databaseDidChangeWithEvent(event: DatabaseEvent) {
        if observedTables.contains(event.tableName) {
            needsComputeChanges = true
        }
    }
    
    public func databaseWillCommit() throws { }
    
    public func databaseDidRollback(db: Database) {
        needsComputeChanges = false
    }
    
    public func databaseDidCommit(db: Database) {
        // The databaseDidCommit callback is called in a serialized dispatch
        // queue: It is guaranteed to process the last database transaction.
        
        guard needsComputeChanges else {
            return
        }
        needsComputeChanges = false
        
        let statement = try! source.selectStatement(db)
        let newItems = Item<T>.fetchAll(statement)
        
        dispatch_async(diffQueue) { [weak self] in
            // This code, submitted to the serial diffQueue, is guaranteed
            // to process the last database transaction:
            
            guard let strongSelf = self else { return }
            
            // Read/write diffItems in self.diffQueue
            let diffItems = strongSelf.diffItems
            let changes = strongSelf.computeChanges(fromRows: diffItems, toRows: newItems)
            strongSelf.diffItems = newItems
            
            guard !changes.isEmpty else {
                return
            }
            
            dispatch_async(strongSelf.mainQueue) {
                // This code, submitted to the serial main queue, is guaranteed
                // to process the last database transaction:
                
                guard let strongSelf = self else { return }
                
                strongSelf.willChangeCallback?()
                strongSelf.mainItems = newItems
                
                if let eventCallback = strongSelf.eventCallback {
                    for change in changes {
                        eventCallback(record: change.record, event: change.event)
                    }
                }
                
                strongSelf.didChangeCallback?()
            }
        }
    }
}


// =============================================================================
// MARK: - FetchedRecordsSectionInfo

public struct FetchedRecordsSectionInfo<T: RowConvertible> {
    private let controller: FetchedRecordsController<T>
    public var numberOfRecords: Int {
        // We only support a single section
        return controller.mainItems.count
    }
    public var records: [T] {
        // We only support a single section
        return controller.mainItems.map { $0.record }
    }
}


// =============================================================================
// MARK: - FetchedRecordsEvent

public enum FetchedRecordsEvent {
    case Insertion(indexPath: NSIndexPath)
    case Deletion(indexPath: NSIndexPath)
    case Move(indexPath: NSIndexPath, newIndexPath: NSIndexPath, changes: [String: DatabaseValue])
    case Update(indexPath: NSIndexPath, changes: [String: DatabaseValue])
}

extension FetchedRecordsEvent: CustomStringConvertible {
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
