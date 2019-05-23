import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class ChangesRecorder<Record: FetchableRecord> {
    var changes: [(record: Record, change: FetchedRecordChange)] = []
    var recordsBeforeChanges: [Record]!
    var recordsAfterChanges: [Record]!
    var countBeforeChanges: Int?
    var countAfterChanges: Int?
    var recordsOnFirstEvent: [Record]!
    var transactionExpectation: XCTestExpectation? {
        didSet {
            changes = []
            recordsBeforeChanges = nil
            recordsAfterChanges = nil
            countBeforeChanges = nil
            countAfterChanges = nil
            recordsOnFirstEvent = nil
        }
    }
    
    func controllerWillChange(_ controller: FetchedRecordsController<Record>, count: Int? = nil) {
        recordsBeforeChanges = controller.fetchedRecords
        countBeforeChanges = count
    }
    
    /// The default implementation does nothing.
    func controller(_ controller: FetchedRecordsController<Record>, didChangeRecord record: Record, with change: FetchedRecordChange) {
        if recordsOnFirstEvent == nil {
            recordsOnFirstEvent = controller.fetchedRecords
        }
        changes.append((record: record, change: change))
    }
    
    /// The default implementation does nothing.
    func controllerDidChange(_ controller: FetchedRecordsController<Record>, count: Int? = nil) {
        recordsAfterChanges = controller.fetchedRecords
        countAfterChanges = count
        if let transactionExpectation = transactionExpectation {
            transactionExpectation.fulfill()
        }
    }
}

private class Person : Record {
    var id: Int64?
    let name: String
    let email: String?
    let bookCount: Int?
    
    init(id: Int64? = nil, name: String, email: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.bookCount = nil
        super.init()
    }
    
    required init(row: Row) {
        id = row["id"]
        name = row["name"]
        email = row["email"]
        bookCount = row["bookCount"]
        super.init(row: row)
    }
    
