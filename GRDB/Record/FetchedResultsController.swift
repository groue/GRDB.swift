//
//  FetchedResultsController.swift
//  GRDB
//
//  Created by Pascal Edmond on 09/12/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//
import UIKit

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

private struct FetchedItem<T: RowConvertible> : RowConvertible, Equatable {
    let row: Row
    var result: T   // var because awakeFromFetch is mutating
    
    init(_ row: Row) {
        self.row = row.copy()
        self.result = T(row)
    }
    
    mutating func awakeFromFetch(row row: Row, database: Database) {
        // TOOD: If result is a Record, it will copy the row *again*. We should
        // avoid creating two distinct copied instances.
        result.awakeFromFetch(row: row, database: database)
    }
}

private func ==<T>(lhs: FetchedItem<T>, rhs: FetchedItem<T>) -> Bool {
    return lhs.row == rhs.row
}

public class FetchedResultsController<T: RowConvertible> {
    
    // MARK: - Initialization
    public convenience init(_ database: DatabaseWriter, _ sql: String, arguments: StatementArguments? = nil, identityComparator: ((T, T) -> Bool)? = nil) {
        let source: Source<T> = .SQL(sql, arguments)
        self.init(database: database, source: source, identityComparator: identityComparator)
    }
    
    public convenience init(_ database: DatabaseWriter, _ request: FetchRequest<T>, identityComparator: ((T, T) -> Bool)? = nil) {
        let source: Source<T> = .FetchRequest(request)
        self.init(database: database, source: source, identityComparator: identityComparator)
    }
    
    private init(database: DatabaseWriter, source: Source<T>, identityComparator: ((T, T) -> Bool)?) {
        self.source = source
        self.database = database
        if let identityComparator = identityComparator {
            self.identityComparator = identityComparator
        } else {
            self.identityComparator = { _ in false }
        }
        database.addTransactionObserver(self)
    }
    
    public func performFetch() {
        try! database.read { db in
            let statement = try self.source.selectStatement(db)
            self.observedTables = statement.sourceTables
            self.fetchedItems = FetchedItem<T>.fetchAll(statement)
        }
    }
    
    
    // MARK: - Configuration
    
    /// The source
    private let source: Source<T>
    
    private let identityComparator: (T, T) -> Bool
    
    /// The observed tables. Set in performFetch()
    private var observedTables: Set<String>? = nil
    
    /// True if databaseDidCommit(db) should compute changes
    private var fetchedItemsDidChange = false
    
    private var fetchedItems: [FetchedItem<T>]?

    /// The databaseWriter
    public let database: DatabaseWriter
    
    /// Delegate that is notified when the resultss set changes.
    weak public var delegate: FetchedResultsControllerDelegate?
    
    
    // MARK: - Accessing results

    /// Returns the results of the query.
    /// Returns nil if the performQuery: hasn't been called.
    public var fetchedResults: [T]? {
        if let fetchedItems = fetchedItems {
            return fetchedItems.map { $0.result }
        }
        return nil
    }

    
    /// Returns the fetched object at a given indexPath.
    public func resultAtIndexPath(indexPath: NSIndexPath) -> T? {
        if let item = fetchedItems?[indexPath.indexAtPosition(1)] {
            return item.result
        } else {
            return nil
        }
    }
    
    /// Returns the indexPath of a given object.
    public func indexPathForResult(result: T) -> NSIndexPath? {
        // TODO
        fatalError("Not implemented")
    }
    
    
    // MARK: - Not public
    
