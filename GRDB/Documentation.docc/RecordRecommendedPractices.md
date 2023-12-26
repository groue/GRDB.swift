# Recommended Practices for Designing Record Types

Leverage the best of record types and associations. 

## Overview

GRDB sits right between low-level SQLite wrappers, and high-level ORMs like [Core Data], so you may face questions when designing the model layer of your application.

This is the topic of this article. Examples will be illustrated with a simple library database made of books and their authors.

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
        t.belongsTo("author", onDelete: .cascade)     // (6)
            .notNull()                                // (7)
    }
}

try migrator.migrate(dbQueue)
```

1. Our database tables follow the <doc:DatabaseSchema#Database-Schema-Recommendations>: table names are English, singular, and camelCased. They look like Swift identifiers: `author`, `book`, `postalAddress`, `httpRequest`.
2. Each author has a unique id.
3. An author must have a name.
4. The country of an author is not always known.
5. A book must have a title.
6. The `book.authorId` column is used to link a book to the author it belongs to. This column is indexed in order to ease the selection of an author's books. A foreign key is defined from `book.authorId` column to `authors.id`, so that SQLite guarantees that no book refers to a missing author. The `onDelete: .cascade` option has SQLite automatically delete all of an author's books when that author is deleted. See [Foreign Key Actions](https://sqlite.org/foreignkeys.html#fk_actions) for more information.
7. The `book.authorId` column is not null so that SQLite guarantees that all books have an author.

Thanks to this database schema, the application will always process *consistent data*, no matter how wrong the Swift code can get. Even after a hard crash, all books will have an author, a non-nil title, etc.

> Tip: **A local SQLite database is not a JSON payload loaded from a remote server.**
>
> The JSON format and content can not be controlled, and an application must defend itself against wacky servers. But a local database is under your full control. It is trustable. A relational database such as SQLite guarantees the quality of users data, as long as enough energy is put in the proper definition of the database schema.

> Tip: **Plan early for future versions of your application**: use <doc:Migrations>.

## Record Types

### Persistable Record Types are Responsible for Their Tables

**Define one record type per database table.** This record type will be responsible for writing in this table.

**Let's start from regular structs** whose properties match the columns in their database table. They conform to the standard [`Codable`] protocol so that we don't have to write the methods that convert to and from raw database rows.

```swift
struct Author: Codable {
    var id: Int64?
    var name: String
    var countryCode: String?
}

