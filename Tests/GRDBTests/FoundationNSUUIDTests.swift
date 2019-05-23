import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationNSUUIDTests: GRDBTestCase {
    private func assert(_ value: DatabaseValueConvertible?, isDecodedAs expectedUUID: NSUUID?) throws {
        try makeDatabaseQueue().read { db in
            if let expectedUUID = expectedUUID {
                let decodedUUID = try NSUUID.fetchOne(db, sql: "SELECT ?", arguments: [value])
                XCTAssertEqual(decodedUUID, expectedUUID)
            } else if value == nil {
                let decodedUUID = try Optional<NSUUID>.fetchAll(db, sql: "SELECT NULL")[0]
                XCTAssertNil(decodedUUID)
            }
        }
        
        let decodedUUID = NSUUID.fromDatabaseValue(value?.databaseValue ?? .null)
        XCTAssertEqual(decodedUUID, expectedUUID)
    }
    
    private func assertRoundTrip(_ uuid: UUID) throws {
        let string = uuid.uuidString
        var uuid_t = uuid.uuid
        let data = withUnsafeBytes(of: &uuid_t) {
            Data(bytes: $0.baseAddress!, count: $0.count)
        }
        try assert(string, isDecodedAs: uuid as NSUUID)
        try assert(string.lowercased(), isDecodedAs: uuid as NSUUID)
        try assert(string.uppercased(), isDecodedAs: uuid as NSUUID)
        try assert(uuid, isDecodedAs: uuid as NSUUID)
        try assert(uuid as NSUUID, isDecodedAs: uuid as NSUUID)
        try assert(data, isDecodedAs: uuid as NSUUID)
    }
    
    func testSuccess() throws {
        try assertRoundTrip(UUID(uuidString: "56e7d8d3-e9e4-48b6-968e-8d102833af00")!)
        try assertRoundTrip(UUID())
        try assert("abcdefghijklmnop".data(using: .utf8)!, isDecodedAs: NSUUID(uuidString: "61626364-6566-6768-696A-6B6C6D6E6F70"))
    }
    
    func testFailure() throws {
        try assert(nil, isDecodedAs: nil)
        try assert(DatabaseValue.null, isDecodedAs: nil)
        try assert(1, isDecodedAs: nil)
        try assert(100000.1, isDecodedAs: nil)
        try assert("56e7d8d3e9e448b6968e8d102833af0", isDecodedAs: nil)
        try assert("56e7d8d3-e9e4-48b6-968e-8d102833af0!", isDecodedAs: nil)
        try assert("foo", isDecodedAs: nil)
        try assert("bar".data(using: .utf8)!, isDecodedAs: nil)
        try assert("abcdefghijklmno".data(using: .utf8)!, isDecodedAs: nil)
        try assert("abcdefghijklmnopq".data(using: .utf8)!, isDecodedAs: nil)
    }
}
