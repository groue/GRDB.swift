import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

class DatabaseQueueFileAttributesTests: GRDBTestCase {
    
    func testDefaultFileAttributes() {
        assertNoError {
            let fm = NSFileManager.default()
            
            let dbQueue = try makeDatabaseQueue()
            var attributes = try fm.attributesOfItem(atPath: dbQueue.path)
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
    
    func testExplicitFileAttributesOnExistingFile() {
        assertNoError {
            let fm = NSFileManager.default()
            
            do {
                let dbQueue = try makeDatabaseQueue()
                let attributes = try fm.attributesOfItem(atPath: dbQueue.path)
                XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            }
            
            do {
                dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
                let dbQueue = try makeDatabaseQueue()
                let attributes = try fm.attributesOfItem(atPath: dbQueue.path)
                XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            }
        }
    }
    
    func testExplicitFileAttributesOnNewFile() {
        assertNoError {
            let fm = NSFileManager.default()
            
            dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
            let dbQueue = try makeDatabaseQueue()
            // TODO: this test is fragile: we have to wait until the database
            // store has been notified of file creation.
            NSThread.sleep(forTimeInterval: 0.1)
            var attributes = try fm.attributesOfItem(atPath: dbQueue.path)
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
}
