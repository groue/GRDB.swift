import XCTest
import GRDB

class DatabasePoolCollationTests: GRDBTestCase {
    
    func testCollationIsSharedBetweenWriterAndReaders() throws {
        dbConfiguration.prepareDatabase { db in
            let collation1 = DatabaseCollation("collation1") { (string1, string2) in
                return (string1 == string2) ? .orderedSame : ((string1 < string2) ? .orderedAscending : .orderedDescending)
            }
            db.add(collation: collation1)
            
            let collation2 = DatabaseCollation("collation2") { (string1, string2) in
                return (string1 == string2) ? .orderedSame : ((string1 < string2) ? .orderedDescending : .orderedAscending)
            }
            db.add(collation: collation2)
        }
        let dbPool = try makeDatabasePool()
        
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
    }
}
