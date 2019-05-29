Good Practices for Designing Record Types
=========================================

This guide aims at helping you leverage the best of GRDB [records] and [associations].

Since GRDB sits right between low-level libraries like SQLite itself or [FMDB], and high-level ORM like [Core Data] or [Realm], you may face questions when designing the model layer of your application.

To support this guide, we'll design a simple library application that lets the user crawl through books and their authors.

- [Trust SQLite More Than Yourself]
- [Persistable Record Types are Responsible for Their Tables]
- [Define Record Requests]
- [Compose Records]
- [How to Design Database Managers]
- [Observe the Database and Refetch when Needed]


## Trust SQLite More Than Yourself

It is important to put things in the right order. An SQLite database stored on one of your user's device is more important than the Swift code that accesses it. When a user installs a new version of your application, all the code may change, but the database remains the same.

This is why we recommend defining a **robust database schema** even before playing with record types.

SQLite is a battle-tested database. Even if you don't know it well, and aren't familiar with the SQL language, you are able to take profit from its solid foundation. It is very difficult to corrupt an SQLite database file. And it can make sure that only valid information is persisted on disk.

This is important because we developers write bugs, and some of them will ship in the wild, affecting the users of our applications. But SQLite will prevent many of those bugs from corrupting our precious users' data.

For example, if we were to define a [migration] that sets up our library database, made of books and their authors, we could write:

```swift
var migrator = DatabaseMigrator()

migrator.registerMigration("createLibrary") { db in
    try db.create(table: "author") { t in             // (1)
        t.autoIncrementedPrimaryKey("id")             // (2)
        t.column("name", .text).notNull()             // (3)
        t.column("country", .text)                    // (4)
    }
    
    try db.create(table: "book") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("title", .text).notNull()            // (5)
        t.column("authorId", .integer)                // (6)
            .notNull()                                // (7)
            .indexed()                                // (8)
            .references("author", onDelete: .cascade) // (9)
    }
}

try migrator.migrate(dbQueue)
```

1. Our database table names follow the [recommended convention]: they are English, singular, and camelCased. They look like Swift identifiers: `author`, `book`, `postalAddress`, `httpRequest`.
2. Each author has a unique id.
3. An author must have a name.
4. The country of an author is not always known.
5. A book must have a title.
6. The `book.authorId` column is used to link a book to the author it belongs to.
7. The `book.authorId` column is not null so that SQLite guarantees that all books have an author.
8. The `book.authorId` column is indexed in order to ease the selection of an author's books.
9. We define a foreign key from `book.authorId` column to `authors.id`, so that SQLite guarantees that no book can refer to a missing author. On top of that, the `onDelete: .cascade` option has SQLite automatically delete all of an author's books when that author is deleted. See [Foreign Key Actions] for more information.

Thanks to this database schema, you can be confident that no matter how wrong our application goes, it will always process *consistent data*. Even after a hard crash, application will always find the author of any book, all books will have a non-nil title, etc.

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


## Persistable Record Types are Responsible for Their Tables

Define one record type per database table, and make it adopt a [PersistableRecord] protocol.

In this sample code, we'll use Codable structs, but there are [other ways](../README.md#examples-of-record-definitions) to define records.

```swift
struct Author: Codable {
    var id: Int64?
    var name: String
    var country: String?
}

struct Book: Codable {
    var id: Int64?
    var authorId: Int64
    var title: String
}

// Add Database access

extension Author: FetchableRecord, MutablePersistableRecord {
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

extension Book: FetchableRecord, MutablePersistableRecord {
    // Update auto-incremented id upon successful insertion
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
> try dbQueue.write { db in
>     var author = Author(id: nil, name: "Hermann Melville", country: "United States")
>     try author.insert(db)
>     print(author.id!) // Guaranteed non-nil id
> }
> ```

Since `Author` and `Book` can insert, update, and delete rows in the `author` and `book` database tables, they are *responsible for modifying those database tables*.

Applying the **[Single Responsibility Principle]** has a consequence: don't even try to have an author responsible for its books. Don't add a `books: [Book]` property in Author. Don't let Author write in the `book` table. When a new fellow coworker joins your team and asks you "who is saving books in the database?", you don't want to answer "it depends." You want to confidently answer: "the Book type".

> :bulb: **Tip**: Make sure each record type deals with one database table, and only one database table.


## Define Record Requests

Now that we have record types that are able to read and write in the database, we'd like to put them to good use.

> :bulb: **Tip**: Define requests which make sense for your application in your record types.

A good place to define those requests is in a constrained extension of the `DerivableRequest` protocol:

```swift
extension Author {
    // Define database columns from CodingKeys
    fileprivate enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let country = Column(CodingKeys.country)
    }
}

extension DerivableRequest where RowDecoder == Author {
    /// Returns a request for all authors ordered by name, in a localized
    /// case-insensitive fashion
    func orderByName() -> Self {
        let name = Author.Columns.name
        return order(name.collating(.localizedCaseInsensitiveCompare))
    }
    
    /// Returns a request for all authors from a country
    func filter(country: String) -> Self {
        return filter(Author.Columns.country == country)
    }
}
```

Requests defined in an extension of the `DerivableRequest` protocol are nice in many ways:

1. They hide intimate database details like database columns inside the record types, and make your application code crystal clear:

    ```swift
    let sortedAuthors = try dbQueue.read { db in
        try Author.all().orderByName().fetchAll(db)
    }
    ```

2. You can use those requests to [observe database changes] in order to, say, reload a table view:

    ```swift
    try ValueObservation
        .trackingAll(Author.all().orderByName())
        .start(in: dbQueue) { (authors: [Author]) in
            print("fresh authors: \(authors)")
        }
    ```

3. Extensions on `DerivableRequest` can be composed:

    ```swift
    try dbQueue.read { db in
        let sortedAuthors = try Author.all()
            .orderByName()
            .fetchAll(db)
        let frenchAuthors = try Author.all()
            .filter(country: "France")
            .fetchAll(db)
        let sortedSpanishAuthors = try Author.all()
            .filter(country: "Spain")
            .orderByName()
            .fetchAll(db)
    }
    ```

4. Extensions on `DerivableRequest` are also available on record [associations]:

    ```swift
    extension DerivableRequest where RowDecoder == Book {
        /// Returns a request for all books from a country
        func filter(authorCountry: String) -> Self {
            // A book is from a country if it can be
            // joined with an author from that country:
            return joining(required: Book.author.filter(country: authorCountry))
            //                                  ^ here!
        }
    
        /// Returns a request for all books ordered by title, in a localized
        /// case-insensitive fashion
        func orderByTitle() -> Self {
            let title = Book.Columns.title
            return order(title.collating(.localizedCaseInsensitiveCompare))
        }
    }

    try dbQueue.read { db in
        let sortedItalianBooks = try Book.all()
            .filter(authorCountry: "Italy")
            .orderByTitle()
            .fetchAll(db)
    }
    ```

    For more information about associations, see [Compose Records] below.

Not all requests can be defined in an extension of `DerivableRequest`, though. That is because not everything can be expressed on both requests and associations. For example, [Association Aggregates] are only available on requests. When this happens, define your requests in a constrained extension to `QueryInterfaceRequest`:

```swift
extension QueryInterfaceRequest where RowDecoder == Author {
    /// Returns a request for all authors with at least one book
    func havingBooks() -> QueryInterfaceRequest<Author> {
        return having(Author.books.isEmpty == false)
    }
}
````

Those requests still compose nicely:

```swift
try dbQueue.read { db in
    let sortedFrenchAuthorsHavingBooks = try Author.all()
        .filter(country: "France")
        .havingBooks()
        .orderByName()
        .fetchAll(db)
}
```

Finally, when it happens that a request only makes sense when defined on the Record type itself, just go ahead and define a static method on your Record type:

```swift
extension MySingletonRecord {
    /// The one any only record stored in the database
    static let shared = all().limit(1)
}

let singleton = try dbQueue.read { db
    try MySingletonRecord.shared.fetchOne(db)
}
```


## Compose Records

We'd like to navigate from books to authors and vice-versa: we may want to know an author's books, or a book's author.

GRDB can help you do this with [associations]. In our case, each author **has many** books, and each book **belongs to** its author. Here is how you define those associations:

```swift
extension Author {
    static let books = hasMany(Book.self)
}

extension Book {
    static let author = belongsTo(Author.self)
}
```

Thanks to this setup, you can fetch associated records, or compute aggregated values from associated records. For example:

```swift
// Fetch all authors and their number of books
struct AuthorInfo: Decodable, FetchableRecord {
    var author: Author
    var bookCount: Int
}
let authorInfos: [AuthorInfo] = try dbQueue.read { db in
    let request = Author.annotated(with: Author.books.count)
    return try AuthorInfo.fetchAll(db, request)
}

