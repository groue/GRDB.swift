import XCTest
import GRDB

class NSDataTests: GRDBTestCase {
    
    func testDatabaseValueCanNotStoreEmptyData() {
        // SQLite can't store zero-length blob.
        let databaseValue = DatabaseValue(NSData())
        XCTAssertEqual(databaseValue, DatabaseValue.Null)
    }
}
