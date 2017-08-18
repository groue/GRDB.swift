import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseQueueTests: GRDBTestCase {
    
    // Until SPM tests can load resources, disable this test for SPM.
    #if !SWIFT_PACKAGE
    func testInvalidFileFormat() throws {
        do {
            let testBundle = Bundle(for: type(of: self))
            let url = testBundle.url(forResource: "Betty", withExtension: "jpeg")!
            guard (try? Data(contentsOf: url)) != nil else {
                XCTFail("Missing file")
                return
            }
            _ = try DatabaseQueue(path: url.path)
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
            XCTAssert([
                "file is encrypted or is not a database",
                "file is not a database"].contains(error.message!))
            XCTAssertTrue(error.sql == nil)
            XCTAssert([
                "SQLite error 26: file is encrypted or is not a database",
                "SQLite error 26: file is not a database"].contains(error.description))
        }
    }
    #endif
    
    func testAddRemoveFunction() throws {
        // Adding a function and then removing it should succeed
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("succ", argumentCount: 1) { dbValues in
            guard let int = Int.fromDatabaseValue(dbValues[0]) else {
                return nil
            }
            return int + 1
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Int.fetchOne(db, "SELECT succ(1)"), 2) // 2
        }
        dbQueue.remove(function: fn)
        do {
            try dbQueue.inDatabase { db in
                try db.execute("SELECT succ(1)")
                XCTFail("Expected Error")
            }
            XCTFail("Expected Error")
        }
        catch let error as DatabaseError {
            // expected error
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssertEqual(error.message!.lowercased(), "no such function: succ") // lowercaseString: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "SELECT succ(1)")
            XCTAssertEqual(error.description.lowercased(), "sqlite error 1 with statement `select succ(1)`: no such function: succ")
        }
    }

    func testAddRemoveCollation() throws {
        // Adding a collation and then removing it should succeed
        let dbQueue = try makeDatabaseQueue()
        let collation = DatabaseCollation("test_collation_foo") { (string1, string2) in
            return (string1 as NSString).localizedStandardCompare(string2)
        }
        dbQueue.add(collation: collation)
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE files (name TEXT COLLATE TEST_COLLATION_FOO)")
        }
        dbQueue.remove(collation: collation)
        do {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE files_fail (name TEXT COLLATE TEST_COLLATION_FOO)")
                XCTFail("Expected Error")
            }
            XCTFail("Expected Error")
        }
        catch let error as DatabaseError {
            // expected error
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssertEqual(error.message!.lowercased(), "no such collation sequence: test_collation_foo") // lowercaseString: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "CREATE TABLE files_fail (name TEXT COLLATE TEST_COLLATION_FOO)")
            XCTAssertEqual(error.description.lowercased(), "sqlite error 1 with statement `create table files_fail (name text collate test_collation_foo)`: no such collation sequence: test_collation_foo")
        }
    }
}
