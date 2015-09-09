import XCTest
import GRDB

class IntegerPropertyOnRealAffinityColumn : Record {
    var value: Int!
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["value": value]
    }
    
    override func updateFromRow(row: Row) {
        for (column, dbv) in row {
            switch column {
            case "value": value = dbv.value()
            default: break
            }
        }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
}

class RecordEditedTests: RecordTestCase {
    
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
        let person = Person(row: row)
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
                let record = IntegerPropertyOnRealAffinityColumn.fetchOne(db, "SELECT * FROM t")!
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
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                
                person.name = "Bobby"           // non-nil vs. non-nil
                XCTAssertTrue(person.databaseEdited)
                try person.reload(db)
                
                person.name = nil               // non-nil vs. nil
                XCTAssertTrue(person.databaseEdited)
                try person.reload(db)
                
                person.creationDate = NSDate()  // nil vs. non-nil
                XCTAssertTrue(person.databaseEdited)
                try person.reload(db)
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
    
    func testRecordIsNotEditedAfterReload() {
        // After reload, a record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                
                person.name = "Bobby"
                XCTAssertTrue(person.databaseEdited)
                
                try person.reload(db)
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
}
