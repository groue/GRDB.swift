//: To run this playground:
//:
//: - Open GRDB.xcworkspace
//: - Select the GRDBOSX scheme: menu Product > Scheme > GRDBOSX
//: - Build: menu Product > Build
//: - Select the playground in the Playgrounds Group
//: - Run the playground

import GRDB

//: Open a database connection

var configuration = Configuration()
configuration.prepareDatabase { db in
    db.trace { print("SQL> \($0)") }
}
let dbQueue = try DatabaseQueue(configuration: configuration)

//: Use a migrator to define the database schema

var migrator = DatabaseMigrator()

migrator.registerMigration("createLibrary") { db in
    try db.create(table: "author") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
    }
    
    try db.create(table: "book") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("title", .text).notNull()
        t.column("authorId", .integer)
            .notNull()
            .indexed()
            .references("author", onDelete: .cascade)
    }
}

try migrator.migrate(dbQueue)

//: Define Record types

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

//: Define Associations

extension Author {
    static let books = hasMany(Book.self)
    var books: QueryInterfaceRequest<Book> { request(for: Author.books) }
}

extension Book {
    static let author = belongsTo(Author.self)
    var author: QueryInterfaceRequest<Author> { request(for: Book.author) }
}

//: Populate the database

print("----------")
print("Populate the database")
try dbQueue.write { db in
    var melville = Author(id: nil, name: "Hermann Melville")
    try melville.insert(db)
    var mobyDick = Book(id: nil, authorId: melville.id!, title: "Moby-Dick")
    try mobyDick.insert(db)

    var genet = Author(id: nil, name: "Jean Genet")
    try genet.insert(db)
    var querelle = Book(id: nil, authorId: genet.id!, title: "Querelle de Brest")
    try querelle.insert(db)
    var lesBonnes = Book(id: nil, authorId: genet.id!, title: "Les Bonnes")
    try lesBonnes.insert(db)
}

//: Fetch author information

print("----------")
print("Fetch author information")
struct AuthorInfo {
    var author: Author
    var books: [Book]
}
let authorId = 2
let authorInfo: AuthorInfo? = try dbQueue.read { db in
    guard let author = try Author.fetchOne(db, key: authorId) else { return nil }
    let books = try author.books.fetchAll(db)
    return AuthorInfo(author: author, books: books)
}
if let authorInfo = authorInfo {
    print("\(authorInfo.author.name) has written:")
    for book in authorInfo.books {
        print("- \(book.title)")
    }
}


//: Fetch book information

print("----------")
print("Fetch book information")
struct BookInfo: FetchableRecord, Codable {
    var book: Book
    var author: Author
}
let bookId = 1
let bookInfo: BookInfo? = try dbQueue.read { db in
    let request = Book
        .filter(key: bookId)
        .including(required: Book.author)
    return try BookInfo.fetchOne(db, request)
}
if let bookInfo = bookInfo {
    print("\(bookInfo.book.title) was written by \(bookInfo.author.name)")
}

//: Fetch all authorships

print("----------")
print("Fetch all authorships")
struct Authorship: Decodable, FetchableRecord {
    var book: Book
    var author: Author
}
let authorships: [Authorship] = try dbQueue.read { db in
    let request = Book.including(required: Book.author)
    return try Authorship.fetchAll(db, request)
}
for authorship in authorships {
    print("\(authorship.book.title) was written by \(authorship.author.name)")
}
