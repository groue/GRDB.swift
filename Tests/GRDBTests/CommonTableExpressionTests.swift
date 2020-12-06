import XCTest
import GRDB

class CommonTableExpressionTests: GRDBTestCase {
    func testQuery() throws {
        struct T: TableRecord { }
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            
            // Just add a WITH clause: sql + arguments
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    sql: "SELECT ?",
                    arguments: ["O'Brien"])
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT * FROM "t"
                    """)
            }
            
            // Just add a WITH clause: sql interpolation
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    literal: "SELECT \("O'Brien")")
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT * FROM "t"
                    """)
            }
            
            // Just add a WITH clause: query interface request
            do {
                let cteRequest = T.all()
                let cte = CommonTableExpression<Void>(named: "cte", request: cteRequest)
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT * FROM "t"
                    """)
            }
            
            // Just add a WITH clause: sql request
            do {
                let cteRequest: SQLRequest<Int> = "SELECT \("O'Brien")"
                let cte = CommonTableExpression<Void>(named: "cte", request: cteRequest)
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT * FROM "t"
                    """)
            }
            
            // Include query interface request as a CTE
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .including(optional: T.association(to: cte, on: { (left, right) in left["id"] > right["id"] }))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    LEFT JOIN "cte" ON "t"."id" > "cte"."id"
                    """)
            }
            
            // Include SQL request as a CTE
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    literal: "SELECT 1 as id")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] == right["id"] }))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 1 as id) \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON "t"."id" = "cte"."id"
                    """)
            }
            
            // Include a filtered SQL request as a CTE
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    literal: "SELECT 1 AS a")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte).filter(Column("a") != nil))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 1 AS a) \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON "cte"."a" IS NOT NULL
                    """)
            }
            
            // Include SQL request as a CTE (empty columns)
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    columns: [],
                    literal: "SELECT 1 AS id")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] == right["id"] }))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 1 AS id) \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON "t"."id" = "cte"."id"
                    """)
            }
            
            // Include SQL request as a CTE (custom column name)
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    columns: ["id", "a"],
                    literal: "SELECT 1, 2")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] == right["id"] }))
                try assertEqualSQL(db, request, """
                    WITH "cte"("id", "a") AS (SELECT 1, 2) \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON "t"."id" = "cte"."id"
                    """)
            }
            
            // Include SQL request as a CTE (empty ON clause)
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    literal: "SELECT \("O'Brien")")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte"
                    """)
            }
            
            // Join query interface request as a CTE
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .joining(required: T.association(to: cte, on: { (left, right) in left["id"] > right["id"] }))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".* \
                    FROM "t" \
                    JOIN "cte" ON "t"."id" > "cte"."id"
                    """)
            }
            
            // Include filtered CTE
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte).filter(Column("id") > 0))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON "cte"."id" > 0
                    """)
            }
            
            // Include ordered CTE
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte).order(Column("id")))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" \
                    ORDER BY "cte"."id"
                    """)
            }
            
            // Aliased CTE
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let alias = TableAlias()
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte).aliased(alias))
                    .filter(alias[Column("id")] > 0)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" \
                    WHERE "cte"."id" > 0
                    """)
            }
            
            // Include one CTE twice with same key and condition
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] > right["id"] }))
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] > right["id"] }))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON "t"."id" > "cte"."id"
                    """)
            }
            
            // Include one CTE twice with same key but different condition (last condition wins)
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] > right["id"] }))
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] + right["id"] == 1 }))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON ("t"."id" + "cte"."id") = 1
                    """)
            }
            
            // Include one CTE twice with different keys
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] > right["id"] }).forKey("a"))
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] < right["id"] }).forKey("b"))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte1".*, "cte2".* \
                    FROM "t" \
                    JOIN "cte" "cte1" ON "t"."id" > "cte1"."id" \
                    JOIN "cte" "cte2" ON "t"."id" < "cte2"."id"
                    """)
            }
            
            // Chain CTE includes
            do {
                enum CTE1 { }
                enum CTE2 { }
                let cte1 = CommonTableExpression<CTE1>(named: "cte1", request: T.all())
                let cte2 = CommonTableExpression<CTE2>(
                    named: "cte2",
                    literal: "SELECT \("O'Brien")")
                let assoc1 = T.association(to: cte1)
                let assoc2 = cte1.association(to: cte2)
                let assoc3 = cte2.association(to: T.self)
                let request = T.all()
                    .with(cte1)
                    .with(cte2)
                    .including(required: assoc1.including(required: assoc2.including(required: assoc3)))
                try assertEqualSQL(db, request, """
                    WITH \
                    "cte1" AS (SELECT * FROM "t"), \
                    "cte2" AS (SELECT 'O''Brien') \
                    SELECT "t1".*, "cte1".*, "cte2".*, "t2".* \
                    FROM "t" "t1" \
                    JOIN "cte1" \
                    JOIN "cte2" \
                    JOIN "t" "t2"
                    """)
            }
            
            // Use CTE as a subquery
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .annotated(with: cte.all())
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT *, (SELECT * FROM "cte") FROM "t"
                    """)
            }
            
            // Use CTE as a collection
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .filter(cte.contains(Column("id")))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT * \
                    FROM "t" \
                    WHERE "id" IN "cte"
                    """)
            }
            
            // Use filtered CTE as a subquery
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .annotated(with: cte.all().filter(Column("id") > 1))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT *, (SELECT * FROM "cte" WHERE "id" > 1) \
                    FROM "t"
                    """)
            }
            
            // Select from a CTE
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = cte.all().with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT * FROM "cte"
                    """)
            }
        }
    }
    
    func testFetchFromCTE() throws {
        try makeDatabaseQueue().read { db in
            do {
                let answer = CommonTableExpression<Row>(
                    named: "answer",
                    sql: "SELECT 42 AS value")
                let row = try answer.all().with(answer).fetchOne(db)
                XCTAssertEqual(row, ["value": 42])
            }
            do {
                struct Answer: Decodable, FetchableRecord, Equatable {
                    var value: Int
                }
                let cte = CommonTableExpression<Answer>(
                    named: "answer",
                    sql: "SELECT 42 AS value")
                let answer = try cte.all().with(cte).fetchOne(db)
                XCTAssertEqual(answer, Answer(value: 42))
            }
        }
    }
    
    func testCTEAsSubquery() throws {
        try makeDatabaseQueue().write { db in
            struct Player: Decodable, FetchableRecord, TableRecord {
                var id: Int64
                var score: Int
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("score", .integer)
            }
            let answer = CommonTableExpression<Void>(
                named: "answer",
                sql: "SELECT 42 AS value")
            let request = Player
                .filter(Column("score") == answer.all())
                .with(answer)
            try assertEqualSQL(db, request, """
                WITH "answer" AS (SELECT 42 AS value) \
                SELECT * \
                FROM "player" \
                WHERE "score" = (SELECT * FROM "answer")
                """)
        }
    }
    
    func testChatWithLatestMessage() throws {
        struct Chat: Codable, FetchableRecord, PersistableRecord, Equatable {
            var id: Int64
        }
        struct Post: Codable, FetchableRecord, PersistableRecord, Equatable {
            var id: Int64
            var chatID: Int64
            var date: Int // easier to test
        }
        struct ChatInfo: Decodable, FetchableRecord, Equatable {
            var chat: Chat
            var latestPost: Post?
        }
        try makeDatabaseQueue().write { db in
            try db.create(table: "chat") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "post") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("chatID", .integer).notNull().references("chat")
                t.column("date", .datetime).notNull()
            }
            
            try Chat(id: 1).insert(db)
            try Post(id: 1, chatID: 1, date: 1).insert(db)
            try Post(id: 2, chatID: 1, date: 2).insert(db)
            try Post(id: 3, chatID: 1, date: 3).insert(db)

            try Chat(id: 2).insert(db)
            try Post(id: 4, chatID: 2, date: 3).insert(db)
            try Post(id: 5, chatID: 2, date: 2).insert(db)
            try Post(id: 6, chatID: 2, date: 1).insert(db)
            
            try Chat(id: 3).insert(db)
            
            // https://sqlite.org/lang_select.html
            // > When the min() or max() aggregate functions are used in an
            // > aggregate query, all bare columns in the result set take values
            // > from the input row which also contains the minimum or maximum.
            let latestPostRequest = Post
                .annotated(with: max(Column("date")))
                .group(Column("chatID"))
            
            let latestPostCTE = CommonTableExpression<Void>(
                named: "latestPost",
                request: latestPostRequest)
            
            let latestPost = Chat.association(to: latestPostCTE, on: { chat, latestPost in
                chat[Column("id")] == latestPost[Column("chatID")]
            })
            
            let request = Chat
                .with(latestPostCTE)
                .including(optional: latestPost)
                .orderByPrimaryKey()
                .asRequest(of: ChatInfo.self)
            
            try assertEqualSQL(db, request, """
                WITH "latestPost" AS (SELECT *, MAX("date") FROM "post" GROUP BY "chatID") \
                SELECT "chat".*, "latestPost".* \
                FROM "chat" \
                LEFT JOIN "latestPost" ON "chat"."id" = "latestPost"."chatID" \
                ORDER BY "chat"."id"
                """)
            
            let chatInfos = try request.fetchAll(db)
            XCTAssertEqual(chatInfos, [
                ChatInfo(chat: Chat(id: 1), latestPost: Post(id: 3, chatID: 1, date: 3)),
                ChatInfo(chat: Chat(id: 2), latestPost: Post(id: 4, chatID: 2, date: 3)),
                ChatInfo(chat: Chat(id: 3), latestPost: nil),
            ])
        }
    }
    
    func testRecursiveCounter() throws {
        try makeDatabaseQueue().read { db in
            func counterRequest(range: ClosedRange<Int>) -> QueryInterfaceRequest<Int> {
                let counter = CommonTableExpression<Int>(
                    recursive: true,
                    named: "counter",
                    columns: ["x"],
                    literal: """
                        VALUES(\(range.lowerBound)) \
                        UNION ALL \
                        SELECT x+1 FROM counter WHERE x < \(range.upperBound)
                        """)
                return counter.all().with(counter)
            }
            
            try assertEqualSQL(db, counterRequest(range: 0...10), """
                WITH RECURSIVE \
                "counter"("x") AS (VALUES(0) UNION ALL SELECT x+1 FROM counter WHERE x < 10) \
                SELECT * FROM "counter"
                """)
            
            try XCTAssertEqual(counterRequest(range: 0...10).fetchAll(db), Array(0...10))
            try XCTAssertEqual(counterRequest(range: 3...7).fetchAll(db), Array(3...7))
        }
    }
    
    func testInterpolation() throws {
        try makeDatabaseQueue().read { db in
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    literal: "SELECT \("O'Brien")")
                let request: SQLRequest<Void> = """
                    WITH \(definitionFor: cte) \
                    SELECT * FROM \(cte)
                    """
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT * FROM "cte"
                    """)
            }
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    literal: "SELECT \("O'Brien")")
                let request: SQLRequest<Void> = """
                    WITH \(definitionFor: cte) \
                    \(cte.all())
                    """
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT * FROM "cte"
                    """)
            }
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    columns: [],
                    literal: "SELECT \("O'Brien")")
                let request: SQLRequest<Void> = """
                    WITH \(definitionFor: cte) \
                    SELECT * FROM \(cte)
                    """
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT * FROM "cte"
                    """)
            }
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    columns: ["name"],
                    literal: "SELECT \("O'Brien")")
                let request: SQLRequest<Void> = """
                    WITH \(definitionFor: cte) \
                    SELECT * FROM \(cte)
                    """
                try assertEqualSQL(db, request, """
                    WITH "cte"("name") AS (SELECT 'O''Brien') \
                    SELECT * FROM "cte"
                    """)
            }
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    columns: ["name", "score"],
                    literal: "SELECT \("O'Brien"), 12")
                let request: SQLRequest<Void> = """
                    WITH \(definitionFor: cte) \
                    SELECT * FROM \(cte)
                    """
                try assertEqualSQL(db, request, """
                    WITH "cte"("name", "score") AS (SELECT 'O''Brien', 12) \
                    SELECT * FROM "cte"
                    """)
            }
        }
    }
    
    func testUpdate() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { t in
                t.column("a")
            }
            
            struct T: Encodable, PersistableRecord { }
            let cte = CommonTableExpression<Void>(named: "cte", sql: "SELECT 1")
            
            try T.with(cte).updateAll(db, Column("a").set(to: cte.all()))
            XCTAssertEqual(lastSQLQuery, """
                WITH "cte" AS (SELECT 1) UPDATE "t" SET "a" = (SELECT * FROM "cte")
                """)
        }
    }
    
    func testDelete() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { t in
                t.column("a")
            }
            
            struct T: Encodable, PersistableRecord { }
            let cte = CommonTableExpression<Void>(named: "cte", sql: "SELECT 1")
            
            try T.with(cte)
                .filter(cte.contains(Column("a")))
                .deleteAll(db)
            XCTAssertEqual(lastSQLQuery, """
                WITH "cte" AS (SELECT 1) \
                DELETE FROM "t" \
                WHERE "a" IN "cte"
                """)
        }
    }
}
