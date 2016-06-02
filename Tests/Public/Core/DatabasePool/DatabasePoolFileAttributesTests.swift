import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabasePoolFileAttributesTests: GRDBTestCase {
    
    func testDefaultFileAttributes() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            let fm = NSFileManager.default()
            
            try dbPool.write { db in
                try db.execute("CREATE TABLE foo (bar INTEGER)")
            }
            var attributes = try fm.attributesOfItem(atPath: dbPool.path)
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItem(atPath: dbPool.path + "-wal")
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItem(atPath: dbPool.path + "-shm")
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
    
    func testExplicitFileAttributesOnExistingFile() {
        assertNoError {
            let fm = NSFileManager.default()
            
            do {
                let dbPool = try makeDatabasePool()
                try dbPool.write { db in
                    try db.execute("CREATE TABLE foo (bar INTEGER)")
                }
                var attributes = try fm.attributesOfItem(atPath: dbPool.path)
                XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItem(atPath: dbPool.path + "-wal")
                XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItem(atPath: dbPool.path + "-shm")
                XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            }
            
            do {
                dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
                let dbPool = try makeDatabasePool()
                // TODO: this test is fragile: we have to wait until the database
                // store has been notified of file creation.
                NSThread.sleep(forTimeInterval: 0.1)
                var attributes = try fm.attributesOfItem(atPath: dbPool.path)
                XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItem(atPath: dbPool.path + "-wal")
                XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItem(atPath: dbPool.path + "-shm")
                XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            }
        }
    }
    
    func testExplicitFileAttributesOnNewFile() {
        assertNoError {
            let fm = NSFileManager.default()
            
            dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE foo (bar INTEGER)")
            }
            // TODO: this test is fragile: we have to wait until the database
            // store has been notified of file creation.
            NSThread.sleep(forTimeInterval: 0.1)
            var attributes = try fm.attributesOfItem(atPath: dbPool.path)
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItem(atPath: dbPool.path + "-wal")
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItem(atPath: dbPool.path + "-shm")
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
}
