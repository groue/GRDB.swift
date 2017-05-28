#if SQLITE_HAS_CODEC
import XCTest
import GRDBCipher

class EncryptionTests: GRDBTestCase {
    
    func testDatabaseQueueWithPassphraseToDatabaseQueueWithPassphrase() throws {
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
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabaseQueueWithoutPassphrase() throws {
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
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabaseQueueWithWrongPassphrase() throws {
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
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabaseQueueWithNewPassphrase() throws {
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
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            dbConfiguration.passphrase = "newSecret"
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithPassphrase() throws {
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
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithoutPassphrase() throws {
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
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithWrongPassphrase() throws {
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
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
            }
        }
    }

    func testDatabaseQueueWithPassphraseToDatabasePoolWithNewPassphrase() throws {
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
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            dbConfiguration.passphrase = "newSecret"
            let dbPool = try makeDatabasePool()
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithPassphrase() throws {
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
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithoutPassphrase() throws {
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
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithWrongPassphrase() throws {
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
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
            }
        }
    }

    func testDatabasePoolWithPassphraseToDatabasePoolWithNewPassphrase() throws {
        
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
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
            }
        }
        
        do {
            dbConfiguration.passphrase = "newSecret"
            let dbPool = try makeDatabasePool()
            try dbPool.read { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 2)
            }
        }
    }

    func testDatabaseQueueWithPragmaPassphraseToDatabaseQueueWithPassphrase() throws {
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
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }

    func testDatabaseQueueWithPragmaPassphraseToDatabaseQueueWithoutPassphrase() throws {
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
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
                XCTAssertEqual(error.message!, "file is encrypted or is not a database")
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description, "SQLite error 26: file is encrypted or is not a database")
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
                try db.execute("CREATE TABLE data (value INTEGER)")
                try db.execute("INSERT INTO data (value) VALUES (1)")
            }
            
            dbConfiguration.passphrase = "secret"
            do {
                _ = try makeDatabaseQueue(filename: "plaintext.sqlite")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
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
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM data")!, 1)
            }
        }
    }
}
#endif
