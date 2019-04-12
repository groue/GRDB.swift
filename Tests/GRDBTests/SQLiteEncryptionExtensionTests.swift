#if SQLITE_HAS_CODEC && GRDB_SQLITE_SEE
import XCTest
@testable import GRDBCustomSQLite

class SQLiteEncryptionExtensionTests: GRDBTestCase {
    
    func testDatabaseQueueWithKeyToDatabaseQueueWithKey() throws {
        do {
            dbConfiguration.key = "secret"
            dbConfiguration.encryptionAlgorithm = .AES128
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.key = "secret"
            dbConfiguration.encryptionAlgorithm = .AES128
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithKeyToDatabaseQueueWithoutKey() throws {
        do {
            dbConfiguration.key = "secret"
            dbConfiguration.encryptionAlgorithm = .AES128
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = nil
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabaseQueueWithKeyToDatabaseQueueWithWrongKey() throws {
        do {
            dbConfiguration.key = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = "wrong"
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }
    
    func testDatabaseQueueWithKeyToDatabaseQueueWithWrongEncryptionAlgorithm() throws {
        do {
            dbConfiguration.key = "secret"
            dbConfiguration.encryptionAlgorithm = .AES128
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.key = "secret"
            dbConfiguration.encryptionAlgorithm = .AES256
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabaseQueueWithKeyToDatabaseQueueWithNewKeyAndAlgorithm() throws {
        do {
            dbConfiguration.key = "secret"
            dbConfiguration.encryptionAlgorithm = .AES128
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.change(key: "newSecret", encryptionAlgorithm: .AES256)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
            }
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }

        do {
            dbConfiguration.key = "newSecret"
            dbConfiguration.encryptionAlgorithm = .AES256
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabaseQueueWithKeyToDatabasePoolWithKey() throws {
        do {
            dbConfiguration.key = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithKeyToDatabasePoolWithoutKey() throws {
        do {
            dbConfiguration.key = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = nil
            do {
                _ = try makeDatabasePool(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabaseQueueWithKeyToDatabasePoolWithWrongKey() throws {
        do {
            dbConfiguration.key = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = "wrong"
            do {
                _ = try makeDatabasePool(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabaseQueueWithKeyToDatabasePoolWithNewKey() throws {
        do {
            dbConfiguration.key = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.change(key: "newSecret", encryptionAlgorithm: .AES128)
            try dbPool.write { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }

        do {
            dbConfiguration.key = "newSecret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabasePoolWithKeyToDatabasePoolWithKey() throws {
        do {
            dbConfiguration.key = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabasePoolWithKeyToDatabasePoolWithoutKey() throws {
        do {
            dbConfiguration.key = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = nil
            do {
                _ = try makeDatabasePool(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabasePoolWithKeyToDatabasePoolWithWrongKey() throws {
        do {
            dbConfiguration.key = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = "wrong"
            do {
                _ = try makeDatabasePool(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }
    
    func testDatabasePoolWithKeyToDatabasePoolWithWrongEncryptionAlgorithm() throws {
        let key = "secret"
        do {
            dbConfiguration.key = key
            dbConfiguration.encryptionAlgorithm = .AES128
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.key = key
            dbConfiguration.encryptionAlgorithm = .AES256
            do {
                _ = try makeDatabasePool(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabasePoolWithKeyToDatabasePoolWithNewKey() throws {

        do {
            dbConfiguration.key = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.change(key: "newSecret", encryptionAlgorithm: .AES128)
            try dbPool.write { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }

        do {
            dbConfiguration.key = "newSecret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabaseQueueWithPragmaKeyToDatabaseQueueWithKey() throws {
        do {
            dbConfiguration.key = nil
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "PRAGMA key = 'secret'")
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithPragmaKeyToDatabaseQueueWithoutKey() throws {
        do {
            dbConfiguration.key = nil
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "PRAGMA key = 'secret'")
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            dbConfiguration.key = nil
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }
    
    func testDatabaseQueueWithKeyToDatabaseQueueWithPragmaRemovedKeyAndType() throws {
        do {
            dbConfiguration.key = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.key = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "PRAGMA rekey = ''")
            }
        }
        
        do {
            dbConfiguration.key = nil
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

}
#endif
