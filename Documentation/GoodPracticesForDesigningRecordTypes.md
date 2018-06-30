Good Practices for Designing Record Types
=========================================

This guide aims at helping you leverage the best of GRDB [records] and [associations].

Since GRDB sits right between low-level libraries like SQLite itself or [FMDB], and high-level ORM like [Core Data] or [Realm], you may face questions when designing the model layer of your application.

To support this guide, we'll design a simply library application that lets the user crawl through books and their authors.

- [Trust SQLite More Than Yourself]
- [Record Types are Responsible for Their Tables]
- [Compose Records]
- [Fetch In Time]
- [Observe the Database and Refetch when Needed]


## Trust SQLite More Than Yourself

SQLite is a robust database. Even if you don't know it well, and aren't familiar with the SQL language, you are able to take profit from its solid foundation. It is very difficult to corrupt an SQLite database file. And it can make sure that only valid information is persisted on disk.

This is important because we developers write bugs, and some of them will ship in the wild, affecting your application users. But thanks to SQLite, those bugs will be unable to corrupt your precious users' data. All it takes is a robust **database schema**.

For example, if we were to define a [migration] that sets up our library database, made of books and their authors, we could write:

```swift
var migrator = DatabaseMigrator()

migrator.registerMigration("createLibrary") { db in
    try db.create(table: "author") { t in             // (1)
        t.autoIncrementedPrimaryKey("id")             // (2)
        t.column("name", .text).notNull()             // (3)
    }
    
    try db.create(table: "book") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("title", .text).notNull()            // (4)
        t.column("authorId", .integer)                // (5)
            .notNull()                                // (6)
            .indexed()                                // (7)
            .references("author", onDelete: .cascade) // (8)
    }
}

try migrator.migrate(dbQueue)
```

1. Our database table names follow the GRDB 3 recommendation: generally speaking they should be singular, and camel-cased. Make them look like Swift identifiers: `author`, `book`, `postalAddress`, `httpRequest`.
2. Each author has a unique id.
3. An author must have a name.
4. A book must have a title.
5. The `book.authorId` column is used to link a book to the author it belongs to.
6. The `book.authorId` column is not null so that SQLite guarantees that all books have an author.
7. The `book.authorId` column is indexed in order to ease the selection of an author's books.
8. We define a foreign key from `book.authorId` column to `authors.id`, so that SQLite guarantees that no book can refer to a missing author. On top of that, the `onDelete: .cascade` option has SQLite automatically delete all of an author's books when that author is deleted. See [Foreign Key Actions] for more information.

Thanks to this database schema, you can be confident so no matter how wrong our application goes, it will always process *consistent data*. Even after a hard crash, application will always find the author of any book, all books will have a non-nil title, etc.

> :bulb: **Tip**: Don't look at your local SQLite database as you look at the JSON you load from a remote server. You can't control the JSON, its format and content: your application must defend itself against wacky servers. But you can control the database. Put the database on your side, make it trustable. Learn about relational databases, and how they can help you guarantee the quality of your application data. Put as much energy as you can in the proper definition of your database schema.
>
> :bulb: **Tip**: Plan early for future versions of your application, and use [migrations].
>
> :bulb: **Tip**: In the definition of your migrations, define tables and their columns with **strings**:
>
> ```swift
> migrator.registerMigration("createLibrary") { db in
>     // RECOMMENDED
>     try db.create(table: "author") { t in
>         t.autoIncrementedPrimaryKey("id")
>         ...
>     }
>
>     // NOT RECOMMENDED
>     try db.create(table: Author.databaseTableName) { t in
>         t.autoIncrementedPrimaryKey(Author.Columns.id.name)
>         ...
>     }
> }
> ```
>
> By using strings, you make sure that you will not have to change the Swift code of your migrations in the future. Even if author columns eventually change. Even if the Author type eventually gets replaced with another type. Even when your startup eventually pivots and starts selling pet food. A good migration that never changes is easy to test once and for good. A good migration that never changes will run smoothly on all devices in the wild, even if a user upgrades straight from version 1.0 to version 5.0 of your application.
>
> So make sure that migrations don't use application types and values: migrations should talk to the database, only to the database, and use the database language: **strings**.


## Record Types are Responsible for Their Tables

Define one record type per database table.

In this sample code, we'll use codable structs, but there are [other ways](../README.md#examples-of-record-definitions) to define records.

```swift
struct Author: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var name: String
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

struct Book: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var authorId: Int64
    var title: String
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
```

That's it. The `Author` type can read and write in the `author` database table. `Book` as well, in `book`. See [record protocols] for more information.

> :bulb: **Tip**: When a column of a database table can't be NULL, store it in a non-optional property of your record type. On the other side, when the database may contain NULL, define an optional property.
> 
> :bulb: **Tip**: When a database table uses an auto-incremented identifier, make the `id` property optional (so that you can instantiate a record before it gets inserted and gains an id), and implement the `didInsert(with:for:)` method:
>
> ```swift
> var author = Author(id: nil, name: "Hermann Melville")
> try author.insert(db)
> print(author.id) // Some non-nil id
> ```

