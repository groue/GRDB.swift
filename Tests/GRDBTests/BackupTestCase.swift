import XCTest
@testable import GRDB

class BackupTestCase: GRDBTestCase {
    
    // A "user" error simply for testing purposes
    private class AbandonBackupError: Error {}
    
    private func setupBackupSource(_ writer: DatabaseWriter) throws -> Int {
        try writer.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO items (id) VALUES (0)")
        }
        
        let pageCount: Int = try writer.read { db in
            try Int.fetchOne(db, sql: "PRAGMA page_count")!
        }
        
        // pageCount must be greater than 1 to allow for incremental backup testing
        XCTAssertGreaterThan(pageCount, 1)
        
        return pageCount
    }
    
    private func setupBackupDestination(_ writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO items (id) VALUES (1)")
        }
    }
    
    func testDatabaseWriterBackup(from source: DatabaseWriter, to destination: DatabaseWriter) throws {
        let sourceDbPageCount = try setupBackupSource(source)
        try setupBackupDestination(destination)

        XCTAssertThrowsError(
            try source.backup(to: destination, pageStepSize: 1) { completedPages, totalPages in
                XCTAssertLessThan(completedPages, totalPages)
                throw AbandonBackupError()
            }
        )

        // Assert that the items table is as it was before the backup was abandoned.
        // Is this a valid assertion?
        try destination.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT id FROM items")!, 1)
        }

        var progressCount: Int = 1
        try source.backup(to: destination, pageStepSize: 1) { completedPages, totalPages in
            let expectedCompletedPages = progressCount
            XCTAssertEqual(expectedCompletedPages, completedPages)
            if completedPages != totalPages {
                progressCount += 1
            } else {
                // Should not re-throw since completedPages == totalPages
                throw AbandonBackupError()
            }
        }
        
        XCTAssertEqual(sourceDbPageCount, progressCount)
        
        try destination.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT id FROM items")!, 0)
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
        try setupBackupDestination(destination)

        try source.write { dbSource in
            try destination.barrierWriteWithoutTransaction { dbDest in
                XCTAssertThrowsError(
                    try dbSource.backup(to: dbDest, pageStepSize: 1) { completedPages, totalPages in
                        XCTAssertLessThan(completedPages, totalPages)
                        throw AbandonBackupError()
                    }
                )
            }
        }

        // Assert that the items table is as it was before the backup was abandoned.
        // Is this a valid assertion?
        try destination.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT id FROM items")!, 1)
        }

        try source.write { dbSource in
            try destination.barrierWriteWithoutTransaction { dbDest in
                var progressCount: Int = 1
                try dbSource.backup(to: dbDest, pageStepSize: 1) { completedPages, totalPages in
                    let expectedCompletedPages = progressCount
                    XCTAssertEqual(expectedCompletedPages, completedPages)
                    if completedPages != totalPages {
                        progressCount += 1
                    } else {
                        // Should not re-throw since completedPages == totalPages
                        throw AbandonBackupError()
                    }
                }
                
                XCTAssertEqual(sourceDbPageCount, progressCount)
            }
        }
        
        try destination.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT id FROM items")!, 0)
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
