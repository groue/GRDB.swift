//
//  Queue.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public class DatabaseQueue {
    public var database: Database { return _database! }
    private let queue: dispatch_queue_t
    private var _database: Database! = nil
    
    public init(path: String, configuration: DatabaseConfiguration = DatabaseConfiguration()) throws {
        queue = dispatch_queue_create("GRDB", nil)
        _database = try Database(path: path, configuration: configuration)
    }
    
    public func inDatabase(block: (db: Database) throws -> Void) throws {
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
    
    public func inTransaction(type: Database.TransactionType = .Exclusive, block: (db: Database) throws -> Void) throws {
        var dbError: ErrorType?
        let database = self.database
        dispatch_sync(queue) { () -> Void in
            do {
                try database.inTransaction(type) { () in
                    try block(db: database)
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
