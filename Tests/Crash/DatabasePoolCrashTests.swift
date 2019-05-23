import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabasePoolCrashTests: GRDBCrashTestCase {
    
    func testReaderCanNotStartTransaction() {
        assertCrash("DatabasePool readers can not start transactions or savepoints.") {
            try dbPool.read { db in
                let statement = try db.makeUpdateStatement(sql: "BEGIN TRANSACTION")
            }
        }
    }
    
    func testReaderCanNotStartSavepoint() {
        assertCrash("DatabasePool readers can not start transactions or savepoints.") {
            try dbPool.read { db in
                let statement = try db.makeUpdateStatement(sql: "SAVEPOINT foo")
            }
        }
    }
}
