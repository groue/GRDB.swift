import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class ChangesRecorder<Record: RowConvertible> {
    var recordsBeforeChanges: [Record]!
    var recordsAfterChanges: [Record]!
    var countBeforeChanges: Int?
    var countAfterChanges: Int?
    var transactionExpectation: XCTestExpectation? {
        didSet {
            recordsBeforeChanges = nil
            recordsAfterChanges = nil
            countBeforeChanges = nil
            countAfterChanges = nil
        }
    }
    
    func controllerWillChange(controller: FetchedRecordsController<Record>, count: Int? = nil) {
        recordsBeforeChanges = controller.fetchedRecords
        countBeforeChanges = count
    }
    
    /// The default implementation does nothing.
    func controllerDidChange(controller: FetchedRecordsController<Record>, count: Int? = nil) {
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

struct Book : RowConvertible {
    var id: Int64
    var authorID: Int64
    var title: String
    
    init(_ row: Row) {
        id = row.value(named: "id")
        authorID = row.value(named: "authorID")
        title = row.value(named: "title")
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
                    "authorId INTEGER NOT NULL REFERENCES persons(id) ON DELETE CASCADE ON UPDATE CASCADE," +
                    "title TEXT" +
                ")")
            try db.execute(
                "CREATE TABLE flowers (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name TEXT" +
                ")")
        }
    }
    
    func testControllerFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let authorId: Int64 = try dbQueue.inDatabase { db in
                let plato = Person(name: "Plato")
                try plato.insert(db)
                try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [plato.id, "Symposium"])
                let cervantes = Person(name: "Cervantes")
                try cervantes.insert(db)
                try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [cervantes.id, "Don Quixote"])
                return cervantes.id!
            }
            
            let controller = FetchedRecordsController<Book>(dbQueue, sql: "SELECT * FROM books WHERE authorID = ?", arguments: [authorId])
            controller.performFetch()
            XCTAssertEqual(controller.fetchedRecords!.count, 1)
            XCTAssertEqual(controller.fetchedRecords![0].title, "Don Quixote")
        }
    }
    
    func testControllerFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let authorId: Int64 = try dbQueue.inDatabase { db in
                let plato = Person(name: "Plato")
                try plato.insert(db)
                try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [plato.id, "Symposium"])
                let cervantes = Person(name: "Cervantes")
                try cervantes.insert(db)
                try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [cervantes.id, "Don Quixote"])
                return cervantes.id!
            }
            
            let adapter = ColumnMapping(["id": "_id", "authorId": "_authorId", "title": "_title"])
            let controller = FetchedRecordsController<Book>(dbQueue, sql: "SELECT id AS _id, authorId AS _authorId, title AS _title FROM books WHERE authorID = ?", arguments: [authorId], adapter: adapter)
            controller.performFetch()
            XCTAssertEqual(controller.fetchedRecords!.count, 1)
            XCTAssertEqual(controller.fetchedRecords![0].title, "Don Quixote")
        }
    }
    
    func testControllerFromFetchRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try Person(name: "Plato").insert(db)
                try Person(name: "Cervantes").insert(db)
            }
            
            let request = Person.order(SQLColumn("name"))
            let controller = FetchedRecordsController<Person>(dbQueue, request: request)
            controller.performFetch()
            XCTAssertEqual(controller.fetchedRecords!.count, 2)
            XCTAssertEqual(controller.fetchedRecords![0].name, "Cervantes")
            XCTAssertEqual(controller.fetchedRecords![1].name, "Plato")
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
            XCTAssertEqual(recorder.recordsAfterChanges.count, 1)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur"])
            
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
            XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur", "Barbara"])
        }
    }
    
    func testSimpleUpdate() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("id")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
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
            XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Craig", "Barbara"])
            
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
            XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Craig", "Danielle"])
        }
    }
    
    func testSimpleDelete() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("id")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
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
            XCTAssertEqual(recorder.recordsAfterChanges.count, 1)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Barbara"])
            
            // Second delete
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [])
                return .Commit
            }
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 1)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Barbara"])
            XCTAssertEqual(recorder.recordsAfterChanges.count, 0)
        }
    }
    
    func testSimpleMove() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("name")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
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
            XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Barbara", "Craig"])
        }
    }
    
    func testSideTableChange() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(
                dbQueue,
                sql: ("SELECT persons.*, COUNT(books.id) AS bookCount " +
                    "FROM persons " +
                    "LEFT JOIN books ON books.authorID = persons.id " +
                    "GROUP BY persons.id " +
                    "ORDER BY persons.name"),
                compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                recordsWillChange: { recorder.controllerWillChange($0) },
                recordsDidChange: { recorder.controllerDidChange($0) })
            controller.performFetch()
            
            // Insert
            recorder.transactionExpectation = expectationWithDescription("expectation")
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Herman Melville"])
                try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [1, "Moby-Dick"])
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
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Herman Melville"])
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.bookCount! }, [1])
            XCTAssertEqual(recorder.recordsAfterChanges.count, 1)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Herman Melville"])
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.bookCount! }, [0])
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
            XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Barbara", "Arthur"])
            
            // Change request with SQL and arguments
            recorder.transactionExpectation = expectationWithDescription("expectation")
            controller.setRequest(sql: "SELECT ? AS id, ? AS name", arguments: [1, "Craig"])
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 2)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Barbara", "Arthur"])
            XCTAssertEqual(recorder.recordsAfterChanges.count, 1)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Craig"])
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
                recordsDidChange: { recorder.controllerDidChange($0) })
            waitForExpectationsWithTimeout(1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 0)
            XCTAssertEqual(recorder.recordsAfterChanges.count, 1)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur"])
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
    
    func testFetchAlongside() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let controller = FetchedRecordsController<Person>(dbQueue, request: Person.order(SQLColumn("id")), compareRecordsByPrimaryKey: true)
            let recorder = ChangesRecorder<Person>()
            controller.trackChanges(
                fetchAlongside: { db in Person.fetchCount(db) },
                recordsWillChange: { (controller, count) in recorder.controllerWillChange(controller, count: count) },
                recordsDidChange: { (controller, count) in recorder.controllerDidChange(controller, count: count) })
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
            XCTAssertEqual(recorder.recordsAfterChanges.count, 1)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur"])
            XCTAssertEqual(recorder.countBeforeChanges!, 1)
            XCTAssertEqual(recorder.countAfterChanges!, 1)
            
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
            XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur", "Barbara"])
            XCTAssertEqual(recorder.countBeforeChanges!, 2)
            XCTAssertEqual(recorder.countAfterChanges!, 2)
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
