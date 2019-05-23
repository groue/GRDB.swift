import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

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
            
            // Infered, tested
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
            
            // Infered, tested
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
            
            // Infered, tested
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
}
