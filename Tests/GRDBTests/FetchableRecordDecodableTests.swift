import Foundation
import XCTest
@testable import GRDB

class FetchableRecordDecodableTests: GRDBTestCase { }

// MARK: - FetchableRecord conformance derived from Decodable

extension FetchableRecordDecodableTests {
    
    func testTrivialDecodable() throws {
        struct Struct : FetchableRecord, Decodable {
            let value: String
        }
        
        do {
            let s = try Struct(row: ["value": "foo"])
            XCTAssertEqual(s.value, "foo")
        }
    }
    
    func testCustomDecodable() throws {
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
            let s = try Struct(row: ["someColumn": "foo"])
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
    
    func testTrivialProperty() throws {
        struct Struct : FetchableRecord, Decodable {
            let int64: Int64
            let optionalInt64: Int64?
        }
        
        do {
            // No null values
            let s = try Struct(row: ["int64": 1, "optionalInt64": 2])
            XCTAssertEqual(s.int64, 1)
            XCTAssertEqual(s.optionalInt64, 2)
        }
        do {
            // Null values
            let s = try Struct(row: ["int64": 2, "optionalInt64": nil])
            XCTAssertEqual(s.int64, 2)
            XCTAssertNil(s.optionalInt64)
        }
        do {
            // Missing and extra values
            let s = try Struct(row: ["int64": 3, "ignored": "?"])
            XCTAssertEqual(s.int64, 3)
            XCTAssertNil(s.optionalInt64)
        }
    }
    
    func testTrivialSingleValueDecodableProperty() throws {
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
            let s = try Struct(row: ["value": "foo", "optionalValue": "bar"])
            XCTAssertEqual(s.value.string, "foo")
            XCTAssertEqual(s.optionalValue!.string, "bar")
        }
        
        do {
            // Null values
            let s = try Struct(row: ["value": "foo", "optionalValue": nil])
            XCTAssertEqual(s.value.string, "foo")
            XCTAssertNil(s.optionalValue)
        }
        
        do {
            // Missing and extra values
            let s = try Struct(row: ["value": "foo", "ignored": "?"])
            XCTAssertEqual(s.value.string, "foo")
            XCTAssertNil(s.optionalValue)
        }
    }
    
    func testSingleValueDataProperty() throws {
        struct Value : Decodable {
            let data: Data
            
            init(from decoder: Decoder) throws {
                data = try decoder.singleValueContainer().decode(Data.self)
            }
        }
        
        struct Struct : FetchableRecord, Decodable {
            static func databaseDataDecodingStrategy(for column: String) -> DatabaseDataDecodingStrategy {
                if column == "value" {
                    return .custom { _ in Data([1, 2, 3]) }
                } else {
                    return .deferredToData
                }
            }
            let value: Value
            let optionalValue: Value?
        }
        
        do {
            // No null values
            let s = try Struct(row: ["value": "foo", "optionalValue": "bar"])
            XCTAssertEqual(s.value.data, Data([1, 2, 3]))
            XCTAssertEqual(s.optionalValue?.data, Data([98, 97, 114]))
        }
        
        do {
            // Null values
            let s = try Struct(row: ["value": "foo", "optionalValue": nil])
            XCTAssertEqual(s.value.data, Data([1, 2, 3]))
            XCTAssertNil(s.optionalValue)
        }
        
        do {
            // Missing and extra values
            let s = try Struct(row: ["value": "foo", "ignored": "?"])
            XCTAssertEqual(s.value.data, Data([1, 2, 3]))
            XCTAssertNil(s.optionalValue)
        }
    }
    
    func testSingleValueDateProperty() throws {
        struct Value : Decodable {
            let date: Date
            
            init(from decoder: Decoder) throws {
                date = try decoder.singleValueContainer().decode(Date.self)
            }
        }
        
        struct Struct : FetchableRecord, Decodable {
            static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
                if column == "value" {
                    return .custom { _ in Date(timeIntervalSince1970: 0) }
                } else {
                    return .deferredToDate
                }
            }
            let value: Value
            let optionalValue: Value?
        }
        
        do {
            // No null values
            let s = try Struct(row: ["value": "foo", "optionalValue": "2001-01-01 00:00:00"])
            XCTAssertEqual(s.value.date, Date(timeIntervalSince1970: 0))
            XCTAssertEqual(s.optionalValue?.date, Date(timeIntervalSinceReferenceDate: 0))
        }
        
