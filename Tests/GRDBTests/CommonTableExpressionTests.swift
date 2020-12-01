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
                let cte = T.all()
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT * FROM "t"
                    """)
            }
            
            // Just add a WITH clause: sql request
            do {
                let cte = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT * FROM "t"
                    """)
            }
            
            // Include query interface request as a CTE
            do {
                let cte = T.all()
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
                let cte = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, on: { _, _ in true }))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien') \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte"
                    """)
            }
            
            // Include a filtered SQL request as a CTE
            do {
                let cte = SQLRequest<Int>(literal: "SELECT 1 AS a")
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
                let cte = SQLRequest<Int>(literal: "SELECT \("O'Brien") AS id")
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, using: Column("id")))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT 'O''Brien' AS id) \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    JOIN "cte" ON "t"."id" = "cte"."id"
                    """)
            }
            
            // Include SQL request as a CTE (empty ON clause)
            do {
                let cte = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
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
                let cte = T.all()
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
            
            // Include one CTE twice with same key and condition
            do {
                let cte = T.all()
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
            
            // Include one CTE twice with same key but different condition (last condition wins)
            do {
                let cte = T.all()
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
                let cte = T.all()
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] > right["id"] }).forKey("a"))
                    .including(required: T.association(to: cte, on: { (left, right) in left["id"] > right["id"] }).forKey("b"))
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte1".*, "cte2".* \
                    FROM "t" \
                    JOIN "cte" "cte1" ON "t"."id" > "cte1"."id" \
                    JOIN "cte" "cte2" ON "t"."id" > "cte2"."id"
                    """)
            }
            
            // Chain CTE includes
            do {
                let cte1 = T.all().commonTableExpression(tableName: "cte1")
                let cte2 = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
                    .commonTableExpression(tableName: "cte2")
                #warning("TODO: from? to? WTF?")
                let assoc1 = T.association(to: cte1)
                let assoc2 = cte1.association(to: cte2)
                let assoc3 = cte2.association(to: T.self)
                let request = T.all()
                    .with(cte1, cte2)
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
            
            // TODO: include filtered CTE
            
            // Use CTE as a subquery
            do {
                let cte = T.all()
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
                let cte = T.all()
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
