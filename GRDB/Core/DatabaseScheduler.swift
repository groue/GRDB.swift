/// DatabaseScheduler makes sure that databases connections are used on correct
/// dispatch queues, and warns the user with a fatal error whenever she misuses
/// a database connection.
///
/// Generally speaking, each connection has its own dispatch queue. But it's not
/// enough: users need to use two database connections at the same time:
/// https://github.com/groue/GRDB.swift/issues/55. To support this use case, a
/// single dispatch queue can be temporarily shared by two or more connections.
///
/// Managing this queue sharing is the job of the DatabaseScheduler class.
///
/// Three entry points:
///
/// - DatabaseScheduler.makeSerializedQueueAllowing(database:) creates a
///   dispatch queue that allows one database.
///
///   It does so by registering one instance of DatabaseScheduler as a specific
///   of the dispatch queue, a DatabaseScheduler that allows that database only.
///
/// - The dispatchSync() function helps using several databases in the same
///   dispatch queue. It does so by temporarily extending the allowed databases
///   in the dispatch queue when it is called from a dispatch queue that already
///   allows some databases.
///
/// - preconditionValidQueue() crashes whenever a database is used in an invalid
///   dispatch queue.
final class DatabaseScheduler {
    private static let specificKey = unsafeBitCast(DatabaseScheduler.self, UnsafePointer<Void>.self) // some unique pointer
    private var allowedSerializedDatabases: [Database]
    
    private init(allowedSerializedDatabase database: Database) {
        allowedSerializedDatabases = [database]
    }
    
    static func makeSerializedQueueAllowing(database database: Database) -> dispatch_queue_t {
        let queue = dispatch_queue_create("GRDB.SerializedDatabase", nil)
        let scheduler = DatabaseScheduler(allowedSerializedDatabase: database)
        let unmanagedScheduler = Unmanaged.passRetained(scheduler)
        let schedulerPointer = unsafeBitCast(unmanagedScheduler, UnsafeMutablePointer<Void>.self)
        dispatch_queue_set_specific(queue, DatabaseScheduler.specificKey, schedulerPointer, destroyDatabaseScheduler)
        return queue
    }
    
    static func dispatchSync<T>(queue: dispatch_queue_t, database: Database, block: (db: Database) throws -> T) rethrows -> T {
        if let sourceScheduler = currentScheduler() {
            // We're in a queue where some databases are allowed.
            //
            // First things first: forbid reentrancy.
            //
            // Reentrancy looks nice at first sight:
            //
            //     dbQueue.inDatabase { db in
            //         dbQueue.inDatabase { db in
            //             // Look, ma! I'm reentrant!
            //         }
            //     }
            //
            // But it does not survive this code, which deadlocks:
            //
            //     let queue = dispatch_queue_create("...", nil)
            //     dbQueue.inDatabase { db in
            //         dispatch_sync(queue) {
            //             dbQueue.inDatabase { db in
            //                 // Never run
            //             }
            //         }
            //     }
            //
            // I try not to ship half-baked solutions, so until a robust
            // solution is found to this problem, I prefer discouraging
            // reentrancy altogether, hoping that users will learn and avoid
            // the deadlock pattern.
            GRDBPrecondition(!sourceScheduler.allows(database), "Database methods are not reentrant.")
            
            // Now let's enter the new queue, and temporarily allow the
            // currently allowed databases inside.
            //
            // The impl function helps us turn dispatch_sync into a rethrowing function
            func impl(queue: dispatch_queue_t, database: Database, block: (db: Database) throws -> T, onError: (ErrorType) throws -> ()) rethrows -> T {
                var result: T? = nil
                var blockError: ErrorType? = nil
                dispatch_sync(queue) {
                    let targetScheduler = currentScheduler()!
                    assert(targetScheduler.allowedSerializedDatabases[0] === database) // sanity check
                    
                    do {
                        let backup = targetScheduler.allowedSerializedDatabases
                        targetScheduler.allowedSerializedDatabases.appendContentsOf(sourceScheduler.allowedSerializedDatabases)
                        defer {
                            targetScheduler.allowedSerializedDatabases = backup
                        }
                        result = try block(db: database)
                    } catch {
                        blockError = error
                    }
                }
                if let blockError = blockError {
                    try onError(blockError)
                }
                return result!
            }
            return try impl(queue, database: database, block: block, onError: { throw $0 })
        } else {
            // We're in a queue where no database is allowed: just dispatch
            // block to queue.
            //
            // The impl function helps us turn dispatch_sync into a rethrowing function
            func impl(queue: dispatch_queue_t, database: Database, block: (db: Database) throws -> T, onError: (ErrorType) throws -> ()) rethrows -> T {
                var result: T? = nil
                var blockError: ErrorType? = nil
                dispatch_sync(queue) {
                    do {
                        result = try block(db: database)
                    } catch {
                        blockError = error
                    }
                }
                if let blockError = blockError {
                    try onError(blockError)
                }
                return result!
            }
            return try impl(queue, database: database, block: block, onError: { throw $0 })
        }
    }
    
    static func preconditionValidQueue(db: Database, @autoclosure _ message: () -> String = "Database was not used on the correct thread.", file: StaticString = #file, line: UInt = #line) {
        GRDBPrecondition(allows(db), message, file: file, line: line)
    }
    
    static func allows(db: Database) -> Bool {
        return currentScheduler()?.allows(db) ?? false
    }
    
    private func allows(db: Database) -> Bool {
        return allowedSerializedDatabases.contains { $0 === db }
    }
    
    private static func currentScheduler() -> DatabaseScheduler? {
        return scheduler(from: dispatch_get_specific(specificKey))
    }
    
    private static func scheduler(from schedulerPointer: UnsafeMutablePointer<Void>) -> DatabaseScheduler? {
        guard schedulerPointer != nil else {
            return nil
        }
        let unmanagedScheduler = unsafeBitCast(schedulerPointer, Unmanaged<DatabaseScheduler>.self)
        return unmanagedScheduler.takeUnretainedValue()
    }
}

/// Destructor for dispatch_queue_set_specific
private func destroyDatabaseScheduler(schedulerPointer: UnsafeMutablePointer<Void>) {
    let unmanagedScheduler = unsafeBitCast(schedulerPointer, Unmanaged<DatabaseScheduler>.self)
    unmanagedScheduler.release()
}
