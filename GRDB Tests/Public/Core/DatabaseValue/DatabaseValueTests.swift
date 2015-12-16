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
        let fooData = "foo".dataUsingEncoding(NSUTF8StringEncoding)!
        let barData = "bar".dataUsingEncoding(NSUTF8StringEncoding)!
        
        XCTAssertEqual(DatabaseValue.Null, DatabaseValue.Null)
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue(Int64(1)))
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue(1.0))
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue("foo"))
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue(fooData))
        
        XCTAssertNotEqual(DatabaseValue(Int64(1)), DatabaseValue.Null)
        XCTAssertEqual(DatabaseValue(Int64(1)), DatabaseValue(Int64(1)))
        XCTAssertNotEqual(DatabaseValue(Int64(1)), DatabaseValue(Int64(2)))
        XCTAssertEqual(DatabaseValue(Int64(1)), DatabaseValue(1.0))
        XCTAssertNotEqual(DatabaseValue(Int64(1)), DatabaseValue(1.1))
        XCTAssertNotEqual(DatabaseValue(Int64(1)), DatabaseValue(2.0))
        XCTAssertEqual(DatabaseValue(1 << 53), DatabaseValue(Double(1 << 53)))                 // Any integer up to 2^53 has an exact representation as a IEEE-754 double...
        XCTAssertNotEqual(DatabaseValue(1 << 53 + 1), DatabaseValue(Double(1 << 53 + 1)))      // ... 2^53 + 1 does not....
        XCTAssertEqual(DatabaseValue(1 << 54), DatabaseValue(Double(1 << 54)))                 // ... but 2^54 does.
        XCTAssertNotEqual(DatabaseValue(Int64.max), DatabaseValue(Double(Int64.max)))          // ... and Int64.max does not.
        XCTAssertNotEqual(DatabaseValue(Int64(1)), DatabaseValue("foo"))
        XCTAssertNotEqual(DatabaseValue(Int64(1)), DatabaseValue("1"))
        XCTAssertNotEqual(DatabaseValue(Int64(1)), DatabaseValue("1.0"))
        XCTAssertNotEqual(DatabaseValue(Int64(1)), DatabaseValue(fooData))
        
        XCTAssertNotEqual(DatabaseValue(1.0), DatabaseValue.Null)
        XCTAssertEqual(DatabaseValue(1.0), DatabaseValue(Int64(1)))
        XCTAssertNotEqual(DatabaseValue(1.1), DatabaseValue(Int64(1)))
        XCTAssertNotEqual(DatabaseValue(1.0), DatabaseValue(Int64(2)))
        XCTAssertEqual(DatabaseValue(1.0), DatabaseValue(1.0))
        XCTAssertNotEqual(DatabaseValue(1.0), DatabaseValue(2.0))
        XCTAssertEqual(DatabaseValue(Double(1 << 53)), DatabaseValue(1 << 53))                 // Any integer up to 2^53 has an exact representation as a IEEE-754 double...
        XCTAssertNotEqual(DatabaseValue(Double(1 << 53 + 1)), DatabaseValue(1 << 53 + 1))      // ... 2^53 + 1 does not....
        XCTAssertEqual(DatabaseValue(Double(1 << 54)), DatabaseValue(1 << 54))                 // ... but 2^54 does.
        XCTAssertNotEqual(DatabaseValue(Double(Int64.max)), DatabaseValue(Int64.max))          // ... and Int64.max does not.
        XCTAssertNotEqual(DatabaseValue(1.0), DatabaseValue("foo"))
        XCTAssertNotEqual(DatabaseValue(1.0), DatabaseValue("1"))
        XCTAssertNotEqual(DatabaseValue(1.0), DatabaseValue("1.0"))
        XCTAssertNotEqual(DatabaseValue(1.0), DatabaseValue(fooData))
        
        XCTAssertNotEqual(DatabaseValue("foo"), DatabaseValue.Null)
        XCTAssertNotEqual(DatabaseValue("foo"), DatabaseValue(Int64(1)))
        XCTAssertNotEqual(DatabaseValue("foo"), DatabaseValue(1.0))
        XCTAssertEqual(DatabaseValue("foo"), DatabaseValue("foo"))
        XCTAssertNotEqual(DatabaseValue("foo"), DatabaseValue("bar"))
        XCTAssertNotEqual(DatabaseValue("foo"), DatabaseValue(fooData))
        
        XCTAssertNotEqual(DatabaseValue(fooData), DatabaseValue.Null)
        XCTAssertNotEqual(DatabaseValue(fooData), DatabaseValue(Int64(1)))
        XCTAssertNotEqual(DatabaseValue(fooData), DatabaseValue(1.0))
        XCTAssertNotEqual(DatabaseValue(fooData), DatabaseValue("foo"))
        XCTAssertEqual(DatabaseValue(fooData), DatabaseValue(fooData))
        XCTAssertNotEqual(DatabaseValue(fooData), DatabaseValue(barData))
    }
}
