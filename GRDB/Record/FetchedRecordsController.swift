//
//  FetchedRecordsController.swift
//  GRDB
//
//  Created by Pascal Edmond on 09/12/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import UIKit

public class FetchedRecordsController<T: DatabaseTableMapping> {
    
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
}


extension FetchedRecordsController : TransactionObserverType {
    
    public func databaseDidChangeWithEvent(event: DatabaseEvent) { }
    
    public func databaseWillCommit() throws { }

    public func databaseDidCommit(db: Database) {

        let newRecords = T.fetchAll(db, self.sql)
        print("newRecords => \(newRecords)")
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let oldRecords = self.fetchedRecords
            print("oldRecords => \(oldRecords)")
            // horrible diff computation
            
            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.controllerWillChangeContent(self)
                
                // after controllerWillChangeContent
                self.fetchedRecords = newRecords
                
                // notify horrible diff computation
                
                // done
                self.delegate?.controllerDidChangeContent(self)
            }
        }
    }
    
    public func databaseDidRollback(db: Database) { }
}

public protocol FetchedRecordsControllerDelegate : class {
    func controllerWillChangeContent<T: DatabaseTableMapping>(controller: FetchedRecordsController<T>)
    func controller<T: DatabaseTableMapping>(controller: FetchedRecordsController<T>, didChangeRecord record: T, atIndexPath indexPath: NSIndexPath?, forChangeType type: FetchedRecordsChangeType, newIndexPath: NSIndexPath?)
    func controllerDidChangeContent<T: DatabaseTableMapping>(controller: FetchedRecordsController<T>)
}

public extension FetchedRecordsControllerDelegate {
    func controllerWillChangeContent<T: DatabaseTableMapping>(controller: FetchedRecordsController<T>) {}
    func controller<T: DatabaseTableMapping>(controller: FetchedRecordsController<T>, didChangeRecord record: T, atIndexPath indexPath: NSIndexPath?, forChangeType type: FetchedRecordsChangeType, newIndexPath: NSIndexPath?) {}
    func controllerDidChangeContent<T: DatabaseTableMapping>(controller: FetchedRecordsController<T>) {}
}

public enum FetchedRecordsChangeType : UInt {
    case Insert
    case Delete
    case Move
    case Update
}
