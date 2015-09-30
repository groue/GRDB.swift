import XCTest
import GRDB

class MetalRowTests: GRDBTestCase {
    
    func testRowAsSequence() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    var columnNames = [String]()
                    var ints = [Int]()
                    var bools = [Bool]()
                    for (columnName, databaseValue) in row {
                        columnNames.append(columnName)
                        ints.append(databaseValue.value() as Int)
                        bools.append(databaseValue.value() as Bool)
                    }
                    
                    XCTAssertEqual(columnNames, ["a", "b", "c"])
                    XCTAssertEqual(ints, [0, 1, 2])
                    XCTAssertEqual(bools, [false, true, true])
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowValueAtIndex() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    
                    // Int extraction, form 1
                    XCTAssertEqual(row.value(atIndex: 0) as Int, 0)
                    XCTAssertEqual(row.value(atIndex: 1) as Int, 1)
                    XCTAssertEqual(row.value(atIndex: 2) as Int, 2)
                    
                    // Int extraction, form 2
                    XCTAssertEqual(row.value(atIndex: 0)! as Int, 0)
                    XCTAssertEqual(row.value(atIndex: 1)! as Int, 1)
                    XCTAssertEqual(row.value(atIndex: 2)! as Int, 2)
                    
                    // Int? extraction
                    XCTAssertEqual((row.value(atIndex: 0) as Int?), 0)
                    XCTAssertEqual((row.value(atIndex: 1) as Int?), 1)
                    XCTAssertEqual((row.value(atIndex: 2) as Int?), 2)
                    
                    // Bool extraction, form 1
                    XCTAssertEqual(row.value(atIndex: 0) as Bool, false)
                    XCTAssertEqual(row.value(atIndex: 1) as Bool, true)
                    XCTAssertEqual(row.value(atIndex: 2) as Bool, true)
                    
                    // Bool extraction, form 2
                    XCTAssertEqual(row.value(atIndex: 0)! as Bool, false)
                    XCTAssertEqual(row.value(atIndex: 1)! as Bool, true)
                    XCTAssertEqual(row.value(atIndex: 2)! as Bool, true)
                    
                    // Bool? extraction
                    XCTAssertEqual((row.value(atIndex: 0) as Bool?), false)
                    XCTAssertEqual((row.value(atIndex: 1) as Bool?), true)
                    XCTAssertEqual((row.value(atIndex: 2) as Bool?), true)
                    
                    // Expect fatal error:
                    //
                    // row.value(atIndex: -1)
                    // row.value(atIndex: 3)
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowValueNamed() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    
                    // Int extraction, form 1
                    XCTAssertEqual(row.value(named: "a") as Int, 0)
                    XCTAssertEqual(row.value(named: "b") as Int, 1)
                    XCTAssertEqual(row.value(named: "c") as Int, 2)
                    
                    // Int extraction, form 2
                    XCTAssertEqual(row.value(named: "a")! as Int, 0)
                    XCTAssertEqual(row.value(named: "b")! as Int, 1)
                    XCTAssertEqual(row.value(named: "c")! as Int, 2)
                    
                    // Int? extraction
                    XCTAssertEqual((row.value(named: "a") as Int?)!, 0)
                    XCTAssertEqual((row.value(named: "b") as Int?)!, 1)
                    XCTAssertEqual((row.value(named: "c") as Int?)!, 2)
                    
                    // Bool extraction, form 1
                    XCTAssertEqual(row.value(named: "a") as Bool, false)
                    XCTAssertEqual(row.value(named: "b") as Bool, true)
                    XCTAssertEqual(row.value(named: "c") as Bool, true)
                    
                    // Bool extraction, form 2
                    XCTAssertEqual(row.value(named: "a")! as Bool, false)
                    XCTAssertEqual(row.value(named: "b")! as Bool, true)
                    XCTAssertEqual(row.value(named: "c")! as Bool, true)
                    
                    // Bool? extraction
                    XCTAssertEqual((row.value(named: "a") as Bool?)!, false)
                    XCTAssertEqual((row.value(named: "b") as Bool?)!, true)
                    XCTAssertEqual((row.value(named: "c") as Bool?)!, true)
                    
                    // Expect fatal error:
                    // row.value(named: "foo")
                    // row.value(named: "foo") as Int?
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowCount() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    XCTAssertEqual(row.count, 3)
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowColumnNames() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT a, b, c FROM ints") {
                    rowFetched = true
                    XCTAssertEqual(Array(row.columnNames), ["a", "b", "c"])
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowDatabaseValues() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT a, b, c FROM ints") {
                    rowFetched = true
                    XCTAssertEqual(Array(row.databaseValues), [0.databaseValue, 1.databaseValue, 2.databaseValue])
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowSubscriptIsCaseInsensitive() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE stuffs (name TEXT)")
                try db.execute("INSERT INTO stuffs (name) VALUES ('foo')")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT nAmE FROM stuffs") {
                    rowFetched = true
                    XCTAssertEqual(row["name"], "foo".databaseValue)
                    XCTAssertEqual(row["NAME"], "foo".databaseValue)
                    XCTAssertEqual(row["NaMe"], "foo".databaseValue)
                    XCTAssertEqual(row.value(named: "name") as String, "foo")
                    XCTAssertEqual(row.value(named: "NAME") as String, "foo")
                    XCTAssertEqual(row.value(named: "NaMe") as String, "foo")
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
}
