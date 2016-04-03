import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

extension Person : Equatable {}
func ==(lhs: Person, rhs: Person) -> Bool {
    return lhs.id == rhs.id
}


class FetchedResultsControllerTests: GRDBTestCase, FetchedResultsControllerDelegate {
    
    var fetchedResultsController: FetchedResultsController<Person>!
    
    var willUpdateExpectation: XCTestExpectation?
    var updates = [Change<Person>]()
    var didFinishUpdatesExpectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons", migrate: Person.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    // MARK: - FetchedResultsControllerDelegate
    
    func controllerWillUpdate<T>(controller: FetchedResultsController<T>) {
        willUpdateExpectation?.fulfill()
    }
    
    func controllerUpdate<T>(controller: FetchedResultsController<T>, update: Change<T>) {
        switch update {
        case .Insertion(let item, let indexPath):
            XCTAssert(item is Person)
            let person: Person = item as! Person
            updates.append(Change.Insertion(item: person, at: indexPath))
        case .Deletion(let item, let indexPath):
            XCTAssert(item is Person)
            let person: Person = item as! Person
            updates.append(Change.Deletion(item: person, at: indexPath))
        case .Move(let item, let fromIndexPath, let toIndexPath):
            XCTAssert(item is Person)
            let person: Person = item as! Person
            updates.append(Change.Move(item: person, from: fromIndexPath, to: toIndexPath))
        case .Update(let item, let indexPath, let changes):
            XCTAssert(item is Person)
            let person: Person = item as! Person
            updates.append(Change.Update(item: person, at: indexPath, changes: changes))
        }
    }
    
    func controllerDidFinishUpdates<T>(controller: FetchedResultsController<T>) {
        didFinishUpdatesExpectation?.fulfill()
    }

    
    // MARK: - Test fetchedResults
    
    func testNoFetchedRecordsBeforeFetch() {
        fetchedResultsController = FetchedResultsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedResultsController.delegate = self
        XCTAssert(fetchedResultsController.fetchedResults == nil)
    }
    
    func testEmptyFetchedRecordsAfterPerformFetch() {
        fetchedResultsController = FetchedResultsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch()
        XCTAssert((fetchedResultsController.fetchedResults) != nil)
        XCTAssert(fetchedResultsController.fetchedResults!.count == 0)
    }
    
    func testNotEmptyFetchedRecordsAfterPerformFetch() {
        
        fetchedResultsController = FetchedResultsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch()
        
        // Insert 4 person
        let pascal = Person(); pascal.name = "Pascal"; pascal.age = 27
        let gwen = Person(); gwen.name = "Gwendal"; gwen.age = 42
        let sylvaine = Person(); sylvaine.name = "Sylvaine"; sylvaine.age = 40
        let fabien = Person(); fabien.name = "Fabien"; fabien.age = 26
        assertNoError {
            try! dbQueue.inDatabase { db in
                try pascal.save(db)
                try gwen.save(db)
                try sylvaine.save(db)
                try fabien.save(db)
            }
        }
        
        // Actuel tests
        fetchedResultsController.performFetch()
        XCTAssert((fetchedResultsController.fetchedResults) != nil)
        XCTAssert(fetchedResultsController.fetchedResults!.count == 4)
    }
    
    
    // MARK: - Test delegate callbacks
    
