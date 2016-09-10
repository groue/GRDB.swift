import XCTest
import GRDBCipher

class EncryptionTests: GRDBTestCase {
    
    func testDatabaseQueueWithPassphraseToDatabaseQueueWithPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                dbQueue.inDatabase { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 1)
                }
            }
        }
    }
    
    func testDatabaseQueueWithPassphraseToDatabaseQueueWithoutPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
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
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
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
    
    func testDatabaseQueueWithPassphraseToDatabaseQueueWithNewPassphrase() {
        assertNoError {
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.change(passphrase: "newSecret")
                try dbQueue.inDatabase { db in
                    try db.execute("INSERT INTO data (value) VALUES (2)")
                }
                dbQueue.inDatabase { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
                }
            }
            
            do {
                dbConfiguration.passphrase = "newSecret"
                let dbQueue = try makeDatabaseQueue()
                dbQueue.inDatabase { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
                }
            }
        }
    }
    
    func testDatabaseQueueWithPassphraseToDatabasePoolWithPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                dbPool.read { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 1)
                }
            }
        }
    }
    
    func testDatabaseQueueWithPassphraseToDatabasePoolWithoutPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
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
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
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
    
    func testDatabaseQueueWithPassphraseToDatabasePoolWithNewPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                try dbPool.change(passphrase: "newSecret")
                try dbPool.write { db in
                    try db.execute("INSERT INTO data (value) VALUES (2)")
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
                }
            }
            
            do {
                dbConfiguration.passphrase = "newSecret"
                let dbPool = try makeDatabasePool()
                dbPool.read { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
                }
            }
        }
    }
    
    func testDatabasePoolWithPassphraseToDatabasePoolWithPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                try dbPool.write { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                dbPool.read { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 1)
                }
            }
        }
    }
    
    func testDatabasePoolWithPassphraseToDatabasePoolWithoutPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                try dbPool.write { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
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
                try dbPool.write { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
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
    
    func testDatabasePoolWithPassphraseToDatabasePoolWithNewPassphrase() {
        assertNoError {
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                try dbPool.write { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbPool = try makeDatabasePool()
                try dbPool.change(passphrase: "newSecret")
                try dbPool.write { db in
                    try db.execute("INSERT INTO data (value) VALUES (2)")
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
                }
            }
            
            do {
                dbConfiguration.passphrase = "newSecret"
                let dbPool = try makeDatabasePool()
                dbPool.read { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
                }
            }
        }
    }
    
    func testDatabaseQueueWithPragmaPassphraseToDatabaseQueueWithPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = nil
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.inDatabase { db in
                    try db.execute("PRAGMA key = 'secret'")
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue()
                dbQueue.inDatabase { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 1)
                }
            }
        }
    }
    
    func testDatabaseQueueWithPragmaPassphraseToDatabaseQueueWithoutPassphrase() {
        assertNoError {
            do {
                dbConfiguration.passphrase = nil
                let dbQueue = try makeDatabaseQueue()
                try dbQueue.inDatabase { db in
                    try db.execute("PRAGMA key = 'secret'")
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
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
    
    func testExportPlainTextDatabaseToEncryptedDatabase() {
        // See https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/868?source_topic_id=939
        assertNoError {
            do {
                dbConfiguration.passphrase = nil
                let plainTextDBQueue = try makeDatabaseQueue(filename: "plaintext.sqlite")
                try plainTextDBQueue.inDatabase { db in
                    try db.execute("CREATE TABLE data (value INTEGER)")
                    try db.execute("INSERT INTO data (value) VALUES (1)")
                }
                
                dbConfiguration.passphrase = "secret"
                do {
                    _ = try makeDatabaseQueue(filename: "plaintext.sqlite")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 26) // SQLITE_NOTADB
                    XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                    XCTAssertTrue(error.sql == nil)
                    XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
                }
                
                let encryptedDBQueue = try makeDatabaseQueue(filename: "encrypted.sqlite")
                
                try plainTextDBQueue.inDatabase { db in
                    try db.execute("ATTACH DATABASE ? AS encrypted KEY ?", arguments: [encryptedDBQueue.path, "secret"])
                    try db.execute("SELECT sqlcipher_export('encrypted')")
                    try db.execute("DETACH DATABASE encrypted")
                }
            }
            
            do {
                dbConfiguration.passphrase = "secret"
                let dbQueue = try makeDatabaseQueue(filename: "encrypted.sqlite")
                dbQueue.inDatabase { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 1)
                }
            }
        }
    }
    
}
