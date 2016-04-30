import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

private class ChangesRecorder<Record>: FetchedRecordsControllerDelegate {
    var changes: [(record: Record, event: FetchedRecordsEvent)] = []
    var recordsBeforeChanges: [Record]!
    var recordsOnFirstEvent: [Record]!
    var transactionExpectation: XCTestExpectation? {
        didSet {
            changes = []
            recordsBeforeChanges = nil
            recordsOnFirstEvent = nil
        }
    }
    
    func controllerWillChangeRecords<T>(controller: FetchedRecordsController<T>) {
        recordsBeforeChanges = controller.fetchedRecords!.map { $0 as! Record }
    }
    
    /// The default implementation does nothing.
    func controller<T>(controller: FetchedRecordsController<T>, didChangeRecord record: T, withEvent event:FetchedRecordsEvent) {
        if recordsOnFirstEvent == nil {
            recordsOnFirstEvent = controller.fetchedRecords!.map { $0 as! Record }
        }
        changes.append((record: record as! Record, event: event))
    }
    
    /// The default implementation does nothing.
    func controllerDidChangeRecords<T>(controller: FetchedRecordsController<T>) {
        if let transactionExpectation = transactionExpectation {
            transactionExpectation.fulfill()
        }
    }
}

private class Person : Record {
    var id: Int64?
    let name: String
    let bookCount: Int?
    
    init(name: String) {
        self.id = nil
        self.name = name
        self.bookCount = nil
        super.init()
    }
    
    required init(_ row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        bookCount = row.value(named: "bookCount")
        super.init(row)
    }
    
    override class func databaseTableName() -> String {
        return "persons"
    }
    
    override var persistentDictionary: [String : DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
    }
}

