import XCTest
import GRDB

class NSDataTests: GRDBTestCase {
    
    func testDatabaseValueCanNotStoreEmptyData() {
        // SQLite can't store zero-length blob.
        let databaseValue = DatabaseValue(data: NSData())
        XCTAssertEqual(databaseValue, DatabaseValue.Null)
    }
    
    func testMemoryBehavior() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE datas (data BLOB)")
                
                let data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
                try db.execute("INSERT INTO datas (data) VALUES (?)", arguments: [data])
                
                // This blob should not copy SQLite data. This can not be tested here: test it at runtime with a breakpoint.
                for row in Row.fetch(db, "SELECT * FROM datas") {
                    // This data should be copied:
                    let copiedData: NSData = row.value(atIndex: 0)
                    XCTAssertEqual(copiedData, data)
                    
                    // This data should not be copied, and extraced raw from the sqliteStatement
                    let nonCopiedData = row.dataNoCopy(atIndex: 0)
                    XCTAssertEqual(nonCopiedData, data)
                }
                
                let row = Row.fetchOne(db, "SELECT * FROM datas")!
                
                // This data should not be copied:
                let nonCopiedData1: NSData = row.value(atIndex: 0)
                XCTAssertEqual(nonCopiedData1, data)
                
                // This data should not be copied:
                let nonCopiedData2 = row.dataNoCopy(atIndex: 0)
                XCTAssertEqual(nonCopiedData2, data)
            }
        }
    }
}
