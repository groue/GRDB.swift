import XCTest
import GRDB

struct SimpleRowConvertible : RowConvertible {
    var firstName: String
    var lastName: String
    
    init(row: Row) {
        firstName = row.value(named: "firstName")
        lastName = row.value(named: "lastName")
    }
}

class RowConvertibleTests: GRDBTestCase {

    override func setUp() {
        super.setUp()
        
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE structs (firstName TEXT, lastName TEXT)")
            }
        }
    }
    
    func testRowInitializer() {
        let row = Row(dictionary: ["firstName": "Arthur", "lastName": "Martin"])
        let s = SimpleRowConvertible(row: row)
        XCTAssertEqual(s.firstName, "Arthur")
        XCTAssertEqual(s.lastName, "Martin")
    }
    
    func testDictionaryInitializer() {
        let s = SimpleRowConvertible(dictionary: ["firstName": "Arthur", "lastName": "Martin"])
        XCTAssertEqual(s.firstName, "Arthur")
        XCTAssertEqual(s.lastName, "Martin")
    }
    
    func testFetchFromDatabase() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let ss = SimpleRowConvertible.fetch(db, "SELECT * FROM structs")
                let s = Array(ss).first!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
            }
        }
    }
    
    func testFetchAllFromDatabase() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let ss = SimpleRowConvertible.fetchAll(db, "SELECT * FROM structs")
                let s = ss.first!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
            }
        }
    }
    
    func testFetchOneFromDatabase() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let missingS = SimpleRowConvertible.fetchOne(db, "SELECT * FROM structs")
                XCTAssertTrue(missingS == nil)
                
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let s = SimpleRowConvertible.fetchOne(db, "SELECT * FROM structs")!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
            }
        }
    }
    
    func testFetchFromStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let statement = db.selectStatement("SELECT * FROM structs")
                let ss = SimpleRowConvertible.fetch(statement)
                let s = Array(ss).first!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
            }
        }
    }
    
    func testFetchAllFromStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let statement = db.selectStatement("SELECT * FROM structs")
                let ss = SimpleRowConvertible.fetchAll(statement)
                let s = ss.first!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
            }
        }
    }
    
    func testFetchOneFromStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let statement = db.selectStatement("SELECT * FROM structs")
                let missingS = SimpleRowConvertible.fetchOne(statement)
                XCTAssertTrue(missingS == nil)
                
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let s = SimpleRowConvertible.fetchOne(statement)!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
            }
        }
    }
}
