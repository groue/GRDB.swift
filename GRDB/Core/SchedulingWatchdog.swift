/// SchedulingWatchdog makes sure that databases connections are used on correct
/// dispatch queues, and warns the user with a fatal error whenever she misuses
/// a database connection.
///
/// Generally speaking, each connection has its own dispatch queue. But it's not
/// enough: users need to use two database connections at the same time:
/// https://github.com/groue/GRDB.swift/issues/55. To support this use case, a
/// single dispatch queue can be temporarily shared by two or more connections.
///
/// - SchedulingWatchdog.makeSerializedQueueAllowing(database:) creates a
///   dispatch queue that allows one database.
///
///   It does so by registering one instance of SchedulingWatchdog as a specific
///   of the dispatch queue, a SchedulingWatchdog that allows that database only.
///
///   Later on, the queue can be shared by several databases with the method
///   allowing(databases:execute:). See SerializedDatabase.performSync() for
///   an example.
///
/// - preconditionValidQueue() crashes whenever a database is used in an invalid
///   dispatch queue.
final class SchedulingWatchdog {
    private static let specificKey = unsafeBitCast(SchedulingWatchdog.self, UnsafePointer<Void>.self) // some unique pointer
    var allowedDatabases: [Database]
    
    private init(allowedDatabase database: Database) {
        allowedDatabases = [database]
    }
    
    static func makeSerializedQueueAllowing(database database: Database) -> dispatch_queue_t {
        let queue = dispatch_queue_create("GRDB.SerializedDatabase", nil)
        let watchdog = SchedulingWatchdog(allowedDatabase: database)
        let unmanagedWatchdog = Unmanaged.passRetained(watchdog)
        let watchdogPointer = unsafeBitCast(unmanagedWatchdog, UnsafeMutablePointer<Void>.self)
        dispatch_queue_set_specific(queue, SchedulingWatchdog.specificKey, watchdogPointer, destroyDatabaseWatchdog)
        return queue
    }
    
    static func preconditionValidQueue(db: Database, @autoclosure _ message: () -> String = "Database was not used on the correct thread.", file: StaticString = #file, line: UInt = #line) {
        GRDBPrecondition(allows(db), message, file: file, line: line)
    }
    
    static func allows(db: Database) -> Bool {
        return current?.allows(db) ?? false
    }
    
    func allows(db: Database) -> Bool {
        return allowedDatabases.contains { $0 === db }
    }
    
    static var current: SchedulingWatchdog? {
        return watchdog(from: dispatch_get_specific(specificKey))
    }
    
    private static func watchdog(from watchdogPointer: UnsafeMutablePointer<Void>) -> SchedulingWatchdog? {
        guard watchdogPointer != nil else {
            return nil
        }
        let unmanagedWatchdog = unsafeBitCast(watchdogPointer, Unmanaged<SchedulingWatchdog>.self)
        return unmanagedWatchdog.takeUnretainedValue()
    }
}

/// Destructor for dispatch_queue_set_specific
private func destroyDatabaseWatchdog(watchdogPointer: UnsafeMutablePointer<Void>) {
    let unmanagedWatchdog = unsafeBitCast(watchdogPointer, Unmanaged<SchedulingWatchdog>.self)
    unmanagedWatchdog.release()
}
