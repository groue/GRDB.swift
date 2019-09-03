#if SQLITE_HAS_CODEC
import XCTest
import GRDB

class EncryptionTests: GRDBTestCase {
    
    func testDatabaseQueueWithPassphraseToDatabaseQueueWithPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabaseQueueWithoutPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite", configuration: Configuration())
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabaseQueueWithWrongPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("wrong")
            }
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }
    
    func testDatabaseQueueWithPassphraseToDatabaseQueueWithNewPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
            try dbQueue.write { db in
                try db.changePassphrase("newSecret")
            }
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
            }
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("newSecret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithoutPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            do {
                _ = try makeDatabasePool(filename: "test.sqlite", configuration: Configuration())
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithWrongPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("wrong")
            }
            do {
                _ = try makeDatabasePool(filename: "test.sqlite", configuration: config)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithNewPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var passphrase = "secret"
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase(passphrase)
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
            try dbPool.barrierWriteWithoutTransaction { db in
                passphrase = "newSecret"
                try db.changePassphrase(passphrase)
                dbPool.invalidateReadOnlyConnections()
            }
            try dbPool.write { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("newSecret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithoutPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            do {
                _ = try makeDatabasePool(filename: "test.sqlite", configuration: Configuration())
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithWrongPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("wrong")
            }
            do {
                _ = try makeDatabasePool(filename: "test.sqlite", configuration: config)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithNewPassphrase() throws {
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var passphrase = "secret"
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase(passphrase)
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
            try dbPool.barrierWriteWithoutTransaction { db in
                passphrase = "newSecret"
                try db.changePassphrase(passphrase)
                dbPool.invalidateReadOnlyConnections()
            }
            try dbPool.write { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("newSecret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabaseQueueWithPragmaPassphraseToDatabaseQueueWithPassphrase() throws {
        do {
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: Configuration())
            try dbQueue.inDatabase { db in
                try db.execute(sql: "PRAGMA key = 'secret'")
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithPragmaPassphraseToDatabaseQueueWithoutPassphrase() throws {
        do {
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: Configuration())
            try dbQueue.inDatabase { db in
                try db.execute(sql: "PRAGMA key = 'secret'")
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite", configuration: Configuration())
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }
    
    func testCipherPageSize() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
                try db.execute(sql: "PRAGMA cipher_page_size = 8192")
            }
            
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase({ db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA cipher_page_size")!, 8192)
            })
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
                try db.execute(sql: "PRAGMA cipher_page_size = 4096")
            }
            
            let dbPool = try makeDatabasePool(filename: "testpool.sqlite", configuration: config)
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
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
                try db.execute(sql: "PRAGMA kdf_iter = 128000")
            }
            
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA kdf_iter"), 128000)
            }
        }

        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
                try db.execute(sql: "PRAGMA kdf_iter = 128000")
            }

            let dbPool = try makeDatabasePool(filename: "testpool.sqlite", configuration: config)
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
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
                try db.execute(sql: "PRAGMA kdf_iter = 128000")
            }

            let dbPool = try makeDatabasePool(filename: "testpool.sqlite", configuration: config)
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
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
                try db.execute(sql: "PRAGMA kdf_iter = 64000")
            }

            do {
                let dbPool = try makeDatabasePool(filename: "testpool.sqlite", configuration: config)

                try dbPool.read { db in
                    XCTAssertEqual(try Int.fetchOne(db, sql: "PRAGMA kdf_iter"), 64000)
                    XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT value FROM data"), 1)
                }
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }
    
    func testExportPlainTextDatabaseToEncryptedDatabase() throws {
        // See https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/868?source_topic_id=939
        do {
            let plainTextDBQueue = try makeDatabaseQueue(filename: "plaintext.sqlite", configuration: Configuration())
            try plainTextDBQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
            
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            do {
                _ = try makeDatabaseQueue(filename: "plaintext.sqlite", configuration: config)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
            
            let encryptedDBQueue = try makeDatabaseQueue(filename: "encrypted.sqlite", configuration: config)
            
            try plainTextDBQueue.inDatabase { db in
                try db.execute(sql: "ATTACH DATABASE ? AS encrypted KEY ?", arguments: [encryptedDBQueue.path, "secret"])
                try db.execute(sql: "SELECT sqlcipher_export('encrypted')")
                try db.execute(sql: "DETACH DATABASE encrypted")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "encrypted.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }
    
    func testSQLCipher3Compatibility() throws {
        guard let cipherMajorVersion = try DatabaseQueue()
            .read({ try String.fetchOne($0, sql: "PRAGMA cipher_version") })
            .flatMap({ $0.split(separator: ".").first })
            .flatMap({ Int($0 )})
            else { XCTFail("Unknown SQLCipher version"); return }
        
        if cipherMajorVersion >= 4 {
            let testBundle = Bundle(for: type(of: self))
            let path = testBundle.url(forResource: "db", withExtension: "SQLCipher3")!.path
            var configuration = Configuration()
            configuration.prepareDatabase = { db in
                try db.usePassphrase("secret")
                try db.execute(sql: "PRAGMA cipher_compatibility = 3")
            }
            
            do {
                let dbQueue = try DatabaseQueue(path: path, configuration: configuration)
                let success = try dbQueue.read { try String.fetchOne($0, sql: "SELECT a FROM t") }
                XCTAssertEqual(success, "success")
            }
            
            do {
                let dbPool = try DatabasePool(path: path, configuration: configuration)
                let success = try dbPool.read { try String.fetchOne($0, sql: "SELECT a FROM t") }
                XCTAssertEqual(success, "success")
            }
        }
    }
    
    // MARK: - Deprecated
    
    func testDeprecatedPassphrase() throws {
        do {
            var config = Configuration()
            config.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }

        do {
            var config = Configuration()
            config.passphrase = "secret"
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 1)
            }
        }

        do {
            var config = Configuration()
            config.passphrase = nil
            do {
                _ = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is not a database")
            }
        }
    }
    
    func testDeprecatedDatabaseQueueWithPassphraseToDatabaseQueueWithNewPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.change(passphrase: "newSecret")
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
            }
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("newSecret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }
    
    func testDeprecatedDatabaseQueueWithPassphraseToDatabasePoolWithNewPassphrase() throws {
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbQueue = try makeDatabaseQueue(filename: "test.sqlite", configuration: config)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.change(passphrase: "newSecret")
            try dbPool.write { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("newSecret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDeprecatedDatabasePoolWithPassphraseToDatabasePoolWithNewPassphrase() throws {
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.write { db in
                try db.execute(sql: "CREATE TABLE data (value INTEGER)")
                try db.execute(sql: "INSERT INTO data (value) VALUES (1)")
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("secret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.change(passphrase: "newSecret")
            try dbPool.write { db in
                try db.execute(sql: "INSERT INTO data (value) VALUES (2)")
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            var config = Configuration()
            config.prepareDatabase = { db in
                try db.usePassphrase("newSecret")
            }
            let dbPool = try makeDatabasePool(filename: "test.sqlite", configuration: config)
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }
}
#endif
