# Recommended Practices for Designing Record Types

Leverage the best of record types and associations. 

## Overview

GRDB sits right between low-level SQLite wrappers, and high-level ORMs like [Core Data], so you may face questions when designing the model layer of your application.

This is the topic of this article. Examples will be illustrated with a simple library database made of books and their authors.

- <doc:RecordRecommendedPractices#Trust-SQLite-More-Than-Yourself>
- <doc:RecordRecommendedPractices#Persistable-Record-Types-are-Responsible-for-Their-Tables>
- <doc:RecordRecommendedPractices#Record-Types-Hide-Intimate-Database-Details>
- <doc:RecordRecommendedPractices#Singleton-Records>
- <doc:RecordRecommendedPractices#Record-Requests>
- <doc:RecordRecommendedPractices#Associations>

## Trust SQLite More Than Yourself

Let's put things in the right order. An SQLite database stored on a user's device is more important than the Swift code that accesses it. When a user installs a new version of an application, only the database stored on the user's device remains the same. But all the Swift code may have changed.

This is why it is recommended to define a **robust database schema** even before playing with record types.

This is important because SQLite is very robust, whereas we developers write bugs. The more responsibility we give to SQLite, the less code we have to write, and the fewer defects we will ship on our users' devices, affecting their precious data.

For example, if we were to define <doc:Migrations> that configure a database made of books and their authors, we could write:

```swift
var migrator = DatabaseMigrator()

migrator.registerMigration("createLibrary") { db in
    try db.create(table: "author") { t in             // (1)
        t.autoIncrementedPrimaryKey("id")             // (2)
        t.column("name", .text).notNull()             // (3)
        t.column("countryCode", .text)                // (4)
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

1. Our database tables follow the <doc:DatabaseSchema#Database-Schema-Recommendations>: table names are English, singular, and camelCased. They look like Swift identifiers: `author`, `book`, `postalAddress`, `httpRequest`.
2. Each author has a unique id.
3. An author must have a name.
4. The country of an author is not always known.
5. A book must have a title.
6. The `book.authorId` column is used to link a book to the author it belongs to.
7. The `book.authorId` column is not null so that SQLite guarantees that all books have an author.
8. The `book.authorId` column is indexed in order to ease the selection of an author's books.
9. We define a foreign key from `book.authorId` column to `authors.id`, so that SQLite guarantees that no book can refer to a missing author. On top of that, the `onDelete: .cascade` option has SQLite automatically delete all of an author's books when that author is deleted. See [Foreign Key Actions](https://sqlite.org/foreignkeys.html#fk_actions) for more information.

Thanks to this database schema, the application will always process *consistent data*, no matter how wrong the Swift code can get. Even after a hard crash, all books will have an author, a non-nil title, etc.

> Tip: **A local SQLite database is not a JSON payload loaded from a remote server.**
>
> The JSON format and content can not be controlled, and an application must defend itself against wacky servers. But a local database is under your full control. It is trustable. A relational database such as SQLite guarantee the quality of users data, as long as enough energy is put in the proper definition of the database schema.

> Tip: **Plan early for future versions of your application**: use <doc:Migrations>.

## Persistable Record Types are Responsible for Their Tables

**Define one record type per database table.** This record type will be responsible for writing in this table.

**Let's start from regular structs** whose properties match the columns in their database table. Those structs conform to the standard [`Identifiable`] protocol because they have an identifier (the primary key). They conform to the standard [`Codable`] protocol so that we don't have to write the methods that convert to and from raw database rows.

```swift
struct Author: Codable, Identifiable {
    var id: Int64?
    var name: String
    var countryCode: String?
}

