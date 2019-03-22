import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

/// Test row scopes
class AssociationHasManyRowScopeTests: GRDBTestCase {
    func testIndirect() throws {
        struct A: TableRecord {
            static let bs = hasMany(B.self)
        }
        struct B: TableRecord {
        }
        
        dbConfiguration.trace = { print($0) }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("aId", .integer).references("a")
                t.column("name", .text)
            }
            try db.execute(
                sql: """
                    INSERT INTO a (id, name) VALUES (?, ?);
                    INSERT INTO a (id, name) VALUES (?, ?);
                    INSERT INTO b (id, aId, name) VALUES (?, ?, ?);
                    INSERT INTO b (id, aId, name) VALUES (?, ?, ?);
                    INSERT INTO b (id, aId, name) VALUES (?, ?, ?);
                    """,
                arguments: [
                    1, "a1",
                    2, "a2",
                    1, 1, "b1",
                    2, 1, "b2",
                    3, 2, "b3",
                ])
            
            let request = A.including(all: A.bs)
            let rows = try Row.fetchAll(db, request)
        }
    }
}