        do {
            // Null values
            let s = try Struct(row: ["value": "foo", "optionalValue": nil])
            XCTAssertEqual(s.value.date, Date(timeIntervalSince1970: 0))
            XCTAssertNil(s.optionalValue)
        }
        
        do {
            // Missing and extra values
            let s = try Struct(row: ["value": "foo", "ignored": "?"])
            XCTAssertEqual(s.value.date, Date(timeIntervalSince1970: 0))
            XCTAssertNil(s.optionalValue)
        }
    }

    func testNonTrivialSingleValueDecodableProperty() throws {
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
            let s = try Struct(row: ["value": "foo", "optionalValue": "bar"])
            XCTAssertEqual(s.value.nestedValue.string, "foo")
            XCTAssertEqual(s.optionalValue!.nestedValue.string, "bar")
        }
        
        do {
            // Null values
            let s = try Struct(row: ["value": "foo", "optionalValue": nil])
            XCTAssertEqual(s.value.nestedValue.string, "foo")
            XCTAssertNil(s.optionalValue)
        }
        
        do {
            // Missing and extra values
            let s = try Struct(row: ["value": "foo", "ignored": "?"])
            XCTAssertEqual(s.value.nestedValue.string, "foo")
            XCTAssertNil(s.optionalValue)
        }
    }
    
    func testDecodableRawRepresentableProperty() throws {
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
            let s = try Struct(row: ["value": "foo", "optionalValue": "bar"])
            XCTAssertEqual(s.value, .foo)
            XCTAssertEqual(s.optionalValue!, .bar)
        }
        
        do {
            // Null values
            let s = try Struct(row: ["value": "foo", "optionalValue": nil])
            XCTAssertEqual(s.value, .foo)
            XCTAssertNil(s.optionalValue)
        }
        
        do {
            // Missing and extra values
            let s = try Struct(row: ["value": "foo", "ignored": "?"])
            XCTAssertEqual(s.value, .foo)
            XCTAssertNil(s.optionalValue)
        }
    }
    
    func testDatabaseValueConvertibleProperty() throws {
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
            
            var databaseValue: DatabaseValue { fatalError("irrelevant") }
            
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
            let s = try Struct(row: ["value": "foo", "optionalValue": "bar"])
            XCTAssertEqual(s.value.string, "foo (DatabaseValueConvertible)")
            XCTAssertEqual(s.optionalValue!.string, "bar (DatabaseValueConvertible)")
        }
        
        do {
            // Null values
            let s = try Struct(row: ["value": "foo", "optionalValue": nil])
            XCTAssertEqual(s.value.string, "foo (DatabaseValueConvertible)")
            XCTAssertNil(s.optionalValue)
        }
        
        do {
            // Missing and extra values
            let s = try Struct(row: ["value": "foo", "ignored": "?"])
            XCTAssertEqual(s.value.string, "foo (DatabaseValueConvertible)")
            XCTAssertNil(s.optionalValue)
        }
    }
}

// MARK: - Foundation Codable Types

extension FetchableRecordDecodableTests {

