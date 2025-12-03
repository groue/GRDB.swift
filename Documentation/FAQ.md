FAQ
===

**[FAQ: Opening Connections](#faq-opening-connections)**

- [How do I create a database in my application?](#how-do-i-create-a-database-in-my-application)
- [How do I open a database stored as a resource of my application?](#how-do-i-open-a-database-stored-as-a-resource-of-my-application)
- [How do I close a database connection?](#how-do-i-close-a-database-connection)

**[FAQ: SQL](#faq-sql)**

- [How do I print a request as SQL?](#how-do-i-print-a-request-as-sql)

**[FAQ: General](#faq-general)**

- [How do I monitor the duration of database statements execution?](#how-do-i-monitor-the-duration-of-database-statements-execution)
- [What Are Experimental Features?](#what-are-experimental-features)
- [Does GRDB support library evolution and ABI stability?](#does-grdb-support-library-evolution-and-abi-stability)

**[FAQ: Associations](#faq-associations)**

- [How do I filter records and only keep those that are associated to another record?](#how-do-i-filter-records-and-only-keep-those-that-are-associated-to-another-record)
- [How do I filter records and only keep those that are NOT associated to another record?](#how-do-i-filter-records-and-only-keep-those-that-are-not-associated-to-another-record)
- [How do I select only one column of an associated record?](#how-do-i-select-only-one-column-of-an-associated-record)

**[FAQ: ValueObservation](#faq-valueobservation)**

- [Why is ValueObservation not publishing value changes?](#why-is-valueobservation-not-publishing-value-changes)

**[FAQ: Errors](#faq-errors)**

- [Generic parameter 'T' could not be inferred](#generic-parameter-t-could-not-be-inferred)
- [Mutation of captured var in concurrently-executing code](#mutation-of-captured-var-in-concurrently-executing-code)
- [SQLite error 1 "no such column"](#sqlite-error-1-no-such-column)
- [SQLite error 10 "disk I/O error", SQLite error 23 "not authorized"](#sqlite-error-10-disk-io-error-sqlite-error-23-not-authorized)
- [SQLite error 21 "wrong number of statement arguments" with LIKE queries](#sqlite-error-21-wrong-number-of-statement-arguments-with-like-queries)


## FAQ: Opening Connections

### How do I create a database in my application?

First choose a proper location for the database file. Document-based applications will let the user pick a location. Apps that use the database as a global storage will prefer the Application Support directory.

The sample code below creates or opens a database file inside its dedicated directory (a [recommended practice](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseconnections)). On the first run, a new empty database file is created. On subsequent runs, the database file already exists, so it just opens a connection:

```swift
// HOW TO create an empty database, or open an existing database file

// Create the "Application Support/MyDatabase" directory
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

### How do I open a database stored as a resource of my application?

Open a read-only connection to your resource:

```swift
// HOW TO open a read-only connection to a database resource

// Get the path to the database resource.
if let dbPath = Bundle.main.path(forResource: "db", ofType: "sqlite") {
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

### How do I close a database connection?

Database connections are automatically closed when `DatabaseQueue` or `DatabasePool` instances are deinitialized.

If the correct execution of your program depends on precise database closing, perform an explicit call to [`close()`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasereader/close()). This method may fail and create zombie connections, so please check its detailed documentation.


## FAQ: SQL

### How do I print a request as SQL?

When you want to debug a request that does not deliver the expected results, you may want to print the SQL that is actually executed.

You can compile the request into a prepared [`Statement`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/statement):

```swift
try dbQueue.read { db in
    let request = Player.filter { $0.email == "arthur@example.com" }
    let statement = try request.makePreparedRequest(db).statement
    print(statement) // SELECT * FROM player WHERE email = ?
    print(statement.arguments) // ["arthur@example.com"]
}
```

Another option is to setup a tracing function that prints out the executed SQL requests. For example, provide a tracing function when you connect to the database:

```swift
// Prints all SQL statements
var config = Configuration()
config.prepareDatabase { db in
    db.trace { print($0) }
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

try dbQueue.read { db in
    // Prints "SELECT * FROM player WHERE email = ?"
    let players = try Player.filter { $0.email == "arthur@example.com" }.fetchAll(db)
}
```

If you want to see statement arguments such as `'arthur@example.com'` in the logged statements, [make statement arguments public](https://swiftpackageindex.com/groue/GRDB.swift/configuration/publicstatementarguments).

> **Note**: the generated SQL may change between GRDB releases, without notice: don't have your application rely on any specific SQL output.


## FAQ: General

### How do I monitor the duration of database statements execution?

Use the `trace(options:_:)` method, with the `.profile` option:

```swift
var config = Configuration()
config.prepareDatabase { db in
    db.trace(options: .profile) { event in
        // Prints all SQL statements with their duration
        print(event)

        // Access to detailed profiling information
        if case let .profile(statement, duration) = event, duration > 0.5 {
            print("Slow query: \(statement.sql)")
        }
    }
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

try dbQueue.read { db in
    let players = try Player.filter { $0.email == "arthur@example.com" }.fetchAll(db)
    // Prints "0.003s SELECT * FROM player WHERE email = ?"
}
```

If you want to see statement arguments such as `'arthur@example.com'` in the logged statements, [make statement arguments public](https://swiftpackageindex.com/groue/GRDB.swift/configuration/publicstatementarguments).

### What Are Experimental Features?

Since GRDB 1.0, all backwards compatibility guarantees of [semantic versioning](http://semver.org) apply: no breaking change will happen until the next major version of the library.

There is an exception, though: *experimental features*, marked with the "**:fire: EXPERIMENTAL**" badge. Those are advanced features that are too young, or lack user feedback. They are not stabilized yet.

Those experimental features are not protected by semantic versioning, and may break between two minor releases of the library. To help them becoming stable, [your feedback](https://github.com/groue/GRDB.swift/issues) is greatly appreciated.

### Does GRDB support library evolution and ABI stability?

No, GRDB does not support library evolution and ABI stability. The only promise is API stability according to [semantic versioning](http://semver.org), with an exception for [experimental features](#what-are-experimental-features).

Yet, GRDB can be built with the "Build Libraries for Distribution" Xcode option (`BUILD_LIBRARY_FOR_DISTRIBUTION`), so that you can build binary frameworks at your convenience.


## FAQ: Associations

### How do I filter records and only keep those that are associated to another record?

Let's say you have two record types, `Book` and `Author`, and you want to only fetch books that have an author, and discard anonymous books.

We start by defining the association between books and authors:

```swift
struct Book: TableRecord {
    ...
    static let author = belongsTo(Author.self)
}

struct Author: TableRecord {
    ...
}
```

And then we can write our request and only fetch books that have an author, discarding anonymous ones:

```swift
let books: [Book] = try dbQueue.read { db in
    // SELECT book.* FROM book
    // JOIN author ON author.id = book.authorID
    let request = Book.joining(required: Book.author)
    return try request.fetchAll(db)
}
```

Note how this request does not use the `filter` method. Instead, we just need to "require that a book can be joined to its author".

### How do I filter records and only keep those that are NOT associated to another record?

Let's say you have two record types, `Book` and `Author`, and you want to only fetch anonymous books that do not have any author.

We start by defining the association between books and authors:

```swift
struct Book: TableRecord {
    ...
    static let author = belongsTo(Author.self)
}

struct Author: TableRecord {
    ...
}
```

And then we can write our request and only fetch anonymous books that don't have any author:

```swift
let books: [Book] = try dbQueue.read { db in
    // SELECT book.* FROM book
    // LEFT JOIN author ON author.id = book.authorID
    // WHERE author.id IS NULL
    let authorAlias = TableAlias<Author>()
    let request = Book
        .joining(optional: Book.author.aliased(authorAlias))
        .filter(!authorAlias.exists)
    return try request.fetchAll(db)
}
```

This request uses a TableAlias in order to be able to filter on the eventual associated author. We make sure that the `Author.primaryKey` is nil, which is another way to say it does not exist: the book has no author.

### How do I select only one column of an associated record?

Let's say you have two record types, `Book` and `Author`, and you want to fetch all books with their author name, but not the full associated author records.

We start by defining the association between books and authors:

```swift
struct Book: Decodable, TableRecord {
    ...
    static let author = belongsTo(Author.self)
}

struct Author: Decodable, TableRecord {
    ...
    enum Columns {
        static let name = Column(CodingKeys.name)
    }
}
```

And then we can write our request and the ad-hoc record that decodes it:

```swift
struct BookInfo: Decodable, FetchableRecord {
    var book: Book
    var authorName: String? // nil when the book is anonymous

    static func all() -> QueryInterfaceRequest<BookInfo> {
        // SELECT book.*, author.name AS authorName
        // FROM book
        // LEFT JOIN author ON author.id = book.authorID
        return Book
            .annotated(withOptional: Book.author.select {
                $0.name.forKey(CodingKeys.authorName)
            })
            .asRequest(of: BookInfo.self)
    }
}

let bookInfos: [BookInfo] = try dbQueue.read { db in
    BookInfo.all().fetchAll(db)
}
```


## FAQ: ValueObservation

### Why is ValueObservation not publishing value changes?

Sometimes it looks that a [ValueObservation](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/valueobservation) does not notify the changes you expect.

There may be four possible reasons for this:

1. The expected changes were not committed into the database.
2. The expected changes were committed into the database, but were quickly overwritten.
3. The observation was stopped.
4. The observation does not track the expected database region.

To answer the first two questions, look at SQL statements executed by the database. This is done when you open the database connection:

```swift
// Prints all SQL statements
var config = Configuration()
config.prepareDatabase { db in
    db.trace { print("SQL: \($0)") }
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

If, after that, you are convinced that the expected changes were committed into the database, and not overwritten soon after, trace observation events:

```swift
let observation = ValueObservation
    .tracking { db in ... }
    .print() // <- trace observation events
let cancellable = observation.start(...)
```

Look at the observation logs which start with `cancel` or `failure`: maybe the observation was cancelled by your app, or did fail with an error.

Look at the observation logs which start with `value`: make sure, again, that the expected value was not actually notified, then overwritten.

Finally, look at the observation logs which start with `tracked region`. Does the printed database region cover the expected changes?


## FAQ: Errors

### Generic parameter 'T' could not be inferred

You may get this error when using the `read` and `write` methods of database queues and pools:

```swift
// Generic parameter 'T' could not be inferred
let string = try dbQueue.read { db in
    let result = try String.fetchOne(db, ...)
    return result
}
```

This is a limitation of the Swift compiler.

The general workaround is to explicitly declare the type of the closure result:

```swift
// General Workaround
let string = try dbQueue.read { db -> String? in
    let result = try String.fetchOne(db, ...)
    return result
}
```

You can also, when possible, write a single-line closure:

```swift
// Single-line closure workaround:
let string = try dbQueue.read { db in
    try String.fetchOne(db, ...)
}
```


### Mutation of captured var in concurrently-executing code

The `insert` and `save` [persistence methods](Records.md#persistence-methods) can trigger a compiler error in async contexts:

```swift
var player = Player(id: nil, name: "Arthur")
try await dbWriter.write { db in
    // Error: Mutation of captured var 'player' in concurrently-executing code
    try player.insert(db)
}
print(player.id) // A non-nil id
```

When this happens, prefer the `inserted` and `saved` methods instead:

```swift
// OK
var player = Player(id: nil, name: "Arthur")
player = try await dbWriter.write { [player] db in
    return try player.inserted(db)
}
print(player.id) // A non-nil id
```


### SQLite error 1 "no such column"

This error message is self-explanatory: do check for misspelled or non-existing column names.

However, sometimes this error only happens when an app runs on a recent operating system (iOS 14+, Big Sur+, etc.) The error does not happen with previous ones.

When this is the case, there are two possible explanations:

1. Maybe a column name is *really* misspelled or missing from the database schema.

    To find it, check the SQL statement that comes with the [DatabaseError](BackupAndUtilities.md#databaseerror).

2. Maybe the application is using the character `"` instead of the single quote `'` as the delimiter for string literals in raw SQL queries. Recent versions of SQLite have learned to tell about this deviation from the SQL standard.

    For example: this is not standard SQL: `UPDATE player SET name = "Arthur"`.

    The standard version is: `UPDATE player SET name = 'Arthur'`.

    The fix is to change the SQL statements run by the application: replace `"` with `'` in your string literals.


### SQLite error 10 "disk I/O error", SQLite error 23 "not authorized"

Those errors may be the sign that SQLite can't access the database due to [data protection](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/encrypting_your_app_s_files).

When your application should be able to run in the background on a locked device, it has to catch this error, and, for example, wait for [UIApplicationDelegate.applicationProtectedDataDidBecomeAvailable(_:)](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1623044-applicationprotecteddatadidbecom) notification and retry the failed database operation.

```swift
do {
    try ...
} catch DatabaseError.SQLITE_IOERR, DatabaseError.SQLITE_AUTH {
    // Handle possible data protection error
}
```

This error can also be prevented altogether by using a more relaxed [file protection](https://developer.apple.com/reference/foundation/filemanager/1653059-file_protection_values).


### SQLite error 21 "wrong number of statement arguments" with LIKE queries

You may get the error "wrong number of statement arguments" when executing a LIKE query similar to:

```swift
let name = textField.text
let players = try dbQueue.read { db in
    try Player.fetchAll(db, sql: "SELECT * FROM player WHERE name LIKE '%?%'", arguments: [name])
}
```

The problem lies in the `'%?%'` pattern.

SQLite only interprets `?` as a parameter when it is a placeholder for a whole value (int, double, string, blob, null). In this incorrect query, `?` is just a character in the `'%?%'` string: it is not a query parameter.

To fix the error, you can feed the request with the pattern itself, instead of the name:

```swift
let name = textField.text
let players: [Player] = try dbQueue.read { db in
    let pattern = "%\(name)%"
    return try Player.fetchAll(db, sql: "SELECT * FROM player WHERE name LIKE ?", arguments: [pattern])
}
```