struct Book: Codable, Identifiable {
    var id: Int64?
    var authorId: Int64
    var title: String
}
```

**We add database powers to our types with record protocols.** 

The `author` and `book` tables have an auto-incremented id. We want inserted records to learn about their id after a successful insertion. That's why we have them conform to the ``MutablePersistableRecord`` protocol, and implement ``MutablePersistableRecord/didInsert(_:)-109jm``. Other kinds of record types would just use ``PersistableRecord``, and ignore `didInsert`.

On the reading side, we use ``FetchableRecord``, the protocol that can decode database rows.

This gives:

```swift
// Add Database access
extension Author: FetchableRecord, MutablePersistableRecord {
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Book: FetchableRecord, MutablePersistableRecord {
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

That's it. The `Author` type can read and write in the `author` database table. `Book` as well, in `book`:

```swift
try dbQueue.write { db in
    // Insert and set author's id
    var author = Author(name: "Herman Melville", countryCode: "US")
    try author.insert(db)

    // Insert and set book's id
    var book = Book(authorId: author.id!, title: "Moby-Dick")
    try book.insert(db)
}

let books = try dbQueue.read { db in
    try Book.fetchAll(db)
}
```

The `Book` and `Author` are independent structs that don't know each other. There is no `books` property in the `Author` struct, and there is no `author` property in the `Book` struct. Each type is fully responsible for its own table.

The relationship between author and books will be detailed below, in the <doc:RecordRecommendedPractices#Associations> section.

> Tip: When a column of a database table can't be NULL, define a non-optional property in the record type. On the other side, when the database may contain NULL, define an optional property. Compare:
>
> ```swift
> try db.create(table: "author") { t in
>     t.autoIncrementedPrimaryKey("id")
>     t.column("name", .text).notNull() // Can't be NULL
>     t.column("countryCode", .text)    // Can be NULL
> }
>
> struct Author: Codable, Identifiable {
>     var id: Int64?
>     var name: String         // Not optional
>     var countryCode: String? // Optional
> }
> ```
>
> There are exceptions to this rule.
>
> For example, the `id` column is never NULL in the database. And yet, `Author` as an optional `id` property. That is because we want to create instances of `Author` before they could be inserted in the database, and be assigned an auto-incremented id. If the `id` property was not optional, the `Author` type could not profit from auto-incremented ids!
>
> Another exception to this rule is described in <doc:RecordTimestamps>, where the creation date of a record is never NULL in the database, but optional in the Swift type.

> Tip: When the database table has a single-column primary key, have the record type adopt the standard [`Identifiable`] protocol. This allows GRDB to define extra methods based on record ids:
>
> ```swift
> let authorID: Int64 = 42
> let author: Author = try dbQueue.read { db in
>     try Author.find(db, id: authorID)
> }
> ```

## Record Types Hide Intimate Database Details

In the previous sample codes, the `Book` and `Author` structs have one property per database column, and their types are natively supported by SQLite (`String`, `Int`, etc.)

But it happens that raw database column names, or raw column types, are not a very good fit for the application.

When this happens, it's time to **distinguish the Swift and database representations**. Record types are the dedicated place where raw database values can be transformed into Swift types that are well-suited for the rest of the application.

Let's look at three examples.

### First Example: Enums

Authors write books, and more specifically novels, poems, essays, or theatre plays. Let's add a `kind` column in the database. We decide that a book kind is represented as a string ("novel", "essay", etc.) in the database:

```swift
try db.create(table: "book") { t in
    ...
    t.column("kind", .text).notNull()
}
```

In Swift, it is not a good practice to use `String` for the type of the `kind` property. We prefer an enum instead:

```swift
struct Book: Codable {
    enum Kind: String, Codable {
        case essay, novel, poetry, theater
    }
    var id: Int64?
    var authorId: Int64
    var title: String
    var kind: Kind
}
```

Thanks to its enum property, the `Book` record prevents invalid book kinds from being stored into the database.

In order to use `Book.Kind` in database requests for books (see <doc:RecordRecommendedPractices#Record-Requests> below), we add the ``DatabaseValueConvertible`` conformance to `Book.Kind`:

```swift
extension Book.Kind: DatabaseValueConvertible { }

// Fetch all novels
let novels = try dbQueue.read { db in
    try Book.filter(Column("kind") == Book.Kind.novel).fetchAll(db)
}
```

### Second Example: GPS Coordinates

GPS coordinates can be stored in two distinct `latitude` and `longitude` columns. But the standard way to deal with such coordinate is a single `CLLocationCoordinate2D` struct.

When this happens, keep column properties private, and provide sensible accessors instead:

```swift
try db.create(table: "place") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("name", .text).notNull()
    t.column("latitude", .double).notNull()
    t.column("longitude", .double).notNull()
}

struct Place: Codable {
    var id: Int64?
    var name: String
    private var latitude: CLLocationDegrees
    private var longitude: CLLocationDegrees
    
    var coordinate: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(
                latitude: latitude, 
                longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
}
```

Generally speaking, private properties make it possible to hide raw columns from the rest of the application. The next example shows another application of this technique.

### Third Example: Money Amounts

Before storing money amounts in an SQLite database, take care that [floating-point numbers are never a good fit](https://stackoverflow.com/questions/3730019/why-not-use-double-or-float-to-represent-currency).

SQLite only supports two kinds of numbers: integers and doubles, so we'll store amounts as integers. $12.00 will be represented by 1200, a quantity of cents. This allows SQLite to compute exact sums of price, for example.

On the other side, an amount of cents is not very practical for the rest of the Swift application. The [`Decimal`] type looks like a better fit.

That's why the `Product` record type has a `price: Decimal` property, backed by a `priceCents` integer column:
    
```swift
try db.create(table: "product") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("name", .text).notNull()
    t.column("priceCents", .integer).notNull()
}

struct Product: Codable {
    var id: Int64?
    var name: String
    private var priceCents: Int
    
    var price: Decimal {
        get {
            Decimal(priceCents) / 100
        }
        set {
            priceCents = Self.cents(for: newValue)
        }
    }

    private static func cents(for value: Decimal) -> Int {
        Int(Double(truncating: NSDecimalNumber(decimal: value * 100)))
    }
}
```

## Singleton Records

Singleton Records are records that store configuration values, user preferences, and generally some global application state. They are backed by a database table that contains a single row.

The recommended setup for such records is described in the <doc:SingleRowTables> guide.

## Record Requests

Once we have record types that are able to read and write in the database, we'd like to perform database requests of such records. 

### Define Columns and Perform Requests

Requests that filter or sort records are defined with **columns**, defined in a dedicated enumeration. When the record type conforms to [`Codable`], columns can be derived from the `CodingKeys` enum:

```swift
// HOW TO define columns for a Codable record
extension Author {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let countryCode = Column(CodingKeys.countryCode)
    }
}
```

For other record types, declare a plain `String` enum that conforms to the ``ColumnExpression`` protocol:

```swift
// HOW TO define columns for a non-Codable record
extension Author {
    enum Columns: String, ColumnExpression {
        case id, name, countryCode
    }
}
```

From those columns it is possible to define requests of type ``QueryInterfaceRequest``:

```swift
try dbQueue.read { db in
    // Fetch all authors, ordered by name,
    // in a localized case-insensitive fashion
    let sortedAuthors: [Author] = try Author.all()
        .order(Author.Columns.name.collating(.localizedCaseInsensitiveCompare))
        .fetchAll(db)
    
    // Count French authors
    let frenchAuthorCount: Int = try Author.all()
        .filter(Author.Columns.countryCode == "FR")
        .fetchCount(db)
}
```

### Turn Commonly-Used Requests into Methods 

An application can define reusable request methods that extend the built-in GRDB apis. Those methods avoid code repetition, ease refactoring, and foster testability.

Define those methods in extensions of the ``DerivableRequest`` protocol, as below:

```swift
// Author requests
extension DerivableRequest<Author> {
    /// Order authors by name, in a localized case-insensitive fashion
    func orderByName() -> Self {
        let name = Author.Columns.name
        return order(name.collating(.localizedCaseInsensitiveCompare))
    }
    
    /// Filters authors from a country
    func filter(countryCode: String) -> Self {
        filter(Author.Columns.countryCode == countryCode)
    }
}

// Book requests
extension DerivableRequest<Book> {
    /// Filters books by kind
    func filter(kind: Book.Kind) -> Self {
        filter(Book.Columns.kind == kind)
    }
}
```

Those methods define a fluent and legible api that encapsulates intimate database details:

```swift
try dbQueue.read { db in
    let sortedSpanishAuthors: [Author] = try Author.all()
        .filter(countryCode: "ES")
        .orderByName()
        .fetchAll(db)
    
    let novelCount: Int = try Book.all()
        .filter(kind: .novel)
        .fetchCount(db)
}
```

Extensions to the `DerivableRequest` protocol can not change the type of requests. They remain requests of the base record. To define requests of another type, use an extension to ``QueryInterfaceRequest``, as in the example below:

```swift
extension QueryInterfaceRequest<Author> {
    // Selects author ids
    func selectId() -> QueryInterfaceRequest<Int64> {
        selectPrimaryKey(as: Int64.self)
    }
}

// The ids of French authors
let ids: Set<Int64> = try Author.all()
    .filter(countryCode: "FR")
    .selectId()
    .fetchSet(db)
```

## Associations

So far, the `Book` and `Author` types don't know each other. The only meeting point is the `Book.authorId` property.

Associations help navigating from authors to their books and vice versa. Because the `book` table has an `authorId` column, we say that each book **belongs to** its author, and each author **has many** books:

```swift
extension Book {
    static let author = belongsTo(Author.self)
}

extension Author {
    static let books = hasMany(Book.self)
}
```

Those associations have many uses, so let's just give a few examples. The [Associations Guide] gives the full picture.

### More Reusable Requests

Associations make it possible to define more convenience request methods, similar to those seen in the <doc:RecordRecommendedPractices#Turn-Commonly-Used-Requests-into-Methods> section above:

```swift
extension DerivableRequest<Author> {
    /// Filters authors with at least one book
    func havingBooks() -> Self {
        having(Author.books.isEmpty == false)
    }
}

extension DerivableRequest<Book> {
    /// Filters books from a country
    func filter(authorCountryCode countryCode: String) -> Self {
        // Books do not have any country column. But their author has one!
        // Return books that can be joined to an author from this country:
        joining(required: Book.author.filter(countryCode: countryCode))
    }
}

try dbQueue.read { db in
    let nonLazyAuthors: [Author] = try Author.all()
        .havingBooks()
        .fetchAll(db)
    
    let italianNovels: [Book] = try Book.all()
        .filter(kind: .novel)
        .filter(authorCountryCode: "IT")
        .fetchAll(db)
}
```

### Composed Records

Associations can also compose records together into richer types:

```swift
// Fetch all authors along with their number of books
struct AuthorInfo: Decodable, FetchableRecord {
    var author: Author
    var bookCount: Int
}
let authorInfos: [AuthorInfo] = try dbQueue.read { db in
    try Author
        .annotated(with: Author.books.count)
        .asRequest(of: AuthorInfo.self)
        .fetchAll(db)
}
```

```swift
// Fetch the careers of French authors, sorted by name
struct Career: Codable, FetchableRecord {
    var author: Author
    var books: [Book]
}
let authorId = 123
let careers: [Career] = try dbQueue.read { db in
    try Author
        .filter(countryCode: "FR")
        .orderByName()
        .including(all: Author.books)
        .asRequest(of: Career.self)
        .fetchAll(db)
}
```

```swift
// Fetch all Colombian books and their authors
struct Authorship: Decodable, FetchableRecord {
    var book: Book
    var author: Author
}
let authorships: [Authorship] = try dbQueue.read { db in
    try Book.all()
        .including(required: Book.author.filter(countryCode: "CO"))
        .asRequest(of: Authorship.self)
        .fetchAll(db)
    
    // Equivalent alternative
    try Book.all()
        .filter(countryAuthorCode: "CO")
        .including(required: Book.author)
        .asRequest(of: Authorship.self)
        .fetchAll(db)
}
```

In the above sample codes, requests that fetch values from several tables are decoded into additional record types: `AuthorInfo`, `Career`, and `Authorship`.

Those record type conform to both [`Decodable`] and ``FetchableRecord``, so that they can feed from database rows. They do not provide any persistence methods, though. All database writes are performed from persistable record instances of type `Author` or `Book`.

For more information about associations, see the [Associations Guide].

> Note:
>
> The additional record types in the previous sample code may look superfluous. There exist other database libraries that are able to navigate in complex graphs of records without additional types.
>
> That is because those libraries perform lazy loading:
>
> ```ruby
> # Ruby's Active Record
> author = Author.find(123)       # Fetch author
> book_count = author.books.count # Lazily count books on demand
> ```
> 
> **GRDB does not perform lazy loading.** In a GUI application, lazy loading can not be achieved without record management (as in [Core Data]), which in turn comes with non-trivial pain points for developers regarding concurrency. Instead of lazy loading, the library provides the tooling needed to fetch data, even complex graphs, in an [isolated] fashion, so that fetched values accurately represent the database content, and all database invariants are preserved. See the <doc:Concurrency> guide for more information.

[Active Record]: http://guides.rubyonrails.org/active_record_basics.html
[`Codable`]: https://developer.apple.com/documentation/swift/Codable
[Core Data]: https://developer.apple.com/documentation/coredata
[`Decimal`]: https://developer.apple.com/documentation/foundation/decimal
[`Decodable`]: https://developer.apple.com/documentation/swift/Decodable
[Django]: https://docs.djangoproject.com/en/4.2/topics/db/
[`Identifiable`]: https://developer.apple.com/documentation/swift/identifiable
[isolated]: https://en.wikipedia.org/wiki/Isolation_(database_systems)
[Associations Guide]: https://github.com/groue/GRDB.swift/blob/master/Documentation/AssociationsBasics.md
