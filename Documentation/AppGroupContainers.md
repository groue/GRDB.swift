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

Protect the creation of the database, as well as the definition of its schema, with an [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator).

```swift
func openDatabase(at databaseURL: URL) throws -> DatabasePool {
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinatorError: NSError?
    var poolError: Error?
    var dbPool: DatabasePool?
    coordinator.coordinate(writingItemAt: databaseURL, options: .forMerging, error: &coordinatorError, byAccessor: { url in
        do {
            dbPool = try DatabasePool(path: url.path)
            // Here perform other database setups, such as defining 
            // your database schema with a DatabaseMigrator.
        } catch {
            poolError = error
        }
    })
    if let error = poolError ?? coordinatorError {
        throw error
    }
    return dbPool!
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

Those steps are only recommended for applications, not for extensions.

1. Set the `suspendsOnBackgroundTimeExpiration` configuration flag:
    
    ```swift
    var configuration = Configuration()
    configuration.suspendsOnBackgroundTimeExpiration = true
    let dbPool = try DatabasePool(path: ..., configuration: configuration)
    ```

2. If you use SQLCipher, use SQLCipher 4+, and call the `cipher_plaintext_header_size` pragma from your database preparation function:
    
    ```swift
    configuration.prepareDatabase = { (db: Database) in
        try db.usePassphrase("secret")
        try db.execute(sql: "PRAGMA cipher_plaintext_header_size = 32")
    }
    ```
    
    This will avoid https://github.com/sqlcipher/sqlcipher/issues/255.

3. From `UIApplicationDelegate.applicationWillEnterForeground(_:)` (or `SceneDelegate.sceneWillEnterForeground(_:)` for scene-based applications), and from all the background mode callbacks defined by iOS, call the `DatabaseBackgroundScheduler.shared.resume(in:)` method:
    
    ```swift
    @UIApplicationMain
    class AppDelegate: UIResponder, UIApplicationDelegate {
        func applicationWillEnterForeground(_ application: UIApplication) {
            // Resume suspended databases
            DatabaseBackgroundScheduler.shared.resume(in: application)
        }
        
        func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
            // Resume suspended databases
            DatabaseBackgroundScheduler.shared.resume(in: application)
            // Proceed with background fetch
            ...
        }
    }
    ```

If you carefully follow this setup, the odds of `0xDEAD10CC` exception are greatly reduced. If you see one in your crash logs, please open an issue!

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
