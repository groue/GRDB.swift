//
//  FetchedResultsController.swift
//  GRDB
//
//  Created by Pascal Edmond on 09/12/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public typealias FetchedResult = protocol<RowConvertible, DatabaseTableMapping, Equatable>

public class FetchedResultsController<T: FetchedResult> {
    
    // MARK: - Initialization
    public required init(sql: String, databaseQueue: DatabaseQueue) {
        self.sql = sql
        self.databaseQueue = databaseQueue
    }
    
    deinit {
        
        // TODO! : What if it is called in dbQueue ?
        // Remove for observation
        databaseQueue.inDatabase { db in
            db.removeTransactionObserver(self)
        }
    }
    
    public func performFetch() {
        
        // TODO! : This can be called several times
        // Install for observation
        databaseQueue.inDatabase { db in
            db.addTransactionObserver(self)
        }
        
        fetchedResults = databaseQueue.inDatabase { db in
            T.fetchAll(db, self.sql)
        }
    }
    
    
    // MARK: - Configuration

    /// The SQL query
    public let sql: String

    /// The databaseQueue
    public let databaseQueue: DatabaseQueue
    
    /// Delegate that is notified when the records set changes.
    weak public var delegate: FetchedResultsControllerDelegate?
    
    
    // MARK: - Accessing records

    /// Returns the results of the query.
    /// Returns nil if the performQuery: hasn't been called.
    public private(set) var fetchedResults: [T]?

    
    /// Returns the fetched object at a given indexPath.
    public func recordAtIndexPath(indexPath: NSIndexPath) -> T? {
        if let record = fetchedResults?[indexPath.indexAtPosition(1)] {
            return record
        } else {
            return nil
        }
    }
    
    /// Returns the indexPath of a given object.
    public func indexPathForRecord(record: T) -> NSIndexPath? {
        return nil
    }


    // MARK: - Not public
    
    func fetchRecords() -> [T] {
        return databaseQueue.inDatabase { db in
            T.fetchAll(db, self.sql)
        }
    }
    
    func diff(fromRows s: [T], toRows t: [T]) -> [Change<T>] {
        
        /// Returns a potential move `Change` based on an array of `Change` elements and an `update` to match up against.
        /// If `update` is a deletion or an insertion, and there is a matching inverse insertion/deletion with the same value in the array, a corresponding `.Move` update is returned.
        /// As a convenience, the index of the matched edit into `edits` is returned as well.
        func moveFromChanges(updates: [Change<T>], deletionOrInsertion update: Change<T>) -> (move: Change<T>, index: Int)? {
            if let inverseIndex = updates.indexOf({ (earlierChange) -> Bool in return earlierChange.isInverse(update) }) {
                switch updates[inverseIndex] {
                case .Deletion(_, let from):
                    switch update {
                    case .Insertion(let insertedItem, let to):
                        return (Change.Move(item: insertedItem, from: from, to: to), inverseIndex)
                    default:
                        break
                    }
                case .Insertion(let insertedItem, let to):
                    switch update {
                    case .Deletion(_, let from):
                        return (Change.Move(item: insertedItem, from: from, to: to), inverseIndex)
                    default:
                        break
                    }
                default:
                    break
                }
            }
            return nil
        }
        
        /// Returns an array where deletion/insertion pairs of the same element are replaced by `.Move` change.
        func reducedChanges(updates: [Change<T>]) -> [Change<T>] {
            return updates.reduce([Change<T>]()) { (var reducedChanges, update) in
                if let (moveChange, index) = moveFromChanges(reducedChanges, deletionOrInsertion: update), case .Move = moveChange {
                    reducedChanges.removeAtIndex(index)
                    reducedChanges.append(moveChange)
                } else {
                    reducedChanges.append(update)
                }
                return reducedChanges
            }
        }

        
        let sourceCount = s.count
        let targetCount = t.count
        
        // Fill first row and column of insertions and deletions.
        
        var d: [[[Change<T>]]] = Array(count: sourceCount + 1, repeatedValue: Array(count: targetCount + 1, repeatedValue: []))
        
        var edits = [Change<T>]()
        for (row, element) in s.enumerate() {
            let deletion = Change.Deletion(item: element, at: NSIndexPath(indexes:[0,row], length:2))
            edits.append(deletion)
            d[row + 1][0] = edits
        }
        
        edits.removeAll()
        for (col, element) in t.enumerate() {
            let insertion = Change.Insertion(item: element, at: NSIndexPath(indexes:[0,col], length:2))
            edits.append(insertion)
            d[0][col + 1] = edits
        }
        
        guard sourceCount > 0 && targetCount > 0 else { return d[sourceCount][targetCount] }
        
        // Indexes into the two collections.
        var sx: Array<T>.Index
        var tx = t.startIndex
        
        
        // Fill body of matrix.
        for j in 1...targetCount {
            sx = s.startIndex
            
            for i in 1...sourceCount {
                if s[sx] == t[tx] {
                    // TODO! : Update
                    /* if let oldRecord = s[sx] as? Record, let newRecord = t[tx] as? Record {
                        let newRecordCopy = newRecord.copy()
                        newRecordCopy.referenceRow = oldRecord.referenceRow
                        let changes = newRecordCopy.persistentChangedValues
                        if  changes.count > 0 {
                            let update = Change.Update(item: t[tx], at: NSIndexPath(indexes:[0,i-1], length:2), changes: changes)
                            updates.append(update)
                        }
                    }*/
                    
                    d[i][j] = d[i - 1][j - 1] // no operation
                } else {
                    
                    var del = d[i - 1][j] // a deletion
                    var ins = d[i][j - 1] // an insertion
                    var sub = d[i - 1][j - 1] // a substitution
                    
                    // Record operation.
                    
                    let minimumCount = min(del.count, ins.count, sub.count)
                    if del.count == minimumCount {
                        let deletion = Change.Deletion(item: s[sx], at: NSIndexPath(indexes:[0,i-1], length:2))
                        del.append(deletion)
                        d[i][j] = del
                    } else if ins.count == minimumCount {
                        let insertion = Change.Insertion(item: t[tx], at: NSIndexPath(indexes:[0,j-1], length:2))
                        ins.append(insertion)
                        d[i][j] = ins
                    } else {
                        // TODO! : We dont want substitution, we want deletion and insertion
                        // print("Substitution => item =\(t[tx]), destination= \(j - 1)")
                        // let substitution = Edit(.Substitution, value: t[tx], destination: j - 1)
                        // sub.append(substitution)
                        // d[i][j] = sub
                    }
                }
                
                sx = sx.advancedBy(1)
            }
            
            tx = tx.advancedBy(1)
        }
        
        // Convert deletion/insertion pairs of same element into moves.
        return reducedChanges(d[sourceCount][targetCount])
    }
}

