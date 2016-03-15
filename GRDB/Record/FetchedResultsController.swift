//
//  FetchedResultsController.swift
//  GRDB
//
//  Created by Pascal Edmond on 09/12/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//
import UIKit

public typealias FetchedResult = protocol<RowConvertible, TableMapping, Equatable>

private enum Source<T: FetchedResult> {
    case SQL(String, StatementArguments?)
    case FetchRequest(GRDB.FetchRequest<T>)

    func fetchAll(db: DatabaseReader) -> [T] {
        switch self {
        case .SQL(let sql, let arguments):
            return T.fetchAll(db, sql, arguments: arguments)
        case .FetchRequest(let fetchRequest):
            return fetchRequest.fetchAll(db)
        }
    }
}

public class FetchedResultsController<T: FetchedResult> {
    
    // MARK: - Initialization
    public convenience init(database: DatabaseWriter, sql: String, arguments: StatementArguments? = nil) {
        let source: Source<T> = .SQL(sql, arguments)
        self.init(database: database, source: source)
    }
    
    public convenience init(database: DatabaseWriter, fetchRequest: FetchRequest<T>) {
        let source: Source<T> = .FetchRequest(fetchRequest)
        self.init(database: database, source: source)
    }
    
    private init(database: DatabaseWriter, source: Source<T>) {
        self.source = source
        self.database = database
        database.addTransactionObserver(self)
    }
    
    public func performFetch() {
        fetchedResults = self.fetch()
    }
    
    
    // MARK: - Configuration
    
    /// The source
    private let source: Source<T>

    /// The databaseWriter
    public let database: DatabaseWriter
    
    /// Delegate that is notified when the resultss set changes.
    weak public var delegate: FetchedResultsControllerDelegate?
    
    
    // MARK: - Accessing results

    /// Returns the results of the query.
    /// Returns nil if the performQuery: hasn't been called.
    public private(set) var fetchedResults: [T]?

    
    /// Returns the fetched object at a given indexPath.
    public func resultAtIndexPath(indexPath: NSIndexPath) -> T? {
        if let result = fetchedResults?[indexPath.indexAtPosition(1)] {
            return result
        } else {
            return nil
        }
    }
    
    /// Returns the indexPath of a given object.
    public func indexPathForResult(result: T) -> NSIndexPath? {
        // TODO
        fatalError("Not implemented")
    }

    public func changesAreEquivalent(change: ResultChange<T>, otherChange: ResultChange<T>) -> Bool {
        switch (change, otherChange) {
        case (.Move(let item1, let from1, let to1), .Move(let item2, let from2, let to2)):
            return (from1 == to2 && to1 == from2 && item1 == resultAtIndexPath(from2) && item2 == resultAtIndexPath(from1))
        default:
            return false
        }
    }

    // MARK: - Not public
    
    func fetch() -> [T] {
        return source.fetchAll(database)
    }
    
