import XCTest
import GRDB

class CommonTableExpressionTests: GRDBTestCase {
    func testQuery() throws {
        struct T: TableRecord { }
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            
            do {
                let cte = T.all().commonTableExpression()
                let request = T.all().with(cte)
                try assertEqualSQL(db, request, """
                WITH "t2" AS (SELECT * FROM "t") \
                SELECT "t1".* FROM "t" "t1"
                """)
            }
            
            do {
                let cte = T.all().commonTableExpression().aliased(TableAlias(name: "custom"))
                let request = T.all().with(cte)
                try assertEqualSQL(db, request, """
                WITH "custom" AS (SELECT * FROM "t") \
                SELECT "t".* FROM "t"
                """)
            }
        }
    }
}
