GRDB Associations
=================

- [Associations Benefits]
- [The Types of Associations]
    - [BelongsTo]
    - [HasOne]
    - [HasMany]
    - [Choosing Between BelongsTo and HasOne]
    - [Self Joins]
- [Associations and the Database Schema]
    - [Convention for Database Table Names]
    - [Convention for the BelongsTo Association]
    - [Convention for the HasOne Association]
    - [Convention for the HasMany Association]
    - [Foreign Keys]
- [Building Requests from Associations]
    - [Requesting Associated Records]
    - [Joining Methods]
    - [Combining Associations]
    - [Filtering Associations]
    - [Sorting Associations]
    - [Columns Selected by an Association]
    - [Table Aliases]
- [Fetching Values from Associations]
    - [The Structure of a Joined Request]
    - [Decoding a Joined Request with a Decodable Record]
    - [Decoding a Joined Request with FetchableRecord]
- [Known Issues]
- [Future Directions]


## Associations Benefits

**An association is a connection between two [Record] types.**

Associations streamline common operations in your code, make them safer, and more efficient. For example, consider a library application that has two record types, author and book:

```swift
struct Author: TableRecord, FetchableRecord {
    var id: Int64
    var name: String
}

struct Book: TableRecord, FetchableRecord {
    var id: Int64
    var authorId: Int64?
    var title: String
}
```

Now, suppose we wanted to load all books from an existing author. We'd need to do something like this:

```swift
let author: Author = ...
let books = try Book
    .filter(Column("authorId") == author.id)
    .fetchAll(db)
```

Or, loading all pairs of books along with their authors:

```swift
struct BookInfo {
    var book: Book
    var author: Author?
}

let books = try Book.fetchAll(db)
let bookInfos = books.map { book -> BookInfo in
    let author = try Author.fetchOne(key: book.authorId)
    return BookInfo(book: book, author: author)
}
```

With GRDB associations, we can streamline these operations (and others), by declaring the connections between books and authors. Here is how we define associations, and properties that access them:

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

Loading all books from an existing author is now easier:

```swift
let books = try author.books.fetchAll(db)
```

As for loading all pairs of books and authors, it is not only easier, but also *far much efficient*:

```swift
struct BookInfo: FetchableRecord, Codable {
    let book: Book
    let author: Author?
}

let request = Book.including(optional: Book.author)
let bookInfos = BookInfo.fetchAll(db, request)
```

