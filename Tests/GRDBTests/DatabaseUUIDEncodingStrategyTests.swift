import XCTest
import Foundation
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

private protocol StrategyProvider {
    static var strategy: DatabaseUUIDEncodingStrategy { get }
}

private enum StrategyDeferredToUUID: StrategyProvider {
    static let strategy: DatabaseUUIDEncodingStrategy = .deferredToUUID
}

private enum StrategyString: StrategyProvider {
    static let strategy: DatabaseUUIDEncodingStrategy = .string
}

private struct RecordWithUUID<Strategy: StrategyProvider>: PersistableRecord, Encodable {
    static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { return Strategy.strategy }
    var uuid: UUID
}

private struct RecordWithOptionalUUID<Strategy: StrategyProvider>: PersistableRecord, Encodable {
    static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { return Strategy.strategy }
    var uuid: UUID?
}

class DatabaseUUIDEncodingStrategyTests: GRDBTestCase {
    private func test<T: PersistableRecord>(
        record: T,
        expectedStorage: DatabaseValue.Storage)
    {
        var container = PersistenceContainer()
        record.encode(to: &container)
        if let dbValue = container["uuid"]?.databaseValue {
            XCTAssertEqual(dbValue.storage, expectedStorage)
        } else {
            XCTAssertEqual(.null, expectedStorage)
        }
    }
    
    private func test<Strategy: StrategyProvider>(strategy: Strategy.Type, encodesUUID uuid: UUID, as value: DatabaseValueConvertible) {
        test(record: RecordWithUUID<Strategy>(uuid: uuid), expectedStorage: value.databaseValue.storage)
        test(record: RecordWithOptionalUUID<Strategy>(uuid: uuid), expectedStorage: value.databaseValue.storage)
    }
    
    private func testNullEncoding<Strategy: StrategyProvider>(strategy: Strategy.Type) {
        test(record: RecordWithOptionalUUID<Strategy>(uuid: nil), expectedStorage: .null)
    }
}

// MARK: - deferredToUUID

extension DatabaseUUIDEncodingStrategyTests {
    func testDeferredToUUID() {
        testNullEncoding(strategy: StrategyDeferredToUUID.self)
        
        test(
            strategy: StrategyDeferredToUUID.self,
            encodesUUID: UUID(uuidString: "61626364-6566-6768-696A-6B6C6D6E6F70")!,
            as: "abcdefghijklmnop".data(using: .utf8)!)
    }
}

// MARK: - string

extension DatabaseUUIDEncodingStrategyTests {
    func testString() {
        testNullEncoding(strategy: StrategyString.self)
        
        test(
            strategy: StrategyString.self,
            encodesUUID: UUID(uuidString: "61626364-6566-6768-696A-6B6C6D6E6F70")!,
            as: "61626364-6566-6768-696A-6B6C6D6E6F70")
        
        test(
            strategy: StrategyString.self,
            encodesUUID: UUID(uuidString: "56e7d8d3-e9e4-48b6-968e-8d102833af00")!,
            as: "56E7D8D3-E9E4-48B6-968E-8D102833AF00")
        
        let uuid = UUID()
        test(
            strategy: StrategyString.self,
            encodesUUID: uuid,
            as: uuid.uuidString.uppercased()) // Assert stable casing
    }
}
