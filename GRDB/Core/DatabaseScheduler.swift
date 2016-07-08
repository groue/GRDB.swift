/// DatabaseScheduler makes sure that databases connections are used on correct
/// dispatch queues, and warns the user with a fatal error whenever she misuses
/// a database connection.
///
/// Generally speaking, each connection has its own dispatch queue. But it's not
/// enough: users need to use two database connections at the same time:
/// https://github.com/groue/GRDB.swift/issues/55. To support this use case, a
/// single dispatch queue can be temporarily shared by two or more connections.
///
/// Two entry points:
///
/// - DatabaseScheduler.makeSerializedQueueAllowing(database:) creates a
///   dispatch queue that allows one database.
///
///   It does so by registering one instance of DatabaseScheduler as a specific
///   of the dispatch queue, a DatabaseScheduler that allows that database only.
///
///   Later on, the queue can be shared by several databases by mutating the
///   allowedDatabases property. See SerializedDatabase.performSync()
///
/// - preconditionValidQueue() crashes whenever a database is used in an invalid
///   dispatch queue.
final class DatabaseScheduler {
    private static let specificKey = unsafeBitCast(DatabaseScheduler.self, UnsafePointer<Void>.self) // some unique pointer
    var allowedDatabases: [Database]
    
    private init(allowedDatabase database: Database) {
        allowedDatabases = [database]
    }
    
    static func makeSerializedQueueAllowing(database database: Database) -> dispatch_queue_t {
        let queue = dispatch_queue_create("GRDB.SerializedDatabase", nil)
        let scheduler = DatabaseScheduler(allowedDatabase: database)
        let unmanagedScheduler = Unmanaged.passRetained(scheduler)
        let schedulerPointer = unsafeBitCast(unmanagedScheduler, UnsafeMutablePointer<Void>.self)
        dispatch_queue_set_specific(queue, DatabaseScheduler.specificKey, schedulerPointer, destroyDatabaseScheduler)
        return queue
    }
    
    static func preconditionValidQueue(db: Database, @autoclosure _ message: () -> String = "Database was not used on the correct thread.", file: StaticString = #file, line: UInt = #line) {
        GRDBPrecondition(allows(db), message, file: file, line: line)
    }
    
    static func allows(db: Database) -> Bool {
        return currentScheduler()?.allows(db) ?? false
    }
    
    func allows(db: Database) -> Bool {
        return allowedDatabases.contains { $0 === db }
    }
    
    static func currentScheduler() -> DatabaseScheduler? {
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