// Fetch all Colombian books and their authors:
struct Authorship: Decodable, FetchableRecord {
    var book: Book
    var author: Author
}
let authorships: [Authorship] = try dbQueue.read { db in
    let request = Book.including(required: Book.author.filter(country: "Colombia"))
    return try Authorship.fetchAll(db, request)
}
```

As in the sample code above, requests which feed from several associated records will often have you define extra record types, such as `AuthorInfo` and `Authorship`. Those extra record types are designed to be able to decode database requests. The names and types of their properties follow the conventions defined by [associations]. Make them conform to the Decodable and FetchableRecord protocols so that they can decode database rows in a breeze.

Unlike the primitive persistable record types `Author` and `Book`, those records can not write in the database. They are simple data types, passive views on the database content. Remember, only [Persistable Record Types are Responsible for Their Tables].

> :question: **Note**: The example `AuthorInfo` and `Authorship` types above may look superfluous to you. After all, other ORMs out there are able to navigate in complex graphs of records without much fuss, aren't they?
>
> That is because other ORMs perform lazy loading:
>
> ```ruby
> # Ruby's Active Record
> author = Author.find(123)       # fetch author
> book_count = author.books.count # lazily counts books on demand
> ```
> 
> GRDB does not perform lazy loading. Lazy loading either requires records to be *managed* (as in [Core Data] and [Realm]), or that all data processing happens in a *single function* (think of an HTTP request handled with a web-oriented ORM like [Active Record] and [Django]). The underlying issue is *data consistency*: you always want your memory objects to accurately represent your application data, without any glitch, ever. This involves the subtle database concept of [isolation] against concurrent changes. In a GUI application, this can't be achieved without a very complex record management, and non-trivial pain points for the application developer.
>
> This is why GRDB has removed lazy loading from the list of desirable features. Instead, it provides the tooling needed to fetch data, even complex ones, in a single and safe stroke. See the "Solving Problems" chapter of [Why Adopt GRDB?](WhyAdoptGRDB.md#solving-problems) for more information.

Granted with primitive and derived record types, your application will load the data it needs, at the moment it needs it, as below:

1. Prepare the application screen that lists all authors:
    
    ```swift
    let authors: [Author] = try dbQueue.read { db in
        try Author.all().orderByName().fetchAll(db)
    }
    ```

2. Prepare the application screen that displays an author and her books:
    
    ```swift
    struct AuthorInfo: Codable, FetchableRecord {
        var author: Author
        var books: [Book]
    }
    let authorId = 123
    let authorInfo: AuthorInfo? = try dbQueue.read { db in
        let request = Author
            .filter(key: authorId)
            .including(all: Author.books)
        return try AuthorInfo.fetchOne(db, request)
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

> :bulb: **Tip**: Identify the various **graph of objects** needed by the various parts of your application. Design them independently, by composing primitive record types linked by associations. Fetch the data your application needs, at the moment it needs it, no more, no less.

A last extension on your record types will further help navigation from records to associated ones:

```swift
extension Author {
    /// The request for the author's books
    var books: QueryInterfaceRequest<Book> {
        return request(for: Author.books)
    }
}

extension Book {
    /// The request for the author of the book
    var author: QueryInterfaceRequest<Author> {
        return request(for: Book.author)
    }
}
```

Those properties provide an alternative way to feed our application:

1. Prepare the application screen that displays an author and her books:
    
    ```swift
    struct AuthorInfo {
        var author: Author
        var books: [Book]
    }
    let authorId = 123
    let authorInfo: AuthorInfo? = try dbQueue.read { db in
        guard let author = try Author.fetchOne(db, key: authorId) else {
            return nil
        }
        let books = try author.books.fetchAll(db)
        return AuthorInfo(
            author: author,
            books: books)
    }
    ```

2. Prepare the application screen that displays a book information:
    
    ```swift
    struct BookInfo {
        var book: Book
        var author: Author
    }
    let bookId = 123
    let bookInfo: BookInfo? = try dbQueue.read { db in
        guard let book = try Book.fetchOne(db, key: bookId) else {
            return nil
        }
        guard let author = try book.author.fetchOne(db) else {
            return nil
        }
        return BookInfo(book: book, author: author)
    }
    ```


## How to Design Database Managers

Many developpers want to hide GRDB database queues and pools inside "database managers":

```swift
// LibraryManager grants access to the library database.
class LibraryManager {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
}
```

> :bulb: **Tip**: Don't let your database managers create their own databases. Instead, give them a database created by, say, the ApplicationDelegate. This will allow you to efficiently test the database manager with an in-memory database, for example.

Design your database managers with the [GRDB concurrency rules] in mind.

Practically, let's start with a naive example, and gradually improve it:

```swift
// A naive manager that we will improve
class NaiveLibraryManager {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func author(id: Int64) -> Author? {
        do {
            return try dbQueue.read { db in
                try Author.fetchOne(db, key: id)
            }
        } catch {
            return nil
        }
    }
    
    func book(id: Int64) -> Book? {
        do {
            return try dbQueue.read { db in
                try Book.fetchOne(db, key: id)
            }
        } catch {
            return nil
        }
    }
    
    func books(writtenBy author: Author) -> [Book] {
        do {
            return try dbQueue.read { db in
                try author.books.fetchAll(db)
            }
        } catch {
            return []
        }
    }
}
```

**This manager can be improved in two ways.**

- [Embrace Errors]
- [Thread-Safety is also an Application Concern]

### Embrace Errors

Have database managers throw database errors instead of catching them.

Consider Apple's [CNContactStore](https://developer.apple.com/documentation/contacts/cncontactstore), for example. Does it hide errors when you fetch or save address book contacts? No it does not. Keychain, Media assets, File system, Core Data? No they do not hide errors either. Follow the practices of Apple engineers: do not hide errors :muscle:

Exposing errors will help you building your application:

- You will be able to inspect errors during development, and fix bugs. `do { ... } catch { print(error) }` will save you hours of clueless questioning.
- You will be able to opt in for advanced OS features like [data protection].

> :bulb: **Tip**: Don't hide database errors. Let the application handle them, because only application can decide how to handle them.

This gives the improved manager below. And it has less code, which means less bugs :bowtie:

```swift
// An improved manager that does not hide errors
class ImprovedLibraryManager {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func author(id: Int64) throws -> Author? {
        return try dbQueue.read { db in
            try Author.fetchOne(db, key: id)
        }
    }
    
    func book(id: Int64) throws -> Book? {
        return try dbQueue.read { db in
            try Book.fetchOne(db, key: id)
        }
    }
    
    func books(writtenBy author: Author) throws -> [Book] {
        return try dbQueue.read { db in
            try author.books.fetchAll(db)
        }
    }
}
```


### Thread-Safety is also an Application Concern

Now, let's make our database manager **thread-safe**.

This one is more subtle. In order to understand what is wrong in our naive manager, one has to consider how it is used by the application.

For example, in the screen that displays an author and her books, we would write:

```swift
let authorId = 123
if let author = libraryManager.author(id: authorId) {
    let books = libraryManager.books(writtenBy: author)
    // Use author and books
}
```

This code is not thread-safe, because other application threads may have modified the database between the two database accesses. You may end up with an author without any book, and this sure does not make a pretty application screen.

Such bugs are uneasy to reproduce. Sometimes your application will refresh the library content from the network, and delete an author right at the wrong time. The more users your application has, the more users will see weird screens. And of course, you'll be bitten right on the day of the demo in front of the boss.

Fortunately, GRDB has all the tools you need to prevent such nasty data races:

> :bulb: **Tip**: Make sure you fetch all the data your application needs at a given moment of time, in a **single database read**.

This gives a much safer manager:

```swift
// A manager that actually manages
class LibraryManager {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
}

// Feeds the list of authors
extension LibraryManager {
    struct AuthorListItem: Decodable, FetchableRecord {
        let author: Author
        let bookCount: Int
    }
    
    func authorList() throws -> [AuthorListItem] {
        return try dbQueue.read { db in
            let request = Author
                .annotated(with: Author.books.count)
                .orderByName()
            return try AuthorListItem.fetchAll(db, request)
        }
    }
}

// Feeds a book screen
extension LibraryManager {
    struct BookInfo {
        var book: Book
        var author: Author
    }
    
    func bookInfo(bookId: Int64) throws -> BookInfo? {
        return try dbQueue.read { db in
            guard let book = try Book.fetchOne(db, key: bookId) else {
                return nil
            }
            guard let author = try book.author.fetchOne(db) else {
                return nil
            }
            return BookInfo(book: book, author: author)
        }
    }
}

// Feeds an author screen
extension LibraryManager {
    struct AuthorInfo {
        var author: Author
        var books: [Book]
    }
    
    func authorInfo(authorId: Int64) throws -> AuthorInfo? {
        return try dbQueue.read { db in
            guard let author = try Author.fetchOne(db, key: authorId) else {
                return nil
            }
            let books = try author.books.fetchAll(db)
            return AuthorInfo(author: author, books: books)
        }
    }
}
```

The `AuthorListItem`, `BookInfo`, `AuthorInfo` types returned by the manager are designed to feed your view controllers.

When a new screen is added to your application, and you want to make sure it displays **consistent data** free from any data race, make sure you update the manager if needed. The rule is very simple: consumed data must come from a **single database access** (`dbQueue.read`, `write`, etc.)

This may sound unusual. Aren't view controllers (or view models, or presenters, depending on your application architecture) supposed to freely pick and compose the pieces of data they need from a general-purpose database manager which stands passively in front of the database?

Well, not quite with GRDB. It is an unmanaged ORM, so some amount of management must be imported into your application.

If you happen to connect to HTTP apis sometimes, here is a way to look at it: have your database manager behave like a web server! Each method of the database manager behaves like a GET, PUT, POST or DELETE endpoint, that performs its job, only its job, and performs it well. Do you like it when a screen of your app has to feed from several HTTP requests? I personally do not, because it is more difficult, error management is tricky, etc. Well, it is the same with your database managers: don't force your screens to feed from multiple endpoints.

> :question: **Note**: Wrapping several fetches in a single `read` method may look like an inconvenience to you. After all, other ORMs don't require that much ceremony:
> 
> ```ruby
> # Ruby's Active Record
> book = Book.find(123) # fetch book
> author = book.author  # fetch author
> # use book and author
> ```
> 
> The problem is that it is very hard to guarantee that you will surely fetch an author after you have fetched a book, despite the constraints of the database schema. One has to perform subsequent fetches in the proper [isolation] level, so that eventual concurrent writes that modify the database are unable to mess with subsequent requests.
> 
> This isolation can be achieved with record management, as in [Core Data] or [Realm], that target long-running multi-threaded applications. On the other side, most web-oriented ORMs rely on short-lived database transactions, so that each HTTP request can be processed independently of others.
> 
> GRDB is not a managed ORM. It thus has to use the same isolation techniques as web-oriented ORMs. But unlike web-oriented ORMs, GRDB can't provide implicit isolation: the application must decide when it wants to safely read information in the database, and this decision is made explicit, in your application code, with database access methods such as `dbQueue.read`.
> 
> See the [Concurrency Guide] for detailed information, and the "Solving Problems" chapter of [Why Adopt GRDB?](WhyAdoptGRDB.md#solving-problems) for more rationale.


## Observe the Database and Refetch when Needed

We have seen above that the primitive Author and Book record types are [responsible](#persistable-record-types-are-responsible-for-their-tables) for their own database tables. Later we built [requests](#define-record-requests) and [composed](#compose-records) records into more complex ones such as BookInfo or AuthorInfo. We have shown how [database managers](#how-to-design-database-managers) should expose database content to the rest of the application.

Database content which has been fetched into memory eventually becomes obsoleted, as the application modifies the database content.

It is up to the application to decide how long it should keep fetched information in memory. Very often though, the application will want to keep memory information synchronized with the database content.

This synchronization is not automatic with GRDB: records do not "auto-update". That is because applications do not always want this feature, and because it is difficult to write correct multi-threaded applications when values can change in unexpected ways.

Instead, have a look at [Database Observation]:

> :bulb: **Tip**: [ValueObservation] performs automated tracking of database changes.
>
> :bulb: **Tip**: [FetchedRecordsController] performs automated tracking of database changes, and can animate the cells of a table or collection view.
>
> :bulb: **Tip**: [RxGRDB] performs automated tracking of database changes, in the [RxSwift](https://github.com/ReactiveX/RxSwift) way.
>
> :bulb: **Tip**: [TransactionObserver] provides low-level database observation, for your most advanced needs.
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
[GRDB concurrency rules]: ../README.md#concurrency
[PersistableRecord]: ../README.md#persistablerecord-protocol
[Database Observation]: ../README.md#database-changes-observation
[ValueObservation]: ../README.md#valueobservation
[FetchedRecordsController]: ../README.md#fetchedrecordscontroller
[RxGRDB]: http://github.com/RxSwiftCommunity/RxGRDB
[TransactionObserver]: ../README.md#transactionobserver-protocol
[Trust SQLite More Than Yourself]: #trust-sqlite-more-than-yourself
[Persistable Record Types are Responsible for Their Tables]: #persistable-record-types-are-responsible-for-their-tables
[Define Record Requests]: #define-record-requests
[Compose Records]: #compose-records
[How to Design Database Managers]: #how-to-design-database-managers
[Observe the Database and Refetch when Needed]: #observe-the-database-and-refetch-when-needed
[query interface]: ../README.md#the-query-interface
[observe database changes]: ../README.md#database-changes-observation
[data protection]: ../README.md#data-protection
[Embrace Errors]: #embrace-errors
[Thread-Safety is also an Application Concern]: #thread-safety-is-also-an-application-concern
[recommended convention]: AssociationsBasics.md#associations-and-the-database-schema
[Association Aggregates]: AssociationsBasics.md#association-aggregates
