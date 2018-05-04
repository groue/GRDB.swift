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
            let request = SQLRequest<Row>("SELECT 1")
            let (statement, adapter) = try request.prepare(db)
            XCTAssertEqual(statement.sql, "SELECT 1")
            XCTAssertNil(adapter)
            let row = try request.fetchOne(db)
            XCTAssertEqual(row, ["1": 1])
        }
    }
    
    func testSQLRequestWithArgumentsAndAdapter() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<Int>("SELECT ?, ?", arguments: [1, 2], adapter: SuffixRowAdapter(fromIndex: 1))
            let (statement, adapter) = try request.prepare(db)
            XCTAssertEqual(statement.sql, "SELECT ?, ?")
            XCTAssertNotNil(adapter)
            let int = try request.fetchOne(db)!
            XCTAssertEqual(int, 2)
        }
    }
    
    func testNotCachedSQLRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<Row>("SELECT 1")
            let (statement1, _) = try request.prepare(db)
            let (statement2, _) = try request.prepare(db)
            XCTAssertTrue(statement1 !== statement2)
        }
    }
    
    func testCachedSQLRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<Row>("SELECT 1", cached: true)
            let (statement1, _) = try request.prepare(db)
            let (statement2, _) = try request.prepare(db)
            XCTAssertTrue(statement1 === statement2)
        }
    }
    
    func testRequestInitializer() throws {
        struct CustomRequest: FetchRequest {
            typealias RowDecoder = Row
            func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                let statement = try db.makeSelectStatement("SELECT ? AS a, ? AS b")
                statement.arguments = [1, "foo"]
                return (statement, nil)
            }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = CustomRequest()
            let sqlRequest = try SQLRequest<Row>(db, request: request)
            XCTAssertEqual(sqlRequest.sql, "SELECT ? AS a, ? AS b")
            XCTAssertEqual(sqlRequest.arguments, [1, "foo"])
            XCTAssertEqual(try sqlRequest.fetchOne(db)!, ["a": 1, "b": "foo"])
        }
    }
}
