import XCTest
@testable import GRDB

class BackupTestCase: GRDBTestCase {
    
    // A "user" error simply for testing purposes
    private struct AbandonBackupError: Error {}
    
    private func setupBackupSource(_ writer: some DatabaseWriter) throws -> Int {
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
    
    private func setupBackupDestination(_ writer: some DatabaseWriter) throws {
        try writer.write { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO items (id) VALUES (1)")
        }
    }
    
    func testDatabaseWriterBackup(from source: some DatabaseWriter, to destination: some DatabaseWriter) throws {
        let sourceDbPageCount = try setupBackupSource(source)
        try setupBackupDestination(destination)

        XCTAssertThrowsError(
            try source.backup(to: destination, pagesPerStep: 1) { progress in
                XCTAssertLessThan(progress.completedPageCount, progress.totalPageCount)
                XCTAssertFalse(progress.isCompleted)
                throw AbandonBackupError()
            }
        )

        try destination.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT id FROM items")!, 1)
        }

        var progressCount: Int = 1
        var isCompleted: Bool = false
        try source.backup(to: destination, pagesPerStep: 1) { progress in
            let expectedCompletedPages = progressCount
            XCTAssertEqual(expectedCompletedPages, progress.completedPageCount)
            if progress.completedPageCount != progress.totalPageCount {
                progressCount += 1
            }
            if progress.isCompleted {
                isCompleted = true
                // Should not re-throw
                throw AbandonBackupError()
            }
        }
        
        XCTAssertEqual(sourceDbPageCount, progressCount)
        XCTAssertTrue(isCompleted)
        
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
    
    func testDatabaseBackup(from source: some DatabaseWriter, to destination: some DatabaseWriter) throws {
        let sourceDbPageCount = try setupBackupSource(source)
        try setupBackupDestination(destination)

        try source.read { sourceDb in
            try destination.barrierWriteWithoutTransaction { destDb in
                XCTAssertThrowsError(
                    try sourceDb.backup(to: destDb, pagesPerStep: 1) { progress in
                        XCTAssertLessThan(progress.completedPageCount, progress.totalPageCount)
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

        try source.read { dbSource in
            try destination.barrierWriteWithoutTransaction { dbDest in
                var progressCount: Int = 1
                var isCompleted: Bool = false
                try dbSource.backup(to: dbDest, pagesPerStep: 1) { progress in
                    let expectedCompletedPages = progressCount
                    XCTAssertEqual(expectedCompletedPages, progress.completedPageCount)
                    if progress.completedPageCount != progress.totalPageCount {
                        progressCount += 1
                    }
                    if progress.isCompleted {
                        isCompleted = true
                        // Should not re-throw
                        throw AbandonBackupError()
                    }
                }
                
                XCTAssertEqual(sourceDbPageCount, progressCount)
                XCTAssertTrue(isCompleted)
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
    
    // Test passes if it compiles.
    // See <https://github.com/groue/GRDB.swift/issues/1541>
    func testBackupToAnyDatabaseWriter(
        _ reader: some DatabaseReader,
        destination: any DatabaseWriter
    ) throws {
        try reader.backup(to: destination)
    }
}
