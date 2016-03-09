import XCTest
import GRDB

class DatabasePoolTests: GRDBTestCase {
    
    func testBasicWriteRead() {
        assertNoError {
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
            }
            let id = dbPool.read { db in
                Int.fetchOne(db, "SELECT id FROM items")!
            }
            XCTAssertEqual(id, 1)
        }
    }
    
}
