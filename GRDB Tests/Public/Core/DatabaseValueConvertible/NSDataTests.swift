import XCTest
import GRDB

class NSDataTests: GRDBTestCase {
    
    func testDatabaseValueCanNotStoreEmptyData() {
        // SQLite can't store zero-length blob.
        let databaseValue = NSData().databaseValue
        XCTAssertEqual(databaseValue, DatabaseValue.Null)
    }
}
