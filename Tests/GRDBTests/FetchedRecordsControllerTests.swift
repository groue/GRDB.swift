import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class ChangesRecorder<Record: FetchableRecord> {
    var changes: [ArraySection<FetchedRecordsSectionInfo<Record>, Item<Record>>] = []
    var transactionExpectation: XCTestExpectation? {
        didSet {
            changes = []
        }
    }

    func record(_ changeSet: StagedChangeset<[ArraySection<FetchedRecordsSectionInfo<Record>, Item<Record>>]>) {
        changes.append(contentsOf: changeSet.flatMap { $0.data })
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

extension Person: Hashable {
    static func == (lhs: Person, rhs: Person) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.email == rhs.email && lhs.bookCount == rhs.bookCount
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(email)
        hasher.combine(bookCount)
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
        controller.track { changes in
            recorder.record(changes)
        }
        try controller.performFetch()

        XCTAssertEqual(controller.fetchedRecords.count, 0)

        // First insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes.flatMap { $0.elements }.map { $0.record.name }, ["Arthur"])
        XCTAssertEqual(recorder.changes[0].elements[0].record.id, 1)
        XCTAssertEqual(recorder.changes[0].elements[0].record.name, "Arthur")
        XCTAssertEqual(recorder.changes[0].model.indexPath, IndexPath(indexes: [0, 0]))
        XCTAssertEqual(controller.indexPath(for: Person(id: 1, name: "Arthur")), IndexPath(indexes: [0, 0]))
        
        // Second insert
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Arthur"),
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual(recorder.changes.count, 1)
        XCTAssertEqual(recorder.changes.flatMap { $0.elements }.map { $0.record.name }, ["Arthur", "Barbara"])
        XCTAssertEqual(recorder.changes[0].elements[0].record.id, 1)
        XCTAssertEqual(recorder.changes[0].elements[0].record.name, "Arthur")
        XCTAssertEqual(recorder.changes[0].model.indexPath, IndexPath(indexes: [0, 0]))
        XCTAssertEqual(controller.indexPath(for: Person(id: 2, name: "Barbara")), IndexPath(indexes: [0, 1]))
    }

    func testSimpleUpdate() throws {
        let dbQueue = try makeDatabaseQueue()
        let controller = try FetchedRecordsController(dbQueue, request: Person.order(Column("id")))
        let recorder = ChangesRecorder<Person>()
        controller.track { changes in
            recorder.record(changes)
        }
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

        var recordsBeforeChanges = controller.fetchedRecords
        
        // First update
        recorder.transactionExpectation = expectation(description: "expectation")
        // One change should be recorded
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Craig"),
                Person(id: 2, name: "Barbara")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recordsBeforeChanges.count, 2)
        XCTAssertEqual(recordsBeforeChanges.map { $0.name }, ["Arthur", "Barbara"])
        XCTAssertEqual(controller.fetchedRecords.map { $0.name }, ["Craig", "Barbara"])

        recordsBeforeChanges = controller.fetchedRecords
        
        // Second update
        recorder.transactionExpectation = expectation(description: "expectation")
        try dbQueue.inTransaction { db in
            try synchronizePersons(db, [
                Person(id: 1, name: "Craig"),
                Person(id: 2, name: "Danielle")])
            return .commit
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(recordsBeforeChanges.count, 2)
        XCTAssertEqual(controller.fetchedRecords.map { $0.name }, ["Craig", "Danielle"])
    }

    func testItSupportsMultipleSections() throws {
        let dbQueue = try makeDatabaseQueue()

        try dbQueue.inDatabase { db in
            try Person(name: "Plato").insert(db)
            try Person(name: "Cervantes").insert(db)
            try Person(name: "Carl").insert(db)
        }

        let controller = try FetchedRecordsController(dbQueue, request: Person.all(), sectionColumn: Column("name"))
        try controller.performFetch()

        XCTAssertEqual(controller.sections.count, 2)

        controller.sectionColumn = Column("id")
        try controller.performFetch()

        XCTAssertEqual(controller.sections.count, 3)
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
