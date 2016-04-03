import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

class DatabasePoolFileAttributesTests: GRDBTestCase {
    
    func testDefaultFileAttributes() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            let fm = NSFileManager.defaultManager()
            
            try dbPool.execute("CREATE TABLE foo (bar INTEGER)")
            var attributes = try fm.attributesOfItemAtPath(dbPool.path)
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPool.path + "-wal")
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPool.path + "-shm")
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
    
    func testExplicitFileAttributesOnExistingFile() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            do {
                let dbPool = try makeDatabasePool()
                try dbPool.execute("CREATE TABLE foo (bar INTEGER)")
                var attributes = try fm.attributesOfItemAtPath(dbPool.path)
                XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItemAtPath(dbPool.path + "-wal")
                XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItemAtPath(dbPool.path + "-shm")
                XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            }
            
            do {
                dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
                let dbPool = try makeDatabasePool()
                // TODO: this test is fragile: we have to wait until the database
                // store has been notified of file creation.
                NSThread.sleepForTimeInterval(0.1)
                var attributes = try fm.attributesOfItemAtPath(dbPool.path)
                XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItemAtPath(dbPool.path + "-wal")
                XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItemAtPath(dbPool.path + "-shm")
                XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            }
        }
    }
    
    func testExplicitFileAttributesOnNewFile() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
            let dbPool = try makeDatabasePool()
            try dbPool.execute("CREATE TABLE foo (bar INTEGER)")
            // TODO: this test is fragile: we have to wait until the database
            // store has been notified of file creation.
            NSThread.sleepForTimeInterval(0.1)
            var attributes = try fm.attributesOfItemAtPath(dbPool.path)
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPool.path + "-wal")
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPool.path + "-shm")
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
}
