import Foundation
import XCTest
@testable import GRDB // TODO: remove @testable when RowDecodingError is public

private protocol StrategyProvider {
    static var strategy: DatabaseDataDecodingStrategy { get }
}

private enum StrategyDeferredToData: StrategyProvider {
    static let strategy: DatabaseDataDecodingStrategy = .deferredToData
}

private enum StrategyCustom: StrategyProvider {
    static let strategy: DatabaseDataDecodingStrategy = .custom { dbValue in
        if dbValue == "invalid".databaseValue {
            return nil
        }
        return "foo".data(using: .utf8)!
    }
}

private struct RecordWithData<Strategy: StrategyProvider>: FetchableRecord, Decodable {
    static var databaseDataDecodingStrategy: DatabaseDataDecodingStrategy { Strategy.strategy }
    var data: Data
}

private struct RecordWithOptionalData<Strategy: StrategyProvider>: FetchableRecord, Decodable {
    static var databaseDataDecodingStrategy: DatabaseDataDecodingStrategy { Strategy.strategy }
    var data: Data?
}

class DatabaseDataDecodingStrategyTests: GRDBTestCase {
    /// test the conversion from a database value to a data extracted from a record
    private func test<T: FetchableRecord>(
        _ db: Database,
        record: T.Type,
        data: (T) -> Data?,
        databaseValue: (any DatabaseValueConvertible)?,
        with test: (Data?) -> Void) throws
    {
        let request = SQLRequest<Void>(sql: "SELECT ? AS data", arguments: [databaseValue])
        do {
            // test decoding straight from SQLite
            let record = try T.fetchOne(db, request)!
            test(data(record))
        }
        do {
            // test decoding from copied row
            let record = try T(row: Row.fetchOne(db, request)!)
            test(data(record))
        }
    }
    
    /// test the conversion from a database value to a data with a given strategy
    private func test<Strategy: StrategyProvider>(
        _ db: Database,
        strategy: Strategy.Type,
        databaseValue: some DatabaseValueConvertible,
        _ test: (Data) -> Void)
    throws
    {
        try self.test(db, record: RecordWithData<Strategy>.self, data: { $0.data }, databaseValue: databaseValue, with: { test($0!) })
        try self.test(db, record: RecordWithOptionalData<Strategy>.self, data: { $0.data }, databaseValue: databaseValue, with: { test($0!) })
    }
    
    private func testNullDecoding<Strategy: StrategyProvider>(_ db: Database, strategy: Strategy.Type) throws {
        try self.test(db, record: RecordWithOptionalData<Strategy>.self, data: { $0.data }, databaseValue: nil) { data in
            XCTAssertNil(data)
        }
    }
}

// MARK: - deferredToData

extension DatabaseDataDecodingStrategyTests {
    func testDeferredToData() throws {
        try makeDatabaseQueue().read { db in
            // Null
            try testNullDecoding(db, strategy: StrategyDeferredToData.self)
            
            // Empty string
            try test(db, strategy: StrategyDeferredToData.self, databaseValue: "") { data in
                XCTAssertEqual(data, Data())
            }
            
            // String
            try test(db, strategy: StrategyDeferredToData.self, databaseValue: "foo") { data in
                XCTAssertEqual(data, "foo".data(using: .utf8))
            }
            
            // Empty blob
            try test(db, strategy: StrategyDeferredToData.self, databaseValue: Data()) { data in
                XCTAssertEqual(data, Data())
            }
            
            // Blob
            try test(db, strategy: StrategyDeferredToData.self, databaseValue: "foo".data(using: .utf8)) { data in
                XCTAssertEqual(data, "foo".data(using: .utf8))
            }
        }
    }
}

// MARK: - custom((DatabaseValue) -> Data?

extension DatabaseDataDecodingStrategyTests {
    func testCustom() throws {
        try makeDatabaseQueue().read { db in
            // Null
            try testNullDecoding(db, strategy: StrategyCustom.self)

            // Data
            try test(db, strategy: StrategyCustom.self, databaseValue: "valid") { data in
                XCTAssertEqual(data, "foo".data(using: .utf8)!)
            }
            
            // error
            do {
                try test(db, strategy: StrategyCustom.self, databaseValue: "invalid") { data in
                    XCTFail("Unexpected Data")
                }
            } catch let error as RowDecodingError {
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                        could not decode Data from database value "invalid" - \
                        column: "data", \
                        column index: 0, \
                        row: [data:"invalid"], \
                        sql: `SELECT ? AS data`, \
                        arguments: ["invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
}
