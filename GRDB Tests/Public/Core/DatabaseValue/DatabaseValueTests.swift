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
        XCTAssertNotEqual(DatabaseValue.Null, 1.databaseValue)
        XCTAssertNotEqual(DatabaseValue.Null, 1.0.databaseValue)
        XCTAssertNotEqual(DatabaseValue.Null, "foo".databaseValue)
        XCTAssertNotEqual(DatabaseValue.Null, fooData.databaseValue)
        
        XCTAssertNotEqual(1.databaseValue, DatabaseValue.Null)
        XCTAssertEqual(1.databaseValue, 1.databaseValue)
        XCTAssertNotEqual(1.databaseValue, 2.databaseValue)
        XCTAssertEqual(1.databaseValue, 1.0.databaseValue)
        XCTAssertNotEqual(1.databaseValue, 1.1.databaseValue)
        XCTAssertNotEqual(1.databaseValue, 2.0.databaseValue)
        XCTAssertEqual(Double(1 << 53).databaseValue, Double(1 << 53).databaseValue)        // Any integer up to 2^53 has an exact representation as a IEEE-754 double...
        XCTAssertNotEqual((1 << 53 + 1).databaseValue, Double(1 << 53 + 1).databaseValue)   // ... 2^53 + 1 does not....
        XCTAssertEqual((1 << 54).databaseValue, Double(1 << 54).databaseValue)              // ... but 2^54 does.
        XCTAssertNotEqual(Int64.max.databaseValue, Double(Int64.max).databaseValue)         // ... and Int64.max does not.
        XCTAssertNotEqual(1.databaseValue, "foo".databaseValue)
        XCTAssertNotEqual(1.databaseValue, "1".databaseValue)
        XCTAssertNotEqual(1.databaseValue, "1.0".databaseValue)
        XCTAssertNotEqual(1.databaseValue, fooData.databaseValue)
        
        XCTAssertNotEqual(1.0.databaseValue, DatabaseValue.Null)
        XCTAssertEqual(1.0.databaseValue, 1.databaseValue)
        XCTAssertNotEqual(1.1.databaseValue, 1.databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, 2.databaseValue)
        XCTAssertEqual(1.0.databaseValue, 1.0.databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, 2.0.databaseValue)
        XCTAssertEqual(Double(1 << 53).databaseValue, Double(1 << 53).databaseValue)        // Any integer up to 2^53 has an exact representation as a IEEE-754 double...
        XCTAssertNotEqual(Double(1 << 53 + 1).databaseValue, (1 << 53 + 1).databaseValue)   // ... 2^53 + 1 does not....
        XCTAssertEqual(Double(1 << 54).databaseValue, (1 << 54).databaseValue)              // ... but 2^54 does.
        XCTAssertNotEqual(Double(Int64.max).databaseValue, Int64.max.databaseValue)         // ... and Int64.max does not.
        XCTAssertNotEqual(1.0.databaseValue, "foo".databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, "1".databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, "1.0".databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, fooData.databaseValue)
        
        XCTAssertNotEqual("foo".databaseValue, DatabaseValue.Null)
        XCTAssertNotEqual("foo".databaseValue, 1.databaseValue)
        XCTAssertNotEqual("foo".databaseValue, 1.0.databaseValue)
        XCTAssertEqual("foo".databaseValue, "foo".databaseValue)
        XCTAssertNotEqual("foo".databaseValue, "bar".databaseValue)
        XCTAssertNotEqual("foo".databaseValue, fooData.databaseValue)
        
        XCTAssertNotEqual(fooData.databaseValue, DatabaseValue.Null)
        XCTAssertNotEqual(fooData.databaseValue, 1.databaseValue)
        XCTAssertNotEqual(fooData.databaseValue, 1.0.databaseValue)
        XCTAssertNotEqual(fooData.databaseValue, "foo".databaseValue)
        XCTAssertEqual(fooData.databaseValue, fooData.databaseValue)
        XCTAssertNotEqual(fooData.databaseValue, barData.databaseValue)
    }
}
