import Foundation
import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class FetchableRecordDecodableTests: GRDBTestCase { }

// MARK: - FetchableRecord conformance derived from Decodable

extension FetchableRecordDecodableTests {
    
    func testTrivialDecodable() {
        struct Struct : FetchableRecord, Decodable {
            let value: String
        }
        
        do {
            let s = Struct(row: ["value": "foo"])
            XCTAssertEqual(s.value, "foo")
        }
    }
    
    func testCustomDecodable() {
        struct Struct : FetchableRecord, Decodable {
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
    
    func testCustomFetchableRecord() {
        struct Struct : FetchableRecord, Decodable {
            let value: String
            
            init(row: Row) {
                value = (row["value"] as String) + " (FetchableRecord)"
            }
        }
        
        do {
            let s = Struct(row: ["value": "foo"])
            XCTAssertEqual(s.value, "foo (FetchableRecord)")
        }
    }
}

// MARK: - Different kinds of single-value properties

extension FetchableRecordDecodableTests {
    
    func testTrivialProperty() {
        struct Struct : FetchableRecord, Decodable {
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
        
        struct Struct : FetchableRecord, Decodable {
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
        
        struct Struct : FetchableRecord, Decodable {
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
        
        struct Struct : FetchableRecord, Decodable {
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
        
        struct Struct : FetchableRecord, Decodable {
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

extension FetchableRecordDecodableTests {

    func testStructWithDate() {
        struct StructWithDate : FetchableRecord, Decodable {
            let date: Date
        }
        
        let date = Date()
        let value = StructWithDate(row: ["date": date])
        XCTAssert(abs(value.date.timeIntervalSince(date)) < 0.001)
    }
    
    func testStructWithURL() {
        struct StructWithURL : FetchableRecord, Decodable {
            let url: URL
        }
        
        let url = URL(string: "https://github.com")
        let value = StructWithURL(row: ["url": url])
        XCTAssertEqual(value.url, url)
    }
    
    func testStructWithUUID() {
        struct StructWithUUID : FetchableRecord, Decodable {
            let uuid: UUID
        }
        
        let uuid = UUID()
        let value = StructWithUUID(row: ["uuid": uuid])
        XCTAssertEqual(value.uuid, uuid)
    }
}

// MARK: - Custom nested Decodable types - nested saved as JSON

extension FetchableRecordDecodableTests {
    func testOptionalNestedStruct() throws {
        struct NestedStruct : Codable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
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
    
    func testOptionalNestedStructNil() throws {
        struct NestedStruct : Codable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let nested: NestedStruct?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }
            
            let value = StructWithNestedType(nested: nil)
            try value.insert(db)
            
            let parentModel = try StructWithNestedType.fetchAll(db)
            
            XCTAssertNil(parentModel.first?.nested)
        }
    }
    
    func testOptionalNestedArrayStruct() throws {
        struct NestedStruct : Codable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let nested: [NestedStruct]?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }

            let nested = NestedStruct(firstName: "Bob", lastName: "Dylan")
            let value = StructWithNestedType(nested: [nested, nested])
            try value.insert(db)
            
            let parentModel = try StructWithNestedType.fetchAll(db)
            
            guard let arrayOfNestedModel = parentModel.first?.nested, let firstNestedModelInArray = arrayOfNestedModel.first else {
                XCTFail()
                return
            }
            
            // Check there are two models in array
            XCTAssertTrue(arrayOfNestedModel.count == 2)
            
            // Check the nested model contains the expected values of first and last name
            XCTAssertEqual(firstNestedModelInArray.firstName, "Bob")
            XCTAssertEqual(firstNestedModelInArray.lastName, "Dylan")
        }
    }
    
    func testOptionalNestedArrayStructNil() throws {
        struct NestedStruct: Codable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let nested: [NestedStruct]?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }
            
            let value = StructWithNestedType(nested: nil)
            try value.insert(db)
            
            let parentModel = try StructWithNestedType.fetchAll(db)
            
            XCTAssertNil(parentModel.first?.nested)
        }
    }
    
    func testNonOptionalNestedStruct() throws {
        struct NestedStruct: Codable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let nested: NestedStruct
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
    
    func testNonOptionalNestedArrayStruct() throws {
        struct NestedStruct : Codable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let nested: [NestedStruct]
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }
        }
        
        try dbQueue.inTransaction { db in
            let value = StructWithNestedType(nested: [
                NestedStruct(firstName: "Bob", lastName: "Dylan"),
                NestedStruct(firstName: "Bob", lastName: "Dylan")])
            try value.insert(db)
            
            let parentModel = try StructWithNestedType.fetchOne(db)
            
            guard let nested = parentModel?.nested else {
                XCTFail()
                return .rollback
            }
            
            // Check there are two models in array
            XCTAssertEqual(nested.count, 2)
            
            // Check the nested model contains the expected values of first and last name
            XCTAssertEqual(nested[0].firstName, "Bob")
            XCTAssertEqual(nested[0].lastName, "Dylan")
            
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            let value = StructWithNestedType(nested: [])
            try value.insert(db)
            
            let parentModel = try StructWithNestedType.fetchOne(db)
            
            guard let nested = parentModel?.nested else {
                XCTFail()
                return .rollback
            }
            
            XCTAssertTrue(nested.isEmpty)
            return .rollback
        }
    }

    func testCodableExampleCode() throws {
        struct Player: PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let name: String
            let score: Int
            let scores: [Int]
            let lastMedal: PlayerMedal
            let medals: [PlayerMedal]
            let timeline: [String: PlayerMedal]
        }

        // A simple Codable that will be nested in a parent Codable
        struct PlayerMedal : Codable {
            let name: String?
            let type: String?
        }

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("name", .text)
                t.column("score", .integer)
                t.column("scores", .integer)
                t.column("lastMedal", .text)
                t.column("medals", .text)
                t.column("timeline", .text)
            }

            let medal1 = PlayerMedal(name: "First", type: "Gold")
            let medal2 = PlayerMedal(name: "Second", type: "Silver")
            let timeline = ["Local Contest": medal1, "National Contest": medal2]
            let value = Player(name: "PlayerName", score: 10, scores: [1,2,3,4,5], lastMedal: medal1, medals: [medal1, medal2], timeline: timeline)
            try value.insert(db)

            let parentModel = try Player.fetchAll(db)

            guard let first = parentModel.first, let firstNestedModelInArray = first.medals.first,  let secondNestedModelInArray = first.medals.last else {
                XCTFail()
                return
            }

            // Check there are two models in array
            XCTAssertTrue(first.medals.count == 2)

            // Check the nested model contains the expected values of first and last name
            XCTAssertEqual(firstNestedModelInArray.name, "First")
            XCTAssertEqual(secondNestedModelInArray.name, "Second")

            XCTAssertEqual(first.name, "PlayerName")
            XCTAssertEqual(first.score, 10)
            XCTAssertEqual(first.scores, [1,2,3,4,5])
            XCTAssertEqual(first.lastMedal.name, medal1.name)
            XCTAssertEqual(first.timeline["Local Contest"]?.name, medal1.name)
            XCTAssertEqual(first.timeline["National Contest"]?.name, medal2.name)
        }

    }
    
