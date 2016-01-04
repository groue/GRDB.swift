import XCTest
import GRDB


extension Person : Hashable {
    
    var hashValue: Int {
        return self.id.hashValue
    }
}

func ==(lhs: Person, rhs: Person) -> Bool {
    return lhs.id == rhs.id
}

func ==(lhs: FetchedRecordsUpdate<Person>, rhs: FetchedRecordsUpdate<Person>) -> Bool {
    switch (lhs, rhs) {
    case (.Inserted(let lhsPerson, let lhsIndexPath), .Inserted(let rhsPerson, let rhsIndexPath)) where lhsPerson == rhsPerson && lhsIndexPath == rhsIndexPath : return true
    case (.Deleted(let lhsPerson, let lhsIndexPath), .Deleted(let rhsPerson, let rhsIndexPath)) where lhsPerson == rhsPerson && lhsIndexPath == rhsIndexPath : return true
    case (.Moved(let lhsPerson, let lhsFromIndexPath, let lhsToIndexPath), .Moved(let rhsPerson, let rhsFromIndexPath, let rhsToIndexPath)) where lhsPerson == rhsPerson && lhsFromIndexPath == rhsFromIndexPath && lhsToIndexPath == rhsToIndexPath : return true
    case (.Updated(let lhsPerson, let lhsIndexPath, _), .Updated(let rhsPerson, let rhsIndexPath, _)) where lhsPerson == rhsPerson && lhsIndexPath == rhsIndexPath : return true
    default: return false
    }
}


class FetchedRecordsControllerTests: GRDBTestCase, FetchedRecordsControllerDelegate {
    
    var fetchedRecordsController: FetchedRecordsController<Person>!
    
    var willUpdateExpectation: XCTestExpectation?
    var updates = [FetchedRecordsUpdate<Person>]()
    var didFinishUpdatesExpectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons", migrate: Person.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    // MARK: - FetchedRecordsControllerDelegate
    
    func controllerWillUpdate<T>(controller: FetchedRecordsController<T>) {
        willUpdateExpectation?.fulfill()
    }
    
    func controllerUpdate<T>(controller: FetchedRecordsController<T>, update: FetchedRecordsUpdate<T>) {
        switch update {
        case .Inserted(let item, let indexPath):
            XCTAssert(item is Person)
            let person: Person = item as! Person
            updates.append(FetchedRecordsUpdate.Inserted(item: person, at: indexPath))
        case .Deleted(let item, let indexPath):
            XCTAssert(item is Person)
            let person: Person = item as! Person
            updates.append(FetchedRecordsUpdate.Deleted(item: person, at: indexPath))
        case .Moved(let item, let fromIndexPath, let toIndexPath):
            XCTAssert(item is Person)
            let person: Person = item as! Person
            updates.append(FetchedRecordsUpdate.Moved(item: person, from: fromIndexPath, to: toIndexPath))
        case .Updated(let item, let indexPath, let changes):
            XCTAssert(item is Person)
            let person: Person = item as! Person
            updates.append(FetchedRecordsUpdate.Updated(item: person, at: indexPath, changes: changes))
        }
    }
    
    func controllerDidFinishUpdates<T>(controller: FetchedRecordsController<T>) {
        didFinishUpdatesExpectation?.fulfill()
    }

    
    // MARK: - Test fetchedRecords
    
    func testNoFetchedRecordsBeforeFetch() {
        fetchedRecordsController = FetchedRecordsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedRecordsController.delegate = self
        XCTAssert(fetchedRecordsController.fetchedRecords == nil)
    }
    
    func testEmptyFetchedRecordsAfterPerformFetch() {
        fetchedRecordsController = FetchedRecordsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedRecordsController.delegate = self
        fetchedRecordsController.performFetch()
        XCTAssert((fetchedRecordsController.fetchedRecords) != nil)
        XCTAssert(fetchedRecordsController.fetchedRecords!.count == 0)
    }
    
    func testNotEmptyFetchedRecordsAfterPerformFetch() {
        
        fetchedRecordsController = FetchedRecordsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedRecordsController.delegate = self
        fetchedRecordsController.performFetch()
        
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
        fetchedRecordsController.performFetch()
        XCTAssert((fetchedRecordsController.fetchedRecords) != nil)
        XCTAssert(fetchedRecordsController.fetchedRecords!.count == 4)
    }
    
    
    // MARK: - Test delegate callbacks
    
    func testNotificationsOnInsertion() {
        
        fetchedRecordsController = FetchedRecordsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedRecordsController.delegate = self
        fetchedRecordsController.performFetch()
        
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
    
    func testRecordInserted() {
        
        fetchedRecordsController = FetchedRecordsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedRecordsController.delegate = self
        fetchedRecordsController.performFetch()
        
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
        
        // We got 1 Update
        XCTAssert(updates.count == 1)
        let update: FetchedRecordsUpdate<Person> = updates[0]
        switch update {
        case .Inserted(let item, let indexPath):
            let p: Person = item
            XCTAssert(p.name == person.name)
            XCTAssert(p.age == person.age)
            XCTAssert(indexPath == NSIndexPath(indexes: [0,0], length: 2))
        default: XCTFail("unexpected update: \(update)")
        }
    }
    
    func testRecordDeleted() {
        
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
        
        fetchedRecordsController = FetchedRecordsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedRecordsController.delegate = self
        fetchedRecordsController.performFetch()
        
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
        
        // We got 1 Update
        XCTAssert(updates.count == 1)
        let update: FetchedRecordsUpdate<Person> = updates[0]
        switch update {
        case .Deleted(let item, let indexPath):
            let p: Person = item
            XCTAssert(p.name == pascal.name)
            XCTAssert(p.age == pascal.age)
            XCTAssert(indexPath == NSIndexPath(indexes: [0,2], length: 2))
        default: XCTFail("unexpected update: \(update)")
        }
    }

    func testRecordUpdated() {
        
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
        
        fetchedRecordsController = FetchedRecordsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedRecordsController.delegate = self
        fetchedRecordsController.performFetch()
        
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
        
        // We got 1 Update
        XCTAssert(updates.count == 1)
        let update: FetchedRecordsUpdate<Person> = updates[0]
        switch update {
        case .Updated(let item, let indexPath, let changes):
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
    
    func testRecordMoved() {
        /*
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
        
        fetchedRecordsController = FetchedRecordsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedRecordsController.delegate = self
        fetchedRecordsController.performFetch()
        
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
        
        // We got 1 Update
        XCTAssert(updates.count == 1)
        let update: FetchedRecordsUpdate<Person> = updates[0]
        switch update {
        case .Moved(let item, let from, let to):
            let p: Person = item
            XCTAssert(p.name == pascal.name)
            XCTAssert(from == NSIndexPath(indexes: [0,2], length: 2))
            XCTAssert(to == NSIndexPath(indexes: [0,0], length: 2))
        default: XCTFail("unexpected update: \(update)")
        }
        */
    }

}

