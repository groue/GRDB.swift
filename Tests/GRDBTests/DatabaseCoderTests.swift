import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseCoderTests: GRDBTestCase {
    
    func testDatabaseCoder() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE arrays (array BLOB)")
            
            let array = [1,2,3]
            try db.execute("INSERT INTO arrays VALUES (?)", arguments: [DatabaseCoder(NSArray(array: array))])
            
            let row = try Row.fetchOne(db, "SELECT * FROM arrays")!
            let fetchedArray = ((row.value(named: "array") as DatabaseCoder).object as! NSArray).map { Int($0 as! NSNumber) }
            XCTAssertEqual(array, fetchedArray)
        }
    }

    func testDatabaseCoderInitNilFailure() {
        XCTAssertNil(DatabaseCoder(nil))
    }
    
    func testDatabaseCoderFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_String = "foo".databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        XCTAssertNil(DatabaseCoder.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(DatabaseCoder.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(DatabaseCoder.fromDatabaseValue(databaseValue_Double))
        XCTAssertNil(DatabaseCoder.fromDatabaseValue(databaseValue_String))
    }
}
