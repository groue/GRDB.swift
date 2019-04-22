import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class RowTestCase: GRDBTestCase {
    
    func assertRowRawValueEqual<T: Equatable>(_ row: Row, index: Int, value: T) {
        // form 1
        let v = row[index]
        XCTAssertEqual(v as! T, value)
        
        // form 2
        XCTAssertEqual(row[index] as! T, value)

        // form 3
        if let v = row[index] as? T {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowRawValueEqual<T: Equatable>(_ row: Row, name: String, value: T) {
        // form 1
        let v = row[name]
        XCTAssertEqual(v as! T, value)
        
        // form 2
        XCTAssertEqual(row[name] as! T, value)
        
        // form 3
        if let v = row[name] as? T {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowRawValueEqual<T: Equatable>(_ row: Row, column: Column, value: T) {
        // form 1
        let v = row[column]
        XCTAssertEqual(v as! T, value)
        
        // form 2
        XCTAssertEqual(row[column] as! T, value)
        
        // form 3
        if let v = row[column] as? T {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, index: Int, value: T) {
        // form 1
        XCTAssertEqual(row[index] as T, value)
        
        // form 2
        XCTAssertEqual(row[index]! as T, value)
        
        // form 3
        XCTAssertEqual((row[index] as T?)!, value)
        
        // form 4
        if let v = row[index] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, name: String, value: T) {
        // form 1
        XCTAssertEqual(row[name] as T, value)
        
        // form 2
        XCTAssertEqual(row[name]! as T, value)
        
        // form 3
        XCTAssertEqual((row[name] as T?)!, value)
        
        // form 4
        if let v = row[name] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, column: Column, value: T) {
        // form 1
        XCTAssertEqual(row[column] as T, value)
        
        // form 2
        XCTAssertEqual(row[column]! as T, value)
        
        // form 3
        XCTAssertEqual((row[column] as T?)!, value)
        
        // form 4
        if let v = row[column] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, index: Int, value: T) {
        // form 1
        XCTAssertEqual(row[index] as T, value)
        
        // form 2
        XCTAssertEqual(row[index]! as T, value)
        
        // form 3
        XCTAssertEqual((row[index] as T?)!, value)
        
        // form 4
        if let v = row[index] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, name: String, value: T) {
        // form 1
        XCTAssertEqual(row[name] as T, value)
        
        // form 2
        XCTAssertEqual(row[name]! as T, value)
        
        // form 3
        XCTAssertEqual((row[name] as T?)!, value)
        
        // form 4
        if let v = row[name] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, column: Column, value: T) {
        // form 1
        XCTAssertEqual(row[column] as T, value)
        
        // form 2
        XCTAssertEqual(row[column]! as T, value)
        
        // form 3
        XCTAssertEqual((row[column] as T?)!, value)
        
        // form 4
        if let v = row[column] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
}
