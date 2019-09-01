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
    }
}
