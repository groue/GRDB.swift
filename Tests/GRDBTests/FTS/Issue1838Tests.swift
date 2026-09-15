import GRDB
import XCTest

class Issue1838Tests: GRDBTestCase {
    /// Regression test for <https://github.com/groue/GRDB.swift/issues/1838>.
    ///
    /// This test passes since <https://github.com/groue/GRDB.swift/pull/1839>
    /// which workarounds the SQLite bug described at
    /// <https://sqlite.org/forum/forumpost/95413eb410>.
    func test_interrupted_rollback() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE VIRTUAL TABLE documents USING FTS5(content)")
            try db.inTransaction {
                try db.execute(sql: "INSERT INTO documents(content) VALUES ('Document')")
                dbQueue.interrupt()
                return .rollback
            }
        }
        
        let documentCount = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents")!
        }
        XCTAssertEqual(documentCount, 0)
    }
    
    /// Tests about how we handle the FTS5 bug <https://sqlite.org/forum/forumpost/95413eb410>
    func test_interrupted_commit() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.write { db in
            try db.execute(sql: "CREATE VIRTUAL TABLE documents USING FTS5(content)")
        }
        
        do {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO documents(content) VALUES ('Document')")
                dbQueue.interrupt()
            }
            // Do not assert that the above code throws, because the
            // FTS5 bug might be fixed in the tested SQLite version.
        } catch DatabaseError.SQLITE_INTERRUPT {
            // Fine: That's the FTS5 bug.
        }
        
        // Make sure the interrupted state created by the FTS5 bug is no longer active.
        try dbQueue.read { db in
            try db.execute(sql: "SELECT COUNT(*) FROM documents")
        }
    }
}
