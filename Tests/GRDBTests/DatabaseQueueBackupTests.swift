import XCTest
@testable import GRDB

class DatabaseQueueBackupTests: GRDBTestCase {

    func testBackup() throws {
        // SQLCipher can't backup encrypted databases: use a pristine Configuration
        let source = try makeDatabaseQueue(filename: "source.sqlite", configuration: Configuration())
        let destination = try makeDatabaseQueue(filename: "destination.sqlite", configuration: Configuration())
        
        var pageCount: Int = 0
        try source.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
            pageCount = try Int.fetchOne(db, sql: "PRAGMA page_count")!
        }
        
        XCTAssert(pageCount > 0)
        
        var progressCount: Int = 1
        try source.backup(to: destination, pageStepSize: 1) { progress in
            let expectedCompletedPages = Int64(progressCount)
            XCTAssertEqual(expectedCompletedPages, progress.completedUnitCount)
            if !progress.isFinished {
                progressCount += 1
            }
        }
        
        XCTAssertEqual(pageCount, progressCount)
        
        try destination.inDatabase { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
        }
        
        try source.inDatabase { db in
            try db.execute(sql: "DROP TABLE items")
        }
        
        try source.backup(to: destination)
        
        try destination.inDatabase { db in
            XCTAssertFalse(try db.tableExists("items"))
        }
    }
}
