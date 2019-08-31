import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseConfigurationTests: GRDBTestCase {
    func testOnConnect() throws {
        // onConnect is called when connection opens
        var connectionCount = 0
        var configuration = Configuration()
        configuration.onConnect { db in
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
    
    func testMultipleOnConnect() throws {
        // onConnect can be called multiple times. Order is deterministic.
        var events: [Int] = []
        var configuration = Configuration()
        configuration.onConnect { db in
            events.append(1)
        }
        configuration.onConnect { db in
            events.append(2)
        }

        _ = DatabaseQueue(configuration: configuration)
        XCTAssertEqual(events, [1, 2])
    }
    
    func testDeprecatedPrepareDatabase() throws {
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
    
    func testDeprecatedPrepareDatabaseIsCalledBeforeOnConnect() throws {
        // prepareDatabase is called before onConnect functions
        var events: [Int] = []
        var configuration = Configuration()
        configuration.onConnect { db in
            events.append(2)
        }
        configuration.prepareDatabase = { db in
            events.append(1)
        }
        configuration.onConnect { db in
            events.append(3)
        }
        
        _ = DatabaseQueue(configuration: configuration)
        XCTAssertEqual(events, [1, 2, 3])
    }
}
