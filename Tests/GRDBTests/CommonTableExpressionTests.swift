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
                    .including(optional: cte, forKey: "ignored", on: { (left, right) in left["id"] > right["id"] })
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".*, "cte".* \
                    FROM "t" \
                    LEFT JOIN "cte" ON "t"."id" > "cte"."id"
                    """)
            }
            
            // Include SQL request as a CTE
            do {
                let cte = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                    .including(required: cte, forKey: "ignored", on: { (_, _) in true })
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
                    .joining(required: cte, forKey: "ignored", on: { (left, right) in left["id"] > right["id"] })
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".* \
                    FROM "t" \
                    JOIN "cte" ON "t"."id" > "cte"."id"
                    """)
            }
            
            // Join two CTEs with same key and condition
            do {
                let cte = T.all()
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                    .joining(required: cte, forKey: "ignored", on: { (left, right) in left["id"] > right["id"] })
                    .joining(required: cte, forKey: "ignored", on: { (left, right) in left["id"] > right["id"] })
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".* \
                    FROM "t" \
                    JOIN "cte" ON "t"."id" > "cte"."id"
                    """)
            }
            
            // Join two CTEs with same key but different condition (last condition wins)
            do {
                let cte = T.all()
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                    .joining(required: cte, forKey: "ignored", on: { (left, right) in left["id"] > right["id"] })
                    .joining(required: cte, forKey: "ignored", on: { (left, right) in left["id"] + right["id"] == 1 })
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".* \
                    FROM "t" \
                    JOIN "cte" ON ("t"."id" + "cte"."id") = 1
                    """)
            }
            
            // Join two CTEs with different keys
            do {
                let cte = T.all()
                    .commonTableExpression(tableName: "cte")
                let request = T.all()
                    .with(cte)
                    .joining(required: cte, forKey: "a", on: { (left, right) in left["id"] > right["id"] })
                    .joining(required: cte, forKey: "b", on: { (left, right) in left["id"] > right["id"] })
                try assertEqualSQL(db, request, """
                    WITH "cte" AS (SELECT * FROM "t") \
                    SELECT "t".* \
                    FROM "t" \
                    JOIN "cte" "cte1" ON "t"."id" > "cte1"."id" \
                    JOIN "cte" "cte2" ON "t"."id" > "cte2"."id"
                    """)
            }
            
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
        }
    }
}
