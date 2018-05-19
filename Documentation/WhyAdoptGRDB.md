Why Adopt GRDB?
===============

This document aims at exposing why GRDB could become your favorite database library.

We'll start with a few [core principles](#core-principles), so that you see where this library aims at. Then we'll see how GRDB [solves problems](#solving-problems) that developers often face when they use database libraries such as FMDB, FCModel, SQLite.swift, Core Data, or Realm.


## Core Principles

### It is generally easier to access a database through "record types".

This is because a database row is not an easy type to deal with, and will never be, compared to a regular model. `player.name` looks and feels more natural than `playerRow["name"]`, doesn't it?

The reputation of "active records" and ORMs has been tarnished by the recent focus on immutability, memory safety, and functional idioms that comes with languages like Swift and Rust. Features of 1st-generation records such as auto-updating, uniquing, lazy loading of relations, etc. are now considered ill-advised, if not plain harmful because of the multi-threading headaches they cause.

Yet recent ORMs such as Rust's [Diesel] have shown that it is possible to build record types that behave as plain and simple values. GRDB belongs to this family.


### Raw SQL is sometimes the correct tool for the job.

Complex database queries sometimes need to be prototyped and debugged in an SQL shell. Once perfected, the process of translating this raw SQL query into calls to a query builder can be long and painful, with no guarantee of success. And the resulting code often lacks the legibility of the initial SQL. When this happens, the query builder is no longer useful: whoever wants to write raw SQL should always be welcome.


### The database file is the single source of truth.

Each Core Data's managed object context has its own version of the database. This can be useful when developing a macOS application full of inspector panels and nested undo stacks. But that's about it.

In the same vein, each application thread has its own version of a Realm database, with non trivial synchronization points.

Conversely, GRDB assumes that many apps want to use the database as a reliable and unambiguous storage.


### Applications developers have specific needs.

GRDB puts all bets on SQLite, and focuses on front-end GUI applications.

This means that dealing with servers, MySQL, or PostgreSQL is out of scope. GRDB is not an alternative to IBM's [Swift-Kuery], Vapor's [Fluent], or Perfect's [StORM].

Focusing on SQLite and applications has allowed GRDB to build features usually only found in company-sponsored libraries: migrations, record comparison, database observation, multi-threading safety, table view animations, support for reactive streams...

The bet of GRDB is that developers can take great profit from a library that provides efficient and community-tested solutions to existing problems. For example, one can not address the multithreading difficulties of Core Data or Realm without looking at database concurrency and records straight in the face.

Since you don't have to take my words for granted, we'll now see how GRDB actually solves common problems that developers face with other database libraries.


## Solving Problems

What is the purpose of the above principles, if not providing solutions to difficulties and limitations of other persistence libraries?


### Allow any Swift struct or class to become a database record

Most libraries that provide record types want you to subclass a root class: [NSManagedObject](https://developer.apple.com/documentation/coredata/nsmanagedobject), [Realm.Object](https://www.realm.io/docs/swift/latest), [FCModel](https://github.com/marcoarment/FCModel).

The main problem with those root classes is that they are classes. You can't define records from plain Swift structs, and leverage all advantages of Swift value types: immutability, multi-threading safety, etc.

With GRDB, any type can become a database record. For example, let's start from this `Place` struct:

```swift
struct Place {
    var id: Int64?
    let title: String
    let coordinate: CLLocationCoordinate2D
}
```

By adopting the [FetchableRecord] protocol, places can be loaded from SQL requests:

```swift
extension Place: FetchableRecord { ... }
let places = try Place.fetchAll(db, "SELECT * FROM place") // [Place]
```

Add the [TableRecord] protocol, and SQL requests are generated for you:

```swift
extension Place: TableRecord { ... }
let place = try Place.fetchOne(db, key: 1) // Place?
```

Add the [PersistableRecord] protocol, and places know how to insert, update and delete themselves:

```swift
extension Place: PersistableRecord { ... }
try place.delete(db)
```

Being a protocol-oriented library that welcomes immutable types, GRDB records are unlike records in other ORM libraries. Particularly, records do not auto-update, and records are not uniqued. We'll see below that the lack of those features can be replaced with **database change notifications**, with many advantages.


### Allow database records to cross threads

As soon as records are immutable values, they can safely be used from different threads. You no longer have to pass object ids or references between threads, as in Core Data or Realm:

```swift
if let player = try Player.fetchOne(db, key: 1) {
    DispatchQueue.main.async {
        nameField.text = player.name
    }
}
```


### Replace auto-updating records with notifications of database changes

GRDB records are plain values, like other values in your application. They are not tied to the database. Sometimes you build them from scratch, and sometimes you fetch them:

```swift
let player = Player(name: "arthur", score: 1000)
let players = try Player.fetchAll(db)
```

**Fetched records behave just like an in-memory cache of the database content.** Your application is free to decide, on its own, how it should handle the lifetime of those cached values: by ignoring future database changes, by observing database changes and react accordingly, or in any way deemed relevant.

There are several ways to be notified of database changes. You can build on top of the low-level [TransactionObserver] protocol. Or you can use [FetchedRecordsController], which looks a lot like Core Data's NSFetchedResultsController, and is able to animate table and collection views. And don't forget [RxGRDB], a set of reactive extensions based on [RxSwift]:

```swift
Player.all().rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        print("Players have changed")
    })
```

No matter which observation technique you use, you have common guarantees:

First, notifications only come from database changes safely saved on disk. This is part of the "database as the single source of truth" core principle. You won't get notifications from unsaved changes or changes that have an opportunity to be rollbacked.

Next, you choose the dispatch queue on which notifications happen. It can be on the special "writer queue", which allows you to process changes before any other thread has any opportunity to perform further database modifications. But notifications can also happen on the queue of your choice (generally the main queue, by default, as in the example above). Of course, GRDB makes sure notifications happen in the same order as database transactions.

Finally, all changes are notified, no matter how they are performed: record methods, raw SQL statements, foreign key cascades, and even SQL triggers. GRDB roots its notification system in the rock-solid SQLite itself, so that high-level requests and raw SQL queries are equally supported.


### Non-blocking database reads

GRDB ships with two ways to access databases, [database queues](../README.md#database-queues) and [pools](../README.md#database-pools).

Database queues look a lot like FMDB's [FMDatabaseQueue](https://github.com/ccgus/fmdb#using-fmdatabasequeue-and-thread-safety): they serialize database accesses in a serial dispatch queue. There is never more than one thread that is accessing the database. This means that a long running database transaction that happens in a background thread, such as the synchronization of your local database from a remote server, can block your UI. As long as the queue is busy, the main thread can't fetch the values it wants to display on screen.

[Database pools](../README.md#database-pools) can lift these unwanted locks. With database pools, reads are generally non-blocking, unless the maximum number of concurrent reads has been reached (and this maximum number can be configured).


### Strong and clear multi-threading guarantees

I'd like to compare GRDB's handling of concurrency with other libraries. To be as clear as possible, we'll identify a few threats, or potential sources of bugs, and wonder if those are handled by the library, or left to the host application.

The more threats are handled by the application, the more skilled and careful a developer has to be in order to avoid them.

- **Concurrent writes**: Two threads want to write in the database at the same time. SQLite does not allow that.
- **Isolation troubles**: As two database queries run one after the other, a concurrent thread sneaks in and modifies the database in between. The two queries can thus perform inconsistent fetches or updates, unless they are properly isolated. Lack of isolation may display funny values on the screen, trigger a relational constraint error, or silently corrupt the database content.
- **Conflicts**: The same piece of data is both edited by the application user, and refreshed from a network operation. What will eventually be stored in the database? Can any conflict be noticed?
- **Blocked UI**: Can it happen that the UI is blocked because the main thread has to wait for a background thread to release a lock on the database?


| Library | Concurrent Writes | Isolation Trouble | Conflicts | Blocked UI |
| ------- | ----------------- | ----------------- | --------- | ---------- |
| FMDB's FMDatabase | Handled by the application | Handled by the application | Handled by the application | Handled by the application |
| FMDB's FMDatabaseQueue | :white_check_mark: | :white_check_mark: | Handled by the application | UI is blocked |
| SQLite.swift | :white_check_mark: | Handled by the application | Handled by the application | Handled by the application |
| Core Data | Handled by the application, because of the constant threat of conflict errors | :white_check_mark: | Handled by the application, and it is very difficult because of the subtleties of Core Data's conflict policies | Handled by the application |
| GRDB's DatabaseQueue | :white_check_mark: | :white_check_mark: | Handled by the application | UI is blocked |
| GRDB's DatabasePool | :white_check_mark: | :white_check_mark: | Handled by the application | :white_check_mark: (as long as the maximum number of readers has not been reached) |

I had to omit [Realm] and [FCModel] from the list, because I don't know them well enough. Yet I'd bet that Realm shares some behaviors with Core Data, and FCModel shares some behaviors with FMDatabaseQueue.

We can see that the threat of conflicts is *always* left to the application. Core Data provides conflict policies, but no one can pretend that they are easy to plan, use, or test. This is an argument for leaving the application 100% responsible for conflict handling, in hope that simple ones can be handled in a simple way.

Finally, raw FMDatabase, SQLite.swift, and Core Data are the hardest tools, and you'd better be a very skilled developer in order to use them properly.

For further information about GRDB concurrency, check its detailed [Concurrency Guide].


### Never pay for using raw SQL

SQL is a weird language. Born in the 70s, easy to [misuse](https://xkcd.com/327/), feared by some developers, despised by others, and yet wonderfully concise and powerful.

GRDB [query interface] and [associations] can generate SQL for you:

```swift
// SELECT * FROM player ORDER BY score DESC LIMIT 10
let bestPlayers: [Player] = try Player
    .order(scoreColumn.desc)
    .limit(10)
    .fetchAll(db)

// SELECT MAX(score) FROM player
let maximumScore: Int? = try Player
    .select(max(scoreColumn))
    .asRequestOf(Int.self)
    .fetchOne(db)

// SELECT book.*, author.*
// FROM book
// LEFT JOIN author ON author.id = book.authorId
let request = Book.including(optional: Book.author)
let bookInfos: [BookInfo] = BookInfo.fetchAll(db, request)
```

But you can always switch to SQL when you want to:

```swift
let bestPlayers: [Player] = try Player.fetchAll(db, """
    SELECT * FROM player ORDER BY score DESC LIMIT 10
    """)

let maximumScore: Int? = try Int.fetchOne(db, """
    SELECT MAX(score) FROM player
    """)
```

Power users can also consume complex joined SQL queries into handy record values, by *adapting* raw database rows to the decoded records (see [Joined Queries Support](#../README.md#joined-queries-support)):

```swift
let bookInfos: [BookInfo] = SQLRequest<BookInfo>("""
    SELECT book.*, author.*
    FROM book
    LEFT JOIN author ON author.id = book.authorId
    """)
    .adapted { db in
        let adapters = try splittingRowAdapters(columnCounts: [
            db.columns(in: "book").count,
            db.columns(in: "author").count])
        return ScopeAdapter([
            "book": adapters[0],
            "author": adapters[1]])
    }
```

In performance-critical sections, you may want to deal with raw database rows, and fetch [lazy cursors](../README.md#cursors) instead of arrays:

```swift
let rows = try Row.fetchCursor(db, "SELECT id, name, score FROM player")
while let row = try rows.next() {
    let id: Int64 = row[0]
    let name: String = row[1]
    let score: Int = row[2]
}
```

When you feel like your code clarity would be enhanced by hiding your custom SQL in a dedicated method, you can build [custom requests](../README.md#custom-requests):

```swift
extension Player {
    static func customRequest(...) -> SQLRequest<Player> {
        return SQLRequest<Player>("SELECT ...", arguments: ...)
    }
}

let players = try Player.customRequest(...).fetchAll(db)
```

Those custom requests are welcome in database observation tools like [FetchedRecordsController] and [RxGRDB]:

```swift
Player.customRequest(...).rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { players: [Player] in
        print("Players have changed")
    })
```

---

If this little tour of GRDB has convinced you, the real trip starts here: [GRDB].

And if you happen to maintain an Objective-C application that uses FMDB, checkout [GRDBObjc]. It provides FMDB-compatible bindings to GRDB, so that you can inject sweet drops of Swift into your app, at your own pace, and at minimal cost.

Happy GRDB! :gift:

[Concurrency Guide]: ../README.md#concurrency
[Core Data]: https://developer.apple.com/documentation/coredata
[DatabasePool]: ../README.md#database-pools
[Diesel]: http://diesel.rs
[FCModel]: https://github.com/marcoarment/FCModel
[FetchedRecordsController]: ../README.md#fetchedrecordscontroller
[Fluent]: https://github.com/vapor/fluent
[FMDB]: http://github.com/ccgus/fmdb
[GRDB]: http://github.com/groue/GRDB.swift
[GRDBObjc]: http://github.com/groue/GRDBObjc
[PersistableRecord]: ../README.md#records
[Realm]: http://realm.io
[FetchableRecord]: ../README.md#records
[RxGRDB]: https://github.com/RxSwiftCommunity/RxGRDB
[RxSwift]: https://github.com/ReactiveX/RxSwift
[SQLite.swift]: http://github.com/stephencelis/SQLite.swift
[StORM]: https://www.perfect.org/docs/StORM.html
[Swift-Kuery]: http://github.com/IBM-Swift/Swift-Kuery
[TableRecord]: ../README.md#records
[TransactionObserver]: ../README.md#transactionobserver-protocol
[query interface]: ../README.md#the-query-interface
[associations]: AssociationsBasics.md
