import XCTest
import GRDB

class DatabaseValueTests: GRDBTestCase {
    
    func testDatabaseValueAdoptsDatabaseValueConvertible() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE integers (integer INTEGER)")
                try db.execute("INSERT INTO integers (integer) VALUES (1)")
                let databaseValue: DatabaseValue = Row.fetchOne(db, "SELECT * FROM integers")!.value(named: "integer")!               // Triggers DatabaseValue.init?(databaseValue: DatabaseValue)
                let count = Int.fetchOne(db, "SELECT COUNT(*) FROM integers WHERE integer = ?", arguments: [databaseValue])!   // Triggers DatabaseValue.databaseValue
                XCTAssertEqual(count, 1)
            }
        }
    }
    
    func testDatabaseValueEquatable() {
        let fooBlob = Blob(data: "foo".dataUsingEncoding(NSUTF8StringEncoding))!
        let barBlob = Blob(data: "bar".dataUsingEncoding(NSUTF8StringEncoding))!
        
        XCTAssertEqual(DatabaseValue.Null, DatabaseValue.Null)
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue(int64: 1))
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue(double: 1.0))
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue(string: "foo"))
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue(blob: fooBlob))
        
        XCTAssertNotEqual(DatabaseValue(int64: 1), DatabaseValue.Null)
        XCTAssertEqual(DatabaseValue(int64: 1), DatabaseValue(int64: 1))
        XCTAssertNotEqual(DatabaseValue(int64: 1), DatabaseValue(int64: 2))
        XCTAssertEqual(DatabaseValue(int64: 1), DatabaseValue(double: 1.0))
        XCTAssertNotEqual(DatabaseValue(int64: 1), DatabaseValue(double: 1.1))
        XCTAssertNotEqual(DatabaseValue(int64: 1), DatabaseValue(double: 2.0))
        XCTAssertEqual(DatabaseValue(int64: 1 << 53), DatabaseValue(double: Double(1 << 53)))                 // Any integer up to 2^53 has an exact representation as a IEEE-754 double...
        XCTAssertNotEqual(DatabaseValue(int64: 1 << 53 + 1), DatabaseValue(double: Double(1 << 53 + 1)))      // ... 2^53 + 1 does not....
        XCTAssertEqual(DatabaseValue(int64: 1 << 54), DatabaseValue(double: Double(1 << 54)))                 // ... but 2^54 does.
        XCTAssertNotEqual(DatabaseValue(int64: Int64.max), DatabaseValue(double: Double(Int64.max)))          // ... and Int64.max does not.
        XCTAssertNotEqual(DatabaseValue(int64: 1), DatabaseValue(string: "foo"))
        XCTAssertNotEqual(DatabaseValue(int64: 1), DatabaseValue(string: "1"))
        XCTAssertNotEqual(DatabaseValue(int64: 1), DatabaseValue(string: "1.0"))
        XCTAssertNotEqual(DatabaseValue(int64: 1), DatabaseValue(blob: fooBlob))
        
        XCTAssertNotEqual(DatabaseValue(double: 1.0), DatabaseValue.Null)
        XCTAssertEqual(DatabaseValue(double: 1.0), DatabaseValue(int64: 1))
        XCTAssertNotEqual(DatabaseValue(double: 1.1), DatabaseValue(int64: 1))
        XCTAssertNotEqual(DatabaseValue(double: 1.0), DatabaseValue(int64: 2))
        XCTAssertEqual(DatabaseValue(double: 1.0), DatabaseValue(double: 1.0))
        XCTAssertNotEqual(DatabaseValue(double: 1.0), DatabaseValue(double: 2.0))
        XCTAssertEqual(DatabaseValue(double: Double(1 << 53)), DatabaseValue(int64: 1 << 53))                 // Any integer up to 2^53 has an exact representation as a IEEE-754 double...
        XCTAssertNotEqual(DatabaseValue(double: Double(1 << 53 + 1)), DatabaseValue(int64: 1 << 53 + 1))      // ... 2^53 + 1 does not....
        XCTAssertEqual(DatabaseValue(double: Double(1 << 54)), DatabaseValue(int64: 1 << 54))                 // ... but 2^54 does.
        XCTAssertNotEqual(DatabaseValue(double: Double(Int64.max)), DatabaseValue(int64: Int64.max))          // ... and Int64.max does not.
        XCTAssertNotEqual(DatabaseValue(double: 1.0), DatabaseValue(string: "foo"))
        XCTAssertNotEqual(DatabaseValue(double: 1.0), DatabaseValue(string: "1"))
        XCTAssertNotEqual(DatabaseValue(double: 1.0), DatabaseValue(string: "1.0"))
        XCTAssertNotEqual(DatabaseValue(double: 1.0), DatabaseValue(blob: fooBlob))
        
        XCTAssertNotEqual(DatabaseValue(string: "foo"), DatabaseValue.Null)
        XCTAssertNotEqual(DatabaseValue(string: "foo"), DatabaseValue(int64: 1))
        XCTAssertNotEqual(DatabaseValue(string: "foo"), DatabaseValue(double: 1.0))
        XCTAssertEqual(DatabaseValue(string: "foo"), DatabaseValue(string: "foo"))
        XCTAssertNotEqual(DatabaseValue(string: "foo"), DatabaseValue(string: "bar"))
        XCTAssertNotEqual(DatabaseValue(string: "foo"), DatabaseValue(blob: fooBlob))
        
        XCTAssertNotEqual(DatabaseValue(blob: fooBlob), DatabaseValue.Null)
        XCTAssertNotEqual(DatabaseValue(blob: fooBlob), DatabaseValue(int64: 1))
        XCTAssertNotEqual(DatabaseValue(blob: fooBlob), DatabaseValue(double: 1.0))
        XCTAssertNotEqual(DatabaseValue(blob: fooBlob), DatabaseValue(string: "foo"))
        XCTAssertEqual(DatabaseValue(blob: fooBlob), DatabaseValue(blob: fooBlob))
        XCTAssertNotEqual(DatabaseValue(blob: fooBlob), DatabaseValue(blob: barBlob))
    }
}
