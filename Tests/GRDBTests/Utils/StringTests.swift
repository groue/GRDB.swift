import XCTest
import GRDB

class StringTests: GRDBTestCase {
    
    func testWrappingPlainIdentifier() throws {
        let input = "identifier"
        let result = input.quotedDatabaseIdentifier
        XCTAssertEqual("\"identifier\"", result)
    }
    
    func testWrappingIdentifierContainingQuotes() throws {
        let input = "\"ident\"ifier"
        let result = input.quotedDatabaseIdentifier
        XCTAssertEqual("\"\"\"ident\"\"ifier\"", result)
    }
}