Since `Author` and `Book` can insert, update, and delete rows in the `author` and `book` database tables, they are *responsible for modifying those database tables*.

Applying the **[Single Responsibility Principle]** has a consequence: don't even try to have an author responsible for its books. Don't add a `books: [Book]` property in Author. Don't let Author write in the `book` table. When a new fellow coworker joins your team and asks you "who is saving books in the database?", you don't want to answer "it depends." You want to confidently answer: "the Book type".

> :bulb: **Tip**: Make sure each record type deals with one database table, and only one database table.


## Compose Records

Now that we have two types for authors and books, we'd like to navigate from books to authors and vice-versa: we may want to know an author's books, or a book's author.

GRDB can help you do this with [associations]. In our case, each author **has many** books, and each book **belongs to** its author. Here is how you define those associations, along with their companion properties:

```swift
extension Author {
    static let books = hasMany(Book.self)
    var books: QueryInterfaceRequest<Book> {
        return request(for: Author.books)
    }
}

extension Book {
    static let author = belongsTo(Author.self)
    var author: QueryInterfaceRequest<Author> {
        return request(for: Book.author)
    }
}
```

Thanks to this setup, you can fetch associated records:

```swift
// Fetch an author and its books
struct AuthorInfo {
    var author: Author
    var books: [Book]
}
let authorInfo: AuthorInfo? = try dbQueue.read { db in
    guard let author = try Author.fetchOne(db, key: 123) else { return nil }
    let books = try author.books.fetchAll(db)
    return AuthorInfo(author: author, books: books)
}

// Fetch all authorships
struct Authorship: Decodable, FetchableRecord {
    var book: Book
    var author: Author
}
let authorships: [Authorship] = try dbQueue.read { db in
    let request = Book.including(required: Book.author)
    return try Authorship.fetchAll(db, request)
}
```

The example `AuthorInfo` and `Authorship` types above may look superfluous to you. After all, other ORMs out there are able to navigate in complex graphs of records without much fuss, aren't they?

That is because other ORMs perform lazy loading:

```ruby
# Ruby's Active Record
author = Author.find(123) # fetch author
books = author.books      # lazily fetches books on demand
```

GRDB does not perform lazy loading. Lazy loading either requires record to be *managed* (as in [Core Data] and [Realm]), or that all data processing happens in a *single function* (think of an HTTP request handled with a web-oriented ORM like [Active Record] and [Django]). The underlying issue is *data consistency*: you always want your memory objects to accurately represent your application data, without any glitch, ever. This involves the subtle database concept of [isolation] against concurrent changes. In a GUI application, this can't be achieved without a very complex record management, and non-trivial pain points for the application developer. This is why GRDB has removed lazy loading from the list of desirable features. See the "Solving Problems" chapter of [Why Adopt GRDB?](WhyAdoptGRDB.md#solving-problems) for more information.

The consequence is that each part of your application will load the data it needs, at the moment it needs it, as below:

1. Prepare the application screen that lists all authors:
    
    ```swift
    let authors: [Author] = dbQueue.read { db in
        Author.order(Colum("name")).fetchAll(db)
    }
    ```

2. Prepare the application screen that displays an author and her books:
    
    ```swift
    struct AuthorInfo {
        var author: Author
        var books: [Book]
    }
    let authorId = 123
    let authorInfo: AuthorInfo? = try dbQueue.read { db in
        guard let author = try Author.fetchOne(db, key: authorId) else { return nil }
        let books = try author.books.fetchAll(db)
        return AuthorInfo(author: author, books: books)
    }
    ```

3. Prepare the application screen that displays a book information:
    
    ```swift
    struct BookInfo: Decodable, FetchableRecord {
        var book: Book
        var author: Author
    }
    let bookId = 123
    let bookInfo: BookInfo? = try dbQueue.read { db in
        let request = Book
            .filter(key: bookId)
            .including(required: Book.author)
        return try BookInfo.fetchOne(db, request)
    }
    ```

> :bulb: **Tip**: Identify the various **graph of objects** needed by the various parts of your application. Design them independently, by composing the basic record types. Fetch the data your application needs, at the moment it needs it, no more, no less.


## Fetch In Time

> :bulb: **Tip**: Make sure you fetch all the data your application needs in a **single database read**.

```swift
// NOT RECOMMENDED
let bookId = 123
// Two fetches not grouped in a single `read` block:
if let book = databaseManager.getBook(id: bookId) {
    let author = databaseManager.getAuthor(id: book.authorId)!
    // use book and author
}

// RECOMMENDED (without associations)
let bookId = 123
let bookInfo: BookInfo? = try dbQueue.read { db in
    // All fetches are grouped in a single `read` block:
    if let book = try Book.fetchOne(db, key: bookId) {
        let author = try Author.fetchOne(db, key: book.authorId)!
        return BookInfo(book: book, author: author)
    } else {}
        return nil
    }
}
if let bookInfo = bookInfo {
    // use bookInfo
}

// RECOMMENDED (with associations)
let bookId = 123
let bookInfo: BookInfo? = try dbQueue.read { db in
    // All fetches are grouped in a single `read` block:
    let request = Book
        .filter(key: bookId)
        .including(required: Book.author)
    return try BookInfo.fetchOne(db, request)
}
if let bookInfo = bookInfo {
    // use bookInfo
}
```

