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
                let statement = try db.updateStatement("BEGIN TRANSACTION")
            }
        }
    }
    
    func testReaderCanNotStartSavepoint() {
        assertCrash("DatabasePool readers can not start transactions or savepoints.") {
            try dbPool.read { db in
                let statement = try db.updateStatement("SAVEPOINT foo")
            }
        }
    }
}
