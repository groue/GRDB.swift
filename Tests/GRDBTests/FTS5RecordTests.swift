#if SQLITE_ENABLE_FTS5
import XCTest
import GRDB

private struct Book {
    var id: Int64?
    let title: String
    let author: String
    let body: String
}

extension Book : FetchableRecord {
    init(row: Row) {
        id = row[.rowID]
        title = row["title"]
        author = row["author"]
        body = row["body"]
    }
}

extension Book : MutablePersistableRecord {
    static let databaseTableName = "books"
    static var databaseSelection: [any SQLSelectable] { [.allColumns, .rowID] }
    
    func encode(to container: inout PersistenceContainer) {
        container[.rowID] = id
        container["title"] = title
        container["author"] = author
        container["body"] = body
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

class FTS5RecordTests: GRDBTestCase {
    override func setUpWithError() throws {
        throw XCTSkip("SQLInterface FIXME: FTS5 needs work")
    }

    override func setup(_ dbWriter: some DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(virtualTable: "books", using: FTS5()) { t in
                t.column("title")
                t.column("author")
                t.column("body")
            }
        }
    }
    
    // MARK: - Full Text
    
    func testRowIdIsSelectedByDefault() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var book = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
            try book.insert(db)
            XCTAssertTrue(book.id != nil)
            
            let fetchedBook = try Book.matching(FTS5Pattern(matchingAllTokensIn: "Herman Melville")!).fetchOne(db)!
            XCTAssertEqual(fetchedBook.id, book.id)
            XCTAssertEqual(fetchedBook.title, book.title)
            XCTAssertEqual(fetchedBook.author, book.author)
            XCTAssertEqual(fetchedBook.body, book.body)
        }
    }

    func testMatch() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                var book = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try book.insert(db)
            }
            
            let pattern = FTS5Pattern(matchingAllTokensIn: "Herman Melville")!
            XCTAssertEqual(try Book.matching(pattern).fetchCount(db), 1)
            XCTAssertEqual(try Book.filter(Column("books").match(pattern)).fetchCount(db), 1)
            XCTAssertEqual(try Book.filter(Column("author").match(pattern)).fetchCount(db), 1)
            XCTAssertEqual(try Book.filter(Column("title").match(pattern)).fetchCount(db), 0)
        }
    }

    func testMatchNil() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                var book = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try book.insert(db)
            }
            
            let pattern = FTS5Pattern(matchingAllTokensIn: "")
            XCTAssertTrue(pattern == nil)
            XCTAssertEqual(try Book.matching(pattern).fetchCount(db), 0)
        }
    }

    func testFetchCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                var book = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try book.insert(db)
            }
            
            do {
                clearSQLQueries()
                let pattern = FTS5Pattern(matchingAllTokensIn: "Herman Melville")!
                XCTAssertEqual(try Book.matching(pattern).fetchCount(db), 1)
                XCTAssertTrue(sqlQueries.contains("SELECT COUNT(*) FROM \"books\" WHERE \"books\" MATCH 'herman melville'"))
            }
            
            do {
                clearSQLQueries()
                XCTAssertEqual(try Book.fetchCount(db), 1)
                XCTAssertTrue(sqlQueries.contains("SELECT COUNT(*) FROM \"books\""))
            }
        }
    }
}
#endif