    func testStructWithData() throws {
        struct StructWithData : FetchableRecord, Decodable {
            let data: Data
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        do {
            let data = "foo".data(using: .utf8)
            
            do {
                let value = try StructWithData(row: ["data": data])
                XCTAssertEqual(value.data, data)
            }
            
            do {
                let value = try dbQueue.read {
                    try StructWithData.fetchOne($0, sql: "SELECT ? AS data", arguments: [data])!
                }
                XCTAssertEqual(value.data, data)
            }
        }
        do {
            do {
                _ = try StructWithData(row: ["data": nil])
                XCTFail("Expected Error")
            } catch let error as RowDecodingError {
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                    could not decode Data from database value NULL - \
                    column: "data", \
                    column index: 0, \
                    row: [data:NULL]
                    """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                try dbQueue.read {
                    _ = try StructWithData.fetchOne($0, sql: "SELECT NULL AS data")
                }
                XCTFail("Expected Error")
            } catch let error as RowDecodingError {
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                    could not decode Data from database value NULL - \
                    column: "data", \
                    column index: 0, \
                    row: [data:NULL], \
                    sql: `SELECT NULL AS data`, \
                    arguments: []
                    """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }

    func testStructWithDate() throws {
        struct StructWithDate : FetchableRecord, Decodable {
            let date: Date
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        do {
            let date = Date()
            
            do {
                let value = try StructWithDate(row: ["date": date])
                XCTAssert(abs(value.date.timeIntervalSince(date)) < 0.001)
            }
            
            do {
                let value = try dbQueue.read {
                    try StructWithDate.fetchOne($0, sql: "SELECT ? AS date", arguments: [date])!
                }
                XCTAssert(abs(value.date.timeIntervalSince(date)) < 0.001)
            }
        }
        do {
            do {
                _ = try StructWithDate(row: ["date": nil])
                XCTFail("Expected Error")
            } catch let error as RowDecodingError {
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                    could not decode Date from database value NULL - \
                    column: "date", \
                    column index: 0, \
                    row: [date:NULL]
                    """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                try dbQueue.read {
                    _ = try StructWithDate.fetchOne($0, sql: "SELECT NULL AS date")
                }
                XCTFail("Expected Error")
            } catch let error as RowDecodingError {
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                    could not decode Date from database value NULL - \
                    column: "date", \
                    column index: 0, \
                    row: [date:NULL], \
                    sql: `SELECT NULL AS date`, \
                    arguments: []
                    """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
    
    func testStructWithURL() throws {
        struct StructWithURL : FetchableRecord, Decodable {
            let url: URL
        }
        
        let url = URL(string: "https://github.com")
        let value = try StructWithURL(row: ["url": url])
        XCTAssertEqual(value.url, url)
    }
    
    func testStructWithUUID() throws {
        struct StructWithUUID : FetchableRecord, Decodable {
            let uuid: UUID
        }
        
        let uuid = UUID()
        let value = try StructWithUUID(row: ["uuid": uuid])
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
        
        let model = try StructWithNestedType(row: row)
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
                try row.withUnsafeData(named: "name") { data in
                    XCTAssertEqual(jsonAsData, data)
                }
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
                try row.withUnsafeData(named: "name") { data in
                    XCTAssertEqual(jsonAsData, data)
                }
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
    
    // MARK: - DatabaseColumnDecodingStrategy
    
    func testDatabaseColumnDecodingStrategy_useDefaultKeys() throws {
        struct Record: FetchableRecord, Decodable, Equatable {
            static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.useDefaultKeys
            let requiredId: Int
            let optionalName: String?
            let requiredDates: [Date]
            let optionalDates: [Date?]
            let optionalDates2: [Date]?
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "requiredId": 1,
                "optionalName": "test1",
                "requiredDates": "[128000]",
                "optionalDates": "[null, 128000]",
                "optionalDates2": "[128000]",
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: "test1",
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: [Date(timeIntervalSince1970: 128)]))
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "REQUIREDID": 1,
                "OPTIONALNAME": "test1",
                "REQUIREDDATES": "[128000]",
                "OPTIONALDATES": "[null, 128000]",
                "OPTIONALDATES2": "[128000]",
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: "test1",
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: [Date(timeIntervalSince1970: 128)]))
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "requiredId": 1,
                "optionalName": nil,
                "requiredDates": "[128000]",
                "optionalDates": "[null, 128000]",
                "optionalDates2": nil,
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: nil,
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: nil))
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "requiredId": 1,
                "requiredDates": "[128000]",
                "optionalDates": "[null, 128000]",
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: nil,
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: nil))
        }
        
        do {
            _ = try FetchableRecordDecoder().decode(Record.self, from: [
                "required_id": 1,
                "optionalName": "test1",
                "requiredDates": "[128000]",
                "optionalDates": "[null, 128000]",
                "optionalDates2": "[128000]",
            ])
            XCTFail("Expected error")
        } catch let RowDecodingError.keyNotFound(.columnName(column), context) {
            XCTAssertEqual(column, "requiredId")
            XCTAssertEqual(context.debugDescription, "column not found: \"requiredId\"")
        }
    }
    
