import XCTest
import GRDB

class DatabaseQueueFileAttributesTests: GRDBTestCase {
    
    func testDefaultFileAttributes() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            _ = dbQueue
            var attributes = try fm.attributesOfItemAtPath(dbQueuePath)
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
    
    func testExplicitFileAttributesOnExistingFile() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            _ = dbQueue
            dbQueue = nil
            var attributes = try fm.attributesOfItemAtPath(dbQueuePath)
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            
            dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
            _ = dbQueue
            attributes = try fm.attributesOfItemAtPath(dbQueuePath)
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
    
    func testExplicitFileAttributesOnNewFile() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            dbConfiguration.fileAttributes = [NSFileExtensionHidden: true]
            _ = dbQueue
            // TODO: this test is fragile: we have to wait until the database
            // store has been notified of file creation.
            NSThread.sleepForTimeInterval(0.1)
            var attributes = try fm.attributesOfItemAtPath(dbQueuePath)
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
}
