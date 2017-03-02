import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

import XCTest

class ResultCodeTests: GRDBTestCase {
    
    func testExtendedResultCodesAreActivated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "children") { t in
                t.column("parentId", .integer).references("parents")
            }
            do {
                try db.execute("INSERT INTO children (parentId) VALUES (1)")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 19)           // primary SQLITE_CONSTRAINT
                XCTAssertEqual(error.extendedResultCode.rawValue, 787)  // extended SQLITE_CONSTRAINT_FOREIGNKEY
            }
        }
    }
    
    func testResultCodeEquatable() {
        XCTAssertEqual(ResultCode(rawValue: 19), .SQLITE_CONSTRAINT)
        XCTAssertEqual(ResultCode(rawValue: 787), .SQLITE_CONSTRAINT_FOREIGNKEY)
        XCTAssertNotEqual(ResultCode.SQLITE_CONSTRAINT, .SQLITE_CONSTRAINT_FOREIGNKEY)
    }
    
    func testResultCodeMatch() {
        XCTAssertTrue(ResultCode.SQLITE_CONSTRAINT ~= .SQLITE_CONSTRAINT)
        XCTAssertTrue(ResultCode.SQLITE_CONSTRAINT ~= .SQLITE_CONSTRAINT_FOREIGNKEY)
        XCTAssertTrue(ResultCode.SQLITE_CONSTRAINT_FOREIGNKEY ~= .SQLITE_CONSTRAINT_FOREIGNKEY)
        XCTAssertFalse(ResultCode.SQLITE_CONSTRAINT_FOREIGNKEY ~= .SQLITE_CONSTRAINT)
        XCTAssertFalse(ResultCode.SQLITE_TOOBIG ~= .SQLITE_CONSTRAINT)
    }
    
    func testResultCodeSwitch() {
        switch ResultCode.SQLITE_CONSTRAINT {
        case ResultCode.SQLITE_CONSTRAINT_FOREIGNKEY: XCTFail()
        case ResultCode.SQLITE_CONSTRAINT: break
        default: XCTFail()
        }
        
        switch ResultCode.SQLITE_CONSTRAINT_FOREIGNKEY {
        case ResultCode.SQLITE_CONSTRAINT_FOREIGNKEY: break
        case ResultCode.SQLITE_CONSTRAINT: XCTFail()
        default: XCTFail()
        }
        
        switch ResultCode.SQLITE_CONSTRAINT_CHECK {
        case ResultCode.SQLITE_CONSTRAINT_FOREIGNKEY: XCTFail()
        case ResultCode.SQLITE_CONSTRAINT: break
        default: XCTFail()
        }
        
        switch ResultCode.SQLITE_TOOBIG {
        case ResultCode.SQLITE_CONSTRAINT_FOREIGNKEY: XCTFail()
        case ResultCode.SQLITE_CONSTRAINT: XCTFail()
        default: break
        }
    }
}
