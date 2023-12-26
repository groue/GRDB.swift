import XCTest
import GRDB

class DatabaseValueConvertibleDecodableTests: GRDBTestCase {
    func testDatabaseValueConvertibleImplementationDerivedFromDecodable1() throws {
        struct Value : Decodable, DatabaseValueConvertible {
            let string: String
            
            init(from decoder: Decoder) throws {
                string = try decoder.singleValueContainer().decode(String.self)
            }
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
            
            // Inferred, tested
            // static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? { ... }
        }
        
        do {
            // Success from DatabaseValue
            let value = Value.fromDatabaseValue("foo".databaseValue)!
            XCTAssertEqual(value.string, "foo")
        }
        do {
            // Success from database
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let value = try Value.fetchOne(db, sql: "SELECT 'foo'")!
                XCTAssertEqual(value.string, "foo")
            }
        }
        do {
            // Failure from DatabaseValue
            let value = Value.fromDatabaseValue(1.databaseValue)
            XCTAssertNil(value)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromDecodable2() throws {
        struct Value : Decodable, DatabaseValueConvertible {
            let string: String
            
            init(from decoder: Decoder) throws {
                string = try decoder.singleValueContainer().decode(String.self)
            }
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
        }
        
        struct ValueWrapper : Decodable, DatabaseValueConvertible {
            let value: Value
            
            init(from decoder: Decoder) throws {
                value = try decoder.singleValueContainer().decode(Value.self)
            }
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
            
            // Inferred, tested
            // static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? { ... }
        }
        
        do {
            // Success from DatabaseValue
            let wrapper = ValueWrapper.fromDatabaseValue("foo".databaseValue)!
            XCTAssertEqual(wrapper.value.string, "foo")
        }
        do {
            // Success from database
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let wrapper = try ValueWrapper.fetchOne(db, sql: "SELECT 'foo'")!
                XCTAssertEqual(wrapper.value.string, "foo")
            }
        }
        do {
            // Failure from DatabaseValue
            let wrapper = ValueWrapper.fromDatabaseValue(1.databaseValue)
            XCTAssertNil(wrapper)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromDecodable3() throws {
        struct ValueWrapper : Decodable, DatabaseValueConvertible {
            struct Nested : Decodable {
                let string: String
                
                init(from decoder: Decoder) throws {
                    string = try decoder.singleValueContainer().decode(String.self)
                }
            }
            let nested: Nested

            init(from decoder: Decoder) throws {
                nested = try decoder.singleValueContainer().decode(Nested.self)
            }
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
            
            // Inferred, tested
            // static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? { ... }
        }
        
        do {
            // Success from DatabaseValue
            let wrapper = ValueWrapper.fromDatabaseValue("foo".databaseValue)!
            XCTAssertEqual(wrapper.nested.string, "foo")
        }
        do {
            // Success from database
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let wrapper = try ValueWrapper.fetchOne(db, sql: "SELECT 'foo'")!
                XCTAssertEqual(wrapper.nested.string, "foo")
            }
        }
        do {
            // Failure from DatabaseValue
            let wrapper = ValueWrapper.fromDatabaseValue(1.databaseValue)
            XCTAssertNil(wrapper)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromDecodable4() throws {
        struct Value: Decodable, DatabaseValueConvertible {
            let strings: [String]
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
        }
        
        do {
            // Success from DatabaseValue
            let value = Value.fromDatabaseValue(#"{ "strings": ["foo", "bar"] }"#.databaseValue)!
            XCTAssertEqual(value.strings, ["foo", "bar"])
        }
        do {
            // Success from database
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let value = try Value.fetchOne(db, sql: #"SELECT '{ "strings": ["foo", "bar"] }'"#)!
                XCTAssertEqual(value.strings, ["foo", "bar"])
            }
        }
        do {
            // Failure from DatabaseValue
            let value = Value.fromDatabaseValue(1.databaseValue)
            XCTAssertNil(value)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromDecodable5() throws {
        struct Value: Decodable, DatabaseValueConvertible {
            let dictionary: [String: Int]
            
            init(from decoder: Decoder) throws {
                dictionary = try .init(from: decoder)
            }
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
        }
        
        do {
            // Success from DatabaseValue
            let value = Value.fromDatabaseValue(#"{"foo": 1}"#.databaseValue)!
            XCTAssertEqual(value.dictionary, ["foo": 1])
        }
        do {
            // Success from database
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let value = try Value.fetchOne(db, sql: #"SELECT '{"foo": 1}'"#)!
                XCTAssertEqual(value.dictionary, ["foo": 1])
            }
        }
        do {
            // Failure from DatabaseValue
            let value = Value.fromDatabaseValue(1.databaseValue)
            XCTAssertNil(value)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromDecodable6() throws {
        struct Value: Decodable, DatabaseValueConvertible {
            let strings: [String]
            
            init(from decoder: Decoder) throws {
                strings = try .init(from: decoder)
            }
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
        }
        
        do {
            // Success from DatabaseValue
            let value = Value.fromDatabaseValue(#"["foo", "bar"]"#.databaseValue)!
            XCTAssertEqual(value.strings, ["foo", "bar"])
        }
        do {
            // Success from database
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let value = try Value.fetchOne(db, sql: #"SELECT '["foo", "bar"]'"#)!
                XCTAssertEqual(value.strings, ["foo", "bar"])
            }
        }
        do {
            // Failure from DatabaseValue
            let value = Value.fromDatabaseValue(1.databaseValue)
            XCTAssertNil(value)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromDecodable7() throws {
        struct Value: Decodable, DatabaseValueConvertible {
            let dictionary: [String: Int]
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                dictionary = try container.decode([String: Int].self)
            }
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
        }
        
        do {
            // Success from DatabaseValue
            let value = Value.fromDatabaseValue(#"{"foo": 1}"#.databaseValue)!
            XCTAssertEqual(value.dictionary, ["foo": 1])
        }
        do {
            // Success from database
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let value = try Value.fetchOne(db, sql: #"SELECT '{"foo": 1}'"#)!
                XCTAssertEqual(value.dictionary, ["foo": 1])
            }
        }
        do {
            // Failure from DatabaseValue
            let value = Value.fromDatabaseValue(1.databaseValue)
            XCTAssertNil(value)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromDecodable8() throws {
        struct Value: Decodable, DatabaseValueConvertible {
            let strings: [String]
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                strings = try container.decode([String].self)
            }
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
        }
        
        do {
            // Success from DatabaseValue
            let value = Value.fromDatabaseValue(#"["foo", "bar"]"#.databaseValue)!
            XCTAssertEqual(value.strings, ["foo", "bar"])
        }
        do {
            // Success from database
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let value = try Value.fetchOne(db, sql: #"SELECT '["foo", "bar"]'"#)!
                XCTAssertEqual(value.strings, ["foo", "bar"])
            }
        }
        do {
            // Failure from DatabaseValue
            let value = Value.fromDatabaseValue(1.databaseValue)
            XCTAssertNil(value)
        }
    }

    func testCustomDatabaseValueConvertible() throws {
        struct Value : Decodable, DatabaseValueConvertible {
            let string: String
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                if let string = String.fromDatabaseValue(databaseValue) {
                    return Value(string: string + " (DatabaseValueConvertible)")
                } else {
                    return nil
                }
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let value = try Value.fetchOne(db, sql: "SELECT 'foo'")!
            XCTAssertEqual(value.string, "foo (DatabaseValueConvertible)")
        }
    }
    
    func testDecodableRawRepresentableFetchingMethod() throws {
        enum Value : String, Decodable, DatabaseValueConvertible {
            case foo, bar
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let value = try Value.fetchOne(db, sql: "SELECT 'foo'")!
            XCTAssertEqual(value, .foo)
        }
    }
    
    func testDatabaseValueConvertibleImplementationDerivedFromDecodableWithCustomJsonDecoder() throws {
        struct Value: Decodable, DatabaseValueConvertible {
            let duration: Double
            
            var databaseValue: DatabaseValue {
                preconditionFailure("not tested")
            }
            
            public static func databaseJSONDecoder() -> JSONDecoder {
                let decoder = JSONDecoder()
                decoder.dataDecodingStrategy = .base64
                decoder.dateDecodingStrategy = .millisecondsSince1970
                decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                    positiveInfinity: "+InF",
                    negativeInfinity: "-InF",
                    nan: "NaN"
                )
                return decoder
            }
        }
        
        do {
            // Success from DatabaseValue
            let value = Value.fromDatabaseValue(#"{ "duration": "+InF" }"#.databaseValue)!
            XCTAssertEqual(value.duration, Double.infinity)
            
            let value2 = Value.fromDatabaseValue(#"{ "duration": "-InF" }"#.databaseValue)!
            XCTAssertEqual(value2.duration, -Double.infinity)
            
            let value3 = Value.fromDatabaseValue(#"{ "duration": "NaN" }"#.databaseValue)!
            XCTAssertTrue(value3.duration.isNaN)
        }
        do {
            // Success from database
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let value = try Value.fetchOne(db, sql: #"SELECT '{ "duration": "+InF" }'"#)!
                XCTAssertEqual(value.duration, Double.infinity)
                
                let value2 = try Value.fetchOne(db, sql: #"SELECT '{ "duration": "-InF" }'"#)!
                XCTAssertEqual(value2.duration, -Double.infinity)
                
                let value3 = try Value.fetchOne(db, sql: #"SELECT '{ "duration": "NaN" }'"#)!
                XCTAssertTrue(value3.duration.isNaN)
            }
        }
        do {
            // Failure from DatabaseValue
            let value = Value.fromDatabaseValue("infinity".databaseValue)
            XCTAssertNil(value)
        }
    }
}
