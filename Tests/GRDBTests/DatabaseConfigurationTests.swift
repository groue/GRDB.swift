import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseConfigurationTests: GRDBTestCase {
    func testPrepareDatabase() throws {
        // prepareDatabase is called when connection opens
        var connectionCount = 0
        var configuration = Configuration()
        configuration.prepareDatabase = { db in
            connectionCount += 1
        }
        
        _ = DatabaseQueue(configuration: configuration)
        XCTAssertEqual(connectionCount, 1)
        
        _ = try makeDatabaseQueue(configuration: configuration)
        XCTAssertEqual(connectionCount, 2)
        
        let pool = try makeDatabasePool(configuration: configuration)
        XCTAssertEqual(connectionCount, 3)
        
        try pool.read { _ in }
        XCTAssertEqual(connectionCount, 4)
        
        try pool.makeSnapshot().read { _ in }
        XCTAssertEqual(connectionCount, 5)
    }
    
    func testPrepareDatabaseError() throws {
        struct TestError: Error { }
        var error: TestError?
        
        var configuration = Configuration()
        configuration.prepareDatabase = { db in
            if let error = error {
                throw error
            }
        }
        
        // TODO: what about in-memory DatabaseQueue???
        
        do {
            error = TestError()
            _ = try makeDatabaseQueue(configuration: configuration)
            XCTFail("Expected TestError")
        } catch is TestError { }
        
        do {
            error = TestError()
            _ = try makeDatabasePool(configuration: configuration)
            XCTFail("Expected TestError")
        } catch is TestError { }
        
        do {
            error = nil
            let pool = try makeDatabasePool(configuration: configuration)
            
            do {
                error = TestError()
                try pool.read { _ in }
                XCTFail("Expected TestError")
            } catch is TestError { }
            
            do {
                error = TestError()
                _ = try pool.makeSnapshot()
                XCTFail("Expected TestError")
            } catch is TestError { }
        }
    }
}
