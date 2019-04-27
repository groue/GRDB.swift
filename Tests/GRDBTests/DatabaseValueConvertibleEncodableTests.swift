import XCTest
import Foundation
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

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
            
            // Infered, tested
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
            
            // Infered, tested
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
            
            // Infered, tested
            // var databaseValue: DatabaseValue { ... }
        }
        
        let dbValue = Wrapper(nested: Wrapper.Nested(string: "foo")).databaseValue
        XCTAssertEqual(dbValue.storage.value as! String, "foo")
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
            
            // Infered, tested
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
            
            // Infered, tested
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
            
            // Infered, tested
            // var databaseValue: DatabaseValue { ... }
        }
        
        let value = Value(uuid: UUID())
        let dbValue = value.databaseValue
        XCTAssert(dbValue.storage.value is Data)
        let encodedUUID = UUID.fromDatabaseValue(dbValue)!
        XCTAssertEqual(encodedUUID, value.uuid)
    }
}
