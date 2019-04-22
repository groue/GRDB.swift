import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseValueTests: GRDBTestCase {
    
    func testDatabaseValueAsDatabaseValueConvertible() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: "SELECT 1")!.storage, DatabaseValue.Storage.int64(1))
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: "SELECT 1.0")!.storage, DatabaseValue.Storage.double(1))
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: "SELECT 'foo'")!.storage, DatabaseValue.Storage.string("foo"))
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: "SELECT x'53514C697465'")!.storage, DatabaseValue.Storage.blob("SQLite".data(using: .utf8)!))
            XCTAssertTrue(try DatabaseValue.fetchOne(db, sql: "SELECT NULL")!.isNull)
        }
    }

    func testDatabaseValueCanBeUsedAsStatementArgument() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE integers (integer INTEGER)")
            try db.execute(sql: "INSERT INTO integers (integer) VALUES (1)")
            let dbValue: DatabaseValue = 1.databaseValue
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM integers WHERE integer = ?", arguments: [dbValue])!
            XCTAssertEqual(count, 1)
        }
    }

    func testDatabaseValueEquatable() {
        let fooData = "foo".data(using: .utf8)!
        let barData = "bar".data(using: .utf8)!
        
        // Any integer up to 2^53 has an exact representation as a IEEE-754 double
        let twoPower53 = Int64(1) << 53

        XCTAssertEqual(DatabaseValue.null, DatabaseValue.null)
        XCTAssertNotEqual(DatabaseValue.null, 1.databaseValue)
        XCTAssertNotEqual(DatabaseValue.null, 1.0.databaseValue)
        XCTAssertNotEqual(DatabaseValue.null, "foo".databaseValue)
        XCTAssertNotEqual(DatabaseValue.null, fooData.databaseValue)
        
        XCTAssertNotEqual(1.databaseValue, DatabaseValue.null)
        XCTAssertEqual(1.databaseValue, 1.databaseValue)
        XCTAssertNotEqual(1.databaseValue, 2.databaseValue)
        XCTAssertEqual(1.databaseValue, 1.0.databaseValue)
        XCTAssertNotEqual(1.databaseValue, 1.1.databaseValue)
        XCTAssertNotEqual(1.databaseValue, 2.0.databaseValue)
        XCTAssertEqual((twoPower53 - 1).databaseValue, Double(twoPower53 - 1).databaseValue)
        XCTAssertEqual(twoPower53.databaseValue, Double(twoPower53).databaseValue)
        XCTAssertNotEqual((twoPower53 + 1).databaseValue, Double(twoPower53 + 1).databaseValue)
        XCTAssertEqual((Int64(1) << 54).databaseValue, Double(Int64(1) << 54).databaseValue)
        XCTAssertNotEqual(Int64.max.databaseValue, Double(Int64.max).databaseValue)
        XCTAssertNotEqual(1.databaseValue, "foo".databaseValue)
        XCTAssertNotEqual(1.databaseValue, "1".databaseValue)
        XCTAssertNotEqual(1.databaseValue, "1.0".databaseValue)
        XCTAssertNotEqual(1.databaseValue, fooData.databaseValue)
        
        XCTAssertNotEqual(1.0.databaseValue, DatabaseValue.null)
        XCTAssertEqual(1.0.databaseValue, 1.databaseValue)
        XCTAssertNotEqual(1.1.databaseValue, 1.databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, 2.databaseValue)
        XCTAssertEqual(1.0.databaseValue, 1.0.databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, 2.0.databaseValue)
        XCTAssertEqual(Double(twoPower53 - 1).databaseValue, (twoPower53 - 1).databaseValue)
        XCTAssertEqual(Double(twoPower53).databaseValue, twoPower53.databaseValue)
        XCTAssertNotEqual(Double(twoPower53 + 1).databaseValue, (twoPower53 + 1).databaseValue)
        XCTAssertEqual(Double(Int64(1) << 54).databaseValue, (Int64(1) << 54).databaseValue)
        XCTAssertNotEqual(Double(Int64.max).databaseValue, Int64.max.databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, "foo".databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, "1".databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, "1.0".databaseValue)
        XCTAssertNotEqual(1.0.databaseValue, fooData.databaseValue)
        
        XCTAssertNotEqual("foo".databaseValue, DatabaseValue.null)
        XCTAssertNotEqual("foo".databaseValue, 1.databaseValue)
        XCTAssertNotEqual("foo".databaseValue, 1.0.databaseValue)
        XCTAssertEqual("foo".databaseValue, "foo".databaseValue)
        XCTAssertNotEqual("foo".databaseValue, "bar".databaseValue)
        XCTAssertNotEqual("foo".databaseValue, fooData.databaseValue)
        
        XCTAssertNotEqual(fooData.databaseValue, DatabaseValue.null)
        XCTAssertNotEqual(fooData.databaseValue, 1.databaseValue)
        XCTAssertNotEqual(fooData.databaseValue, 1.0.databaseValue)
        XCTAssertNotEqual(fooData.databaseValue, "foo".databaseValue)
        XCTAssertEqual(fooData.databaseValue, fooData.databaseValue)
        XCTAssertNotEqual(fooData.databaseValue, barData.databaseValue)
    }
    
    func testDatabaseValueHash() {
        // Equal => Same hash
        let intValue = 1.databaseValue
        let doubleValue = 1.0.databaseValue
        XCTAssertEqual(intValue, doubleValue)
        XCTAssertEqual(intValue.hashValue, doubleValue.hashValue)
        
        let string1 = "foo".databaseValue
        let string2 = "foo".databaseValue
        XCTAssertEqual(string1, string2)
        XCTAssertEqual(string1.hashValue, string2.hashValue)
        
        let fooData1 = "foo".data(using: .utf8)!.databaseValue
        let fooData2 = "foo".data(using: .utf8)!.databaseValue
        XCTAssertEqual(fooData1, fooData2)
        XCTAssertEqual(fooData1.hashValue, fooData2.hashValue)
    }
    
    func testDatabaseValueDescription() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_String = "foo\n\t\r".databaseValue
        let databaseValue_Data = "foo".data(using: .utf8)!.databaseValue
        
        XCTAssertEqual(databaseValue_Null.description, "NULL")
        XCTAssertEqual(databaseValue_Int64.description, "1")
        XCTAssertEqual(databaseValue_Double.description, "100000.1")
        XCTAssertEqual(databaseValue_String.description, "\"foo\\n\\t\\r\"")
        XCTAssertEqual(databaseValue_Data.description, "Data(3 bytes)")   // may be fragile
    }
}