This tip is paramount, and deserves an explanation because too many database libraries out there tend to completely disregard multi-threading gotchas.

When you do not fetch your data in a single database access block, other threads of your application may modify the database in the background, and have you fetch inconsistent data. This leads to hard-to-reproduce bugs, from funny values on screen to data loss.

Wrapping all fetches in a `read` method may look like an inconvenience to you. After all, other ORMs don't require that much ceremony:

```ruby
# Ruby's Active Record
if book = Book.find(123) # fetch book
  author = book.author   # fetch author
  # use book and author
end
```

The problem is that it is very hard to guarantee that you will surely fetch an author after you have fetched a book, despite the constraints of the database schema. One has to perform subsequent fetches in the proper [isolation] level, so that eventual concurrent writes that modify the database are unable to mess with subsequent requests.

This isolation can be achieved with record management, as in [Core Data] or [Realm], that target long-running multi-threaded applications. On the other side, most web-oriented ORMs rely on short-lived database transactions, so that each HTTP request can be processed independently of others.

GRDB is not a managed ORM. It thus has to use the same isolation techniques as web-oriented ORMs. But unlike web-oriented ORMs, GRDB can't provide implicit isolation: the application must decide when it wants to safely read information in the database, and this decision is made explicit with database access methods such as `dbQueue.read`.

Do not overlook this advice, or your application will exhibit weird concurrency-related bugs. Read the [Concurrency Guide] for detailed information, and the "Solving Problems" chapter of [Why Adopt GRDB?](WhyAdoptGRDB.md#solving-problems) for more rationale.


## Observe the Database and Refetch when Needed

We have seen above that the Author and Book record types are [responsible](#record-types-are-responsible-for-their-tables) for their own dedicated database tables. Later we [composed](#compose-records) them into more complex types such as `BookInfo` or `AuthorInfo`. We advised the application to fetch database information [right on time](#fetch-in-time), when it needs to process it.

Fetched information eventually becomes obsoleted, as the application modifies the database content.

It is up to the application to decide how long it should keep fetched information in memory. Very often though, the application will want to keep memory information synchronized with the database content.

This synchronization is not automatic with GRDB: records do not "auto-update". That is because applications do not always want this feature, and because it is difficult to write correct multi-threaded applications when values can change in unexpected ways.

Instead, have a look at [Database Observation]:

> :bulb: **Tip**: Use [FetchedRecordsController] when a table or collection views should remained synchronized with the database, in an animated way.
>
> :bulb: **Tip**: Use [RxGRDB] when your application needs to react to all changes in the results of a database request.
>
> :bulb: **Tip**: Use [TransactionObserver], the low-level protocol for database observation, for your most advanced needs.
>
> :bulb: **Tip**: Don't try to write complex methods that both modify the database and the values in memory at the same time. Instead, modify the database with plain record types, and rely on database observation for automatically refreshing values, even complex ones.


[records]: ../README.md#records
[associations]: AssociationsBasics.md
[FMDB]: https://github.com/ccgus/fmdb
[Core Data]: https://developer.apple.com/documentation/coredata
[Realm]: https://realm.io
[Active Record]: http://guides.rubyonrails.org/active_record_basics.html
[Django]: https://docs.djangoproject.com/en/2.0/topics/db/
[record protocols]: ../README.md#record-protocols-overview
[Separation of Concerns]: https://en.wikipedia.org/wiki/Separation_of_concerns
[Single Responsibility Principle]: https://en.wikipedia.org/wiki/Single_responsibility_principle
[Single Source of Truth]: https://en.wikipedia.org/wiki/Single_source_of_truth
[Divide and Conquer]: https://en.wikipedia.org/wiki/Divide_and_rule
[Why Adopt GRDB?]: WhyAdoptGRDB.md
[isolation]: https://en.wikipedia.org/wiki/Isolation_(database_systems)
[migrations]: ../README.md#migrations
[migration]: ../README.md#migrations
[Foreign Key Actions]: https://sqlite.org/foreignkeys.html#fk_actions
[Concurrency Guide]: ../README.md#concurrency
[PersistableRecord]: ../README.md#persistablerecord-protocol
[Database Observation]: ../README.md#database-changes-observation
[FetchedRecordsController]: ../README.md#fetchedrecordscontroller
[RxGRDB]: http://github.com/RxSwiftCommunity/RxGRDB
[TransactionObserver]: ../README.md#transactionobserver-protocol
[Trust SQLite More Than Yourself]: #trust-sqlite-more-than-yourself
[Record Types are Responsible for Their Tables]: #record-types-are-responsible-for-their-tables
[Compose Records]: #compose-records
[Fetch In Time]: #fetch-in-time
[Observe the Database and Refetch when Needed]: #observe-the-database-and-refetch-when-needed
