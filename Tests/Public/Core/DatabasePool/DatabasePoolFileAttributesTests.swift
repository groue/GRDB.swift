import XCTest
import GRDB

class DatabasePoolFileAttributesTests: GRDBTestCase {
    
    func testDefaultFileAttributes() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            try dbPool.execute("CREATE TABLE foo (bar INTEGER)")
            var attributes = try fm.attributesOfItemAtPath(dbPoolPath)
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-wal")
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-shm")
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
    
    func testExplicitFileAttributesOnExistingFile() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            try dbPool.execute("CREATE TABLE foo (bar INTEGER)")
            var attributes = try fm.attributesOfItemAtPath(dbPoolPath)
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-wal")
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-shm")
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            dbPool = nil
            
            dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
            _ = dbPool
            attributes = try fm.attributesOfItemAtPath(dbPoolPath)
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-wal")
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-shm")
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
    
    func testExplicitFileAttributesOnNewFile() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
            try dbPool.execute("CREATE TABLE foo (bar INTEGER)")
            // TODO: this test is fragile: we have to wait until the database
            // store has been notified of file creation.
            NSThread.sleepForTimeInterval(0.1)
            var attributes = try fm.attributesOfItemAtPath(dbPoolPath)
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-wal")
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-shm")
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
}
