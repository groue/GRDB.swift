import XCTest
import GRDB

class RowTestCase: GRDBTestCase {
    
    func assertRowRawValueEqual<T: Equatable>(_ row: Row, index: Int, value: T) {
        // form 1
        do {
            let v = row[index]
            XCTAssertEqual(v as! T, value)
        }
        
        // form 2
        XCTAssertEqual(row[index] as! T, value)

        // form 3
        if let v = row[index] as? T {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected successful extraction")
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
            XCTFail("expected successful extraction")
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
            XCTFail("expected successful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, index: Int, value: T) throws {
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
            XCTFail("expected successful extraction")
        }
        
        // form 5
        try XCTAssertEqual(row.decode(T.self, atIndex: index), value)
        
        // form 6
        try XCTAssertEqual(row.decode(atIndex: index) as T, value)
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, name: String, value: T) throws {
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
            XCTFail("expected successful extraction")
        }
        
        // form 5
        try XCTAssertEqual(row.decode(T.self, forColumn: name), value)
        
        // form 6
        try XCTAssertEqual(row.decode(forColumn: name) as T, value)
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, column: Column, value: T) throws {
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
            XCTFail("expected successful extraction")
        }
        
        // form 5
        try XCTAssertEqual(row.decode(T.self, forColumn: column), value)
        
        // form 6
        try XCTAssertEqual(row.decode(forColumn: column) as T, value)
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, index: Int, value: T) throws {
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
            XCTFail("expected successful extraction")
        }
        
        // form 5
        try XCTAssertEqual(row.decode(T.self, atIndex: index), value)
        
        // form 6
        try XCTAssertEqual(row.decode(atIndex: index) as T, value)
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, name: String, value: T) throws {
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
            XCTFail("expected successful extraction")
        }
        
        // form 5
        try XCTAssertEqual(row.decode(T.self, forColumn: name), value)
        
        // form 6
        try XCTAssertEqual(row.decode(forColumn: name) as T, value)
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, column: Column, value: T) throws {
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
            XCTFail("expected successful extraction")
        }
        
        // form 5
        try XCTAssertEqual(row.decode(T.self, forColumn: column), value)
        
        // form 6
        try XCTAssertEqual(row.decode(forColumn: column) as T, value)
    }
}
