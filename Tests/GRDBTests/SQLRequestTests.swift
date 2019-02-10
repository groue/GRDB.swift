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
    
    func testSQLStringInitializer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<String>(SQLString(sql: """
                SELECT ?
                """, arguments: ["O'Brien"]))
            XCTAssertEqual(request.sql, """
                SELECT ?
                """)
            let string = try request.fetchOne(db)!
            XCTAssertEqual(string, "O'Brien")
        }
    }
    
    #if swift(>=5.0)
    func testSQLStringInitializerWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<String>(SQLString("""
                SELECT \("O'Brien")
                """))
            XCTAssertEqual(request.sql, """
                SELECT ?
                """)
            let string = try request.fetchOne(db)!
            XCTAssertEqual(string, "O'Brien")
        }
    }
    #endif

    #if swift(>=5.0)
    func testSQLInterpolation() throws {
        // This test assumes SQLRequest interpolation is based on
        // SQLInterpolation, just like SQLString. We thus test much less
        // cases.
        struct Player: Codable, TableRecord {
            var id: Int64?
            var name: String
            
            static func filter(id: Int64) -> SQLRequest<Player> {
                return """
                    SELECT *
                    FROM \(self)
                    WHERE \(CodingKeys.id) = \(id)
                    """
            }

            static func filter(ids: [Int64]) -> SQLRequest<Player> {
                return """
                    SELECT *
                    FROM \(self)
                    WHERE \(CodingKeys.id) IN \(ids)
                    """
            }

            static func genericFilter<S>(ids: S) -> SQLRequest<Player> where S: Sequence, S.Element == Int64 {
                return """
                    SELECT *
                    FROM \(self)
                    WHERE \(CodingKeys.id) IN \(ids)
                    """
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            
            do {
                let request = Player.filter(id: 42)
                XCTAssertEqual(request.sql, """
                    SELECT *
                    FROM "player"
                    WHERE "id" = ?
                    """)
                _ = try Row.fetchOne(db, request)
                XCTAssertEqual(lastSQLQuery, """
                    SELECT *
                    FROM "player"
                    WHERE "id" = 42
                    """)
            }
            
            do {
                let request = Player.filter(ids: [1, 2, 3])
                XCTAssertEqual(request.sql, """
                    SELECT *
                    FROM "player"
                    WHERE "id" IN (?,?,?)
                    """)
                _ = try Row.fetchOne(db, request)
                XCTAssertEqual(lastSQLQuery, """
                    SELECT *
                    FROM "player"
                    WHERE "id" IN (1,2,3)
                    """)
            }
            
            do {
                let request = Player.genericFilter(ids: [42, 666])
                XCTAssertEqual(request.sql, """
                    SELECT *
                    FROM "player"
                    WHERE "id" IN (?,?)
                    """)
                _ = try Row.fetchOne(db, request)
                XCTAssertEqual(lastSQLQuery, """
                    SELECT *
                    FROM "player"
                    WHERE "id" IN (42,666)
                    """)
            }
        }
    }
    #endif
}
