import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

/// Same as NSIndexPath(forRow:inSection:), but works on OSX as well.
private func makeIndexPath(forRow row:Int, inSection section: Int) -> NSIndexPath {
    #if os(iOS)
        return NSIndexPath(forRow: row, inSection: section)
    #else
        return [section, row].withUnsafeBufferPointer { buffer in NSIndexPath(indexes: buffer.baseAddress, length: buffer.count) }
    #endif
}

/// Same as NSIndexPath.row, but works on OSX as well.
private func row(for indexPath:NSIndexPath) -> Int {
    #if os(iOS)
        return indexPath.row
    #else
        return indexPath.indexAtPosition(1)
    #endif
}

private class ChangesRecorder<Record: RowConvertible> {
    var changes: [(record: Record, event: TableViewEvent)] = []
    var recordsBeforeChanges: [Record]!
    var recordsOnFirstEvent: [Record]!
    var transactionExpectation: XCTestExpectation? {
        didSet {
            changes = []
            recordsBeforeChanges = nil
            recordsOnFirstEvent = nil
        }
    }
    
    func controllerWillChange(controller: FetchedRecordsController<Record>) {
        recordsBeforeChanges = controller.fetchedRecords!
    }
    
    /// The default implementation does nothing.
    func controller(controller: FetchedRecordsController<Record>, didChangeRecord record: Record, withEvent event:TableViewEvent) {
        if recordsOnFirstEvent == nil {
            recordsOnFirstEvent = controller.fetchedRecords!
        }
        changes.append((record: record, event: event))
    }
    
    /// The default implementation does nothing.
    func controllerDidChange(controller: FetchedRecordsController<Record>) {
        if let transactionExpectation = transactionExpectation {
            transactionExpectation.fulfill()
        }
    }
}

private class Person : Record {
    var id: Int64?
    let name: String
    let bookCount: Int?
    
