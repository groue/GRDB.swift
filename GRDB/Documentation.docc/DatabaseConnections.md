# Database Connections

Open database connections to SQLite databases. 

## Overview

GRDB provides two classes for accessing SQLite databases: ``DatabaseQueue`` and ``DatabasePool``:

```swift
import GRDB

// Pick one:
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
```

The differences are:

- `DatabasePool` allows concurrent database accesses (this can improve the performance of multithreaded applications).
- `DatabasePool` opens your SQLite database in the [WAL mode](https://www.sqlite.org/wal.html).
- `DatabaseQueue` supports <doc:DatabaseQueue#In-Memory-Databases>.

**If you are not sure, choose `DatabaseQueue`.** You will always be able to switch to `DatabasePool` later.

## Opening a Connection

You need a path to a database file in order to open a database connection.

**When the SQLite file is ready-made, and you do not intend to modify its content**, then add the database file as a [resource of your Xcode project or Swift package](https://developer.apple.com/documentation/xcode), and open a read-only database connection:

```swift
// HOW TO open a read-only connection to a database resource

// Get the path to the database resource.
// Replace `Bundle.main` with `Bundle.module` when you write a Swift Package.
if let dbPath = Bundle.main.path(forResource: "db", ofType: "sqlite")

if let dbPath {
    // If the resource exists, open a read-only connection.
    // Writes are disallowed because resources can not be modified. 
    var config = Configuration()
    config.readonly = true
    let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
} else {
    // The database resource can not be found.
    // Fix your setup, or report the problem to the user. 
}
```

**If the application creates or writes in the database**, then first choose a proper location for the database file. Document-based applications will let the user pick a location. Apps that use the database as a global storage will prefer the Application Support directory.

> Tip: Regardless of the database location, it is recommended that you wrap the database file inside a dedicated directory. This directory will bundle the main database file and its related [SQLite temporary files](https://www.sqlite.org/tempfiles.html) together.
>
> The dedicated directory helps moving or deleting the whole database when needed: just move or delete the directory.
>
> On iOS, the directory can be encrypted with [data protection](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/encrypting_your_app_s_files), in order to help securing all database files in one shot. When a database is protected, an application that runs in the background on a locked device won't be able to read or write from it. Instead, it will catch ``DatabaseError`` with code [`SQLITE_IOERR`](https://www.sqlite.org/rescode.html#ioerr) (10) "disk I/O error", or [`SQLITE_AUTH`](https://www.sqlite.org/rescode.html#auth) (23) "not authorized".

The sample code below creates or opens a database file inside its dedicated directory. On the first run, a new empty database file is created. On subsequent runs, the directory and database file already exist, so it just opens a connection:

```swift
// HOW TO create an empty database, or open an existing database file

// Create the "Application Support/MyDatabase" directory if needed
let fileManager = FileManager.default
let appSupportURL = try fileManager.url(
    for: .applicationSupportDirectory, in: .userDomainMask,
    appropriateFor: nil, create: true) 
let directoryURL = appSupportURL.appendingPathComponent("MyDatabase", isDirectory: true)
try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

// Open or create the database
let databaseURL = directoryURL.appendingPathComponent("db.sqlite")
let dbQueue = try DatabaseQueue(path: databaseURL.path)
```

## Closing Connections

Database connections are automatically closed when ``DatabaseQueue`` or ``DatabasePool`` instances are deinitialized.

If the correct execution of your program depends on precise database closing, perform an explicit call to ``DatabaseReader/close()``. This method may fail and create zombie connections, so please check its detailed documentation.


## Next Steps

Once connected to the database, your next steps are probably:

- Define the structure of newly created databases: see <doc:Migrations>.
- If you intend to write SQL, see <doc:SQLSupport>. Otherwise, see <doc:QueryInterface>.

Even if you plan to keep your project mundane and simple, take the time to read the <doc:Concurrency> guide eventually.

## Topics

### Configuring database connections

- ``Configuration``

### Connections for read and write accesses

- ``DatabaseQueue``
- ``DatabasePool``

### Read-only connections on an unchanging database content

- ``DatabaseSnapshot``
- ``DatabaseSnapshotPool``

### Using database connections

- ``Database``
- ``DatabaseError``
