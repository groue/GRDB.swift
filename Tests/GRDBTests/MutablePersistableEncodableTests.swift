import XCTest
import Foundation
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class MutablePersistableEncodableTests: GRDBTestCase { }

// MARK: - MutablePersistable conformance derived from Encodable

extension MutablePersistableEncodableTests {
    
    func testTrivialEncodable() throws {
        struct Struct : MutablePersistable, Encodable {
            static let databaseTableName = "t1"
            let value: String
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("value", .text)
            }
            
            var value = Struct(value: "foo")
            assert(value, isEncodedIn: ["value": "foo"])
            
            try value.insert(db)
            let string = try String.fetchOne(db, "SELECT value FROM t1")!
            XCTAssertEqual(string, "foo")
        }
    }
    
    func testCustomEncodable() throws {
        struct Struct : MutablePersistable, Encodable {
            static let databaseTableName = "t1"
            let value: String
            
            private enum CodingKeys : String, CodingKey {
                case value = "someColumn"
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(value + " (Encodable)", forKey: .value)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("someColumn", .text)
            }
            
            var value = Struct(value: "foo")
            assert(value, isEncodedIn: ["someColumn": "foo (Encodable)"])
            
            try value.insert(db)
            let string = try String.fetchOne(db, "SELECT someColumn FROM t1")!
            XCTAssertEqual(string, "foo (Encodable)")
        }
    }
    
    func testCustomMutablePersistable() throws {
        struct Struct : MutablePersistable, Encodable {
            static let databaseTableName = "t1"
            let value: String
            
            func encode(to container: inout PersistenceContainer) {
                container["value"] = value + " (MutablePersistable)"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("value", .text)
            }
            
            var value = Struct(value: "foo")
            assert(value, isEncodedIn: ["value": "foo (MutablePersistable)"])
            
            try value.insert(db)
            let string = try String.fetchOne(db, "SELECT value FROM t1")!
            XCTAssertEqual(string, "foo (MutablePersistable)")
        }
    }
}

// MARK: - Different kinds of single-value properties

extension MutablePersistableEncodableTests {
    
    func testTrivialProperty() throws {
        struct Struct : MutablePersistable, Encodable {
            static let databaseTableName = "t1"
            let int64: Int64
            let optionalInt64: Int64?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("int64", .integer)
                t.column("optionalInt64", .integer)
            }
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(int64: 123, optionalInt64: 456)
            assert(value, isEncodedIn: ["int64": 123, "optionalInt64": 456])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, "SELECT * FROM t1")!
            XCTAssertEqual(row, ["int64": 123, "optionalInt64": 456])
            return .rollback
        }
    
        try dbQueue.inTransaction { db in
            var value = Struct(int64: 123, optionalInt64: nil)
            assert(value, isEncodedIn: ["int64": 123, "optionalInt64": nil])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, "SELECT * FROM t1")!
            XCTAssertEqual(row, ["int64": 123, "optionalInt64": nil])
            return .rollback
        }
    }
    
    func testTrivialSingleValueEncodableProperty() throws {
        struct Value : Encodable {
            let string: String
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(string)
            }
        }
        
        struct Struct : MutablePersistable, Encodable {
            static let databaseTableName = "t1"
            let value: Value
            let optionalValue: Value?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("value", .integer)
                t.column("optionalValue", .integer)
            }
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: Value(string: "foo"), optionalValue: Value(string: "bar"))
            assert(value, isEncodedIn: ["value": "foo", "optionalValue": "bar"])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo", "optionalValue": "bar"])
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: Value(string: "foo"), optionalValue: nil)
            assert(value, isEncodedIn: ["value": "foo", "optionalValue": nil])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo", "optionalValue": nil])
            return .rollback
        }
    }
    
    func testNonTrivialSingleValueEncodableProperty() throws {
        struct NestedValue : Encodable {
            let string: String
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(string)
            }
        }
        
        struct Value : Encodable {
            let nestedValue: NestedValue
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(nestedValue)
            }
        }
        
        struct Struct : MutablePersistable, Encodable {
            static let databaseTableName = "t1"
            let value: Value
            let optionalValue: Value?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("value", .integer)
                t.column("optionalValue", .integer)
            }
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: Value(nestedValue: NestedValue(string: "foo")), optionalValue: Value(nestedValue: NestedValue(string: "bar")))
            assert(value, isEncodedIn: ["value": "foo", "optionalValue": "bar"])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo", "optionalValue": "bar"])
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: Value(nestedValue: NestedValue(string: "foo")), optionalValue: nil)
            assert(value, isEncodedIn: ["value": "foo", "optionalValue": nil])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo", "optionalValue": nil])
            return .rollback
        }
    }
    
    func testEncodableRawRepresentableProperty() throws {
        // This test is somewhat redundant with testSingleValueEncodableProperty,
        // since a RawRepresentable enum is a "single-value" Encodable.
        //
        // But with an explicit test for enums, we are sure that enums, widely
        // used, are supported.
        enum Value : String, Encodable {
            case foo, bar
        }
        
        struct Struct : MutablePersistable, Encodable {
            static let databaseTableName = "t1"
            let value: Value
            let optionalValue: Value?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("value", .integer)
                t.column("optionalValue", .integer)
            }
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: .foo, optionalValue: .bar)
            assert(value, isEncodedIn: ["value": "foo", "optionalValue": "bar"])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo", "optionalValue": "bar"])
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: .foo, optionalValue: nil)
            assert(value, isEncodedIn: ["value": "foo", "optionalValue": nil])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo", "optionalValue": nil])
            return .rollback
        }
    }
    
    func testDatabaseValueConvertibleProperty() throws {
        // This test makes sure that Date, for example, can be stored as a String.
        //
        // Without this preference for databaseValue over encode(to:),
        // Date would encode as a double.
        struct Value : Encodable, DatabaseValueConvertible {
            let string: String
            
            init(string: String) {
                self.string = string
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(string + " (Encodable)")
            }
            
            // DatabaseValueConvertible adoption
            
            var databaseValue: DatabaseValue {
                return (string + " (DatabaseValueConvertible)").databaseValue
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                fatalError("irrelevant")
            }
        }
        
        struct Struct : MutablePersistable, Encodable {
            static let databaseTableName = "t1"
            let value: Value
            let optionalValue: Value?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("value", .integer)
                t.column("optionalValue", .integer)
            }
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: Value(string: "foo"), optionalValue: Value(string: "bar"))
            assert(value, isEncodedIn: ["value": "foo (DatabaseValueConvertible)", "optionalValue": "bar (DatabaseValueConvertible)"])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo (DatabaseValueConvertible)", "optionalValue": "bar (DatabaseValueConvertible)"])
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: Value(string: "foo"), optionalValue: nil)
            assert(value, isEncodedIn: ["value": "foo (DatabaseValueConvertible)", "optionalValue": nil])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo (DatabaseValueConvertible)", "optionalValue": nil])
            return .rollback
        }
    }
}

