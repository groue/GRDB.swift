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
        
        fetchedRecordsController = FetchedRecordsController(sql: "SELECT * FROM persons ORDER BY LOWER(name)", databaseQueue: dbQueue)
        fetchedRecordsController.delegate = self
        fetchedRecordsController.performFetch()
    }
    
    // MARK: - FetchedRecordsControllerDelegate
    
    func controllerWillUpdate<T>(controller: FetchedRecordsController<T>) {
        willUpdateExpectation?.fulfill()
    }
    
    func controllerUpdate<T>(controller: FetchedRecordsController<T>, update: FetchedRecordsUpdate<T>) {
        updates.append(update)
    }
    
    func controllerDidFinishUpdates<T>(controller: FetchedRecordsController<T>) {
        didFinishUpdatesExpectation?.fulfill()
    }

    // MARK: - Tests
    
    func testNotificationsOnInsertion() {
        
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
    
    func testUpdateOnInsertion() {
        
        let person = Person()
        person.name = "Pascal"
        person.age = 27
        
        // Save person
        assertNoError {
            try! dbQueue.inDatabase { db in
                try person.save(db)
            }
        }
        
        // Update
        XCTAssert(updates.count == 1)
    }
}