    override class var databaseTableName: String {
        return "persons"
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["email"] = email
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct Book : FetchableRecord {
    var id: Int64
    var authorID: Int64
    var title: String
    
    init(row: Row) {
        id = row["id"]
        authorID = row["authorID"]
        title = row["title"]
    }
}

class FetchedRecordsControllerTests: GRDBTestCase {

    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
                t.column("email", .text)
            }
            try db.create(table: "books") { t in
                t.column("id", .integer).primaryKey()
                t.column("authorId", .integer).notNull().references("persons", onDelete: .cascade, onUpdate: .cascade)
                t.column("title", .text)
            }
            try db.create(table: "flowers") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
        }
    }
    
    func testControllerFromSQL() throws {
        let dbQueue = try makeDatabaseQueue()
        let authorId: Int64 = try dbQueue.inDatabase { db in
            let plato = Person(name: "Plato")
            try plato.insert(db)
            try db.execute(sql: "INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [plato.id, "Symposium"])
            let cervantes = Person(name: "Cervantes")
            try cervantes.insert(db)
            try db.execute(sql: "INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [cervantes.id, "Don Quixote"])
            return cervantes.id!
        }
        
        let controller = try FetchedRecordsController<Book>(dbQueue, sql: "SELECT * FROM books WHERE authorID = ?", arguments: [authorId])
        try controller.performFetch()
        XCTAssertEqual(controller.fetchedRecords.count, 1)
        XCTAssertEqual(controller.fetchedRecords[0].title, "Don Quixote")
    }

    func testControllerFromSQLWithAdapter() throws {
        let dbQueue = try makeDatabaseQueue()
        let authorId: Int64 = try dbQueue.inDatabase { db in
            let plato = Person(name: "Plato")
            try plato.insert(db)
            try db.execute(sql: "INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [plato.id, "Symposium"])
            let cervantes = Person(name: "Cervantes")
            try cervantes.insert(db)
            try db.execute(sql: "INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [cervantes.id, "Don Quixote"])
            return cervantes.id!
        }
        
        let adapter = ColumnMapping(["id": "_id", "authorId": "_authorId", "title": "_title"])
        let controller = try FetchedRecordsController<Book>(dbQueue, sql: "SELECT id AS _id, authorId AS _authorId, title AS _title FROM books WHERE authorID = ?", arguments: [authorId], adapter: adapter)
        try controller.performFetch()
        XCTAssertEqual(controller.fetchedRecords.count, 1)
        XCTAssertEqual(controller.fetchedRecords[0].title, "Don Quixote")
    }

    func testControllerFromRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(name: "Plato").insert(db)
            try Person(name: "Cervantes").insert(db)
        }
        
        let request = Person.order(Column("name"))
        let controller = try FetchedRecordsController(dbQueue, request: request)
        try controller.performFetch()
        XCTAssertEqual(controller.fetchedRecords.count, 2)
        XCTAssertEqual(controller.fetchedRecords[0].name, "Cervantes")
        XCTAssertEqual(controller.fetchedRecords[1].name, "Plato")
    }

    func testSections() throws {
        let dbQueue = try makeDatabaseQueue()
        let arthur = Person(name: "Arthur")
        try dbQueue.inDatabase { db in
            try arthur.insert(db)
        }
        
        let request = Person.all()
        let controller = try FetchedRecordsController(dbQueue, request: request)
        try controller.performFetch()
        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].numberOfRecords, 1)
        XCTAssertEqual(controller.sections[0].records.count, 1)
        XCTAssertEqual(controller.sections[0].records[0].name, "Arthur")
        XCTAssertEqual(controller.fetchedRecords.count, 1)
        XCTAssertEqual(controller.fetchedRecords[0].name, "Arthur")
        XCTAssertEqual(controller.record(at: IndexPath(indexes: [0, 0])).name, "Arthur")
        XCTAssertEqual(controller.indexPath(for: arthur), IndexPath(indexes: [0, 0]))
    }

    func testEmptyRequestGivesOneSection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Person.all()
        let controller = try FetchedRecordsController(dbQueue, request: request)
        try controller.performFetch()
        XCTAssertEqual(controller.fetchedRecords.count, 0)
        
        // Just like NSFetchedResultsController
        XCTAssertEqual(controller.sections.count, 1)
    }

    func testDatabaseChangesAreNotReReflectedUntilPerformFetchAndDelegateIsSet() {
        // TODO: test that controller.fetchedRecords does not eventually change
        // after a database change. The difficulty of this test lies in the
        // "eventually" word.
    }

    func testSimpleInsert() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.order(Column("id")))
        let recorder = ChangesRecorder<Person>()
        controller.trackChanges(
            willChange: { recorder.controllerWillChange($0) },
            onChange: { (controller, record, change) in recorder.controller(controller, didChangeRecord: record, with: change) },
            didChange: { recorder.controllerDidChange($0) })
        try controller.performFetch()
        
        // First insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 0)
        XCTAssertEqual(recorder.recordsOnFirstEvent.count, 1)
        XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Arthur"])
        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes[0].record.id, 1)
        XCTAssertEqual(recorder.changes[0].record.name, "Arthur")
        switch recorder.changes[0].change {
        case .insertion(let indexPath):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 0]))
        default:
            XCTFail()
        }
        
        // Second insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur"),
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 1)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur"])
        XCTAssertEqual(recorder.recordsOnFirstEvent.count, 2)
        XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Arthur", "Barbara"])
        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes[0].record.id, 2)
        XCTAssertEqual(recorder.changes[0].record.name, "Barbara")
        switch recorder.changes[0].change {
        case .insertion(let indexPath):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 1]))
        default:
            XCTFail()
        }
    }

    func testSimpleUpdate() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.order(Column("id")))
        let recorder = ChangesRecorder<Person>()
        controller.trackChanges(
            willChange: { recorder.controllerWillChange($0) },
            onChange: { (controller, record, change) in recorder.controller(controller, didChangeRecord: record, with: change) },
            didChange: { recorder.controllerDidChange($0) })
        try controller.performFetch()
        
        // Insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur"),
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // First update
        recorder.transactionExpectation = expectation(description: "expectation")
        // No change should be recorded
        try dbQueue.inTransaction { db in
            try db.execute(sql: "UPDATE persons SET name = ? WHERE id = ?", arguments: ["Arthur", 1])
            return .commit
        }
        // One change should be recorded
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Craig"),
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
        XCTAssertEqual(recorder.recordsOnFirstEvent.count, 2)
        XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Craig", "Barbara"])
        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes[0].record.id, 1)
        XCTAssertEqual(recorder.changes[0].record.name, "Craig")
        switch recorder.changes[0].change {
        case .update(let indexPath, let changes):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 0]))
            XCTAssertEqual(changes, ["name": "Arthur".databaseValue])
        default:
            XCTFail()
        }
        
        // Second update
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Craig"),
                Person(id: 2, name: "Danielle")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Craig", "Barbara"])
        XCTAssertEqual(recorder.recordsOnFirstEvent.count, 2)
        XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Craig", "Danielle"])
        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes[0].record.id, 2)
        XCTAssertEqual(recorder.changes[0].record.name, "Danielle")
        switch recorder.changes[0].change {
        case .update(let indexPath, let changes):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 1]))
            XCTAssertEqual(changes, ["name": "Barbara".databaseValue])
        default:
            XCTFail()
        }
    }

    func testSimpleDelete() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.order(Column("id")))
        let recorder = ChangesRecorder<Person>()
        controller.trackChanges(
            willChange: { recorder.controllerWillChange($0) },
            onChange: { (controller, record, change) in recorder.controller(controller, didChangeRecord: record, with: change) },
            didChange: { recorder.controllerDidChange($0) })
        try controller.performFetch()
        
        // Insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur"),
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // First delete
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
        XCTAssertEqual(recorder.recordsOnFirstEvent.count, 1)
        XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Barbara"])
        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes[0].record.id, 1)
        XCTAssertEqual(recorder.changes[0].record.name, "Arthur")
        switch recorder.changes[0].change {
        case .deletion(let indexPath):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 0]))
        default:
            XCTFail()
        }
        
        // Second delete
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 1)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Barbara"])
        XCTAssertEqual(recorder.recordsOnFirstEvent.count, 0)
        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes[0].record.id, 2)
        XCTAssertEqual(recorder.changes[0].record.name, "Barbara")
        switch recorder.changes[0].change {
        case .deletion(let indexPath):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 0]))
        default:
            XCTFail()
        }
    }

    func testSimpleMove() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.order(Column("name")))
        let recorder = ChangesRecorder<Person>()
        controller.trackChanges(
            willChange: { recorder.controllerWillChange($0) },
            onChange: { (controller, record, change) in recorder.controller(controller, didChangeRecord: record, with: change) },
            didChange: { recorder.controllerDidChange($0) })
        try controller.performFetch()
        
        // Insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur"),
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // Move
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Craig"),
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
        XCTAssertEqual(recorder.recordsOnFirstEvent.count, 2)
        XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Barbara", "Craig"])
        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes[0].record.id, 1)
        XCTAssertEqual(recorder.changes[0].record.name, "Craig")
        switch recorder.changes[0].change {
        case .move(let indexPath, let newIndexPath, let changes):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 0]))
            XCTAssertEqual(newIndexPath, IndexPath(indexes: [0, 1]))
            XCTAssertEqual(changes, ["name": "Arthur".databaseValue])
        default:
            XCTFail()
        }
    }

    func testSideTableChange() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController<Person>(
            dbQueue,
            sql: """
                SELECT persons.*, COUNT(books.id) AS bookCount
                FROM persons
                LEFT JOIN books ON books.authorId = persons.id
                GROUP BY persons.id
                ORDER BY persons.name
                """)
        let recorder = ChangesRecorder<Person>()
        controller.trackChanges(
            willChange: { recorder.controllerWillChange($0) },
            onChange: { (controller, record, change) in recorder.controller(controller, didChangeRecord: record, with: change) },
            didChange: { recorder.controllerDidChange($0) })
        try controller.performFetch()
        
        // Insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
            try db.execute(sql: "INSERT INTO books (authorId, title) VALUES (?, ?)", arguments: [1, "Moby Dick"])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // Change books
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try db.execute(sql: "DELETE FROM books")
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
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
        switch recorder.changes[0].change {
        case .update(let indexPath, let changes):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 0]))
            XCTAssertEqual(changes, ["bookCount": 1.databaseValue])
        default:
            XCTFail()
        }
    }

    func testComplexChanges() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.order(Column("name")))
        let recorder = ChangesRecorder<Person>()
        controller.trackChanges(
            willChange: { recorder.controllerWillChange($0) },
            onChange: { (controller, record, change) in recorder.controller(controller, didChangeRecord: record, with: change) },
            didChange: { recorder.controllerDidChange($0) })
        try controller.performFetch()
        
        enum EventTest {
            case I(String, Int) // insert string at index
            case M(String, Int, Int, String) // move string from index to index with changed string
            case D(String, Int) // delete string at index
            case U(String, Int, String) // update string at index with changed string
            
            func match(name: String, event: FetchedRecordChange) -> Bool {
                switch self {
                case .I(let s, let i):
                    switch event {
                    case .insertion(let indexPath):
                        return s == name && i == indexPath[1]
                    default:
                        return false
                    }
                case .M(let s, let i, let j, let c):
                    switch event {
                    case .move(let indexPath, let newIndexPath, let changes):
                        return s == name && i == indexPath[1] && j == newIndexPath[1] && c == String.fromDatabaseValue(changes["name"]!)!
                    default:
                        return false
                    }
                case .D(let s, let i):
                    switch event {
                    case .deletion(let indexPath):
                        return s == name && i == indexPath[1]
                    default:
                        return false
                    }
                case .U(let s, let i, let c):
                    switch event {
                    case .update(let indexPath, let changes):
                        return s == name && i == indexPath[1] && c == String.fromDatabaseValue(changes["name"]!)!
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
            recorder.transactionExpectation = expectation(description: "expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, step.word.enumerated().map { Person(id: Int64($0), name: String($1)) })
                return .commit
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(recorder.changes.count, step.events.count)
            for (change, event) in zip(recorder.changes, step.events) {
                XCTAssertTrue(event.match(name: change.record.name, event: change.change))
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

    func testRequestChange() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.order(Column("name")))
        let recorder = ChangesRecorder<Person>()
        controller.trackChanges(
            willChange: { recorder.controllerWillChange($0) },
            onChange: { (controller, record, change) in recorder.controller(controller, didChangeRecord: record, with: change) },
            didChange: { recorder.controllerDidChange($0) })
        try controller.performFetch()
        
        // Insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur"),
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // Change request with Request
        recorder.transactionExpectation = expectation(description: "expectation")
        try controller.setRequest(Person.order(Column("name").desc))
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
        XCTAssertEqual(recorder.recordsOnFirstEvent.count, 2)
        XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Barbara", "Arthur"])
        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes[0].record.id, 2)
        XCTAssertEqual(recorder.changes[0].record.name, "Barbara")
        switch recorder.changes[0].change {
        case .move(let indexPath, let newIndexPath, let changes):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 1]))
            XCTAssertEqual(newIndexPath, IndexPath(indexes: [0, 0]))
            XCTAssertTrue(changes.isEmpty)
        default:
            XCTFail()
        }
        
        // Change request with SQL and arguments
        recorder.transactionExpectation = expectation(description: "expectation")
        try controller.setRequest(sql: "SELECT ? AS id, ? AS name", arguments: [1, "Craig"])
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Barbara", "Arthur"])
        XCTAssertEqual(recorder.recordsOnFirstEvent.count, 1)
        XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Craig"])
        XCTAssertEqual(recorder.changes.count, 2)
        XCTAssertEqual(recorder.changes[0].record.id, 2)
        XCTAssertEqual(recorder.changes[0].record.name, "Barbara")
        XCTAssertEqual(recorder.changes[1].record.id, 1)
        XCTAssertEqual(recorder.changes[1].record.name, "Craig")
        switch recorder.changes[0].change {
        case .deletion(let indexPath):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 0]))
        default:
            XCTFail()
        }
        switch recorder.changes[1].change {
        case .move(let indexPath, let newIndexPath, let changes):
            // TODO: is it really what we should expect? Wouldn't an update fit better?
            // What does UITableView think?
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 1]))
            XCTAssertEqual(newIndexPath, IndexPath(indexes: [0, 0]))
            XCTAssertEqual(changes, ["name": "Arthur".databaseValue])
        default:
            XCTFail()
        }
        
        // Change request with a different set of tracked columns
        recorder.transactionExpectation = expectation(description: "expectation")
        try controller.setRequest(Person.select(Column("id"), Column("name"), Column("email")).order(Column("name")))
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 1)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Craig"])
        XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
        XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur", "Barbara"])
        
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try db.execute(sql: "UPDATE persons SET email = ? WHERE name = ?", arguments: ["arthur@example.com", "Arthur"])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
        XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
        XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur", "Barbara"])
        
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try db.execute(sql: "UPDATE PERSONS SET EMAIL = ? WHERE NAME = ?", arguments: ["barbara@example.com", "Barbara"])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
        XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
        XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur", "Barbara"])
    }

    func testSetCallbacksAfterUpdate() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.order(Column("name")))
        let recorder = ChangesRecorder<Person>()
        try controller.performFetch()
        
        // Insert
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur")])
            return .commit
        }
        
        // Set callbacks
        recorder.transactionExpectation = expectation(description: "expectation")
        controller.trackChanges(
            willChange: { recorder.controllerWillChange($0) },
            onChange: { (controller, record, change) in recorder.controller(controller, didChangeRecord: record, with: change) },
            didChange: { recorder.controllerDidChange($0) })
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 0)
        XCTAssertEqual(recorder.recordsOnFirstEvent.count, 1)
        XCTAssertEqual(recorder.recordsOnFirstEvent.map { $0.name }, ["Arthur"])
        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes[0].record.id, 1)
        XCTAssertEqual(recorder.changes[0].record.name, "Arthur")
        switch recorder.changes[0].change {
        case .insertion(let indexPath):
            XCTAssertEqual(indexPath, IndexPath(indexes: [0, 0]))
        default:
            XCTFail()
        }
    }

    func testTrailingClosureCallback() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.order(Column("name")))
        var persons: [Person] = []
        try controller.performFetch()
        
        let expectation = self.expectation(description: "expectation")
        controller.trackChanges {
            persons = $0.fetchedRecords
            expectation.fulfill()
        }
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(persons.map { $0.name }, ["Arthur"])
    }

    func testFetchAlongside() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.order(Column("id")))
        let recorder = ChangesRecorder<Person>()
        controller.trackChanges(
            fetchAlongside: { db in try Person.fetchCount(db) },
            willChange: { (controller, count) in recorder.controllerWillChange(controller, count: count) },
            onChange: { (controller, record, change) in recorder.controller(controller, didChangeRecord: record, with: change) },
            didChange: { (controller, count) in recorder.controllerDidChange(controller, count: count) })
        try controller.performFetch()
        
        // First insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 0)
        XCTAssertEqual(recorder.recordsAfterChanges.count, 1)
        XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur"])
        XCTAssertEqual(recorder.countBeforeChanges!, 1)
        XCTAssertEqual(recorder.countAfterChanges!, 1)
        
        // Second insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur"),
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recorder.recordsBeforeChanges.count, 1)
        XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur"])
        XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
        XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur", "Barbara"])
        XCTAssertEqual(recorder.countBeforeChanges!, 2)
        XCTAssertEqual(recorder.countAfterChanges!, 2)
    }

    func testFetchErrors() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.all())
        
        let expectation = self.expectation(description: "expectation")
        var error: Error?
        controller.trackErrors {
            error = $1
            expectation.fulfill()
        }
        controller.trackChanges { _ in }
        try controller.performFetch()
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur")])
            try db.drop(table: "persons")
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        if let error = error as? DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssertEqual(error.message, "no such table: persons")
            XCTAssertEqual(error.sql!, "SELECT * FROM \"persons\"")
            XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT * FROM \"persons\"`: no such table: persons")
        } else {
            XCTFail("Expected DatabaseError")
        }
    }
    
    func testObservationOfSpecificRowIds() throws {
        let dbQueue = try makeDatabaseQueue()
        
        let generalController = try FetchedRecordsController(dbQueue, request: Person.all())
        let specificController = try FetchedRecordsController(dbQueue, request: Person.filter(key: 1))

        let generalExpectation = expectation(description: "expectation")
        generalExpectation.expectedFulfillmentCount = 6
        var generalChangeCount = 0
        generalController.trackChanges(onChange: { (_, _, _) in
            generalChangeCount += 1
            generalExpectation.fulfill()
        })
        try generalController.performFetch()

        let specificExpectation = expectation(description: "expectation")
        specificExpectation.expectedFulfillmentCount = 3
        var specificChangeCount = 0
        specificController.trackChanges(onChange: { (_, _, _) in
            specificChangeCount += 1
            specificExpectation.fulfill()
        })
        try specificController.performFetch()

        try dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "INSERT INTO persons (id, name) VALUES (?, ?)", arguments: [1, "Arthur"])
            try db.execute(sql: "INSERT INTO persons (id, name) VALUES (?, ?)", arguments: [2, "Barbara"])
            try db.execute(sql: "UPDATE persons SET name = ? WHERE id = ?", arguments: ["Craig", 1])
            try db.execute(sql: "UPDATE persons SET name = ? WHERE id = ?", arguments: ["David", 2])
            try db.execute(sql: "DELETE FROM persons")
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(generalChangeCount, 6)
        XCTAssertEqual(specificChangeCount, 3)
    }
}


