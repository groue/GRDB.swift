import Foundation
import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class RowConvertibleDecodableTests: GRDBTestCase { }

// MARK: - RowConvertible conformance derived from Decodable

extension RowConvertibleDecodableTests {
    
    func testTrivialDecodable() {
        struct Struct : RowConvertible, Decodable {
            let value: String
        }
        
        do {
            let s = Struct(row: ["value": "foo"])
            XCTAssertEqual(s.value, "foo")
        }
    }
    
    func testCustomDecodable() {
        struct Struct : RowConvertible, Decodable {
            let value: String
            
            private enum CodingKeys : String, CodingKey {
                case value = "someColumn"
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                value = try container.decode(String.self, forKey: .value)
            }
        }
        
        do {
            let s = Struct(row: ["someColumn": "foo"])
            XCTAssertEqual(s.value, "foo")
        }
    }
    
    func testCustomRowConvertible() {
        struct Struct : RowConvertible, Decodable {
            let value: String
            
            init(row: Row) {
                value = (row["value"] as String) + " (RowConvertible)"
            }
        }
        
        do {
            let s = Struct(row: ["value": "foo"])
            XCTAssertEqual(s.value, "foo (RowConvertible)")
        }
    }
}

// MARK: - Different kinds of single-value properties

extension RowConvertibleDecodableTests {
    
    func testTrivialProperty() {
        struct Struct : RowConvertible, Decodable {
            let int64: Int64
            let optionalInt64: Int64?
        }
        
        do {
            // No null values
            let s = Struct(row: ["int64": 1, "optionalInt64": 2])
            XCTAssertEqual(s.int64, 1)
            XCTAssertEqual(s.optionalInt64, 2)
        }
        do {
            // Null values
            let s = Struct(row: ["int64": 2, "optionalInt64": nil])
            XCTAssertEqual(s.int64, 2)
            XCTAssertNil(s.optionalInt64)
        }
        do {
            // Missing and extra values
            let s = Struct(row: ["int64": 3, "ignored": "?"])
            XCTAssertEqual(s.int64, 3)
            XCTAssertNil(s.optionalInt64)
        }
    }
    
    func testTrivialSingleValueDecodableProperty() {
        struct Value : Decodable {
            let string: String
            
            init(from decoder: Decoder) throws {
                string = try decoder.singleValueContainer().decode(String.self)
            }
        }
        
        struct Struct : RowConvertible, Decodable {
            let value: Value
            let optionalValue: Value?
        }
        
        do {
            // No null values
            let s = Struct(row: ["value": "foo", "optionalValue": "bar"])
            XCTAssertEqual(s.value.string, "foo")
            XCTAssertEqual(s.optionalValue!.string, "bar")
        }
        
        do {
            // Null values
            let s = Struct(row: ["value": "foo", "optionalValue": nil])
            XCTAssertEqual(s.value.string, "foo")
            XCTAssertNil(s.optionalValue)
        }
        
        do {
            // Missing and extra values
            let s = Struct(row: ["value": "foo", "ignored": "?"])
            XCTAssertEqual(s.value.string, "foo")
            XCTAssertNil(s.optionalValue)
        }
    }
    
    func testNonTrivialSingleValueDecodableProperty() {
        struct NestedValue : Decodable {
            let string: String
            
            init(from decoder: Decoder) throws {
                string = try decoder.singleValueContainer().decode(String.self)
            }
        }
        
        struct Value : Decodable {
            let nestedValue: NestedValue
            
            init(from decoder: Decoder) throws {
                nestedValue = try decoder.singleValueContainer().decode(NestedValue.self)
            }
        }
        
        struct Struct : RowConvertible, Decodable {
            let value: Value
            let optionalValue: Value?
        }
        
        do {
            // No null values
            let s = Struct(row: ["value": "foo", "optionalValue": "bar"])
            XCTAssertEqual(s.value.nestedValue.string, "foo")
            XCTAssertEqual(s.optionalValue!.nestedValue.string, "bar")
        }
        
        do {
            // Null values
            let s = Struct(row: ["value": "foo", "optionalValue": nil])
            XCTAssertEqual(s.value.nestedValue.string, "foo")
            XCTAssertNil(s.optionalValue)
        }
        
        do {
            // Missing and extra values
            let s = Struct(row: ["value": "foo", "ignored": "?"])
            XCTAssertEqual(s.value.nestedValue.string, "foo")
            XCTAssertNil(s.optionalValue)
        }
    }
    
