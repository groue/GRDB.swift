import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class SQLStringStatementsTests: GRDBTestCase {
    func testDatabaseExecute() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(SQLString(sql: """
                CREATE TABLE t(a);
                INSERT INTO t(a) VALUES (?);
                INSERT INTO t(a) VALUES (?);
                """, arguments: [1, 2]))
            let value = try Int.fetchOne(db, "SELECT SUM(a) FROM t")
            XCTAssertEqual(value, 3)
        }
    }
    
    #if swift(>=5.0)
    func testDatabaseExecuteWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(SQLString("""
                CREATE TABLE t(a);
                INSERT INTO t(a) VALUES (\(1));
                INSERT INTO t(a) VALUES (\(2));
                """))
            let value = try Int.fetchOne(db, "SELECT SUM(a) FROM t")
            XCTAssertEqual(value, 3)
        }
    }
    #endif
}
