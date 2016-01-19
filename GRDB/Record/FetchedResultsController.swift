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
                case .Deleted(_, let from):
                    switch update {
                    case .Inserted(let insertedItem, let to):
                        //(Edit(.Move(origin: edit.destination), value: edit.value, destination: edits[insertionIndex].destination), insertionIndex)
                        return (Change.Moved(item: insertedItem, from: from, to: to), inverseIndex)
                    default:
                        break
                    }
                case .Inserted(let insertedItem, let to):
                    switch update {
                    case .Deleted(_, let from):
                        //(Edit(.Move(origin: edit.destination), value: edit.value, destination: edits[insertionIndex].destination), insertionIndex)
                        return (Change.Moved(item: insertedItem, from: from, to: to), inverseIndex)
                    default:
                        break
                    }
                default:
                    break
                }
            }
            return nil
        }
        
        /// Returns an array where deletion/insertion pairs of the same element are replaced by `.Move` edits.
        func reducedChanges(updates: [Change<T>]) -> [Change<T>] {
            return updates.reduce([Change<T>]()) { (var reducedChanges, update) in
                if let (moveChange, index) = moveFromChanges(reducedChanges, deletionOrInsertion: update), case .Moved = moveChange {
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
            let deletion = Change.Deleted(item: element, at: NSIndexPath(indexes:[0,row], length:2)) // Edit(.Deletion, value: element, destination: row)
            edits.append(deletion)
            d[row + 1][0] = edits
        }
        
        edits.removeAll()
        for (col, element) in t.enumerate() {
            let insertion = Change.Inserted(item: element, at: NSIndexPath(indexes:[0,col], length:2)) // Edit(.Insertion, value: element, destination: col)
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
                    // TODO! : Make Update operation
                    d[i][j] = d[i - 1][j - 1] // no operation
                } else {
                    
                    var del = d[i - 1][j] // a deletion
                    var ins = d[i][j - 1] // an insertion
                    var sub = d[i - 1][j - 1] // a substitution
                    
                    // Record operation.
                    
                    let minimumCount = min(del.count, ins.count, sub.count)
                    if del.count == minimumCount {
                        let deletion = Change.Deleted(item: s[sx], at: NSIndexPath(indexes:[0,i-1], length:2)) // Edit(.Deletion, value: s[sx], destination: i - 1)
                        del.append(deletion)
                        d[i][j] = del
                    } else if ins.count == minimumCount {
                        let insertion = Change.Inserted(item: t[tx], at: NSIndexPath(indexes:[0,j-1], length:2)) // Edit(.Insertion, value: t[tx], destination: j - 1)
                        ins.append(insertion)
                        d[i][j] = ins
                    } else {
                        // TODO! : We dont want substitution, we want deletion and insertion
                        print("Substitution => item =\(t[tx]), destination= \(j - 1)")
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
    case Inserted(item:T, at: NSIndexPath)
    case Deleted(item:T, at: NSIndexPath)
    case Moved(item:T, from: NSIndexPath, to: NSIndexPath)
    case Updated(item:T, at: NSIndexPath, changes: [String: DatabaseValue?]?)
    
    var description: String {
        switch self {
        case .Inserted(let item, let at):
            return "Inserted \(item) at indexpath \(at)"
            
        case .Deleted(let item, let at):
            return "Deleted \(item) from indexpath \(at)"
            
        case .Moved(let item, let from, let to):
            return "Moved \(item) from indexpath \(from) to indexpath \(to)"
            
        case .Updated(let item, let at, let changes):
            return "Updated \(changes) of \(item) at indexpath \(at)"
        }
    }
    
    func isInverse(otherChange: Change<T>) -> Bool {
        
        switch (self, otherChange) {
        case (.Deleted(let deletedItem, let from), .Inserted(let insertedItem, let to)): return (deletedItem == insertedItem && to == from)
        case (.Inserted(let insertedItem, let to), .Deleted(let deletedItem, let from)): return (deletedItem == insertedItem && to == from)
        case (.Moved(let item1, let from1, let to1), .Moved(let item2, let from2, let to2)): return (item1 == item2 && from1 == to2 && to1 == from2)
        default: break
        }
        
        return false
    }
}

func ==<T>(lhs: Change<T>, rhs: Change<T>) -> Bool {
    switch (lhs, rhs) {
    case (.Inserted(let lhsResult, let lhsIndexPath), .Inserted(let rhsResult, let rhsIndexPath)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
    case (.Deleted(let lhsResult, let lhsIndexPath), .Deleted(let rhsResult, let rhsIndexPath)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
    case (.Moved(let lhsResult, let lhsFromIndexPath, let lhsToIndexPath), .Moved(let rhsResult, let rhsFromIndexPath, let rhsToIndexPath)) where lhsResult == rhsResult && lhsFromIndexPath == rhsFromIndexPath && lhsToIndexPath == rhsToIndexPath : return true
    case (.Updated(let lhsResult, let lhsIndexPath, _), .Updated(let rhsResult, let rhsIndexPath, _)) where lhsResult == rhsResult && lhsIndexPath == rhsIndexPath : return true
    default: return false
    }
}
