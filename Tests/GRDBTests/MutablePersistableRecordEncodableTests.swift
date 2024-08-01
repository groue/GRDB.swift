import XCTest
import Foundation
import GRDB

class MutablePersistableRecordEncodableTests: GRDBTestCase { }

// MARK: - MutablePersistableRecord conformance derived from Encodable

extension MutablePersistableRecordEncodableTests {
    
    func testTrivialEncodable() throws {
        struct Struct : MutablePersistableRecord, Encodable {
            static let databaseTableName = "t1"
            let value: String
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("value", .text)
            }
            
            var value = Struct(value: "foo")
            try assert(value, isEncodedIn: ["value": "foo"])
            
            try value.insert(db)
            let string = try String.fetchOne(db, sql: "SELECT value FROM t1")!
            XCTAssertEqual(string, "foo")
        }
    }
    
    func testCustomEncodable() throws {
        struct Struct : MutablePersistableRecord, Encodable {
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
            try assert(value, isEncodedIn: ["someColumn": "foo (Encodable)"])
            
            try value.insert(db)
            let string = try String.fetchOne(db, sql: "SELECT someColumn FROM t1")!
            XCTAssertEqual(string, "foo (Encodable)")
        }
    }
    
    func testCustomMutablePersistableRecord() throws {
        struct Struct : MutablePersistableRecord, Encodable {
            static let databaseTableName = "t1"
            let value: String
            
            func encode(to container: inout PersistenceContainer) {
                container["value"] = value + " (MutablePersistableRecord)"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("value", .text)
            }
            
            var value = Struct(value: "foo")
            try assert(value, isEncodedIn: ["value": "foo (MutablePersistableRecord)"])
            
            try value.insert(db)
            let string = try String.fetchOne(db, sql: "SELECT value FROM t1")!
            XCTAssertEqual(string, "foo (MutablePersistableRecord)")
        }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1565>
    func testSingleValueContainer() throws {
        struct Struct: Encodable {
            let value: String
        }
        
        struct Wrapper<Model: Encodable>: MutablePersistableRecord, Encodable {
            static var databaseTableName: String { "t1" }
            var model: Model
            var otherValue: String
            
            enum CodingKeys: String, CodingKey {
                case otherValue
            }
            
            func encode(to encoder: any Encoder) throws {
                var modelContainer = encoder.singleValueContainer()
                try modelContainer.encode(model)
                
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(otherValue, forKey: .otherValue)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("value", .text)
                t.column("otherValue", .text)
            }
            
            var value = Wrapper(model: Struct(value: "foo"), otherValue: "bar")
            try assert(value, isEncodedIn: ["value": "foo", "otherValue": "bar"])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT value, otherValue FROM t1")!
            XCTAssertEqual(row[0], "foo")
            XCTAssertEqual(row[1], "bar")
        }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1565>
    // Here we test that `EncodableRecord` takes precedence over `Encodable`
    // when a record is encoded with a `SingleValueEncodingContainer`.
    func testSingleValueContainerWithEncodableRecord() throws {
        struct Struct: Encodable, EncodableRecord {
            let value: String
            
            func encode(to container: inout PersistenceContainer) throws {
                container["column1"] = "test"
                container["column2"] = 12
            }
        }
        
        struct Wrapper<Model: Encodable>: MutablePersistableRecord, Encodable {
            static var databaseTableName: String { "t1" }
            var model: Model
            var otherValue: String
            
            enum CodingKeys: String, CodingKey {
                case otherValue
            }
            
            func encode(to encoder: any Encoder) throws {
                var modelContainer = encoder.singleValueContainer()
                try modelContainer.encode(model)
                
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(otherValue, forKey: .otherValue)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("column1", .text)
                t.column("column2", .integer)
                t.column("otherValue", .text)
            }
            
            var value = Wrapper(model: Struct(value: "foo"), otherValue: "bar")
            try assert(value, isEncodedIn: ["column1": "test", "column2": 12, "otherValue": "bar"])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT column1, column2, otherValue FROM t1")!
            XCTAssertEqual(row[0], "test")
            XCTAssertEqual(row[1], 12)
            XCTAssertEqual(row[2], "bar")
        }
    }
}

// MARK: - Different kinds of single-value properties

extension MutablePersistableRecordEncodableTests {
    
    func testTrivialProperty() throws {
        struct Struct : MutablePersistableRecord, Encodable {
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
            try assert(value, isEncodedIn: ["int64": 123, "optionalInt64": 456])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM t1")!
            XCTAssertEqual(row, ["int64": 123, "optionalInt64": 456])
            return .rollback
        }
    
        try dbQueue.inTransaction { db in
            var value = Struct(int64: 123, optionalInt64: nil)
            try assert(value, isEncodedIn: ["int64": 123, "optionalInt64": nil])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM t1")!
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
        
        struct Struct : MutablePersistableRecord, Encodable {
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
            try assert(value, isEncodedIn: ["value": "foo", "optionalValue": "bar"])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo", "optionalValue": "bar"])
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: Value(string: "foo"), optionalValue: nil)
            try assert(value, isEncodedIn: ["value": "foo", "optionalValue": nil])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM t1")!
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
        
        struct Struct : MutablePersistableRecord, Encodable {
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
            try assert(value, isEncodedIn: ["value": "foo", "optionalValue": "bar"])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo", "optionalValue": "bar"])
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: Value(nestedValue: NestedValue(string: "foo")), optionalValue: nil)
            try assert(value, isEncodedIn: ["value": "foo", "optionalValue": nil])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM t1")!
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
        
        struct Struct : MutablePersistableRecord, Encodable {
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
            try assert(value, isEncodedIn: ["value": "foo", "optionalValue": "bar"])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo", "optionalValue": "bar"])
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: .foo, optionalValue: nil)
            try assert(value, isEncodedIn: ["value": "foo", "optionalValue": nil])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM t1")!
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
                (string + " (DatabaseValueConvertible)").databaseValue
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                fatalError("irrelevant")
            }
        }
        
        struct Struct : MutablePersistableRecord, Encodable {
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
            try assert(value, isEncodedIn: ["value": "foo (DatabaseValueConvertible)", "optionalValue": "bar (DatabaseValueConvertible)"])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo (DatabaseValueConvertible)", "optionalValue": "bar (DatabaseValueConvertible)"])
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            var value = Struct(value: Value(string: "foo"), optionalValue: nil)
            try assert(value, isEncodedIn: ["value": "foo (DatabaseValueConvertible)", "optionalValue": nil])
            
            try value.insert(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM t1")!
            XCTAssertEqual(row, ["value": "foo (DatabaseValueConvertible)", "optionalValue": nil])
            return .rollback
        }
    }
}

// MARK: - Foundation Codable Types

extension MutablePersistableRecordEncodableTests {
    
    func testStructWithDate() throws {
        struct StructWithDate : PersistableRecord, Encodable {
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
            
            let dbValue = try DatabaseValue.fetchOne(db, sql: "SELECT date FROM t1")!
            
            // Date has a default Encodable implementation which encodes a Double.
            // We expect here a String, because DatabaseValueConvertible has
            // precedence over Encodable.
            XCTAssert(dbValue.storage.value is String)
            
            let fetchedDate = Date.fromDatabaseValue(dbValue)!
            XCTAssert(abs(fetchedDate.timeIntervalSince(value.date)) < 0.001)
        }
    }
    
    func testStructWithURL() throws {
        struct StructWithURL : PersistableRecord, Encodable {
            static let databaseTableName = "t1"
            let url: URL
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("url", .text)
            }
            
            let value = StructWithURL(url: URL(string: "https://github.com")!)
            try assert(value, isEncodedIn: ["url": value.url])
            
            try value.insert(db)
            let dbValue = try DatabaseValue.fetchOne(db, sql: "SELECT url FROM t1")!
            XCTAssert(dbValue.storage.value is String)
            let fetchedURL = URL.fromDatabaseValue(dbValue)!
            XCTAssertEqual(fetchedURL, value.url)
        }
    }
    
    func testStructWithUUID() throws {
        struct StructWithUUID : PersistableRecord, Encodable {
            static let databaseTableName = "t1"
            let uuid: UUID
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("uuid", .blob)
            }
            
            let value = StructWithUUID(uuid: UUID())
            try assert(value, isEncodedIn: ["uuid": value.uuid])
            
            try value.insert(db)
            let dbValue = try DatabaseValue.fetchOne(db, sql: "SELECT uuid FROM t1")!
            XCTAssert(dbValue.storage.value is Data)
            let fetchedUUID = UUID.fromDatabaseValue(dbValue)!
            XCTAssertEqual(fetchedUUID, value.uuid)
        }
    }
    
    func testArrayJSONEncoding() throws {
        struct Record: PersistableRecord, Encodable {
            let array: [String]
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "record") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("array", .text)
            }
            
            try Record(array: []).insert(db)
            try Record(array: ["foo"]).insert(db)
            try Record(array: ["foo", "bar"]).insert(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM record ORDER BY id")
            XCTAssertEqual(rows.count, 3)
            XCTAssertEqual(rows[0]["array"], "[]")
            XCTAssertEqual(rows[1]["array"], "[\"foo\"]")
            XCTAssertEqual(rows[2]["array"], "[\"foo\",\"bar\"]")
        }
    }
    
    func testOptionalArrayJSONEncoding() throws {
        struct Record: PersistableRecord, Encodable {
            let array: [String]?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "record") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("array", .text)
            }
            
            try Record(array: nil).insert(db)
            try Record(array: []).insert(db)
            try Record(array: ["foo"]).insert(db)
            try Record(array: ["foo", "bar"]).insert(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM record ORDER BY id")
            XCTAssertEqual(rows.count, 4)
            XCTAssertTrue(rows[0]["array"] == nil)
            XCTAssertEqual(rows[1]["array"], "[]")
            XCTAssertEqual(rows[2]["array"], "[\"foo\"]")
            XCTAssertEqual(rows[3]["array"], "[\"foo\",\"bar\"]")
        }
    }

    func testDictionaryJSONEncoding() throws {
        struct Record: PersistableRecord, Encodable {
            let dictionary: [String: Int]
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "record") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("dictionary", .text)
            }
            
            try Record(dictionary: [:]).insert(db)
            try Record(dictionary: ["foo": 1]).insert(db)

            let rows = try Row.fetchAll(db, sql: "SELECT * FROM record ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["dictionary"], "{}")
            XCTAssertEqual(rows[1]["dictionary"], "{\"foo\":1}")
        }
    }
    
    func testOptionalDictionaryJSONEncoding() throws {
        struct Record: PersistableRecord, Encodable {
            let dictionary: [String: Int]?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "record") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("dictionary", .text)
            }
            
            try Record(dictionary: nil).insert(db)
            try Record(dictionary: [:]).insert(db)
            try Record(dictionary: ["foo": 1]).insert(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM record ORDER BY id")
            XCTAssertEqual(rows.count, 3)
            XCTAssertTrue(rows[0]["dictionary"] == nil)
            XCTAssertEqual(rows[1]["dictionary"], "{}")
            XCTAssertEqual(rows[2]["dictionary"], "{\"foo\":1}")
        }
    }

    func testJSONDataEncodingStrategy() throws {
        struct Record: PersistableRecord, Encodable {
            let data: Data
            let optionalData: Data?
            let datas: [Data]
            let optionalDatas: [Data?]
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "record") { t in
                t.column("data", .text)
                t.column("optionalData", .text)
                t.column("datas", .text)
                t.column("optionalDatas", .text)
            }
            
            let data = "foo".data(using: .utf8)!
            let record = Record(data: data, optionalData: data, datas: [data], optionalDatas: [nil, data])
            try record.insert(db)
            
            let row = try Row.fetchOne(db, Record.all())!
            XCTAssertEqual(row["data"], data)
            XCTAssertEqual(row["optionalData"], data)
            XCTAssertEqual(row["datas"], "[\"Zm9v\"]")
            XCTAssertEqual(row["optionalDatas"], "[null,\"Zm9v\"]")
        }
    }

    func testJSONDateEncodingStrategy() throws {
        struct Record: PersistableRecord, Encodable {
            let date: Date
            let optionalDate: Date?
            let dates: [Date]
            let optionalDates: [Date?]
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "record") { t in
                t.column("date", .text)
                t.column("optionalDate", .text)
                t.column("dates", .text)
                t.column("optionalDates", .text)
            }
            
            let date = Date(timeIntervalSince1970: 128)
            let record = Record(date: date, optionalDate: date, dates: [date], optionalDates: [nil, date])
            try record.insert(db)
            
            let row = try Row.fetchOne(db, Record.all())!
            XCTAssertEqual(row["date"], "1970-01-01 00:02:08.000")
            XCTAssertEqual(row["optionalDate"], "1970-01-01 00:02:08.000")
            XCTAssertEqual(row["dates"], "[128000]")
            XCTAssertEqual(row["optionalDates"], "[null,128000]")
        }
    }
}

