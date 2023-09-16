import XCTest
import Foundation
import GRDB

class DatabaseValueConvertibleEncodableTests: GRDBTestCase {
    func testDatabaseValueConvertibleImplementationDerivedFromEncodable1() {
        struct Value : Encodable, DatabaseValueConvertible {
            let string: String
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(string)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
            
            // Inferred, tested
            // var databaseValue: DatabaseValue { ... }
        }
        
        let dbValue = Value(string: "foo").databaseValue
        XCTAssertEqual(dbValue.storage.value as! String, "foo")
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromEncodable2() {
        struct Value : Encodable, DatabaseValueConvertible {
            let string: String
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(string)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
        }
        
        struct Wrapper : Encodable, DatabaseValueConvertible {
            let value: Value
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(value)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Wrapper? {
                preconditionFailure("not tested")
            }
            
            // Inferred, tested
            // var databaseValue: DatabaseValue { ... }
        }
        
        let dbValue = Wrapper(value: Value(string: "foo")).databaseValue
        XCTAssertEqual(dbValue.storage.value as! String, "foo")
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromEncodable3() {
        struct Wrapper : Encodable, DatabaseValueConvertible {
            struct Nested : Encodable {
                let string: String
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    try container.encode(string)
                }
            }
            let nested: Nested
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(nested)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Wrapper? {
                preconditionFailure("not tested")
            }
            
            // Inferred, tested
            // var databaseValue: DatabaseValue { ... }
        }
        
        let dbValue = Wrapper(nested: Wrapper.Nested(string: "foo")).databaseValue
        XCTAssertEqual(dbValue.storage.value as! String, "foo")
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromEncodable4() throws {
        struct Value: Encodable, DatabaseValueConvertible {
            let strings: [String]
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
        }
        
        do {
            let dbValue = Value(strings: ["foo", "bar"]).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"{"strings":["foo","bar"]}"#)
        }
        
        do {
            let dbValue = Value(strings: []).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"{"strings":[]}"#)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromEncodable5() throws {
        struct Value: Encodable, DatabaseValueConvertible {
            let dictionary: [String: Int]
            
            func encode(to encoder: Encoder) throws {
                try dictionary.encode(to: encoder)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
        }
        
        do {
            let dbValue = Value(dictionary: ["foo": 1]).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"{"foo":1}"#)
        }
        
        do {
            let dbValue = Value(dictionary: [:]).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"{}"#)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromEncodable6() throws {
        struct Value: Encodable, DatabaseValueConvertible {
            let strings: [String]
            
            func encode(to encoder: Encoder) throws {
                try strings.encode(to: encoder)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
        }
        
        do {
            let dbValue = Value(strings: ["foo", "bar"]).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"["foo","bar"]"#)
        }
        
        do {
            let dbValue = Value(strings: []).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"[]"#)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromEncodable7() throws {
        struct Value: Encodable, DatabaseValueConvertible {
            let dictionary: [String: Int]
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(dictionary)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
        }
        
        do {
            let dbValue = Value(dictionary: ["foo": 1]).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"{"foo":1}"#)
        }
        
        do {
            let dbValue = Value(dictionary: [:]).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"{}"#)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromEncodable8() throws {
        struct Value: Encodable, DatabaseValueConvertible {
            let strings: [String]
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(strings)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
        }
        
        do {
            let dbValue = Value(strings: ["foo", "bar"]).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"["foo","bar"]"#)
        }
        
        do {
            let dbValue = Value(strings: []).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"[]"#)
        }
    }
    
    func testEncodableRawRepresentable() {
        // Test that the rawValue is encoded with DatabaseValueConvertible, not with Encodable
        struct Value : RawRepresentable, Encodable, DatabaseValueConvertible {
            let rawValue: Date
        }
        
        let dbValue = Value(rawValue: Date()).databaseValue
        XCTAssertTrue(dbValue.storage.value is String)
    }
    
    func testEncodableRawRepresentableEnum() {
        // Make sure this kind of declaration is possible
        enum Value : String, Encodable, DatabaseValueConvertible {
            case foo, bar
        }
        let dbValue = Value.foo.databaseValue
        XCTAssertEqual(dbValue.storage.value as! String, "foo")
    }
}

// MARK: - Foundation Codable Types

extension DatabaseValueConvertibleEncodableTests {
    func testDateProperty() {
        struct Value : Encodable, DatabaseValueConvertible {
            let date: Date
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(date)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
            
            // Inferred, tested
            // var databaseValue: DatabaseValue { ... }
        }
        
        let value = Value(date: Date())
        let dbValue = value.databaseValue
        
        // Date has a default Encodable implementation which encodes a Double.
        // We expect here a String, because DatabaseValueConvertible has
        // precedence over Encodable.
        XCTAssert(dbValue.storage.value is String)
        
        let encodedDate = Date.fromDatabaseValue(dbValue)!
        XCTAssert(abs(encodedDate.timeIntervalSince(value.date)) < 0.001)
    }
    
    func testURLProperty() {
        struct Value : Encodable, DatabaseValueConvertible {
            let url: URL
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(url)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
            
            // Inferred, tested
            // var databaseValue: DatabaseValue { ... }
        }
        
        let value = Value(url: URL(string: "https://github.com")!)
        let dbValue = value.databaseValue
        XCTAssert(dbValue.storage.value is String)
        let encodedURL = URL.fromDatabaseValue(dbValue)!
        XCTAssertEqual(encodedURL, value.url)
    }
    
    func testUUIDProperty() {
        struct Value : Encodable, DatabaseValueConvertible {
            let uuid: UUID
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(uuid)
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
            
            // Inferred, tested
            // var databaseValue: DatabaseValue { ... }
        }
        
        let value = Value(uuid: UUID())
        let dbValue = value.databaseValue
        XCTAssert(dbValue.storage.value is Data)
        let encodedUUID = UUID.fromDatabaseValue(dbValue)!
        XCTAssertEqual(encodedUUID, value.uuid)
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromEncodableWithCustomJsonEncoder() throws {
        struct Value: Encodable, DatabaseValueConvertible {
            let duration: Double
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                preconditionFailure("not tested")
            }
            
            public static func databaseJSONEncoder() -> JSONEncoder {
                let encoder = JSONEncoder()
                encoder.dataEncodingStrategy = .base64
                encoder.dateEncodingStrategy = .millisecondsSince1970
                encoder.nonConformingFloatEncodingStrategy = .convertToString(
                    positiveInfinity: "+InF",
                    negativeInfinity: "-InF",
                    nan: "NaN"
                )
                // guarantee some stability in order to ease value comparison
                encoder.outputFormatting = .sortedKeys
                return encoder
            }
        }
        
        do {
            let dbValue = Value(duration: .infinity).databaseValue
            XCTAssertEqual(dbValue.storage.value as! String, #"{"duration":"+InF"}"#)
            
            let dbValue2 = Value(duration: -Double.infinity).databaseValue
            XCTAssertEqual(dbValue2.storage.value as! String, #"{"duration":"-InF"}"#)
            
            let dbValue3 = Value(duration: .nan).databaseValue
            XCTAssertEqual(dbValue3.storage.value as! String, #"{"duration":"NaN"}"#)
        }
    }
}