    func testDecodableRawRepresentableProperty() {
        // This test is somewhat redundant with testSingleValueDecodableProperty,
        // since a RawRepresentable enum is a "single-value" Decodable.
        //
        // But with an explicit test for enums, we are sure that enums, widely
        // used, are supported.
        enum Value : String, Decodable {
            case foo, bar
        }
        
        struct Struct : RowConvertible, Decodable {
            let value: Value
            let optionalValue: Value?
        }
        
        do {
            // No null values
            let s = Struct(row: ["value": "foo", "optionalValue": "bar"])
            XCTAssertEqual(s.value, .foo)
            XCTAssertEqual(s.optionalValue!, .bar)
        }
        
        do {
            // Null values
            let s = Struct(row: ["value": "foo", "optionalValue": nil])
            XCTAssertEqual(s.value, .foo)
            XCTAssertNil(s.optionalValue)
        }
        
        do {
            // Missing and extra values
            let s = Struct(row: ["value": "foo", "ignored": "?"])
            XCTAssertEqual(s.value, .foo)
            XCTAssertNil(s.optionalValue)
        }
    }
    
    func testDatabaseValueConvertibleProperty() {
        // This test makes sure that Date, for example, can be read from a String.
        //
        // Without this preference for fromDatabaseValue(_:) over init(from:Decoder),
        // Date would only decode from doubles.
        struct Value : Decodable, DatabaseValueConvertible {
            let string: String
            
            init(string: String) {
                self.string = string
            }
            
            init(from decoder: Decoder) throws {
                string = try decoder.singleValueContainer().decode(String.self) + " (Decodable)"
            }
            
            // DatabaseValueConvertible adoption
            
            var databaseValue: DatabaseValue {
                fatalError("irrelevant")
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                if let string = String.fromDatabaseValue(databaseValue) {
                    return Value(string: string + " (DatabaseValueConvertible)")
                } else {
                    return nil
                }
            }
        }
        
        struct Struct : RowConvertible, Decodable {
            let value: Value
            let optionalValue: Value?
        }
        
        do {
            // No null values
            let s = Struct(row: ["value": "foo", "optionalValue": "bar"])
            XCTAssertEqual(s.value.string, "foo (DatabaseValueConvertible)")
            XCTAssertEqual(s.optionalValue!.string, "bar (DatabaseValueConvertible)")
        }
        
        do {
            // Null values
            let s = Struct(row: ["value": "foo", "optionalValue": nil])
            XCTAssertEqual(s.value.string, "foo (DatabaseValueConvertible)")
            XCTAssertNil(s.optionalValue)
        }
        
        do {
            // Missing and extra values
            let s = Struct(row: ["value": "foo", "ignored": "?"])
            XCTAssertEqual(s.value.string, "foo (DatabaseValueConvertible)")
            XCTAssertNil(s.optionalValue)
        }
    }
}

// MARK: - Foundation Codable Types

extension RowConvertibleDecodableTests {

    func testStructWithDate() {
        struct StructWithDate : RowConvertible, Decodable {
            let date: Date
        }
        
        let date = Date()
        let value = StructWithDate(row: ["date": date])
        XCTAssert(abs(value.date.timeIntervalSince(date)) < 0.001)
    }
    
    func testStructWithURL() {
        struct StructWithURL : RowConvertible, Decodable {
            let url: URL
        }
        
        let url = URL(string: "https://github.com")
        let value = StructWithURL(row: ["url": url])
        XCTAssertEqual(value.url, url)
    }
    
    func testStructWithUUID() {
        struct StructWithUUID : RowConvertible, Decodable {
            let uuid: UUID
        }
        
        let uuid = UUID()
        let value = StructWithUUID(row: ["uuid": uuid])
        XCTAssertEqual(value.uuid, uuid)
    }
}