struct Book: Codable {
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

> Tip: When a column of a database table can't be NULL, define a non-optional property in the record type. On the other side, when the database may contain NULL, define an optional property. Compare:
>
> ```swift
> try db.create(table: "author") { t in
>     t.autoIncrementedPrimaryKey("id")
>     t.column("name", .text).notNull() // Can't be NULL
>     t.column("countryCode", .text)    // Can be NULL
> }
>
> struct Author: Codable {
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
>
> Take care that **`Identifiable` is not a good fit for optional ids**. You will frequently meet optional ids for records with auto-incremented ids:
>
> ```swift
> struct Player: Codable {
>     var id: Int64? // Optional ids are not suitable for Identifiable
>     var name: String
>     var score: Int
> }
> 
> extension Player: FetchableRecord, MutablePersistableRecord {
>     // Update auto-incremented id upon successful insertion
>     mutating func didInsert(_ inserted: InsertionSuccess) {
>         id = inserted.rowID
>     }
> }
> ```
>
> For more details about auto-incremented ids and `Identifiable`, see [issue #1435](https://github.com/groue/GRDB.swift/issues/1435#issuecomment-1740857712).

### Record Types Hide Intimate Database Details

In the previous sample codes, the `Book` and `Author` structs have one property per database column, and their types are natively supported by SQLite (`String`, `Int`, etc.)

But it happens that raw database column names, or raw column types, are not a very good fit for the application.

When this happens, it's time to **distinguish the Swift and database representations**. Record types are the dedicated place where raw database values can be transformed into Swift types that are well-suited for the rest of the application.

Let's look at three examples.

#### First Example: Enums

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

#### Second Example: GPS Coordinates

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

#### Third Example: Money Amounts

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

## Record Requests

Once we have record types that are able to read and write in the database, we'd like to perform database requests of such records. 

### Columns 

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
    /// Order books by title, in a localized case-insensitive fashion
    func orderByTitle() -> Self {
        let title = Book.Columns.title
        return order(title.collating(.localizedCaseInsensitiveCompare))
    }
    
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

// The ids of Japanese authors
let ids: Set<Int64> = try Author.all()
    .filter(countryCode: "JP")
    .selectId()
    .fetchSet(db)
```

## Associations

[Associations] help navigating from authors to their books and vice versa. Because the `book` table has an `authorId` column, we say that each book **belongs to** its author, and each author **has many** books:

```swift
extension Book {
    static let author = belongsTo(Author.self)
}

extension Author {
    static let books = hasMany(Book.self)
}
```

With associations, you can fetch a book's author, or an author's books:

```swift
// Fetch all novels from an author
try dbQueue.read { db in
    let author: Author = ...
    let novels: [Book] = try author.request(for: Author.books)
        .filter(kind: .novel)
        .orderByTitle()
        .fetchAll(db)
}
```

Associations also make it possible to define more convenience request methods:

```swift
extension DerivableRequest<Book> {
    /// Filters books from a country
    func filter(authorCountryCode countryCode: String) -> Self {
        // Books do not have any country column. But their author has one!
        // Return books that can be joined to an author from this country:
        joining(required: Book.author.filter(countryCode: countryCode))
    }
}

// Fetch all Italian novels
try dbQueue.read { db in
    let italianNovels: [Book] = try Book.all()
        .filter(kind: .novel)
        .filter(authorCountryCode: "IT")
        .fetchAll(db)
}
```

With associations, you can also process graphs of authors and books, as described in the next section. 

### How to Model Graphs of Objects

Since the beginning of this article, the `Book` and `Author` are independent structs that don't know each other. The only "meeting point" is the `Book.authorId` property.

Record types don't know each other on purpose: one does not need to know the author of a book when it's time to update the title of a book, for example.

When an application wants to process authors and books together, it defines dedicated types that model the desired view on the graph of related objects. For example:

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
// Fetch the literary careers of German authors, sorted by name
struct LiteraryCareer: Codable, FetchableRecord {
    var author: Author
    var books: [Book]
}
let careers: [LiteraryCareer] = try dbQueue.read { db in
    try Author
        .filter(countryCode: "DE")
        .orderByName()
        .including(all: Author.books)
        .asRequest(of: LiteraryCareer.self)
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
        .filter(authorCountryCode: "CO")
        .including(required: Book.author)
        .asRequest(of: Authorship.self)
        .fetchAll(db)
}
```

In the above sample codes, requests that fetch values from several tables are decoded into additional record types: `AuthorInfo`, `LiteraryCareer`, and `Authorship`.

Those record type conform to both [`Decodable`] and ``FetchableRecord``, so that they can feed from database rows. They do not provide any persistence methods, though. **All database writes are performed from persistable record instances** (of type `Author` or `Book`).

For more information about associations, see the [Associations] guide.

### Lazy and Eager Loading: Comparison with Other Database Libraries

The additional record types described in the previous section may look superfluous. Some other database libraries are able to navigate in graphs of records without additional types.

For example, [Core Data] and Ruby's [Active Record] use **lazy loading**. This means that relationships are lazily fetched on demand:

```ruby
# Lazy loading with Active Record
author = Author.first       # Fetch first author
puts author.name
author.books.each do |book| # Lazily fetch books on demand
  puts book.title
end
```

**GRDB does not perform lazy loading.** In a GUI application, lazy loading can not be achieved without record management (as in [Core Data]), which in turn comes with non-trivial pain points for developers regarding concurrency. Instead of lazy loading, the library provides the tooling needed to fetch data, even complex graphs, in an [isolated] fashion, so that fetched values accurately represent the database content, and all database invariants are preserved. See the <doc:Concurrency> guide for more information.

Vapor [Fluent] uses **eager loading**, which means that relationships are only fetched if explicitly requested:

```swift
// Eager loading with Fluent
let query = Author.query(on: db)
    .with(\.$books) // <- Explicit request for books
    .first()

// Fetch first author and its books in one stroke
if let author = query.get() {
    print(author.name)
    for book in author.books { print(book.title) } 
}
```

One must take care of fetching relationships, though, or Fluent raises a fatal error: 

```swift
// Oops, the books relation is not explicitly requested
let query = Author.query(on: db).first()
if let author = query.get() {
    // fatal error: Children relation not eager loaded.
    for book in author.books { print(book.title) } 
}
```

**GRDB supports eager loading**. The difference with Fluent is that the relationships are modelled in a dedicated record type that provides runtime safety:

```swift
// Eager loading with GRDB
struct LiteraryCareer: Codable, FetchableRecord {
    var author: Author
    var books: [Book]
}

let request = Author.all()
    .including(all: Author.books) // <- Explicit request for books
    .asRequest(of: LiteraryCareer.self)

// Fetch first author and its books in one stroke
if let career = try request.fetchOne(db) {
    print(career.author.name)
    for book in career.books { print(book.title) } 
}
```

[Active Record]: http://guides.rubyonrails.org/active_record_basics.html
[`Codable`]: https://developer.apple.com/documentation/swift/Codable
[Core Data]: https://developer.apple.com/documentation/coredata
[`Decimal`]: https://developer.apple.com/documentation/foundation/decimal
[`Decodable`]: https://developer.apple.com/documentation/swift/Decodable
[Django]: https://docs.djangoproject.com/en/4.2/topics/db/
[Fluent]: https://docs.vapor.codes/fluent/overview/
[`Identifiable`]: https://developer.apple.com/documentation/swift/identifiable
[isolated]: https://en.wikipedia.org/wiki/Isolation_(database_systems)
[Associations]: https://github.com/groue/GRDB.swift/blob/master/Documentation/AssociationsBasics.md
