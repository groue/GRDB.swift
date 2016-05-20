import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
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
}