// MARK: - <TransactionObserverType>
extension FetchedResultsController : TransactionObserverType {
    public func databaseDidChangeWithEvent(event: DatabaseEvent) { }
    public func databaseWillCommit() throws { }
    public func databaseDidRollback(db: Database) { }
    public func databaseDidCommit(db: Database) {
        let newRecords = T.fetchAll(db, self.sql)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let oldRecords = self.fetchedResults
            
            // horrible diff computation
            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.controllerWillUpdate(self)
                
                // after controllerWillChangeContent
                self.fetchedResults = newRecords
                
                // notify horrible diff computation
                for update in self.diff(fromRows: oldRecords!, toRows: newRecords) {
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
    func controllerUpdate<T>(controller: FetchedResultsController<T>, update: Change<T>)
    func controllerDidFinishUpdates<T>(controller: FetchedResultsController<T>)
}


public extension FetchedResultsControllerDelegate {
    func controllerWillUpdate<T>(controller: FetchedResultsController<T>) {}
    func controllerUpdate<T>(controller: FetchedResultsController<T>, update: Change<T>) {}
    func controllerDidFinishUpdates<T>(controller: FetchedResultsController<T>) {}
}


public enum Change<T: FetchedResult> {
    case Insertion(item:T, at: NSIndexPath)
    case Deletion(item:T, at: NSIndexPath)
    case Move(item:T, from: NSIndexPath, to: NSIndexPath)
    case Update(item:T, at: NSIndexPath, changes: [String: DatabaseValue?]?)
    
    var description: String {
        switch self {
        case .Insertion(let item, let at):
            return "Inserted \(item) at indexpath \(at)"
            
        case .Deletion(let item, let at):
            return "Deleted \(item) from indexpath \(at)"
            
        case .Move(let item, let from, let to):
            return "Moved \(item) from indexpath \(from) to indexpath \(to)"
            
        case .Update(let item, let at, let changes):
            return "Updated \(changes) of \(item) at indexpath \(at)"
        }
    }
    
    func isInverse(otherChange: Change<T>) -> Bool {
        
        switch (self, otherChange) {
        case (.Deletion(let deletedItem, let from), .Insertion(let insertedItem, let to)): return (deletedItem == insertedItem && to == from)
        case (.Insertion(let insertedItem, let to), .Deletion(let deletedItem, let from)): return (deletedItem == insertedItem && to == from)
        case (.Move(let item1, let from1, let to1), .Move(let item2, let from2, let to2)): return (item1 == item2 && from1 == to2 && to1 == from2)
        default: break
        }
        
        return false
    }
}

func ==<T>(lhs: Change<T>, rhs: Change<T>) -> Bool {
    switch (lhs, rhs) {
    case (.Insertion(let lhsResult, let lhsIndexPath), .Insertion(let rhsResult, let rhsIndexPath)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
    case (.Deletion(let lhsResult, let lhsIndexPath), .Deletion(let rhsResult, let rhsIndexPath)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
    case (.Move(let lhsResult, let lhsFromIndexPath, let lhsToIndexPath), .Move(let rhsResult, let rhsFromIndexPath, let rhsToIndexPath)) where lhsResult == rhsResult && lhsFromIndexPath == rhsFromIndexPath && lhsToIndexPath == rhsToIndexPath : return true
    case (.Update(let lhsResult, let lhsIndexPath, _), .Update(let rhsResult, let rhsIndexPath, _)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
    default: return false
    }
}