    // MARK: - JSON data in Detached Rows
    
    func testDetachedRows() throws {
        struct NestedStruct : PersistableRecord, FetchableRecord, Codable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let nested: NestedStruct
        }
        
        let row: Row = ["nested": """
            {"firstName":"Bob","lastName":"Dylan"}
            """]
        
        let model = StructWithNestedType(row: row)
        XCTAssertEqual(model.nested.firstName, "Bob")
        XCTAssertEqual(model.nested.lastName, "Dylan")
    }
    
    func testArrayOfDetachedRowsAsData() throws {
        struct TestStruct : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let name: String
        }
        
        let jsonAsString = "{\"firstName\":\"Bob\",\"lastName\":\"Marley\"}"
        let jsonAsData = jsonAsString.data(using: .utf8)
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("name", .text)
            }
            
            let model = TestStruct(name: jsonAsString)
            try model.insert(db)
        }
        
        try dbQueue.read { db in
            
            // ... with an array of detached rows:
            let array = try Row.fetchAll(db, sql: "SELECT * FROM t1")
            for row in array {
                let data1: Data? = row["name"]
                XCTAssertEqual(jsonAsData, data1)
                let data = row.dataNoCopy(named: "name")
                XCTAssertEqual(jsonAsData, data)
            }
        }
    }
    
    func testArrayOfDetachedRowsAsString() throws {
        struct TestStruct : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let name: String
        }
        
        let jsonAsString = "{\"firstName\":\"Bob\",\"lastName\":\"Marley\"}"
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("name", .text)
            }
            
            let model = TestStruct(name: jsonAsString)
            try model.insert(db)
        }
        
        try dbQueue.read { db in
            
            // ... with an array of detached rows:
            let array = try Row.fetchAll(db, sql: "SELECT * FROM t1")
            for row in array {
                let string: String? = row["name"]
                XCTAssertEqual(jsonAsString, string)
            }
        }
    }
    
    func testCursorRowsAsData() throws {
        struct TestStruct : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let name: String
        }
        
        let jsonAsString = "{\"firstName\":\"Bob\",\"lastName\":\"Marley\"}"
        let jsonAsData = jsonAsString.data(using: .utf8)
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("name", .text)
            }
            
            let model = TestStruct(name: jsonAsString)
            try model.insert(db)
        }
        
        try dbQueue.read { db in
            // Compare cursor of low-level rows:
            let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM t1")
            while let row = try cursor.next() {
                let data1: Data? = row["name"]
                XCTAssertEqual(jsonAsData, data1)
                let data = row.dataNoCopy(named: "name")
                XCTAssertEqual(jsonAsData, data)
            }
        }
    }
    
    func testCursorRowsAsString() throws {
        struct TestStruct : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let name: String
        }
        
        let jsonAsString = "{\"firstName\":\"Bob\",\"lastName\":\"Marley\"}"
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("name", .text)
            }
            
            let model = TestStruct(name: jsonAsString)
            try model.insert(db)
        }
        
        try dbQueue.read { db in
            // Compare cursor of low-level rows:
            let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM t1")
            while let row = try cursor.next() {
                let string: String? = row["name"]
                XCTAssertEqual(jsonAsString, string)
            }
        }
    }
    
    func testJSONDataEncodingStrategy() throws {
        struct Record: FetchableRecord, Decodable {
            let data: Data
            let optionalData: Data?
            let datas: [Data]
            let optionalDatas: [Data?]
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let data = "foo".data(using: .utf8)!
            let record = try Record.fetchOne(db, sql: "SELECT ? AS data, ? AS optionalData, ? AS datas, ? AS optionalDatas", arguments: [
                data,
                data,
                "[\"Zm9v\"]",
                "[null, \"Zm9v\"]"
            ])!
            XCTAssertEqual(record.data, data)
            XCTAssertEqual(record.optionalData!, data)
            XCTAssertEqual(record.datas.count, 1)
            XCTAssertEqual(record.datas[0], data)
            XCTAssertEqual(record.optionalDatas.count, 2)
            XCTAssertNil(record.optionalDatas[0])
            XCTAssertEqual(record.optionalDatas[1]!, data)
        }
    }
    
    func testJSONDateEncodingStrategy() throws {
        struct Record: FetchableRecord, Decodable {
            let date: Date
            let optionalDate: Date?
            let dates: [Date]
            let optionalDates: [Date?]
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = try Record.fetchOne(db, sql: "SELECT ? AS date, ? AS optionalDate, ? AS dates, ? AS optionalDates", arguments: [
                "1970-01-01 00:02:08.000",
                "1970-01-01 00:02:08.000",
                "[128000]",
                "[null,128000]"
                ])!
            XCTAssertEqual(record.date.timeIntervalSince1970, 128)
            XCTAssertEqual(record.optionalDate!.timeIntervalSince1970, 128)
            XCTAssertEqual(record.dates.count, 1)
            XCTAssertEqual(record.dates[0].timeIntervalSince1970, 128)
            XCTAssertEqual(record.optionalDates.count, 2)
            XCTAssertNil(record.optionalDates[0])
            XCTAssertEqual(record.optionalDates[1]!.timeIntervalSince1970, 128)
        }
    }
}

