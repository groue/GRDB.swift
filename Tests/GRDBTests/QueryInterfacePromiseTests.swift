import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Node: TableRecord {
    static let parent = belongsTo(Node.self)
}

private struct NotARecord { }

// Here we test that filter(key:), orderByPrimaryKey(), and groupByPrimaryKey()
// don't forget their table when the request type is changed.
class QueryInterfacePromiseTests: GRDBTestCase {
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "node") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("parentId", .integer).references("node")
            }
        }
    }
    
    func testFilterKeyCapturesTableName() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Node
                    .filter(key: 1)
                let sql = """
                    SELECT * FROM "node" WHERE "id" = 1
                    """
                try assertEqualSQL(db, request, sql)
                try assertEqualSQL(db, request.asRequest(of: Row.self), sql)
            }
            do {
                let request = Node
                    .filter(key: 1)
                    .joining(optional: Node.parent.filter(key: 2))
                let sql = """
                    SELECT "node1".* \
                    FROM "node" "node1" \
                    LEFT JOIN "node" "node2" ON ("node2"."id" = "node1"."parentId") AND ("node2"."id" = 2) \
                    WHERE "node1"."id" = 1
                    """
                try assertEqualSQL(db, request, sql)
                try assertEqualSQL(db, request.asRequest(of: Row.self), sql)
            }
            do {
                let request = Node
                    .joining(optional: Node.parent.filter(key: 2))
                    .filter(key: 1)
                let sql = """
                    SELECT "node1".* \
                    FROM "node" "node1" \
                    LEFT JOIN "node" "node2" ON ("node2"."id" = "node1"."parentId") AND ("node2"."id" = 2) \
                    WHERE "node1"."id" = 1
                    """
                try assertEqualSQL(db, request, sql)
                try assertEqualSQL(db, request.asRequest(of: Row.self), sql)
            }
        }
    }
    
    func testOrderByPrimaryKeyCapturesTableName() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Node.orderByPrimaryKey()
                let sql = """
                    SELECT * FROM "node" ORDER BY "id"
                    """
                try assertEqualSQL(db, request, sql)
                try assertEqualSQL(db, request.asRequest(of: Row.self), sql)
            }
            do {
                let request = Node.orderByPrimaryKey().joining(optional: Node.parent.orderByPrimaryKey())
                let sql = """
                    SELECT "node1".* \
                    FROM "node" "node1" \
                    LEFT JOIN "node" "node2" ON "node2"."id" = "node1"."parentId" \
                    ORDER BY "node1"."id", "node2"."id"
                    """
                try assertEqualSQL(db, request, sql)
                try assertEqualSQL(db, request.asRequest(of: Row.self), sql)
            }
        }
    }
    
    func testGroupByPrimaryKeyCapturesTableName() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Node.all().groupByPrimaryKey()
            let sql = """
                SELECT * FROM "node" GROUP BY "id"
                """
            try assertEqualSQL(db, request, sql)
            try assertEqualSQL(db, request.asRequest(of: Row.self), sql)
        }
    }
    
    func testSourceTableIsCapturedInTheRequestAndNotInTheTypeOfTheFetchedRecord() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Node.all()
                    .asRequest(of: NotARecord.self)
                    .filter(key: 1)
                let sql = """
                    SELECT * FROM "node" WHERE "id" = 1
                    """
                try assertEqualSQL(db, request, sql)
                try assertEqualSQL(db, request.asRequest(of: Row.self), sql)
            }
            do {
                let request = Node
                    .joining(optional: Node.parent.filter(key: 2))
                    .asRequest(of: NotARecord.self)
                    .filter(key: 1)
                let sql = """
                    SELECT "node1".* \
                    FROM "node" "node1" \
                    LEFT JOIN "node" "node2" ON ("node2"."id" = "node1"."parentId") AND ("node2"."id" = 2) \
                    WHERE "node1"."id" = 1
                    """
                try assertEqualSQL(db, request, sql)
                try assertEqualSQL(db, request.asRequest(of: Row.self), sql)
            }
        }
    }
}
