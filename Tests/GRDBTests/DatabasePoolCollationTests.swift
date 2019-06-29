import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabasePoolCollationTests: GRDBTestCase {
    
    func testCollationIsSharedBetweenWriterAndReaders() throws {
        let dbPool = try makeDatabasePool()
        
        let collation1 = DatabaseCollation("collation1") { (string1, string2) in
            return (string1 == string2) ? .orderedSame : ((string1 < string2) ? .orderedAscending : .orderedDescending)
        }
        dbPool.add(collation: collation1)
        
        let collation2 = DatabaseCollation("collation2") { (string1, string2) in
            return (string1 == string2) ? .orderedSame : ((string1 < string2) ? .orderedDescending : .orderedAscending)
        }
        dbPool.add(collation: collation2)
        
        try dbPool.write { db in
            // Both collations are available in writer
            try db.execute(sql: """
                CREATE TABLE items (text TEXT COLLATE collation2);
                INSERT INTO items (text) VALUES ('a');
                INSERT INTO items (text) VALUES ('b');
                INSERT INTO items (text) VALUES ('c');
                """)
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT text FROM items ORDER BY text"), ["c", "b", "a"])
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT text FROM items ORDER BY text COLLATE collation1"), ["a", "b", "c"])
        }
        
        try dbPool.read { db in
            // Both collations are available in reader
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT text FROM items ORDER BY text"), ["c", "b", "a"])
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT text FROM items ORDER BY text COLLATE collation1"), ["a", "b", "c"])
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT text FROM items ORDER BY text COLLATE collation2"), ["c", "b", "a"])
        }
        
        dbPool.remove(collation: collation1)
        
        do {
            // collation1 is no longer available in writer
            try dbPool.write { db in
                _ = try String.fetchAll(db, sql: "SELECT text FROM items ORDER BY text COLLATE collation1")
            }
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssert(error.message!.contains("collation1"))
        }
        
        do {
            // collation1 is no longer available in reader
            try dbPool.read { db in
                _ = try String.fetchAll(db, sql: "SELECT text FROM items ORDER BY text COLLATE collation1")
            }
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssert(error.message!.contains("collation1"))
        }
    }
}