class FetchedRecordsControllerTests: GRDBTestCase {

    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name TEXT" +
                ")")
            try db.execute(
                "CREATE TABLE books (" +
                    "id INTEGER PRIMARY KEY, " +
                    "ownerId INTEGER NOT NULL REFERENCES persons(id) ON DELETE CASCADE ON UPDATE CASCADE," +
                    "title TEXT" +
                ")")
            try db.execute(
                "CREATE TABLE flowers (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name TEXT" +
                ")")
        }
    }
    
    func testRecordsAreNotLoadedUntilPerformFetch() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let arthur = Person(name: "Arthur")
            try dbQueue.inDatabase { db in
                try arthur.insert(db)
            }
            
            let request = Person.all()
            let controller = FetchedRecordsController<Person>(dbQueue, request: request, compareRecordsByPrimaryKey: true)
            XCTAssertTrue(controller.fetchedRecords == nil)
            controller.performFetch()
            XCTAssertEqual(controller.fetchedRecords!.count, 1)
            XCTAssertEqual(controller.fetchedRecords![0].name, "Arthur")
            XCTAssertEqual(controller.recordAtIndexPath(NSIndexPath(forRow: 0, inSection: 0)).name, "Arthur")
            XCTAssertEqual(controller.indexPathForRecord(arthur), NSIndexPath(forRow: 0, inSection: 0))
        }
    }
    
    func testDatabaseChangesAreNotReReflectedUntilPerformFetchAndDelegateIsSet() {
        // TODO: test that controller.fetchedRecords does not eventually change
        // after a database change. The difficulty of this test lies in the
        // "eventually" word.
    }

    func testSimpleInsert() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.all(), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.delegate = recorder
            controller.performFetch()
            
            
            // First insert
            
            recorder.transactionExpectation = expectationWithDescription("First insert")
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 0)
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 1)
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Arthur"])
            XCTAssertEqual(recorder.changes.count, 1)
            XCTAssertEqual(recorder.changes[0].record.id, 1)
            XCTAssertEqual(recorder.changes[0].record.name, "Arthur")
            switch recorder.changes[0].event {
            case .Insertion(let indexPath):
                XCTAssertEqual(indexPath, NSIndexPath(forRow: 0, inSection: 0))
            default:
                XCTFail()
            }
            
            
            // Second insert
            
            recorder.transactionExpectation = expectationWithDescription("Second insert")
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 1)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur"])
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 2)
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Arthur", "Barbara"])
            XCTAssertEqual(recorder.changes.count, 1)
            XCTAssertEqual(recorder.changes[0].record.id, 2)
            XCTAssertEqual(recorder.changes[0].record.name, "Barbara")
            switch recorder.changes[0].event {
            case .Insertion(let indexPath):
                XCTAssertEqual(indexPath, NSIndexPath(forRow: 1, inSection: 0))
            default:
                XCTFail()
            }
            
        }
    }
    
    func testSimpleUpdate() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.all(), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.delegate = recorder
            controller.performFetch()
            
            // Insert
            
            recorder.transactionExpectation = expectationWithDescription("Insert")
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            
            // First update
            
            recorder.transactionExpectation = expectationWithDescription("First update")
            // No change should be recorded
            try dbQueue.inTransaction { db in
                try db.execute("UPDATE persons SET name = ? WHERE id = ?", arguments: ["Arthur", 1])
                return .Commit
            }
            // One change should be recorded
            try dbQueue.inTransaction { db in
                try db.execute("UPDATE persons SET name = ? WHERE id = ?", arguments: ["Craig", 1])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 2)
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Craig", "Barbara"])
            XCTAssertEqual(recorder.changes.count, 1)
            XCTAssertEqual(recorder.changes[0].record.id, 1)
            XCTAssertEqual(recorder.changes[0].record.name, "Craig")
            switch recorder.changes[0].event {
            case .Update(let indexPath, let changes):
                XCTAssertEqual(indexPath, NSIndexPath(forRow: 0, inSection: 0))
                XCTAssertEqual(changes, ["name": "Arthur".databaseValue])
            default:
                XCTFail()
            }
            
            
            // Second update
            
            recorder.transactionExpectation = expectationWithDescription("Second update")
            try dbQueue.inTransaction { db in
                try db.execute("UPDATE persons SET name = ? WHERE id = ?", arguments: ["Danielle", 2])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Craig", "Barbara"])
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 2)
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Craig", "Danielle"])
            XCTAssertEqual(recorder.changes.count, 1)
            XCTAssertEqual(recorder.changes[0].record.id, 2)
            XCTAssertEqual(recorder.changes[0].record.name, "Danielle")
            switch recorder.changes[0].event {
            case .Update(let indexPath, let changes):
                XCTAssertEqual(indexPath, NSIndexPath(forRow: 1, inSection: 0))
                XCTAssertEqual(changes, ["name": "Barbara".databaseValue])
            default:
                XCTFail()
            }
        }
    }
    
    func testSimpleDelete() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.all(), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.delegate = recorder
            controller.performFetch()
            
            // Insert
            
            recorder.transactionExpectation = expectationWithDescription("Insert")
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            
            // First delete
            
            recorder.transactionExpectation = expectationWithDescription("First delete")
            try dbQueue.inTransaction { db in
                try db.execute("DELETE FROM persons WHERE id = ?", arguments: [1])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 1)
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Barbara"])
            XCTAssertEqual(recorder.changes.count, 1)
            XCTAssertEqual(recorder.changes[0].record.id, 1)
            XCTAssertEqual(recorder.changes[0].record.name, "Arthur")
            switch recorder.changes[0].event {
            case .Deletion(let indexPath):
                XCTAssertEqual(indexPath, NSIndexPath(forRow: 0, inSection: 0))
            default:
                XCTFail()
            }
            
            
            // Second delete
            
            recorder.transactionExpectation = expectationWithDescription("Second delete")
            try dbQueue.inTransaction { db in
                try db.execute("DELETE FROM persons WHERE id = ?", arguments: [2])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 1)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Barbara"])
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 0)
            XCTAssertEqual(recorder.changes.count, 1)
            XCTAssertEqual(recorder.changes[0].record.id, 2)
            XCTAssertEqual(recorder.changes[0].record.name, "Barbara")
            switch recorder.changes[0].event {
            case .Deletion(let indexPath):
                XCTAssertEqual(indexPath, NSIndexPath(forRow: 0, inSection: 0))
            default:
                XCTFail()
            }
        }
    }
    
    func testSimpleMove() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("name")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.delegate = recorder
            controller.performFetch()
            
            // Insert
            
            recorder.transactionExpectation = expectationWithDescription("Insert")
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            
            // Move
            
            recorder.transactionExpectation = expectationWithDescription("First delete")
            try dbQueue.inTransaction { db in
                try db.execute("UPDATE persons SET name = ? WHERE id = ?", arguments: ["Craig", 1])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 2)
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Barbara", "Craig"])
            XCTAssertEqual(recorder.changes.count, 1)
            XCTAssertEqual(recorder.changes[0].record.id, 1)
            XCTAssertEqual(recorder.changes[0].record.name, "Craig")
            switch recorder.changes[0].event {
            case .Move(let indexPath, let newIndexPath, let changes):
                XCTAssertEqual(indexPath, NSIndexPath(forRow: 0, inSection: 0))
                XCTAssertEqual(newIndexPath, NSIndexPath(forRow: 1, inSection: 0))
                XCTAssertEqual(changes, ["name": "Arthur".databaseValue])
            default:
                XCTFail()
            }
        }
    }
    
    func testSideTableChange() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(
                dbQueue,
                sql: "SELECT persons.*, COUNT(books.id) AS bookCount " +
                    "FROM persons " +
                    "LEFT JOIN books ON books.ownerId = persons.id " +
                    "GROUP BY persons.id " +
                "ORDER BY persons.name",
                compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.delegate = recorder
            controller.performFetch()
            
            // Insert
            
            recorder.transactionExpectation = expectationWithDescription("Insert")
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
                try db.execute("INSERT INTO books (ownerId, title) VALUES (?, ?)", arguments: [1, "Moby Dick"])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            
            // Change books
            
            recorder.transactionExpectation = expectationWithDescription("Change books")
            try dbQueue.inTransaction { db in
                try db.execute("DELETE FROM books")
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 1)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur"])
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.bookCount! }, [1])
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 1)
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Arthur"])
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.bookCount! }, [0])
            XCTAssertEqual(recorder.changes.count, 1)
            XCTAssertEqual(recorder.changes[0].record.id, 1)
            XCTAssertEqual(recorder.changes[0].record.name, "Arthur")
            XCTAssertEqual(recorder.changes[0].record.bookCount, 0)
            switch recorder.changes[0].event {
            case .Update(let indexPath, let changes):
                XCTAssertEqual(indexPath, NSIndexPath(forRow: 0, inSection: 0))
                XCTAssertEqual(changes, ["bookCount": 1.databaseValue])
            default:
                XCTFail()
            }
        }
    }
    
    func testExternalTableChange() {
        // TODO: test that delegate is not notified after a database change in a
        // table not involved in the fetch request. The difficulty of this test
        // lies in the "not" word.
    }
}
