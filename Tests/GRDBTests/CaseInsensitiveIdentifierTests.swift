import XCTest
@testable import GRDB

class CaseInsensitiveIdentifierTests: XCTestCase {
    func testCasePreserving() {
        let identifier = CaseInsensitiveIdentifier(rawValue: "tableName")
        XCTAssertEqual(identifier.rawValue, "tableName")
    }
    
    func testCaseInsensitiveEquality() {
        let identifier = CaseInsensitiveIdentifier(rawValue: "tableName")
        XCTAssertEqual(identifier, CaseInsensitiveIdentifier(rawValue: "tableName"))
        XCTAssertEqual(identifier, CaseInsensitiveIdentifier(rawValue: "tablename"))
        XCTAssertEqual(identifier, CaseInsensitiveIdentifier(rawValue: "TABLENAME"))
        XCTAssertNotEqual(identifier, CaseInsensitiveIdentifier(rawValue: "foo"))
        XCTAssertNotEqual(identifier, CaseInsensitiveIdentifier(rawValue: "tableName2"))
    }
    
    func testCaseInsensitiveHash() {
        func hashValue<T: Hashable>(_ value: T) -> Int {
            var hasher = Hasher()
            hasher.combine(value)
            return hasher.finalize()
        }
        let identifier = CaseInsensitiveIdentifier(rawValue: "tableName")
        XCTAssertEqual(hashValue(identifier), hashValue(CaseInsensitiveIdentifier(rawValue: "tableName")))
        XCTAssertEqual(hashValue(identifier), hashValue(CaseInsensitiveIdentifier(rawValue: "tablename")))
        XCTAssertEqual(hashValue(identifier), hashValue(CaseInsensitiveIdentifier(rawValue: "TABLENAME")))
        XCTAssertNotEqual(hashValue(identifier), hashValue(CaseInsensitiveIdentifier(rawValue: "foo")))
        XCTAssertNotEqual(hashValue(identifier), hashValue(CaseInsensitiveIdentifier(rawValue: "tableName2")))
    }
    
    func testSet() {
        let set: Set = [
            CaseInsensitiveIdentifier(rawValue: ""),
            CaseInsensitiveIdentifier(rawValue: "a"),
            CaseInsensitiveIdentifier(rawValue: "A"),
            CaseInsensitiveIdentifier(rawValue: "id"),
            CaseInsensitiveIdentifier(rawValue: "ID"),
            CaseInsensitiveIdentifier(rawValue: "foo"),
            CaseInsensitiveIdentifier(rawValue: "FOO"),
            CaseInsensitiveIdentifier(rawValue: "score"),
            CaseInsensitiveIdentifier(rawValue: "Score"),
            CaseInsensitiveIdentifier(rawValue: "tablename"),
            CaseInsensitiveIdentifier(rawValue: "tableName"),
            CaseInsensitiveIdentifier(rawValue: "someReasonablyLongDatabaseIdentifier"),
            CaseInsensitiveIdentifier(rawValue: "someReasonablyLongDatabaseIdentifier"),
            CaseInsensitiveIdentifier(rawValue: "someReasonablyLongDatabaseIdentifiex"),
            CaseInsensitiveIdentifier(rawValue: "xomeReasonablyLongDatabaseIdentifier"),
        ]
        XCTAssertEqual(set.count, 9)
        XCTAssertEqual(Set(set.map { $0.rawValue.lowercased() }), [
            "",
            "a",
            "id",
            "foo",
            "score",
            "tablename",
            "somereasonablylongdatabaseidentifier",
            "somereasonablylongdatabaseidentifiex",
            "xomereasonablylongdatabaseidentifier",
        ])
    }
    
    func testDictionary() {
        let dictionary = [CaseInsensitiveIdentifier(rawValue: "foo"): 1]
        XCTAssertEqual(dictionary[CaseInsensitiveIdentifier(rawValue: "foo")], 1)
        XCTAssertEqual(dictionary[CaseInsensitiveIdentifier(rawValue: "FOO")], 1)
        XCTAssertEqual(dictionary[CaseInsensitiveIdentifier(rawValue: "bar")], nil)
    }
}
