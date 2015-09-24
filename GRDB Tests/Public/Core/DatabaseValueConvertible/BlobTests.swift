import XCTest
import GRDB

class BlobTests: GRDBTestCase {
    
    func testBlobCanNotStoreEmptyData() {
        // SQLite can't store zero-length blob.
        let blob = Blob(data: NSData())
        XCTAssertTrue(blob == nil)
    }
    
    func testBlobCanNotStoreZeroLengthBuffer() {
        // SQLite can't store zero-length blob.
        let blob = Blob(bytes: nil, length: 0)
        XCTAssertTrue(blob == nil)
    }
    
    func testMemoryBehavior() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE datas (data BLOB)")
                
                let data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
                try db.execute("INSERT INTO datas (data) VALUES (?)", arguments: [data])
                
                // This blob should not copy SQLite data. This can not be tested here: test it at runtime with a breakpoint.
                for row in Row.fetch(db, "SELECT * FROM datas") {
                    let blob: Blob = row.value(atIndex: 0)
                    XCTAssertEqual(blob.data, data)
                }
                
                // This blob should have a copy of SQLite data. This can not be tested here: test it at runtime with a breakpoint.
                let row = Row.fetchOne(db, "SELECT * FROM datas")!
                let blob: Blob = row.value(atIndex: 0)
                XCTAssertEqual(blob.data, data)
            }
        }
    }
}
