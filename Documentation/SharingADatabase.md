Sharing a Database
==================

This chapter describes a recommended setup that applies as soon as several processes want to access a same SQLite database.

On iOS for example, you can share database files between multiple processes by storing them in an [App Group Container](https://developer.apple.com/documentation/foundation/nsfilemanager/1412643-containerurlforsecurityapplicati). On macOS as well, several processes may want to open the same database, according to their particular sandboxing contexts.

Accessing a shared database from several SQLite connections, from several processes, creates challenges at various levels:

1. **Database setup** may be attempted by multiple processes, concurrently.
2. **SQLite** may throw `SQLITE_BUSY` errors, code 5, "database is locked".
3. **iOS** may kill your application with a `0xDEAD10CC` exception.
4. **GRDB** database observation misses changes performed by external processes.

We'll address all of those challenges below.

- [Use a Database Pool]
- [How to limit the `SQLITE_BUSY` error]
- [How to limit the `0xDEAD10CC` exception]
- [How to perform cross-process database observation]


## Use a Database Pool

In order to access a shared database, use a [Database Pool]. It opens the database in the [WAL mode](https://www.sqlite.org/wal.html), which helps sharing a database.

Since several processes may open the database at the same time, protect the creation of the database pool with an [NSFileCoordinator].

- In a process that can create and write in the database, use this sample code:
    
    ```swift
    /// Returns an initialized database pool at the shared location databaseURL
    func openSharedDatabase(at databaseURL: URL) throws -> DatabasePool {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var dbPool: DatabasePool?
        var dbError: Error?
        coordinator.coordinate(writingItemAt: databaseURL, options: .forMerging, error: &coordinatorError, byAccessor: { url in
            do {
                dbPool = try openDatabase(at: url)
            } catch {
                dbError = error
            }
        })
        if let error = dbError ?? coordinatorError {
            throw error
        }
        return dbPool!
    }
    
    private func openDatabase(at databaseURL: URL) throws -> DatabasePool {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            // Activate the persistent WAL mode so that
            // readonly processes can access the database.
            //
            // See https://www.sqlite.org/walformat.html#operations_that_require_locks_and_which_locks_those_operations_use
            // and https://www.sqlite.org/c3ref/c_fcntl_begin_atomic_write.html#sqlitefcntlpersistwal
            if db.configuration.readonly == false {
                var flag: CInt = 1
                let code = withUnsafeMutablePointer(to: &flag) { flagP in
                    sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
                }
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: ResultCode(rawValue: code))
                }
            }
        }
        let dbPool = try DatabasePool(path: databaseURL.path)
        
        // Perform here other database setups, such as defining
        // the database schema with a DatabaseMigrator, and 
        // checking if the application can open the file:
        try migrator.migrate(dbPool)
        if try dbPool.read(migrator.hasBeenSuperseded) {
            // Database is too recent
            throw /* some error */
        }
        
        return dbPool
    }
    ```

- In a process that only reads in the database, use this sample code:
    
    ```swift
    /// Returns an initialized database pool at the shared location databaseURL,
    /// or nil if the database is not created yet, or does not have the required
    /// schema version.
    func openSharedReadOnlyDatabase(at databaseURL: URL) throws -> DatabasePool? {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var dbPool: DatabasePool?
        var dbError: Error?
        coordinator.coordinate(readingItemAt: databaseURL, options: .withoutChanges, error: &coordinatorError, byAccessor: { url in
            do {
                dbPool = try openReadOnlyDatabase(at: url)
            } catch {
                dbError = error
            }
        })
        if let error = dbError ?? coordinatorError {
            throw error
        }
        return dbPool
    }
    
    private func openReadOnlyDatabase(at databaseURL: URL) throws -> DatabasePool? {
        do {
            var configuration = Configuration()
            configuration.readonly = true
            let dbPool = try DatabasePool(path: databaseURL.path, configuration: configuration)
            
            // Check here if the database schema is the expected one,
            // for example with a DatabaseMigrator:
            return try dbPool.read { db in
                if try migrator.hasBeenSuperseded(db) {
                    // Database is too recent
                    return nil
                } else if try migrator.hasCompletedMigrations(db) == false {
                    // Database is too old
                    return nil
                }
                return dbPool
            }
        } catch {
            if FileManager.default.fileExists(atPath: databaseURL.path) {
                throw error
            } else {
                return nil
            }
        }
    }
    ```


#### The specific case of readonly connections

Readonly connections will fail unless two extra files ending in `-shm` and `-wal` are present next to the database file ([source](https://www.sqlite.org/walformat.html#operations_that_require_locks_and_which_locks_those_operations_use)). Those files are regular companions of databases in the [WAL mode]. But they are deleted, under regular operations, when database connections are closed. Precisely speaking, they *may* be deleted: it depends on the SQLite and the operating system versions ([source](https://github.com/groue/GRDB.swift/issues/739#issuecomment-604363998)). And when they are deleted, readonly connections fail.

The solution is to enable the "persistent WAL mode", as shown in the sample code above, by setting the [SQLITE_FCNTL_PERSIST_WAL](https://www.sqlite.org/c3ref/c_fcntl_begin_atomic_write.html#sqlitefcntlpersistwal) flag. This mode makes sure the `-shm` and `-wal` files are never deleted, and guarantees a database access to readonly connections.


## How to limit the `SQLITE_BUSY` error

> The SQLITE_BUSY result code indicates that the database file could not be written (or in some cases read) because of concurrent activity by some other database connection, usually a database connection in a separate process.

See https://www.sqlite.org/rescode.html#busy for more information about this error.

If several processes want to write in the database, configure the database pool of each process that wants to write:

```swift
var configuration = Configuration()
configuration.busyMode = .timeout(/* a TimeInterval */)
configuration.defaultTransactionKind = .immediate
let dbPool = try DatabasePool(path: ..., configuration: configuration)
```

With such a setup, you may still get `SQLITE_BUSY` (5, "database is locked") errors from all write operations. They will occur if the database remains locked by another process for longer than the specified timeout.

```swift
do {
    try dbPool.write { db in ... }
} catch let error as DatabaseError where error.resultCode == .SQLITE_BUSY {
    // Another process won't let you write. Deal with it.
}
```

> :bulb: **Tip**: In order to be nice to other processes, measure the duration of your longest writes, and attempt at optimizing the ones that last for too long. See the [How do I monitor the duration of database statements execution?] FAQ.


## How to limit the `0xDEAD10CC` exception

> The exception code 0xDEAD10CC indicates that an application has been terminated by the OS because it held on to a file lock or sqlite database lock during suspension.

See https://developer.apple.com/library/archive/technotes/tn2151/_index.html for more information about this exception.

1. If you use SQLCipher, use SQLCipher 4+, and call the `cipher_plaintext_header_size` pragma from your database preparation function:
    
    ```swift
    var configuration = Configuration()
    configuration.prepareDatabase { (db: Database) in
        try db.usePassphrase("secret")
        try db.execute(sql: "PRAGMA cipher_plaintext_header_size = 32")
    }
    let dbPool = try DatabasePool(path: ..., configuration: configuration)
    ```
    
    This will avoid https://github.com/sqlcipher/sqlcipher/issues/255.

2. [**:fire: EXPERIMENTAL**](../README.md#what-are-experimental-features) In each process that wants to write in the database:

    Set the `observesSuspensionNotifications` configuration flag:
    
    ```swift
    var configuration = Configuration()
    configuration.observesSuspensionNotifications = true
    let dbPool = try DatabasePool(path: ..., configuration: configuration)
    ```
    
    Post `Database.suspendNotification` when the application is about to be [suspended](https://developer.apple.com/documentation/uikit/app_and_environment/managing_your_app_s_life_cycle). You can for example post this notification from `UIApplicationDelegate.applicationDidEnterBackground(_:)`, or in the expiration handler of a [background task](https://forums.developer.apple.com/thread/85066).
    
    ```swift
    @UIApplicationMain
    class AppDelegate: UIResponder, UIApplicationDelegate {
        func applicationDidEnterBackground(_ application: UIApplication) {
            // Suspend databases
            NotificationCenter.default.post(name: Database.suspendNotification, object: self)
        }
    }
    ```
    
    Post `Database.resumeNotification` from `UIApplicationDelegate.applicationWillEnterForeground(_:)` (or `SceneDelegate.sceneWillEnterForeground(_:)` for scene-based applications):
    
    ```swift
    @UIApplicationMain
    class AppDelegate: UIResponder, UIApplicationDelegate {
        func applicationWillEnterForeground(_ application: UIApplication) {
            // Resume databases
            NotificationCenter.default.post(name: Database.resumeNotification, object: self)
        }
    }
    ```
    
    If the application uses the background modes supported by iOS, post `Database.resumeNotification` method from each and every background mode callback that may use the database. For example, if your application supports background fetches:
    
    ```swift
    @UIApplicationMain
    class AppDelegate: UIResponder, UIApplicationDelegate {
        func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
            // Resume databases
            NotificationCenter.default.post(name: Database.resumeNotification, object: self)
            // Proceed with background fetch
            ...
        }
    }
    ```
    
    Suspended databases greatly reduce the odds of `0xDEAD10CC` exception occurring. If you see one in your crash logs, please open an issue!
    
    In exchange, you will get `SQLITE_INTERRUPT` (9) or `SQLITE_ABORT` (4) errors, with messages "Database is suspended", "Transaction was aborted", or "interrupted", for any attempt at writing in the database when it is suspended.
    
    You can catch those errors:
    
    ```swift
    do {
        try dbPool.write { db in ... }
    } catch let error as DatabaseError where error.isInterruptionError {
        // Oops, the database is suspended.
        // Maybe try again after database is resumed?
    }
    ```


## How to perform cross-process database observation

GRDB [Database Observation] features, as well as its [Combine publishers] and [RxGRDB], are not able to notify database changes performed by other processes.

Whenever you need to notify other processes that the database has been changed, you will have to use a cross-process notification mechanism such as [NSFileCoordinator] or [CFNotificationCenterGetDarwinNotifyCenter].

You can trigger those notifications automatically with [DatabaseRegionObservation]:

```swift
// Notify all changes made to the "player" and "team" database tables
let observation = DatabaseRegionObservation(tracking: Player.all(), Team.all())
let observer = try observation.start(in: dbPool) { (db: Database) in
    // Notify other processes
}

// Notify all changes made to the database
let observation = DatabaseRegionObservation(tracking: DatabaseRegion.fullDatabase)
let observer = try observation.start(in: dbPool) { (db: Database) in
    // Notify other processes
}
```

[Use a Database Pool]: #use-a-database-pool
[How to limit the `SQLITE_BUSY` error]: #how-to-limit-the-sqlite_busy-error
[How to limit the `0xDEAD10CC` exception]: #how-to-limit-the-0xdead10cc-exception
[How to perform cross-process database observation]: #how-to-perform-cross-process-database-observation
[Database Pool]: ../README.md#database-pools
[Database Observation]: ../README.md#database-changes-observation
[RxGRDB]: https://github.com/RxSwiftCommunity/RxGRDB
[NSFileCoordinator]: https://developer.apple.com/documentation/foundation/nsfilecoordinator
[CFNotificationCenterGetDarwinNotifyCenter]: https://developer.apple.com/documentation/corefoundation/1542572-cfnotificationcentergetdarwinnot
[DatabaseRegionObservation]: ../README.md#databaseregionobservation
[WAL mode]: https://www.sqlite.org/wal.html
[How do I monitor the duration of database statements execution?]: ../README.md#how-do-i-monitor-the-duration-of-database-statements-execution
[Combine publishers]: Combine.md
