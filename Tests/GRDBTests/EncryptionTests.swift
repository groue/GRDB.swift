#if SQLITE_HAS_CODEC
import XCTest
import GRDBCipher

class EncryptionTests: GRDBTestCase {
    
    func testDatabaseQueueWithPassphraseToDatabaseQueueWithPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabaseQueueWithoutPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = nil
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabaseQueueWithWrongPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = "wrong"
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabaseQueueWithNewPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.change(passphrase: "newSecret")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
            }
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            dbConfiguration.passphrase = "newSecret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithoutPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = nil
            do {
                _ = try makeDatabasePool(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithWrongPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = "wrong"
            do {
                _ = try makeDatabasePool(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithNewPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.change(passphrase: "newSecret")
            try dbPool.write { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            dbConfiguration.passphrase = "newSecret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithoutPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = nil
            do {
                _ = try makeDatabasePool(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is not a database")
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithWrongPassphrase() throws {
        do {
            dbConfiguration.passphrase = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = "wrong"
            do {
                _ = try makeDatabasePool(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is not a database")
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithNewPassphrase() throws {
        
        do {
            dbConfiguration.passphrase = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = "secret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.change(passphrase: "newSecret")
            try dbPool.write { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            dbConfiguration.passphrase = "newSecret"
            let dbPool = try makeDatabasePool(filename: "test.sqlite")
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabaseQueueWithPragmaPassphraseToDatabaseQueueWithPassphrase() throws {
        do {
            dbConfiguration.passphrase = nil
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "PRAGMA key = 'secret'")
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithPragmaPassphraseToDatabaseQueueWithoutPassphrase() throws {
        do {
            dbConfiguration.passphrase = nil
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "PRAGMA key = 'secret'")
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            dbConfiguration.passphrase = nil
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is not a database")
            }
        }
    }
    
    func testCipherPageSize() throws {
        do {
            dbConfiguration.passphrase = "secret"
            dbConfiguration.prepareDatabase = { db in
                try db.execute(sql: "PRAGMA cipher_page_size = 8192")
            }
            
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase({ db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA cipher_page_size")!, 8192)
            })
        }
        
        do {
            dbConfiguration.passphrase = "secret"
            dbConfiguration.prepareDatabase = { db in
                try db.execute(sql: "PRAGMA cipher_page_size = 4096")
            }
            
            let dbPool = try makeDatabasePool(filename: "testpool.sqlite")
            try dbPool.write({ db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA cipher_page_size")!, 4096)
                try db.execute(sql: "CREATE TABLE data(value INTEGER)")
                try db.execute(sql: "INSERT INTO data(value) VALUES(1)")
            })
            try dbPool.read({ db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA cipher_page_size")!, 4096)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT value FROM data"), 1)
            })
            
        }
    }
    
    func testCipherKDFIterations() throws {
        do {
            dbConfiguration.passphrase = "secret"
            dbConfiguration.prepareDatabase = { db in
                try db.execute(sql: "PRAGMA kdf_iter = 128000")
            }
            
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA kdf_iter"), 128000)
            }
        }

        do {
            dbConfiguration.passphrase = "secret"
            dbConfiguration.prepareDatabase = { db in
                try db.execute(sql: "PRAGMA kdf_iter = 128000")
            }

            let dbPool = try makeDatabasePool(filename: "testpool.sqlite")
            try dbPool.write { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA kdf_iter"), 128000)
                try db.execute(sql: "CREATE TABLE data(value INTEGER)")
                try db.execute(sql: "INSERT INTO data(value) VALUES(1)")
            }
            
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA kdf_iter"), 128000)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT value FROM data"), 1)
            }
        }
    }

    func testCipherWithMismatchedKDFIterations() throws {
        do {
            dbConfiguration.passphrase = "secret"
            dbConfiguration.prepareDatabase = { db in
                try db.execute(sql: "PRAGMA kdf_iter = 128000")
            }

            let dbPool = try makeDatabasePool(filename: "testpool.sqlite")
            try dbPool.write { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA kdf_iter"), 128000)
                try db.execute(sql: "CREATE TABLE data(value INTEGER)")
                try db.execute(sql: "INSERT INTO data(value) VALUES(1)")
            }

            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA kdf_iter"), 128000)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT value FROM data"), 1)
            }
        }

        do {
            dbConfiguration.passphrase = "secret"
            dbConfiguration.prepareDatabase = { db in
                try db.execute(sql: "PRAGMA kdf_iter = 64000")
            }

            do {
                let dbPool = try makeDatabasePool(filename: "testpool.sqlite")

                try dbPool.read { db in
                    XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA kdf_iter"), 64000)
                    XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT value FROM data"), 1)
                }
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is not a database")
            }
        }
    }
    
    func testExportPlainTextDatabaseToEncryptedDatabase() throws {
        // See https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/868?source_topic_id=939
        do {
            // https://github.com/sqlcipher/sqlcipher/issues/216
            // SQLCipher 3.4.1 crashes when sqlcipher_export() is called and a
            // trace hook has been installed. So we disable query tracing for
            // this test.
            dbConfiguration.trace = nil
            
            dbConfiguration.passphrase = nil
            let plainTextDBQueue = try makeDatabaseQueue(filename: "plaintext.sqlite")
            try plainTextDBQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
            
            dbConfiguration.passphrase = "secret"
            do {
                _ = try makeDatabaseQueue(filename: "plaintext.sqlite")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is not a database")
            }
            
            let encryptedDBQueue = try makeDatabaseQueue(filename: "encrypted.sqlite")
            
            try plainTextDBQueue.inDatabase { db in
                try db.execute(sql: "ATTACH DATABASE ? AS encrypted KEY ?", arguments: [encryptedDBQueue.path, "secret"])
                try db.execute(sql: "SELECT sqlcipher_export('encrypted')")
                try db.execute(sql: "DETACH DATABASE encrypted")
            }
        }
        
        do {
            dbConfiguration.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "encrypted.sqlite")
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }
}
#endif
