//
//  FetchedRecordsController.swift
//  GRDB
//
//  Created by Pascal Edmond on 09/12/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public class FetchedRecordsController<T: protocol<RowConvertible, DatabaseTableMapping, Hashable>> {
    
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
        
        fetchedRecords = databaseQueue.inDatabase { db in
            T.fetchAll(db, self.sql)
        }
    }
    
    
    // MARK: - Configuration

    /// The SQL query
    public let sql: String

    /// The databaseQueue
    public let databaseQueue: DatabaseQueue
    
    /// Delegate that is notified when the records set changes.
    weak public var delegate: FetchedRecordsControllerDelegate?
    
    
    // MARK: - Accessing records

    /// Returns the results of the query.
    /// Returns nil if the performQuery: hasn't been called.
    public private(set) var fetchedRecords: [T]?

    
    /// Returns the fetched object at a given indexPath.
    public func recordAtIndexPath(indexPath: NSIndexPath) -> T? {
        if let record = fetchedRecords?[indexPath.indexAtPosition(1)] {
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
    
    func diff(fromRows rows: [T], toRows: [T]) -> [FetchedRecordsUpdate<T>] {
        
        var updates = [FetchedRecordsUpdate<T>]()
        var currentRecords = rows
        let finalIndexPathForItem: [T:NSIndexPath]!
        var currentIndexPathForItem: [T:NSIndexPath]!
        
        func indexPaths(items: [T]) -> [T:NSIndexPath] {
            var indexPathForItem = [T:NSIndexPath]()
            for (index, item) in items.enumerate() {
                let indexPath = NSIndexPath(indexes: [0,index], length: 2)
                indexPathForItem[item] = indexPath
            }
            return indexPathForItem
        }
        
        func apply(update: FetchedRecordsUpdate<T>) {
            currentRecords.applyUpdate(update)
            currentIndexPathForItem = indexPaths(currentRecords)
        }
        
        finalIndexPathForItem = indexPaths(toRows)
        currentIndexPathForItem = indexPaths(currentRecords)
        
        // 2 - INSERTS
        for item: T in toRows {
            if let _ = currentIndexPathForItem[item] {
                // item was there
            } else {
                guard let newIndexPath = finalIndexPathForItem[item] else {
                    fatalError()
                }
                
                let update = FetchedRecordsUpdate.Inserted(item: item, at: newIndexPath)
                updates.append(update)
                apply(update)
            }
        }
        
        // 3 - DELETES, MOVES & RELOAD
        for oldItem: T in currentRecords {
            
            guard let oldIndexPath = currentIndexPathForItem[oldItem] else {
                fatalError()
            }

            if let index = finalIndexPathForItem.indexForKey(oldItem) {
                let (newItem, newIndexPath) = finalIndexPathForItem[index]
                if oldIndexPath == newIndexPath {
                    if let oldRecord = oldItem as? Record, let newRecord = newItem as? Record {
                        let recordCopy = newRecord.copy()
                        recordCopy.referenceRow = oldRecord.referenceRow
                        let changes = recordCopy.persistentChangedValues
                        if changes.count > 0 {
                            let update = FetchedRecordsUpdate.Updated(item: newItem, at: newIndexPath, changes: changes)
                            updates.append(update)
                            apply(update)
                        }
                    } else {
                        // Not a record
                        let update = FetchedRecordsUpdate.Updated(item: newItem, at: newIndexPath, changes: nil)
                        updates.append(update)
                        apply(update)
                    }
                } else {
                    // item moved
                    let update = FetchedRecordsUpdate.Moved(item: newItem, from: oldIndexPath, to: newIndexPath)
                    updates.append(update)
                    apply(update)
                }
            } else {
                // item deleted
                let update = FetchedRecordsUpdate.Deleted(item: oldItem, at: oldIndexPath)
                updates.append(update)
                apply(update)
            }
        }
        
        return updates
    }
}


extension FetchedRecordsController : TransactionObserverType {
    public func databaseDidChangeWithEvent(event: DatabaseEvent) { }
    public func databaseWillCommit() throws { }
    public func databaseDidRollback(db: Database) { }
    public func databaseDidCommit(db: Database) {
        let newRecords = T.fetchAll(db, self.sql)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let oldRecords = self.fetchedRecords
            
            // horrible diff computation
            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.controllerWillUpdate(self)
                
                // after controllerWillChangeContent
                self.fetchedRecords = newRecords
                
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


public protocol FetchedRecordsControllerDelegate : class {
    func controllerWillUpdate<T>(controller: FetchedRecordsController<T>)
    func controllerUpdate<T>(controller: FetchedRecordsController<T>, update: FetchedRecordsUpdate<T>)
    func controllerDidFinishUpdates<T>(controller: FetchedRecordsController<T>)
}


public extension FetchedRecordsControllerDelegate {
    func controllerWillUpdate<T>(controller: FetchedRecordsController<T>) {}
    func controllerUpdate<T>(controller: FetchedRecordsController<T>, update: FetchedRecordsUpdate<T>) {}
    func controllerDidFinishUpdates<T>(controller: FetchedRecordsController<T>) {}
}


public enum FetchedRecordsUpdate<T> {
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
}

extension Array {
    mutating func applyUpdate(update: FetchedRecordsUpdate<Array.Generator.Element>) {
        switch update {
        case .Inserted(let item, let at):
            self.insert(item, atIndex: at.indexAtPosition(1))
            
        case .Deleted(_, let from):
            self.removeAtIndex(from.indexAtPosition(1))
            
        case .Moved(let item, let from, let to):
            self.removeAtIndex(from.indexAtPosition(1))
            self.insert(item, atIndex: to.indexAtPosition(1))
            
        case .Updated(_, _, _): break
        }
        // print(update.description)
    }
}

