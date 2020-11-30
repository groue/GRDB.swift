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
                    .commonTableExpression()
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "t2" AS (SELECT * FROM "t") \
                    SELECT "t1".* FROM "t" "t1"
                    """)
            }
            
            // Just add a WITH clause: sql request
            do {
                let cte = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
                    .commonTableExpression(key: "custom")
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "custom" AS (SELECT 'O''Brien') \
                    SELECT "t".* FROM "t"
                    """)
            }
            
            // Just add a WITH clause: sql request with conflicting key
            do {
                let cte = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
                    .commonTableExpression(key: "t")
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "t2" AS (SELECT 'O''Brien') \
                    SELECT "t1".* FROM "t" "t1"
                    """)
            }
            
            // Just add a WITH clause: sql request with conflicting alias name
            do {
                let cte = SQLRequest<Int>(literal: "SELECT \("O'Brien")")
                    .commonTableExpression(key: "custom")
                    .aliased(TableAlias(name: "t"))
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "t" AS (SELECT 'O''Brien') \
                    SELECT "t1".* FROM "t" "t1"
                    """)
            }
            
            // Just add a WITH clause: custom name for the CTE
            do {
                let cte = T.all()
                    .commonTableExpression()
                    .aliased(TableAlias(name: "custom"))
                let request = T.all()
                    .with(cte)
                try assertEqualSQL(db, request, """
                    WITH "custom" AS (SELECT * FROM "t") \
                    SELECT "t".* FROM "t"
                    """)
            }
            
            // Include query interface request as a CTE
            do {
                let cte = T.all()
                    .commonTableExpression()
                let request = T.all()
                    .with(cte)
                    .including(optional: cte, on: { (left, right) in left["id"] > right["id"] })
                try assertEqualSQL(db, request, """
                    WITH "t2" AS (SELECT * FROM "t") \
                    SELECT "t1".*, "t2".* \
                    FROM "t" "t1" \
                    LEFT JOIN "t2" ON "t1"."id" > "t2"."id"
                    """)
            }
            
            // Join query interface request as a CTE
            do {
                let cte = T.all()
                    .commonTableExpression()
                let request = T.all()
                    .with(cte)
                    .joining(required: cte, on: { (left, right) in left["id"] > right["id"] })
                try assertEqualSQL(db, request, """
                    WITH "t2" AS (SELECT * FROM "t") \
                    SELECT "t1".* \
                    FROM "t" "t1" \
                    JOIN "t2" ON "t1"."id" > "t2"."id"
                    """)
            }
            
            // Join two CTEs with same key and condition
            do {
                let cte = T.all()
                    .commonTableExpression()
                let request = T.all()
                    .with(cte)
                    .joining(required: cte, on: { (left, right) in left["id"] > right["id"] })
                    .joining(required: cte, on: { (left, right) in left["id"] > right["id"] })
                try assertEqualSQL(db, request, """
                    WITH "t2" AS (SELECT * FROM "t") \
                    SELECT "t1".* \
                    FROM "t" "t1" \
                    JOIN "t2" ON "t1"."id" > "t2"."id"
                    """)
            }
            
            // Join two CTEs with same key but different condition
            do {
                let cte = T.all()
                    .commonTableExpression()
                let request = T.all()
                    .with(cte)
                    .joining(required: cte, on: { (left, right) in left["id"] > right["id"] })
                    .joining(required: cte, on: { (left, right) in left["id"] + right["id"] == 1 })
                try assertEqualSQL(db, request, """
                    WITH "t2" AS (SELECT * FROM "t") \
                    SELECT "t1".* \
                    FROM "t" "t1" \
                    JOIN "t2" ON "t1"."id" > "t2"."id"
                    """)
            }
            
            // Join two CTEs with different keys
            do {
                let cte = T.all()
                    .commonTableExpression()
                let request = T.all()
                    .with(cte)
                    .joining(required: cte.forKey("a"), on: { (left, right) in left["id"] > right["id"] })
                    .joining(required: cte.forKey("b"), on: { (left, right) in left["id"] > right["id"] })
                try assertEqualSQL(db, request, """
                    WITH "t2" AS (SELECT * FROM "t") \
                    SELECT "t1".* \
                    FROM "t" "t1" \
                    JOIN "t2" ON "t1"."id" > "t2"."id"
                    """)
            }
            
//            // Use CTE as a subquery
//            do {
//                let cte = T.all()
//                    .commonTableExpression()
//                let request = T.all()
//                    .with(cte)
//                    .annotated(with: cte.all())
//                try assertEqualSQL(db, request, """
//                    WITH "foo" AS (SELECT * FROM "t") \
//                    SELECT "t".*, (SELECT * FROM "foo") FROM "t"
//                    """)
//            }
        }
    }
}
