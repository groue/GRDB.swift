GRDB Associations
=================

- [Associations Benefits]
- [Required Protocols]
- [The Types of Associations]
    - [BelongsTo]
    - [HasMany]
    - [HasOne]
    - [HasManyThrough]
    - [HasOneThrough]
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
    - [Joining And Prefetching Associated Records]
    - [Combining Associations]
    - [Filtering Associations]
    - [Sorting Associations]
    - [Ordered Associations]
    - [Columns Selected by an Association]
    - [Table Aliases]
    - [Refining Association Requests]
- [Fetching Values from Associations]
    - [The Structure of a Joined Request]
    - [Decoding a Joined Request with a Decodable Record]
    - [Decoding a Joined Request with FetchableRecord]
    - [Debugging Request Decoding]
- [Association Aggregates]
    - [Available Association Aggregates]
    - [Annotating a Request with Aggregates]
    - [Filtering a Request with Aggregates]
    - [Aggregate Operations]
    - [Isolation of Multiple Aggregates]
- [DerivableRequest Protocol]

**[FAQ]**

- [How do I filter records and only keep those that are associated to another record?](../README.md#how-do-i-filter-records-and-only-keep-those-that-are-associated-to-another-record)
- [How do I filter records and only keep those that are NOT associated to another record?](../README.md#how-do-i-filter-records-and-only-keep-those-that-are-not-associated-to-another-record)
- [How do I select only one column of an associated record?](../README.md#how-do-i-select-only-one-column-of-an-associated-record)

**[Known Issues]**


## Associations Benefits

**An association is a connection between two [Record] types.**

Associations streamline common operations in your code, make them safer, and more efficient. For example, consider a library application that has two record types, author and book:

```swift
struct Author {
    var id: Int64
    var name: String
}

struct Book {
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
    let author = try Author.fetchOne(db, key: book.authorId)
    return BookInfo(book: book, author: author)
}
```

With GRDB associations, we can streamline these operations (and others), by declaring the connections between books and authors. Here is how we define associations, and properties that access them:

```swift
extension Author {
    static let books = hasMany(Book.self)
    var books: QueryInterfaceRequest<Book> {
        request(for: Author.books)
    }
}

extension Book {
    static let author = belongsTo(Author.self)
    var author: QueryInterfaceRequest<Author> {
        request(for: Book.author)
    }
}
```

Loading all books from an existing author is now easier:

```swift
let books = try author.books.fetchAll(db)
```

As for loading all pairs of books and authors, it is not only easier, but also *much more efficient*:

```swift
struct BookInfo: FetchableRecord, Decodable {
    let book: Book
    let author: Author?
}

let request = Book.including(optional: Book.author)
let bookInfos = BookInfo.fetchAll(db, request)
```

Before we dive in, please remember that associations can not generate all possible SQL queries that involve several tables. You may also *prefer* writing SQL, and this is just OK, because your SQL skills are welcome: see the [Joined Queries Support](../README.md#joined-queries-support) chapter.


## Required Protocols

**Associations are available on types that adopt the necessary supporting protocols.**

When your record type is a subclass of the [Record class], all necessary protocols are already setup and ready: you can skip this chapter.

Generally speaking, associations use the [TableRecord], [FetchableRecord], and [EncodableRecord] protocols:

- **[TableRecord]** is the protocol that lets you declare associations between record types:

    ```swift
    extension Author: TableRecord {
        static let books = hasMany(Book.self)
    }
    
    extension Book: TableRecord {
        static let author = belongsTo(Author.self)
    }
    ```

- **[FetchableRecord]** makes it possible to fetch records from the database:

    ```swift
    extension Author: FetchableRecord { }
    
    // Who's prolific?
    let authors = try dbQueue.read { db in
        try Author
            .having(Author.books.count >= 20)
            .fetchAll(db) // [Author]
    }
    ```
    
    FetchableRecord conformance can be derived from the standard Decodable protocol. See [Codable Records] for more information.

- **[EncodableRecord]** makes it possible to fetch associated records with the `request(for:)` method:

    ```swift
    extension Book: EncodableRecord {
        // The request for the author of a book.
        var author: QueryInterfaceRequest<Author> {
            request(for: Book.author)
        }
    }
    
    // Who wrote this book?
    let book: Book = ...
    let author = try dbQueue.read { db in
        try book.author.fetchOne(db) // Author?
    }
    ```
    
    A record type can conform to EncodableRecord via the [PersistableRecord] protocol. However, PersistableRecord also grants [persistence methods], the ones that are able to insert, update, and delete rows in the database. When you'd rather keep a record type read-only, and yet profit from associations, all you need is EncodableRecord.
    
    EncodableRecord conformance can be derived from the standard Encodable protocol. See [Codable Records] for more information.


The Types of Associations
=========================

GRDB handles five types of associations:

- **BelongsTo**
- **HasMany**
- **HasOne**
- **HasManyThrough**
- **HasOneThrough**

An association declares a link from a record type to another, as in "one book **belongs to** its author". It instructs GRDB to use the foreign keys declared in the database as support for Swift methods.

Each one of these associations is appropriate for a particular database situation.

- [BelongsTo]
- [HasMany]
- [HasOne]
- [HasManyThrough]
- [HasOneThrough]
- [Choosing Between BelongsTo and HasOne]
- [Self Joins]


## BelongsTo

The **BelongsTo** association sets up a one-to-one connection from a record type to another record type, such as each instance of the declaring record "belongs to" an instance of the other record.

For example, if your application includes authors and books, and each book is assigned its author, you'd declare the `Book.author` association as below:

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

![BelongsToSchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/BelongsToSchema.svg)

See [Convention for the BelongsTo Association] for some sample code that defines the database schema for such an association, and [Building Requests from Associations] in order to learn how to use it.


## HasMany

The **HasMany** association indicates a one-to-many connection between two record types, such as each instance of the declaring record "has many" instances of the other record. You'll often find this association on the other side of a **BelongsTo** association.

For example, if your application includes authors and books, and each author is assigned zero or more books, you'd declare the `Author.books` association as below:

```swift
struct Author: TableRecord {
    static let books = hasMany(Book.self)
}

struct Book: TableRecord {
    ...
}
```

The **HasMany** association between an author and its books needs that the database table for books has a column that points to the table for authors:

![HasManySchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/HasManySchema.svg)

See [Convention for the HasMany Association] for some sample code that defines the database schema for such an association, and [Building Requests from Associations] in order to learn how to use it.


## HasOne

The **HasOne** association, like BelongsTo, sets up a one-to-one connection from a record type to another record type, but with different semantics, and underlying database schema. It is usually used when an entity has been denormalized into two database tables.

For example, if your application has one database table for countries, and another for their demographic profiles, you'd declare the `Country.demographics` association as below:

```swift
struct Country: TableRecord {
    static let demographics = hasOne(Demographics.self, key: "demographics")
    ...
}

struct Demographics: TableRecord {
    ...
}
```

The **HasOne** association between a country and its demographics needs that the database table for demographics has a column that points to the table for countries:

![HasOneSchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/HasOneSchema.svg)

Note that this demographics example of HasOne association uses an explicit `"demographics"` key, unlike the BelongsTo and HasMany associations above. This key is necessary when you use a plural name for a one-to-one association. See [Convention for Database Table Names] for more information.

See [Convention for the HasOne Association] for some sample code that defines the database schema for such an association, and [Building Requests from Associations] in order to learn how to use it.


## HasManyThrough

The **HasManyThrough** association is often used to set up a many-to-many connection with another record. This association indicates that the declaring record can be matched with zero or more instances of another record by proceeding through a third record. For example, consider the practice of passport delivery. The relevant association declarations could look like this:

```swift
struct Country: TableRecord {
    static let passports = hasMany(Passport.self)
    static let citizens = hasMany(Citizen.self, through: passports, using: Passport.citizen)
    ...
}

struct Passport: TableRecord {
    static let country = belongsTo(Country.self)
    static let citizen = belongsTo(Citizen.self)
}
 
struct Citizen: TableRecord {
    static let passports = hasMany(Passport.self)
    static let countries = hasMany(Country.self, through: passports, using: Passport.country)
    ...
}
```

![HasManyThroughSchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/HasManyThroughSchema.svg)

The **HasManyThrough** association is also useful for setting up "shortcuts" through nested associations. For example, if a document has many sections, and a section has many paragraphs, you may sometimes want to get a simple collection of all paragraphs in the document. You could set that up this way:

```swift
struct Document: TableRecord {
    static let sections = hasMany(Section.self)
    static let paragraphs = hasMany(Paragraph.self, through: sections, using: Section.paragraphs)
    ...
}

struct Section: TableRecord {
    static let paragraphs = hasMany(Paragraph.self)
    ...
}
 
struct Paragraph: TableRecord {
    ...
}
```

As in the examples above, **HasManyThrough** association is always built from two other associations: the `through:` and `using:` arguments. Those associations can be any other association (BelongsTo, HasMany, HasManyThrough, etc). The above `Document.paragraphs` association can also be defined, in a much more explicit way, as below:

```swift
struct Document: TableRecord {
    static let paragraphs = hasMany(
        Paragraph.self,
        through: Document.hasMany(Section.self),
        using: Section.hasMany(Paragraph.self))
    ...
}
```

See [Building Requests from Associations] in order to learn how to use the HasManyThrough association.


## HasOneThrough

A **HasOneThrough** association sets up a one-to-one connection with another record. This association indicates that the declaring record can be matched with one instance of another record by proceeding through a third record. For example, if each book belongs to a library, and each library has one address, then one knows where the book should be returned to:

```swift
struct Book: TableRecord {
    static let library = belongsTo(Library.self)
    static let returnAddress = hasOne(Address.self, through: library, using: Library.address)
    ...
}

struct Library: TableRecord {
    static let address = hasOne(Address.self)
    ...
}
 
struct Address: TableRecord {
    ...
}
```

![HasOneThroughSchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/HasOneThroughSchema.svg)

As in the example above, **HasOneThrough** association is always built from two other associations: the `through:` and `using:` arguments. Those associations can be any other association to one (BelongsTo, HasOne, HasOneThrough). The above `Book.returnAddress` association can also be defined, in a much more explicit way, as below:

```swift
struct Book: TableRecord {
    static let returnAddress = hasOne(
        Address.self,
        through: Book.belongsTo(Library.self),
        using: Library.hasOne(Address.self))
    ...
}
```

See [Building Requests from Associations] in order to learn how to use the HasOneThrough association.


## Choosing Between BelongsTo and HasOne

When you want to set up a one-to-one relationship between two record types, you'll need to add a **BelongsTo** association to one, and a **HasOne** association to the other. How do you know which is which?

The distinction is in where you place the database foreign key. The record that points to the other one has the **BelongsTo** association. The other record has the **HasOne** association:

A country **has one** demographic profile, a demographic profile **belongs to** a country:

![HasOneSchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/HasOneSchema.svg)

```swift
struct Country: TableRecord {
    static let demographics = hasOne(Demographics.self)
    ...
}

struct Demographics: TableRecord {
    static let country = belongsTo(Country.self)
    ...
}
```

## Self Joins

When designing your data model, you will sometimes find a record that should have a relation to itself. For example, you may want to store all employees in a single database table, but be able to trace relationships such as between manager and subordinates. This situation can be modeled with self-joining associations:

```swift
struct Employee {
    static let subordinates = hasMany(Employee.self, key: "subordinates")
    static let manager = belongsTo(Employee.self, key: "manager")
    ...
}
```

![RecursiveSchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/RecursiveSchema.svg)

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

Note that both sides of the self-join use a customized **[association key](#the-structure-of-a-joined-request)**. This helps consuming this association. For example:

```swift
struct EmployeeInfo: FetchableRecord, Decodable {
    var employee: Employee
    var manager: Employee?
    var subordinates: Set<Employee>
}

let request = Employee
    .including(optional: Employee.manager)
    .including(all: Employee.subordinates)

let employeeInfos: [EmployeeInfo] = try EmployeeInfo.fetchAll(db, request)
```

See [Fetching Values from Associations] for more information.


Associations and the Database Schema
====================================

**Associations are grounded in the database schema, the way database tables are defined.**

For example, a **[BelongsTo]** association between a book and its author needs that the database table for books has a column that points to the table for authors.

GRDB also comes with several *conventions* for defining your database schema.

Those conventions help associations be convenient and, generally, "just work". When you can't, or don't want to follow conventions, you will have to override the expected defaults in your Swift code.

- [Convention for Database Table Names]
- [Convention for the BelongsTo Association]
- [Convention for the HasMany Association]
- [Convention for the HasOne Association]
- [Foreign Keys]


## Convention for Database Table Names

**Database table names should be written in English, singular, and camelCased.**

Make them look like Swift identifiers: `book`, `author`, `postalAddress`.

If the database schema does not follow this convention, and has, for example, database tables which are named with underscores (`postal_address`), you can still use associations. But you need to help row consumption by naming your associations with a customized key:

```swift
// Setup for table names that does not follow the expected convention

struct PostalAddress: TableRecord {
    // Customized table name
    static let databaseTableName = "postal_address"
}

extension Author {
    // Customized association key
    static let postalAddress = belongsTo(PostalAddress.self, key: "postalAddress")
}
```

GRDB will automatically **pluralize** or **singularize** names in order to help you easily associate records.

For example, the Book and Author records will automatically feed properties named `books`, `author`, or `bookCount` in your decoded records, without any explicit configuration, as long as the names of the backing database tables are "book" and "author".

The GRDB pluralization mechanisms are very powerful, being capable of pluralizing and singularizing both regular and irregular words (it's directly inspired from the battle-tested [Ruby on Rails inflections](https://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-pluralize)).

When using class names composed of two or more words, the table name should use the camelCase singular form:

| RecordType | Table Name | Derived identifiers |
| ---------- | ---------- | ------------------- |
| Book       | book       | `book`, `books`, `bookCount` |
| LineItem   | lineItem   | `lineItem`, `lineItems`, `lineItemPriceSum` |
| Mouse      | mouse      | `mouse`, `mice`, `maxMouseSize` |
| Person     | person     | `person`, `people`, `personCount` |

If your application relies on non-English names, GRDB may generate unexpected identifiers. If this happens, please [open an issue](http://github.com/groue/GRDB.swift/issues).

See [The Structure of a Joined Request] for more information.


## Convention for the BelongsTo Association

```swift
extension Book: TableRecord {
    static let author = belongsTo(Author.self)
}
```

![BelongsToSchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/BelongsToSchema.svg)

Here is the recommended [migration] for the **[BelongsTo]** association:

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

The example above uses auto-incremented primary keys. But generally speaking, all primary keys are supported, including composite primary keys that span several columns.

Following this convention lets you write, for example:

```swift
struct Book: TableRecord {
    static let author = belongsTo(Author.self)
}

struct Author: TableRecord {
}
```

If the database schema does not follow this convention, and does not define foreign keys between tables, you can still use **BelongsTo** associations. But your help is needed to define the missing foreign key:

```swift
struct Book: TableRecord {
    static let author = belongsTo(Author.self, using: ForeignKey(...))
}
```

See [Foreign Keys] for more information.


## Convention for the HasMany Association

```swift
extension Author: TableRecord {
    static let books = hasMany(Book.self)
}
```

![HasManySchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/HasManySchema.svg)

Here is the recommended [migration] for the **[HasMany]** association:

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

The example above uses auto-incremented primary keys. But generally speaking, all primary keys are supported, including composite primary keys that span several columns.

Following this convention lets you write, for example:

```swift
struct Book: TableRecord {
}

struct Author: TableRecord {
    static let books = hasMany(Book.self)
}
```

If the database schema does not follow this convention, and does not define foreign keys between tables, you can still use **HasMany** associations. But your help is needed to define the missing foreign key:

```swift
struct Author: TableRecord {
    static let books = hasMany(Book.self, using: ForeignKey(...))
}
```

See [Foreign Keys] for more information.


## Convention for the HasOne Association

```swift
extension Country: TableRecord {
    static let demographics = hasOne(Demographics.self)
}
```

![HasOneSchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/HasOneSchema.svg)

Here is the recommended [migration] for the **[HasOne]** association:

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

The example above uses a string primary key for the "country" table. But generally speaking, all primary keys are supported, including composite primary keys that span several columns.

Following this convention lets you write, for example:

```swift
struct Country: TableRecord {
    static let demographics = hasOne(Demographics.self)
}

struct Demographics: TableRecord {
}
```

If the database schema does not follow this convention, and does not define foreign keys between tables, you can still use HasOne associations. But your help is needed to define the missing foreign key:

```swift
struct Country: TableRecord {
    static let demographics = hasOne(Demographics.self, using: ForeignKey(...))
}
```

See [Foreign Keys] for more information.


## Foreign Keys

**Associations can automatically infer the foreign keys that define how two database tables are linked together.**

In the example below, the `book.authorId` column is automatically used to link a book to its author:

![BelongsToSchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/BelongsToSchema.svg)

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

![AmbiguousForeignKeys](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/AmbiguousForeignKeys.svg)

When this happens, associations can't be automatically inferred from the database schema. GRDB will complain with a fatal error such as "Ambiguous foreign key from book to person", or "Could not infer foreign key from book to person".

Your help is needed. You have to instruct GRDB which foreign key to use:

```swift
struct Book: TableRecord {
    // Define foreign keys
    static let authorForeignKey = ForeignKey(["authorId"])
    static let translatorForeignKey = ForeignKey(["translatorId"])
    
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

Foreign keys can also be defined from query interface columns:

```swift
struct Book: TableRecord {
    enum Columns: String, ColumnExpression {
        case id, title, authorId, translatorId
    }
    
    static let authorForeignKey = ForeignKey([Columns.authorId])
    static let translatorForeignKey = ForeignKey([Columns.translatorId])
}
```

When the destination table of a foreign key does not define any primary key, you need to provide the full definition of a foreign key:

```swift
struct Book: TableRecord {
    static let authorForeignKey = ForeignKey(["authorId"], to: ["id"])
    static let author = belongsTo(Person.self, using: authorForeignKey)
}
```


Building Requests from Associations
===================================

**Once you have defined associations, you can define fetch request that involve several record types.**

Fetch requests do not visit the database until you fetch values from them. This will be covered in [Fetching Values from Associations]. But before you can fetch anything, you have to describe what you want to fetch. This is the topic of this chapter.

- [Requesting Associated Records]
- [Joining And Prefetching Associated Records]
- [Combining Associations]
- [Filtering Associations]
- [Sorting Associations]
- [Ordered Associations]
- [Columns Selected by an Association]
- [Table Aliases]
- [Refining Association Requests]


## Requesting Associated Records

**You can use associations to build requests for associated records.**

For example, given a `Book.author` **[BelongsTo]** association, you can build a request for the author of a book with the `request(for:)` method. In the example below, we return this request from the `Book.author` property:

```swift
struct Book: TableRecord, EncodableRecord {
    /// The association from a book to is author
    static let author = belongsTo(Author.self)
    
    /// The request for the author of a book
    var author: QueryInterfaceRequest<Author> {
        request(for: Book.author)
    }
}
```

You can now fetch the author of a book:

```swift
let book: Book = ...
let author = try book.author.fetchOne(db) // Author?
```

All other associations, **[HasOne]**, **[HasMany]**, **[HasOneThrough]**, and **[HasManyThrough]**, can also build requests for associated records. For example:

```swift
struct Author: TableRecord, EncodableRecord {
    /// The association from an author to its books
    static let books = hasMany(Book.self)
    
    /// The request for the books of an author
    var books: QueryInterfaceRequest<Book> {
        request(for: Author.books)
    }
}

let author: Author = ...
let books = try author.books.fetchAll(db) // [Book]
```

Requests for associated records can be filtered and ordered like all [query interface requests]:

```swift
let novels = try author
    .books
    .filter(Column("kind") == BookKind.novel)
    .order(Column("publishDate").desc)
    .fetchAll(db) // [Book]
```


## Joining And Prefetching Associated Records

**You build requests that involve several records with the following "joining methods":**

- `joining(optional: association)`
- `joining(required: association)`
- `including(optional: association)`
- `including(required: association)`
- `including(all: associationToMany)`

Before we describe them in detail, let's see a few requests they can build:

```swift
/// All authors with their respective books
let request = Author
    .including(all: Author.books)

/// All books with their respective author
let request = Book
    .including(required: Book.author)

/// All books with their respective author, sorted by title
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
    
    For example, to load books with their respective author, you use `including(required:)`:
    
    ```swift
    // All books with their respective author
    let request = Book
        .including(required: Book.author)
    
    // This request can feed the following record:
    struct BookInfo: FetchableRecord, Decodable {
        var book: Book
        var author: Author // the required associated author
    }
    let bookInfos: [BookInfo] = try BookInfo.fetchAll(db, request)
    ```
    
    And to load authors with their respective books, you use `including(all:)`:
    
    ```swift
    // All authors with their respective books
    let request = Author
        .including(all: Author.books)
    
    // This request can feed the following record:
    struct AuthorInfo: FetchableRecord, Decodable {
        var author: Author
        var books: [Book] // all associated books
    }
    let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)
    ```
    
    On the other side, to load all books written by a French author, you sure need to filter authors, but you don't need them to be present in the fetched results. You prefer `joining`:
    
    ```swift
    // All books written by a French author
    let request = Book
        .joining(required: Book.author.filter(Column("countryCode") == "FR"))
    
    // This request feeds the Book record:
    let books: [Book] = try request.fetchAll(db)
    ```

2. For to-one associations, should the request allow missing associated records?
    
    If yes, choose the `optional` variant. Otherwise, choose `required`.
    
    For example, to load all books with their respective authors, even if the book has no recorded author, you'd use `including(optional:)`:
    
    ```swift
    // All books with their respective (eventual) authors
    let request = Book
        .including(optional: Book.author)
    
    // This request can feed the following record:
    struct BookInfo: FetchableRecord, Decodable {
        var book: Book
        var author: Author? // the optional associated author
    }
    let bookInfos: [BookInfo] = try BookInfo.fetchAll(db, request)
    ```
    
    You can remember to use `optional` when the fetched associated records should feed optional Swift values, of type `Author?`. Conversely, when the fetched results feed non-optional values of type `Author`, prefer `required`.
    
    Another way to describe the difference is that `required` filters the fetched results in order to discard missing associated records, when `optional` does not filter anything, and lets missing values pass through.
    
    Finally, readers who speak SQL may compare `optional` with left joins, and `required` with inner joins.

> :warning: **Warning**: You will get a database error with code [`SQLITE_ERROR`](https://www.sqlite.org/rescode.html#error) (1) "Expression tree is too large", when the following conditions are met:
>
> - You use the `including(all:)` method (say: `Parent.including(all: children)`).
> - The association is based on a compound foreign key (made of two columns or more).
> - The request fetches a lot of parent records. The exact threshold depends on [SQLITE_LIMIT_EXPR_DEPTH](https://www.sqlite.org/limits.html). It is around 1000 parents in recent iOS and macOS systems. To get an exact figure, run:
>
>     ```swift
>     let limit = try dbQueue.read { db in
>          sqlite3_limit(db.sqliteConnection, SQLITE_LIMIT_EXPR_DEPTH, -1)
>     }
>     ```
>
> Possible workarounds are:
> 
> - Refactor the database schema so that you do not depend on a compound foreign key.
> - Prefetch children with your own code, without using `including(all:)`.
>
> For more information about this caveat, see [issue #871](https://github.com/groue/GRDB.swift/issues/871).

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

// This request can feed the following record:
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var author: Person
    var translator: Person?
}
let bookInfos: [BookInfo] = try BookInfo.fetchAll(db, request)
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

// This request can feed the following record:
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var author: Author
    var country: Country?
}
let bookInfos: [BookInfo] = try BookInfo.fetchAll(db, request)
```

The request above fetches all books, along with their author, and their author's country.

When you chain associations, you can avoid fetching intermediate tables by replacing the `including` method with `joining`. The request below fetches all books, along with their author's country, but does not include the intermediate authors in the fetched results:

```swift
// SELECT book.*, country.*
// FROM book
// LEFT JOIN person ON person.id = book.authorId
// LEFT JOIN country ON country.code = person.countryCode
let request = Book
    .joining(optional: Book.author
        .including(optional: Person.country))

// This request can feed the following record:
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var country: Country?
}
let bookInfos: [BookInfo] = try BookInfo.fetchAll(db, request)
```

**[HasOneThrough]** and **[HasManyThrough]** associations provide a shortcut for those requests that skip intermediate tables:

```swift
// SELECT book.*, country.*
// FROM book
// LEFT JOIN person ON person.id = book.authorId
// LEFT JOIN country ON country.code = person.countryCode
let request = Book.including(optional: Book.country)

// This request can feed the following record:
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var country: Country?
}
let bookInfos: [BookInfo] = try BookInfo.fetchAll(db, request)
```

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

// This request feeds the Book record:
let books: [Book] = try request.fetchAll(db)
```

The request above fetches all books written by a French author.

The one below fetches all authors along with their novels and poems:

```swift
let request = Author
    .including(all: Author.book
        .filter(Column("kind") == "novel")
        .forKey("novels"))
    .including(all: Author.book
        .filter(Column("kind") == "poems")
        .forKey("poems"))

// This request can feed the following record:
struct AuthorInfo: FetchableRecord, Decodable {
    var author: Author
    var novels: [Book]
    var poems: [Book]
}
let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)
```

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


## Ordered Associations

By default, **[HasMany]** or **[HasManyThrough]** associations are unordered: the order of associated records is undefined unless [explicitly specified](#sorting-associations) on each request.

But you can build an ordering right into the definition of an association, so that it becomes the default ordering for this association. For example, let's model soccer teams and players, ordered by the number printed on their shirt.

Let's start with a **HasMany** association. Each player knows its position in its team:

```swift
struct Team: FetchableRecord, TableRecord {
    var id: Int64
    var name: String
}

struct Player: FetchableRecord, TableRecord {
    var id: Int64
    var teamId: Int64
    var name: String
    var position: Int
}
```

The `Team.players` association is ordered by position, so that all team players are loaded well-sorted by default:

```swift
extension Team {
    static let players = hasMany(Player.self).order(Column("position"))
    
    var players: QueryInterfaceRequest<Player> {
        request(for: Team.players)
    }
}
```

Things are very similar for **HasManyThrough** associations. Now each player knows its position in the teams it belongs to:

```swift
struct Team: FetchableRecord, TableRecord {
    var id: Int64
    var name: String
}

struct PlayerRole: FetchableRecord, TableRecord {
    var teamId: Int64
    var playerId: Int64
    var position: Int
}

struct Player: FetchableRecord, TableRecord {
    var id: Int64
    var name: String
}
```

Again, the `Team.players` association is ordered by position, so that all team players are loaded well-sorted by default:

```swift
extension Team {
    static let playerRoles = hasMany(PlayerRole.self).order(Column("position"))
    
    static let players = hasMany(Player.self, through: playerRoles, using: PlayerRole.player)
    
    var players: QueryInterfaceRequest<Player> {
        request(for: Team.players)
    }
}

extension PlayerRole {
    static let player = belongsTo(Player.self)
}
```

In both cases, you can escape the default ordering when you need it:

```swift
struct TeamInfo: Decodable, FetchableRecord {
    var team: Team
    var players: [Player]
}

// Default ordering by position
let team: Team = ...
let players = try team.players.fetchAll(db)
let teamInfos = try Team
    .including(all: Team.players)
    .asRequest(of: TeamInfo.self)
    .fetchAll(db)

// Custom ordering
let team: Team = ...
let players = try team.players.order(Column("name")).fetchAll(db)
let teamInfos = try Team
    .including(all: Team.players.order(Column("name")))
    .asRequest(of: TeamInfo.self)
    .fetchAll(db)
```


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

To specify the default selection for all inclusions of a given type, see [Columns Selected by a Request](../README.md#columns-selected-by-a-request).


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
// SELECT b.*
// FROM book b
// JOIN person a ON a.id = b.authorId
//              AND a.countryCode = 'FR'
// WHERE b.publishDate >= a.deathDate
let bookAlias = TableAlias(name: "b")
let authorAlias = TableAlias(name: "a")
let request = Book.aliased(bookAlias)
    .joining(required: Book.author.aliased(authorAlias)
        .filter(sql: "a.countryCode = ?", arguments: ["FR"]))
    .filter(sql: "b.publishDate >= a.deathDate")
```

> :point_up: **Note**: avoid reusing table aliases between several tables or requests, because you will get a fatal error:
>
> ```swift
> // Fatal error: A TableAlias most not be used to refer to multiple tables
> let alias = TableAlias()
> let books = Book.aliased(alias)...
> let people = Person.aliased(alias)...
> ```
>
> :point_up: **Note**: you can't use the `including(all:)` method and use table aliases to filter the associated records on other records:
> 
> ```swift
> // NOT IMPLEMENTED: loading all authors along with their posthumous books
> let authorAlias = TableAlias()
> let request = Author
>     .aliased(authorAlias)
>     .including(all: Author.books
>         .filter(Column("publishDate") >= authorAlias[Column("deathDate")]))    
> ```


## Refining Association Requests

When you join or include an association several times, with the same **[association key](#the-structure-of-a-joined-request)**, GRDB will apply the following rules:

- `including` wins over `joining`:

    ```swift
    // Equivalent to Record.including(optional: association)
    Record
        .including(optional: association)
        .joining(optional: association)
    ```

- `required` wins over `optional`:

    ```swift
    // Equivalent to Record.including(required: association)
    Record
        .including(required: association)
        .including(optional: association)
    ```

- All [filters](#filtering-associations) are applied:

    ```swift
    // Equivalent to Record.including(required: association.filter(condition1 && condition2))
    Record
        .including(required: association.filter(condition1))
        .including(optional: association.filter(condition1))
    ```

- The last [ordering](#sorting-associations) wins:

    ```swift
    // Equivalent to Record.including(required: association.order(ordering2))
    Record
        .including(required: association.order(ordering1))
        .including(optional: association.order(ordering2))
    ```

- The last [selection](#columns-selected-by-an-association) wins:

    ```swift
    // Equivalent to Record.including(required: association.select(selection2))
    Record
        .including(required: association.select(selection1))
        .including(optional: association.select(selection2))
    ```

**Those rules exist so that you can design fluent interfaces that build complex requests out of simple building blocks.**

For example, we can start by defining base requests as extensions to the [DerivableRequest Protocol]:

```swift
// Author requests
extension DerivableRequest where RowDecoder == Author {
    /// Filters authors by country
    func filter(country: String) -> Self {
        filter(Column("country") == country)
    }
}

// Book requests
extension DerivableRequest where RowDecoder == Book {
    /// Filters books by author country
    func filter(authorCountry: String) -> Self {
        joining(required: Book.author.filter(country: country))
    }
    
    /// Order books by author name and then book title
    func orderedByAuthorNameAndYear() -> Self {
        let authorAlias = TableAlias()
        return self
            .joining(optional: Book.author.aliased(authorAlias))
            .order(
                authorAlias[Column("name")].collating(.localizedCaseInsensitiveCompare),
                Column("year"))
    }
}
```

And then compose those in a fluent style:

```swift
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var author: Author
}

// SELECT book.*, author.*
// FROM book
// JOIN author ON author.id = book.authorId AND author.country = 'FR'
// ORDER BY author.name COLLATE ..., book.year
let bookInfos = try Book.all()
    .filter(authorCountry: "FR")
    .orderedByAuthorNameAndYear()
    .including(required: Book.author)
    .asRequest(of: BookInfo.self)
    .fetchAll(db)
```

Remember that those refinement rules only apply when an association is joined or included several times, with the same **[association key](#the-structure-of-a-joined-request)**. Changing this key stops merging associations together. See [Isolation of Multiple Aggregates] for a longer discussion.


Fetching Values from Associations
=================================

We have seen in [Joining And Prefetching Associated Records] how to define requests that involve several records.

To consume those requests, you will generally define a record type that matches the structure of the request. You'll make it adopt the [FetchableRecord] protocol, so that it can decode database rows.

Often, you'll also make it adopt the standard Decodable protocol, because the compiler will generate the decoding code for you.

Each association included in the request can feed a property of the decoded record:

- `including(optional:)` feeds an optional property:

    ```swift
    let request = Employee.including(optional: Employee.manager)
    
    struct EmployeeInfo: FetchableRecord, Decodable {
        var employee: Employee
        var manager: Employee? // the optional associated manager
    }
    let employeeInfos: [EmployeeInfo] = try EmployeeInfo.fetchAll(db, request)
    ```

- `including(required:)` feeds an non-optional property:

    ```swift
    let request = Book.including(required: Book.author)
    
    struct BookInfo: FetchableRecord, Decodable {
        var book: Book
        var author: Author // the required associated author
    }
    
    let bookInfos: [BookInfo] = try BookInfo.fetchAll(db, request)
    ```

- `including(all:)` feeds an Array or Set property:

    ```swift
    let request = Author.including(all: Author.books)
    
    struct AuthorInfo: FetchableRecord, Decodable {
        var author: Author
        var books: [Book] // all associated books
    }
    let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)
    ```

- [The Structure of a Joined Request]
- [Decoding a Joined Request with a Decodable Record]
- [Decoding a Joined Request with FetchableRecord]
- [Debugging Request Decoding]
- [Good Practices for Designing Record Types] - in this general guide about records, check out the "Compose Records" chapter.


## The Structure of a Joined Request

**Joined request defines a tree of associated records identified by "association keys".**

Below, author and cover image are both associated to book, and country is associated to author:

```swift
let request = Book
    .including(required: Book.author
        .including(optional: Author.country))
    .including(optional: Book.coverImage)
```

This request builds the following **tree of association keys**:

![TreeOfAssociationKeys](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/TreeOfAssociationKeys.svg)

Requests can feed record types whose property names match those association keys:

```swift
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var author: Author
    var country: Country?
    var coverImage: CoverImage?
}

let bookInfos: [BookInfo] = try BookInfo.fetchAll(db, request)
```

By default, **association keys** are the names of the database tables of associated records. Keys are automatically [singularized or pluralized](#convention-for-database-table-names), depending of the cardinality of the included association:

```swift
extension Author {
    static let books = hasMany(Book.self)
}
Author.including(all: Author.books)            // association key "books"

extension Book {
    static let author = belongsTo(Author.self)
}
Book.including(required: Book.author)          // association key "author"
```

Keys can be customized when the association is defined:

```swift
extension Employee {
    static let manager = belongsTo(Employee.self, key: "manager")
}
Employee.including(optional: Employee.manager) // association key "manager"
```

Keys can also be customized with the `forKey` method:

```swift
extension Author {
    static let novels = books
        .filter(Column("kind") == "novel")
        .forKey("novels")
}
Author.including(all: Author.novels)           // association key "novels"
```


## Decoding a Joined Request with a Decodable Record

When **association keys** match the property names of a Decodable record, you get free decoding of joined requests into this record:

```swift
let request = Book
    .including(required: Book.author
        .including(optional: Author.country))
    .including(optional: Book.coverImage)

struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var author: Author
    var country: Country?
    var coverImage: CoverImage?
}
let bookInfos: [BookInfo] = try BookInfo.fetchAll(db, request)
```

We see that a hierarchical tree has been flattened in the `BookInfo` record.

But sometimes your decoded records will have better reflect the hierarchical structure of the request:


### Decoding a Hierarchical Decodable Record

Some requests are better decoded with a Decodable record that reflects the hierarchical structure of the request.

```swift
let request = Book
    .including(optional: Book.coverImage)
    .including(required: Book.author
        .including(optional: Person.country))
    .including(optional: Book.translator
        .including(optional: Person.country))
```

This requests for all books, with their cover images, and their authors and translators. Those people are themselves decorated with their respective nationalities.

We plan to decode this request into is the following nested record:

```swift
struct BookInfo: FetchableRecord, Decodable {
    struct PersonInfo: Decodable {
        var person: Person
        var country: Country?
    }
    var book: Book
    var authorInfo: PersonInfo
    var translatorInfo: PersonInfo?
    var coverImage: CoverImage?
}
```

This request needs a little preparation: we need **association keys** that match the **coding keys** for the authorInfo and translatorInfo properties.

And who is the most able to know those coding keys? BookInfo itself, thanks to its `CodingKeys` enum that was automatically generated by the Swift compiler. We thus define the `BookInfo.all()` method that builds our request:

```swift
extension BookInfo {
    static func all() -> QueryInterfaceRequest<BookInfo> {
        Book.including(optional: Book.coverImage)
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


## Decoding a Joined Request with FetchableRecord

When [Decodable](#decoding-a-joined-request-with-a-decodable-record) records provides convenient decoding of joined rows, you may want a little more control over row decoding.

The `init(row:)` initializer of the [FetchableRecord] protocol is what you look after:

```swift
let request = Book
    .including(required: Book.author
        .including(optional: Author.country))
    .including(optional: Book.coverImage)

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

let bookInfos: [BookInfo] = try BookInfo.fetchAll(db, request)
```

You are already familiar with row subscripts to decode [database values](../README.md#column-values):

```swift
let name: String = row["name"]
```

When you extract a record instead of a value from a row, GRDB looks up the tree of **association keys**. If the key is not found, or only associated with columns that all contain NULL values, an optional record is decoded as nil:

```swift
let author: Author = row["author"]
let country: Country? = row["country"]
```

You can also perform custom navigation in the tree by using *row scopes*. See [Row Adapters] for more information.

When you use the `include(all:)` method, you can decode an Array or a Set of records:

```swift
let request = Author.including(all: Author.books)

struct AuthorInfo: FetchableRecord {
    var author: Author
    var books: [Book]
    
    init(row: Row) {
        author = Author(row: row)
        books = row["books"]
    }
}

let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)
```


## Debugging Request Decoding

When you have difficulties building a Decodable record that successfully decodes a joined request, we advise to temporarily decode raw database rows, and inspect them.

```swift
let request = Book
    .including(required: Book.author
        .including(optional: Author.country))
    .including(optional: Book.coverImage)
    .including(all: Book.prizes)

let rows = try Row.fetchAll(db, request)
print(rows[0].debugDescription)
// Prints:
// ▿ [id:1, authorId:2, title:"Moby-Dick"]
//   unadapted: [id:1, authorId:2, title:"Moby-Dick", id:2, name:"Herman Melville", countryCode:"US", code:"US", name:"United States of America", id:NULL, imageId:NULL, path:NULL]
//   - author: [id:2, name:"Herman Melville", countryCode:"US"]
//     - country: [code:"US", name:"United States of America"]
//   - coverImage: [id:NULL, imageId:NULL, path:NULL]
//   + prizes: 3 rows
```

Watch in the row debugging description:

- the **association keys**: "person", "country", "coverImage" and "prizes" in our example
- associated rows that contain only null values ("coverImage", above).

The associated rows that contain only null values are easy to deal with: null rows loaded from optional associated records should be decoded into Swift optionals:

```swift
struct BookInfo: FetchableRecord, Decodable {
    var book: Book
    var author: Author          // .including(required: Book.author)
    var country: Country?       // .including(optional: Author.country)
    var coverImage: CoverImage? // .including(optional: Book.coverImage)
    var prizes: [Prize]         // .including(all: Book.prizes)
}
```

When the **association keys** don't match your expectations, change them (see [The Structure of a Joined Request]):

```swift
let request = Book
    .including(optional: Book.author.forKey("writer")) // customized association key

let rows = try Row.fetchAll(db, request)
print(rows[0].debugDescription)
// Prints:
// ▿ [id:1, authorId:2, title:"Moby-Dick"]
//   unadapted: [id:1, authorId:2, title:"Moby-Dick", id:2, name:"Herman Melville"]
//   - writer: [id:2, name:"Herman Melville", countryCode:"US"]
```


## Association Aggregates

It is possible to fetch aggregated values from **[HasMany]** and **[HasManyThrough]** associations:

Counting associated records, fetching the minimum, maximum, average value of an associated record column, computing the sum of an associated record column, these are all aggregation operations.

When you need to compute aggregates **from a single record**, you use [regular aggregating methods] on [requests for associated records]. For example:

```swift
struct Author: TableRecord, EncodableRecord {
    static let books = hasMany(Book.self)
    var books: QueryInterfaceRequest<Book> {
        request(for: Author.books)
    }
}

let author: Author = ...

// The number of books by this author
let bookCount = try author.books.fetchCount(db)  // Int

// The year of the most recent book by this author
let request = author.books.select(max(yearColumn))
let maxBookYear = try Int.fetchOne(db, request)  // Int?
```

When you need to compute aggregates **from several record**, in a single shot, you'll use an **association aggregate**. Those are the topic of this chapter.

For example, you'll use the `isEmpty` aggregate when you want, say, to fetch all authors who wrote no book at all, or some books:

```swift
let lazyAuthors = try Author
    .having(Author.books.isEmpty)
    .fetchAll(db) // [Author]

let productiveAuthors: [Author] = try Author
    .having(Author.books.isEmpty == false)
    .fetchAll(db) // [Author]
```

And you'll use the `count` aggregate in order to fetch all authors along with the number of books they wrote:

```swift
struct AuthorInfo: Decodable, FetchableRecord {
    var author: Author
    var bookCount: Int
}

let request = Author.annotated(with: Author.books.count)
let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)

for info in authorInfos {
    print("\(info.author.name) wrote \(info.bookCount) book(s).")
}
```


### Available Association Aggregates

**[HasMany]** and **[HasManyThrough]** associations let you build the following association aggregates:

- `books.count`
- `books.isEmpty`
- `books.min(column)`
- `books.max(column)`
- `books.average(column)`
- `books.sum(column)`


### Annotating a Request with Aggregates

The `annotated(with:)` method appends aggregated values to the selected columns of a request. You can append as many aggregates values as needed, from one or several associations.

In order to access those values, you fetch records that have matching properties.

For example:

```swift
struct AuthorInfo: Decodable, FetchableRecord {
    var author: Author
    var bookCount: Int
    var maxBookYear: Int?
}

// SELECT author.*,
//        COUNT(DISTINCT book.id) AS bookCount,
//        MAX(book.year) AS maxBookYear,
// FROM author
// LEFT JOIN book ON book.authorId = author.id
// GROUP BY author.id
let request = Author.annotated(with:
    Author.books.count,
    Author.books.max(Column("year")))

let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)

for info in authorInfos {
    print(info.author.name)
    print("- number of books: \(info.bookCount)")
    print("- last book published on: \(info.maxBookYear)")
}
```

As seen in the above example, aggregated values are given a **default name**, such as "bookCount" or "maxBookYear", which directly feeds the decoded records.

The default name is built from the aggregating method, the **[association key](#the-structure-of-a-joined-request)**, and the aggregated column name:

| Method | Association Key | Aggregated Column | Aggregate name |
| ------ | --------------- | ----------------- | -------------- |
| `Author.books.isEmpty`.                 | `books` | -        | `hasNoBook`        |
| `Author.books.count`.                   | `books` | -        | `bookCount`        |
| `Author.books.min(Column("year"))`      | `books` | `year`   | `minBookYear`      |
| `Author.books.max(Column("year"))`      | `books` | `year`   | `maxBookYear`      |
| `Author.books.average(Column("price"))` | `books` | `price`  | `averageBookPrice` |
| `Author.books.sum(Column("awards"))`    | `books` | `awards` | `bookAwardsSum`    |

Those default names are lost whenever an aggregate is modified (negated, added, multiplied, whatever).

You can name or rename aggregates with the `forKey` method:

```swift
struct AuthorInfo: Decodable, FetchableRecord {
    var author: Author
    var numberOfBooks: Int
}
let numberOfBooks = Author.books.count.forKey("numberOfBooks")                    // <--
let request = Author.annotated(with: numberOfBooks)
let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)

struct AuthorInfo: Decodable, FetchableRecord {
    var author: Author
    var hasBooks: Bool
}
let hasBooks = (Author.books.isEmpty == false).forKey("hasBooks")                 // <--
let request = Author.annotated(with: hasBooks)
let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)

struct AuthorInfo: Decodable, FetchableRecord {
    var author: Author
    var workCount: Int
}
let workCount = (Author.books.count + Author.paintings.count).forKey("workCount") // <--
let request = Author.annotated(with: workCount)
let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)
```

Coding keys are also accepted:

```swift
struct AuthorInfo: Decodable, FetchableRecord {
    var author: Author
    var numberOfBooks: Int
    
    static func all() -> QueryInterfaceRequest<AuthorInfo> {
        let numberOfBooks = Author.books.count.forKey(CodingKey.numberOfBooks)    // <--
        return Author
            .annotated(with: numberOfBooks)
            .asRequest(of: AuthorInfo.self)
    }
}
let authorInfos: [AuthorInfo] = try AuthorInfo.all().fetchAll(db)
```


### Filtering a Request with Aggregates

The `having(_:)` method filters a request according to an aggregated value. You can append as many aggregate conditions as needed, from one or several associations.

- Authors who did not write any book:

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    GROUP BY author.id
    HAVING COUNT(DISTINCT book.id) = 0
    ```
    
    </details>
    
    ```swift
    let request = Author.having(Author.books.isEmpty)
    ```

- Authors who wrote at least one book:

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    GROUP BY author.id
    HAVING COUNT(DISTINCT book.id) > 0
    ```
    
    </details>
    
    ```swift
    let request = Author.having(Author.books.isEmpty == false)
    ```

- Authors who wrote at least two books:

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    GROUP BY author.id
    HAVING COUNT(DISTINCT book.id) >= 2
    ```
    
    </details>
    
    ```swift
    let request = Author.having(Author.books.count >= 2)
    ```

- Authors who wrote at least one book after 2010:

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    GROUP BY author.id
    HAVING MAX(book.year) >= 2010
    ```
    
    </details>
    
    ```swift
    let request = Author.having(Author.books.max(Column("year")) >= 2010)
    ```

- Authors who wrote at least one book of kind "novel":

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*
    FROM author
    LEFT JOIN book ON book.authorId = author.id AND book.kind = 'novel'
    GROUP BY author.id
    HAVING COUNT(DISTINCT book.id) > 0
    ```
    
    </details>
    
    ```swift
    let novels = Author.books.filter(Column("kind") == "novel")
    let request = Author.having(novels.isEmpty == false)
    ```
    
- Authors who wrote more books than they made paintings:

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    LEFT JOIN painting ON painting.authorId = author.id
    GROUP BY author.id
    HAVING COUNT(DISTINCT book.id) > COUNT(DISTINCT painting.id)
    ```
    
    </details>
    
    ```swift
    let request = Author.having(Author.books.count > Author.paintings.count)
    ```

- Authors who wrote no book, but made at least one painting:

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    LEFT JOIN painting ON painting.authorId = author.id
    GROUP BY author.id
    HAVING ((COUNT(DISTINCT book.id) = 0) AND (COUNT(DISTINCT painting.id) > 0))
    ```
    
    </details>
    
    ```swift
    let request = Author.having(Author.books.isEmpty && !Author.paintings.isEmpty)
    ```


### Aggregate Operations

Aggregates can be modified and combined with Swift operators:

- Logical operators `&&`, `||` and `!`
    
    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    LEFT JOIN painting ON painting.authorId = author.id
    GROUP BY author.id
    HAVING ((COUNT(DISTINCT book.id) = 0) AND (COUNT(DISTINCT painting.id) = 0))
    ```
    
    </details>
    
    ```swift
    let condition = Author.books.isEmpty && Author.paintings.isEmpty
    let request = Author.having(condition)
    ```

- Comparison operators `<`, `<=`, `=`, `!=`, `>=`, `>`

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    GROUP BY author.id
    HAVING MAX(book.year) >= 2010
    ```
    
    </details>
    
    ```swift
    let request = Author.having(Author.books.max(Column("year")) >= 2010)
    ```

- Arithmetic operators `+`, `-`, `*`, `/`

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*,
           (COUNT(DISTINCT book.id) +
            COUNT(DISTINCT painting.id)) AS workCount
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    LEFT JOIN painting ON painting.authorId = author.id
    GROUP BY author.id
    ```
    
    </details>
    
    ```swift
    let workCount = Author.books.count + Author.paintings.count)
    let request = Author.annotated(with: workCount.forKey("workCount"))
    ```

- IFNULL operator `??`

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT "team".*, IFNULL(MIN("player"."score"), 0) AS "minPlayerScore"
    FROM "team"
    LEFT JOIN "player" ON ("player"."teamId" = "team"."id")
    GROUP BY "team"."id"
    ```
    
    </details>
    
    ```swift
    let request = Team.annotated(with: Team.players.min(Column("score")) ?? 0)
    ```

    
### Isolation of Multiple Aggregates

When you compute multiple aggregates, make sure they use as many distinct **[association keys](#the-structure-of-a-joined-request)** as there are distinct populations of associated records.

In the example below, we use compute two aggregates from the same association `Author.books`. Both aggregates are computed on the same population of associated records, and so we want them to share the same association key:

- Authors with the publishing year of their first and last book:

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*,
           MIN(book.year) AS minBookYear,
           MAX(book.year) AS maxBookYea
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    GROUP BY author.id
    ```
    
    </details>
    
    ```swift
    struct Author: TableRecord {
        static let books = hasMany(Book.self) // association key "books"
    }
    
    struct AuthorInfo: Decodable, FetchableRecord {
        var author: Author
        var minBookYear: Int?
        var maxBookYear: Int?
    }
    
    let request = Author.annotated(with:
        Author.books.min(Column("year")), // association key "books"
        Author.books.max(Column("year"))) // association key "books"
    let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)
    ```

In this other example, the `Author.books` and `Author.paintings` have the distinct `book` and `painting` keys. They don't interfere, and provide the expected results:

- Authors with their number of books and paintings:

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*,
           (COUNT(DISTINCT book.id) + COUNT(DISTINCT painting.id)) AS workCount
    FROM author
    LEFT JOIN book ON book.authorId = author.id
    LEFT JOIN painting ON painting.authorId = author.id
    GROUP BY author.id
    ```
    
    </details>
    
    ```swift
    struct Author: TableRecord {
        static let books = hasMany(Book.self)         // association key "books"
        static let paintings = hasMany(Painting.self) // association key "paintings"
    }
    
    struct AuthorInfo: Decodable, FetchableRecord {
        var author: Author
        var workCount: Int
    }
    
    let aggregate = Author.books.count +   // association key "books"
                    Author.paintings.count // association key "paintings"
    let request = Author.annotated(with: aggregate.forKey("workCount"))
    let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)
    ```

But in the following example, we use the same association `Author.books` twice, in order to compute aggregates on two distinct populations of associated books. We must provide explicit keys in order to make sure both aggregates are computed independently:

- Authors with their number of novels and theatre plays:

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*,
           COUNT(DISTINCT book1.id) AS novelCount,
           COUNT(DISTINCT book2.id) AS theatrePlayCount
    FROM author
    LEFT JOIN book book1 ON book1.authorId = author.id AND book1.kind = 'novel'
    LEFT JOIN book book2 ON book2.authorId = author.id AND book2.kind = 'theatrePlay'
    GROUP BY author.id
    ```
    
    </details>
    
    ```swift
    struct Author: TableRecord {
        static let books = hasMany(Book.self) // association key "books"
    }
    
    struct AuthorInfo: Decodable, FetchableRecord {
        var author: Author
        var novelCount: Int
        var theatrePlayCount: Int
    }
    
    let novelCount = Author.books
        .filter(Column("kind") == "novel")
        .forKey("novels")                        // association key "novels"
        .count
    let theatrePlayCount = Author.books
        .filter(Column("kind") == "theatrePlay")
        .forKey("theatrePlays")                  // association key "theatrePlays"
        .count
    let request = Author.annotated(with: novelCount, theatrePlayCount)
    let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)
    ```
    
    When one doesn't use distinct association keys for novels and theatre plays, GRDB will not count two distinct sets of associated books, and will not fetch the expected results:

    <details>
        <summary>SQL</summary>
    
    ```sql
    SELECT author.*,
           COUNT(DISTINCT book.id) AS novelCount,
           COUNT(DISTINCT book.id) AS theatrePlayCount
    FROM author
    LEFT JOIN book ON book.authorId = author.id
          AND (book.kind = 'novel' AND book.kind = 'theatrePlay')
    GROUP BY author.id
    ```
    
    </details>
    
    ```swift
    // WRONG: not counting distinct sets of associated books
    let novelCount = Author.books                // association key "books"
        .filter(Column("kind") == "novel")
        .count
        .forKey("novelCount")
    let theatrePlayCount = Author.books          // association key "books"
        .filter(Column("kind") == "theatrePlay")
        .count
        .forKey("theatrePlayCount")
    let request = Author.annotated(with: novelCount, theatrePlayCount)
    let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)
    ```


## DerivableRequest Protocol

The `DerivableRequest` protocol is adopted by both [query interface requests] such as `Author.all()` and associations such as `Book.author`. It is intended for you to use as a customization point when you want to extend the built-in GRDB apis.

For example, we may want to define `orderedByName()` and `filter(country:)` request methods that make our requests easier to read:

```swift
// Authors sorted by name
let request = Author.all().orderedByName()

// French authors ordered by name
let request = Author.all().filter(country: "FR").orderedByName()

// Spanish books
let request = Book.all().filter(country: "ES")
```

Those methods are defined on extensions to the `DerivableRequest` protocol:

```swift
extension DerivableRequest where RowDecoder == Author {
    func filter(country: String) -> Self {
        filter(Column("country") == country)
    }
    
    func orderedByName() -> Self {
        order(Column("name").collating(.localizedCaseInsensitiveCompare))
    }
}

extension DerivableRequest where RowDecoder == Book {
    func filter(country: String) -> Self {
        joining(required: Book.author.filter(country: country))
    }
}
```

See [Good Practices for Designing Record Types] for more information.


## Known Issues

- **You can't chain a required association on an optional association:**

    ```swift
    // NOT IMPLEMENTED
    let request = Book
        .joining(optional: Book.author
            .including(required: Person.country))
    ```

    This code compiles, but you'll get a runtime fatal error "Not implemented: chaining a required association behind an optional association". Future versions of GRDB may allow such requests.

- **You can't use the `including(all:)` method and use table aliases to filter the associated records on other records:**

    ```swift
    // NOT IMPLEMENTED: loading all authors along with their posthumous books
    let authorAlias = TableAlias()
    let request = Author
        .aliased(authorAlias)
        .including(all: Author.books
            .filter(Column("publishDate") >= authorAlias[Column("deathDate")]))    
    ```

- **You can't use the `including(all:)` method with a [HasMany] and a [HasManyThrough] associations that share the same base association in the same request**:

    ```swift
    // NOT IMPLEMENTED
    let request = Country
        .including(all: Country.passports)
        .including(all: Country.citizens)
    ```

    This code compiles, but you'll get a runtime fatal error "Not implemented: merging a direct association and an indirect one with including(all:)". Future versions of GRDB may allow such requests.

    The workaround is to nest the most remote association:

    ```swift
    // Workaround
    let request = Country
        .including(all: Country.passports
            .including(required: Passport.citizen))
    ```
    
- **The `including(all:)` method may fail with a database error of code [`SQLITE_ERROR`](https://www.sqlite.org/rescode.html#error) (1) "Expression tree is too large" when you use a compound foreign key and there are a lot of parent records.**

    See [Joining And Prefetching Associated Records] for more information about this error.

Come [discuss](http://twitter.com/groue) for more information, or if you wish to help turning those missing features into reality.

---

This documentation owns a lot to the [Active Record Associations](http://guides.rubyonrails.org/association_basics.html) guide, which is an immensely well-written introduction to database relations. Many thanks to the Rails team and contributors.

---

### LICENSE

**GRDB**

Copyright (C) 2015-2020 Gwendal Roué

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
[Required Protocols]: #required-protocols
[BelongsTo]: #belongsto
[HasMany]: #hasmany
[HasOne]: #hasone
[HasManyThrough]: #hasmanythrough
[HasOneThrough]: #hasonethrough
[Choosing Between BelongsTo and HasOne]: #choosing-between-belongsto-and-hasone
[Self Joins]: #self-joins
[Ordered Associations]: #ordered-associations
[The Types of Associations]: #the-types-of-associations
[FetchableRecord]: ../README.md#fetchablerecord-protocols
[migration]: Migrations.md
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
[requests for associated records]: #requesting-associated-records
[Joining And Prefetching Associated Records]: #joining-and-prefetching-associated-records
[Filtering Associations]: #filtering-associations
[Sorting Associations]: #sorting-associations
[Columns Selected by an Association]: #columns-selected-by-an-association
[Table Aliases]: #table-aliases
[Refining Association Requests]: #refining-association-requests
[The Structure of a Joined Request]: #the-structure-of-a-joined-request
[Decoding a Joined Request with a Decodable Record]: #decoding-a-joined-request-with-a-decodable-record
[Decoding a Hierarchical Decodable Record]: #decoding-a-hierarchical-decodable-record
[Decoding a Joined Request with FetchableRecord]: #decoding-a-joined-request-with-fetchablerecord
[Debugging Request Decoding]: #debugging-request-decoding
[Custom Requests]: ../README.md#custom-requests
[Association Aggregates]: #association-aggregates
[Available Association Aggregates]: #available-association-aggregates
[Annotating a Request with Aggregates]: #annotating-a-request-with-aggregates
[Filtering a Request with Aggregates]: #filtering-a-request-with-aggregates
[Aggregate Operations]: #aggregate-operations
[Isolation of Multiple Aggregates]: #isolation-of-multiple-aggregates
[DerivableRequest Protocol]: #derivablerequest-protocol
[Known Issues]: #known-issues
[Row Adapters]: ../README.md#row-adapters
[query interface requests]: ../README.md#requests
[TableRecord]: ../README.md#tablerecord-protocol
[Good Practices for Designing Record Types]: GoodPracticesForDesigningRecordTypes.md
[regular aggregating methods]: ../README.md#fetching-aggregated-values
[Record class]: ../README.md#record-class
[EncodableRecord]: ../README.md#persistablerecord-protocol
[PersistableRecord]: ../README.md#persistablerecord-protocol
[Codable Records]: ../README.md#codable-records
[persistence methods]: ../README.md#persistence-methods
[database observation tools]: ../README.md#database-changes-observation
[ValueObservation]: ../README.md#valueobservation
[FAQ]: ../README.md#faq-associations