// Synchronizes the persons table with a JSON payload
private func synchronizePersons(_ db: Database, _ newPersons: [Person]) throws {
    // Sort new persons and database persons by id:
    let newPersons = newPersons.sorted { $0.id! < $1.id! }
    let databasePersons = try Person.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
    
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
        case .left(let databasePerson):
            try databasePerson.delete(db)
        case .right(let newPerson):
            try newPerson.insert(db)
        case .common(_, let newPerson):
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
///         case .left(let left):
///             print("- Left: \(left)")
///         case .right(let right):
///             print("- Right: \(right)")
///         case .common(let left, let right):
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
private func sortedMerge<LeftSequence: Sequence, RightSequence: Sequence, Key: Comparable>(
    left lSeq: LeftSequence,
    right rSeq: RightSequence,
    leftKey: @escaping (LeftSequence.Element) -> Key,
    rightKey: @escaping (RightSequence.Element) -> Key) -> AnySequence<MergeStep<LeftSequence.Element, RightSequence.Element>>
{
    return AnySequence { () -> AnyIterator<MergeStep<LeftSequence.Element, RightSequence.Element>> in
        var (lGen, rGen) = (lSeq.makeIterator(), rSeq.makeIterator())
        var (lOpt, rOpt) = (lGen.next(), rGen.next())
        return AnyIterator {
            switch (lOpt, rOpt) {
            case (let lElem?, let rElem?):
                let (lKey, rKey) = (leftKey(lElem), rightKey(rElem))
                if lKey > rKey {
                    rOpt = rGen.next()
                    return .right(rElem)
                } else if lKey == rKey {
                    (lOpt, rOpt) = (lGen.next(), rGen.next())
                    return .common(lElem, rElem)
                } else {
                    lOpt = lGen.next()
                    return .left(lElem)
                }
            case (nil, let rElem?):
                rOpt = rGen.next()
                return .right(rElem)
            case (let lElem?, nil):
                lOpt = lGen.next()
                return .left(lElem)
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
    case left(LeftElement)
    /// An element only found in the right sequence:
    case right(RightElement)
    /// Left and right elements share a common key:
    case common(LeftElement, RightElement)
}
