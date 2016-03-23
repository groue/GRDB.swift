//
//  FetchedRecordsController.swift
//  GRDB
//
//  Created by Pascal Edmond on 09/12/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//
import UIKit

public class FetchedRecordsController<T: RowConvertible> {
    
    // MARK: - Initialization
    
    // TODO: document that queue MUST be serial
    public convenience init(_ database: DatabaseWriter, _ sql: String, arguments: StatementArguments? = nil, queue: dispatch_queue_t = dispatch_get_main_queue(), isSameRecord: ((T, T) -> Bool)? = nil) {
        let source: Source<T> = .SQL(sql, arguments)
        self.init(database: database, source: source, queue: queue, isSameRecord: isSameRecord)
    }
    
    // TODO: document that queue MUST be serial
    public convenience init(_ database: DatabaseWriter, _ request: FetchRequest<T>, isSameRecord: ((T, T) -> Bool)? = nil) {
        let source: Source<T> = .FetchRequest(request)
        self.init(database: database, source: source, isSameRecord: isSameRecord)
    }
    
    private convenience init(database: DatabaseWriter, source: Source<T>, queue: dispatch_queue_t = dispatch_get_main_queue(), isSameRecord: ((T, T) -> Bool)?) {
        let isSameRecordBuilder: (Database) -> (T, T) -> Bool
        if let isSameRecord = isSameRecord {
            isSameRecordBuilder = { _ in isSameRecord }
        } else {
            isSameRecordBuilder = { _ in { _ in return false } }
        }
        self.init(database: database, source: source, queue: queue, isSameRecordBuilder: isSameRecordBuilder)
    }
    
    private init(database: DatabaseWriter, source: Source<T>, queue: dispatch_queue_t, isSameRecordBuilder: (Database) -> (T, T) -> Bool) {
        self.source = source
        self.database = database
        self.isSameRecordBuilder = isSameRecordBuilder
        self.diffQueue = dispatch_queue_create("GRDB.FetchedRecordsController.diff", nil)
        self.mainQueue = queue
        database.addTransactionObserver(self)
    }
    
    
    // MARK: - Configuration
    
    /// The databaseWriter
    public let database: DatabaseWriter
    
    public func willChange(callback:() -> ()) {
        willChangeCallback = callback
    }
    private var willChangeCallback: (() -> ())?
    
    public func didChange(callback:() -> ()) {
        didChangeCallback = callback
    }
    private var didChangeCallback: (() -> ())?
    
    public func onEvent(callback:(record: T, event: FetchedRecordsEvent) -> ()) {
        eventCallback = callback
    }
    private var eventCallback: ((record: T, event: FetchedRecordsEvent) -> ())?
    
    private var isSameRecord: ((T, T) -> Bool)?
    private let isSameRecordBuilder: (Database) -> (T, T) -> Bool
    
    
    /// The source
    private let source: Source<T>
    
    /// The observed tables. Set in performFetch()
    private var observedTables: Set<String>? = nil  // protected by database writer queue
    
    /// True if databaseDidCommit(db) should compute changes
    private var needsComputeChanges = false         // protected by database writer queue
    
    /// Dedicated to fetchedRecords, recordAtIndexPath
    private var mainItems: [Item<T>]?               // protected by mainQueue
    public private(set) var mainQueue: dispatch_queue_t
    
    /// Dedicated to change computation
    private var diffItems: [Item<T>]?               // protected by diffQueue
    private var diffQueue: dispatch_queue_t
    
    
    // MARK: - Accessing records
    
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public func performFetch() {
        // Use database.write, so that we are serialized with transaction
        // callbacks, which happen on the writing queue.
        database.write { db in
            let statement = try! self.source.selectStatement(db)
            self.observedTables = statement.sourceTables
            self.mainItems = Item<T>.fetchAll(statement)
            self.isSameRecord = self.isSameRecordBuilder(db)
        }
        dispatch_sync(self.diffQueue) {
            self.diffItems = self.mainItems
        }
    }

