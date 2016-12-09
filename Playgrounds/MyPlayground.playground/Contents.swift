// To run this playground, select and build the GRDBOSX scheme.

import GRDB


var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)

struct Book: RowConvertible, TableMapping {
    static let databaseTableName = "books"
    let title: String
    init(row: Row) {
        title = row.value(named: "title")
    }
}

struct Author: RowConvertible, TableMapping {
    static let databaseTableName = "authors"
    let name: String
    init(row: Row) {
        name = row.value(named: "name")
    }
}

extension Author {
    static func myCustomRequest() -> AnyTypedRequest<Author> {
        // Some custom SQL
        let sqlRequest = SQLRequest("SELECT * FROM authors")
        return sqlRequest.bound(to: Author.self)
    }
}


struct BookAuthorPair : RowConvertible {
    let book: Book
    let author: Author
    
    init(row: Row) {
        book = Book(row: row.scoped(on: "book")!)
        author = Author(row: row.scoped(on: "author")!)
    }
    
    static func all() -> AnyTypedRequest<BookAuthorPair> {
        return AnyTypedRequest { db in
            let sql = "SELECT books.*, authors.* " +
                "FROM books " +
            "JOIN authors ON authors.id = books.authorID"
            let adapter = try ScopeAdapter([
                "book": SuffixRowAdapter(fromIndex: 0),
                "author": SuffixRowAdapter(fromIndex: db.columnCount(in: "books"))])
            let statement = try db.makeSelectStatement(sql)
            return (statement, adapter)
        }
    }
}

struct JoinPair<Left: RowConvertible, Right: RowConvertible> : RowConvertible {
    let left: Left
    let right: Right
    
    init(row: Row) {
        left = Left(row: row.scoped(on: "left")!)
        right = Right(row: row.scoped(on: "right")!)
    }
    
    static func all(leftTable: String, rightTable: String) -> AnyTypedRequest<JoinPair<Left, Right>> {
        return AnyTypedRequest { db in
            let left = leftTable.quotedDatabaseIdentifier
            let right = rightTable.quotedDatabaseIdentifier
            let sql = "SELECT \(left).*, \(right).* " +
                "FROM \(left) " +
            "JOIN \(right) ON \(right).id = \(left).authorID"
            let adapter = try ScopeAdapter([
                "left": SuffixRowAdapter(fromIndex: 0),
                "right": SuffixRowAdapter(fromIndex: db.columnCount(in: leftTable))])
            let statement = try db.makeSelectStatement(sql)
            return (statement, adapter)
        }
    }
}

extension JoinPair where Left: TableMapping, Right: TableMapping {
    static func all() -> AnyTypedRequest<JoinPair<Left, Right>> {
        return all(leftTable: Left.databaseTableName, rightTable: Right.databaseTableName)
    }
    
}

try! dbQueue.inDatabase { db in
    
    try db.create(table: "authors") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text)
    }
    
    try db.create(table: "books") { t in
        t.column("id", .integer).primaryKey()
        t.column("authorID", .integer).notNull().references("authors")
        t.column("title", .text)
    }
    
    try db.execute("INSERT INTO authors (id, name) VALUES (?, ?)", arguments: [1, "Foo"])
    try db.execute("INSERT INTO authors (id, name) VALUES (?, ?)", arguments: [2, "Bar"])
    try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [1, "Foo"])
    try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [1, "Bar"])
    try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [2, "Baz"])
    
    for pair in try BookAuthorPair.all().fetchAll(db) {
        print("\(pair.book.title) by \(pair.author.name)")
    }
    
    let r = JoinPair<Book, Author>.all()
    for pair in try r.fetchAll(db) {
        print("\(pair.left.title) by \(pair.right.name)")
    }

    try Author.myCustomRequest().fetchAll(db)
//    try db.create(table: "persons") { t in
//        t.column("id", .integer).primaryKey()
//        t.column("name", .text)
//    }
//    
//    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
//    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
//    
//    let names = try String.fetchAll(db, "SELECT name FROM persons")
//    print(names)
//    
//    struct Person : TableMapping {
//        static var databaseTableName: String { return "persons" }
//    }
//    let request = Person.select(max(Column("id"))).bound(to: Int64.self)
//    try request.fetchOne(db)
}
