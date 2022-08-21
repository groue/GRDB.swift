import GRDB

class DatabasePoolBackupTests: BackupTestCase {
    
    func testDatabaseWriterBackup() throws {
        // SQLCipher can't backup encrypted databases: use a pristine Configuration
        let source = try makeDatabasePool(filename: "source.sqlite", configuration: Configuration())
        let destination = try makeDatabasePool(filename: "destination.sqlite", configuration: Configuration())
        try testDatabaseWriterBackup(from: source, to: destination)
    }
    
    func testDatabaseBackup() throws {
        let source = try makeDatabasePool(filename: "source.sqlite", configuration: Configuration())
        let destination = try makeDatabasePool(filename: "destination.sqlite", configuration: Configuration())
        try testDatabaseBackup(from: source, to: destination)
    }
    
    // TODO: fix flaky test
//    func testConcurrentWriteDuringBackup() throws {
//        let source = try makeDatabasePool(filename: "source.sqlite")
//        let destination = try makeDatabasePool(filename: "destination.sqlite")
//        
//        try source.write { db in
//            try db.execute(sql: "CREATE TABLE item (id INTEGER PRIMARY KEY)")
//            try db.execute(sql: "INSERT INTO item (id) VALUES (NULL)")
//            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item")!, 1)
//        }
//        
//        let s1 = DispatchSemaphore(value: 0)
//        let s2 = DispatchSemaphore(value: 0)
//        DispatchQueue.global().async {
//            _ = s1.wait(timeout: .distantFuture)
//            try! source.writeInTransaction(.immediate) { db in
//                try db.execute(sql: "INSERT INTO item (id) VALUES (NULL)")
//                s2.signal()
//                return .commit
//            }
//        }
//        
//        try destination.writeWithoutTransaction { dbDestination in
//            try source.backup(
//                to: dbDestination,
//                afterBackupInit: {
//                    s1.signal()
//                    _ = s2.wait(timeout: .distantFuture)
//            },
//                afterBackupStep: {
//                    try! source.write { db in
//                        try db.execute(sql: "INSERT INTO item (id) VALUES (NULL)")
//                    }
//            })
//        }
//        
//        try source.read { db in
//            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item")!, 3)
//        }
//        try destination.read { db in
//            // TODO: understand why the fix for https://github.com/groue/GRDB.swift/issues/102
//            // had this value change from 2 to 1.
//            // TODO: Worse, this test is fragile. I've seen not 1 but 2 once.
//            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item")!, 1)
//        }
//    }
}