    private static func computeChanges(fromRows s: [FetchedItem<T>], toRows t: [FetchedItem<T>], identityComparator: ((T, T) -> Bool)) -> [ResultChange<FetchedItem<T>>] {
        
        let m = s.count
        let n = t.count
        
        // Fill first row and column of insertions and deletions.
        
        var d: [[[ResultChange<FetchedItem<T>>]]] = Array(count: m + 1, repeatedValue: Array(count: n + 1, repeatedValue: []))
        
        var changes = [ResultChange<FetchedItem<T>>]()
        for (row, item) in s.enumerate() {
            let deletion = ResultChange.Deletion(item: item, at: NSIndexPath(forRow: row, inSection: 0))
            changes.append(deletion)
            d[row + 1][0] = changes
        }
        
        changes.removeAll()
        for (col, item) in t.enumerate() {
            let insertion = ResultChange.Insertion(item: item, at: NSIndexPath(forRow: col, inSection: 0))
            changes.append(insertion)
            d[0][col + 1] = changes
        }
        
        guard m > 0 && n > 0 else { return d[m][n] }
        
        // Indexes into the two collections.
        var sx: Array<T>.Index
        var tx = t.startIndex
        
        // Fill body of matrix.
        
        for j in 1...n {
            sx = s.startIndex
            
            for i in 1...m {
                if s[sx] == t[tx] {
                    // TODO: compute changes
                    d[i][j] = d[i - 1][j - 1] // no operation
                } else {
                    
                    var del = d[i - 1][j] // a deletion
                    var ins = d[i][j - 1] // an insertion
                    var sub = d[i - 1][j - 1] // a substitution
                    
                    // Record operation.
                    
                    let minimumCount = min(del.count, ins.count, sub.count)
                    if del.count == minimumCount {
                        let deletion = ResultChange.Deletion(item: s[sx], at: NSIndexPath(forRow: i-1, inSection: 0))
                        del.append(deletion)
                        d[i][j] = del
                    } else if ins.count == minimumCount {
                        let insertion = ResultChange.Insertion(item: t[tx], at: NSIndexPath(forRow: j-1, inSection: 0))
                        ins.append(insertion)
                        d[i][j] = ins
                    } else {
                        let deletion = ResultChange.Deletion(item: s[sx], at: NSIndexPath(forRow: i-1, inSection: 0))
                        let insertion = ResultChange.Insertion(item: t[tx], at: NSIndexPath(forRow: j-1, inSection: 0))
                        sub.append(deletion)
                        sub.append(insertion)
                        d[i][j] = sub
                    }
                }
                
                sx = sx.advancedBy(1)
            }
            
            tx = tx.advancedBy(1)
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
        func standardizeChanges(changes: [ResultChange<FetchedItem<T>>]) -> [ResultChange<FetchedItem<T>>] {
            
            /// Returns a potential .Move `ResultChange` based on an array of `ResultChange` elements and a `ResultChange` to match up against.
            /// If `deletionOrInsertion` is a deletion or an insertion, and there is a matching inverse insertion/deletion with the same value in the array, a corresponding `.Move` update is returned.
            /// As a convenience, the index of the matched `ResultChange` into `changes` is returned as well.
            func mergedChangeFromChanges(changes: [ResultChange<FetchedItem<T>>], deletionOrInsertion change: ResultChange<FetchedItem<T>>) -> (mergedChange: ResultChange<FetchedItem<T>>, obsoleteIndex: Int)? {
                let obsoleteIndex = changes.indexOf { earlierChange in
                    return earlierChange.isMoveCounterpart(change, identityComparator: { (lhs, rhs) in return identityComparator(lhs.result, rhs.result) })
                }
                if let obsoleteIndex = obsoleteIndex {
                    switch (changes[obsoleteIndex], change) {
                    case (.Deletion(let deletedItem, let from), .Insertion(let insertedItem, let to)):
                        let rowChanges = changedValues(from: deletedItem.row, to: insertedItem.row)
                        if from == to {
                            return (ResultChange.Update(item: insertedItem, at: from, changes: rowChanges), obsoleteIndex)
                        } else {
                            return (ResultChange.Move(item: insertedItem, from: from, to: to, changes: rowChanges), obsoleteIndex)
                        }
                    case (.Insertion(let insertedItem, let to), .Deletion(let deletedItem, let from)):
                        let rowChanges = changedValues(from: deletedItem.row, to: insertedItem.row)
                        if from == to {
                            return (ResultChange.Update(item: insertedItem, at: from, changes: rowChanges), obsoleteIndex)
                        } else {
                            return (ResultChange.Move(item: insertedItem, from: from, to: to, changes: rowChanges), obsoleteIndex)
                        }
                    default:
                        break
                    }
                }
                return nil
            }
            
            // Updates must be pushed at the end
            var mergedChanges: [ResultChange<FetchedItem<T>>] = []
            var updateChanges: [ResultChange<FetchedItem<T>>] = []
            for change in changes {
                if let (mergedChange, obsoleteIndex) = mergedChangeFromChanges(mergedChanges, deletionOrInsertion: change) {
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
        
        // NSFetchResultsController sometimes add some extra notifications
        // We'll see in the future if it is needed or not
        //for (sIndex, sItem) in s.enumerate() {
        //    if let tIndex = t.indexOf(sItem) as? Int where tIndex != sIndex {
        //        var shouldAdd = true
        //        for edit in reducedAndOrdoredEdits {
        //            switch edit.operation {
        //            case .Move:
        //                if edit.value == sItem {
        //                    shouldAdd = false
        //                }
        //            default: break
        //            }
        //        }
        //
        //        if shouldAdd {
        //            // TODO! get value from destination array!!!!
        //            let move = Edit(.Move(origin: sIndex), value: sItem, destination: tIndex)
        //            print("Added extra \(move)")
        //            reducedAndOrdoredEdits.append(move)
        //        }
        //    }
        //}
    }
}

// MARK: - <TransactionObserverType>
extension FetchedResultsController : TransactionObserverType {
    public func databaseDidChangeWithEvent(event: DatabaseEvent) {
        if let observedTables = observedTables where observedTables.contains(event.tableName) {
            fetchedItemsDidChange = true
        }
    }
    
    public func databaseWillCommit() throws { }
    
    public func databaseDidRollback(db: Database) {
        fetchedItemsDidChange = false
    }
    
    public func databaseDidCommit(db: Database) {
        guard fetchedItemsDidChange else {
            return
        }
        
        let statement = try! source.selectStatement(db)
        let newItems = FetchedItem<T>.fetchAll(statement)
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let oldItems = self.fetchedItems!
            let changes = FetchedResultsController.computeChanges(fromRows: oldItems, toRows: newItems, identityComparator: self.identityComparator)
            guard !changes.isEmpty else {
                return
            }

            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.controllerWillUpdate(self)
                
                // after controllerWillUpdate
                self.fetchedItems = newItems
                
                // notify all updates
                for update in changes { // TODO: use consistent name ("change" or "update", we need to choose)
                    self.delegate?.controllerUpdate(self, update: update.map { $0.result })
                }
                
                // done
                self.delegate?.controllerDidFinishUpdates(self)
            }
        }
    }
}


public protocol FetchedResultsControllerDelegate : class {
    func controllerWillUpdate<T>(controller: FetchedResultsController<T>)
    func controllerUpdate<T>(controller: FetchedResultsController<T>, update: ResultChange<T>)
    func controllerDidFinishUpdates<T>(controller: FetchedResultsController<T>)
}


public extension FetchedResultsControllerDelegate {
    func controllerWillUpdate<T>(controller: FetchedResultsController<T>) {}
    func controllerUpdate<T>(controller: FetchedResultsController<T>, update: ResultChange<T>) {}
    func controllerDidFinishUpdates<T>(controller: FetchedResultsController<T>) {}
}


public enum ResultChange<T> {
    case Insertion(item:T, at: NSIndexPath)
    case Deletion(item:T, at: NSIndexPath)
    // TODO: A Move can come with changes
    case Move(item:T, from: NSIndexPath, to: NSIndexPath, changes: [String: DatabaseValue])
    case Update(item:T, at: NSIndexPath, changes: [String: DatabaseValue])
}

extension ResultChange {
    func map<U>(@noescape transform: T throws -> U) rethrows -> ResultChange<U> {
        switch self {
        case .Insertion(item: let item, at: let indexPath):
            return try .Insertion(item: transform(item), at: indexPath)
        case .Deletion(item: let item, at: let indexPath):
            return try .Deletion(item: transform(item), at: indexPath)
        case .Move(item: let item, from: let from, to: let to, changes: let changes):
            return try .Move(item: transform(item), from: from, to: to, changes: changes)
        case .Update(item: let item, at: let indexPath, changes: let changes):
            return try .Update(item: transform(item), at: indexPath, changes: changes)
        }
    }
}

extension ResultChange {
    func isMoveCounterpart(otherChange: ResultChange<T>, identityComparator: (T, T) -> Bool) -> Bool {
        switch (self, otherChange) {
        case (.Deletion(let deletedItem, _), .Insertion(let insertedItem, _)):
            return identityComparator(deletedItem, insertedItem)
        case (.Insertion(let insertedItem, _), .Deletion(let deletedItem, _)):
            return identityComparator(deletedItem, insertedItem)
        default:
            return false
        }
    }
}

extension ResultChange: CustomStringConvertible {
    public var description: String {
        switch self {
        case .Insertion(let item, let at):
            return "INSERTED \(item) AT index \(at.row)"
            
        case .Deletion(let item, let at):
            return "DELETED \(item) FROM index \(at.row)"
            
        case .Move(let item, let from, let to, changes: let changes):
            return "MOVED \(item) FROM index \(from.row) TO index \(to.row) WITH CHANGES: \(changes)"
            
        case .Update(let item, let at, let changes):
            return "UPDATED \(item) AT index \(at.row) WITH CHANGES: \(changes)"
        }
    }
}

//public func ==<T: Equatable>(lhs: ResultChange<T>, rhs: ResultChange<T>) -> Bool {
//    switch (lhs, rhs) {
//    case (.Insertion(let lhsResult, let lhsIndexPath), .Insertion(let rhsResult, let rhsIndexPath)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
//    case (.Deletion(let lhsResult, let lhsIndexPath), .Deletion(let rhsResult, let rhsIndexPath)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
//    case (.Move(let lhsResult, let lhsFromIndexPath, let lhsToIndexPath), .Move(let rhsResult, let rhsFromIndexPath, let rhsToIndexPath)) where lhsResult == rhsResult && lhsFromIndexPath == rhsFromIndexPath && lhsToIndexPath == rhsToIndexPath : return true
//    case (.Update(let lhsResult, let lhsIndexPath, _), .Update(let rhsResult, let rhsIndexPath, _)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
//    default: return false
//    }
//}