    init(id: Int64? = nil, name: String) {
        self.id = id
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

class FetchedRecordsControlleriOSTests: GRDBTestCase {

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
            XCTAssertEqual(controller.sections.count, 1)
            XCTAssertEqual(controller.sections[0].numberOfRecords, 1)
            XCTAssertEqual(controller.sections[0].records.count, 1)
            XCTAssertEqual(controller.sections[0].records[0].name, "Arthur")
            XCTAssertEqual(controller.fetchedRecords!.count, 1)
            XCTAssertEqual(controller.fetchedRecords![0].name, "Arthur")
            XCTAssertEqual(controller.recordAtIndexPath(makeIndexPath(forRow: 0, inSection: 0)).name, "Arthur")
            XCTAssertEqual(controller.indexPathForRecord(arthur), makeIndexPath(forRow: 0, inSection: 0))
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
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("id")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
                tableViewEvent: { (controller, record, event) in recorder.controller(controller, didChangeRecord: record, withEvent: event) },
                recordsDidChange: { recorder.controllerDidChange($0) })
            controller.performFetch()
            
            // First insert
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Arthur")])
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
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 0, inSection: 0))
            default:
                XCTFail()
            }
            
            // Second insert
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Arthur"),
                    Person(id: 2, name: "Barbara")])
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
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 1, inSection: 0))
            default:
                XCTFail()
            }
            
        }
    }
    
    func testSimpleUpdate() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("id")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
                tableViewEvent: { (controller, record, event) in recorder.controller(controller, didChangeRecord: record, withEvent: event) },
                recordsDidChange: { recorder.controllerDidChange($0) })
            controller.performFetch()
            
            // Insert
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Arthur"),
                    Person(id: 2, name: "Barbara")])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            // First update
            recorder.transactionExpectation = expectationWithDescription("expectation")
            // No change should be recorded
            try dbQueue.inTransaction { db in
                try db.execute("UPDATE persons SET name = ? WHERE id = ?", arguments: ["Arthur", 1])
                return .Commit
            }
            // One change should be recorded
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Craig"),
                    Person(id: 2, name: "Barbara")])
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
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 0, inSection: 0))
                XCTAssertEqual(changes, ["name": "Arthur".databaseValue])
            default:
                XCTFail()
            }
            
            // Second update
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Craig"),
                    Person(id: 2, name: "Danielle")])
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
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 1, inSection: 0))
                XCTAssertEqual(changes, ["name": "Barbara".databaseValue])
            default:
                XCTFail()
            }
        }
    }
    
    func testSimpleDelete() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("id")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
                tableViewEvent: { (controller, record, event) in recorder.controller(controller, didChangeRecord: record, withEvent: event) },
                recordsDidChange: { recorder.controllerDidChange($0) })
            controller.performFetch()
            
            // Insert
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Arthur"),
                    Person(id: 2, name: "Barbara")])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            // First delete
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 2, name: "Barbara")])
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
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 0, inSection: 0))
            default:
                XCTFail()
            }
            
            // Second delete
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [])
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
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 0, inSection: 0))
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
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
                tableViewEvent: { (controller, record, event) in recorder.controller(controller, didChangeRecord: record, withEvent: event) },
                recordsDidChange: { recorder.controllerDidChange($0) })
            controller.performFetch()
            
            // Insert
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Arthur"),
                    Person(id: 2, name: "Barbara")])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            // Move
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Craig"),
                    Person(id: 2, name: "Barbara")])
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
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 0, inSection: 0))
                XCTAssertEqual(newIndexPath, makeIndexPath(forRow: 1, inSection: 0))
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
                sql: ("SELECT persons.*, COUNT(books.id) AS bookCount " +
                    "FROM persons " +
                    "LEFT JOIN books ON books.ownerId = persons.id " +
                    "GROUP BY persons.id " +
                    "ORDER BY persons.name"),
                compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
                tableViewEvent: { (controller, record, event) in recorder.controller(controller, didChangeRecord: record, withEvent: event) },
                recordsDidChange: { recorder.controllerDidChange($0) })
            controller.performFetch()
            
            // Insert
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
                try db.execute("INSERT INTO books (ownerId, title) VALUES (?, ?)", arguments: [1, "Moby Dick"])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            // Change books
            recorder.transactionExpectation = expectationWithDescription("expectation")
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
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 0, inSection: 0))
                XCTAssertEqual(changes, ["bookCount": 1.databaseValue])
            default:
                XCTFail()
            }
        }
    }
    
    func testComplexChanges() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("name")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
                tableViewEvent: { (controller, record, event) in recorder.controller(controller, didChangeRecord: record, withEvent: event) },
                recordsDidChange: { recorder.controllerDidChange($0) })
            controller.performFetch()
            
            enum EventTest {
                case I(String, Int) // insert string at index
                case M(String, Int, Int, String) // move string from index to index with changed string
                case D(String, Int) // delete string at index
                case U(String, Int, String) // update string at index with changed string
                
                func match(name: String, event: TableViewEvent) -> Bool {
                    switch self {
                    case .I(let s, let i):
                        switch event {
                        case .Insertion(let indexPath):
                            return s == name && i == row(for: indexPath)
                        default:
                            return false
                        }
                    case .M(let s, let i, let j, let c):
                        switch event {
                        case .Move(let indexPath, let newIndexPath, let changes):
                            return s == name && i == row(for: indexPath) && j == row(for: newIndexPath) && c == changes["name"]!.value()
                        default:
                            return false
                        }
                    case .D(let s, let i):
                        switch event {
                        case .Deletion(let indexPath):
                            return s == name && i == row(for: indexPath)
                        default:
                            return false
                        }
                    case .U(let s, let i, let c):
                        switch event {
                        case .Update(let indexPath, let changes):
                            return s == name && i == row(for: indexPath) && c == changes["name"]!.value()
                        default:
                            return false
                        }
                    }
                }
            }
            
            // A list of random updates. We hope to cover most cases if not all cases here.
            let steps: [(word: String, events: [EventTest])] = [
                (word: "B", events: [.I("B",0)]),
                (word: "BA", events: [.I("A",0)]),
                (word: "ABF", events: [.M("B",0,1,"A"), .M("A",1,0,"B"), .I("F",2)]),
                (word: "AB", events: [.D("F",2)]),
                (word: "A", events: [.D("B",1)]),
                (word: "C", events: [.U("C",0,"A")]),
                (word: "", events: [.D("C",0)]),
                (word: "C", events: [.I("C",0)]),
                (word: "CD", events: [.I("D",1)]),
                (word: "B", events: [.D("D",1), .U("B",0,"C")]),
                (word: "BCAEFD", events: [.I("A",0), .I("C",2), .I("D",3), .I("E",4), .I("F",5)]),
                (word: "CADBE", events: [.M("A",2,0,"C"), .D("D",3), .M("C",1,2,"B"), .M("B",4,1,"E"), .M("D",0,3,"A"), .M("E",5,4,"F")]),
                (word: "EB", events: [.D("B",1), .D("D",3), .D("E",4), .M("E",2,1,"C"), .U("B",0,"A")]),
                (word: "BEC", events: [.I("C",1), .M("B",1,0,"E"), .M("E",0,2,"B")]),
                (word: "AB", events: [.D("C",1), .M("B",2,1,"E"), .U("A",0,"B")]),
                (word: "ADEFCB", events: [.I("B",1), .I("C",2), .I("E",4), .M("D",1,3,"B"), .I("F",5)]),
                (word: "DA", events: [.D("B",1), .D("C",2), .D("E",4), .M("A",3,0,"D"), .D("F",5), .M("D",0,1,"A")]),
                (word: "BACEF", events: [.I("C",2), .I("E",3), .I("F",4), .U("B",1,"D")]),
                (word: "BACD", events: [.D("F",4), .U("D",3,"E")]),
                (word: "EABDFC", events: [.M("B",2,1,"C"), .I("C",2), .M("E",1,4,"B"), .I("F",5)]),
                (word: "CAB", events: [.D("C",2), .D("D",3), .D("F",5), .M("C",4,2,"E")]),
                (word: "CBAD", events: [.M("A",1,0,"B"), .M("B",0,1,"A"), .I("D",3)]),
                (word: "BAC", events: [.M("A",1,0,"B"), .M("B",2,1,"C"), .D("D",3), .M("C",0,2,"A")]),
                (word: "CBEADF", events: [.I("A",0), .M("B",0,1,"A"), .I("D",3), .M("C",1,2,"B"), .M("E",2,4,"C"), .I("F",5)]),
                (word: "CBA", events: [.D("A",0), .D("D",3), .M("A",4,0,"E"), .D("F",5)]),
                (word: "CBDAF", events: [.I("A",0), .M("D",0,3,"A"), .I("F",4)]),
                (word: "B", events: [.D("A",0), .D("B",1), .D("D",3), .D("F",4), .M("B",2,0,"C")]),
                (word: "BDECAF", events: [.I("A",0), .I("C",2), .I("D",3), .I("E",4), .I("F",5)]),
                (word: "ABCDEF", events: [.M("A",1,0,"B"), .M("B",3,1,"D"), .M("D",2,3,"C"), .M("C",4,2,"E"), .M("E",0,4,"A")]),
                (word: "ADBCF", events: [.M("B",2,1,"C"), .M("C",3,2,"D"), .M("D",1,3,"B"), .D("F",5), .U("F",4,"E")]),
                (word: "A", events: [.D("B",1), .D("C",2), .D("D",3), .D("F",4)]),
                (word: "AEBDCF", events: [.I("B",1), .I("C",2), .I("D",3), .I("E",4), .I("F",5)]),
                (word: "B", events: [.D("B",1), .D("C",2), .D("D",3), .D("E",4), .D("F",5), .U("B",0,"A")]),
                (word: "ABCDF", events: [.I("B",1), .I("C",2), .I("D",3), .I("F",4), .U("A",0,"B")]),
                (word: "CAB", events: [.M("A",1,0,"B"), .D("D",3), .M("B",2,1,"C"), .D("F",4), .M("C",0,2,"A")]),
                (word: "AC", events: [.D("B",1), .M("A",2,0,"C"), .M("C",0,1,"A")]),
                (word: "DABC", events: [.I("B",1), .I("C",2), .M("A",1,0,"C"), .M("D",0,3,"A")]),
                (word: "BACD", events: [.M("C",1,2,"B"), .M("B",3,1,"D"), .M("D",2,3,"C")]),
                (word: "D", events: [.D("A",0), .D("C",2), .D("D",3), .M("D",1,0,"B")]),
                (word: "CABDFE", events: [.I("A",0), .I("B",1), .I("D",3), .I("E",4), .M("C",0,2,"D"), .I("F",5)]),
                (word: "BACDEF", events: [.M("B",2,1,"C"), .M("C",1,2,"B"), .M("E",5,4,"F"), .M("F",4,5,"E")]),
                (word: "AB", events: [.D("C",2), .D("D",3), .D("E",4), .M("A",1,0,"B"), .D("F",5), .M("B",0,1,"A")]),
                (word: "BACDE", events: [.I("C",2), .M("B",0,1,"A"), .I("D",3), .M("A",1,0,"B"), .I("E",4)]),
                (word: "E", events: [.D("A",0), .D("C",2), .D("D",3), .D("E",4), .M("E",1,0,"B")]),
                (word: "A", events: [.U("A",0,"E")]),
                (word: "ABCDE", events: [.I("B",1), .I("C",2), .I("D",3), .I("E",4)]),
                (word: "BA", events: [.D("C",2), .D("D",3), .M("A",1,0,"B"), .D("E",4), .M("B",0,1,"A")]),
                (word: "A", events: [.D("A",0), .M("A",1,0,"B")]),
                (word: "CAB", events: [.I("A",0), .I("B",1), .M("C",0,2,"A")]),
                (word: "EA", events: [.D("B",1), .M("E",2,1,"C")]),
                (word: "B", events: [.D("A",0), .M("B",1,0,"E")]),
            ]

            for step in steps {
                recorder.transactionExpectation = expectationWithDescription("expectation")
                try dbQueue.inTransaction { db in
                    try synchronizePersons(db, step.word.characters.enumerate().map { Person(id: Int64($0), name: String($1)) })
                    return .Commit
                }
                waitForExpectationsWithTimeout(1, handler: nil)
                
                XCTAssertEqual(recorder.changes.count, step.events.count)
                for (change, event) in zip(recorder.changes, step.events) {
                    XCTAssertTrue(event.match(change.record.name, event: change.event))
                }
            }
        }
    }
    
    func testExternalTableChange() {
        // TODO: test that delegate is not notified after a database change in a
        // table not involved in the fetch request. The difficulty of this test
        // lies in the "not" word.
    }
    
    func testCustomRecordIdentity() {
        // TODO: test record comparison not based on primary key but based on
        // custom function
    }
    
    func testRequestChange() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("name")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
                tableViewEvent: { (controller, record, event) in recorder.controller(controller, didChangeRecord: record, withEvent: event) },
                recordsDidChange: { recorder.controllerDidChange($0) })
            controller.performFetch()
            
            // Insert
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Arthur"),
                    Person(id: 2, name: "Barbara")])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            // Change request with FetchRequest
            recorder.transactionExpectation = expectationWithDescription("expectation")
            controller.setRequest(Person.order(SQLColumn("name").desc))
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 2)
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Barbara", "Arthur"])
            XCTAssertEqual(recorder.changes.count, 1)
            XCTAssertEqual(recorder.changes[0].record.id, 2)
            XCTAssertEqual(recorder.changes[0].record.name, "Barbara")
            switch recorder.changes[0].event {
            case .Move(let indexPath, let newIndexPath, let changes):
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 1, inSection: 0))
                XCTAssertEqual(newIndexPath, makeIndexPath(forRow: 0, inSection: 0))
                XCTAssertTrue(changes.isEmpty)
            default:
                XCTFail()
            }
            
            // Change request with SQL and arguments
            recorder.transactionExpectation = expectationWithDescription("expectation")
            controller.setRequest(sql: "SELECT ? AS id, ? AS name", arguments: [1, "Craig"])
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Barbara", "Arthur"])
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 1)
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Craig"])
            XCTAssertEqual(recorder.changes.count, 2)
            XCTAssertEqual(recorder.changes[0].record.id, 2)
            XCTAssertEqual(recorder.changes[0].record.name, "Barbara")
            XCTAssertEqual(recorder.changes[1].record.id, 1)
            XCTAssertEqual(recorder.changes[1].record.name, "Craig")
            switch recorder.changes[0].event {
            case .Deletion(let indexPath):
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 0, inSection: 0))
            default:
                XCTFail()
            }
            switch recorder.changes[1].event {
            case .Move(let indexPath, let newIndexPath, let changes):
                // TODO: is it really what we should expect? Wouldn't an update fit better?
                // What does UITableView think?
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 1, inSection: 0))
                XCTAssertEqual(newIndexPath, makeIndexPath(forRow: 0, inSection: 0))
                XCTAssertEqual(changes, ["name": "Arthur".databaseValue])
            default:
                XCTFail()
            }
        }
    }
    
    func testSetCallbacksAfterUpdate() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("name")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.performFetch()
            
            // Insert
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Arthur")])
                return .Commit
            }
            
            // Set callbacks
            recorder.transactionExpectation = expectationWithDescription("expectation")
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
                tableViewEvent: { (controller, record, event) in recorder.controller(controller, didChangeRecord: record, withEvent: event) },
                recordsDidChange: { recorder.controllerDidChange($0) })
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 0)
            XCTAssertEqual(recorder.recordsOnFirstEvent.count, 1)
            XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Arthur"])
            XCTAssertEqual(recorder.changes.count, 1)
            XCTAssertEqual(recorder.changes[0].record.id, 1)
            XCTAssertEqual(recorder.changes[0].record.name, "Arthur")
            switch recorder.changes[0].event {
            case .Insertion(let indexPath):
                XCTAssertEqual(indexPath, makeIndexPath(forRow: 0, inSection: 0))
            default:
                XCTFail()
            }
        }
    }
    
    func testTrailingClosureCallback() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("name")), compareRecordsByPrimaryKey: true)
            var persons: [Person] = []
            controller.performFetch()
            
            let expectation = expectationWithDescription("expectation")
            controller.trackChanges {
                persons = $0.fetchedRecords!
                expectation.fulfill()
            }
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Arthur")])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            XCTAssertEqual(persons.map { $0.name }, ["Arthur"])
        }
    }
}


