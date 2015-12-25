import XCTest
import GRDB

struct SimpleRowConvertible : RowConvertible {
    var firstName: String
    var lastName: String
    var fetched: Bool = false
    
    static func fromRow(row: Row) -> SimpleRowConvertible {
        return SimpleRowConvertible(
            firstName: row.value(named: "firstName"),
            lastName: row.value(named: "lastName"),
            fetched: false)
    }
    
    mutating func awakeFromFetch(row row: Row, database: Database) {
        fetched = true
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
        let s = SimpleRowConvertible.fromRow(row)
        XCTAssertEqual(s.firstName, "Arthur")
        XCTAssertEqual(s.lastName, "Martin")
        XCTAssertFalse(s.fetched)
    }
    
    func testFetchFromDatabase() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let ss = SimpleRowConvertible.fetch(db, "SELECT * FROM structs")
                let s = Array(ss).first!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
                XCTAssertTrue(s.fetched)
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
                XCTAssertTrue(s.fetched)
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
                XCTAssertTrue(s.fetched)
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
                XCTAssertTrue(s.fetched)
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
                XCTAssertTrue(s.fetched)
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
                XCTAssertTrue(s.fetched)
            }
        }
    }
}
