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
    var title: String
    var author: String
    var body: String
    
    var insertedRowIDColumn: String?
    
    init(id: Int64? = nil, title: String, author: String, body: String) {
        self.id = id
        self.title = title
        self.author = author
        self.body = body
    }
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
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            Column.rowID.name: id,
            "title": title,
            "author": author,
            "body": body,
        ]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
        insertedRowIDColumn = column
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
    
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                XCTAssertTrue(record.id == nil)
                try record.insert(db)
                XCTAssertTrue(record.id != nil)
                
                let row = Row.fetchOne(db, "SELECT *, rowid FROM books WHERE rowid = ?", arguments: [record.id])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testRollbackedInsertWithNilPrimaryKeyDoesNotResetPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
            try dbQueue.inTransaction { db in
                XCTAssertTrue(record.id == nil)
                try record.insert(db)
                XCTAssertTrue(record.id != nil)
                
                let row = Row.fetchOne(db, "SELECT *, rowid FROM books WHERE rowid = ?", arguments: [record.id])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
                return .rollback
            }
            // This is debatable, actually.
            XCTAssertTrue(record.id != nil)
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(id: 123456, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT *, rowid FROM books WHERE rowid = ?", arguments: [record.id])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testRollbackedInsertWithNotNilPrimaryKeyDoeNotResetPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            var record = Book(id: 123456, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
            try dbQueue.inTransaction { db in
                try record.insert(db)
                XCTAssertEqual(record.id!, 123456)
                return .rollback
            }
            XCTAssertEqual(record.id!, 123456)
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                do {
                    try record.insert(db)
                    XCTFail("Expected DatabaseError")
                } catch is DatabaseError {
                    // Expected DatabaseError
                }
            }
        }
    }
    
    func testInsertAfterDeleteInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                try record.delete(db)
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT *, rowid FROM books WHERE rowid = ?", arguments: [record.id])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Update
    
    func testUpdateWithNilPrimaryKeyThrowsRecordNotFound() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                do {
                    try record.update(db)
                    XCTFail("Expected PersistenceError.recordNotFound")
                } catch PersistenceError.recordNotFound {
                    // Expected PersistenceError.recordNotFound
                }
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Book(id: 123456, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                do {
                    try record.update(db)
                    XCTFail("Expected PersistenceError.recordNotFound")
                } catch PersistenceError.recordNotFound {
                    // Expected PersistenceError.recordNotFound
                }
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                record.title = "Moby-Dick"
                try record.update(db)
                
                let row = Row.fetchOne(db, "SELECT *, rowid FROM books WHERE rowid = ?", arguments: [record.id])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testUpdateAfterDeleteThrowsRecordNotFound() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                try record.delete(db)
                do {
                    try record.update(db)
                    XCTFail("Expected PersistenceError.recordNotFound")
                } catch PersistenceError.recordNotFound {
                    // Expected PersistenceError.recordNotFound
                }
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                XCTAssertTrue(record.id == nil)
                try record.save(db)
                XCTAssertTrue(record.id != nil)
                
                let row = Row.fetchOne(db, "SELECT *, rowid FROM books WHERE rowid = ?", arguments: [record.id])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(id: 123456, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT *, rowid FROM books WHERE rowid = ?", arguments: [record.id])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                try record.save(db)   // Test that useless update succeeds. It is a proof that save() has performed an UPDATE statement, and not an INSERT statement: INSERT would have throw a database error for duplicated key.
                record.title = "Moby-Dick"
                try record.save(db)   // Actual update
                
                let row = Row.fetchOne(db, "SELECT *, rowid FROM books WHERE rowid = ?", arguments: [record.id])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveAfterDeleteInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                try record.delete(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT *, rowid FROM books WHERE rowid = ?", arguments: [record.id])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Delete
    
    func testDeleteWithNilPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                let deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Book(id: 123456, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                let deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                let deleted = try record.delete(db)
                XCTAssertTrue(deleted)
                
                let row = Row.fetchOne(db, "SELECT * FROM books WHERE rowid = ?", arguments: [record.id])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                var deleted = try record.delete(db)
                XCTAssertTrue(deleted)
                deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    
    // MARK: - Fetch With Key
    
    func testFetchWithKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record1 = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record1.insert(db)
                var record2 = Book(title: "Querelle", author: "Jean Genet", body: "L’idée de mer évoque souvent l’idée de mer, de marins.")
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Array(Book.fetch(db, keys: []))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Array(Book.fetch(db, keys: [["rowid": record1.id], ["rowid": record2.id]]))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id! }), Set([record1.id!, record2.id!]))
                }
                
                do {
                    let fetchedRecords = Array(Book.fetch(db, keys: [["rowid": record1.id], ["rowid": nil]]))
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.id, record1.id!)
                }
            }
        }
    }
    
    func testFetchAllWithKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record1 = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record1.insert(db)
                var record2 = Book(title: "Querelle", author: "Jean Genet", body: "L’idée de mer évoque souvent l’idée de mer, de marins.")
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Book.fetchAll(db, keys: [])
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Book.fetchAll(db, keys: [["rowid": record1.id], ["rowid": record2.id]])
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id! }), Set([record1.id!, record2.id!]))
                }
                
                do {
                    let fetchedRecords = Book.fetchAll(db, keys: [["rowid": record1.id], ["rowid": nil]])
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.id, record1.id!)
                }
            }
        }
    }
    
    func testFetchOneWithKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                
                let fetchedRecord = Book.fetchOne(db, key: ["rowid": record.id])!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertTrue(fetchedRecord.title == record.title)
                XCTAssertTrue(fetchedRecord.author == record.author)
                XCTAssertTrue(fetchedRecord.body == record.body)
            }
        }
    }
    
    
    // MARK: - Fetch With Primary Key
    
    func testFetchWithPrimaryKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record1 = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record1.insert(db)
                var record2 = Book(title: "Querelle", author: "Jean Genet", body: "L’idée de mer évoque souvent l’idée de mer, de marins.")
                try record2.insert(db)
                
                do {
                    let ids: [Int64] = []
                    let fetchedRecords = Array(Book.fetch(db, keys: ids))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id!, record2.id!]
                    let fetchedRecords = Array(Book.fetch(db, keys: ids))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id! }), Set(ids))
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record1 = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record1.insert(db)
                var record2 = Book(title: "Querelle", author: "Jean Genet", body: "L’idée de mer évoque souvent l’idée de mer, de marins.")
                try record2.insert(db)
                
                do {
                    let ids: [Int64] = []
                    let fetchedRecords = Book.fetchAll(db, keys: ids)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id!, record2.id!]
                    let fetchedRecords = Book.fetchAll(db, keys: ids)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id! }), Set(ids))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                
                do {
                    let id: Int64? = nil
                    let fetchedRecord = Book.fetchOne(db, key: id)
                    XCTAssertTrue(fetchedRecord == nil)
                }
                
                do {
                    let fetchedRecord = Book.fetchOne(db, key: record.id)!
                    XCTAssertTrue(fetchedRecord.id == record.id)
                    XCTAssertTrue(fetchedRecord.title == record.title)
                    XCTAssertTrue(fetchedRecord.author == record.author)
                    XCTAssertTrue(fetchedRecord.body == record.body)
                }
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNilPrimaryKeyReturnsFalse() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let record = Book(id: nil, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                XCTAssertFalse(record.exists(db))
            }
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let record = Book(id: 123456, title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                XCTAssertFalse(record.exists(db))
            }
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                XCTAssertTrue(record.exists(db))
            }
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var record = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
                try record.insert(db)
                try record.delete(db)
                XCTAssertFalse(record.exists(db))
            }
        }
    }
    
    
    // MARK: - Full Text
    
    func testRowIdIsSelectedByDefault() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    var book = Book(title: "Moby Dick", author: "Herman Melville", body: "Call me Ishmael.")
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
                assertBookIsComplete(Book.fetchOne(db, key: [Column.rowID.name: 1])!)
                assertBookIsComplete(Book.fetchAll(db).first!)
                assertBookIsComplete(Book.fetchAll(db, keys: [1]).first!)
                assertBookIsComplete(Book.fetchAll(db, keys: [[Column.rowID.name: 1]]).first!)
                assertBookIsComplete(Book.all().fetchOne(db)!)
                assertBookIsComplete(Book.filter(Column.rowID == 1).fetchOne(db)!)
                assertBookIsComplete(Book.filter(sql: "\(Column.rowID.name) = 1").fetchOne(db)!)
                assertBookIsComplete(Book.order(Column.rowID).fetchOne(db)!)
                assertBookIsComplete(Book.order(sql: Column.rowID.name).fetchOne(db)!)
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