    func testNotificationsOnInsertion() {
        
        fetchedResultsController = FetchedResultsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch()
        
        let person = Person()
        person.name = "Pascal"
        person.age = 27
        
        willUpdateExpectation = expectationWithDescription("Did receive controllerWillUpdate:")
        didFinishUpdatesExpectation = expectationWithDescription("Did receive controllerDidFinishUpdates:")
        
        // Save person
        assertNoError {
            try! dbQueue.inDatabase { db in
                try person.save(db)
            }
        }
        
        // Did received notifications
        waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    
    // MARK: - Test atomic updates
    
    func testRecordInsertion() {
        
        fetchedResultsController = FetchedResultsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch()
        
        let person = Person()
        person.name = "Pascal"
        person.age = 27
        
        willUpdateExpectation = expectationWithDescription("Did receive controllerWillUpdate:")
        didFinishUpdatesExpectation = expectationWithDescription("Did receive controllerDidFinishUpdates:")

        // Save person
        assertNoError {
            try! dbQueue.inDatabase { db in
                try person.save(db)
            }
        }
        
        // This is used to wait that our delegate calls has been called
        waitForExpectationsWithTimeout(2, handler: nil)
        
        // We got 1 Change
        if (updates.count != 1) {
            XCTFail("Expected updates to contain 1 change")
            return
        }
        let update: Change<Person> = updates[0]
        switch update {
        case .Insertion(let item, let indexPath):
            let p: Person = item
            XCTAssert(p.name == person.name)
            XCTAssert(p.age == person.age)
            XCTAssert(indexPath == NSIndexPath(indexes: [0,0], length: 2))
        default: XCTFail("unexpected update: \(update)")
        }
    }
    
    func testRecordDeletion() {
        
        // Insert 4 person
        let pascal = Person(); pascal.name = "Pascal"; pascal.age = 27
        let gwen = Person(); gwen.name = "Gwendal"; gwen.age = 42
        let sylvaine = Person(); sylvaine.name = "Sylvaine"; sylvaine.age = 40
        let fabien = Person(); fabien.name = "Fabien"; fabien.age = 26
        assertNoError {
            try! dbQueue.inDatabase { db in
                try pascal.save(db)
                try gwen.save(db)
                try sylvaine.save(db)
                try fabien.save(db)
            }
        }
        
        fetchedResultsController = FetchedResultsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch()
        
        willUpdateExpectation = expectationWithDescription("Did receive controllerWillUpdate:")
        didFinishUpdatesExpectation = expectationWithDescription("Did receive controllerDidFinishUpdates:")
        
        // Delete pascal
        assertNoError {
            try! dbQueue.inDatabase { db in
                try pascal.delete(db)
            }
        }
        
        // This is used to wait that our delegate calls has been called
        waitForExpectationsWithTimeout(2, handler: nil)
        
        // We got 1 Change
        if (updates.count != 1) {
            XCTFail("Expected updates to contain 1 change")
            return
        }
        let update: Change<Person> = updates[0]
        switch update {
        case .Deletion(let item, let indexPath):
            let p: Person = item
            XCTAssert(p.name == pascal.name)
            XCTAssert(p.age == pascal.age)
            XCTAssert(indexPath == NSIndexPath(indexes: [0,2], length: 2))
        default: XCTFail("unexpected update: \(update)")
        }
    }

    func testRecordUpdate() {
        
        // Insert 4 person
        let pascal = Person(); pascal.name = "Pascal"; pascal.age = 27
        let gwen = Person(); gwen.name = "Gwendal"; gwen.age = 42
        let sylvaine = Person(); sylvaine.name = "Sylvaine"; sylvaine.age = 40
        let fabien = Person(); fabien.name = "Fabien"; fabien.age = 26
        assertNoError {
            try! dbQueue.inDatabase { db in
                try pascal.save(db)
                try gwen.save(db)
                try sylvaine.save(db)
                try fabien.save(db)
            }
        }
        
        fetchedResultsController = FetchedResultsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch()
        
        willUpdateExpectation = expectationWithDescription("Did receive controllerWillUpdate:")
        didFinishUpdatesExpectation = expectationWithDescription("Did receive controllerDidFinishUpdates:")
        
        // Update pascal
        pascal.age = 29
        assertNoError {
            try! dbQueue.inDatabase { db in
                try pascal.save(db)
            }
        }
        
        // This is used to wait that our delegate calls has been called
        waitForExpectationsWithTimeout(2, handler: nil)
        
        // We got 1 Change
        print(updates)
        if (updates.count != 1) {
            XCTFail("Expected updates to contain 1 change")
            return
        }
        let update: Change<Person> = updates[0]
        switch update {
        case .Update(let item, let indexPath, let changes):
            let p: Person = item
            XCTAssert(p.name == pascal.name)
            XCTAssert(p.age == pascal.age)
            XCTAssert(indexPath == NSIndexPath(indexes: [0,2], length: 2))
            XCTAssert(changes != nil)
            XCTAssert(changes!.count == 1)
            XCTAssert(changes!["age"] != nil)
        default: XCTFail("unexpected update: \(update)")
        }
    }
    
    func testRecordMove() {
        // Insert 4 person
        let pascal = Person(); pascal.name = "Pascal"; pascal.age = 27
        let gwen = Person(); gwen.name = "Gwendal"; gwen.age = 42
        let sylvaine = Person(); sylvaine.name = "Sylvaine"; sylvaine.age = 40
        let fabien = Person(); fabien.name = "Fabien"; fabien.age = 26
        assertNoError {
            try! dbQueue.inDatabase { db in
                try pascal.save(db)
                try gwen.save(db)
                try sylvaine.save(db)
                try fabien.save(db)
            }
        }
        
        fetchedResultsController = FetchedResultsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch()
        
        willUpdateExpectation = expectationWithDescription("Did receive controllerWillUpdate:")
        didFinishUpdatesExpectation = expectationWithDescription("Did receive controllerDidFinishUpdates:")
        
        // Update pascal'name to move it
        pascal.name = "Alfred"
        assertNoError {
            try! dbQueue.inDatabase { db in
                try pascal.save(db)
            }
        }
        
        // This is used to wait that our delegate calls has been called
        waitForExpectationsWithTimeout(2, handler: nil)
        
        // We got 1 Change
        if (updates.count != 1) {
            XCTFail("Expected updates to contain 1 change")
            return
        }
        let update: Change<Person> = updates[0]
        switch update {
        case .Move(let item, let from, let to):
            let p: Person = item
            XCTAssert(p.name == pascal.name)
            XCTAssert(from == NSIndexPath(indexes: [0,2], length: 2))
            XCTAssert(to == NSIndexPath(indexes: [0,0], length: 2))
        default: XCTFail("unexpected update: \(update)")
        }
    }
}

