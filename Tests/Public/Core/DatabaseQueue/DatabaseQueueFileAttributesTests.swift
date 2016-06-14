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
            let fm = FileManager.default()
            
            let dbQueue = try makeDatabaseQueue()
            var attributes = try fm.attributesOfItem(atPath: dbQueue.path)
            XCTAssertFalse((attributes[FileAttributeKey.extensionHidden.rawValue] as! NSNumber).boolValue)
        }
    }
    
    func testExplicitFileAttributesOnExistingFile() {
        assertNoError {
            let fm = FileManager.default()
            
            do {
                let dbQueue = try makeDatabaseQueue()
                let attributes = try fm.attributesOfItem(atPath: dbQueue.path)
                XCTAssertFalse((attributes[FileAttributeKey.extensionHidden.rawValue] as! NSNumber).boolValue)
            }
            
            do {
                dbConfiguration.fileAttributes = [FileAttributeKey.extensionHidden.rawValue: true]
                let dbQueue = try makeDatabaseQueue()
                let attributes = try fm.attributesOfItem(atPath: dbQueue.path)
                XCTAssertTrue((attributes[FileAttributeKey.extensionHidden.rawValue] as! NSNumber).boolValue)
            }
        }
    }
    
    func testExplicitFileAttributesOnNewFile() {
        assertNoError {
            let fm = FileManager.default()
            
            dbConfiguration.fileAttributes = [FileAttributeKey.extensionHidden.rawValue: true]
            let dbQueue = try makeDatabaseQueue()
            // TODO: this test is fragile: we have to wait until the database
            // store has been notified of file creation.
            Thread.sleep(forTimeInterval: 0.1)
            var attributes = try fm.attributesOfItem(atPath: dbQueue.path)
            XCTAssertTrue((attributes[FileAttributeKey.extensionHidden.rawValue] as! NSNumber).boolValue)
        }
    }
}
