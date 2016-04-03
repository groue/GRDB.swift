import XCTest
import GRDBCipher

class EncryptionTests: GRDBTestCase {
    
    func testDatabaseQueueWithPassphraseToDatabaseQueueWithPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.execute("CREATE TABLE data (value INTEGER)")
                try dbQueue.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                XCTAssertEqual(Int.fetchOne(dbQueue, "SELECT value FROM data")!, 1)
            }
        }
    }
    
    func testDatabaseQueueWithPassphraseToDatabaseQueueWithoutPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.execute("CREATE TABLE data (value INTEGER)")
                try dbQueue.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            do {
                dbConfiguration.passphrase = nil
                do {
                    _ = try makeDatabaseQueue()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 26) // SQLITE_NOTADB
                    XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                    XCTAssertTrue(error.sql == nil)
                    XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
                }
            }
        }
    }
    
    func testDatabaseQueueWithPassphraseToDatabaseQueueWithWrongPassphrase() {
        assertNoError {
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.execute("CREATE TABLE data (value INTEGER)")
                try dbQueue.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            do {
                dbConfiguration.passphrase = "wrong"
                do {
                    _ = try makeDatabaseQueue()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 26) // SQLITE_NOTADB
                    XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                    XCTAssertTrue(error.sql == nil)
                    XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
                }
            }
        }
    }
    
    func testDatabaseQueueWithPassphraseToDatabasePoolWithPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.execute("CREATE TABLE data (value INTEGER)")
                try dbQueue.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                XCTAssertEqual(Int.fetchOne(dbPool, "SELECT value FROM data")!, 1)
            }
        }
    }
    
    func testDatabaseQueueWithPassphraseToDatabasePoolWithoutPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.execute("CREATE TABLE data (value INTEGER)")
                try dbQueue.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            do {
                dbConfiguration.passphrase = nil
                do {
                    _ = try makeDatabasePool()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 26) // SQLITE_NOTADB
                    XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                    XCTAssertTrue(error.sql == nil)
                    XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
                }
            }
        }
    }
    
    func testDatabaseQueueWithPassphraseToDatabasePoolWithWrongPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.execute("CREATE TABLE data (value INTEGER)")
                try dbQueue.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            do {
                dbConfiguration.passphrase = "wrong"
                do {
                    _ = try makeDatabasePool()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 26) // SQLITE_NOTADB
                    XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                    XCTAssertTrue(error.sql == nil)
                    XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
                }
            }
        }
    }
    
    func testDatabasePoolWithPassphraseToDatabasePoolWithPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                try dbPool.execute("CREATE TABLE data (value INTEGER)")
                try dbPool.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                XCTAssertEqual(Int.fetchOne(dbPool, "SELECT value FROM data")!, 1)
            }
        }
    }
    
    func testDatabasePoolWithPassphraseToDatabasePoolWithoutPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                try dbPool.execute("CREATE TABLE data (value INTEGER)")
                try dbPool.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            do {
                dbConfiguration.passphrase = nil
                do {
                    _ = try makeDatabasePool()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 26) // SQLITE_NOTADB
                    XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                    XCTAssertTrue(error.sql == nil)
                    XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
                }
            }
        }
    }
    
    func testDatabasePoolWithPassphraseToDatabasePoolWithWrongPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                try dbPool.execute("CREATE TABLE data (value INTEGER)")
                try dbPool.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            do {
                dbConfiguration.passphrase = "wrong"
                do {
                    _ = try makeDatabasePool()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 26) // SQLITE_NOTADB
                    XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                    XCTAssertTrue(error.sql == nil)
                    XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
                }
            }
        }
    }
    
    func testDatabaseQueueWithPragmaPassphraseToDatabaseQueueWithPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = nil
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.execute("PRAGMA key = 'secret'")
                try dbQueue.execute("CREATE TABLE data (value INTEGER)")
                try dbQueue.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                XCTAssertEqual(Int.fetchOne(dbQueue, "SELECT value FROM data")!, 1)
            }
        }
    }
}
