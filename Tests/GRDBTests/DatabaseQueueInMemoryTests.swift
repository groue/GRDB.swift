import XCTest
import GRDB

class DatabaseQueueInMemoryTests : GRDBTestCase {
    func test_independent_in_memory_database() throws {
        let baz = try DatabaseQueue().write { db in
            try db.execute(sql: "CREATE TABLE foo (bar TEXT)")
            try db.execute(sql: "INSERT INTO foo (bar) VALUES ('baz')")
            return try String.fetchOne(db, sql: "SELECT bar FROM foo")!
        }
        XCTAssertEqual(baz, "baz")
    }
    
    func test_independent_in_memory_databases_are_independent() throws {
        try DatabaseQueue().write { db in
            try db.execute(sql: "CREATE TABLE foo (bar TEXT)")
        }
        
        try XCTAssertFalse(DatabaseQueue().read { try $0.tableExists("foo") })
    }
    
    func test_shared_in_memory_database() throws {
        let name = UUID().uuidString
        let baz = try DatabaseQueue(named: name).write { db in
            try db.execute(sql: "CREATE TABLE foo (bar TEXT)")
            try db.execute(sql: "INSERT INTO foo (bar) VALUES ('baz')")
            return try String.fetchOne(db, sql: "SELECT bar FROM foo")!
        }
        XCTAssertEqual(baz, "baz")
    }
    
    func test_shared_in_memory_databases_are_shared_by_name() throws {
        let nameA = UUID().uuidString
        let dbA = try DatabaseQueue(named: nameA)
        try dbA.write { db in
            try db.execute(sql: "CREATE TABLE foo (bar TEXT)")
        }
        
        try withExtendedLifetime(dbA) {
            try XCTAssertTrue(DatabaseQueue(named: nameA).read { try $0.tableExists("foo") })
            try XCTAssertFalse(DatabaseQueue(named: UUID().uuidString).read { try $0.tableExists("foo") })
        }
    }
}