Before we dive in, please remember that associations can not generate all possible SQL queries that involve several tables. You may also *prefer* writing SQL, and this is just OK, because your SQL skills are welcome: see the [Joined Queries Support](../README.md#joined-queries-support) chapter.


The Types of Associations
=========================

GRDB handles three types of associations:

- **BelongsTo**
- **HasOne**
- **HasMany**

An association declares a link from a record type to another, as in "one book **belongs to** its author". It instructs GRDB to use the foreign keys declared in the database as support for Swift methods.

Each one of the three types of associations is appropriate for a particular database situation.

- [BelongsTo]
- [HasOne]
- [HasMany]
- [Choosing Between BelongsTo and HasOne]
- [Self Joins]


## BelongsTo

The **BelongsTo** association sets up a one-to-one connection from a record type to another record type, such as each instance of the declaring record "belongs to" an instance of the other record.

For example, if your application includes authors and books, and each book is assigned its author, you'd declare the association this way:

```swift
struct Book: TableRecord {
    static let author = belongsTo(Author.self)
    ...
}

struct Author: TableRecord {
    ...
}
```

The **BelongsTo** association between a book and its author needs that the database table for books has a column that points to the table for authors:

![BelongsToSchema](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/BelongsToSchema.svg)

See [Convention for the BelongsTo Association] for some sample code that defines the database schema for such an association.


## HasOne

The **HasOne** association also sets up a one-to-one connection from a record type to another record type, but with different semantics, and underlying database schema. It is usually used when an entity has been denormalized into two database tables.

For example, if your application has one database table for countries, and another for their demographic profiles, you'd declare the association this way:

```swift
struct Country: TableRecord {
    static let demographics = hasOne(Demographics.self)
    ...
}

struct Demographics: TableRecord {
    ...
}
```

The **HasOne** association between a country and its demographics needs that the database table for demographics has a column that points to the table for countries:

![HasOneSchema](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/HasOneSchema.svg)

See [Convention for the HasOne Association] for some sample code that defines the database schema for such an association.


## HasMany

The **HasMany** association indicates a one-to-many connection between two record types, such as each instance of the declaring record "has many" instances of the other record. You'll often find this association on the other side of a **BelongsTo** association.

For example, if your application includes authors and books, and each author is assigned zero or more books, you'd declare the association this way:

```swift
struct Author: TableRecord {
    static let books = hasMany(Book.self)
}

struct Book: TableRecord {
    ...
}
```

The **HasMany** association between an author and its books needs that the database table for books has a column that points to the table for authors:

![HasManySchema](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/HasManySchema.svg)

See [Convention for the HasMany Association] for some sample code that defines the database schema for such an association.


## Choosing Between BelongsTo and HasOne

When you want to set up a one-to-one relationship between two record types, you'll need to add a **BelongsTo** association to one, and a **HasOne** association to the other. How do you know which is which?

The distinction is in where you place the database foreign key. The record that points to the other one has the **BelongsTo** association. The other record has the **HasOne** association:

A country **has one** demographic profile, a demographic profile **belongs to** a country:

![HasOneSchema](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/HasOneSchema.svg)

```swift
struct Country: TableRecord, FetchableRecord {
    static let demographics = hasOne(Demographics.self)
    ...
}

struct Demographics: TableRecord, FetchableRecord {
    static let country = belongsTo(Demographics.self)
    ...
}
```

## Self Joins

When designing your data model, you will sometimes find a record that should have a relation to itself. For example, you may want to store all employees in a single database table, but be able to trace relationships such as between manager and subordinates. This situation can be modeled with self-joining associations:

```swift
struct Employee {
    static let subordinates = hasMany(Employee.self)
    static let manager = belongsTo(Employee.self)
}
```

![RecursiveSchema](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/RecursiveSchema.svg)

The matching [migration] would look like:

```swift
migrator.registerMigration("Employees") { db in
    try db.create(table: "employee") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("managerId", .integer)
            .indexed()
            .references("employee", onDelete: .restrict)
        t.column("name", .text)
    }
}
```


Associations and the Database Schema
====================================

**Associations are grounded in the database schema, the way database tables are defined.**

For example, a **[BelongsTo]** association between a book and its author needs that the database table for books has a column that points to the table for authors.

GRDB also comes with several *conventions* for defining your database schema.

Those conventions help associations be convenient and, generally, "just work". When you can't, or don't want to follow conventions, you will have to override the expected defaults in your Swift code.

- [Convention for Database Table Names]
- [Convention for the BelongsTo Association]
- [Convention for the HasOne Association]
- [Convention for the HasMany Association]
- [Foreign Keys]


## Convention for Database Table Names

**Database table names should be singular and camel-cased.**

Make them look like Swift identifiers: `book`, `author`, `postalAddress`.

This convention helps fetching values from associations. It is used, for example, in the sample code below, where we load all pairs of books along with their authors:

```swift
// The Book record
struct Book: FetchableRecord, TableRecord {
    static let databaseTableName = "book"
    static let author = belongsTo(Author.self)
    ...
}

// The Author record
struct Author: FetchableRecord, TableRecord {
    static let databaseTableName = "author"
    ...
}

// A pair made of a book and its author
struct BookInfo: FetchableRecord, Codable {
    let book: Book
    let author: Author?
}

let request = Book.including(optional: Book.author)
let bookInfos = BookInfo.fetchAll(db, request)
```

This sample code only works if the database table for authors is called "author". This name "author" is the key that helps BookInfo initialize its `author` property.

If the database schema does not follow this convention, and has, for example, database tables named with plural names (`authors` and `books`), you can still use associations. But you need to help row consumption by providing the required key:

```swift
struct Book: FetchableRecord, TableRecord {
    static let author = belongsTo(Author.self).forKey("author") // <-
}
```

See [The Structure of a Joined Request] for more information.


## Convention for the BelongsTo Association

**[BelongsTo] associations should be supported by an SQLite foreign key.**

Foreign keys are the recommended way to declare relationships between database tables. Not only will SQLite guarantee the integrity of your data, but GRDB will be able to use those foreign keys to automatically configure your associations.

![BelongsToSchema](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/BelongsToSchema.svg)

The matching [migration] could look like:

```swift
migrator.registerMigration("Books and Authors") { db in
    try db.create(table: "author") { t in
        t.autoIncrementedPrimaryKey("id")             // (1)
        t.column("name", .text)
    }
    try db.create(table: "book") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("authorId", .integer)                // (2)
            .notNull()                                // (3)
            .indexed()                                // (4)
            .references("author", onDelete: .cascade) // (5)
        t.column("title", .text)
    }
}
```

1. The `author` table has a primary key.
2. The `book.authorId` column is used to link a book to the author it belongs to.
3. Make the `book.authorId` column not null if you want SQLite to guarantee that all books have an author.
4. Create an index on the `book.authorId` column in order to ease the selection of an author's books.
5. Create a foreign key from `book.authorId` column to `authors.id`, so that SQLite guarantees that no book refers to a missing author. The `onDelete: .cascade` option has SQLite automatically delete all of an author's books when that author is deleted. See [Foreign Key Actions] for more information.

The example above uses auto-incremented primary keys. But generally speaking, all primary keys are supported.

Following this convention lets you write, for example:

```swift
struct Book: FetchableRecord, TableRecord {
    static let databaseTableName = "book"
    static let author = belongsTo(Author.self)
}

struct Author: FetchableRecord, TableRecord {
    static let databaseTableName = "author"
}
```

If the database schema does not follow this convention, and does not define foreign keys between tables, you can still use **BelongsTo** associations. But your help is needed to define the missing foreign key:

```swift
struct Book: FetchableRecord, TableRecord {
    static let author = belongsTo(Author.self, using: ForeignKey(...))
}
```

See [Foreign Keys] for more information.


## Convention for the HasOne Association

**[HasOne] associations should be supported by an SQLite foreign key.**

Foreign keys are the recommended way to declare relationships between database tables. Not only will SQLite guarantee the integrity of your data, but GRDB will be able to use those foreign keys to automatically configure your associations.

![HasOneSchema](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/HasOneSchema.svg)

The matching [migration] could look like:

```swift
migrator.registerMigration("Countries") { db in
    try db.create(table: "country") { t in
        t.column("code", .text).primaryKey()           // (1)
        t.column("name", .text)
    }
    try db.create(table: "demographics") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("countryCode", .text)                 // (2)
            .notNull()                                 // (3)
            .unique()                                  // (4)
            .references("country", onDelete: .cascade) // (5)
        t.column("population", .integer)
        t.column("density", .double)
    }
}
```

1. The `country` table has a primary key.
2. The `demographics.countryCode` column is used to link a demographic profile to the country it belongs to.
3. Make the `demographics.countryCode` column not null if you want SQLite to guarantee that all profiles are linked to a country.
4. Create a unique index on the `demographics.countryCode` column in order to guarantee the unicity of any country's profile.
5. Create a foreign key from `demographics.countryCode` column to `country.code`, so that SQLite guarantees that no profile refers to a missing country. The `onDelete: .cascade` option has SQLite automatically delete a profile when its country is deleted. See [Foreign Key Actions] for more information.

The example above uses a string primary key for the "country" table. But generally speaking, all primary keys are supported.

Following this convention lets you write, for example:

```swift
struct Country: FetchableRecord, TableRecord {
    static let databaseTableName = "country"
    static let demographics = hasOne(Demographics.self)
}

struct Demographics: FetchableRecord, TableRecord {
    static let databaseTableName = "demographics"
}
```

If the database schema does not follow this convention, and does not define foreign keys between tables, you can still use HasOne associations. But your help is needed to define the missing foreign key:

```swift
struct Book: FetchableRecord, TableRecord {
    static let demographics = hasOne(Demographics.self, using: ForeignKey(...))
}
```

See [Foreign Keys] for more information.


## Convention for the HasMany Association

**[HasMany] associations should be supported by an SQLite foreign key.**

Foreign keys are the recommended way to declare relationships between database tables. Not only will SQLite guarantee the integrity of your data, but GRDB will be able to use those foreign keys to automatically configure your associations.

![HasManySchema](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/HasManySchema.svg)

The matching [migration] could look like:

```swift
migrator.registerMigration("Books and Authors") { db in
    try db.create(table: "author") { t in
        t.autoIncrementedPrimaryKey("id")             // (1)
        t.column("name", .text)
    }
    try db.create(table: "book") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("authorId", .integer)                // (2)
            .notNull()                                // (3)
            .indexed()                                // (4)
            .references("author", onDelete: .cascade) // (5)
        t.column("title", .text)
    }
}
```

1. The `author` table has a primary key.
2. The `book.authorId` column is used to link a book to the author it belongs to.
3. Make the `book.authorId` column not null if you want SQLite to guarantee that all books have an author.
4. Create an index on the `book.authorId` column in order to ease the selection of an author's books.
5. Create a foreign key from `book.authorId` column to `authors.id`, so that SQLite guarantees that no book refers to a missing author. The `onDelete: .cascade` option has SQLite automatically delete all of an author's books when that author is deleted. See [Foreign Key Actions] for more information.

The example above uses auto-incremented primary keys. But generally speaking, all primary keys are supported.

Following this convention lets you write, for example:

```swift
struct Book: FetchableRecord, TableRecord {
    static let databaseTableName = "book"
}

struct Author: FetchableRecord, TableRecord {
    static let databaseTableName = "author"
    static let books = hasMany(Book.self)
}
```

If the database schema does not follow this convention, and does not define foreign keys between tables, you can still use **HasMany** associations. But your help is needed to define the missing foreign key:

```swift
struct Author: FetchableRecord, TableRecord {
    static let books = hasMany(Book.self, using: ForeignKey(...))
}
```

See [Foreign Keys] for more information.


## Foreign Keys

**Associations can automatically infer the foreign keys that define how two database tables are linked together.**

In the example below, the `book.authorId` column is automatically used to link a book to its author:

![BelongsToSchema](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/BelongsToSchema.svg)

```swift
struct Book: TableRecord {
    static let author = belongsTo(Author.self)
}

struct Author: TableRecord {
    static let books = hasMany(Book.self)
}
```

But this requires the database schema to define a foreign key between the book and author database tables (see [Convention for the BelongsTo Association]).

Sometimes the database schema does not define any foreign key. And sometimes, there are *several* foreign keys from a table to another.

![AmbiguousForeignKeys](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/AmbiguousForeignKeys.svg)

When this happens, associations can't be automatically inferred from the database schema. GRDB will complain with a fatal error such as "Ambiguous foreign key from book to author", or "Could not infer foreign key from book to author".

Your help is needed. You have to instruct GRDB which foreign key to use:

```swift
struct Book: TableRecord {
    // Define foreign keys
    static let authorForeignKey = ForeignKey(["authorId"]))
    static let translatorForeignKey = ForeignKey(["translatorId"]))
    
    // Use foreign keys to define associations:
    static let author = belongsTo(Person.self, using: authorForeignKey)
    static let translator = belongsTo(Person.self, using: translatorForeignKey)
}
```

Foreign keys are always defined from the table that contains the columns at the origin of the foreign key. Person's symmetric **HasMany** associations reuse Book's foreign keys:

```swift
struct Person: TableRecord {
    static let writtenBooks = hasMany(Book.self, using: Book.authorForeignKey)
    static let translatedBooks = hasMany(Book.self, using: Book.translatorForeignKey)
}
```

Foreign keys can also be defined from `Column`:

```swift
struct Book: TableRecord {
    enum Columns: String, ColumnExpression {
        case id, title, authorId, translatorId
    }
    
    static let authorForeignKey = ForeignKey([Columns.authorId]))
    static let translatorForeignKey = ForeignKey([Columns.translatorId]))
}
```

When the destination table of a foreign key does not define any primary key, you need to provide the full definition of a foreign key:

```swift
struct Book: TableRecord {
    static let authorForeignKey = ForeignKey(["authorId"], to: ["id"]))
    static let author = belongsTo(Person.self, using: authorForeignKey)
}
```


Building Requests from Associations
===================================

**Once you have defined associations, you can define fetch request that involve several record types.**

> :point_up: **Note**: Those requests are executed by SQLite as *SQL joined queries*. In all examples below, we'll show the SQL queries executed by our association-based requests. You can ignore them if you are not familiar with SQL.

Fetch requests do not visit the database until you fetch values from them. This will be covered in [Fetching Values from Associations]. But before you can fetch anything, you have to describe what you want to fetch. This is the topic of this chapter.

- [Requesting Associated Records]
- [Joining Methods]
- [Combining Associations]
- [Filtering Associations]
- [Sorting Associations]
- [Columns Selected by an Association]
- [Table Aliases]


## Requesting Associated Records

**You can use associations to build requests for associated records.**

For example, given a `Book.author` **[BelongsTo]** association, you can build a request for the author of a book. In the example below, we return this request from the `Book.author` property:

```swift
struct Book: PersistableRecord {
    static let author = belongsTo(Author.self)
    
    /// The request for a book's author
    var author: QueryInterfaceRequest<Author> {
        return request(for: Book.author)
    }
}
```

This request can fetch a book's author:

```swift
let book: Book = ...
let author = try book.author.fetchOne(db)   // Author?
```

**[HasOne]** and **[HasMany]** associations can also build requests for associated records. For example:

```swift
struct Author: PersistableRecord {
    static let books = hasMany(Book.self)
    
    /// The request for an author's books
    var books: QueryInterfaceRequest<Author> {
        return request(for: Author.books)
    }
}

let author: Author = ...
let books = try author.books.fetchAll(db)   // [Book]
```

Those requests can also turn out useful when you want to track their changes with database observation tools like [RxGRDB](http://github.com/RxSwiftCommunity/RxGRDB):

```swift
// Track changes in the author's books:
let author: Author = ...
author.books.rx
    .fetchAll(in: dbQueue)
    .subscribe(onNext: { (books: [Book]) in
        print("Author's book have changed")
    })
```


## Joining Methods

**You build requests that involve several records with the four "joining methods":**

- `including(optional: association)`
- `including(required: association)`
- `joining(optional: association)`
- `joining(required: association)`

Before we describe them in detail, let's see a few requests they can build:

```swift
/// All books with their respective authors
let request = Book
    .including(required: Book.author)

/// All books with their respective authors, sorted by title
let request = Book
    .order(Column("title"))
    .including(required: Book.author)

/// All books written by a French author
let request = Book
    .joining(required: Book.author.filter(Column("countryCode") == "FR"))
```

The pattern is always the same: you start from a base request, that you extend with one of the joining methods.

**To choose the joining method you need, you ask yourself two questions:**

1. Should the associated records be fetched along with the base records?
    
    If yes, use `including(...)`. Otherwise, use `joining(...)`.
    
    For example, to load all books with their respective authors, you want authors to be fetched, and you use `including`:
    
    ```swift
    /// All books with their respective authors
    let request = Book
        .including(required: Book.author)
    ```
    
    On the other side, to load all books written by a French author, you sure need to filter authors, but you don't need them to be present in the fetched results. You prefer `joining`:
    
    ```swift
    /// All books written by a French author
    let request = Book
        .joining(required: Book.author.filter(Column("countryCode") == "FR"))
    ```

2. Should the request allow missing associated records?
    
    If yes, choose the `optional` variant. Otherwise, choose `required`.
    
    For example, to load all books with their respective authors, even if the book has no recorded author, you'd use `including(optional:)`:
    
    ```swift
    /// All books with their respective (eventual) authors
    /// (One Thousand and One Nights should be there)
    let request = Book
        .including(optional: Book.author)
    ```
    
    You can remember to use `optional` when the fetched associated records should feed optional Swift values, of type `Author?`. Conversely, when the fetched results feed non-optional values of type `Author`, prefer `required`.
    
    Another way to describe the difference is that `required` filters the fetched results in order to discard missing associated records, when `optional` does not filter anything, and lets missing values pass through.
    
    For example, consider this request:
    
    ```swift
    let request = Book
        .joining(optional: Book.author.filter(Column("countryCode") == "FR"))
    ```
    
    It fetches books that have a French author, but also those who don't :sweat_smile:. It's just another way to tell `Book.all()`. But we'll see below that such join can turn out useful.
    
    Finally, readers who speak SQL may compare `optional` with left joins, and `required` with inner joins.


## Combining Associations

**Associations can be combined in order to build more complex requests.**

You can join several associations in parallel:

```swift
// SELECT book.*, person1.*, person2.*
// FROM book
// JOIN person person1 ON person1.id = book.authorId
// LEFT JOIN person person2 ON person2.id = book.translatorId
let request = Book
    .including(required: Book.author)
    .including(optional: Book.translator)
```

The request above fetches all books, along with their author and eventual translator.

You can chain associations in order to jump from a record to another:

```swift
// SELECT book.*, person.*, country.*
// FROM book
// JOIN person ON person.id = book.authorId
// LEFT JOIN country ON country.code = person.countryCode
let request = Book
    .including(required: Book.author
        .including(optional: Person.country))
```

The request above fetches all books, along with their author, and their author's country.

When you chain associations, you can avoid fetching intermediate values by replacing the `including` method with `joining`:

```swift
// SELECT book.*, country.*
// FROM book
// LEFT JOIN person ON person.id = book.authorId
// LEFT JOIN country ON country.code = person.countryCode
let request = Book
    .joining(optional: Book.author
        .including(optional: Person.country))
```

The request above fetches all books, along with their author's country.

> :warning: **Warning**: you can not currently chain a required association behind an optional association:
>
> ```swift
> // Not implemented
> let request = Book
>     .joining(optional: Book.author
>         .including(required: Person.country))
> ```
>
> This code compiles, but you'll get a runtime fatal error "Not implemented: chaining a required association behind an optional association". Future versions of GRDB may allow such requests.


## Filtering Associations

**You can filter associated records.**

The `filter(_:)`, `filter(key:)` and `filter(keys:)` methods, that you already know for [filtering simple requests](../README.md#requests), can filter associated records as well:

```swift
// SELECT book.*
// FROM book
// JOIN person ON person.id = book.authorId
//            AND person.countryCode = 'FR'
let frenchAuthor = Book.author.filter(Column("countryCode") == "FR")
let request = Book.joining(required: frenchAuthor)
```

The request above fetches all books written by a French author.

**There are more filtering options:**

- Filtering on conditions that involve several tables.
- Filtering in the WHERE clause instead of the ON clause (can be useful when you are skilled enough in SQL to make the difference).

Those extra filtering options require **[Table Aliases]**, introduced below.


## Sorting Associations

**You can sort fetched results according to associated records.**

The `order()` method, that you already know for [sorting simple requests](../README.md#requests), can sort associated records as well:

```swift
// SELECT book.*, person.*
// FROM book
// JOIN person ON person.id = book.authorId
// ORDER BY person.name
let sortedAuthor = Book.author.order(Column("name"))
let request = Book.including(required: sortedAuthor)
```

When you sort both the base record on the associated record, the request is sorted on the base record first, and on the associated record next:

```swift
// SELECT book.*, person.*
// FROM book
// JOIN person ON person.id = book.authorId
// ORDER BY book.publishDate DESC, person.name
let sortedAuthor = Book.author.order(Column("name"))
let request = Book
    .including(required: sortedAuthor)
    .order(Column("publishDate").desc)
```

**There are more sorting options:**

- Sorting on expressions that involve several tables.
- Changing the order of the sorting terms (such as sorting on author name first, and then publish date).

Those extra sorting options require **[Table Aliases]**, introduced below.


## Columns Selected by an Association

By default, associated records include all their columns:

```swift
// SELECT book.*, author.*
// FROM book
// JOIN author ON author.id = book.authorId
let request = Book.including(required: Book.author)
```

**The selection can be changed for each individual request, or for all requests including a given type.**

To specify the selection of an associated record in a specific request, use the `select` method:

```swift
// SELECT book.*, author.id, author.name
// FROM book
// JOIN author ON author.id = book.authorId
let restrictedAuthor = Book.author.select(Column("id"), Column("name"))
let request = Book.including(required: restrictedAuthor)
```

To specify the default selection for all inclusions of a given type, define the `databaseSelection` property:

```swift
struct RestrictedAuthor: TableRecord {
    static let databaseSelection: [SQLSelectable] = [Column("id"), Column("name")]
}

struct ExtendedAuthor: TableRecord {
    static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
}

extension Book {
    static let restrictedAuthor = belongsTo(RestrictedAuthor.self)
    static let extendedAuthor = belongsTo(ExtendedAuthor.self)
}

// SELECT book.*, author.id, author.name
// FROM book
// JOIN author ON author.id = book.authorId
let request = Book.including(required: Book.restrictedAuthor)

// SELECT book.*, author.*, author.rowid
// FROM book
// JOIN author ON author.id = book.authorId
let request = Book.including(required: Book.extendedAuthor)
```

Modifying `databaseSelection` not only affects joined requests, but all requests built from the modified record. This is how records make sure they are always fed with the columns they need, no more, no less:

```swift
// SELECT id, name FROM author
let request = RestrictedAuthor.all()
```

> :point_up: **Note**: make sure the `databaseSelection` property is explicitely declared as `[SQLSelectable]`. If it is not, the Swift compiler may infer a type which may silently miss the protocol requirement, resulting in sticky SELECT * requests. See [Columns Selected by a Request](../README.md#columns-selected-by-a-request) for further information.


## Table Aliases

In all examples we have seen so far, all associated records are joined, included, filtered, and sorted independently. We could not filter them on conditions that involve several records, for example.

Let's say we look for posthumous books, published after their author has died. We need to compare a book publication date with an author eventual death date.

Let's first see a wrong way to do it:

```swift
// A wrong request:
// SELECT book.*
// FROM book
// JOIN person ON person.id = book.authorId
// WHERE book.publishDate >= book.deathDate
let request = Book
    .joining(required: Book.author)
    .filter(Column("publishDate") >= Column("deathDate"))
```

When executed, we'll get a DatabaseError of code 1, "no such column: book.deathDate".

That is because the "deathDate" column has been used for filtering books, when it is defined on the person database table.

To fix this error, we need a **table alias**:

```swift
let authorAlias = TableAlias()
```

We modify the `Book.author` association so that it uses this table alias, and we use the table alias to qualify author columns where needed:

```swift
// SELECT book.*
// FROM book
// JOIN person ON person.id = book.authorId
// WHERE book.publishDate >= person.deathDate
let request = Book
    .joining(required: Book.author.aliased(authorAlias))
    .filter(Column("publishDate") >= authorAlias[Column("deathDate")])
```

**Table aliases** can also improve control over the ordering of request results. In the example below, we override the [default ordering](#sorting-associations) of associated records by sorting on author names first:

```swift
// SELECT book.*
// FROM book
// JOIN person ON person.id = book.authorId
// ORDER BY person.name, book.publishDate
let request = Book
    .joining(required: Book.author.aliased(authorAlias))
    .order(authorAlias[Column("name")], Column("publishDate"))
```

**Table aliases** can be given a name. This name is guaranteed to be used as the table alias in the SQL query. This guarantee lets you write SQL snippets when you need it:

```swift
// SELECT myBook.*
// FROM book myBook
// JOIN person myAuthor ON myAuthor.id = myBook.authorId
//                     AND myAuthor.countryCode = 'FR'
// WHERE myBook.publishDate >= myAuthor.deathDate
let bookAlias = TableAlias(name: "myBook")
let authorAlias = TableAlias(name: "myAuthor")
let request = Book.aliased(bookAlias)
    .joining(required: Book.author.aliased(authorAlias)
        .filter(sql: "myAuthor.countryCode = ?", arguments: ["FR"]))
    .filter(sql: "myBook.publishDate >= myAuthor.deathDate")
```


Fetching Values from Associations
=================================

We have seen in [Building Requests from Associations] how to define requests that involve several records by the mean of [Joining Methods].

If your application needs to display a list of books with information about their author, country, and cover image, you may build the following joined request:

```swift
// SELECT book.*, author.*, country.*, coverImage.*
// FROM book
// JOIN author ON author.id = book.authorId
// LEFT JOIN country ON country.code = author.countryCode
// LEFT JOIN coverImage ON coverImage.bookId = book.id
let request = Book
    .including(required: Book.author
        .including(optional: Author.country))
    .including(optional: Bool.coverImage)
```

**Now is the time to tell how joined requests should be consumed.**

As always in GRDB, requests can be consumed as raw database rows, or as well-structured and convenient records.

The request above can be consumed into the following record:

```swift
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var author: Author
    var country: Country?
    var coverImage: CoverImage?
}

let bookInfos = try BookInfo.fetchAll(db, request) // [BookInfo]
```

If we consume raw rows, we start to see what's happening under the hood:

```swift
let row = try Row.fetchOne(db, request)! // Row
print(row.debugDescription)
// ▿ [id:1, authorId:2, title:"Moby-Dick"]
//   unadapted: [id:1, authorId:2, title:"Moby-Dick", id:2, name:"Herman Melville", countryCode:"US", code:"US", name:"United States of America", id:42, imageId:1, path:"moby-dick.jpg"]
//   - author: [id:2, name:"Herman Melville", countryCode:"US"]
//     - country: [code:"US", name:"United States of America"]
//   - coverImage: [id:42, imageId:1, path:"moby-dick.jpg"]
```

- [The Structure of a Joined Request]
- [Decoding a Joined Request with a Decodable Record]
- [Decoding a Joined Request with FetchableRecord]


## The Structure of a Joined Request

**Joined request define a tree of associated records identified by "association keys".**

Below, author and cover image are both associated to book, and country is associated to author:

```swift
let request = Book
    .including(required: Book.author
        .including(optional: Author.country))
    .including(optional: Bool.coverImage)
```

This request builds the following **tree of association keys**:

![TreeOfAssociationKeys](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/TreeOfAssociationKeys.svg)

**Association keys** are strings. They are the names of the database tables of associated records (unless you specify otherwise, as we'll see below).

Those keys are associated with slices in the fetched rows:

![TreeOfAssociationKeysMapping](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/TreeOfAssociationKeysMapping.svg)

We'll see below how this tree of association keys and row slices can feed a Decodable record type. We'll then add some details by using FetchableRecord without Decodable support.


## Decoding a Joined Request with a Decodable Record

When **association keys** match the property names of a Decodable record, you get free decoding of joined requests into this record:

```swift
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var author: Author
    var country: Country?
    var coverImage: CoverImage?
}

let bookInfos = try BookInfo.fetchAll(db, request) // [BookInfo]
```

We see that a hierarchical tree has been flattened in the `BookInfo` record.

This flattening is made possible because the BookInfo initializer generated by the Decodable protocol matches **coding keys** with **association keys** by performing a breadth-first search in the tree of association keys.

This deserves a little explanation:

You known that the Decodable protocol feeds a value's properties by looking for **coding keys**. For example, the standard built-in JSONDecoder matches those coding keys with dictionary keys in a JSON object. The GRDB record decoder also matches coding keys, but with association keys:

![TreeOfAssociationKeysMapping](https://cdn.rawgit.com/groue/GRDB.swift/GRDB3/Documentation/Images/Associations2/TreeOfAssociationKeysMapping.svg)

Practically speaking, the BookInfo initializer first looks for the "book" coding key. This key is not found anywhere in the tree of association keys, so the book property is initialized from the row slice associated with the root of the tree, which contains book columns.

The BookInfo initializer then looks for the "author", "country", and "coverImage" coding keys. All those are found in the tree of association keys, and each property is initialized from its matching row slice.

The key lookup digs into the tree of association keys, and stops as soon as a key as been found, digging into deep tree levels only if the key was not found in higher levels (that's called a "breadth-first search"). This is how we can decode a hierarchical tree into a flat record.

But sometimes your decoded records will have better reflect the hierarchical structure of the request:


### Decoding a Hierarchical Decodable Record

Some requests are better decoded with a Decodable record that reflects the hierarchical structure of the request.

```swift
let request = Book
    .including(optional: Bool.coverImage)
    .including(required: Book.author
        .including(optional: Person.country))
    .including(optional: Book.translator
        .including(optional: Person.country))
```

This requests for all books, with their cover images, and their authors and translators. Those people are themselves decorated with their respective nationalities.

We plan to decode this request into is the following record:

```swift
struct BookInfo: FetchableRecord, Decodable {
    struct AuthorInfo: Decodable {
        var author: Author
        var country: Country?
    }
    var book: Book
    var authorInfo: AuthorInfo
    var translatorInfo: AuthorInfo?
    var coverImage: CoverImage?
}
```

This request needs a little preparation: we need **association keys** that match the **coding keys** for the authorInfo and translatorInfo properties.

And who is the most able to know those coding keys? BookInfo itself, thanks to its `CodingKeys` enum that was automatically generated by the Swift compiler. We thus define the `BookInfo.all()` method that builds our request:

```swift
extension BookInfo {
    static func all() -> QueryInterfaceRequest<BookInfo> {
        return Book
            .including(optional: Bool.coverImage)
            .including(required: Book.author
                .forKey(CodingKeys.authorInfo)        // (1)
                .including(optional: Person.country))
            .including(optional: Book.translator
                .forKey(CodingKeys.translatorInfo)    // (1)
                .including(optional: Person.country))
            .asRequest(of: BookInfo.self)             // (2)
    }
}

let bookInfos = try BookInfo.all().fetchAll(db, request) // [BookInfo]
```

1. The `forKey(_:)` method changes the association key, so that the associated records can feed their target properties.
2. The `asRequest(of:)` method turns the request into a request of BookInfo. See [Custom Requests] for more information.


### Debugging Joined Request Decoding

When you have difficulties building a Decodable record that successfully decodes a joined request, we advise to temporarily decode raw database rows, and inspect them.

```swift
let request = Book
    .including(required: Book.author
        .including(optional: Author.country))
    .including(optional: Bool.coverImage)

let rows = try Row.fetchAll(db, request)
print(rows[0])
// Prints:
// ▿ [id:1, authorId:2, title:"Moby-Dick"]
//   unadapted: [id:1, authorId:2, title:"Moby-Dick", id:2, name:"Herman Melville", countryCode:"US", code:"US", name:"United States of America", id:NULL, imageId:NULL, path:NULL]
//   - person: [id:2, name:"Herman Melville", countryCode:"US"]
//     - country: [code:"US", name:"United States of America"]
//   - coverImage: [id:NULL, imageId:NULL, path:NULL]
```

There are two important things to look into the row debugging description:

- the **association keys**: "person", "country", and "coverImage" in our example
- associated rows that contain only null values (coverImage).

The associated rows that contain only null values are easy to deal with: null rows loaded from optional associated records should be decoded into Swift optionals:

```swift
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var author: Author          // .including(required: Book.author)
    var country: Country?       // .including(optional: Author.country)
    var coverImage: CoverImage? // .including(optional: Bool.coverImage)
}
```

**Association keys** may not match the property names of your Decodable record. In this case, use the `forKey(_:)` method.

This can be done at the request level:

```swift
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var author: Author          // Expect "author" association key
    var country: Country?
    var coverImage: CoverImage?
}

let request = Book
    .including(required: Book.author
        .forKey("author")       // Change association key
        .including(optional: Author.country))
    .including(optional: Bool.coverImage)
```

Association keys can also be defined right into the definition of the association:

```swift
struct Book {
    static let author = belongsTo(Person.self).forKey("author")
}

let request = Book
    .including(required: Book.author // "author" association key
        .including(optional: Author.country))
    .including(optional: Bool.coverImage)
```

The best choice is up to you and the structure of your application. See also [Decoding a Hierarchical Decodable Record] for further discussion about decoding keys.


## Decoding a Joined Request with FetchableRecord

When [Dedocable](#decoding-a-joined-request-with-a-decodable-record) records provides convenient decoding of joined rows, you may want a little more control over row decoding.

The `init(row:)` initializer of the FetchableRecord protocol is what you look after:

```swift
struct BookInfo: FetchableRecord {
    var book: Book
    var author: Author
    var country: Country?
    var coverImage: CoverImage?
    
    init(row: Row) {
        book = Book(row: row)
        author = row["author"]
        country = row["country"]
        coverImage = row["coverImage"]
    }
}

let bookInfos = try BookInfo.fetchAll(db, request) // [BookInfo]
```

You are already familiar with row subscripts to decode [database values](../README.md#column-values):

```swift
let name: String = row["name"]
```

When you extract a record instead of a value from a row, GRDB perfoms a breadth-first search in the tree of **association keys** defined by the joined request. If the key is not found, or only associated with columns that all contain NULL values, an optional record is decoded as nil:

```swift
let author: Author = row["author"]
let country: Country? = row["country"]
```

You can also perform custom navigation in the tree by using *row scopes*. See [Row Adapters] for more information.


## Known Issues

**You can't chain a required association on an optional association:**

```swift
// NOT IMPLEMENTED
let request = Book
    .joining(optional: Book.author
        .including(required: Person.country))
```

This code compiles, but you'll get a runtime fatal error "Not implemented: chaining a required association behind an optional association". Future versions of GRDB may allow such requests.

**You can't join two associations with the same [association key](#the-structure-of-a-joined-request) at the same level:**

```swift
// NOT IMPLEMENTED
let request = Book
    .including(Book.author) // key "author"
    .including(Book.author) // key "author"
```

This code compiles, but you'll get a runtime fatal error "The association key `author` is ambiguous. Use the Association.forKey(_:) method is order to disambiguate.". Future versions of GRDB may allow such requests.

To join the same table twice, and make sure GRDB does not modify the fetched results in some future release, make sure no two associations have the same name on a given level:

```swift
// OK
let request = Book
    .including(Book.author.forKey("firstAuthor"))
    .including(Book.author.forKey("secondAuthor"))
```


## Future Directions

The APIs that have been described above do not cover the whole topic of joined requests. Among the biggest omissions, there is:

- One can not yet join two tables without a foreign key. One can not build the plain `SELECT * FROM a JOIN b`, for example.

- One can not yet express requests such as "all authors with all their books".

- A common use case of associations is aggregations, such as fetching all authors with the number of books they have written:
    
    ```swift
    let request = Author.annotate(with: Author.books.count)
    ```

- There's no HasOneThrough and HasManyThrough association, which would allow to skip intermediate bridge records when building requests.
    
Those features are not present yet because they hide several very tough challenges. Come [discuss](http://twitter.com/groue) for more information, or if you wish to help turning those features into reality.


---

This documentation owns a lot to the [Active Record Associations](http://guides.rubyonrails.org/association_basics.html) guide, which is an immensely well-written introduction to database relations. Many thanks to the Rails team and contributors.

---

### LICENSE

**GRDB**

Copyright (C) 2018 Gwendal Roué

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

**Ruby on Rails documentation**

Copyright (c) 2005-2018 David Heinemeier Hansson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

[Associations Benefits]: #associations-benefits
[BelongsTo]: #belongsto
[HasOne]: #hasone
[HasMany]: #hasmany
[Choosing Between BelongsTo and HasOne]: #choosing-between-belongsto-and-hasone
[Self Joins]: #self-joins
[The Types of Associations]: #the-types-of-associations
[Codable]: https://developer.apple.com/documentation/swift/codable
[FetchableRecord]: ../README.md#fetchablerecord-protocols
[migration]: ../README.md#migrations
[Record]: ../README.md#records
[Foreign Key Actions]: https://sqlite.org/foreignkeys.html#fk_actions
[Associations and the Database Schema]: #associations-and-the-database-schema
[Convention for Database Table Names]: #convention-for-database-table-names
[Convention for the BelongsTo Association]: #convention-for-the-belongsto-association
[Convention for the HasOne Association]: #convention-for-the-hasone-association
[Convention for the HasMany Association]: #convention-for-the-hasmany-association
[Foreign Keys]: #foreign-keys
[Building Requests from Associations]: #building-requests-from-associations
[Fetching Values from Associations]: #fetching-values-from-associations
[Combining Associations]: #combining-associations
[Requesting Associated Records]: #requesting-associated-records
[Joining Methods]: #joining-methods
[Filtering Associations]: #filtering-associations
[Sorting Associations]: #sorting-associations
[Columns Selected by an Association]: #columns-selected-by-an-association
[Table Aliases]: #table-aliases
[The Structure of a Joined Request]: #the-structure-of-a-joined-request
[Decoding a Joined Request with a Decodable Record]: #decoding-a-joined-request-with-a-decodable-record
[Decoding a Hierarchical Decodable Record]: #decoding-a-hierarchical-decodable-record
[Decoding a Joined Request with FetchableRecord]: #decoding-a-joined-request-with-fetchablerecord
[Custom Requests]: ../README.md#custom-requests
[Known Issues]: #known-issues
[Future Directions]: #future-directions
[Row Adapters]: ../README.md#row-adapters