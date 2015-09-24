import XCTest
import GRDB

class NSDataTests: GRDBTestCase {
    
    func testMemoryBehavior() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE datas (data BLOB)")
                
                let data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
                try db.execute("INSERT INTO datas (data) VALUES (?)", arguments: [data])
                
                for row in Row.fetch(db, "SELECT * FROM datas") {
                    // This data should hold a copy of SQLite data. This can not be tested here: test it at runtime with a breakpoint.
                    //
                    // At commit 1022309f8079ed5072a92e340a1eab913d4f7d23, the data is actually copied *twice*.
                    // This is not very efficient (TODO).
                    //
                    // The reason for it is:
                    // 1. NSData does not adopt SQLiteStatementConvertible because the protocol can't be adopted by non-final classes.
                    //    (Maybe we can do something about it)
                    // 2. Thus the value extraction of plain DatabaseValueConvertible is invoked.
                    // 3. This involves creating a DatabaseValue, which makes a first copy of the data into a stand-alone Blob.
                    // 4. The returned NSData returns a (second) copy of this Blob's data.
                    let copiedData1: NSData = row.value(atIndex: 0)
                    XCTAssertEqual(copiedData1, data)
                    
                    // This data should hold a copy of the blob data.
                    let blob: Blob = row.value(atIndex: 0)
                    let copiedData2 = blob.data
                    XCTAssertEqual(copiedData2, data)
                    XCTAssertNotEqual(copiedData2.bytes, blob.bytes)
                    
                    // This data does not hold any copy, but the code is ugly (TODO).
                    let nonCopiedData = NSData(bytesNoCopy: UnsafeMutablePointer(blob.bytes), length: blob.length, freeWhenDone: false)
                    XCTAssertEqual(nonCopiedData, data)
                }
            }
        }
    }
}
