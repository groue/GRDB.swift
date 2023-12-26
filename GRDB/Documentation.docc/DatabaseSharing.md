# Sharing a Database

How to share an SQLite database between multiple processes • Recommendations for App Group containers, App Extensions, App Sandbox, and file coordination.

## Overview

**This guide describes a recommended setup that applies as soon as several processes want to access the same SQLite database.** It complements the <doc:Concurrency> guide, that you should read first.

On iOS for example, you can share database files between multiple processes by storing them in an [App Group Container](https://developer.apple.com/documentation/foundation/nsfilemanager/1412643-containerurlforsecurityapplicati). On macOS, several processes may want to open the same database, according to their particular sandboxing contexts.

Accessing a shared database from several SQLite connections, from several processes, creates challenges at various levels:

1. **Database setup** may be attempted by multiple processes, concurrently, with possible conflicts.
2. **SQLite** may throw [`SQLITE_BUSY`] errors, "database is locked".
3. **iOS** may kill your application with a [`0xDEAD10CC`] exception.
4. **GRDB** <doc:DatabaseObservation> does not detect changes performed by external processes.

We'll address all of those challenges below.

> Important: Preventing errors that may happen due to database sharing is difficult. It is extremely difficult on iOS. And it is almost impossible to test.
>
> Always consider sharing plain files, or any other inter-process communication technique, before sharing an SQLite database.

## Use the WAL mode

In order to access a shared database, use a ``DatabasePool``. It opens the database in the [WAL mode], which helps sharing a database because it allows multiple processes to access the database concurrently.

It is also possible to use a ``DatabaseQueue``, with the `.wal` ``Configuration/journalMode``.

Since several processes may open the database at the same time, protect the creation of the database connection with an [NSFileCoordinator].

- In a process that can create and write in the database, use this sample code:
    
    ```swift
    /// Returns an initialized database pool at the shared location databaseURL
    func openSharedDatabase(at databaseURL: URL) throws -> DatabasePool {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var dbPool: DatabasePool?
        var dbError: Error?
        coordinator.coordinate(writingItemAt: databaseURL, options: .forMerging, error: &coordinatorError) { url in
            do {
                dbPool = try openDatabase(at: url)
            } catch {
                dbError = error
            }
        }
        if let error = dbError ?? coordinatorError {
            throw error
        }
        return dbPool!
    }
    
    private func openDatabase(at databaseURL: URL) throws -> DatabasePool {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            // Activate the persistent WAL mode so that
            // read-only processes can access the database.
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
        let dbPool = try DatabasePool(path: databaseURL.path, configuration: configuration)
        
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
        coordinator.coordinate(readingItemAt: databaseURL, options: .withoutChanges, error: &coordinatorError) { url in
            do {
                dbPool = try openReadOnlyDatabase(at: url)
            } catch {
                dbError = error
            }
        }
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


#### The Specific Case of Read-Only Connections

Read-only connections will fail unless two extra files ending in `-shm` and `-wal` are present next to the database file ([source](https://www.sqlite.org/walformat.html#operations_that_require_locks_and_which_locks_those_operations_use)). Those files are regular companions of databases in the [WAL mode]. But they are deleted, under regular operations, when database connections are closed. Precisely speaking, they *may* be deleted: it depends on the SQLite and the operating system versions ([source](https://github.com/groue/GRDB.swift/issues/739#issuecomment-604363998)). And when they are deleted, read-only connections fail.

The solution is to enable the "persistent WAL mode", as shown in the sample code above, by setting the [SQLITE_FCNTL_PERSIST_WAL](https://www.sqlite.org/c3ref/c_fcntl_begin_atomic_write.html#sqlitefcntlpersistwal) flag. This mode makes sure the `-shm` and `-wal` files are never deleted, and guarantees a database access to read-only connections.


## How to limit the SQLITE_BUSY error

> SQLite Documentation: The [`SQLITE_BUSY`] result code indicates that the database file could not be written (or in some cases read) because of concurrent activity by some other database connection, usually a database connection in a separate process.

If several processes want to write in the database, configure the database pool of each process that wants to write:

```swift
var configuration = Configuration()
configuration.busyMode = .timeout(/* a TimeInterval */)
let dbPool = try DatabasePool(path: ..., configuration: configuration)
```

With such a setup, you may still get `SQLITE_BUSY` errors from all write operations. They will occur if the database remains locked by another process for longer than the specified timeout. You can catch those errors:

```swift
do {
    try dbPool.write { db in ... }
} catch DatabaseError.SQLITE_BUSY {
    // Another process won't let you write. Deal with it.
}
```

## How to limit the 0xDEAD10CC exception

> Apple documentation: [`0xDEAD10CC`] (pronounced “dead lock”): the operating system terminated the app because it held on to a file lock or SQLite database lock during suspension.

#### If you use SQLCipher

Use SQLCipher 4+, and configure the database from ``Configuration/prepareDatabase(_:)``:

```swift
var configuration = Configuration()
configuration.prepareDatabase { (db: Database) in
    try db.usePassphrase("secret")
    try db.execute(sql: "PRAGMA cipher_plaintext_header_size = 32")
}
let dbPool = try DatabasePool(path: ..., configuration: configuration)
```

Applications become responsible for managing the salt themselves: see [instructions](https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_plaintext_header_size). See also <https://github.com/sqlcipher/sqlcipher/issues/255> for more context and information.

#### In all cases

The technique described below is based on [this discussion](https://developer.apple.com/forums/thread/126438) on the Apple Developer Forums. It is [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features).

In each process that writes in the database, set the ``Configuration/observesSuspensionNotifications`` configuration flag:

```swift
var configuration = Configuration()
configuration.observesSuspensionNotifications = true
let dbPool = try DatabasePool(path: ..., configuration: configuration)
```

Post ``Database/suspendNotification`` when the application is about to be [suspended](https://developer.apple.com/documentation/uikit/app_and_environment/managing_your_app_s_life_cycle). You can for example post this notification from `UIApplicationDelegate.applicationDidEnterBackground(_:)`, or in the expiration handler of a [background task](https://forums.developer.apple.com/thread/85066):

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    func applicationDidEnterBackground(_ application: UIApplication) {
        NotificationCenter.default.post(name: Database.suspendNotification, object: self)
    }
}
```

Once suspended, a database won't acquire any new lock that could cause the `0xDEAD10CC` exception.

In exchange, you will get `SQLITE_INTERRUPT` (code 9) or `SQLITE_ABORT` (code 4) errors, with messages "Database is suspended", "Transaction was aborted", or "interrupted". You can catch those errors:

```swift
do {
    try dbPool.write { db in ... }
} catch DatabaseError.SQLITE_INTERRUPT, DatabaseError.SQLITE_ABORT {
    // Oops, the database is suspended.
    // Maybe try again after database is resumed?
}
```

Post ``Database/resumeNotification`` in order to resume suspended databases. You can safely post this notification when the app comes back to foreground.

In applications that use the background modes supported by iOS, post `resumeNotification` method from each and every background mode callback that may use the database, and don't forget to post `suspendNotification` again before the app turns suspended.

## How to perform cross-process database observation

<doc:DatabaseObservation> features are not able to detect database changes performed by other processes.

Whenever you need to notify other processes that the database has been changed, you will have to use a cross-process notification mechanism such as [NSFileCoordinator] or [CFNotificationCenterGetDarwinNotifyCenter]. You can trigger those notifications automatically with ``DatabaseRegionObservation``:

```swift
// Notify all changes made to the database
let observation = DatabaseRegionObservation(tracking: .fullDatabase)
let observer = try observation.start(in: dbPool) { db in
    // Notify other processes
}

// Notify changes made to the "player" and "team" tables only
let observation = DatabaseRegionObservation(tracking: Player.all(), Team.all())
let observer = try observation.start(in: dbPool) { db in
    // Notify other processes
}
```

The processes that observe the database can catch those notifications, and deal with the notified changes. See <doc:GRDB/TransactionObserver#Dealing-with-Undetected-Changes> for some related techniques.

[NSFileCoordinator]: https://developer.apple.com/documentation/foundation/nsfilecoordinator
[CFNotificationCenterGetDarwinNotifyCenter]: https://developer.apple.com/documentation/corefoundation/1542572-cfnotificationcentergetdarwinnot
[WAL mode]: https://www.sqlite.org/wal.html
[`SQLITE_BUSY`]: https://www.sqlite.org/rescode.html#busy
[`0xDEAD10CC`]: https://developer.apple.com/documentation/xcode/understanding-the-exception-types-in-a-crash-report
