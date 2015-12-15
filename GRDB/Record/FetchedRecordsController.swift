//
//  FetchedRecordsController.swift
//  GRDB
//
//  Created by Pascal Edmond on 09/12/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import UIKit

public class FetchedRecordsController<T: protocol<RowConvertible, DatabaseTableMapping, Hashable>> {
    
    // MARK: - Initialization
    public required init(sql: String, databaseQueue: DatabaseQueue) {
        self.sql = sql
        self.databaseQueue = databaseQueue
    }
    
    public func performFetch() {
        
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
        if let record = fetchedRecords?[indexPath.row] {
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
    
    func calculateUpdatesFrom(fromRecords: [T], toRecords: [T]) -> [FetchedRecordsUpdate<T>] {
        
        var updates = [FetchedRecordsUpdate<T>]()
        var currentRecords = fromRecords
        let finalIndexPathForItem: [T:NSIndexPath]!
        var currentIndexPathForItem: [T:NSIndexPath]!
        
        func indexPaths(items: [T]) -> [T:NSIndexPath] {
            var indexPathForItem = [T:NSIndexPath]()
            for (index, item) in items.enumerate() {
                let indexPath = NSIndexPath(forItem: index, inSection: 0)
                indexPathForItem[item] = indexPath
            }
            return indexPathForItem
        }
        
        func apply(update: FetchedRecordsUpdate<T>) {
            currentRecords.applyUpdate(update)
            currentIndexPathForItem = indexPaths(currentRecords)
        }
        
        finalIndexPathForItem = indexPaths(toRecords)
        currentIndexPathForItem = indexPaths(currentRecords)
        
        // 2 - INSERTS
        for item: T in toRecords {
            if let _ = currentIndexPathForItem[item] {
                // item was there
            } else {
                // Insert
                guard let newIndexPath = finalIndexPathForItem[item] else {
                    print("WTF?!")
                    break
                }
                
                let update = FetchedRecordsUpdate.Insert(item: item, at: newIndexPath)
                updates.append(update)
                apply(update)
            }
        }
        
        // 3 - DELETES, MOVES & RELOAD
        for item: T in currentRecords {
            guard let oldIndexPath = currentIndexPathForItem[item] else {
                print("WTF?!")
                break
            }
            if let newIndexPath = finalIndexPathForItem[item] {
                
                if oldIndexPath == newIndexPath {
                    // item updates ?
                    // let update = FetchedRecordsUpdate.Reload(item: item, at: newIndexPath)
                    // updates.append(update)
                    // apply(update)
                } else {
                    // item moved
                    let update = FetchedRecordsUpdate.Move(item: item, from: oldIndexPath, to: newIndexPath)
                    updates.append(update)
                    apply(update)
                }
                
            } else {
                // item deleted
                let update = FetchedRecordsUpdate.Delete(item: item, from: oldIndexPath)
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
                for update in self.calculateUpdatesFrom(oldRecords!, toRecords: newRecords) {
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
    case Insert(item:T, at: NSIndexPath)
    case Delete(item:T, from: NSIndexPath)
    case Move(item:T, from: NSIndexPath, to: NSIndexPath)
    case Reload(item:T, at: NSIndexPath)
    
    var description: String {
        switch self {
        case .Insert(let item, let at):
            return "\(item) inserted at \(at)"
            
        case .Delete(let item, let from):
            return "\(item) deleted from \(from)"
            
        case .Move(let item, let from, let to):
            return "\(item) moved from \(from) to \(to)"
            
        case .Reload(let item, let at):
            return "\(item) updated at \(at)"
        }
    }
}

extension Array {
    mutating func applyUpdate(update: FetchedRecordsUpdate<Array.Generator.Element>) {
        switch update {
        case .Insert(let item, let at):
            self.insert(item, atIndex: at.item)
            
        case .Delete(_, let from):
            self.removeAtIndex(from.item)
            
        case .Move(let item, let from, let to):
            self.removeAtIndex(from.item)
            self.insert(item, atIndex: to.item)
            
        case .Reload(_, _): break
        }
        print(update.description)
    }
}

