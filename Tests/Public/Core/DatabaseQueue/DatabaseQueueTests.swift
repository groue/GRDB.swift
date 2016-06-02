import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseQueueTests: GRDBTestCase {
    
    func testInvalidFileFormat() {
        assertNoError {
            do {
                let testBundle = NSBundle(forClass: self.dynamicType)
                let path = testBundle.pathForResource("Betty", ofType: "jpeg")!
                guard NSData(contentsOfFile: path) != nil else {
                    XCTFail("Missing file")
                    return
                }
                _ = try DatabaseQueue(path: path)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, 26) // SQLITE_NOTADB
                XCTAssertEqual(error.message!.lowercaseString, "file is encrypted or is not a database") // lowercaseString: accept multiple SQLite version
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description.lowercaseString, "sqlite error 26: file is encrypted or is not a database")
            }
        }
    }
    
    func testReleaseMemory() {
        // TODO: test DatabaseQueue.releaseMemory() ?
    }
    
    func testAddRemoveFunction() {
        // Adding a function and then removing it should succeed
        assertNoError {
            do {
                let dbQueue = try makeDatabaseQueue()
                let fn = DatabaseFunction("succ", argumentCount: 1) { databaseValues in
                     let dbv = databaseValues.first!
                     guard let int = dbv.value() as Int? else {
                        return nil
                     }
                     return int + 1
                 }
                dbQueue.addFunction(fn)
                try dbQueue.inDatabase { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT succ(1)"), 2) // 2
                    try db.execute("SELECT succ(1)")
                }
                dbQueue.removeFunction(fn)
                do {
                    try dbQueue.inDatabase { db in
                        try db.execute("SELECT succ(1)")
                        XCTFail("Expected Error")
                    }
                    XCTFail("Expected Error")
                }
                catch let error as DatabaseError {
                    // expected error
                    XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                    XCTAssertEqual(error.message!.lowercaseString, "no such function: succ") // lowercaseString: accept multiple SQLite version
                    XCTAssertEqual(error.sql!, "SELECT succ(1)")
                    XCTAssertEqual(error.description.lowercaseString, "sqlite error 1 with statement `select succ(1)`: no such function: succ")
                }
            }
        }
    }
    
    func testAddRemoveCollation() {
        // Adding a collation and then removing it should succeed
        assertNoError {
            do {
                let dbQueue = try makeDatabaseQueue()
                let collation = DatabaseCollation("test_collation_foo") { (string1, string2) in
                    return (string1 as NSString).localizedStandardCompare(string2)
                }
                dbQueue.addCollation(collation)
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE files (name TEXT COLLATE TEST_COLLATION_FOO)")
                }
                dbQueue.removeCollation(collation)
                do {
                    try dbQueue.inDatabase { db in
                        try db.execute("CREATE TABLE files_fail (name TEXT COLLATE TEST_COLLATION_FOO)")
                        XCTFail("Expected Error")
                    }
                    XCTFail("Expected Error")
                }
                catch let error as DatabaseError {
                    // expected error
                    XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                    XCTAssertEqual(error.message!.lowercaseString, "no such collation sequence: test_collation_foo") // lowercaseString: accept multiple SQLite version
                    XCTAssertEqual(error.sql!, "CREATE TABLE files_fail (name TEXT COLLATE TEST_COLLATION_FOO)")
                    XCTAssertEqual(error.description.lowercaseString, "sqlite error 1 with statement `create table files_fail (name text collate test_collation_foo)`: no such collation sequence: test_collation_foo")
                }
            }
        }
    }
    
    func testConfigurationSetGet() {
        assertNoError {
            do {
                let inputConfiguration = dbConfiguration
                let dbQueue = try makeDatabaseQueue()
                var queueConfiguration = dbQueue.configuration
                
                // Test values of the Configurations for equality
                // NOTE: some of the values can't be tested for equality (ex. closures)
                
                XCTAssertEqual(inputConfiguration.foreignKeysEnabled, queueConfiguration.foreignKeysEnabled)
                XCTAssertEqual(inputConfiguration.readonly, queueConfiguration.readonly)
                // can only test whether both have trace set
                XCTAssertTrue(compareOptional(inputConfiguration.trace, with: queueConfiguration.trace))
                #if SQLITE_HAS_CODEC
                    XCTAssertEqual(inputConfiguration.passphrase, queueConfiguration.passphrase)
                #endif
                XCTAssertTrue(compare(fileAttributes: inputConfiguration.fileAttributes, with: queueConfiguration.fileAttributes))
                XCTAssertEqual(inputConfiguration.defaultTransactionKind, queueConfiguration.defaultTransactionKind)
                XCTAssertTrue(compare(busyMode: inputConfiguration.busyMode, with: queueConfiguration.busyMode))
                XCTAssertEqual(inputConfiguration.maximumReaderCount, queueConfiguration.maximumReaderCount)
                
                //threadingMode
                //SQLiteConnectionDidOpen
                //SQLiteConnectionWillClose
                //SQLiteConnectionDidClose
                //SQLiteOpenFlags
            }
        }
    }
    
    // compares whether two optionals of type T are both nil or !nil
    private func compareOptional<T>(lhs: T?, with rhs: T?) -> Bool
    {
        if lhs != nil {
            return rhs != nil
        } else {
            return rhs == nil
        }
    }
    
    private func compare(fileAttributes lhs: [String: AnyObject]?, with rhs: [String: AnyObject]?) -> Bool
    {
        guard let lhs = lhs else { return rhs == nil }
        guard let rhs = rhs else { return false }
        
        guard Set<String>(lhs.keys) == Set<String>(rhs.keys) else { return false }
        
        for (key, value) in lhs
        {
            if let value = value as? NSObject {
                guard value.isEqual(rhs[key] as? NSObject) else {
                    return false
                }
            } else {
                // do simple nil/!nil matching test
                guard compareOptional(value, with: rhs[key]) else { return false }
            }
        }
        
        return true
    }
    
    private func compare(busyMode lhs: BusyMode, with rhs: BusyMode) -> Bool
    {
        switch (lhs, rhs) {
        case (.ImmediateError, .ImmediateError):
            return true
        case (.Timeout(let lhs_interval), .Timeout(let rhs_interval)):
            return lhs_interval == rhs_interval
        case (.Callback(_), .Callback(_)):
            // Note: can't compare callback closures
            // Just make sure both sides have Callback set
            return true
        default:
            return false
        }
    }
}
