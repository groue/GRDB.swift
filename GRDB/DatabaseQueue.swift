//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


typealias DatabaseQueueID = UnsafeMutablePointer<Void>

public final class DatabaseQueue {
    private var database: Database { return _database! }
    private let queue: dispatch_queue_t
    private var _database: Database! = nil
    static var databaseQueueIDKey = unsafeBitCast(DatabaseQueue.self, UnsafePointer<Void>.self)
    private lazy var databaseQueueID: DatabaseQueueID = unsafeBitCast(self, DatabaseQueueID.self)
    
    public convenience init(path: String, configuration: Configuration = Configuration()) throws {
        try self.init(database: Database(path: path, configuration: configuration))
    }
    
    public convenience init(configuration: Configuration = Configuration()) {
        self.init(database: Database(configuration: configuration))
    }
    
    init(database: Database) {
        queue = dispatch_queue_create("GRDB", nil)
        _database = database
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
    
    public func inDatabase(block: (db: Database) -> Void) {
        guard databaseQueueID != dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
            fatalError("inDatabase(_:) was called reentrantly on the same queue, which would lead to a deadlock")
        }
        
        dispatch_sync(queue) { () -> Void in
            block(db: self.database)
        }
    }
    
    public func inDatabase<Result>(block: (db: Database) -> Result) -> Result {
        guard databaseQueueID != dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
            fatalError("inDatabase(_:) was called reentrantly on the same queue, which would lead to a deadlock")
        }
        
        var result: Result? = nil
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
