import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabaseLogErrorTests: GRDBTestCase {
    
    func testErrorLog() throws {
        let dbQueue = try makeDatabaseQueue()
        dbQueue.inDatabase { db in
            _ = try? db.execute("That's not SQL.")
        }
        XCTAssertEqual(lastResultCode!, ResultCode.SQLITE_ERROR)
        XCTAssertEqual(lastMessage!, "near \"That\": syntax error")
    }
}
