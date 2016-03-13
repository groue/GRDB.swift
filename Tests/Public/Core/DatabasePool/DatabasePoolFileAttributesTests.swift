import XCTest
@testable import GRDB   // This is a public test where we use the dbPool.store.sync() private API :-/

class DatabasePoolFileAttributesTests: GRDBTestCase {
    
    func testDefaultFileAttributes() {
        assertNoError {
            let fm = NSFileManager.defaultManager()
            
            try dbPool.execute("CREATE TABLE foo (bar INTEGER)")
            dbPool.store.sync() // Private API
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
            dbPool.store.sync() // Private API
            dbPool = nil
            var attributes = try fm.attributesOfItemAtPath(dbPoolPath)
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-wal")
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-shm")
            XCTAssertFalse((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            
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
            dbPool.store.sync() // Private API
            var attributes = try fm.attributesOfItemAtPath(dbPoolPath)
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-wal")
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
            attributes = try fm.attributesOfItemAtPath(dbPoolPath + "-shm")
            XCTAssertTrue((attributes[NSFileExtensionHidden] as! NSNumber).boolValue)
        }
    }
}
