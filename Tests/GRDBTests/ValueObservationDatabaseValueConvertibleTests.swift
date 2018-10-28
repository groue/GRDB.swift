import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    import GRDB
#endif

private struct Name: DatabaseValueConvertible {
    var rawValue: String
    
    var databaseValue: DatabaseValue {
        return rawValue.databaseValue
    }
    
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Name? {
        guard let rawValue = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return Name(rawValue: rawValue)
    }
}

class ValueObservationDatabaseValueConvertibleTests: GRDBTestCase {
    func testAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Name]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        var observation = ValueObservation.forAll(SQLRequest<Name>("SELECT name FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try dbQueue.add(observation: observation) { names in
            results.append(names)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write {
            try $0.execute("UPDATE t SET name = 'foo' WHERE id = 1")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
            [],
            ["foo"],
            ["foo"],
            ["foo", "bar"]])
    }
    
    func testAllWithUniquing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Name]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        var observation = ValueObservation.forAll(withUniquing: SQLRequest<Name>("SELECT name FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try dbQueue.add(observation: observation) { names in
            results.append(names)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write {
            try $0.execute("UPDATE t SET name = 'foo' WHERE id = 1")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
            [],
            ["foo"],
            ["foo", "bar"]])
    }
    
    func testOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Name?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 5
        
        var observation = ValueObservation.forOne(SQLRequest<Name>("SELECT name FROM t ORDER BY id DESC"))
        observation.extent = .databaseLifetime
        _ = try dbQueue.add(observation: observation) { name in
            results.append(name)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write {
            try $0.execute("UPDATE t SET name = 'foo' WHERE id = 1")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
        }
        try dbQueue.write {
            try $0.execute("DELETE FROM t")
        }

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
            nil,
            "foo",
            "foo",
            "bar",
            nil])
    }
    
    func testOneWithUniquing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Name?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        var observation = ValueObservation.forOne(withUniquing: SQLRequest<Name>("SELECT name FROM t ORDER BY id DESC"))
        observation.extent = .databaseLifetime
        _ = try dbQueue.add(observation: observation) { name in
            results.append(name)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write {
            try $0.execute("UPDATE t SET name = 'foo' WHERE id = 1")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
        }
        try dbQueue.write {
            try $0.execute("DELETE FROM t")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
            nil,
            "foo",
            "bar",
            nil])
    }
    
    func testAllOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Name?]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        var observation = ValueObservation.forAll(SQLRequest<Name?>("SELECT name FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try dbQueue.add(observation: observation) { names in
            results.append(names)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write {
            try $0.execute("UPDATE t SET name = 'foo' WHERE id = 1")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (2, NULL)")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results.map { $0.map { $0?.rawValue }}, [
            [],
            ["foo"],
            ["foo"],
            ["foo", nil]])
    }
    
    func testAllOptionalWithUniquing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Name?]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        var observation = ValueObservation.forAll(withUniquing: SQLRequest<Name?>("SELECT name FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try dbQueue.add(observation: observation) { names in
            results.append(names)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write {
            try $0.execute("UPDATE t SET name = 'foo' WHERE id = 1")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (2, NULL)")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results.map { $0.map { $0?.rawValue }}, [
            [],
            ["foo"],
            ["foo", nil]])
    }
}
