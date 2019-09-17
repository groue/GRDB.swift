import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class SQLRequestTests: GRDBTestCase {
    
    func testSQLRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<Row>(sql: "SELECT 1")
            let (statement, adapter) = try request.prepare(db, forSingleResult: false)
            XCTAssertEqual(statement.sql, "SELECT 1")
            XCTAssertNil(adapter)
            let row = try request.fetchOne(db)
            XCTAssertEqual(row, ["1": 1])
        }
    }
    
    func testSQLRequestWithArgumentsAndAdapter() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<Int>(sql: "SELECT ?, ?", arguments: [1, 2], adapter: SuffixRowAdapter(fromIndex: 1))
            let (statement, adapter) = try request.prepare(db, forSingleResult: false)
            XCTAssertEqual(statement.sql, "SELECT ?, ?")
            XCTAssertNotNil(adapter)
            let int = try request.fetchOne(db)!
            XCTAssertEqual(int, 2)
        }
    }
    
    func testNotCachedSQLRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<Row>(sql: "SELECT 1")
            let (statement1, _) = try request.prepare(db, forSingleResult: false)
            let (statement2, _) = try request.prepare(db, forSingleResult: false)
            XCTAssertTrue(statement1 !== statement2)
        }
    }
    
    func testCachedSQLRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<Row>(sql: "SELECT 1", cached: true)
            let (statement1, _) = try request.prepare(db, forSingleResult: false)
            let (statement2, _) = try request.prepare(db, forSingleResult: false)
            XCTAssertTrue(statement1 === statement2)
        }
    }
    
    func testRequestInitializer() throws {
        struct CustomRequest: FetchRequest {
            typealias RowDecoder = Row
            func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
                let statement = try db.makeSelectStatement(sql: "SELECT ? AS a, ? AS b")
                statement.arguments = [1, "foo"]
                return PreparedRequest(statement: statement)
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
    
    func testRequestInitializerAndSingleResultHint() throws {
        struct CustomRequest: FetchRequest {
            typealias RowDecoder = Row
            func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
                if singleResult { fatalError("not implemented") }
                return try PreparedRequest(statement: db.makeSelectStatement(sql: "SELECT 'multiple'"))
            }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            let request = try SQLRequest(db, request: CustomRequest())
            XCTAssertEqual(request.sql, "SELECT 'multiple'")
        }
    }

    func testSQLLiteralInitializer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<String>(literal: SQLLiteral(sql: """
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
    func testLiteralInitializer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<String>("""
                SELECT \("O'Brien")
                """)
            XCTAssertEqual(request.sql, """
                SELECT ?
                """)
            let string = try request.fetchOne(db)!
            XCTAssertEqual(string, "O'Brien")
        }
    }
    
    func testSQLLiteralInitializerWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<String>(literal: """
                SELECT \("O'Brien")
                """)
            XCTAssertEqual(request.sql, """
                SELECT ?
                """)
            let string = try request.fetchOne(db)!
            XCTAssertEqual(string, "O'Brien")
        }
    }
    
    func testSQLInterpolation() throws {
        // This test assumes SQLRequest interpolation is based on
        // SQLInterpolation, just like SQLLiteral. We thus test much less
        // cases.
        struct Player: Codable, TableRecord, FetchableRecord, PersistableRecord {
            var id: Int64
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

            static func filter<S>(excludedIds: S) -> SQLRequest<Player> where S: Sequence, S.Element == Int64 {
                return """
                    SELECT *
                    FROM \(self)
                    WHERE \(CodingKeys.id) NOT IN \(excludedIds)
                    """
            }
            
            // The test pass if this method compiles.
            static func complexRequest() -> SQLRequest<Player> {
                let query: SQLLiteral = "SELECT * FROM \(self)"
                return SQLRequest(literal: query)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            
            try Player(id: 1, name: "Arthur").insert(db)
            try Player(id: 42, name: "Barbara").insert(db)
            
            do {
                let request = Player.filter(id: 42)
                XCTAssertEqual(request.sql, """
                    SELECT *
                    FROM "player"
                    WHERE "id" = ?
                    """)
                let player = try request.fetchOne(db)!
                XCTAssertEqual(player.name, "Barbara")
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
                let players = try request.fetchAll(db)
                XCTAssertEqual(players.count, 1)
                XCTAssertEqual(players[0].name, "Arthur")
                XCTAssertEqual(lastSQLQuery, """
                    SELECT *
                    FROM "player"
                    WHERE "id" IN (1,2,3)
                    """)
            }
            
            do {
                let request = Player.filter(ids: [])
                XCTAssertEqual(request.sql, """
                    SELECT *
                    FROM "player"
                    WHERE "id" IN (SELECT NULL WHERE NULL)
                    """)
                let players = try request.fetchAll(db)
                XCTAssert(players.isEmpty)
                XCTAssertEqual(lastSQLQuery, """
                    SELECT *
                    FROM "player"
                    WHERE "id" IN (SELECT NULL WHERE NULL)
                    """)
            }
            
            do {
                let request = Player.filter(excludedIds: [42, 666])
                XCTAssertEqual(request.sql, """
                    SELECT *
                    FROM "player"
                    WHERE "id" NOT IN (?,?)
                    """)
                let players = try request.fetchAll(db)
                XCTAssertEqual(players.count, 1)
                XCTAssertEqual(players[0].name, "Arthur")
                XCTAssertEqual(lastSQLQuery, """
                    SELECT *
                    FROM "player"
                    WHERE "id" NOT IN (42,666)
                    """)
            }
            
            do {
                let request = Player.filter(excludedIds: [])
                XCTAssertEqual(request.sql, """
                    SELECT *
                    FROM "player"
                    WHERE "id" NOT IN (SELECT NULL WHERE NULL)
                    """)
                let players = try request.fetchAll(db)
                XCTAssertEqual(players.count, 2)
                XCTAssertEqual(lastSQLQuery, """
                    SELECT *
                    FROM "player"
                    WHERE "id" NOT IN (SELECT NULL WHERE NULL)
                    """)
            }
        }
    }
    #endif
}
