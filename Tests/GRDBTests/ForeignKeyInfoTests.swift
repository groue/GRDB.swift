import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class ForeignKeyInfoTests: GRDBTestCase {
    
    private func assertEqual(_ lhs: ForeignKeyInfo, _ rhs: ForeignKeyInfo, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(lhs.destinationTable, rhs.destinationTable, file: file, line: line)
        XCTAssertEqual(lhs.mapping.count, rhs.mapping.count, file: file, line: line)
        for (larrow, rarrow) in zip(lhs.mapping, rhs.mapping) {
            XCTAssertEqual(larrow.origin, rarrow.origin, file: file, line: line)
            XCTAssertEqual(larrow.destination, rarrow.destination, file: file, line: line)
        }
    }
    
    func testForeignKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE parents1 (id PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE parents2 (a, b, PRIMARY KEY (a,b))")
            try db.execute(sql: "CREATE TABLE children1 (parentId REFERENCES parents1)")
            try db.execute(sql: "CREATE TABLE children2 (parentId1 REFERENCES parents1, parentId2 REFERENCES parents1)")
            try db.execute(sql: "CREATE TABLE children3 (parentA, parentB, FOREIGN KEY (parentA, parentB) REFERENCES parents2)")
            try db.execute(sql: "CREATE TABLE children4 (parentA1, parentB1, parentA2, parentB2, FOREIGN KEY (parentA1, parentB1) REFERENCES parents2, FOREIGN KEY (parentA2, parentB2) REFERENCES parents2(b, a))")
            
            do {
                _ = try db.foreignKeys(on: "missing")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "no such table: missing")
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "parents1")
                XCTAssert(foreignKeys.isEmpty)
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "parents2")
                XCTAssert(foreignKeys.isEmpty)
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "children1")
                XCTAssertEqual(foreignKeys.count, 1)
                assertEqual(foreignKeys[0], ForeignKeyInfo(destinationTable: "parents1", mapping: [(origin: "parentId", destination: "id")]))
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "children2")
                XCTAssertEqual(foreignKeys.count, 2)
                assertEqual(foreignKeys[0], ForeignKeyInfo(destinationTable: "parents1", mapping: [(origin: "parentId2", destination: "id")]))
                assertEqual(foreignKeys[1], ForeignKeyInfo(destinationTable: "parents1", mapping: [(origin: "parentId1", destination: "id")]))
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "children3")
                XCTAssertEqual(foreignKeys.count, 1)
                assertEqual(foreignKeys[0], ForeignKeyInfo(destinationTable: "parents2", mapping: [(origin: "parentA", destination: "a"), (origin: "parentB", destination: "b")]))
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "children4")
                XCTAssertEqual(foreignKeys.count, 2)
                assertEqual(foreignKeys[0], ForeignKeyInfo(destinationTable: "parents2", mapping: [(origin: "parentA2", destination: "b"), (origin: "parentB2", destination: "a")]))
                assertEqual(foreignKeys[1], ForeignKeyInfo(destinationTable: "parents2", mapping: [(origin: "parentA1", destination: "a"), (origin: "parentB1", destination: "b")]))
            }
        }
    }
}
