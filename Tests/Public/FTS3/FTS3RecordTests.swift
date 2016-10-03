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
        id = row.value(named: "docid")
        title = row.value(named: "title")
        author = row.value(named: "author")
        body = row.value(named: "body")
    }
}

extension Book : MutablePersistable {
    static let databaseTableName = "books"
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "docid": id,
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
            try db.execute("CREATE VIRTUAL TABLE books USING fts4(title, author, body)")
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
    
    func testDocIdIsNotSelectedByDefault() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    var book = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                    try book.insert(db)
                }
                
                let request = Book.all()
                let row = Row.fetchOne(db, request)!
                XCTAssertEqual(row.count, 3)
                XCTAssertTrue(row.hasColumn("title"))
                XCTAssertTrue(row.hasColumn("author"))
                XCTAssertTrue(row.hasColumn("body"))
                XCTAssertTrue(!row.hasColumn("docid"))
            }
        }
    }
    
}
