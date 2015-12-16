import XCTest
import GRDB

class IntegerPropertyOnRealAffinityColumn : Record {
    var value: Int!
    
    init(value: Int?) {
        self.value = value
        super.init()
    }
    
    // Record
    
    required init(_ row: Row) {
        value = row.value(named: "value")
        super.init(row)
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["value": value]
    }
}

class RecordEditedTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson", migrate: Person.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    
    func testRecordIsEditedAfterInit() {
        // Create a Record. No fetch has happen, so we don't know if it is
        // identical to its eventual row in the database. So it is edited.
        let person = Person(name: "Arthur", age: 41)
        XCTAssertTrue(person.databaseEdited)
    }
    
    func testRecordIsEditedAfterInitFromRow() {
        // Create a Record from a row. The row may not come from the database.
        // So it is edited.
        let row = Row(dictionary: ["name": "Arthur", "age": 41])
        let person = Person(row)
        XCTAssertTrue(person.databaseEdited)
    }
    
    func testRecordIsNotEditedAfterFullFetch() {
        // Fetch a record from a row that contains all the columns in
        // storedDatabaseDictionary: An update statement, which only saves the
        // columns in storedDatabaseDictionary would perform no change. So the
        // record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person = Person.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertFalse(person.databaseEdited)
            }
        }
    }
    
    func testRecordIsNotEditedAfterFullFetchWithIntegerPropertyOnRealAffinityColumn() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE t (value REAL)")
                try db.execute("INSERT INTO t (value) VALUES (1)")
                
                // Load a double...
                let row1 = Row.fetchOne(db, "SELECT * FROM t")!
                switch row1["value"]!.storage {
                case .Double(let double):
                    XCTAssertEqual(double, 1.0)
                default:
                    XCTFail("Unexpected DatabaseValue")
                }
                
                // Compare to an Int
                let record = IntegerPropertyOnRealAffinityColumn.fetchOne(db, "SELECT * FROM t")!
                let row2 = Row(dictionary: record.storedDatabaseDictionary)
                switch row2["value"]!.storage {
                case .Int64(let int64):
                    XCTAssertEqual(int64, 1)
                default:
                    XCTFail("Unexpected DatabaseValue")
                }
                
                XCTAssertFalse(record.databaseEdited)
            }
        }
    }
    
    func testRecordIsNotEditedAfterWiderThanFullFetch() {
        // Fetch a record from a row that contains all the columns in
        // storedDatabaseDictionary, plus extra ones: An update statement,
        // which only saves the columns in storedDatabaseDictionary would
        // perform no change. So the record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person = Person.fetchOne(db, "SELECT *, 1 AS foo FROM persons")!
                XCTAssertFalse(person.databaseEdited)
            }
        }
    }
    
    func testRecordIsEditedAfterPartialFetch() {
        // Fetch a record from a row that does not contain all the columns in
        // storedDatabaseDictionary: An update statement saves the columns in
        // storedDatabaseDictionary, so it may perform unpredictable change.
        // So the record is edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person =  Person.fetchOne(db, "SELECT name FROM persons")!
                XCTAssertTrue(person.databaseEdited)
            }
        }
    }
    
    func testRecordIsNotEditedAfterInsert() {
        // After insertion, a record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                XCTAssertFalse(person.databaseEdited)
            }
        }
    }
    
    func testRecordIsEditedAfterValueChange() {
        // Any change in a value exposed in storedDatabaseDictionary yields a
        // record that is edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                do {
                    let person = Person(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.name != nil)
                    person.name = "Bobby"           // non-nil vs. non-nil
                    XCTAssertTrue(person.databaseEdited)
                }
                do {
                    let person = Person(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.name != nil)
                    person.name = nil               // non-nil vs. nil
                    XCTAssertTrue(person.databaseEdited)
                }
                do {
                    let person = Person(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.age == nil)
                    person.age = 41                 // nil vs. non-nil
                    XCTAssertTrue(person.databaseEdited)
                }
            }
        }
    }
    
    func testRecordIsNotEditedAfterSameValueChange() {
        assertNoError {
            try dbQueue.inDatabase { db in
                do {
                    let person = Person(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.name != nil)
                    person.name = "Arthur"           // non-nil vs. non-nil
                    XCTAssertFalse(person.databaseEdited)
                }
                do {
                    let person = Person(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.age == nil)
                    person.age = nil                 // nil vs. nil
                    XCTAssertFalse(person.databaseEdited)
                }
            }
        }
    }
    
    func testRecordIsNotEditedAfterUpdate() {
        // After update, a record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                person.name = "Bobby"
                try person.update(db)
                XCTAssertFalse(person.databaseEdited)
            }
        }
    }
    
    func testRecordIsNotEditedAfterSave() {
        // After save, a record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.save(db)
                XCTAssertFalse(person.databaseEdited)
                person.name = "Bobby"
                XCTAssertTrue(person.databaseEdited)
                try person.save(db)
                XCTAssertFalse(person.databaseEdited)
            }
        }
    }
    
    func testRecordIsEditedAfterPrimaryKeyChange() {
        // After reload, a record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                person.id = person.id + 1
                XCTAssertTrue(person.databaseEdited)
            }
        }
    }
    
    func testCopyTransfersEditedFlag() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                
                try person.insert(db)
                XCTAssertFalse(person.databaseEdited)
                XCTAssertFalse(person.copy().databaseEdited)
                
                person.name = "Barbara"
                XCTAssertTrue(person.databaseEdited)
                XCTAssertTrue(person.copy().databaseEdited)
                
                person.databaseEdited = false
                XCTAssertFalse(person.databaseEdited)
                XCTAssertFalse(person.copy().databaseEdited)
                
                person.databaseEdited = true
                XCTAssertTrue(person.databaseEdited)
                XCTAssertTrue(person.copy().databaseEdited)
            }
        }
    }

    func testChangesAfterInit() {
        let person = Person(name: "Arthur", age: 41)
        let changes = person.databaseChanges
        XCTAssertEqual(changes.count, 4)
        for (column, old) in changes {
            switch column {
            case "id":
                XCTAssertTrue(old == nil)
            case "name":
                XCTAssertTrue(old == nil)
            case "age":
                XCTAssertTrue(old == nil)
            case "creationDate":
                XCTAssertTrue(old == nil)
            default:
                XCTFail("Unexpected column: \(column)")
            }
        }
    }
    
    func testChangesAfterInitFromRow() {
        let person = Person(Row(dictionary:["name": "Arthur", "age": 41]))
        let changes = person.databaseChanges
        XCTAssertEqual(changes.count, 4)
        for (column, old) in changes {
            switch column {
            case "id":
                XCTAssertTrue(old == nil)
            case "name":
                XCTAssertTrue(old == nil)
            case "age":
                XCTAssertTrue(old == nil)
            case "creationDate":
                XCTAssertTrue(old == nil)
            default:
                XCTFail("Unexpected column: \(column)")
            }
        }
    }
    
    func testChangesAfterFullFetch() {
        // Fetch a record from a row that contains all the columns in
        // storedDatabaseDictionary: An update statement, which only saves the
        // columns in storedDatabaseDictionary would perform no change. So the
        // record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person = Person.fetchOne(db, "SELECT * FROM persons")!
                let changes = person.databaseChanges
                XCTAssertEqual(changes.count, 0)
            }
        }
    }

    func testChangesAfterPartialFetch() {
        // Fetch a record from a row that does not contain all the columns in
        // storedDatabaseDictionary: An update statement saves the columns in
        // storedDatabaseDictionary, so it may perform unpredictable change.
        // So the record is edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person =  Person.fetchOne(db, "SELECT name FROM persons")!
                let changes = person.databaseChanges
                XCTAssertEqual(changes.count, 3)
                for (column, old) in changes {
                    switch column {
                    case "id":
                        XCTAssertTrue(old == nil)
                    case "age":
                        XCTAssertTrue(old == nil)
                    case "creationDate":
                        XCTAssertTrue(old == nil)
                    default:
                        XCTFail("Unexpected column: \(column)")
                    }
                }
            }
        }
    }
    
    func testChangesAfterInsert() {
        // After insertion, a record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                let changes = person.databaseChanges
                XCTAssertEqual(changes.count, 0)
            }
        }
    }
    
    func testChangesAfterValueChange() {
        // Any change in a value exposed in storedDatabaseDictionary yields a
        // record that is edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: nil)
                try person.insert(db)
                
                person.name = "Bobby"           // non-nil -> non-nil
                person.age = 41                 // nil -> non-nil
                person.creationDate = nil       // non-nil -> nil
                let changes = person.databaseChanges
                XCTAssertEqual(changes.count, 3)
                for (column, old) in changes {
                    switch column {
                    case "name":
                        XCTAssertEqual(old, "Arthur".databaseValue)
                    case "age":
                        XCTAssertEqual(old, DatabaseValue.Null)
                    case "creationDate":
                        XCTAssertTrue((old?.value() as NSDate?) != nil)
                    default:
                        XCTFail("Unexpected column: \(column)")
                    }
                }
            }
        }
    }
    
    func testChangesAfterUpdate() {
        // After update, a record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                person.name = "Bobby"
                try person.update(db)
                XCTAssertEqual(person.databaseChanges.count, 0)
            }
        }
    }
    
    func testChangesAfterSave() {
        // After save, a record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.save(db)
                XCTAssertEqual(person.databaseChanges.count, 0)
                
                person.name = "Bobby"
                let changes = person.databaseChanges
                XCTAssertEqual(changes.count, 1)
                for (column, old) in changes {
                    switch column {
                    case "name":
                        XCTAssertEqual(old, "Arthur".databaseValue)
                    default:
                        XCTFail("Unexpected column: \(column)")
                    }
                }
                try person.save(db)
                XCTAssertEqual(person.databaseChanges.count, 0)
            }
        }
    }
    
    func testChangesAfterPrimaryKeyChange() {
        // After reload, a record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                person.id = person.id + 1
                let changes = person.databaseChanges
                XCTAssertEqual(changes.count, 1)
                for (column, old) in changes {
                    switch column {
                    case "id":
                        XCTAssertEqual(old, (person.id - 1).databaseValue)
                    default:
                        XCTFail("Unexpected column: \(column)")
                    }
                }
            }
        }
    }
    
    func testCopyTransfersChanges() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                
                try person.insert(db)
                XCTAssertEqual(person.databaseChanges.count, 0)
                XCTAssertEqual(person.copy().databaseChanges.count, 0)
                
                person.name = "Barbara"
                XCTAssertTrue(person.databaseChanges.count > 0)            // TODO: compare actual changes
                XCTAssertEqual(person.databaseChanges.count, person.copy().databaseChanges.count)
                
                person.databaseEdited = false
                XCTAssertEqual(person.databaseChanges.count, 0)
                XCTAssertEqual(person.copy().databaseChanges.count, 0)
                
                person.databaseEdited = true
                XCTAssertTrue(person.databaseChanges.count > 0)            // TODO: compare actual changes
                XCTAssertEqual(person.databaseChanges.count, person.copy().databaseChanges.count)
            }
        }
    }
    
}
