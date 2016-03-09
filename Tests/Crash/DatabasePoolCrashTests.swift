import GRDB
import XCTest

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
