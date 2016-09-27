import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

extension Database.TextEncoding : DatabaseValueConvertible { }

class TextEncodingTests : GRDBTestCase {
    
    func testDefaultEncoding() {
        assertNoError {
            dbConfiguration = Configuration()
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let encoding = Database.TextEncoding.fetchOne(db, "PRAGMA encoding")
                XCTAssertEqual(encoding, .utf8)
                XCTAssertEqual(db.configuration.textEncoding, .utf8)
            }
            XCTAssertEqual(dbQueue.configuration.textEncoding, .utf8)
        }
    }
    
    func testCustomEncoding() {
        assertNoError {
            dbConfiguration.textEncoding = .utf16le
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let encoding = Database.TextEncoding.fetchOne(db, "PRAGMA encoding")
                XCTAssertEqual(encoding, .utf16le)
                XCTAssertEqual(db.configuration.textEncoding, .utf16le)
            }
            XCTAssertEqual(dbQueue.configuration.textEncoding, .utf16le)
        }
    }
    
    func testDatabaseKnowsItsEncoding() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue(filename: "db.sqlite")
            // Something has to be written so that the encoding is actually locked
            try dbQueue.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column("id", .integer)
                }
            }
        }
        assertNoError {
            dbConfiguration.textEncoding = .utf16le
            let dbQueue = try makeDatabaseQueue(filename: "db.sqlite")
            dbQueue.inDatabase { db in
                let encoding = Database.TextEncoding.fetchOne(db, "PRAGMA encoding")
                XCTAssertEqual(encoding, .utf8)
                XCTAssertEqual(db.configuration.textEncoding, .utf8)
            }
            XCTAssertEqual(dbQueue.configuration.textEncoding, .utf8)
        }
    }
}
