import XCTest
import GRDB

class DatabasePoolCrashTests: GRDBCrashTestCase {
    
    func testReaderCanNotStartTransaction() {
        assertCrash("DatabasePool readers can not start transactions or savepoints.") {
            try dbPool.read { db in
                let statement = try db.makeStatement(sql: "BEGIN TRANSACTION")
            }
        }
    }
    
    func testReaderCanNotStartSavepoint() {
        assertCrash("DatabasePool readers can not start transactions or savepoints.") {
            try dbPool.read { db in
                let statement = try db.makeStatement(sql: "SAVEPOINT foo")
            }
        }
    }
}
