import XCTest
#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class LogErrorTests: GRDBTestCase {
    
    func testErrorLog() throws {
        // Remember current log function
        let currentLogError = Database.logError
        
        var lastResultCode: ResultCode? = nil
        var lastMessage: String? = nil
        Database.logError = { (resultCode, message) in
            lastResultCode = resultCode
            lastMessage = message
        }
        let dbQueue = try makeDatabaseQueue()
        dbQueue.inDatabase { db in
            _ = try? db.execute("That's not SQL.")
        }
        XCTAssertEqual(lastResultCode!, ResultCode.SQLITE_ERROR)
        XCTAssertEqual(lastMessage!, "near \"That\": syntax error")
        
        // Restore current log function
        Database.logError = currentLogError
    }
}
