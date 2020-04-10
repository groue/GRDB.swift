import XCTest
import GRDB

import XCTest

class ResultCodeTests: GRDBTestCase {
    
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
    
    func testCatchResultCode() throws {
        do {
            do {
                throw DatabaseError(resultCode: .SQLITE_ERROR)
            } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY {
                XCTFail()
            } catch DatabaseError.SQLITE_CONSTRAINT {
                XCTFail()
            } catch DatabaseError.SQLITE_OK {
                XCTFail()
            } catch {
                // Success
            }
            
            do {
                throw DatabaseError(resultCode: .SQLITE_CONSTRAINT)
            } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY {
                XCTFail()
            } catch DatabaseError.SQLITE_CONSTRAINT {
                // Success
            } catch DatabaseError.SQLITE_OK {
                XCTFail()
            } catch {
                XCTFail()
            }
            
            do {
                throw DatabaseError(resultCode: .SQLITE_CONSTRAINT_FOREIGNKEY)
            } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY {
                // Success
            } catch DatabaseError.SQLITE_CONSTRAINT {
                XCTFail()
            } catch DatabaseError.SQLITE_OK {
                XCTFail()
            } catch {
                XCTFail()
            }
            
            do {
                throw DatabaseError(resultCode: .SQLITE_CONSTRAINT_CHECK)
            } catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY {
                XCTFail()
            } catch DatabaseError.SQLITE_CONSTRAINT {
                // Success
            } catch DatabaseError.SQLITE_OK {
                XCTFail()
            } catch {
                XCTFail()
            }
        }
        
        do {
            do {
                throw DatabaseError(resultCode: .SQLITE_ERROR)
            } catch let error as DatabaseError {
                switch error {
                case DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY:
                    XCTFail()
                case DatabaseError.SQLITE_CONSTRAINT:
                    XCTFail()
                case DatabaseError.SQLITE_OK:
                    XCTFail()
                default:
                    break // Success
                }
            }
            
            do {
                throw DatabaseError(resultCode: .SQLITE_CONSTRAINT)
            } catch let error as DatabaseError {
                switch error {
                case DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY:
                    XCTFail()
                case DatabaseError.SQLITE_CONSTRAINT:
                break // Success
                case DatabaseError.SQLITE_OK:
                    XCTFail()
                default:
                    XCTFail()
                }
            }
            
            do {
                throw DatabaseError(resultCode: .SQLITE_CONSTRAINT_FOREIGNKEY)
            } catch let error as DatabaseError {
                switch error {
                case DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY:
                break // Success
                case DatabaseError.SQLITE_CONSTRAINT:
                    XCTFail()
                case DatabaseError.SQLITE_OK:
                    XCTFail()
                default:
                    XCTFail()
                }
            }
            
            do {
                throw DatabaseError(resultCode: .SQLITE_CONSTRAINT_CHECK)
            } catch let error as DatabaseError {
                switch error {
                case DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY:
                    XCTFail()
                case DatabaseError.SQLITE_CONSTRAINT:
                break // Success
                case DatabaseError.SQLITE_OK:
                    XCTFail()
                default:
                    XCTFail()
                }
            }
        }
    }
}
