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
    private static let specificKey = DispatchSpecificKey<DatabaseScheduler>()
    private var allowedSerializedDatabases: [Database]
    
    private init(allowedSerializedDatabase database: Database) {
        allowedSerializedDatabases = [database]
    }
    
    static func makeSerializedQueueAllowing(database: Database) -> DispatchQueue {
        let queue = DispatchQueue(label: "GRDB.SerializedDatabase")
        let scheduler = DatabaseScheduler(allowedSerializedDatabase: database)
        queue.setSpecific(key: specificKey, value: scheduler)
        return queue
    }
    
    static func sync<T>(queue: DispatchQueue, database: Database, block: @noescape (db: Database) throws -> T) rethrows -> T {
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
            //         queue.sync {
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
            return try queue.sync {
                let targetScheduler = currentScheduler()!
                assert(targetScheduler.allowedSerializedDatabases[0] === database) // sanity check
                
                let backup = targetScheduler.allowedSerializedDatabases
                targetScheduler.allowedSerializedDatabases.append(contentsOf: sourceScheduler.allowedSerializedDatabases)
                defer {
                    targetScheduler.allowedSerializedDatabases = backup
                }
                return try block(db: database)
            }
            
        } else {
            // We're in a queue where no database is allowed: just dispatch
            // block to queue.
            return try queue.sync {
                try block(db: database)
            }
        }
    }
    
    static func preconditionValidQueue(_ db: Database, _ message: @autoclosure() -> String = "Database was not used on the correct thread.", file: StaticString = #file, line: UInt = #line) {
        GRDBPrecondition(allows(db), message, file: file, line: line)
    }
    
    static func allows(_ db: Database) -> Bool {
        return currentScheduler()?.allows(db) ?? false
    }
    
    private func allows(_ db: Database) -> Bool {
        return allowedSerializedDatabases.contains { $0 === db }
    }
    
    private static func currentScheduler() -> DatabaseScheduler? {
        guard let scheduler = DispatchQueue.getSpecific(key: specificKey) else {
            return nil
        }
        return scheduler
    }
}
