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


/**
A Database Queue serializes access to an SQLite database.
*/
public final class DatabaseQueue {
    
    // MARK: - Configuration
    
    /// The database configuration
    public var configuration: Configuration {
        return database.configuration
    }
    
    
    // MARK: - Initializers
    
    /**
    Opens the SQLite database at path *path*.
    
        let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
    
    Database connections get closed when the database queue gets deallocated.
    
    - parameter path: The path to the database file.
    - parameter configuration: A configuration
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public convenience init(path: String, configuration: Configuration = Configuration()) throws {
        try self.init(database: Database(path: path, configuration: configuration))
    }
    
    /**
    Opens an in-memory SQLite database.
    
        let dbQueue = DatabaseQueue()
    
    Database memory is released when the database queue gets deallocated.
    
    - parameter configuration: A configuration
    */
    public convenience init(configuration: Configuration = Configuration()) {
        self.init(database: Database(configuration: configuration))
    }
    
    
    // MARK: - Database access
    
    /**
    Executes a block in the database queue.
    
        dbQueue.inDatabase { db in
            db.fetch(...)
        }

    This method is not reentrant.
    
    - parameter block: A block that accesses the databse.
    - throws: The error thrown by the block.
    */
    public func inDatabase(block: (db: Database) throws -> Void) rethrows {
        guard databaseQueueID != dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
            fatalError("DatabaseQueue.inDatabase(_:) was called reentrantly on the same queue, which would lead to a deadlock.")
        }
        
        try DatabaseQueue.performSync(queue) { () -> Void in
            try block(db: self.database)
        }
    }
    
    /**
    Executes a block in the database queue, and returns its result.
    
        let rows = dbQueue.inDatabase { db in
            db.fetch(...)
        }
    
    This method is not reentrant.
    
    - parameter block: A block that accesses the databse.
    - throws: The error thrown by the block.
    */
    public func inDatabase<R>(block: (db: Database) throws -> R) rethrows -> R {
        guard databaseQueueID != dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
            fatalError("DatabaseQueue.inDatabase(_:) was called reentrantly on the same queue, which would lead to a deadlock.")
        }
        
        return try DatabaseQueue.performSync(queue) { () -> R in
            return try block(db: self.database)
        }
    }
    
    /**
    Executes a block in the database queue, wrapped inside a transaction.
    
    If the block throws an error, the transaction is rollbacked and the error is
    rethrown.
    
        try dbQueue.inTransaction { db in
            db.execute(...)
            return .Commit
        }
    
    This method is not reentrant.
    
    - parameter type:  The transaction type (default Exclusive)
                       See https://www.sqlite.org/lang_transaction.html
    - parameter block: A block that executes SQL statements and return either
                       .Commit or .Rollback.
    - throws: The error thrown by the block.
    */
    public func inTransaction(type: Database.TransactionType = .Exclusive, block: (db: Database) throws -> Database.TransactionCompletion) rethrows {
        guard databaseQueueID != dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
            fatalError("DatabaseQueue.inTransaction(_:) was called reentrantly on the same queue, which would lead to a deadlock.")
        }
        
        let database = self.database
        try DatabaseQueue.performSync(queue) { () -> Void in
            try database.inTransaction(type) { () in
                try block(db: database)
            }
        }
    }
    
    
    // MARK: - Not public
    
    /// The Database
    private var database: Database
    
    /// The dispatch queue
    private let queue: dispatch_queue_t
    
    /// The key for the dispatch queue specific that holds the DatabaseQueue
    /// identity. See databaseQueueID.
    static var databaseQueueIDKey = unsafeBitCast(DatabaseQueue.self, UnsafePointer<Void>.self)     // some unique pointer
    
    /// The value for the dispatch queue specific that holds the DatabaseQueue
    /// identity.
    ///
    /// It helps:
    /// - warning the user when he wraps calls to inDatabase() or
    ///   inTransaction(), which would create a deadlock
    /// - warning the user the he uses a statement outside of the database
    ///   queue.
    private lazy var databaseQueueID: DatabaseQueueID = { [unowned self] in
        unsafeBitCast(self, DatabaseQueueID.self)   // pointer to self
    }()
    
    init(database: Database) {
        queue = dispatch_queue_create("GRDB", nil)
        self.database = database
        dispatch_queue_set_specific(queue, DatabaseQueue.databaseQueueIDKey, databaseQueueID, nil)
    }
    
    // A function declared as rethrows that synchronously executes a throwing
    // block in a dispatch_queue.
    static func performSync<R>(queue: dispatch_queue_t, block: () throws -> R) rethrows -> R {
        func performSyncImpl(queue: dispatch_queue_t, block: () throws -> R, block2: (ErrorType) throws -> Void) rethrows -> R {
            var result: R? = nil
            var blockError: ErrorType? = nil
            dispatch_sync(queue) {
                do {
                    result = try block()
                } catch {
                    blockError = error
                }
            }
            if let blockError = blockError {
                try block2(blockError)
            }
            return result!
        }
        return try performSyncImpl(queue, block: block, block2: { throw $0 })
    }

}

typealias DatabaseQueueID = UnsafeMutablePointer<Void>

