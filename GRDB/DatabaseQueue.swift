//
//  Queue.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

typealias DatabaseQueueID = UnsafeMutablePointer<Void>

public class DatabaseQueue {
    public var database: Database { return _database! }
    private let queue: dispatch_queue_t
    private var _database: Database! = nil
    static var databaseQueueIDKey = unsafeBitCast(DatabaseQueue.self, UnsafePointer<Void>.self)
    lazy var databaseQueueID: DatabaseQueueID = unsafeBitCast(self, DatabaseQueueID.self)
    
    public init(path: String, configuration: DatabaseConfiguration = DatabaseConfiguration()) throws {
        queue = dispatch_queue_create("GRDB", nil)
        _database = try Database(path: path, configuration: configuration)
        dispatch_queue_set_specific(queue, DatabaseQueue.databaseQueueIDKey, databaseQueueID, nil)
    }
    
    public func inDatabase(block: (db: Database) throws -> Void) throws {
        guard databaseQueueID != dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
            fatalError("inDatabase(_:) was called reentrantly on the same queue, which would lead to a deadlock")
        }
        
        var dbError: ErrorType?
        dispatch_sync(queue) { () -> Void in
            do {
                try block(db: self.database)
            } catch {
                dbError = error
            }
        }
        if let dbError = dbError {
            throw dbError
        }
    }
    
    public func inDatabase<R>(block: (db: Database) -> R) -> R {
        guard databaseQueueID != dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
            fatalError("inDatabase(_:) was called reentrantly on the same queue, which would lead to a deadlock")
        }
        
        var result: R? = nil
        dispatch_sync(queue) { () -> Void in
            result = block(db: self.database)
        }
        return result!
    }
    
    public func inTransaction(type: Database.TransactionType = .Exclusive, block: (db: Database) throws -> Database.TransactionCompletion) throws {
        guard databaseQueueID != dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
            fatalError("inDatabase(_:) was called reentrantly on the same queue, which would lead to a deadlock")
        }
        
        var dbError: ErrorType?
        let database = self.database
        dispatch_sync(queue) { () -> Void in
            do {
                try database.inTransaction(type) { () in
                    return try block(db: database)
                }
            } catch {
                dbError = error
            }
        }
        if let dbError = dbError {
            throw dbError
        }
    }
}
