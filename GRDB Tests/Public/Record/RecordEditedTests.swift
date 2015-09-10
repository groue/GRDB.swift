import XCTest
import GRDB

class IntegerPropertyOnRealAffinityColumn : Record {
    var value: Int!
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["value": value]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["value"] { value = dbv.value() }
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
                
                // Load a double...
                let row1 = Row.fetchOne(db, "SELECT * FROM t")!
                switch row1["value"]! {
                case .Real(let double):
                    XCTAssertEqual(double, 1.0)
                default:
                    XCTFail("Unexpected DatabaseValue")
                }
                
                // Compare to an Int
                let record = IntegerPropertyOnRealAffinityColumn.fetchOne(db, "SELECT * FROM t")!
                let row2 = Row(dictionary: record.storedDatabaseDictionary)
                switch row2["value"]! {
                case .Integer(let integer):
                    XCTAssertEqual(integer, 1)
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

    func testChangesAfterInit() {
        let person = Person(name: "Arthur", age: 41)
        let changes = person.databaseChanges
        XCTAssertEqual(changes.count, 4)
        for (column, (old: old, new: new)) in changes {
            switch column {
            case "id":
                XCTAssertTrue(old == nil)
                XCTAssertEqual(new, DatabaseValue.Null)
            case "name":
                XCTAssertTrue(old == nil)
                XCTAssertEqual(new, "Arthur".databaseValue)
            case "age":
                XCTAssertTrue(old == nil)
                XCTAssertEqual(new, 41.databaseValue)
            case "creationDate":
                XCTAssertTrue(old == nil)
                XCTAssertEqual(new, DatabaseValue.Null)
            default:
                XCTFail("Unexpected column: \(column)")
            }
        }
    }
    
    func testChangesAfterInitFromRow() {
        let person = Person(row: Row(dictionary:["name": "Arthur", "age": 41]))
        let changes = person.databaseChanges
        XCTAssertEqual(changes.count, 4)
        for (column, (old: old, new: new)) in changes {
            switch column {
            case "id":
                XCTAssertTrue(old == nil)
                XCTAssertEqual(new, DatabaseValue.Null)
            case "name":
                XCTAssertTrue(old == nil)
                XCTAssertEqual(new, "Arthur".databaseValue)
            case "age":
                XCTAssertTrue(old == nil)
                XCTAssertEqual(new, 41.databaseValue)
            case "creationDate":
                XCTAssertTrue(old == nil)
                XCTAssertEqual(new, DatabaseValue.Null)
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
                for (column, (old: old, new: new)) in changes {
                    switch column {
                    case "id":
                        XCTAssertTrue(old == nil)
                        XCTAssertEqual(new, DatabaseValue.Null)
                    case "age":
                        XCTAssertTrue(old == nil)
                        XCTAssertEqual(new, DatabaseValue.Null)
                    case "creationDate":
                        XCTAssertTrue(old == nil)
                        XCTAssertEqual(new, DatabaseValue.Null)
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
                for (column, (old: old, new: new)) in changes {
                    switch column {
                    case "name":
                        XCTAssertEqual(old, "Arthur".databaseValue)
                        XCTAssertEqual(new, "Bobby".databaseValue)
                    case "age":
                        XCTAssertEqual(old, DatabaseValue.Null)
                        XCTAssertEqual(new, 41.databaseValue)
                    case "creationDate":
                        XCTAssertTrue((old?.value() as NSDate?) != nil)
                        XCTAssertEqual(new, DatabaseValue.Null)
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
                for (column, (old: old, new: new)) in changes {
                    switch column {
                    case "name":
                        XCTAssertEqual(old, "Arthur".databaseValue)
                        XCTAssertEqual(new, "Bobby".databaseValue)
                    default:
                        XCTFail("Unexpected column: \(column)")
                    }
                }
                try person.save(db)
                XCTAssertEqual(person.databaseChanges.count, 0)
            }
        }
    }
    
    func testChangesAfterReload() {
        // After reload, a record is not edited.
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                
                person.name = "Bobby"
                let changes = person.databaseChanges
                XCTAssertEqual(changes.count, 1)
                for (column, (old: old, new: new)) in changes {
                    switch column {
                    case "name":
                        XCTAssertEqual(old, "Arthur".databaseValue)
                        XCTAssertEqual(new, "Bobby".databaseValue)
                    default:
                        XCTFail("Unexpected column: \(column)")
                    }
                }
                
                try person.reload(db)
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
                for (column, (old: old, new: new)) in changes {
                    switch column {
                    case "id":
                        XCTAssertEqual(old, (person.id - 1).databaseValue)
                        XCTAssertEqual(new, person.id.databaseValue)
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
                XCTAssertTrue(person.databaseChanges.count > 0)            // TODO: compare actal changes
                XCTAssertEqual(person.databaseChanges.count, person.copy().databaseChanges.count)
                
                person.databaseEdited = false
                XCTAssertEqual(person.databaseChanges.count, 0)
                XCTAssertEqual(person.copy().databaseChanges.count, 0)
                
                person.databaseEdited = true
                XCTAssertTrue(person.databaseChanges.count > 0)            // TODO: compare actal changes
                XCTAssertEqual(person.databaseChanges.count, person.copy().databaseChanges.count)
            }
        }
    }
    
}
