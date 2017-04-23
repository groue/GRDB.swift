import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseWriterTests : GRDBTestCase {
    
    func testDatabaseQueueAvailableDatabaseConnection() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertTrue(dbQueue.availableDatabaseConnection == nil)
        dbQueue.inDatabase { db in
            XCTAssertTrue(dbQueue.availableDatabaseConnection != nil)
        }
    }
    
    func testDatabasePoolAvailableDatabaseConnection() throws {
        let dbPool = try makeDatabasePool()
        XCTAssertTrue(dbPool.availableDatabaseConnection == nil)
        dbPool.write { db in
            XCTAssertTrue(dbPool.availableDatabaseConnection != nil)
        }
    }
}
