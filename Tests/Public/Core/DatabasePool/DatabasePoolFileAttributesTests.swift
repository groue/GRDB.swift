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
            let fm = FileManager.default
            
            try dbPool.write { db in
                try db.execute("CREATE TABLE foo (bar INTEGER)")
            }
            var attributes = try fm.attributesOfItem(atPath: dbPool.path)
            XCTAssertFalse((attributes[.extensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItem(atPath: dbPool.path + "-wal")
            XCTAssertFalse((attributes[.extensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItem(atPath: dbPool.path + "-shm")
            XCTAssertFalse((attributes[.extensionHidden] as! NSNumber).boolValue)
        }
    }
    
    func testExplicitFileAttributesOnExistingFile() {
        assertNoError {
            let fm = FileManager.default
            
            do {
                let dbPool = try makeDatabasePool()
                try dbPool.write { db in
                    try db.execute("CREATE TABLE foo (bar INTEGER)")
                }
                var attributes = try fm.attributesOfItem(atPath: dbPool.path)
                XCTAssertFalse((attributes[.extensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItem(atPath: dbPool.path + "-wal")
                XCTAssertFalse((attributes[.extensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItem(atPath: dbPool.path + "-shm")
                XCTAssertFalse((attributes[.extensionHidden] as! NSNumber).boolValue)
            }
            
            do {
                dbConfiguration.fileAttributes = [.extensionHidden: true]
                let dbPool = try makeDatabasePool()
                // TODO: this test is fragile: we have to wait until the database
                // store has been notified of file creation.
                Thread.sleep(forTimeInterval: 0.1)
                var attributes = try fm.attributesOfItem(atPath: dbPool.path)
                XCTAssertTrue((attributes[.extensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItem(atPath: dbPool.path + "-wal")
                XCTAssertTrue((attributes[.extensionHidden] as! NSNumber).boolValue)
                attributes = try fm.attributesOfItem(atPath: dbPool.path + "-shm")
                XCTAssertTrue((attributes[.extensionHidden] as! NSNumber).boolValue)
            }
        }
    }
    
    func testExplicitFileAttributesOnNewFile() {
        assertNoError {
            let fm = FileManager.default
            
            dbConfiguration.fileAttributes = [.extensionHidden: true]
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE foo (bar INTEGER)")
            }
            // TODO: this test is fragile: we have to wait until the database
            // store has been notified of file creation.
            Thread.sleep(forTimeInterval: 0.1)
            var attributes = try fm.attributesOfItem(atPath: dbPool.path)
            XCTAssertTrue((attributes[.extensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItem(atPath: dbPool.path + "-wal")
            XCTAssertTrue((attributes[.extensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItem(atPath: dbPool.path + "-shm")
            XCTAssertTrue((attributes[.extensionHidden] as! NSNumber).boolValue)
        }
    }
}
