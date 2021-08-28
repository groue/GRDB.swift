import XCTest
import Foundation
@testable import GRDB

private struct UseDefaultKeysRecord: PersistableRecord, Encodable {
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .useDefaultKeys }
    var recordID: String
}

private struct ConvertToSnakeCaseRecord: PersistableRecord, Encodable {
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }
    var recordID: String
}

class DatabaseColumnEncodingStrategyTests: GRDBTestCase {
    func testUseDefaultKeys() {
        let record = UseDefaultKeysRecord(recordID: "test")

        var container = PersistenceContainer()
        record.encode(to: &container)
        XCTAssertNil(container["record_id"]?.databaseValue.storage)
        XCTAssertEqual(container["recordID"]?.databaseValue.storage, "test".databaseValue.storage)
    }

    func testConvertToSnakeCase() {
        let record = ConvertToSnakeCaseRecord(recordID: "test")

        var container = PersistenceContainer()
        record.encode(to: &container)
        XCTAssertNil(container["recordID"]?.databaseValue.storage)
        XCTAssertEqual(container["record_id"]?.databaseValue.storage, "test".databaseValue.storage)
    }
}
