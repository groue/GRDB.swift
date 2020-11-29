import XCTest
import GRDB

class CommonTableExpressionTests: GRDBTestCase {
    func testQuery() throws {
        struct T: TableRecord { }
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            let request = T.all().with(T.all(), aliased: TableAlias())
            try assertEqualSQL(db, request, """
                WITH "t2" AS (SELECT * FROM "t") \
                SELECT "t1".* FROM "t" "t1"
                """)
        }
    }
}
