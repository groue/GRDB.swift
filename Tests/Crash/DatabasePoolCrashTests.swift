import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

class DatabasePoolCrashTests: GRDBCrashTestCase {
    
    func testReaderCanNotStartTransaction() {
        assertCrash("DatabasePool readers can not start transactions or savepoints.") {
            try dbPool.read { db in
                let statement = try db.makeUpdateStatement("BEGIN TRANSACTION")
            }
        }
    }
    
    func testReaderCanNotStartSavepoint() {
        assertCrash("DatabasePool readers can not start transactions or savepoints.") {
            try dbPool.read { db in
                let statement = try db.makeUpdateStatement("SAVEPOINT foo")
            }
        }
    }
}
