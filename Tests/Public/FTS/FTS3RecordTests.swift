import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Book {
    var id: Int64?
    let title: String
    let author: String
    let body: String
}

extension Book : RowConvertible {
    init(row: Row) {
        id = row.value(named: "rowid")
        title = row.value(named: "title")
        author = row.value(named: "author")
        body = row.value(named: "body")
    }
}

extension Book : MutablePersistable {
    static let databaseTableName = "books"
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "rowid": id,
            "title": title,
            "author": author,
            "body": body,
        ]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class FTS3RecordTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(virtualTable: "books", using: FTS3()) { t in
                t.column("title")
                t.column("author")
                t.column("body")
            }
        }
    }
    
    func testInsertionNotifiesRowId() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var book = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try book.insert(db)
                XCTAssertEqual(book.id, 1)
            }
        }
    }
    
    func testUpdate() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var book = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try book.insert(db)
                try book.update(db)
            }
        }
    }
    
    func testRowIdIsSelectedByDefault() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    var book = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                    try book.insert(db)
                }
                
                func assertBookIsComplete(_ book: Book) {
                    XCTAssertEqual(book.id, 1)
                    XCTAssertEqual(book.title, "Moby Dick")
                    XCTAssertEqual(book.author, "Herman Melville")
                    XCTAssertEqual(book.body, "Call me Ishmael.")
                }
                
                for book in Book.fetch(db) {
                    assertBookIsComplete(book)
                }
                
                assertBookIsComplete(Book.fetchOne(db)!)
                assertBookIsComplete(Book.fetchOne(db, key: 1)!)
                assertBookIsComplete(Book.fetchOne(db, key: ["rowid": 1])!)
                assertBookIsComplete(Book.fetchAll(db).first!)
                assertBookIsComplete(Book.fetchAll(db, keys: [1]).first!)
                assertBookIsComplete(Book.fetchAll(db, keys: [["rowid": 1]]).first!)
                assertBookIsComplete(Book.all().fetchOne(db)!)
                assertBookIsComplete(Book.filter(Column("rowid") == 1).fetchOne(db)!)
                assertBookIsComplete(Book.filter(sql: "rowid = 1").fetchOne(db)!)
                assertBookIsComplete(Book.order(Column("rowid")).fetchOne(db)!)
                assertBookIsComplete(Book.order(sql: "rowid").fetchOne(db)!)
                assertBookIsComplete(Book.limit(1).fetchOne(db)!)
                assertBookIsComplete(Book.matching(FTS3Pattern(matchingAllTokensIn: "Herman Melville")!).fetchOne(db)!)
            }
        }
    }
    
    func testMatch() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    var book = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                    try book.insert(db)
                }
                
                let pattern = FTS3Pattern(matchingAllTokensIn: "Herman Melville")!
                XCTAssertEqual(Book.matching(pattern).fetchCount(db), 1)
                XCTAssertEqual(Book.filter(Column("books").match(pattern)).fetchCount(db), 1)
                XCTAssertEqual(Book.filter(Column("author").match(pattern)).fetchCount(db), 1)
                XCTAssertEqual(Book.filter(Column("title").match(pattern)).fetchCount(db), 0)
            }
        }
    }
}
