import XCTest
@testable import GRDB

class BackupTestCase: GRDBTestCase {
    
    func setupBackupSource(_ writer: DatabaseWriter) throws -> Int {
        try writer.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
        }
        
        let pageCount: Int = try writer.read { db in
            try Int.fetchOne(db, sql: "PRAGMA page_count")!
        }
        
        XCTAssert(pageCount > 0)
        
        return pageCount
    }
    
    func testDatabaseWriterBackup(from source: DatabaseWriter, to destination: DatabaseWriter) throws {
        let sourceDbPageCount = try setupBackupSource(source)
        var progressCount: Int = 1
        try source.backup(to: destination, pageStepSize: 1) { progress in
            let expectedCompletedPages = progressCount
            XCTAssertEqual(expectedCompletedPages, progress.completedPages)
            if !progress.isFinished {
                progressCount += 1
            }
        }
        
        XCTAssertEqual(sourceDbPageCount, progressCount)
        
        try destination.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
        }
        
        try source.write { db in
            try db.execute(sql: "DROP TABLE items")
        }
        
        try source.backup(to: destination)
        
        try destination.read { db in
            XCTAssertFalse(try db.tableExists("items"))
        }
    }
    
    func testDatabaseBackup(from source: DatabaseWriter, to destination: DatabaseWriter) throws {
        let sourceDbPageCount = try setupBackupSource(source)
        try source.write { dbSource in
            try destination.barrierWriteWithoutTransaction { dbDest in
                var progressCount: Int = 1
                try dbSource.backup(to: dbDest, pageStepSize: 1) { progress in
                    let expectedCompletedPages = progressCount
                    XCTAssertEqual(expectedCompletedPages, progress.completedPages)
                    if !progress.isFinished {
                        progressCount += 1
                    }
                }
                
                XCTAssertEqual(sourceDbPageCount, progressCount)
            }
        }
        
        try destination.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
        }
        
        try source.write { db in
            try db.execute(sql: "DROP TABLE items")
        }
        
        try source.backup(to: destination)
        
        try destination.read { db in
            XCTAssertFalse(try db.tableExists("items"))
        }
    }
}