// MARK: - User Infos & Coding Keys

private let testKeyRoot = CodingUserInfoKey(rawValue: "test1")!
private let testKeyNested = CodingUserInfoKey(rawValue: "test2")!

extension FetchableRecordDecodableTests {
    struct NestedKeyed: Decodable {
        var name: String
        var key: String?
        var context: String?
        
        enum CodingKeys: String, CodingKey { case name }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            key = decoder.codingPath.last?.stringValue
            context = decoder.userInfo[testKeyNested] as? String
        }
    }
    
    struct NestedSingle: Decodable {
        var name: String
        var key: String?
        var context: String?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            name = try container.decode(String.self)
            key = decoder.codingPath.last?.stringValue
            context = decoder.userInfo[testKeyNested] as? String
        }
    }
    
    struct NestedUnkeyed: Decodable {
        var name: String
        var key: String?
        var context: String?
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            name = try container.decode(String.self)
            key = decoder.codingPath.last?.stringValue
            context = decoder.userInfo[testKeyNested] as? String
        }
    }
    
    struct Record: Decodable, FetchableRecord {
        var nestedKeyed: NestedKeyed
        var nestedSingle: NestedSingle
        var nestedUnkeyed: NestedUnkeyed
        var key: String?
        var context: String?
        
        enum CodingKeys: String, CodingKey {
            case nestedKeyed, nestedSingle, nestedUnkeyed
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            nestedKeyed = try container.decode(NestedKeyed.self, forKey: .nestedKeyed)
            nestedSingle = try container.decode(NestedSingle.self, forKey: .nestedSingle)
            nestedUnkeyed = try container.decode(NestedUnkeyed.self, forKey: .nestedUnkeyed)
            key = decoder.codingPath.last?.stringValue
            context = decoder.userInfo[testKeyRoot] as? String
        }
    }
    
    class CustomizedRecord: Decodable, FetchableRecord {
        var nestedKeyed: NestedKeyed
        var nestedSingle: NestedSingle
        var nestedUnkeyed: NestedUnkeyed
        var key: String?
        var context: String?
        
        enum CodingKeys: String, CodingKey {
            case nestedKeyed, nestedSingle, nestedUnkeyed
        }
        
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            nestedKeyed = try container.decode(NestedKeyed.self, forKey: .nestedKeyed)
            nestedSingle = try container.decode(NestedSingle.self, forKey: .nestedSingle)
            nestedUnkeyed = try container.decode(NestedUnkeyed.self, forKey: .nestedUnkeyed)
            key = decoder.codingPath.last?.stringValue
            context = decoder.userInfo[testKeyRoot] as? String
        }

        static let databaseDecodingUserInfo: [CodingUserInfoKey: Any] = [
            testKeyRoot: "GRDB root",
            testKeyNested: "GRDB column or scope"]
        
        static func databaseJSONDecoder(for column: String) -> JSONDecoder {
            let decoder = JSONDecoder()
            decoder.userInfo = [
                testKeyRoot: "JSON root",
                testKeyNested: "JSON column: \(column)"]
            return decoder
        }
    }
    
    // Used as a reference
    func testFoundationBehavior() throws {
        let json = """
            {
              "nestedKeyed": { "name": "foo" },
              "nestedSingle": "bar",
              "nestedUnkeyed": ["baz"]
            }
            """.data(using: .utf8)!
        
        do {
            let decoder = JSONDecoder()
            let record = try decoder.decode(Record.self, from: json)
            XCTAssertNil(record.key)
            XCTAssertNil(record.context)
            XCTAssertEqual(record.nestedKeyed.name, "foo")
            XCTAssertEqual(record.nestedKeyed.key, "nestedKeyed")
            XCTAssertNil(record.nestedKeyed.context)
            XCTAssertEqual(record.nestedSingle.name, "bar")
            XCTAssertEqual(record.nestedSingle.key, "nestedSingle")
            XCTAssertNil(record.nestedSingle.context)
            XCTAssertEqual(record.nestedUnkeyed.name, "baz")
            XCTAssertEqual(record.nestedUnkeyed.key, "nestedUnkeyed")
            XCTAssertNil(record.nestedUnkeyed.context)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.userInfo = [testKeyRoot: "root", testKeyNested: "nested"]
            let record = try decoder.decode(Record.self, from: json)
            XCTAssertNil(record.key)
            XCTAssertEqual(record.context, "root")
            XCTAssertEqual(record.nestedKeyed.name, "foo")
            XCTAssertEqual(record.nestedKeyed.key, "nestedKeyed")
            XCTAssertEqual(record.nestedKeyed.context, "nested")
            XCTAssertEqual(record.nestedSingle.name, "bar")
            XCTAssertEqual(record.nestedSingle.key, "nestedSingle")
            XCTAssertEqual(record.nestedSingle.context, "nested")
            XCTAssertEqual(record.nestedUnkeyed.name, "baz")
            XCTAssertEqual(record.nestedUnkeyed.key, "nestedUnkeyed")
            XCTAssertEqual(record.nestedUnkeyed.context, "nested")
        }
    }
    
    func testRecord1() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            func test(_ record: Record) {
                XCTAssertNil(record.key)
                XCTAssertNil(record.context)
                
                // scope
                XCTAssertEqual(record.nestedKeyed.name, "foo")
                XCTAssertEqual(record.nestedKeyed.key, "nestedKeyed")
                XCTAssertNil(record.nestedKeyed.context)
                
                // column
                XCTAssertEqual(record.nestedSingle.name, "bar")
                XCTAssertEqual(record.nestedSingle.key, "nestedSingle")
                XCTAssertNil(record.nestedSingle.context)
                
                // JSON column
                XCTAssertEqual(record.nestedUnkeyed.name, "baz")
                XCTAssertNil(record.nestedUnkeyed.key)
                XCTAssertNil(record.nestedUnkeyed.context)
            }
            
            let adapter = SuffixRowAdapter(fromIndex: 1).addingScopes(["nestedKeyed": RangeRowAdapter(0..<1)])
            let request = SQLRequest<Void>(
                sql: "SELECT ? AS name, ? AS nestedSingle, ? AS nestedUnkeyed",
                arguments: ["foo", "bar", "[\"baz\"]"],
                adapter: adapter)
            
            let record = try Record.fetchOne(db, request)!
            test(record)
            
            let row = try Row.fetchOne(db, request)!
            test(Record(row: row))
        }
    }
    
    func testRecord2() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            func test(_ record: Record) {
                XCTAssertNil(record.key)
                XCTAssertNil(record.context)
                
                // JSON column
                XCTAssertEqual(record.nestedKeyed.name, "foo")
                XCTAssertNil(record.nestedKeyed.key)
                XCTAssertNil(record.nestedKeyed.context)
                
                // column
                XCTAssertEqual(record.nestedSingle.name, "bar")
                XCTAssertEqual(record.nestedSingle.key, "nestedSingle")
                XCTAssertNil(record.nestedSingle.context)
                
                // JSON column
                XCTAssertEqual(record.nestedUnkeyed.name, "baz")
                XCTAssertNil(record.nestedUnkeyed.key)
                XCTAssertNil(record.nestedUnkeyed.context)
            }
            
            let request = SQLRequest<Void>(
                sql: "SELECT ? AS nestedKeyed, ? AS nestedSingle, ? AS nestedUnkeyed",
                arguments: ["{\"name\":\"foo\"}", "bar", "[\"baz\"]"])
            
            let record = try Record.fetchOne(db, request)!
            test(record)
            
            let row = try Row.fetchOne(db, request)!
            test(Record(row: row))
        }
    }
    
    func testCustomizedRecord1() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            func test(_ record: CustomizedRecord) {
                XCTAssertNil(record.key)
                XCTAssertEqual(record.context, "GRDB root")
                
                // scope
                XCTAssertEqual(record.nestedKeyed.name, "foo")
                XCTAssertEqual(record.nestedKeyed.key, "nestedKeyed")
                XCTAssertEqual(record.nestedKeyed.context, "GRDB column or scope")
                
                // column
                XCTAssertEqual(record.nestedSingle.name, "bar")
                XCTAssertEqual(record.nestedSingle.key, "nestedSingle")
                XCTAssertEqual(record.nestedSingle.context, "GRDB column or scope")
                
                // JSON column
                XCTAssertEqual(record.nestedUnkeyed.name, "baz")
                XCTAssertNil(record.nestedUnkeyed.key)
                XCTAssertEqual(record.nestedUnkeyed.context, "JSON column: nestedUnkeyed")
            }
            
            let adapter = SuffixRowAdapter(fromIndex: 1).addingScopes(["nestedKeyed": RangeRowAdapter(0..<1)])
            let request = SQLRequest<Void>(
                sql: "SELECT ? AS name, ? AS nestedSingle, ? AS nestedUnkeyed",
                arguments: ["foo", "bar", "[\"baz\"]"],
                adapter: adapter)
            
            let record = try CustomizedRecord.fetchOne(db, request)!
            test(record)
            
            let row = try Row.fetchOne(db, request)!
            test(CustomizedRecord(row: row))
        }
    }
    
    func testCustomizedRecord2() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            func test(_ record: CustomizedRecord) {
                XCTAssertNil(record.key)
                XCTAssertEqual(record.context, "GRDB root")
                
                // JSON column
                XCTAssertEqual(record.nestedKeyed.name, "foo")
                XCTAssertNil(record.nestedKeyed.key)
                XCTAssertEqual(record.nestedKeyed.context, "JSON column: nestedKeyed")
                
                // column
                XCTAssertEqual(record.nestedSingle.name, "bar")
                XCTAssertEqual(record.nestedSingle.key, "nestedSingle")
                XCTAssertEqual(record.nestedSingle.context, "GRDB column or scope")

                // JSON column
                XCTAssertEqual(record.nestedUnkeyed.name, "baz")
                XCTAssertNil(record.nestedUnkeyed.key)
                XCTAssertEqual(record.nestedUnkeyed.context, "JSON column: nestedUnkeyed")
            }
            
            let request = SQLRequest<Void>(
                sql: "SELECT ? AS nestedKeyed, ? AS nestedSingle, ? AS nestedUnkeyed",
                arguments: ["{\"name\":\"foo\"}", "bar", "[\"baz\"]"])
            
            let record = try CustomizedRecord.fetchOne(db, request)!
            test(record)
            
            let row = try Row.fetchOne(db, request)!
            test(CustomizedRecord(row: row))
        }
    }
    
    // MARK: - Ill-defined records
    
    // This is a regression test for https://github.com/groue/GRDB.swift/issues/664
    func testIllDecoding() throws {
        struct Left: Decodable { }
        struct Right: Decodable { }
        struct Composed: Decodable, FetchableRecord {
            var left: Left
            var right: Right
        }
        let decoder = RowDecoder()
        do {
            _ = try decoder.decode(Composed.self, from: [:])
            XCTFail("Expected error")
        } catch let DecodingError.keyNotFound(key, context) {
            XCTAssertEqual(key.stringValue, "left")
            XCTAssertEqual(context.debugDescription, "No such key: left")
        }
    }
    
    // This is a regression test for https://github.com/groue/GRDB.swift/issues/664
    // TODO: make this test pass
//    func testIllDecoding2() throws {
//        struct Left: Decodable { }
//        struct Right: Decodable { }
//        struct Composed: Decodable, FetchableRecord {
//            var left: Left
//            var right: Right?
//        }
//        let decoder = RowDecoder()
//        do {
//            _ = try decoder.decode(Composed.self, from: [:])
//            XCTFail("Expected error")
//        } catch let DecodingError.keyNotFound(key, context) {
//            XCTAssertEqual(key.stringValue, "left")
//            XCTAssertEqual(context.debugDescription, "No such key: left")
//        }
//    }
}
