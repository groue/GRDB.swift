import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class RowTestCase: GRDBTestCase {
    
    func assertRowRawValueEqual<T: Equatable>(_ row: Row, index: Int, value: T) {
        // form 1
        let v = row.value(atIndex: index)
        XCTAssertEqual(v as! T, value)
        
        // form 2
        XCTAssertEqual(row.value(atIndex: index) as! T, value)

        // form 3
        if let v = row.value(atIndex: index) as? T {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowRawValueEqual<T: Equatable>(_ row: Row, name: String, value: T) {
        // form 1
        let v = row.value(named: name)
        XCTAssertEqual(v as! T, value)
        
        // form 2
        XCTAssertEqual(row.value(named: name) as! T, value)
        
        // form 3
        if let v = row.value(named: name) as? T {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowRawValueEqual<T: Equatable>(_ row: Row, column: Column, value: T) {
        // form 1
        let v = row.value(column)
        XCTAssertEqual(v as! T, value)
        
        // form 2
        XCTAssertEqual(row.value(column) as! T, value)
        
        // form 3
        if let v = row.value(column) as? T {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, index: Int, value: T) {
        // form 1
        XCTAssertEqual(row.value(atIndex: index) as T, value)
        
        // form 2
        XCTAssertEqual(row.value(atIndex: index)! as T, value)
        
        // form 3
        XCTAssertEqual((row.value(atIndex: index) as T?)!, value)
        
        // form 4
        if let v = row.value(atIndex: index) as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, name: String, value: T) {
        // form 1
        XCTAssertEqual(row.value(named: name) as T, value)
        
        // form 2
        XCTAssertEqual(row.value(named: name)! as T, value)
        
        // form 3
        XCTAssertEqual((row.value(named: name) as T?)!, value)
        
        // form 4
        if let v = row.value(named: name) as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, column: Column, value: T) {
        // form 1
        XCTAssertEqual(row.value(column) as T, value)
        
        // form 2
        XCTAssertEqual(row.value(column)! as T, value)
        
        // form 3
        XCTAssertEqual((row.value(column) as T?)!, value)
        
        // form 4
        if let v = row.value(column) as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, index: Int, value: T) {
        // form 1
        XCTAssertEqual(row.value(atIndex: index) as T, value)
        
        // form 2
        XCTAssertEqual(row.value(atIndex: index)! as T, value)
        
        // form 3
        XCTAssertEqual((row.value(atIndex: index) as T?)!, value)
        
        // form 4
        if let v = row.value(atIndex: index) as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, name: String, value: T) {
        // form 1
        XCTAssertEqual(row.value(named: name) as T, value)
        
        // form 2
        XCTAssertEqual(row.value(named: name)! as T, value)
        
        // form 3
        XCTAssertEqual((row.value(named: name) as T?)!, value)
        
        // form 4
        if let v = row.value(named: name) as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, column: Column, value: T) {
        // form 1
        XCTAssertEqual(row.value(column) as T, value)
        
        // form 2
        XCTAssertEqual(row.value(column)! as T, value)
        
        // form 3
        XCTAssertEqual((row.value(column) as T?)!, value)
        
        // form 4
        if let v = row.value(column) as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected succesful extraction")
        }
    }
}