    /// Returns the records of the query.
    /// Returns nil if the performQuery: hasn't been called.
    ///
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public var fetchedRecords: [T]? {
        if let mainItems = self.mainItems {
            return mainItems.map { $0.record }
        }
        return nil
    }

    
    /// Returns the fetched record at a given indexPath.
    ///
    /// MUST BE CALLED ON mainQueue (TODO: say it nicely)
    public func recordAtIndexPath(indexPath: NSIndexPath) -> T {
        return mainItems![indexPath.indexAtPosition(1)].record
    }
    
    /// Returns the indexPath of a given record.
    public func indexPathForRecord(record: T) -> NSIndexPath? {
        // TODO
        fatalError("Not implemented")
    }
    
    
    // MARK: - Not public
    
    private static func computeChanges(fromRows s: [Item<T>], toRows t: [Item<T>], isSameRecord: ((T, T) -> Bool)) -> [ItemChange<T>] {
        
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
        
        /// Returns the changes between two rows
        /// Precondition: both rows have the same columns
        func changedValues(from referenceRow: Row, to newRow: Row) -> [String: DatabaseValue] {
            var changedValues: [String: DatabaseValue] = [:]
            for (column, newValue) in newRow {
                let oldValue = referenceRow[column]!
                if newValue != oldValue {
                    changedValues[column] = oldValue
                }
            }
            return changedValues
        }

        
        /// Returns an array where deletion/insertion pairs of the same element are replaced by `.Move` change.
        func standardizeChanges(changes: [ItemChange<T>]) -> [ItemChange<T>] {
            
            /// Returns a potential .Move or .Update if *change* has a matching change in *changes*:
            /// If *change* is a deletion or an insertion, and there is a matching inverse
            /// insertion/deletion with the same value in *changes*, a corresponding .Move or .Update is returned.
            /// As a convenience, the index of the matched change is returned as well.
            func mergedChange(change: ItemChange<T>, inChanges changes: [ItemChange<T>]) -> (mergedChange: ItemChange<T>, obsoleteIndex: Int)? {
                let obsoleteIndex = changes.indexOf { earlierChange in
                    return earlierChange.isMoveCounterpart(change, isSameRecord: isSameRecord)
                }
                if let obsoleteIndex = obsoleteIndex {
                    switch (changes[obsoleteIndex], change) {
                    case (.Deletion(let oldItem, let oldIndexPath), .Insertion(let newItem, let newIndexPath)):
                        let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                        if oldIndexPath == newIndexPath {
                            return (ItemChange.Update(item: newItem, indexPath: oldIndexPath, changes: rowChanges), obsoleteIndex)
                        } else {
                            return (ItemChange.Move(item: newItem, indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges), obsoleteIndex)
                        }
                    case (.Insertion(let newItem, let newIndexPath), .Deletion(let oldItem, let oldIndexPath)):
                        let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                        if oldIndexPath == newIndexPath {
                            return (ItemChange.Update(item: newItem, indexPath: oldIndexPath, changes: rowChanges), obsoleteIndex)
                        } else {
                            return (ItemChange.Move(item: newItem, indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges), obsoleteIndex)
                        }
                    default:
                        break
                    }
                }
                return nil
            }
            
            // Updates must be pushed at the end
            var mergedChanges: [ItemChange<T>] = []
            var updateChanges: [ItemChange<T>] = []
            for change in changes {
                if let (mergedChange, obsoleteIndex) = mergedChange(change, inChanges: mergedChanges) {
                    mergedChanges.removeAtIndex(obsoleteIndex)
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
        let source: Source<T> = .SQL(sql, arguments)
        self.init(database: database, source: source, queue: queue, isSameRecordBuilder: { db in try! T.primaryKeyComparator(db) })
    }
    
    // TODO: document that queue MUST be serial
    public convenience init(_ database: DatabaseWriter, _ request: FetchRequest<T>, queue: dispatch_queue_t = dispatch_get_main_queue(), compareRecordsByPrimaryKey: Bool) {
        let source: Source<T> = .FetchRequest(request)
        self.init(database: database, source: source, queue: queue, isSameRecordBuilder: { db in try! T.primaryKeyComparator(db) })
    }
}


// MARK: - <TransactionObserverType>
extension FetchedRecordsController : TransactionObserverType {
    
    public func databaseDidChangeWithEvent(event: DatabaseEvent) {
        if let observedTables = observedTables where observedTables.contains(event.tableName) {
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
        
        guard let diffItems = diffItems, let isSameRecord = isSameRecord else {
            // performFetch() has not been called yet
            return
        }
        
        let statement = try! source.selectStatement(db)
        let newItems = Item<T>.fetchAll(statement)
        
        dispatch_async(diffQueue) {
            // This code, submitted to the serial diffQueue, is guaranteed
            // to process the last database transaction:
            
            // Read/write diffItems in self.diffQueue
            let changes = FetchedRecordsController.computeChanges(fromRows: diffItems, toRows: newItems, isSameRecord: isSameRecord)
            self.diffItems = newItems
            
            guard !changes.isEmpty else {
                return
            }
            
            dispatch_async(self.mainQueue) { [weak self] in
                // This code, submitted to the serial main queue, is guaranteed
                // to process the last database transaction:
                
                guard let strongSelf = self else { return }
                
                strongSelf.willChangeCallback?()
                strongSelf.mainItems = newItems
                
                if let eventCallback = strongSelf.eventCallback {
                    for change in changes {
                        eventCallback(record: change.item.record, event: change.event)
                    }
                }
                
                strongSelf.didChangeCallback?()
            }
        }
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

// TODO: remove this debugging code
extension FetchedRecordsEvent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .Insertion(let indexPath):
            return "INSERTED AT index \(indexPath.row)"
            
        case .Deletion(let indexPath):
            return "DELETED FROM index \(indexPath.row)"
            
        case .Move(let indexPath, let newIndexPath, changes: let changes):
            return "MOVED FROM index \(indexPath.row) TO index \(newIndexPath.row) WITH CHANGES: \(changes)"
            
        case .Update(let indexPath, let changes):
            return "UPDATED AT index \(indexPath.row) WITH CHANGES: \(changes)"
        }
    }
}


// =============================================================================
// MARK: - Source

private enum Source<T> {
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

private struct Item<T: RowConvertible> : RowConvertible, Equatable {
    let row: Row
    var record: T   // var because awakeFromFetch is mutating
    
    init(_ row: Row) {
        self.row = row.copy()
        self.record = T(row)
    }
    
    mutating func awakeFromFetch(row row: Row, database: Database) {
        // TOOD: If record is a Record, it will copy the row *again*. We should
        // avoid creating two distinct copied instances.
        record.awakeFromFetch(row: row, database: database)
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

    var item: Item<T> {
        switch self {
        case .Insertion(item: let item, indexPath: _):
            return item
        case .Deletion(item: let item, indexPath: _):
            return item
        case .Move(item: let item, indexPath: _, newIndexPath: _, changes: _):
            return item
        case .Update(item: let item, indexPath: _, changes: _):
            return item
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

extension ItemChange {
    func isMoveCounterpart(otherChange: ItemChange<T>, isSameRecord: (T, T) -> Bool) -> Bool {
        switch (self, otherChange) {
        case (.Deletion(let deletedItem, _), .Insertion(let insertedItem, _)):
            return isSameRecord(deletedItem.record, insertedItem.record)
        case (.Insertion(let insertedItem, _), .Deletion(let deletedItem, _)):
            return isSameRecord(deletedItem.record, insertedItem.record)
        default:
            return false
        }
    }
}

extension ItemChange: CustomStringConvertible {
    var description: String {
        switch self {
        case .Insertion(let item, let indexPath):
            return "INSERTED \(item) AT index \(indexPath.row)"
            
        case .Deletion(let item, let indexPath):
            return "DELETED \(item) FROM index \(indexPath.row)"
            
        case .Move(let item, let indexPath, let newIndexPath, changes: let changes):
            return "MOVED \(item) FROM index \(indexPath.row) TO index \(newIndexPath.row) WITH CHANGES: \(changes)"
            
        case .Update(let item, let indexPath, let changes):
            return "UPDATED \(item) AT index \(indexPath.row) WITH CHANGES: \(changes)"
        }
    }
}
