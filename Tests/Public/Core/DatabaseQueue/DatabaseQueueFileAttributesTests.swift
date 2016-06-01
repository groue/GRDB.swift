import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseQueueFileAttributesTests: GRDBTestCase {
    
    func testDefaultFileAttributes() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            let dbQueue = try makeDatabaseQueue()
            var attributes = try fm.attributesOfItemAtPath(dbQueue.path)
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
    
    func testExplicitFileAttributesOnExistingFile() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            do {
                let dbQueue = try makeDatabaseQueue()
                let attributes = try fm.attributesOfItemAtPath(dbQueue.path)
                XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            }
            
            do {
                dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
                let dbQueue = try makeDatabaseQueue()
                let attributes = try fm.attributesOfItemAtPath(dbQueue.path)
                XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            }
        }
    }
    
    func testExplicitFileAttributesOnNewFile() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
            let dbQueue = try makeDatabaseQueue()
            // TODO: this test is fragile: we have to wait until the database
            // store has been notified of file creation.
            NSThread.sleepForTimeInterval(0.1)
            var attributes = try fm.attributesOfItemAtPath(dbQueue.path)
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
}