    static func computeChanges(fromRows s: [T], toRows t: [T]) -> [ResultChange<T>] {
        
        let m = s.count
        let n = t.count
        
        // Fill first row and column of insertions and deletions.
        
        var d: [[[ResultChange<T>]]] = Array(count: m + 1, repeatedValue: Array(count: n + 1, repeatedValue: []))
        
        var changes = [ResultChange<T>]()
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
        
        /// Returns an array where deletion/insertion pairs of the same element are replaced by `.Move` change.
        func standardizeChanges(changes: [ResultChange<T>]) -> [ResultChange<T>] {
            
            /// Returns a potential .Move `ResultChange` based on an array of `ResultChange` elements and a `ResultChange` to match up against.
            /// If `deletionOrInsertion` is a deletion or an insertion, and there is a matching inverse insertion/deletion with the same value in the array, a corresponding `.Move` update is returned.
            /// As a convenience, the index of the matched `ResultChange` into `changes` is returned as well.
            func moveFromChanges(changes: [ResultChange<T>], deletionOrInsertion change: ResultChange<T>) -> (move: ResultChange<T>, index: Int)? {
                if let inverseIndex = changes.indexOf({ (earlierChange) -> Bool in return earlierChange.isMoveCounterpart(change) }) {
                    switch changes[inverseIndex] {
                    case .Deletion(_, let from):
                        switch change {
                        case .Insertion(let insertedItem, let to):
                            return (ResultChange.Move(item: insertedItem, from: from, to: to), inverseIndex)
                        default:
                            break
                        }
                    case .Insertion(let insertedItem, let to):
                        switch change {
                        case .Deletion(_, let from):
                            return (ResultChange.Move(item: insertedItem, from: from, to: to), inverseIndex)
                        default:
                            break
                        }
                    default:
                        break
                    }
                }
                return nil
            }
            
            return changes.reduce([ResultChange<T>]()) { (var reducedChanges, update) in
                if let (move, index) = moveFromChanges(reducedChanges, deletionOrInsertion: update) {
                    reducedChanges.removeAtIndex(index)
                    reducedChanges.append(move)
                } else {
                    reducedChanges.append(update)
                }
                return reducedChanges
            }
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
    public func databaseDidChangeWithEvent(event: DatabaseEvent) { }
    public func databaseWillCommit() throws { }
    public func databaseDidRollback(db: Database) { }
    public func databaseDidCommit(db: Database) {
        let newResults = source.fetchAll(db)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let oldResults = self.fetchedResults

            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.controllerWillUpdate(self)
                
                // after controllerWillChangeContent
                self.fetchedResults = newResults
                
                // notify all updates
                for update in FetchedResultsController.computeChanges(fromRows: oldResults!, toRows: newResults) {
                    self.delegate?.controllerUpdate(self, update: update)
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


public enum ResultChange<T: FetchedResult> {
    case Insertion(item:T, at: NSIndexPath)
    case Deletion(item:T, at: NSIndexPath)
    case Move(item:T, from: NSIndexPath, to: NSIndexPath)
    case Update(item:T, at: NSIndexPath, changes: [String: DatabaseValue?]?)
    
    func isMoveCounterpart(otherChange: ResultChange<T>) -> Bool {
        switch (self, otherChange) {
        case (.Deletion(let deletedItem, _), .Insertion(let insertedItem, _)):
            return (deletedItem == insertedItem)
        case (.Insertion(let insertedItem, _), .Deletion(let deletedItem, _)):
            return (deletedItem == insertedItem)
        default:
            return false
        }
    }
    
    func isRelativeToSameResult(otherChange: ResultChange<T>) -> Bool {
        switch self {
        case .Insertion(let item, _):
            switch otherChange {
            case .Insertion(let otherItem, _): return item == otherItem
            case .Deletion(let otherItem, _): return item == otherItem
            case .Move(let otherItem, _, _): return item == otherItem
            case .Update(let otherItem, _, _): return item == otherItem
            }
        case .Deletion(let item, _):
            switch otherChange {
            case .Insertion(let otherItem, _): return item == otherItem
            case .Deletion(let otherItem, _): return item == otherItem
            case .Move(let otherItem, _, _): return item == otherItem
            case .Update(let otherItem, _, _): return item == otherItem
            }
        case .Move(let item, _, _):
            switch otherChange {
            case .Insertion(let otherItem, _): return item == otherItem
            case .Deletion(let otherItem, _): return item == otherItem
            case .Move(let otherItem, _, _): return item == otherItem
            case .Update(let otherItem, _, _): return item == otherItem
            }
        case .Update(let item, _, _):
            switch otherChange {
            case .Insertion(let otherItem, _): return item == otherItem
            case .Deletion(let otherItem, _): return item == otherItem
            case .Move(let otherItem, _, _): return item == otherItem
            case .Update(let otherItem, _, _): return item == otherItem
            }
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
            
        case .Move(let item, let from, let to):
            return "MOVED \(item) FROM index \(from.row) TO index \(to.row)"
            
        case .Update(let item, let at, let changes):
            return "UPDATED \(changes) OF \(item) AT index \(at.row)"
        }
    }
}

public func ==<T>(lhs: ResultChange<T>, rhs: ResultChange<T>) -> Bool {
    switch (lhs, rhs) {
    case (.Insertion(let lhsResult, let lhsIndexPath), .Insertion(let rhsResult, let rhsIndexPath)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
    case (.Deletion(let lhsResult, let lhsIndexPath), .Deletion(let rhsResult, let rhsIndexPath)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
    case (.Move(let lhsResult, let lhsFromIndexPath, let lhsToIndexPath), .Move(let rhsResult, let rhsFromIndexPath, let rhsToIndexPath)) where lhsResult == rhsResult && lhsFromIndexPath == rhsFromIndexPath && lhsToIndexPath == rhsToIndexPath : return true
    case (.Update(let lhsResult, let lhsIndexPath, _), .Update(let rhsResult, let rhsIndexPath, _)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
    default: return false
    }
}