// MARK: - Foundation Codable Types

extension MutablePersistableEncodableTests {
    
    func testStructWithDate() throws {
        struct StructWithDate : Persistable, Encodable {
            static let databaseTableName = "t1"
            let date: Date
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("date", .datetime)
            }
            
            let value = StructWithDate(date: Date())
            try value.insert(db)
            
            let dbValue = try DatabaseValue.fetchOne(db, "SELECT date FROM t1")!
            
            // Date has a default Encodable implementation which encodes a Double.
            // We expect here a String, because DatabaseValueConvertible has
            // precedence over Encodable.
            XCTAssert(dbValue.storage.value is String)
            
            let fetchedDate = Date.fromDatabaseValue(dbValue)!
            XCTAssert(abs(fetchedDate.timeIntervalSince(value.date)) < 0.001)
        }
    }
    
    func testStructWithURL() throws {
        struct StructWithURL : Persistable, Encodable {
            static let databaseTableName = "t1"
            let url: URL
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("url", .text)
            }
            
            let value = StructWithURL(url: URL(string: "https://github.com")!)
            assert(value, isEncodedIn: ["url": value.url])
            
            try value.insert(db)
            let dbValue = try DatabaseValue.fetchOne(db, "SELECT url FROM t1")!
            XCTAssert(dbValue.storage.value is String)
            let fetchedURL = URL.fromDatabaseValue(dbValue)!
            XCTAssertEqual(fetchedURL, value.url)
        }
    }
    
    func testStructWithUUID() throws {
        struct StructWithUUID : Persistable, Encodable {
            static let databaseTableName = "t1"
            let uuid: UUID
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("uuid", .blob)
            }
            
            let value = StructWithUUID(uuid: UUID())
            assert(value, isEncodedIn: ["uuid": value.uuid])
            
            try value.insert(db)
            let dbValue = try DatabaseValue.fetchOne(db, "SELECT uuid FROM t1")!
            XCTAssert(dbValue.storage.value is Data)
            let fetchedUUID = UUID.fromDatabaseValue(dbValue)!
            XCTAssertEqual(fetchedUUID, value.uuid)
        }
    }
}
