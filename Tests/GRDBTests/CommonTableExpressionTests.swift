import XCTest
import GRDB

class CommonTableExpressionTests: GRDBTestCase {
    func testQuery() throws {
        struct T: TableRecord { }
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            
            // Just add a WITH clause: query interface request
            do {
                enum CTE { }
                let cteRequest = T.all()
                let cte = cteRequest.commonTableExpression(tableName: "cte", type: CTE.self)
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT * FROM "t"
                    """)
            }
            
            // Just add a WITH clause: sql request
            do {
                enum CTE { }
                let cteRequest: SQLRequest<Int> = "SELECT \("O'Brien")"
                let cte = cteRequest.commonTableExpression(tableName: "cte", type: CTE.self)
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT * FROM "t"
                    """)
            }
            
            // Just add a WITH clause: sql + arguments
            do {
                enum CTE { }
                let cte = CommonTableExpression(
                    tableName: "cte",
                    sql: "SELECT ?",
                    arguments: ["O'Brien"],
                    type: CTE.self)
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT * FROM "t"
                    """)
            }
            
            // Just add a WITH clause: sql interpolation
            do {
                enum CTE { }
                let cte = CommonTableExpression(
                    tableName: "cte",
                    literal: "SELECT \("O'Brien")",
                    type: CTE.self)
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT * FROM "t"
                    """)
            }
            
            // Include query interface request as a CTE
            do {
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = SQLRequest<Int>(literal: "SELECT 1 AS a")
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = SQLRequest<Int>(literal: "SELECT \("O'Brien") AS id")
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, using: [Column("id")]))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien' AS id) \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON "t"."id" = "cte"."id"
                    """)
            }
            
            // Include SQL request as a CTE (custom column name)
            do {
                enum CTE { }
                let cte: CommonTableExpression<CTE> = SQLRequest<Int>(literal: "SELECT 1, 2")
                    .commonTableExpression(tableName: "cte", columns: [Column("id"), Column("a")])
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
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
                let cte1: CommonTableExpression<CTE1> = T.all().commonTableExpression(tableName: "cte1")
                let cte2: CommonTableExpression<CTE2> = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
                    .commonTableExpression(tableName: "cte2")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
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
                enum CTE { }
                let cte: CommonTableExpression<CTE> = T.all()
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                    .annotated(with: cte.all().filter(Column("id") > 1))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT *, (SELECT * FROM "cte" WHERE "id" > 1) \
                    FROM "t"
                    """)
            }
        }
    }
}