    func testDatabaseColumnDecodingStrategy_convertFromSnakeCase() throws {
        struct Record: FetchableRecord, Decodable, Equatable {
            static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
            let requiredId: Int
            let optionalName: String?
            let requiredDates: [Date]
            let optionalDates: [Date?]
            let optionalDates2: [Date]?
        }
        
        struct IncorrectRecord: FetchableRecord, Decodable, Equatable {
            static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
            let requiredID: Int // incorrect: should be requiredId
            let optionalName: String?
            let requiredDates: [Date]
            let optionalDates: [Date?]
            let optionalDates2: [Date]?
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "required_id": 1,
                "optional_name": "test1",
                "required_dates": "[128000]",
                "optional_dates": "[null, 128000]",
                "optional_dates2": "[128000]",
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: "test1",
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: [Date(timeIntervalSince1970: 128)]))
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "REQUIRED_ID": 1,
                "OPTIONAL_NAME": "test1",
                "REQUIRED_DATES": "[128000]",
                "OPTIONAL_DATES": "[null, 128000]",
                "OPTIONAL_DATES2": "[128000]",
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: "test1",
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: [Date(timeIntervalSince1970: 128)]))
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "required_id": 1,
                "optional_name": nil,
                "required_dates": "[128000]",
                "optional_dates": "[null, 128000]",
                "optional_dates2": nil,
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: nil,
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: nil))
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "required_id": 1,
                "required_dates": "[128000]",
                "optional_dates": "[null, 128000]",
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: nil,
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: nil))
        }
        
        do {
            // Matches JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase behavior
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "requiredId": 1,
                "optionalName": "test1",
                "requiredDates": "[128000]",
                "optionalDates": "[null, 128000]",
                "optionalDates2": "[128000]",
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: "test1",
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: [Date(timeIntervalSince1970: 128)]))
        }
        
        do {
            _ = try FetchableRecordDecoder().decode(Record.self, from: [
                "required_idx": 1,
                "optional_name": "test1",
                "required_dates": "[128000]",
                "optional_dates": "[null, 128000]",
                "optional_dates2": "[128000]",
            ])
            XCTFail("Expected error")
        } catch let RowDecodingError.keyNotFound(.columnName(column), context) {
            XCTAssertEqual(column, "requiredId")
            XCTAssertEqual(context.debugDescription, """
                key not found: CodingKeys(stringValue: "requiredId", intValue: nil) ("requiredId"), \
                converted to required_id
                """)
        }
        
        do {
            _ = try FetchableRecordDecoder().decode(IncorrectRecord.self, from: [
                "required_id": 1,
                "optional_name": "test1",
                "required_dates": "[128000]",
                "optional_dates": "[null, 128000]",
                "optional_dates2": "[128000]",
            ])
            XCTFail("Expected error")
        } catch let RowDecodingError.keyNotFound(.columnName(column), context) {
            XCTAssertEqual(column, "requiredID")
            XCTAssertEqual(context.debugDescription, """
                key not found: CodingKeys(stringValue: "requiredID", intValue: nil) ("requiredID"), \
                with divergent representation requiredId, \
                converted to required_id
                """)
        }
    }
    
    func testDatabaseColumnDecodingStrategy_custom() throws {
        struct AnyKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }
        
        struct Record: FetchableRecord, Decodable, Equatable {
            static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.custom { column in
                AnyKey(stringValue: String(column.dropFirst()))
            }
            let requiredId: Int
            let optionalName: String?
            let requiredDates: [Date]
            let optionalDates: [Date?]
            let optionalDates2: [Date]?
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "_requiredId": 1,
                "_optionalName": "test1",
                "_requiredDates": "[128000]",
                "_optionalDates": "[null, 128000]",
                "_optionalDates2": "[128000]",
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: "test1",
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: [Date(timeIntervalSince1970: 128)]))
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "_requiredId": 1,
                "_optionalName": nil,
                "_requiredDates": "[128000]",
                "_optionalDates": "[null, 128000]",
                "_optionalDates2": nil,
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: nil,
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: nil))
        }
        
        do {
            let record = try FetchableRecordDecoder().decode(Record.self, from: [
                "_requiredId": 1,
                "_requiredDates": "[128000]",
                "_optionalDates": "[null, 128000]",
            ])
            XCTAssertEqual(record, Record(
                            requiredId: 1,
                            optionalName: nil,
                            requiredDates: [Date(timeIntervalSince1970: 128)],
                            optionalDates: [nil, Date(timeIntervalSince1970: 128)],
                            optionalDates2: nil))
        }
        
        do {
            _ = try FetchableRecordDecoder().decode(Record.self, from: [
                "requiredId": 1,
                "_optionalName": "test1",
                "_requiredDates": "[128000]",
                "_optionalDates": "[null, 128000]",
                "_optionalDates2": "[128000]",
            ])
            XCTFail("Expected error")
        } catch let RowDecodingError.keyNotFound(.columnName(column), context) {
            XCTAssertEqual(column, "requiredId")
            XCTAssertEqual(context.debugDescription, """
                key not found: CodingKeys(stringValue: "requiredId", intValue: nil) ("requiredId")
                """)
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

        static var databaseDecodingUserInfo: [CodingUserInfoKey: Any] {
            [
                testKeyRoot: "GRDB root",
                testKeyNested: "GRDB column or scope",
            ]
        }
        
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
            let request = SQLRequest(
                sql: "SELECT ? AS name, ? AS nestedSingle, ? AS nestedUnkeyed",
                arguments: ["foo", "bar", "[\"baz\"]"],
                adapter: adapter)
            
            let record = try Record.fetchOne(db, request)!
            test(record)
            
            let row = try Row.fetchOne(db, request)!
            try test(Record(row: row))
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
            
            let request = SQLRequest(
                sql: "SELECT ? AS nestedKeyed, ? AS nestedSingle, ? AS nestedUnkeyed",
                arguments: ["{\"name\":\"foo\"}", "bar", "[\"baz\"]"])
            
            let record = try Record.fetchOne(db, request)!
            test(record)
            
            let row = try Row.fetchOne(db, request)!
            try test(Record(row: row))
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
            let request = SQLRequest(
                sql: "SELECT ? AS name, ? AS nestedSingle, ? AS nestedUnkeyed",
                arguments: ["foo", "bar", "[\"baz\"]"],
                adapter: adapter)
            
            let record = try CustomizedRecord.fetchOne(db, request)!
            test(record)
            
            let row = try Row.fetchOne(db, request)!
            try test(CustomizedRecord(row: row))
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
            
            let request = SQLRequest(
                sql: "SELECT ? AS nestedKeyed, ? AS nestedSingle, ? AS nestedUnkeyed",
                arguments: ["{\"name\":\"foo\"}", "bar", "[\"baz\"]"])
            
            let record = try CustomizedRecord.fetchOne(db, request)!
            test(record)
            
            let row = try Row.fetchOne(db, request)!
            try test(CustomizedRecord(row: row))
        }
    }
    
    func testMissingKeys1() throws {
        struct A: Decodable { }
        struct B: Decodable { }
        struct C: Decodable { }
        struct Composed: Decodable, FetchableRecord {
            var a: A
            var b: B?
            var c: C?
        }
        
        // No error expected:
        // - a is successfully decoded because it consumes the one and unique
        //   allowed missing key
        // - b and c are successfully decoded, because they are optionals, and
        //   all optionals decode missing keys are nil. This is because GRDB
        //   records accept rows with missing columns, and b and c may want to
        //   decode columns.
        _ = try FetchableRecordDecoder().decode(Composed.self, from: [:])
    }
    
    // This is a regression test for https://github.com/groue/GRDB.swift/issues/664
    func testMissingKeys2() throws {
        struct A: Decodable { }
        struct B: Decodable { }
        struct Composed: Decodable, FetchableRecord {
            var a: A
            var b: B
        }
        do {
            _ = try FetchableRecordDecoder().decode(Composed.self, from: [:])
            XCTFail("Expected error")
        } catch DecodingError.keyNotFound {
            // a or b can not be decoded because only one key is allowed to be missing
        }
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/836
    func testRootKeyDecodingError() throws {
        struct Record: Decodable { }
        struct Composed: Decodable, FetchableRecord {
            var a: Record
            var b: Record
            var c: Record
        }
        try makeDatabaseQueue().read { db in
            do {
                // - a is present
                // - root is b and c is missing, or the opposite (two possible user intents)
                let row = try Row.fetchOne(db, sql: "SELECT NULL", adapter: ScopeAdapter(["a": EmptyRowAdapter()]))!
                _ = try FetchableRecordDecoder().decode(Composed.self, from: row)
                XCTFail("Expected error")
            } catch let DecodingError.keyNotFound(key, context) {
                XCTAssert(["b", "c"].contains(key.stringValue))
                XCTAssertEqual(context.debugDescription, "No such key: b or c")
            }
            do {
                // - b is present
                // - root is a and c is missing, or the opposite (two possible user intents)
                let row = try Row.fetchOne(db, sql: "SELECT NULL", adapter: ScopeAdapter(["b": EmptyRowAdapter()]))!
                _ = try FetchableRecordDecoder().decode(Composed.self, from: row)
                XCTFail("Expected error")
            } catch let DecodingError.keyNotFound(key, context) {
                XCTAssert(["a", "c"].contains(key.stringValue))
                XCTAssertEqual(context.debugDescription, "No such key: a or c")
            }
            do {
                // - c is present
                // - root is a and b is missing, or the opposite (two possible user intents)
                let row = try Row.fetchOne(db, sql: "SELECT NULL", adapter: ScopeAdapter(["c": EmptyRowAdapter()]))!
                _ = try FetchableRecordDecoder().decode(Composed.self, from: row)
                XCTFail("Expected error")
            } catch let DecodingError.keyNotFound(key, context) {
                XCTAssert(["a", "b"].contains(key.stringValue))
                XCTAssertEqual(context.debugDescription, "No such key: a or b")
            }
        }
    }

    func testUserInfoJsonDecoding() throws {
        struct NestedStruct : Codable {
            let firstName: String?
            let lastName: String?

            init(firstName: String?, lastName: String?) {
                self.firstName = firstName
                self.lastName = lastName
            }

            init(from decoder: Decoder) throws {
                let userInfoValue = decoder.userInfo[.testKey] as? String

                let container = try decoder.container(keyedBy: CodingKeys.self)
                if userInfoValue == "correct" {
                    firstName = try container.decode(String.self, forKey: .firstName)
                    lastName = try container.decode(String.self, forKey: .lastName)
                } else {
                    firstName = try container.decode(String.self, forKey: .lastName)
                    lastName = try container.decode(String.self, forKey: .firstName)
                }
            }
        }

        struct StructWithNestedType : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            static var databaseDecodingUserInfo: [CodingUserInfoKey: Any] {
                [CodingUserInfoKey.testKey: "correct"]
            }
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

// MARK: - Decodable + custom init

extension FetchableRecordDecodableTests {
    // Test for <https://github.com/groue/GRDB.swift/issues/1366#issuecomment-1527280022>
    func testStructWithCustomizedRowInitializer() throws {
        struct Player: Decodable, FetchableRecord {
            var id: Int
            var name: String
            var isFetched: Bool = false
            
            enum CodingKeys: String, CodingKey {
                case id, name
            }
            
            init(id: Int, name: String) {
                self.id = id
                self.name = name
                self.isFetched = false
            }
            
            init(row: Row) throws {
                self = try FetchableRecordDecoder().decode(Player.self, from: row)
                self.isFetched = true
            }
        }
        
        do {
            let player = Player(id: 1, name: "Arthur")
            XCTAssertEqual(player.id, 1)
            XCTAssertEqual(player.name, "Arthur")
            XCTAssertEqual(player.isFetched, false)
        }
        
        do {
            let player = try Player(row: ["id": 2, "name": "Barbara"])
            XCTAssertEqual(player.id, 2)
            XCTAssertEqual(player.name, "Barbara")
            XCTAssertEqual(player.isFetched, true)
        }
    }
}

// MARK: - KeyedContainer tests

extension FetchableRecordDecodableTests {
    struct AnyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        
        init(_ key: String) {
            self.stringValue = key
        }
        
        init(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
    
    func test_allKeys_and_containsKey() throws {
        struct Witness: Decodable, FetchableRecord {
            init(from decoder: any Decoder) throws {
                // Top
                let container = try decoder.container(keyedBy: AnyCodingKey.self)
                do {
                    // Test allKeys
                    let allKeys = container.allKeys
                    XCTAssertEqual(Set(allKeys.map(\.stringValue)), [
                        "a",
                        "topLevelScope1",
                        "topLevelScope2",
                        "nestedScope1",
                        "nestedScope2",
                        "prefetchedRows1",
                        "prefetchedRows2"])

                    // Test contains(_:)
                    for key in allKeys {
                        XCTAssertTrue(container.contains(key))
                    }
                    XCTAssertFalse(container.contains(AnyCodingKey("b")))
                    XCTAssertFalse(container.contains(AnyCodingKey("c")))
                }
                
                // topLevelScope1
                let topLevelScope1Container = try container.nestedContainer(
                    keyedBy: AnyCodingKey.self,
                    forKey: AnyCodingKey("topLevelScope1"))
                do {
                    // Test allKeys
                    let allKeys = topLevelScope1Container.allKeys
                    XCTAssertEqual(Set(allKeys.map(\.stringValue)), [
                        "c",
                    ])

                    // Test contains(_:)
                    for key in allKeys {
                        XCTAssertTrue(topLevelScope1Container.contains(key))
                    }
                }
                
                // topLevelScope2
                let topLevelScope2Container = try container.nestedContainer(
                    keyedBy: AnyCodingKey.self,
                    forKey: AnyCodingKey("topLevelScope2"))
                do {
                    // Test allKeys
                    let allKeys = topLevelScope2Container.allKeys
                    XCTAssertEqual(Set(allKeys.map(\.stringValue)), [
                        "nestedScope2",
                        "nestedScope1",
                        "prefetchedRows2",
                    ])

                    // Test contains(_:)
                    for key in allKeys {
                        XCTAssertTrue(topLevelScope2Container.contains(key))
                    }
                }
            }
        }
        
        try makeDatabaseQueue().read { db in
            let row = try Row.fetchOne(
                db, sql: """
                    SELECT 1 AS a, -- main row
                           2 AS b, -- not exposed
                           3 AS c, -- scope topLevelScope1
                           4 AS d, -- scope topLevelScope2.nestedScope1
                           5 AS e  -- scope topLevelScope2.nestedScope2
                    """,
                adapter: RangeRowAdapter(0..<1)
                    .addingScopes([
                        "topLevelScope1": RangeRowAdapter(2..<3),
                        "topLevelScope2": EmptyRowAdapter().addingScopes([
                            "nestedScope1": RangeRowAdapter(3..<4),
                            "nestedScope2": RangeRowAdapter(4..<5),
                        ]),
                    ]))!
            
            row.prefetchedRows.setRows([], forKeyPath: ["prefetchedRows1"])
            row.prefetchedRows.setRows([Row()], forKeyPath: ["topLevelScope2", "prefetchedRows2"])
            // Check test setup
            XCTAssertEqual(row.debugDescription, """
                ▿ [a:1]
                  unadapted: [a:1 b:2 c:3 d:4 e:5]
                  - topLevelScope1: [c:3]
                  - topLevelScope2: []
                    - nestedScope1: [d:4]
                    - nestedScope2: [e:5]
                    + prefetchedRows2: 1 row
                  + prefetchedRows1: 0 row
                  + prefetchedRows2: 1 row
                """)
            
            // Test keyed container
            _ = try FetchableRecordDecoder().decode(Witness.self, from: row)
        }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1531>
    func test_decodeNil_and_containsKey() throws {
        struct Witness: Decodable, FetchableRecord {
            struct NestedRecord: Decodable, FetchableRecord { }
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: AnyCodingKey.self)
                
                // column
                do {
                    let key = AnyCodingKey("a")
                    let nilDecoded = try container.decodeNil(forKey: key)
                    let value = try container.decodeIfPresent(Int.self, forKey: key)
                    XCTAssertTrue(nilDecoded == (value == nil))
                    XCTAssertTrue(container.contains(key))
                }
                
                // scope
                do {
                    let key = AnyCodingKey("nested")
                    let nilDecoded = try container.decodeNil(forKey: key)
                    let value = try container.decodeIfPresent(NestedRecord.self, forKey: key)
                    XCTAssertTrue(nilDecoded == (value == nil))
                    XCTAssertTrue(container.contains(key))
                }
                
                // missing key
                do {
                    let key = AnyCodingKey("missing")
                    try XCTAssertTrue(container.decodeNil(forKey: key))
                    try XCTAssertNil(container.decodeIfPresent(Int.self, forKey: key))
                    try XCTAssertNil(container.decodeIfPresent(NestedRecord.self, forKey: key))
                    XCTAssertFalse(container.contains(key))
                }
            }
        }
        
        try makeDatabaseQueue().read { db in
            do {
                let row = try Row.fetchOne(
                    db, sql: """
                        SELECT 1 AS a, 2 AS b
                        """,
                    adapter: ScopeAdapter([
                        "nested": RangeRowAdapter(1..<2),
                    ]))!
                
                // Check test setup
                XCTAssertEqual(row.debugDescription, """
                ▿ [a:1 b:2]
                  unadapted: [a:1 b:2]
                  - nested: [b:2]
                """)
                
                // Test keyed container
                _ = try FetchableRecordDecoder().decode(Witness.self, from: row)
            }
            
            do {
                let row = try Row.fetchOne(
                    db, sql: """
                        SELECT NULL AS a, NULL AS b
                        """,
                    adapter: ScopeAdapter([
                        "nested": RangeRowAdapter(1..<2),
                    ]))!
                
                // Check test setup
                XCTAssertEqual(row.debugDescription, """
                ▿ [a:NULL b:NULL]
                  unadapted: [a:NULL b:NULL]
                  - nested: [b:NULL]
                """)
                
                // Test keyed container
                _ = try FetchableRecordDecoder().decode(Witness.self, from: row)
            }
        }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1531>
    func test_decodeNil_when_scope_and_column_have_the_same_name() throws {
        struct Witness: Decodable, FetchableRecord {
            struct NestedRecord: Decodable, FetchableRecord { }
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: AnyCodingKey.self)
                
                let key = AnyCodingKey("a")
                let nilDecoded = try container.decodeNil(forKey: key)
                let intValue = try container.decodeIfPresent(Int.self, forKey: key)
                let recordValue = try container.decodeIfPresent(NestedRecord.self, forKey: key)
                XCTAssertTrue(nilDecoded == (intValue == nil))
                XCTAssertTrue(nilDecoded == (recordValue == nil))
            }
        }
        
        try makeDatabaseQueue().read { db in
            do {
                let row = try Row.fetchOne(
                    db, sql: """
                        SELECT 1 AS a
                        """,
                    adapter: ScopeAdapter([
                        "a": SuffixRowAdapter(fromIndex: 0),
                    ]))!
                
                // Check test setup
                XCTAssertEqual(row.debugDescription, """
                ▿ [a:1]
                  unadapted: [a:1]
                  - a: [a:1]
                """)
                
                // Test keyed container
                _ = try FetchableRecordDecoder().decode(Witness.self, from: row)
            }
            
            do {
                let row = try Row.fetchOne(
                    db, sql: """
                        SELECT NULL AS a
                        """,
                    adapter: ScopeAdapter([
                        "a": SuffixRowAdapter(fromIndex: 0),
                    ]))!
                
                // Check test setup
                XCTAssertEqual(row.debugDescription, """
                ▿ [a:NULL]
                  unadapted: [a:NULL]
                  - a: [a:NULL]
                """)
                
                // Test keyed container
                _ = try FetchableRecordDecoder().decode(Witness.self, from: row)
            }
        }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1572>
    func testSingleValueContainer() throws {
        struct Struct: Decodable {
            let value: String
        }
        
        struct Wrapper<Model: Decodable>: FetchableRecord, Decodable {
            var model: Model
            var otherValue: String
            
            enum CodingKeys: String, CodingKey {
                case otherValue
            }
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                otherValue = try container.decode(String.self, forKey: . otherValue)
                
                let singleValueContainer = try decoder.singleValueContainer()
                model = try singleValueContainer.decode(Model.self)
            }
        }
        
        let row = Row(["value": "foo", "otherValue": "bar"])
        
        let wrapper = try Wrapper<Struct>(row: row)
        XCTAssertEqual(wrapper.model.value, "foo")
        XCTAssertEqual(wrapper.otherValue, "bar")
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1572>
    // Here we test that `FetchableRecord` takes precedence over `Decodable`
    // when a record is encoded with a `SingleValueEncodingContainer`.
    func testSingleValueContainerWithFetchableRecord() throws {
        struct Struct: Decodable, FetchableRecord {
            let value: String
            
            init(row: Row) throws {
                value = row["actualValue"]
            }
        }
        
        struct Wrapper<Model: Decodable>: FetchableRecord, Decodable {
            var model: Model
            var otherValue: String
            
            enum CodingKeys: String, CodingKey {
                case otherValue
            }
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                otherValue = try container.decode(String.self, forKey: . otherValue)
                
                let singleValueContainer = try decoder.singleValueContainer()
                model = try singleValueContainer.decode(Model.self)
            }
        }
        
        let row = Row(["value": "foo", "otherValue": "bar", "actualValue": "test"])
        
        let wrapper = try Wrapper<Struct>(row: row)
        XCTAssertEqual(wrapper.model.value, "test")
        XCTAssertEqual(wrapper.otherValue, "bar")
    }
}
