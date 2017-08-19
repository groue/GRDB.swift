import Dispatch

/// SchedulingWatchdog makes sure that databases connections are used on correct
/// dispatch queues, and warns the user with a fatal error whenever she misuses
/// a database connection.
///
/// Generally speaking, each connection has its own dispatch queue. But it's not
/// enough: users need to use two database connections at the same time:
/// https://github.com/groue/GRDB.swift/issues/55. To support this use case, a
/// single dispatch queue can be temporarily shared by two or more connections.
///
/// - SchedulingWatchdog.makeSerializedQueue(allowingDatabase:) creates a
///   dispatch queue that allows one database.
///
///   It does so by registering one instance of SchedulingWatchdog as a specific
///   of the dispatch queue, a SchedulingWatchdog that allows that database only.
///
///   Later on, the queue can be shared by several databases with the method
///   allowing(databases:execute:). See SerializedDatabase.sync() for
///   an example.
///
/// - preconditionValidQueue() crashes whenever a database is used in an invalid
///   dispatch queue.
final class SchedulingWatchdog {
    private static let specificKey = DispatchSpecificKey<SchedulingWatchdog>()
    private(set) var allowedDatabases: [Database]
    
    private init(allowedDatabase database: Database) {
        allowedDatabases = [database]
    }
    
    static func makeSerializedQueue(allowingDatabase database: Database) -> DispatchQueue {
        let queue = DispatchQueue(label: "GRDB.SerializedDatabase")
        let watchdog = SchedulingWatchdog(allowedDatabase: database)
        queue.setSpecific(key: specificKey, value: watchdog)
        return queue
    }
    
    // Temporarily allows `databases` while executing `body`
    func allowing<T>(databases: [Database], execute body: () throws -> T) rethrows -> T {
        let backup = allowedDatabases
        allowedDatabases.append(contentsOf: databases)
        defer { allowedDatabases = backup }
        return try body()
    }
    
    static func preconditionValidQueue(_ db: Database, _ message: @autoclosure() -> String = "Database was not used on the correct thread.", file: StaticString = #file, line: UInt = #line) {
        GRDBPrecondition(allows(db), message, file: file, line: line)
    }
    
    static func allows(_ db: Database) -> Bool {
        return current?.allows(db) ?? false
    }
    
    func allows(_ db: Database) -> Bool {
        return allowedDatabases.contains { $0 === db }
    }
    
    static var current: SchedulingWatchdog? {
        return DispatchQueue.getSpecific(key: specificKey)
    }
}