// Synchronizes the persons table with a JSON payload
private func synchronizePersons(db: Database, _ newPersons: [Person]) throws {
    // Sort new persons and database persons by id:
    let newPersons = newPersons.sort { $0.id! < $1.id! }
    let databasePersons = Person.fetchAll(db, "SELECT * FROM persons ORDER BY id")
    
    // Now that both lists are sorted by id, we can compare them with
    // the sortedMerge() function.
    //
    // We'll delete, insert or update persons, depending on their presence
    // in either lists.
    for mergeStep in sortedMerge(
        left: databasePersons,
        right: newPersons,
        leftKey: { $0.id! },
        rightKey: { $0.id! })
    {
        switch mergeStep {
        case .Left(let databasePerson):
            try databasePerson.delete(db)
        case .Right(let newPerson):
            try newPerson.insert(db)
        case .Common(_, let newPerson):
            try newPerson.update(db)
        }
    }
}


/// Given two sorted sequences (left and right), this function emits "merge steps"
/// which tell whether elements are only found on the left, on the right, or on
/// both sides.
///
/// Both sequences do not have to share the same element type. Yet elements must
/// share a common comparable *key*.
///
/// Both sequences must be sorted by this key.
///
/// Keys must be unique in both sequences.
///
/// The example below compare two sequences sorted by integer representation,
/// and prints:
///
/// - Left: 1
/// - Common: 2, 2
/// - Common: 3, 3
/// - Right: 4
///
///     for mergeStep in sortedMerge(
///         left: [1,2,3],
///         right: ["2", "3", "4"],
///         leftKey: { $0 },
///         rightKey: { Int($0)! })
///     {
///         switch mergeStep {
///         case .Left(let left):
///             print("- Left: \(left)")
///         case .Right(let right):
///             print("- Right: \(right)")
///         case .Common(let left, let right):
///             print("- Common: \(left), \(right)")
///         }
///     }
///
/// - parameters:
///     - left: The left sequence.
///     - right: The right sequence.
///     - leftKey: A function that returns the key of a left element.
///     - rightKey: A function that returns the key of a right element.
/// - returns: A sequence of MergeStep
private func sortedMerge<LeftSequence: SequenceType, RightSequence: SequenceType, Key: Comparable>(
    left lSeq: LeftSequence,
    right rSeq: RightSequence,
    leftKey: LeftSequence.Generator.Element -> Key,
    rightKey: RightSequence.Generator.Element -> Key) -> AnySequence<MergeStep<LeftSequence.Generator.Element, RightSequence.Generator.Element>>
{
    return AnySequence { () -> AnyGenerator<MergeStep<LeftSequence.Generator.Element, RightSequence.Generator.Element>> in
        var (lGen, rGen) = (lSeq.generate(), rSeq.generate())
        var (lOpt, rOpt) = (lGen.next(), rGen.next())
        return AnyGenerator {
            switch (lOpt, rOpt) {
            case (let lElem?, let rElem?):
                let (lKey, rKey) = (leftKey(lElem), rightKey(rElem))
                if lKey > rKey {
                    rOpt = rGen.next()
                    return .Right(rElem)
                } else if lKey == rKey {
                    (lOpt, rOpt) = (lGen.next(), rGen.next())
                    return .Common(lElem, rElem)
                } else {
                    lOpt = lGen.next()
                    return .Left(lElem)
                }
            case (nil, let rElem?):
                rOpt = rGen.next()
                return .Right(rElem)
            case (let lElem?, nil):
                lOpt = lGen.next()
                return .Left(lElem)
            case (nil, nil):
                return nil
            }
        }
    }
}

/**
 Support for sortedMerge()
 */
private enum MergeStep<LeftElement, RightElement> {
    /// An element only found in the left sequence:
    case Left(LeftElement)
    /// An element only found in the right sequence:
    case Right(RightElement)
    /// Left and right elements share a common key:
    case Common(LeftElement, RightElement)
}
