#if SQLITE_ENABLE_FTS5
import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
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
        id = row.value(Column.rowID)
        title = row.value(named: "title")
        author = row.value(named: "author")
        body = row.value(named: "body")
    }
}

extension Book : MutablePersistable {
    static let databaseTableName = "books"
    static let selectsRowID = true
    
    func encode(to container: inout PersistenceContainer) {
        container[.rowID] = id
        container["title"] = title
        container["author"] = author
        container["body"] = body
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class FTS5RecordTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        dbConfiguration.trace = { [unowned self] sql in
            // Ignore virtual table logs
            if !sql.hasPrefix("--") {
                self.sqlQueries.append(sql)
            }
        }
    }
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
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
            
            let pattern = FTS5Pattern(matchingAllTokensIn: "Herman Melville")!
            XCTAssertEqual(try Book.matching(pattern).fetchCount(db), 1)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"books\" WHERE (\"books\" MATCH 'herman melville')")
            
            XCTAssertEqual(try Book.fetchCount(db), 1)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"books\"")
        }
    }
}
#endif
