import XCTest
import GRDB

class RowTestCase: GRDBTestCase {
    
    func assertRowRawValueEqual(_ row: Row, index: Int, value: DatabaseValue) {
        XCTAssertEqual(row.databaseValue(atIndex: index).storage, value.storage)
    }
    
    func assertRowRawValueEqual(_ row: Row, name: String, value: DatabaseValue) {
        XCTAssertEqual(row.databaseValue(forColumn: name)!.storage, value.storage)
    }
    
    func assertRowRawValueEqual(_ row: Row, column: Column, value: DatabaseValue) {
        XCTAssertEqual(row.databaseValue(forColumn: column)!.storage, value.storage)
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, index: Int, value: T) throws {
        // form 1
        try XCTAssertEqual(row[index] as T, value)
        
        // form 2
        try XCTAssertEqual(row[index]! as T, value)
        
        // form 3
        try XCTAssertEqual((row[index] as T?)!, value)
        
        // form 4
        if let v = try row[index] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected successful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, name: String, value: T) throws {
        // form 1
        try XCTAssertEqual(row[name] as T, value)
        
        // form 2
        try XCTAssertEqual(row[name]! as T, value)
        
        // form 3
        try XCTAssertEqual((row[name] as T?)!, value)
        
        // form 4
        if let v = try row[name] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected successful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible>(_ row: Row, column: Column, value: T) throws {
        // form 1
        try XCTAssertEqual(row[column] as T, value)
        
        // form 2
        try XCTAssertEqual(row[column]! as T, value)
        
        // form 3
        try XCTAssertEqual((row[column] as T?)!, value)
        
        // form 4
        if let v = try row[column] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected successful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, index: Int, value: T) throws {
        // form 1
        try XCTAssertEqual(row[index] as T, value)
        
        // form 2
        try XCTAssertEqual(row[index]! as T, value)
        
        // form 3
        try XCTAssertEqual((row[index] as T?)!, value)
        
        // form 4
        if let v = try row[index] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected successful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, name: String, value: T) throws {
        // form 1
        try XCTAssertEqual(row[name] as T, value)
        
        // form 2
        try XCTAssertEqual(row[name]! as T, value)
        
        // form 3
        try XCTAssertEqual((row[name] as T?)!, value)
        
        // form 4
        if let v = try row[name] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected successful extraction")
        }
    }
    
    func assertRowConvertedValueEqual<T: Equatable & DatabaseValueConvertible & StatementColumnConvertible>(_ row: Row, column: Column, value: T) throws {
        // form 1
        try XCTAssertEqual(row[column] as T, value)
        
        // form 2
        try XCTAssertEqual(row[column]! as T, value)
        
        // form 3
        try XCTAssertEqual((row[column] as T?)!, value)
        
        // form 4
        if let v = try row[column] as T? {
            XCTAssertEqual(v, value)
        } else {
            XCTFail("expected successful extraction")
        }
    }
}
