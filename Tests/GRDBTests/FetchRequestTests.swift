import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FetchRequestTests: GRDBTestCase {
    
    func testRequestFetchRows() throws {
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Row
            func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                return try (db.makeSelectStatement("SELECT * FROM table1"), nil)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute("INSERT INTO table1 DEFAULT VALUES")
            try db.execute("INSERT INTO table1 DEFAULT VALUES")
            
            let request = CustomRequest()
            let rows = try request.fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM table1")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0], ["id": 1])
            XCTAssertEqual(rows[1], ["id": 2])
        }
    }
    
    func testRequestFetchValues() throws {
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Int
            func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                return try (db.makeSelectStatement("SELECT id FROM table1"), nil)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute("INSERT INTO table1 DEFAULT VALUES")
            try db.execute("INSERT INTO table1 DEFAULT VALUES")
            
            let request = CustomRequest()
            let ints = try request.fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT id FROM table1")
            XCTAssertEqual(ints.count, 2)
            XCTAssertEqual(ints[0], 1)
            XCTAssertEqual(ints[1], 2)
        }
    }
    
    func testRequestFetchRecords() throws {
        struct CustomRecord: FetchableRecord, Decodable {
            var id: Int
        }
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = CustomRecord
            func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                return try (db.makeSelectStatement("SELECT id FROM table1"), nil)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute("INSERT INTO table1 DEFAULT VALUES")
            try db.execute("INSERT INTO table1 DEFAULT VALUES")
            
            let request = CustomRequest()
            let records = try request.fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT id FROM table1")
            XCTAssertEqual(records.count, 2)
            XCTAssertEqual(records[0].id, 1)
            XCTAssertEqual(records[1].id, 2)
        }
    }
    
    func testRequestFetchCount() throws {
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Row
            func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                return try (db.makeSelectStatement("SELECT * FROM table1"), nil)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute("INSERT INTO table1 DEFAULT VALUES")
            try db.execute("INSERT INTO table1 DEFAULT VALUES")
            
            let request = CustomRequest()
            let count = try request.fetchCount(db)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT * FROM table1)")
            XCTAssertEqual(count, 2)
        }
    }
    
    func testRequestCustomizedFetchCount() throws {
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Row
            func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                return try (db.makeSelectStatement("INVALID"), nil)
            }
            
            func fetchCount(_ db: Database) throws -> Int {
                return 2
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute("INSERT INTO table1 DEFAULT VALUES")
            try db.execute("INSERT INTO table1 DEFAULT VALUES")
            
            let request = CustomRequest()
            let count = try request.fetchCount(db)
            XCTAssertEqual(lastSQLQuery, "INSERT INTO table1 DEFAULT VALUES")
            XCTAssertEqual(count, 2)
        }
    }
}