// MARK: - User Infos & Coding Keys

private let testKeyRoot = CodingUserInfoKey(rawValue: "test1")!
private let testKeyNested = CodingUserInfoKey(rawValue: "test2")!

extension MutablePersistableRecordEncodableTests {
    struct NestedKeyed: Encodable {
        var name: String
        
        enum CodingKeys: String, CodingKey { case name, key, context }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(encoder.codingPath.last?.stringValue, forKey: .key)
            try container.encodeIfPresent(encoder.userInfo[testKeyNested] as? String, forKey: .context)
        }
    }
    
    struct NestedSingle: Encodable {
        var name: String
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            var value = name
            value += ",key:\(encoder.codingPath.last?.stringValue ?? "nil")"
            value += ",context:\(encoder.userInfo[testKeyNested] as? String ?? "nil")"
            try container.encode(value)
        }
    }
    
    struct NestedUnkeyed: Encodable {
        var name: String
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(name)
            if let key = encoder.codingPath.last?.stringValue {
                try container.encode(key)
            } else {
                try container.encodeNil()
            }
            if let context = encoder.userInfo[testKeyNested] as? String {
                try container.encode(context)
            } else {
                try container.encodeNil()
            }
        }
    }
    
    struct Record: Encodable, MutablePersistableRecord {
        var nestedKeyed: NestedKeyed
        var nestedSingle: NestedSingle
        var nestedUnkeyed: NestedUnkeyed
        
        init(nestedKeyed: NestedKeyed, nestedSingle: NestedSingle, nestedUnkeyed: NestedUnkeyed) {
            self.nestedKeyed = nestedKeyed
            self.nestedSingle = nestedSingle
            self.nestedUnkeyed = nestedUnkeyed
        }
        
        enum CodingKeys: String, CodingKey {
            case nestedKeyed, nestedSingle, nestedUnkeyed, key, context
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(nestedKeyed, forKey: .nestedKeyed)
            try container.encode(nestedSingle, forKey: .nestedSingle)
            try container.encode(nestedUnkeyed, forKey: .nestedUnkeyed)
            try container.encodeIfPresent(encoder.codingPath.last?.stringValue, forKey: .key)
            try container.encodeIfPresent(encoder.userInfo[testKeyRoot] as? String, forKey: .context)
        }
    }
    
    struct CustomizedRecord: Encodable, MutablePersistableRecord {
        var nestedKeyed: NestedKeyed
        var nestedSingle: NestedSingle
        var nestedUnkeyed: NestedUnkeyed
        
        init(nestedKeyed: NestedKeyed, nestedSingle: NestedSingle, nestedUnkeyed: NestedUnkeyed) {
            self.nestedKeyed = nestedKeyed
            self.nestedSingle = nestedSingle
            self.nestedUnkeyed = nestedUnkeyed
        }
        
        enum CodingKeys: String, CodingKey {
            case nestedKeyed, nestedSingle, nestedUnkeyed, key, context
        }
        
        static let databaseEncodingUserInfo: [CodingUserInfoKey: Any] = [
            testKeyRoot: "GRDB root",
            testKeyNested: "GRDB nested"]
        
        static func databaseJSONEncoder(for column: String) -> JSONEncoder {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            encoder.userInfo = [
                testKeyRoot: "JSON root",
                testKeyNested: "JSON nested: \(column)"]
            return encoder
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(nestedKeyed, forKey: .nestedKeyed)
            try container.encode(nestedSingle, forKey: .nestedSingle)
            try container.encode(nestedUnkeyed, forKey: .nestedUnkeyed)
            try container.encodeIfPresent(encoder.codingPath.last?.stringValue, forKey: .key)
            try container.encodeIfPresent(encoder.userInfo[testKeyRoot] as? String, forKey: .context)
        }
    }
    
    // Used as a reference
    func testFoundationBehavior() throws {
        do {
            let record = Record(
                nestedKeyed: NestedKeyed(name: "foo"),
                nestedSingle: NestedSingle(name: "bar"),
                nestedUnkeyed: NestedUnkeyed(name: "baz"))
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            let json = try String(data: encoder.encode(record), encoding: .utf8)!
            XCTAssertEqual(json, """
                {
                  "nestedKeyed" : {
                    "key" : "nestedKeyed",
                    "name" : "foo"
                  },
                  "nestedSingle" : "bar,key:nestedSingle,context:nil",
                  "nestedUnkeyed" : [
                    "baz",
                    "nestedUnkeyed",
                    null
                  ]
                }
                """)
        }
        
        do {
            let record = Record(
                nestedKeyed: NestedKeyed(name: "foo"),
                nestedSingle: NestedSingle(name: "bar"),
                nestedUnkeyed: NestedUnkeyed(name: "baz"))
            
            let encoder = JSONEncoder()
            encoder.userInfo = [testKeyRoot: "root", testKeyNested: "nested"]
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            let json = try String(data: encoder.encode(record), encoding: .utf8)
            XCTAssertEqual(json, """
                {
                  "context" : "root",
                  "nestedKeyed" : {
                    "context" : "nested",
                    "key" : "nestedKeyed",
                    "name" : "foo"
                  },
                  "nestedSingle" : "bar,key:nestedSingle,context:nested",
                  "nestedUnkeyed" : [
                    "baz",
                    "nestedUnkeyed",
                    "nested"
                  ]
                }
                """)
        }
    }
    
    func testRecord() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "record") { t in
                t.column("context")
                t.column("key")
                t.column("nestedKeyed")
                t.column("nestedSingle")
                t.column("nestedUnkeyed")
            }
            
            var record = Record(
                nestedKeyed: NestedKeyed(name: "foo"),
                nestedSingle: NestedSingle(name: "bar"),
                nestedUnkeyed: NestedUnkeyed(name: "baz"))
            try record.insert(db)
            
            let row = try Row.fetchOne(db, Record.all())!
            XCTAssertEqual(row, [
                "context": nil,
                "key": nil,
                "nestedKeyed": "{\"name\":\"foo\"}",
                "nestedSingle": "bar,key:nestedSingle,context:nil",
                "nestedUnkeyed": "[\"baz\",null,null]"])
        }
    }
    
    func testCustomizedRecord() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "customizedRecord") { t in
                t.column("context")
                t.column("key")
                t.column("nestedKeyed")
                t.column("nestedSingle")
                t.column("nestedUnkeyed")
            }
            
            var record = CustomizedRecord(
                nestedKeyed: NestedKeyed(name: "foo"),
                nestedSingle: NestedSingle(name: "bar"),
                nestedUnkeyed: NestedUnkeyed(name: "baz"))
            try record.insert(db)
            
            let row = try Row.fetchOne(db, CustomizedRecord.all())!
            XCTAssertEqual(row, [
                "context": "GRDB root",
                "key": nil,
                "nestedKeyed": "{\"context\":\"JSON nested: nestedKeyed\",\"name\":\"foo\"}",
                "nestedSingle": "bar,key:nestedSingle,context:GRDB nested",
                "nestedUnkeyed": "[\"baz\",null,\"JSON nested: nestedUnkeyed\"]"])
        }
    }

    func testUserInfoJsonEncoding() throws {
        struct NestedStruct : Codable {
            let firstName: String?
            let lastName: String?

            init(firstName: String?, lastName: String?) {
                self.firstName = firstName
                self.lastName = lastName
            }

            func encode(to encoder: Encoder) throws {
                let userInfoValue = encoder.userInfo[.testKey] as? String
                var container = encoder.container(keyedBy: CodingKeys.self)

                if userInfoValue == "correct" {
                    try container.encode(firstName, forKey: .firstName)
                    try container.encode(lastName, forKey: .lastName)
                } else {
                    try container.encode(firstName, forKey: .lastName)
                    try container.encode(lastName, forKey: .firstName)
                }
            }
        }

        struct StructWithNestedType : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            static var databaseEncodingUserInfo: [CodingUserInfoKey: Any] = [CodingUserInfoKey.testKey: "correct"]
            let nested: NestedStruct?
        }

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }
            let nested = NestedStruct(firstName: "Bob", lastName: "Dylan")
            let value = StructWithNestedType(nested: nested)
            try value.insert(db)

            let parentModel = try StructWithNestedType.fetchAll(db)

            guard let nestedModel = parentModel.first?.nested else {
                XCTFail()
                return
            }

            // Check the nested model contains the expected values of first and last name
            XCTAssertEqual(nestedModel.firstName, "Bob")
            XCTAssertEqual(nestedModel.lastName, "Dylan")
        }
    }
}

fileprivate extension CodingUserInfoKey {
    static let testKey = CodingUserInfoKey(rawValue: "correct")!
}
