GRDB Associations, In Depth
===========================

This guide digs deeper in the topic of [associations](AssociationsBasics.md) between record types.

It is organized in small focused chapters, without particular order. If your question is not answered here, please open an [issue](https://github.com/groue/GRDB.swift/issues/new) explaining which topic should be enhanced, or added to this document.

- [Columns are scoped]

### Columns are scoped

Whenever you refine a request with column-based expressions with methods such as `select`, `filter`, `order`, those columns are scoped to the table at the origin of the request.

To illustrate this, let's consider the following record definitions:

```swift
struct Book: Decodable, FetchableRecord, TableRecord {
    static let author = belongsTo(Author.self)
}
struct Author: Decodable, FetchableRecord, TableRecord {
    static let books = hasMany(Book.self)
}
```

In a request of books, all columns are book columns (as expected):

```swift
let request = Book                    // origin table: book
    .filter(Column("kind") = "novel") // "kind" column of the book table

// SELECT * FROM book WHERE kind = 'novel'
let books = try request.fetchAll(db)
```

When you extend this request with an association, the "kind" column is still unambiguously a book column:

```swift
let request2 = request.including(required: Book.author)

// SELECT book.*, author.*
// FROM book
// JOIN author ON author.id = book.authorId
// WHERE book.kind = 'novel'
struct BookInfo: Decodable, FetchableRecord {
    var book: Book
    var author: Author
}
let bookInfos = try BookInfo.fetchAll(db, request2)
```

And when you refine an association, all columns are scoped to the associated table:

```swift
let frenchAuthor = Book.author             // origin table: author
    .filter(Column("country") == "France") // "country" column of the author table
let request3 = request.including(required: frenchAuthor)

// SELECT book.*, author.*
// FROM book
// JOIN author ON author.id = book.authorId
//            AND author.country = 'France'
// WHERE book.kind = 'novel'
let bookInfos = try BookInfo.fetchAll(db, request3)
```

The only way to escape this implicit column scoping is table aliases:

```swift
let alias = TableAlias()
let request4 = Book
    .select(
        Column("title"),                           // implicit book column
        Column("year"),                            // implicit book column
        alias[Column("country")])                  // explicit author column
    .joining(required: Book.author.aliased(alias)) // attach the alias to the author table

// SELECT book.title, book.year, author.country
// FROM book
// JOIN author ON author.id = book.authorId
struct Release: Decodable, FetchableRecord {
    var title: String
    var year: String
    var country: String
}
let releases = try Release.fetchAll(db, request4)
```

Column scoping makes it possible to define extensions to DerivableRequest. Columns are always attached to the correct table:

```swift
extension DerivableRequest where RowDecoder == Book {
    func filter(kind: String) -> Self {
        filter(Column("kind") == kind) // implicit book column
    }
}

extension DerivableRequest where RowDecoder == Author {
    func filter(country: String) -> Self {
        filter(Column("country") == country) // implicit author column
    }
}

// SELECT * FROM book WHERE kind = 'novel'
Book.all().filter(kind: "novel")

// SELECT * FROM author WHERE country = 'France'
Author.all().filter(country: "France")

// SELECT book.*
// FROM book
// JOIN author ON author.id = book.authorId
//            AND author.country = 'France'
// WHERE book.kind = 'novel'
Book
    .filter(kind: "novel")
    .joining(required: Book.author.filter(country: "France"))

// SELECT author.* WHERE country = 'France'
// SELECT * FROM book WHERE authorId IN (1, 2, 3) AND kind = 'novel'
Author
    .filter(country: "France")
    .including(all: Author.books.filter(kind: "novel"))
```

[Columns are scoped]: #columns-are-scoped
