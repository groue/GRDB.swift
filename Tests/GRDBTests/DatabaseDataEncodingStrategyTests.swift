import XCTest
import Foundation
@testable import GRDB

private protocol StrategyProvider {
    static var strategy: DatabaseDataEncodingStrategy { get }
}

private enum StrategyDeferredToData: StrategyProvider {
    static let strategy: DatabaseDataEncodingStrategy = .deferredToData
}

private enum StrategyTextUTF8: StrategyProvider {
    static let strategy: DatabaseDataEncodingStrategy = .text
}

private enum StrategyCustom: StrategyProvider {
    static let strategy: DatabaseDataEncodingStrategy = .custom { _ in "custom" }
}

private struct RecordWithData<Strategy: StrategyProvider>: EncodableRecord, Encodable {
    static var databaseDataEncodingStrategy: DatabaseDataEncodingStrategy { Strategy.strategy }
    var data: Data
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension RecordWithData: Identifiable {
    var id: Data { data }
}

private struct RecordWithOptionalData<Strategy: StrategyProvider>: EncodableRecord, Encodable {
    static var databaseDataEncodingStrategy: DatabaseDataEncodingStrategy { Strategy.strategy }
    var data: Data?
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension RecordWithOptionalData: Identifiable {
    var id: Data? { data }
}

class DatabaseDataEncodingStrategyTests: GRDBTestCase {
    let testedDatas = [
        "foo".data(using: .utf8)!,
        Data(),
    ]
    
    private func test<T: EncodableRecord>(
        record: T,
        expectedStorage: DatabaseValue.Storage)
    throws
    {
        var container = PersistenceContainer()
        try record.encode(to: &container)
        if let dbValue = container["data"]?.databaseValue {
            XCTAssertEqual(dbValue.storage, expectedStorage)
        } else {
            XCTAssertEqual(.null, expectedStorage)
        }
    }
    
    private func test<Strategy: StrategyProvider>(
        strategy: Strategy.Type,
        encodesData data: Data,
        as value: some DatabaseValueConvertible)
    throws
    {
        try test(record: RecordWithData<Strategy>(data: data), expectedStorage: value.databaseValue.storage)
        try test(record: RecordWithOptionalData<Strategy>(data: data), expectedStorage: value.databaseValue.storage)
    }
    
    private func testNullEncoding<Strategy: StrategyProvider>(strategy: Strategy.Type) throws {
        try test(record: RecordWithOptionalData<Strategy>(data: nil), expectedStorage: .null)
    }
}

// MARK: - deferredToData

extension DatabaseDataEncodingStrategyTests {
    func testDeferredToData() throws {
        try testNullEncoding(strategy: StrategyDeferredToData.self)
        
        for (data, value) in zip(testedDatas, [
            "foo".data(using: .utf8)!,
            Data(),
            ]) { try test(strategy: StrategyDeferredToData.self, encodesData: data, as: value) }
    }
}

// MARK: - text(UTF8)

extension DatabaseDataEncodingStrategyTests {
    func testTextUTF8() throws {
        try testNullEncoding(strategy: StrategyTextUTF8.self)
        
        for (data, value) in zip(testedDatas, [
            "foo",
            "",
            ]) { try test(strategy: StrategyTextUTF8.self, encodesData: data, as: value) }
    }
}

// MARK: - custom((Data) -> DatabaseValueConvertible?)

extension DatabaseDataEncodingStrategyTests {
    func testCustom() throws {
        try testNullEncoding(strategy: StrategyCustom.self)
        
        for (data, value) in zip(testedDatas, [
            "custom",
            "custom",
            ]) { try test(strategy: StrategyCustom.self, encodesData: data, as: value) }
    }
}

// MARK: - Filter

extension DatabaseDataEncodingStrategyTests {
    func testFilterKey() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { $0.primaryKey("id", .blob) }
            
            do {
                let request = Table<RecordWithData<StrategyDeferredToData>>("t").filter(key: testedDatas[0])
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" = x'666f6f'
                    """)
            }
            
            do {
                let request = Table<RecordWithData<StrategyDeferredToData>>("t").filter(keys: testedDatas)
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" IN (x'666f6f', x'')
                    """)
            }
            
