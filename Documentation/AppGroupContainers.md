Sharing a Datatase in an App Group Container
============================================

On iOS, you can share database files between multiple processes by storing them in an [App Group Container](https://developer.apple.com/documentation/foundation/nsfilemanager/1412643-containerurlforsecurityapplicati).

A shared database is accessed from several SQLite connections, from several processes. This creates challenges at various levels:

1. **SQLite** may throw `SQLITE_BUSY` errors, code 5, "database is locked".
2. **iOS** may kill your application with a `0xDEAD10CC` exception.
3. **GRDB** database observation misses changes performed by external processes.

We'll address all of those challenges below.


## Use a Database Pool

In order to access a shared database, use a [Database Pool]. It opens the database in the [WAL mode](https://www.sqlite.org/wal.html), which helps sharing a database.

Since several processes may open the database at the same time, protect the creation of the database pool with an [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator).

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
        let dbPool = try DatabasePool(path: databaseURL.path)
        // Perform here other database setups, such as defining 
        // the database schema with a DatabaseMigrator.
        return dbPool
    }
    ```

- In a process that only reads in the database, use this sample code:
    
    ```swift
    /// Returns an initialized database pool at the shared location databaseURL,
    /// or nil if the database was not created yet.
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
            return try DatabasePool(path: databaseURL.path, configuration: configuration)
        } catch {
            if FileManager.default.fileExists(atPath: databaseURL.path) {
                // Something went wrong
                throw error
            } else {
                // Database file does not exist
                return nil
            }
        }
    }
    ```


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

> :bulb: **Tip**: In order to be nice to other processes, measure the duration of your longest writes, and attempt at optimizing the ones that last for too long.


## How to limit the `0xDEAD10CC` exception

> The exception code 0xDEAD10CC indicates that an application has been terminated by the OS because it held on to a file lock or sqlite database lock during suspension.

See https://developer.apple.com/library/archive/technotes/tn2151/_index.html for more information about this exception.

1. If you use SQLCipher, use SQLCipher 4+, and call the `cipher_plaintext_header_size` pragma from your database preparation function:
    
    ```swift
    var configuration = Configuration()
    configuration.prepareDatabase = { (db: Database) in
        try db.usePassphrase("secret")
        try db.execute(sql: "PRAGMA cipher_plaintext_header_size = 32")
    }
    let dbPool = try DatabasePool(path: ..., configuration: configuration)
    ```
    
    This will avoid https://github.com/sqlcipher/sqlcipher/issues/255.

2. In applications (not extensions), perform this extra setup:

    Set the `suspendsOnBackgroundTimeExpiration` configuration flag:
    
    ```swift
    var configuration = Configuration()
    configuration.suspendsOnBackgroundTimeExpiration = true
    let dbPool = try DatabasePool(path: ..., configuration: configuration)
    ```
    
    Call the `DatabaseBackgroundScheduler.shared.resume(in:)` method from `UIApplicationDelegate.applicationWillEnterForeground(_:)` (or `SceneDelegate.sceneWillEnterForeground(_:)` for scene-based applications):
    
    ```swift
    @UIApplicationMain
    class AppDelegate: UIResponder, UIApplicationDelegate {
        func applicationWillEnterForeground(_ application: UIApplication) {
            // Resume suspended databases
            DatabaseBackgroundScheduler.shared.resume(in: application)
        }
    }
    ```
    
    If your application uses the background modes supported by iOS, call the `DatabaseBackgroundScheduler.shared.resume(in:)` method from each and every background mode callback that may use the database. For example, if your application supports background fetches:
    
    ```swift
    @UIApplicationMain
    class AppDelegate: UIResponder, UIApplicationDelegate {
        func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
            // Resume suspended databases
            DatabaseBackgroundScheduler.shared.resume(in: application)
            // Proceed with background fetch
            ...
        }
    }
    ```
    
    If you carefully follow those steps, the odds of `0xDEAD10CC` exception are greatly reduced. If you see one in your crash logs, please open an issue!
    
    In exchange, you will get `SQLITE_INTERRUPT` (9) or `SQLITE_ABORT` (4) errors, with messages "Database is suspended", "Transaction was aborted", or "interrupted", for any attempt at writing in the database when it is **suspended**.
    
    The database is suspended soon before the application transitions to the [suspended state](https://developer.apple.com/documentation/uikit/app_and_environment/managing_your_app_s_life_cycle), and resumes on the next call to `DatabaseBackgroundScheduler.shared.resume(in:)`.
    
    Those events are globally notified with the `DatabaseBackgroundScheduler.databaseWillSuspendNotification` and `DatabaseBackgroundScheduler.databaseDidResumeNotification` notifications.
    
    ```swift
    do {
        try dbPool.write { db in ... }
    } catch let error as DatabaseError where error.isDatabaseSuspensionError {
        // Oops, the database is suspended.
        // Maybe try again after DatabaseBackgroundScheduler.databaseDidResumeNotification?
    }
    ```


## How to perform cross-process database observation

TODO get ideas from https://www.avanderlee.com/swift/core-data-app-extension-data-sharing/


[Database Pool]: ../README.md#database-pools
