import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class SQLRequestTests: GRDBTestCase {
    
    func testSQLRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest("SELECT 1")
            let (statement, adapter) = try request.prepare(db)
            XCTAssertEqual(statement.sql, "SELECT 1")
            XCTAssertNil(adapter)
        }
    }
    
    func testSQLRequestWithArgumentsAndAdapter() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest("SELECT ?, ?", arguments: [1, 2], adapter: SuffixRowAdapter(fromIndex: 1))
            let (statement, adapter) = try request.prepare(db)
            XCTAssertEqual(statement.sql, "SELECT ?, ?")
            XCTAssertNotNil(adapter)
            let int = try Int.fetchOne(db, request)!
            XCTAssertEqual(int, 2)
        }
    }
    
    func testNotCachedSQLRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest("SELECT 1")
            let (statement1, _) = try request.prepare(db)
            let (statement2, _) = try request.prepare(db)
            XCTAssertTrue(statement1 !== statement2)
        }
    }
    
    func testCachedSQLRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest("SELECT 1", cached: true)
            let (statement1, _) = try request.prepare(db)
            let (statement2, _) = try request.prepare(db)
            XCTAssertTrue(statement1 === statement2)
        }
    }
    
    func testAsSQLRequest() throws {
        struct CustomRequest: Request {
            func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                return try SQLRequest("SELECT ?, ?", arguments: [1, "foo"]).prepare(db)
            }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = CustomRequest()
            let sqlRequest = try request.asSQLRequest(db)
            XCTAssertEqual(sqlRequest.sql, "SELECT ?, ?")
            XCTAssertEqual(sqlRequest.arguments, [1, "foo"])
        }
    }
}
