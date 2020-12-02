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
            
            // Include SQL request as a CTE (true ON clause)
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    literal: "SELECT \("O'Brien")")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, on: { _, _ in true }))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON 1
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
            
            // Include SQL request as a CTE (USING clause)
            do {
                let cte = CommonTableExpression<Void>(
                    named: "cte",
                    literal: "SELECT 1 AS id")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, using: [Column("id")]))
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
                    columns: [Column("id"), Column("a")],
                    literal: "SELECT 1, 2")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, using: [Column("id")]))
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
            
            // Include one CTE twice with same key and used columns
            do {
                let cte = CommonTableExpression<Void>(named: "cte", request: T.all())
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, using: [Column("id")]))
                    .including(required: T.association(to: cte, using: [Column("id")]))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON "t"."id" = "cte"."id"
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
                    .including(required: T.association(to: cte, using: [Column("id")]).forKey("a"))
                    .including(required: T.association(to: cte, using: [Column("id")]).forKey("b"))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte1".*, "cte2".* \
                    FROM "t" \
                    JOIN "cte" "cte1" ON "t"."id" = "cte1"."id" \
                    JOIN "cte" "cte2" ON "t"."id" = "cte2"."id"
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
            
            let latestPost = CommonTableExpression<Void>(
                named: "latestPost",
                request: Post
                    .annotated(with: max(Column("date")))
                    .group(Column("chatID")))
            let request = Chat
                .orderByPrimaryKey()
                .with(latestPost)
                .including(optional: Chat.association(to: latestPost, on: { chat, latestPost in
                    chat[Column("id")] == latestPost[Column("chatID")]
                }))
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
}