            do {
                let request = Table<RecordWithData<StrategyTextUTF8>>("t").filter(key: testedDatas[0])
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" = 'foo'
                    """)
            }
            
            do {
                let request = Table<RecordWithData<StrategyTextUTF8>>("t").filter(keys: testedDatas)
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" IN ('foo', '')
                    """)
            }
        }
    }
    
    func testFilterID() throws {
        guard #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Identifiable not available")
        }
        
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { $0.primaryKey("id", .blob) }
            
            do {
                let request = Table<RecordWithData<StrategyDeferredToData>>("t").filter(id: testedDatas[0])
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" = x'666f6f'
                    """)
            }
            
            do {
                let request = Table<RecordWithData<StrategyDeferredToData>>("t").filter(ids: testedDatas)
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" IN (x'666f6f', x'')
                    """)
            }
            
            do {
                let request = Table<RecordWithData<StrategyTextUTF8>>("t").filter(id: testedDatas[0])
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" = 'foo'
                    """)
            }
            
            do {
                let request = Table<RecordWithData<StrategyTextUTF8>>("t").filter(ids: testedDatas)
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" IN ('foo', '')
                    """)
            }
            
            do {
                let request = Table<RecordWithOptionalData<StrategyDeferredToData>>("t").filter(id: nil)
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE 0
                    """)
            }
            
            do {
                let request = Table<RecordWithOptionalData<StrategyDeferredToData>>("t").filter(id: testedDatas[0])
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" = x'666f6f'
                    """)
            }
            
            do {
                let request = Table<RecordWithOptionalData<StrategyDeferredToData>>("t").filter(ids: testedDatas)
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" IN (x'666f6f', x'')
                    """)
            }
            
            do {
                let request = Table<RecordWithOptionalData<StrategyTextUTF8>>("t").filter(id: nil)
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE 0
                    """)
            }
            
            do {
                let request = Table<RecordWithOptionalData<StrategyTextUTF8>>("t").filter(id: testedDatas[0])
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" = 'foo'
                    """)
            }
            
            do {
                let request = Table<RecordWithOptionalData<StrategyTextUTF8>>("t").filter(ids: testedDatas)
                try assertEqualSQL(db, request, """
                    SELECT * FROM "t" WHERE "id" IN ('foo', '')
                    """)
            }
        }
    }
    
    func testDeleteID() throws {
        guard #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Identifiable not available")
        }
        
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { $0.primaryKey("id", .blob) }
            
            do {
                try Table<RecordWithData<StrategyDeferredToData>>("t").deleteOne(db, id: testedDatas[0])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "t" WHERE "id" = x'666f6f'
                    """)
            }
            
            do {
                try Table<RecordWithData<StrategyDeferredToData>>("t").deleteAll(db, ids: testedDatas)
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "t" WHERE "id" IN (x'666f6f', x'')
                    """)
            }
            
            do {
                try Table<RecordWithData<StrategyTextUTF8>>("t").deleteOne(db, id: testedDatas[0])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "t" WHERE "id" = 'foo'
                    """)
            }
            
            do {
                try Table<RecordWithData<StrategyTextUTF8>>("t").deleteAll(db, ids: testedDatas)
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "t" WHERE "id" IN ('foo', '')
                    """)
            }
            
            do {
                sqlQueries.removeAll()
                try Table<RecordWithOptionalData<StrategyDeferredToData>>("t").deleteOne(db, id: nil)
                XCTAssertNil(lastSQLQuery) // Database not hit
            }
            
            do {
                try Table<RecordWithOptionalData<StrategyDeferredToData>>("t").deleteOne(db, id: testedDatas[0])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "t" WHERE "id" = x'666f6f'
                    """)
            }
            
            do {
                try Table<RecordWithOptionalData<StrategyDeferredToData>>("t").deleteAll(db, ids: testedDatas)
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "t" WHERE "id" IN (x'666f6f', x'')
                    """)
            }
            
            do {
                sqlQueries.removeAll()
                try Table<RecordWithOptionalData<StrategyTextUTF8>>("t").deleteOne(db, id: nil)
                XCTAssertNil(lastSQLQuery) // Database not hit
            }
            
            do {
                try Table<RecordWithOptionalData<StrategyTextUTF8>>("t").deleteOne(db, id: testedDatas[0])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "t" WHERE "id" = 'foo'
                    """)
            }
            
            do {
                try Table<RecordWithOptionalData<StrategyTextUTF8>>("t").deleteAll(db, ids: testedDatas)
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "t" WHERE "id" IN ('foo', '')
                    """)
            }
        }
    }
}
